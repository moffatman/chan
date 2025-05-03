import 'dart:async';
import 'dart:ui';

import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/util.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/reply_box.dart';
import 'package:chan/widgets/scroll_tracker.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

const weakSettings = RouteSettings(
  name: 'weak'
);

class WeakNavigator extends StatefulWidget {
  final Widget child;
  final Curve curve;
  final Duration duration;

  const WeakNavigator({
    required this.child,
    this.curve = Curves.ease,
    this.duration = const Duration(milliseconds: 150),
    Key? key
  }) : super(key: key);

  @override
  createState() => WeakNavigatorState();

  static WeakNavigatorState? of(BuildContext context) {
    return context.findAncestorStateOfType<WeakNavigatorState>();
  }

  static Future<T?> push<T extends Object?>(BuildContext context, Widget widget) {
    if (WeakNavigator.of(context) != null) {
      return WeakNavigator.of(context)!.push(widget);
    }
    else {
      final imageboard = context.read<Imageboard?>();
      final replyBoxZone = context.read<ReplyBoxZone?>();
      return Navigator.of(context).push(TransparentRoute(
        builder: (context) => imageboard == null ? widget : ImageboardScope(
          imageboardKey: null,
          imageboard: imageboard,
          child: MultiProvider(
            providers: [
              Provider<void>.value(value: null), // Dummy, at least one provider is required
              if (replyBoxZone != null) Provider<ReplyBoxZone>.value(value: replyBoxZone)
            ],
            child: widget
          )
        ),
        settings: weakSettings
      ));
    }
  }

  static void pop<T extends Object?>(BuildContext context, [T? result]) {
    if (WeakNavigator.of(context) != null) {
      WeakNavigator.of(context)!.pop(result);
    }
    else {
      Navigator.of(context).pop(result);
    }
  }

  static VoidCallback pushAndReturnCallback<T extends Object?>(BuildContext context, Widget widget) {
    if (WeakNavigator.of(context) != null) {
      WeakNavigator.of(context)!.push(widget);
      return WeakNavigator.of(context)!.pop;
    }
    else {
      final imageboard = context.read<Imageboard?>();
      Navigator.of(context).push(TransparentRoute(
        builder: (context) => imageboard == null ? widget : ImageboardScope(
          imageboardKey: null,
          imageboard: imageboard,
          child: widget
        ),
        settings: weakSettings
      ));
    }
    return Navigator.of(context).pop;
  }

  static setHandleStatusBarTap(BuildContext context, bool Function() handleStatusBarTap) {
    final route = context.read<WeakNavigatorRoute?>();
    if (route != null) {
      route.handleStatusBarTap = handleStatusBarTap;
    }
    else {

    }
  }
}

class WeakNavigatorRoute<T> {
  final Widget child;
  final Curve curve;
  final AnimationController forwardController;
  final CurvedAnimation forwardCurvedAnimation;
  final AnimationController coverController;
  final Completer<T> completer;
  bool Function()? handleStatusBarTap;
  late final OverlayEntry overlayEntry = OverlayEntry(
    builder: (context) => FadeTransition(
      opacity: forwardCurvedAnimation,
      child: _AnimatedBlur(
        animation: coverController,
        curve: curve,
        child: Provider<WeakNavigatorRoute>.value(
          value: this,
          child: child
        )
      )
    ),
    maintainState: true
  );

  WeakNavigatorRoute({
    required this.child,
    required this.curve,
    required this.forwardController,
    required this.forwardCurvedAnimation,
    required this.coverController,
    required this.completer
  });
}

class WeakNavigatorState extends State<WeakNavigator> with TickerProviderStateMixin {
  final List<WeakNavigatorRoute> stack = [];
  final _overlayKey = GlobalKey<OverlayState>();
  late OverlayEntry rootEntry;
  late final AnimationController rootCoverAnimationController = AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    rootEntry = OverlayEntry(
      builder: (context) => _AnimatedBlur(
        animation: rootCoverAnimationController,
        curve: widget.curve,
        child: widget.child,
      ),
      opaque: true,
      maintainState: true
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: stack.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          pop(result);
        }
      },
      child: ClipRect(
        child: Overlay(
          key: _overlayKey,
          initialEntries: [rootEntry]
        )
      )
    );
  }

  Future<T?> push<T extends Object?>(Widget child) {
    ScrollTracker.instance.weakNavigatorDidPush();
    lightHapticFeedback();
    final forwardController = AnimationController(
      vsync: this,
      duration: widget.duration
    );
    final forwardCurvedAnimation = CurvedAnimation(
      curve: widget.curve,
      parent: forwardController
    );
    final coverController = AnimationController(
      vsync: this,
      duration: widget.duration
    );
    final entry = WeakNavigatorRoute<T>(
      curve: widget.curve,
      child: child,
      forwardController: forwardController,
      forwardCurvedAnimation: forwardCurvedAnimation,
      coverController: coverController,
      completer: Completer<T>()
    );
    stack.add(entry);
    _overlayKey.currentState!.insert(entry.overlayEntry);
    forwardController.forward();
    if (stack.length > 1) {
      stack[stack.length - 2].coverController.forward();
    }
    else {
      rootCoverAnimationController.forward();
    }
    setState(() {});
    return entry.completer.future;
  }

  void pop<T extends Object?>([T? result]) async {
    ScrollTracker.instance.weakNavigatorDidPop();
    lightHapticFeedback();
    final entry = stack.removeLast();
    if (stack.isNotEmpty) {
      stack.last.coverController.reverse();
    }
    else {
      rootCoverAnimationController.reverse();
    }
    setState(() {});
    await entry.forwardController.reverse(from: 1).orCancel;
    entry.overlayEntry.remove();
    entry.completer.complete(result);
    entry.forwardController.dispose();
    entry.forwardCurvedAnimation.dispose();
    entry.coverController.dispose();
  }

  Future<void> popAllExceptFirst({bool animated = false}) async {
    ScrollTracker.instance.weakNavigatorDidPop();
    lightHapticFeedback();
    await Future.wait([
      rootCoverAnimationController.reverse(),
      ...stack.map((x) => x.forwardController.reverse(from: 1))
    ]);
    for (final x in stack) {
      x.overlayEntry.remove();
      x.completer.complete();
      x.forwardController.dispose();
      x.forwardCurvedAnimation.dispose();
      x.coverController.dispose();
    }
    stack.clear();
    setState(() {});
  }

  bool handleStatusBarTap() {
    return stack.tryLast?.handleStatusBarTap?.call() ?? false;
  }

  @override
  void dispose() {
    super.dispose();
    rootCoverAnimationController.dispose();
  }
}

class _AnimatedBlur extends StatelessWidget {
  final AnimationController animation;
  final Curve curve;
  final Widget child;

  const _AnimatedBlur({
    required this.animation,
    this.curve = Curves.linear,
    required this.child,
    Key? key
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!Persistence.settings.blurEffects) {
      return child;
    }
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => ImageFiltered(
        enabled: animation.value != 0.0,
        imageFilter: ImageFilter.blur(
          sigmaX: 5.0 * curve.transform(animation.value),
          sigmaY: 5.0 * curve.transform(animation.value)
        ),
        child: child
      ),
      child: child
    );
  }
}
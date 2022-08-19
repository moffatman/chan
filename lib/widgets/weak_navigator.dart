import 'dart:async';
import 'dart:ui';

import 'package:chan/services/imageboard.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/util.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';

class WeakNavigator extends StatefulWidget {
  final Widget child;

  const WeakNavigator({
    required this.child,
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
      return Navigator.of(context).push(TransparentRoute(
        builder: (context) => imageboard == null ? widget : ImageboardScope(
          imageboardKey: null,
          imageboard: imageboard,
          child: widget
        ),
        showAnimations: context.read<EffectiveSettings>().showAnimations
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
}

class WeakNavigatorState extends State<WeakNavigator> with TickerProviderStateMixin {
  final List<Tuple4<OverlayEntry, AnimationController, AnimationController, Completer>> stack = [];
  final _overlayKey = GlobalKey<OverlayState>();
  late OverlayEntry rootEntry;
  late final AnimationController rootCoverAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));

  @override
  void initState() {
    super.initState();
    rootEntry = OverlayEntry(
      builder: (context) => _AnimatedBlur(
        animation: rootCoverAnimationController,
        child: widget.child,
      ),
      opaque: true,
      maintainState: true
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (stack.isNotEmpty) {
          pop();
          return false;
        }
        return true;
      },
      child: ClipRect(
        child: Overlay(
          key: _overlayKey,
          initialEntries: [rootEntry]
        )
      )
    );
  }

  Future<T?> push<T extends Object?>(Widget widget) {
    lightHapticFeedback();
    final forwardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150)
    );
    final coverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150)
    );
    final entry = Tuple4(OverlayEntry(
      builder: (context) => FadeTransition(
        opacity: forwardController,
        child: _AnimatedBlur(
          animation: coverController,
          child: widget
        )
      ),
      maintainState: true
    ), forwardController, coverController, Completer<T>());
    stack.add(entry);
    _overlayKey.currentState!.insert(entry.item1);
    forwardController.forward();
    if (stack.length > 1) {
      stack[stack.length - 2].item3.forward();
    }
    else {
      rootCoverAnimationController.forward();
    }
    return entry.item4.future;
  }

  void pop<T extends Object?>([T? result]) async {
    lightHapticFeedback();
    final entry = stack.removeLast();
    if (stack.isNotEmpty) {
      stack.last.item3.reverse();
    }
    else {
      rootCoverAnimationController.reverse();
    }
    await entry.item2.reverse(from: 1).orCancel;
    entry.item1.remove();
    entry.item4.complete(result);
    entry.item2.dispose();
    entry.item3.dispose();
  }

  Future<void> popAllExceptFirst({bool animated = false}) async {
    lightHapticFeedback();
    await Future.wait([
      rootCoverAnimationController.reverse(),
      ...stack.map((x) => x.item2.reverse(from: 1))
    ]);
    for (final x in stack) {
      x.item1.remove();
      x.item4.complete();
      x.item2.dispose();
      x.item3.dispose();
    }
    stack.clear();
  }

  @override
  void dispose() {
    super.dispose();
    rootCoverAnimationController.dispose();
  }
}

class _AnimatedBlur extends StatelessWidget {
  final AnimationController animation;
  final Widget child;

  const _AnimatedBlur({
    required this.animation,
    required this.child,
    Key? key
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => ImageFiltered(
        enabled: animation.value != 0.0,
        imageFilter: ImageFilter.blur(
          sigmaX: 5.0 * animation.value,
          sigmaY: 5.0 * animation.value
        ),
        child: child
      ),
      child: child
    );
  }
}
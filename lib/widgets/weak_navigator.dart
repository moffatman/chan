import 'dart:async';
import 'dart:ui';

import 'package:chan/services/settings.dart';
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
      return Navigator.of(context).push(TransparentRoute(
        builder: (context) => widget,
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
    final forwardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150)
    );
    final coverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150)
    );
    final entry = Tuple4(OverlayEntry(
      builder: (context) => Opacity(
        opacity: 0.99,
        child: FadeTransition(
          opacity: forwardController,
          child: _AnimatedBlur(
            animation: coverController,
            child: widget
          )
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
  }

  Future<void> popAllExceptFirst({bool animated = false}) async {
    await Future.wait([
      rootCoverAnimationController.reverse(),
      ...stack.map((x) => x.item2.reverse(from: 1))
    ]);
    for (final x in stack) {
      x.item1.remove();
      x.item4.complete();
    }
    stack.clear();
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
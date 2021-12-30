import 'dart:async';
import 'dart:ui';

import 'package:chan/widgets/util.dart';
import 'package:flutter/widgets.dart';
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
        builder: (context) => widget
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
  final List<Tuple3<OverlayEntry, AnimationController, Completer>> stack = [];
  final _overlayKey = GlobalKey<OverlayState>();
  late OverlayEntry rootEntry;

  @override
  void initState() {
    super.initState();
    rootEntry = OverlayEntry(
      builder: (context) => widget.child,
      maintainState: true
    );
  }

  @override
  Widget build(BuildContext context) {
    return Overlay(
      key: _overlayKey,
      initialEntries: [rootEntry],
    );
  }

  Future<T?> push<T extends Object?>(Widget widget) {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150)
    );
    final entry = Tuple3(OverlayEntry(
      builder: (context) => AnimatedBuilder(
        animation: controller,
        builder: (context, child) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: controller.value * 5, sigmaY: controller.value * 5),
          child: Opacity(
            opacity: controller.value,
            child: child
          )
        ),
        child: widget
      ),
      maintainState: true
    ), controller, Completer<T>());
    stack.add(entry);
    _overlayKey.currentState!.insert(entry.item1);
    controller.forward();
    return entry.item3.future;
  }

  void pop<T extends Object?>([T? result]) async {
    final entry = stack.removeLast();
    await entry.item2.reverse(from: 1).orCancel;
    entry.item1.remove();
    entry.item3.complete(result);
  }

  Future<void> popAllExceptFirst({bool animated = false}) async {
    await Future.wait(stack.map((x) => x.item2.reverse(from: 1)));
    for (final x in stack) {
      x.item1.remove();
      x.item3.complete();
    }
    stack.clear();
  }
}
import 'package:chan/pages/master_detail.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class SwitchingView<T> extends StatefulWidget {
  const SwitchingView({
    required this.currentIndex,
    required this.items,
    required this.builder,
		Key? key
  }) : super(key: key);

  final int currentIndex;
  final List<T> items;
  final Widget Function(T) builder;

  @override
  createState() => _SwitchingViewState<T>();
}

class _SwitchingViewState<T> extends State<SwitchingView<T>> {
  final Map<T, bool> shouldBuild = <T, bool>{};
  final Map<T, FocusScopeNode> focusNodes = <T, FocusScopeNode>{};

  // When focus nodes are no longer needed, we need to dispose of them, but we
  // can't be sure that nothing else is listening to them until this widget is
  // disposed of, so when they are no longer needed, we move them to this list,
  // and dispose of them when we dispose of this widget.
  final List<FocusScopeNode> discardedNodes = <FocusScopeNode>[];

  final Map<T, WillPopZone> willPopZones = <T, WillPopZone>{};

  final Map<T, Widget> widgets = <T, Widget>{};

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _focusActiveTab();
  }

  @override
  void didUpdateWidget(SwitchingView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ks = widget.items.toSet();
    for (final key in focusNodes.keys.toList(growable: false)) {
      if (!ks.contains(key)) {
        print('Scrapping $key');
        discardedNodes.add(focusNodes.remove(key)!);
        willPopZones.remove(key);
        widgets.remove(key);
      }
    }
    _focusActiveTab();
  }

  // Will focus the active tab if the FocusScope above it has focus already.  If
  // not, then it will just mark it as the preferred focus for that scope.
  void _focusActiveTab() {
    final node = focusNodes[widget.items[widget.currentIndex]];
    if (node == null) {
      return;
    }
    try {
      FocusScope.of(context).setFirstFocus(node);
    }
    catch (e) {
      print('failed to set focus: $e');
    }
  }

  @override
  void dispose() {
    for (final FocusScopeNode focusScopeNode in focusNodes.values) {
      focusScopeNode.dispose();
    }
    for (final FocusScopeNode focusScopeNode in discardedNodes) {
      focusScopeNode.dispose();
    }
    super.dispose();
  }

  Future<bool> _maybePop() async {
    return (await willPopZones[widget.items[widget.currentIndex]]?.maybePop?.call()) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final primaryScrollController = PrimaryScrollController.maybeOf(context);
    context.watch<WillPopZone?>()?.maybePop = _maybePop;
    return Stack(
      fit: StackFit.expand,
      children: List<Widget>.generate(widget.items.length, (int index) {
        final item = widget.items[index];
        final bool active = index == widget.currentIndex;
        final build = shouldBuild[item] = active || (shouldBuild[item] ?? false);
        print('build $item= $build');
        final child = build ? widgets.putIfAbsent(item, () => widget.builder(item)) : const SizedBox.shrink();
        return HeroMode(
          key: ValueKey(widget.items[index]),
          enabled: active,
          child: Offstage(
            offstage: !active,
            child: TickerMode(
              enabled: active,
              child: FocusScope(
                node: focusNodes[item] ??= FocusScopeNode(debugLabel: 'SwitchingView[${index + focusNodes.length}] $item'),
                child: Provider.value(
                  value: willPopZones[item] ??= WillPopZone(),
                  child: (active && primaryScrollController != null) ? PrimaryScrollController(
                    controller: primaryScrollController,
                    child: child
                  ) : PrimaryScrollController.none(child: child)
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
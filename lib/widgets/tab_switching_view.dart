import 'package:chan/pages/master_detail.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class TabSwitchingView extends StatefulWidget {
  const TabSwitchingView({
    required this.currentTabIndex,
    required this.tabCount,
    required this.tabBuilder,
		Key? key
  }) : super(key: key);

  final int currentTabIndex;
  final int tabCount;
  final IndexedWidgetBuilder tabBuilder;

  @override
  createState() => _TabSwitchingViewState();
}

class _TabSwitchingViewState extends State<TabSwitchingView> {
  final List<bool> shouldBuildTab = <bool>[];
  final List<FocusScopeNode> tabFocusNodes = <FocusScopeNode>[];

  // When focus nodes are no longer needed, we need to dispose of them, but we
  // can't be sure that nothing else is listening to them until this widget is
  // disposed of, so when they are no longer needed, we move them to this list,
  // and dispose of them when we dispose of this widget.
  final List<FocusScopeNode> discardedNodes = <FocusScopeNode>[];

  final List<WillPopZone> willPopZones = <WillPopZone>[];

  @override
  void initState() {
    super.initState();
    shouldBuildTab.addAll(List<bool>.filled(widget.tabCount, false));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _focusActiveTab();
  }

  @override
  void didUpdateWidget(TabSwitchingView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only partially invalidate the tabs cache to avoid breaking the current
    // behavior. We assume that the only possible change is either:
    // - new tabs are appended to the tab list, or
    // - some trailing tabs are removed.
    // If the above assumption is not true, some tabs may lose their state.
    final int lengthDiff = widget.tabCount - shouldBuildTab.length;
    if (lengthDiff > 0) {
      shouldBuildTab.addAll(List<bool>.filled(lengthDiff, false));
    } else if (lengthDiff < 0) {
      shouldBuildTab.removeRange(widget.tabCount, shouldBuildTab.length);
    }
    _focusActiveTab();
  }

  // Will focus the active tab if the FocusScope above it has focus already.  If
  // not, then it will just mark it as the preferred focus for that scope.
  void _focusActiveTab() {
    if (tabFocusNodes.length != widget.tabCount) {
      if (tabFocusNodes.length > widget.tabCount) {
        discardedNodes.addAll(tabFocusNodes.sublist(widget.tabCount));
        tabFocusNodes.removeRange(widget.tabCount, tabFocusNodes.length);
        willPopZones.removeRange(widget.tabCount, willPopZones.length);
      } else {
        tabFocusNodes.addAll(
          List<FocusScopeNode>.generate(
            widget.tabCount - tabFocusNodes.length,
              (int index) => FocusScopeNode(debugLabel: 'TabSwitchingView Tab ${index + tabFocusNodes.length}'),
          ),
        );
        willPopZones.addAll(
          List<WillPopZone>.generate(
            widget.tabCount - willPopZones.length,
              (int index) => WillPopZone()
          )
        );
      }
    }
    try {
      FocusScope.of(context).setFirstFocus(tabFocusNodes[widget.currentTabIndex]);
    }
    catch (e) {
      print('failed to set focus: $e');
    }
  }

  @override
  void dispose() {
    for (final FocusScopeNode focusScopeNode in tabFocusNodes) {
      focusScopeNode.dispose();
    }
    for (final FocusScopeNode focusScopeNode in discardedNodes) {
      focusScopeNode.dispose();
    }
    super.dispose();
  }

  Future<bool> _maybePop() async {
    return (await willPopZones[widget.currentTabIndex].maybePop?.call()) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<WillPopZone?>()?.maybePop = _maybePop;
    return Stack(
      fit: StackFit.expand,
      children: List<Widget>.generate(widget.tabCount, (int index) {
        final bool active = index == widget.currentTabIndex;
        shouldBuildTab[index] = active || shouldBuildTab[index];

        return HeroMode(
          enabled: active,
          child: Offstage(
            offstage: !active,
            child: TickerMode(
              enabled: active,
              child: FocusScope(
                node: tabFocusNodes[index],
                child: Provider.value(
                  value: willPopZones[index],
                  child: Builder(builder: (BuildContext context) {
                    return shouldBuildTab[index] ? widget.tabBuilder(context, index) : const SizedBox.shrink();
                  }),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
import 'package:chan/main.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/util.dart';
import 'package:chan/widgets/tab_menu.dart';
import 'package:chan/widgets/tab_widget_builder.dart';
import 'package:chan/widgets/util.dart';
import 'package:chan/widgets/weak_gesture_recognizer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class _TabListTile extends StatelessWidget {
	final PersistentBrowserTab tab;
	final bool selected;
	final VoidCallback? onTap;

	const _TabListTile({
		required this.tab,
		this.onTap,
		this.selected = false
	});

	@override
	Widget build(BuildContext context) {
		return TabWidgetBuilder(
			tab: tab,
			builder: (context, data) => ListTile(
				selected: selected,
				leading: SizedBox(
					width: 30,
					height: 30,
					child: Stack(
						children: [
							data.primaryIcon,
							if (data.secondaryIcon != null) Align(
								alignment: Alignment.bottomRight,
								child: SizedBox(
									width: 20,
									height: 20,
									child: data.secondaryIcon!
								)
							)
						]
					)
				),
				leadingAndTrailingTextStyle: TextStyle(
					color: ChanceTheme.primaryColorWithBrightness80Of(context),
					fontSize: 15
				),
				trailing: Row(
					mainAxisSize: MainAxisSize.min,
					children: [
						if (data.unseenYouCount > 0) Text('${data.unseenYouCount}', style: TextStyle(color: ChanceTheme.secondaryColorOf(context))),
						if (data.unseenCount > 0) Text('${data.unseenCount}')
					]
				),
				onTap: onTap,
				title: Text(data.longTitle, maxLines: 1, overflow: TextOverflow.ellipsis)
			)
		);
	}
}

class ChanceDrawer extends StatelessWidget {
	const ChanceDrawer({
		super.key
	});

	@override
	Widget build(BuildContext context) {
		final tabs = context.watch<ChanTabs>();
		return Drawer(
			child: Column(
				children: [
					Expanded(
						child: ReorderableListView.builder(
							padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
							reverse: true,
							itemCount: Persistence.tabs.length,
							onReorder: (oldIndex, newIndex) {
								tabs.onReorder(Persistence.tabs.length - (1 + oldIndex), Persistence.tabs.length - newIndex);
							},
							itemBuilder: (context, rawIndex) {
								final i = Persistence.tabs.length - (1 + rawIndex);
								final tab = Persistence.tabs[i];
								return ReorderableDelayedDragStartListener(
									index: i,
									key: ValueKey(i),
									child: Builder(
										builder: (context) {
											void showThisTabMenu() {
												final ro = context.findRenderObject()! as RenderBox;
												showTabMenu(
													context: context,
													direction: AxisDirection.right,
													showTitles: false,
													origin: Rect.fromPoints(
														ro.localToGlobal(ro.semanticBounds.topLeft),
														ro.localToGlobal(ro.semanticBounds.bottomRight)
													),
													actions: [
														TabMenuAction(
															icon: Icons.close,
															title: 'Close',
															isDestructiveAction: true,
															disabled: Persistence.tabs.length == 1,
															onPressed: () => tabs.closeBrowseTab(i)
														),
														TabMenuAction(
															icon: Icons.copy,
															title: 'Clone',
															onPressed: () {
																tabs.addNewTab(
																	withImageboardKey: tab.imageboardKey,
																	atPosition: i + 1,
																	withBoard: tab.board?.name,
																	withThread: tab.thread,
																	incognito: tab.incognito,
																	withInitialSearch: tab.initialSearch,
																	activate: true
																);
															}
														)
													]
												);
											}
											return RawGestureDetector(
												gestures: {
													WeakHorizontalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<WeakHorizontalDragGestureRecognizer>(
														() => WeakHorizontalDragGestureRecognizer(weakness: 1, sign: 1),
														(recognizer) {
															recognizer.onEnd = (details) => showThisTabMenu();
														}
													)
												},
												child: _TabListTile(
													selected: tabs.mainTabIndex == 0 && tabs.browseTabIndex == i,
													onTap: () {
														lightHapticFeedback();
														if (tabs.mainTabIndex != 0) {
															tabs.mainTabIndex = 0;
															tabs.browseTabIndex = i;
															Navigator.pop(context);
														}
														else if (tabs.browseTabIndex != i) {
															tabs.browseTabIndex = i;
															Navigator.pop(context);
														}
														else {
															showThisTabMenu();
														}
													},
													tab: tab
												)
											);
										}
									)
								);
							}
						)
					),
					Builder(
						builder: (context) => RawGestureDetector(
							gestures: {
								WeakHorizontalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<WeakHorizontalDragGestureRecognizer>(
									() => WeakHorizontalDragGestureRecognizer(weakness: 1, sign: 1),
									(recognizer) {
										recognizer.onEnd = (details) {
											tabs.showNewTabPopup(
												context: context,
												axis: Axis.vertical,
												showTitles: false
											);
										};
									}
								)
							},
							child: ListTile(
								onTap: () {
									lightHapticFeedback();
									tabs.addNewTab(activate: true);
									Navigator.pop(context);
								},
								onLongPress: () => tabs.showNewTabPopup(
									context: context,
									axis: Axis.vertical,
									showTitles: false
								),
								leading: const Icon(Icons.add),
								title: const Text('New Tab')
							)
						)
					),
					AnimatedBuilder(
						animation: Listenable.merge([
							...ImageboardRegistry.instance.imageboards.map((x) => x.threadWatcher.unseenYouCount),
							...ImageboardRegistry.instance.imageboards.map((x) => x.threadWatcher.unseenCount)
						]),
						builder: (context, _) {
							final unseenYouCount = ImageboardRegistry.instance.imageboards.map((x) => x.threadWatcher.unseenYouCount).fold(0, (a, b) => a + b.value);
							final unseenCount = ImageboardRegistry.instance.imageboards.map((x) => x.threadWatcher.unseenCount).fold(0, (a, b) => a + b.value);
							return ListTile(
								onTap: () {
									lightHapticFeedback();
									tabs.mainTabIndex = 1;
									Navigator.pop(context);
								},
								selected: tabs.mainTabIndex == 1,
								leading: const Icon(Icons.bookmark),
								title: const Text('Saved'),
								leadingAndTrailingTextStyle: TextStyle(
									color: ChanceTheme.primaryColorWithBrightness80Of(context),
									fontSize: 15
								),
								trailing: Row(
									mainAxisSize: MainAxisSize.min,
									children: [
										if (unseenYouCount > 0) Text('$unseenYouCount   ', style: TextStyle(color: ChanceTheme.secondaryColorOf(context))),
										if (unseenCount > 0) Text('$unseenCount')
									]
								)
							);
						}
					),
					GestureDetector(
						onLongPress: () {
							mediumHapticFeedback();
							settings.recordThreadsInHistory = !settings.recordThreadsInHistory;
							showToast(
								context: context,
								message: settings.recordThreadsInHistory ? 'History resumed' : 'History stopped',
								icon: settings.recordThreadsInHistory ? CupertinoIcons.play : CupertinoIcons.stop
							);
						},
						child: ListTile(
							onTap: () {
								lightHapticFeedback();
								tabs.mainTabIndex = 2;
								Navigator.pop(context);
							},
							selected: tabs.mainTabIndex == 2,
							leading: context.select<EffectiveSettings, bool>((s) => s.recordThreadsInHistory) ? const Icon(Icons.history) : const Icon(Icons.history_toggle_off),
							title: const Text('History')
						)
					),
					ListTile(
						onTap: () {
							lightHapticFeedback();
							tabs.mainTabIndex = 3;
							Navigator.pop(context);
						},
						selected: tabs.mainTabIndex == 3,
						leading: const Icon(Icons.search),
						title: const Text('Search')
					),
					AnimatedBuilder(
						animation: Listenable.merge([
							ImageboardRegistry.instance.dev?.threadWatcher.unseenCount,
							ImageboardRegistry.instance.dev?.threadWatcher.unseenYouCount
						]),
						builder: (context, _) {
							final unseenCount = ImageboardRegistry.instance.dev?.threadWatcher.unseenCount.value ?? 0;
							final unseenYouCount = ImageboardRegistry.instance.dev?.threadWatcher.unseenYouCount.value ?? 0;
							return ListTile(
								onTap: () {
									lightHapticFeedback();
									tabs.mainTabIndex = 4;
									Navigator.pop(context);
								},
								selected: tabs.mainTabIndex == 4,
								leading: const Icon(Icons.settings),
								title: const Text('Settings'),
								leadingAndTrailingTextStyle: TextStyle(
									color: ChanceTheme.primaryColorWithBrightness80Of(context),
									fontSize: 15
								),
								trailing: Row(
									mainAxisSize: MainAxisSize.min,
									children: [
										if (unseenYouCount > 0) Text('$unseenYouCount   ', style: TextStyle(color: ChanceTheme.secondaryColorOf(context))),
										if (unseenCount > 0) Text('$unseenCount')
									]
								)
							);
						}
					),
					SizedBox(
						height: MediaQuery.paddingOf(context).bottom
					)
				]
			)
		);
	}
}
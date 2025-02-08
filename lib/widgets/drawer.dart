import 'package:chan/main.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/sorting.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/thread_collection_actions.dart' as thread_actions;
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/services/util.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/notifying_icon.dart';
import 'package:chan/widgets/tab_menu.dart';
import 'package:chan/widgets/thread_widget_builder.dart';
import 'package:chan/widgets/thread_row.dart';
import 'package:chan/widgets/util.dart';
import 'package:chan/widgets/weak_gesture_recognizer.dart';
import 'package:flutter/cupertino.dart' hide WeakMap;
import 'package:flutter/material.dart' hide WeakMap;
import 'package:provider/provider.dart';
import 'package:weak_map/weak_map.dart';

class _TabListTile extends StatelessWidget {
	final ThreadWidgetData data;
	final bool selected;
	final VoidCallback? onTap;

	const _TabListTile({
		required this.data,
		this.onTap,
		this.selected = false
	});

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<Settings>();
		final theme = context.watch<SavedTheme>();
		final currentImageboard = data.imageboard;
		final currentThread = data.threadState?.thread;
		final primaryColorWithBrightness80 = theme.primaryColorWithBrightness(0.8);
		return ListTile(
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
				color: primaryColorWithBrightness80,
				fontSize: 15
			),
			trailing: Row(
				mainAxisSize: MainAxisSize.min,
				children: [
					if (data.unseenYouCount > 0) Text(
						'${data.unseenYouCount} ',
						style: TextStyle(
							color: theme.secondaryColor,
							fontWeight: FontWeight.bold
						)
					),
					if (data.unseenCount > 0 && !(data.threadState?.threadWatch?.localYousOnly ?? false)) Text(
						'${data.unseenCount}',
						style: TextStyle(
							color: data.isArchived ? theme.primaryColorWithBrightness(0.6) : null
						)
					)
				]
			),
			onTap: onTap,
			title: Text(data.longTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
			subtitle: (currentImageboard == null || data.threadState == null || currentThread == null) ? null : Padding(
				padding: const EdgeInsets.only(top: 2),
				child: Text.rich(buildThreadCounters(
					settings: settings,
					theme: theme,
					imageboard: currentImageboard,
					thread: currentThread,
					threadState: data.threadState,
					showPageNumber: true,
					countsUnreliable: false,
					showUnseenColors: false,
					showUnseenCounters: (data.threadState?.threadWatch?.localYousOnly ?? false),
					showChrome: false
				))
			),
			subtitleTextStyle: TextStyle(
				color: primaryColorWithBrightness80,
				fontSize: 15
			)
		);
	}
}

class DrawerList<T extends Object> {
	final List<T> list;
	final Widget Function(T, Widget Function(BuildContext, ThreadWidgetData)) builder;
	final void Function(int, int)? onReorder;
	final ({String message, VoidCallback? onUndo}) Function(int)? onClose;
	final bool Function(int) isSelected;
	final void Function(int) onSelect;
	final Iterable<TabMenuAction> Function(int, T) buildAdditionalActions;
	final Future<void> Function()? onRefresh;
	final bool pinFirstItem;
	final AxisDirection menuAxisDirection;
	final Widget? footer;

	static Iterable<TabMenuAction> _buildNothing(int i, Object t) => const Iterable.empty();

	static int _undoId = 0;

	const DrawerList({
		required this.list,
		required this.builder,
		required this.onClose,
		required this.isSelected,
		required this.onSelect,
		required this.menuAxisDirection,
		this.buildAdditionalActions = _buildNothing,
		this.onReorder,
		this.onRefresh,
		this.pinFirstItem = false,
		this.footer
	});

	Widget itemBuilder(BuildContext context, int i) {
		final item = list[i];
		final onClose = pinFirstItem && i == 0 ? null : this.onClose;
		final innerBuilder = Builder(
			builder: (context) {
				void showThisTabMenu() {
					showTabMenu(
						context: context,
						direction: menuAxisDirection,
						titles: null,
						origin: context.globalSemanticBounds!,
						actions: [
							if (onClose != null) TabMenuAction(
								icon: Icons.close,
								title: 'Close',
								isDestructiveAction: true,
								onPressed: list.length == 1 ? null : () {
									final data = onClose(i);
									if (data.onUndo != null) {
										showUndoToast(
											context: context,
											message: data.message,
											onUndo: data.onUndo!
										);
									}
								}
							),
							...buildAdditionalActions(i, item)
						]
					);
				}
				final tile = builder(item, (context, data) => _TabListTile(
					data: data,
					selected: isSelected(i),
					onTap: () {
						lightHapticFeedback();
						if (isSelected(i)) {
							showThisTabMenu();
						}
						else {
							onSelect(i);
						}
					}
				));
				return onClose == null ? tile : Dismissible(
					key: ValueKey((item, _undoId)),
					direction: switch (menuAxisDirection) {
						// Can swipe in either direction
						AxisDirection.up || AxisDirection.down => DismissDirection.horizontal,
						AxisDirection.right => DismissDirection.startToEnd,
						AxisDirection.left => DismissDirection.endToStart
					},
					onDismissed: (direction) {
						final data = onClose(i);
						if (data.onUndo != null) {
							showUndoToast(
								context: context,
								message: data.message,
								onUndo: () {
									_undoId++;
									data.onUndo!();
								}
							);
						}
					},
					child: tile
				);
			}
		);
		if (pinFirstItem && i == 0) {
			return innerBuilder;
		}
		return ReorderableDelayedDragStartListener(
			enabled: onReorder != null,
			index: i,
			key: ValueKey(i),
			child: innerBuilder
		);
	}

	static DrawerList<PersistentBrowserTab> tabs({
		required ChanTabs tabs,
		required Settings settings,
		required VoidCallback afterUse,
		required AxisDirection menuAxisDirection,
	}) => DrawerList<PersistentBrowserTab>(
		menuAxisDirection: menuAxisDirection,
		pinFirstItem: settings.usingHomeBoard,
		list: Persistence.tabs,
		builder: (tab, builder) => TabWidgetBuilder(
			tab: tab,
			builder: builder
		),
		onReorder: tabs.onReorder,
		onClose: Persistence.tabs.length > 1 ? (i) {
			final previouslyActiveTab = tabs.browseTabIndex;
			final closedTab = Persistence.tabs[i];
			tabs.closeBrowseTab(i);
			return (
				message: 'Closed tab',
				onUndo: closedTab.board == null ? null : () {
					tabs.insertInitializedTab(i, closedTab);
					tabs.browseTabIndex = previouslyActiveTab;
				}
			);
			} : null,
		isSelected: (i) => tabs.mainTabIndex == 0 && tabs.browseTabIndex == i,
		onSelect: (i) {
			if (tabs.mainTabIndex != 0) {
				tabs.mainTabIndex = 0;
			}
			tabs.browseTabIndex = i;
			afterUse();
		},
		buildAdditionalActions: (i, tab) => [
			TabMenuAction(
				icon: Icons.copy,
				title: 'Clone',
				onPressed: () {
					tabs.addNewTab(
						withImageboardKey: tab.imageboardKey,
						atPosition: i + 1,
						withBoard: tab.board,
						withThread: tab.thread,
						incognito: tab.incognito,
						withInitialSearch: tab.initialSearch,
						activate: true
					);
				}
			)
		],
		footer: Builder(
			builder: (context) => RawGestureDetector(
				gestures: {
					WeakHorizontalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<WeakHorizontalDragGestureRecognizer>(
						() => WeakHorizontalDragGestureRecognizer(weakness: 1, sign: 1),
						(recognizer) {
							recognizer.onEnd = (details) {
								tabs.showNewTabPopup(
									context: context,
									direction: menuAxisDirection,
									titles: null,
								);
							};
						}
					)
				},
				child: ListTile(
					onTap: () {
						lightHapticFeedback();
						settings.drawerMode = DrawerMode.tabs;
						tabs.addNewTab(activate: true);
						afterUse();
					},
					tileColor: ChanceTheme.barColorOf(context),
					onLongPress: () => tabs.showNewTabPopup(
						context: context,
						direction: menuAxisDirection,
						titles: null,
					),
					leading: const Icon(Icons.add),
					title: const Text('New Tab')
				)
			)
		)
	);
}

final _ensuredThreads = WeakMap<PersistentThreadState, bool?>();

class ChanceDrawer extends StatefulWidget {
	final bool persistent;

	const ChanceDrawer({
		required this.persistent,
		super.key,
	});

	@override
	createState() => _ChanceDrawerState();
}

class _ChanceDrawerState extends State<ChanceDrawer> with SingleTickerProviderStateMixin {
	late final TabController _tabController;

	@override
	void initState() {
		super.initState();
		_tabController = TabController(
			length: 3,
			vsync: this,
			initialIndex: switch(Settings.instance.drawerMode) {
					DrawerMode.tabs => 0,
					DrawerMode.watchedThreads => 1,
					_ => 2
				}
		);
	}

	void _afterUse() {
		if (!widget.persistent) {
			Navigator.pop(context);
		}
	}

	@override
	Widget build(BuildContext context) {
		// Note - a lot of this is lazy and missing listens.
		// But it should always be updated when we open drawer so nbd.
		final tabs = context.watch<ChanTabs>();
		final settings = context.watch<Settings>();
		final DrawerList list;
		if (settings.drawerMode == DrawerMode.tabs) {
			list = DrawerList.tabs(
				tabs: tabs,
				settings: settings,
				afterUse: _afterUse,
				menuAxisDirection: AxisDirection.right
			);
		}
		else if (settings.drawerMode == DrawerMode.watchedThreads) {
			final watches = ImageboardRegistry.instance.imageboards.expand((i) => i.persistence.browserState.threadWatches.values.map(i.scope)).toList();
			sortWatchedThreads(watches);
			if (settings.onlyShowUnreadWatches) {
				watches.removeWhere((w) => !w.shouldCountAsUnread);
			}
			list = DrawerList<ImageboardScoped<ThreadWatch>>(
				list: watches,
				builder: (watch, builder) {
					if (!Persistence.isThreadCached(watch.imageboard.key, watch.item.board, watch.item.threadId)) {
						return const SizedBox(width: double.infinity);
					}
					return ThreadWidgetBuilder(
						imageboard: watch.imageboard,
						persistence: null,
						boardName: watch.item.board,
						thread: watch.item.threadIdentifier,
						builder: builder
					);
				},
				onRefresh: ImageboardRegistry.threadWatcherController.update,
				onReorder: null,
				onClose: (i) {
					final watch = watches[i];
					watch.imageboard.notifications.unsubscribeFromThread(watch.item.threadIdentifier);
					setState(() {});
					return (
						message: 'Unwatched thread',
						onUndo: () async {
							await watch.imageboard.notifications.insertWatch(watch.item);
							setState(() {});
						}
					);
				},
				isSelected: (i) => tabs.mainTabIndex == 0 && tabs.currentBrowserThread == watches[i].imageboard.scope(watches[i].item.threadIdentifier),
				onSelect: (i) async {
					final watch = watches[i];
					if (tabs.mainTabIndex != 0) {
						tabs.mainTabIndex = 0;
					}
					if (settings.openDrawerThreadsInNewTabs) {
						tabs.goToPost(
							imageboardKey: watch.imageboard.key,
							board: watch.item.board,
							threadId: watch.item.threadId,
							openNewTabIfNeeded: true
						);
					}
					else {
						tabs.setCurrentBrowserThread(watch.imageboard.scope(watch.item.threadIdentifier), showAnimationsForward: false);
					}
					_afterUse();
				},
				menuAxisDirection: AxisDirection.right
			);
		}
		else {
			List<PersistentThreadState> states = Persistence.sharedThreadStateBox.values.where((i) => i.savedTime != null && i.imageboard != null).toList();
			states.sort(getSavedThreadsSortMethod());
			states = states.take(100).toList();
			for (final state in states) {
				// Hacky way to kick off the loading
				if (!_ensuredThreads.contains(state)) {
					state.ensureThreadLoaded(catalog: true).then((_) => state.save());
					_ensuredThreads.add(key: state, value: true);
				}
			}
			list = DrawerList<PersistentThreadState>(
				list: states,
				builder: (state, builder) => ThreadWidgetBuilder(
					imageboard: state.imageboard,
					persistence: null,
					boardName: state.board,
					thread: state.identifier,
					builder: builder,
				),
				onReorder: null,
				onRefresh: () async {
					for (final state in states) {
						if (state.thread?.isArchived != true) {
							await state.imageboard?.threadWatcher.updateThread(state.identifier);
						}
					}
				},
				onClose: (i) {
					final state = states[i];
					final oldSavedTime = state.savedTime;
					state.savedTime = null;
					state.save();
					setState(() {});
					return (
						message: 'Unsaved thread',
						onUndo: () {
							state.savedTime = oldSavedTime ?? DateTime.now();
							state.save();
							setState(() {});
						}
					);
				},
				isSelected: (i) => tabs.mainTabIndex == 0 && tabs.currentBrowserThread == states[i].imageboard?.scope(states[i].identifier),
				onSelect: (i) {
					final state = states[i];
					if (tabs.mainTabIndex != 0) {
						tabs.mainTabIndex = 0;
					}
					if (settings.openDrawerThreadsInNewTabs) {
						tabs.goToPost(
							imageboardKey: state.imageboard!.key,
							board: state.board,
							threadId: state.id,
							openNewTabIfNeeded: true
						);
					}
					else {
						tabs.setCurrentBrowserThread(state.imageboard!.scope(state.identifier), showAnimationsForward: false);
					}
					_afterUse();
				},
				menuAxisDirection: AxisDirection.right
			);
		}
		final backgroundColor = ChanceTheme.backgroundColorOf(context);
		final primaryColor = ChanceTheme.primaryColorOf(context);
		final selectedButtonColor = ChanceTheme.primaryColorWithBrightness80Of(context);
		final unselectedButtonColor = ChanceTheme.primaryColorWithBrightness20Of(context);
		return Drawer(
			shape: widget.persistent ? const Border() : null,
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					SizedBox(
						height: MediaQuery.paddingOf(context).top + (ChanceTheme.materialOf(context) ? 8 : 0)
					),
					Row(
						children: [
							Flexible(
								child: Center(
									child: AnimatedBuilder(
										animation: Listenable.merge([
											ImageboardRegistry.instance.dev?.threadWatcher.unseenCount,
											ImageboardRegistry.instance.dev?.threadWatcher.unseenYouCount
										]),
										builder: (context, _) {
											final unseenCount = ImageboardRegistry.instance.dev?.threadWatcher.unseenCount.value ?? 0;
											final unseenYouCount = ImageboardRegistry.instance.dev?.threadWatcher.unseenYouCount.value ?? 0;
											return GestureDetector(
												onLongPress: () => Settings.instance.runQuickAction(context),
												child: AdaptiveFilledButton(
													color: tabs.mainTabIndex == 4 ? selectedButtonColor : unselectedButtonColor,
													padding: const EdgeInsets.all(8),
													onPressed: () {
														lightHapticFeedback();
														tabs.mainTabIndex = 4;
														_afterUse();
													},
													child: StationaryNotifyingIcon(
														primary: unseenYouCount,
														secondary: unseenCount,
														icon: Icon(Icons.settings, color: tabs.mainTabIndex == 4 ? backgroundColor : primaryColor)
													)
												)
											);
										}
									)
								)
							),
							Flexible(
								child: Center(
									child: AdaptiveFilledButton(
										padding: const EdgeInsets.all(8),
										color: tabs.mainTabIndex == 3 ? selectedButtonColor : unselectedButtonColor,
										onPressed: () {
											lightHapticFeedback();
											tabs.mainTabIndex = 3;
											_afterUse();
										},
										child: Icon(Icons.search, color: tabs.mainTabIndex == 3 ? backgroundColor : primaryColor)
									)
								)
							),
							Flexible(
								child: Center(
									child: GestureDetector(
										onLongPress: () {
											mediumHapticFeedback();
											final settings = Settings.instance;
											Settings.recordThreadsInHistorySetting.value = !settings.recordThreadsInHistory;
											showToast(
												context: context,
												message: settings.recordThreadsInHistory ? 'History resumed' : 'History stopped',
												icon: settings.recordThreadsInHistory ? CupertinoIcons.play : CupertinoIcons.stop
											);
										},
										child: AdaptiveFilledButton(
											padding: const EdgeInsets.all(8),
											color: tabs.mainTabIndex == 2 ? selectedButtonColor : unselectedButtonColor,
											onPressed: () {
												lightHapticFeedback();
												tabs.mainTabIndex = 2;
												_afterUse();
											},
											child: Icon(
												Settings.recordThreadsInHistorySetting.watch(context) ? Icons.history : Icons.history_toggle_off,
												color: tabs.mainTabIndex == 2 ? backgroundColor : primaryColor
											)
										)
									)
								)
							),
							Flexible(
								child: Center(
									child: AdaptiveFilledButton(
										padding: const EdgeInsets.all(8),
										color: tabs.mainTabIndex == 1 ? selectedButtonColor : unselectedButtonColor,
										onPressed: () {
											lightHapticFeedback();
											tabs.mainTabIndex = 1;
											_afterUse();
										},
										child: Icon(Adaptive.icons.bookmark, color: tabs.mainTabIndex == 1 ? backgroundColor : primaryColor)
									)
								)
							)
						]
					),
					const SizedBox(height: 16),
					Builder(
						builder: (context) => TabBar(
							controller: _tabController,
							indicatorColor: ChanceTheme.primaryColorOf(context),
							dividerColor: ChanceTheme.primaryColorWithBrightness20Of(context),
							unselectedLabelColor: ChanceTheme.primaryColorWithBrightness50Of(context),
							tabs: [
								const Tab(
									icon: Icon(CupertinoIcons.rectangle_stack)
								),
								Tab(
									icon: NotifyingIcon(
										primaryCount: CombiningValueListenable<int>(
											children: ImageboardRegistry.instance.imageboards.map((x) => x.threadWatcher.unseenYouCount).toList(),
											combine: (list) => list.fold(0, (a, b) => a + b)
										),
										secondaryCount: CombiningValueListenable<int>(
											children: ImageboardRegistry.instance.imageboards.map((x) => x.threadWatcher.unseenCount).toList(),
											combine: (list) => list.fold(0, (a, b) => a + b)
										),
										icon: const Icon(CupertinoIcons.bell)
									)
								),
								Tab(
									icon: Icon(Adaptive.icons.bookmark)
								)
							],
							onTap: (index) {
								final newMode = switch(index) {
									0 => DrawerMode.tabs,
									1 => DrawerMode.watchedThreads,
									_ => DrawerMode.savedThreads
								};
								if (settings.drawerMode == newMode) {
									if (newMode == DrawerMode.tabs) {
										tabs.showNewTabPopup(
											context: context,
											direction: AxisDirection.down,
											titles: Axis.horizontal,
										);
									}
									else if (newMode == DrawerMode.watchedThreads) {
										showTabMenu(
											context: context,
											direction: AxisDirection.down,
											titles: Axis.horizontal,
											origin: context.globalSemanticBounds!,
											actions: [
												TabMenuAction(
													icon: CupertinoIcons.sort_down,
													title: 'Sort...',
													onPressed: () => selectWatchedThreadsSortMethod(context)
												),
												TabMenuAction(
													icon: settings.onlyShowUnreadWatches ? CupertinoIcons.asterisk_circle_fill : CupertinoIcons.asterisk_circle,
													title: settings.onlyShowUnreadWatches ? 'Showing unread only' : 'Showing all threads',
													onPressed: () {
														settings.onlyShowUnreadWatches = !settings.onlyShowUnreadWatches;
														showToast(
															context: context,
															icon: settings.onlyShowUnreadWatches ? CupertinoIcons.asterisk_circle_fill : CupertinoIcons.asterisk_circle,
															message: settings.onlyShowUnreadWatches ? 'Showing unread only' : 'Showing all threads'
														);
														setState(() {});
													}
												),
												...thread_actions.getWatchedThreadsActions(context, onMutate: () => setState(() {}))
											]
										);
									}
									else if (newMode == DrawerMode.savedThreads) {
										showTabMenu(
											context: context,
											direction: AxisDirection.down,
											titles: Axis.horizontal,
											origin: context.globalSemanticBounds!,
											actions: [
												TabMenuAction(
													icon: CupertinoIcons.sort_down,
													title: 'Sort...',
													onPressed: () => selectSavedThreadsSortMethod(context)
												),
												TabMenuAction(
													icon: CupertinoIcons.delete,
													isDestructiveAction: true,
													title: 'Unsave all',
													onPressed: () => thread_actions.unsaveAllSavedThreads(context, onMutate: () => setState(() {}))
												)
											]
										);
									}
								}
								else {
									setState(() {
										settings.drawerMode = newMode;
									});
								}
							}
						)
					),
					if (list.pinFirstItem) Builder(
						builder: (context) => list.itemBuilder(context, 0)
					),
					Expanded(
						child: Material(
							color: backgroundColor,
							child: RefreshIndicator(
								notificationPredicate: (x) => list.onRefresh != null,
								onRefresh: () async {
									await list.onRefresh?.call();
								},
								child: MaybeScrollbar(
									child: ReorderableListView.builder(
										key: PageStorageKey(settings.drawerMode),
										primary: false,
										buildDefaultDragHandles: false,
										physics: const AlwaysScrollableScrollPhysics(),
										itemCount: list.pinFirstItem ? list.list.length - 1 : list.list.length,
										onReorder: (oldIndex, newIndex) {
											final oldI = list.pinFirstItem ? oldIndex + 1 : oldIndex;
											final newI = list.pinFirstItem ? newIndex + 1 : newIndex;
											list.onReorder?.call(oldI, newI);
										},
										itemBuilder: (context, index) {
											final i = list.pinFirstItem ? index + 1 : index;
											return list.itemBuilder(context, i);
										}
									)
								)
							)
						)
					),
					if (list.footer != null) list.footer!,
					SizedBox(
						height: MediaQuery.paddingOf(context).bottom
					)
				]
			)
		);
	}

	@override
	void dispose() {
		super.dispose();
		_tabController.dispose();
	}
}
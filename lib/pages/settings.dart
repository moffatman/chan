import 'package:chan/models/thread.dart';
import 'package:chan/pages/board.dart';
import 'package:chan/pages/licenses.dart';
import 'package:chan/pages/popup_drawer.dart';
import 'package:chan/pages/settings/appearance.dart';
import 'package:chan/pages/settings/behavior.dart';
import 'package:chan/pages/settings/common.dart';
import 'package:chan/pages/settings/data.dart';
import 'package:chan/pages/settings/site.dart';
import 'package:chan/services/luck.dart';
import 'package:chan/pages/staggered_grid_debugging.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/pages/tree_debugging.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/sorting.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/version.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/drawer.dart';
import 'package:chan/widgets/thread_row.dart';
import 'package:chan/widgets/thread_widget_builder.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatefulWidget {
	const SettingsPage({
		super.key
	});

	@override
	createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
	final scrollKey = GlobalKey(debugLabel: '_SettingsPageState.scrollKey');
	late final TextEditingController searchController;
	late final FocusNode searchFocusNode;
	String query = '';
	late Future<List<Thread>> stickyFuture = makeStickyFuture();

	Future<List<Thread>> makeStickyFuture() async {
		final imageboard = context.read<Imageboard>();
		final catalog = await imageboard.site.getCatalog(
			kDevBoard.name,
			priority: RequestPriority.interactive,
			acceptCached: CacheConstraints.any()
		);
		final list = catalog.threads.values.where((t) => t.isSticky).toList();
		for (final thread in list) {
			await thread.preinit(catalog: true);
			await imageboard.persistence.getThreadStateIfExists(thread.identifier)?.ensureThreadLoaded();
		}
		return list;
	}

	@override
	void initState() {
		super.initState();
		searchController = TextEditingController();
		searchFocusNode = FocusNode();
	}

	@override
	void dispose() {
		super.dispose();
		searchController.dispose();
		searchFocusNode.dispose();
	}

	Iterable<Widget> _buildNormal(BuildContext context) {
		final site = context.watch<ImageboardSite>();
		final settings = context.watch<Settings>();
		final skill = calculateLuck();
		return [
			GestureDetector(
				onDoubleTap: () async {
					final route = await showAdaptiveDialog<Route>(
						context: context,
						barrierDismissible: true,
						builder: (context) => AdaptiveAlertDialog(
							content: SettingsLoginPanel(
								loginSystem: site.loginSystem!
							),
							actions: [
								AdaptiveDialogAction(
									onPressed: () {
										Navigator.pop(context, adaptivePageRoute(
											builder: (context) => const TreeDebuggingPage()
										));
									},
									child: const Text('Tree Debugging')
								),
								AdaptiveDialogAction(
									onPressed: () {
										Navigator.pop(context, adaptivePageRoute(
											builder: (context) => const StaggeredGridDebuggingPage()
										));
									},
									child: const Text('Staggered Grid Debugging')
								),
								AdaptiveDialogAction(
									onPressed: () {
										Settings.showPerformanceOverlaySetting.value = !settings.showPerformanceOverlay;
										Navigator.pop(context);
									},
									child: const Text('Toggle FPS Graph')
								),
								AdaptiveDialogAction(
									onPressed: () async {
										await editStringList(
											context: context,
											list: Settings.instance.settings.appliedMigrations,
											name: 'migration',
											title: 'Applied Migrations'
										);
										await Settings.instance.didEdit();
										if (context.mounted) {
											Navigator.pop(context);
										}
									},
									child: const Text('Applied Migrations')
								),
								AdaptiveDialogAction(
									onPressed: () => Navigator.pop(context),
									child: const Text('Close')
								)
							]
						)
					);
					if (context.mounted && route != null) {
						Navigator.push(context, route);
					}
				},
				child: const Text('Development News')
			),
			const SizedBox(height: 16),
			AnimatedSize(
				duration: const Duration(milliseconds: 250),
				curve: Curves.ease,
				alignment: Alignment.topCenter,
				child: FutureBuilder<List<Thread>>(
					future: stickyFuture,
					builder: (context, snapshot) {
						if (snapshot.hasError) {
							return ErrorMessageCard(
								snapshot.error.toString(),
								remedies: {
									'Retry': () {
										stickyFuture = makeStickyFuture();
										setState(() {});
									}
								}
							);
						}
						if (!snapshot.hasData) {
							return const SizedBox(
								height: 200,
								child: Center(
									child: CircularProgressIndicator.adaptive()
								)
							);
						}
						final children = (snapshot.data ?? []).map<Widget>((thread) => CupertinoButton(
							padding: EdgeInsets.zero,
							onPressed: () => Navigator.push(context, adaptivePageRoute(
								builder: (context) => ThreadPage(
									thread: thread.identifier,
									boardSemanticId: -1,
								)
							)),
							child: Container(
								constraints: const BoxConstraints(
									maxHeight: 125
								),
								child: ThreadRow(
									thread: thread,
									isSelected: false
								)
							)
						)).toList();
						if (children.isEmpty) {
							children.add(const Center(
								child: Text('No current news', style: TextStyle(color: Colors.grey))
							));
						}
						children.add(const SizedBox(height: 16));
						final imageboard = context.watch<Imageboard>();
						children.add(Center(
							child: Padding(
								padding: const EdgeInsets.symmetric(horizontal: 16),
								child: Row(
									children: [
										Expanded(
											child: AdaptiveThinButton(
												child: const Row(
													mainAxisSize: MainAxisSize.min,
													children: [
														Icon(CupertinoIcons.chat_bubble_2),
														SizedBox(width: 16),
														Expanded(
															child: Text('More discussion')
														),
														SizedBox(width: 8),
														Icon(CupertinoIcons.chevron_forward)
													]
												),
												onPressed: () => Navigator.push(context, adaptivePageRoute(
													builder: (context) => BoardPage(
														initialBoard: kDevBoard,
														allowChangingBoard: false,
														semanticId: -1
													)
												))
											)
										),
										ValueListenableBuilder(
											valueListenable: Combining2ValueListenable(
												child1: MappingValueListenable(
													parent: context.watch<ThreadWatcher>().unseenCount,
													mapper: (unseenCount) => unseenCount.value - (snapshot.data?.map((t) {
														return imageboard.persistence.getThreadStateIfExists(t.identifier)?.unseenReplyCount() ?? 0;
													}).fold<int>(0, (a, b) => a + b) ?? 0)
												),
												child2: MappingValueListenable(
													parent: context.watch<ThreadWatcher>().unseenYouCount,
													mapper: (unseenYouCount) => unseenYouCount.value - (snapshot.data?.map((t) {
														return imageboard.persistence.getThreadStateIfExists(t.identifier)?.unseenReplyIdsToYouCount() ?? 0;
													}).fold<int>(0, (a, b) => a + b) ?? 0)
												),
												combine: (nonStickyUnseenCount, nonStickyUnseenYouCount) => (
													nonStickyUnseenCount: nonStickyUnseenCount,
													nonStickyUnseenYouCount: nonStickyUnseenYouCount
												)
											),
											builder: (context, data, _) {
												if (data.nonStickyUnseenCount <= 0 && data.nonStickyUnseenYouCount <= 0) {
													return const SizedBox.shrink();
												}
												return Padding(
													padding: const EdgeInsets.only(left: 8),
													child: AdaptiveThinButton(
														onPressed: () async {
															final watches = imageboard.persistence.browserState.threadWatches.values.toList();
															sortUnscopedWatchedThreads(imageboard, watches);
															/// !shouldCountAsUnread
															watches.removeWhere((item) {
																final threadState = imageboard.persistence.getThreadStateIfExists(item.threadIdentifier);
																if (item.localYousOnly) {
																	return (threadState?.unseenReplyIdsToYouCount() ?? 0) == 0;
																}
																return (threadState?.unseenReplyCount() ?? 0) == 0;
															});
															final selection = await Navigator.push<ThreadIdentifier>(context, TransparentRoute(
																builder: (context) {
																	final list = DrawerList<ThreadWatch>(
																		list: watches,
																		builder: (watch, builder) {
																			if (!Persistence.isThreadCached(imageboard.key, watch.board, watch.threadId)) {
																				return const SizedBox(width: double.infinity);
																			}
																			return ThreadWidgetBuilder(
																				imageboard: imageboard,
																				persistence: null,
																				boardName: watch.board,
																				thread: watch.threadIdentifier,
																				builder: builder
																			);
																		},
																		onRefresh: imageboard.threadWatcherController?.update,
																		// Don't bother with onReorder
																		onClose: (i) {
																			final watch = watches[i];
																			imageboard.notifications.unsubscribeFromThread(watch.threadIdentifier);
																			setState(() {});
																			return (
																				message: 'Unwatched thread',
																				onUndo: () async {
																					await imageboard.notifications.insertWatch(watch);
																					setState(() {});
																				}
																			);
																		},
																		isSelected: (i) => false,
																		onSelect: (i) async {
																			final watch = watches[i];
																			Navigator.pop(context, watch.threadIdentifier);
																		},
																		menuAxisDirection: AxisDirection.right
																	);
																	return PopupDrawerPage(list: list, title: '/chance/ notifications');
																}
															));
															if (selection != null && context.mounted) {
																Navigator.push(context, adaptivePageRoute(
																	builder: (context) => ThreadPage(
																		thread: selection,
																		boardSemanticId: -1,
																	)
																));
															}
														},
														child: Row(
															mainAxisSize: MainAxisSize.min,
															children: [
																const Icon(CupertinoIcons.bell),
																if (data.nonStickyUnseenCount > 0) Text(' +${data.nonStickyUnseenCount}'),
																if (data.nonStickyUnseenYouCount > 0) Text(' +${data.nonStickyUnseenYouCount}', style: TextStyle(color: settings.theme.secondaryColor))
															]
														)
													)
												);
											}
										)
									]
								)
							)
						));
						return Column(
							mainAxisSize: MainAxisSize.min,
							children: children
						);
					}
				)
			),
			const SizedBox(height: 24),
			...topLevelSettings.map((s) => s.build()),
			Wrap(
				alignment: WrapAlignment.center,
				spacing: 8,
				runSpacing: 8,
				children: [
					if (skill != null) AdaptiveButton(
						child: Text('Luck: ${(skill * 100).toStringAsFixed(0)}%'),
						onPressed: () => showLuckPopup(context: context)
					),
					AdaptiveButton(
						child: const Text('Licenses'),
						onPressed: () {
							Navigator.of(context).push(adaptivePageRoute(
								builder: (context) => const LicensesPage()
							));
						}
					)
				]
			),
			const SizedBox(height: 8),
			Center(
				child: Text('Chance $kChanceVersion', style: TextStyle(color: ChanceTheme.primaryColorWithBrightness50Of(context)))
			)
		];
	}

	Iterable<Widget> _buildResults() {
		final q = query.toLowerCase().split(' ');
		final results = topLevelSettings.expand((e) => e.search(context, q));
		if (results.isEmpty) {
			return [
				const Center(
					child: Padding(
						padding: EdgeInsets.all(16),
						child: Text('No results')
					)
				)
			];
		}
		return results.map((r) => r.build());
	}

	@override
	Widget build(BuildContext context) {
		return AdaptiveScaffold(
			resizeToAvoidBottomInset: false,
			bar: const AdaptiveBar(
				title: Text('Settings')
			),
			body: Builder(
				builder: (context) => MaybeScrollbar(
					child: ListView(
						// This will override default AlwaysScrollable for [primary]
						physics: ScrollConfiguration.of(context).getScrollPhysics(context),
						padding: MediaQuery.paddingOf(context) + const EdgeInsets.all(16),
						key: scrollKey,
						children: [
							AdaptiveSearchTextField(
								placeholder: 'Search settings...',
								controller: searchController,
								autocorrect: false,
								focusNode: searchFocusNode,
								onChanged: (newQuery) {
									setState(() {
										query = newQuery;
									});
								},
								onSuffixTap: () {
									searchController.clear();
									searchFocusNode.unfocus();
									setState(() {
										query = '';
									});
								},
							),
							const SizedBox(height: 16),
							if (query.isEmpty) ..._buildNormal(context)
							else ..._buildResults(),
							const SizedBox(height: 16),
						].map((x) => Align(
							alignment: Alignment.center,
							child: ConstrainedBox(
								constraints: const BoxConstraints(
									minWidth: 500,
									maxWidth: 500
								),
								child: x
							)
						)).toList()
					)
				)
			)
		);
	}
}

final topLevelSettings = <PopupSubpageSettingWidget>[
	PopupSubpageSettingWidget(
		settings: siteSettings,
		description: 'Site Settings',
		icon: CupertinoIcons.globe
	),
	PopupSubpageSettingWidget(
		settings: appearanceSettings,
		description: 'Appearance Settings',
		icon: CupertinoIcons.paintbrush
	),
	PopupSubpageSettingWidget(
		settings: behaviorSettings,
		description: 'Behavior Settings',
		icon: CupertinoIcons.eye_slash,
		color: MappedMutableSetting(
			CombinedMutableSetting(filtersColor, notificationsColor),
			(pair) => pair.$1 ?? pair.$2
		)
	),
	PopupSubpageSettingWidget(
		settings: dataSettings,
		description: 'Data Settings',
		icon: Adaptive.icons.photos
	)
];

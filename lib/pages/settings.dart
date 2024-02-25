import 'package:chan/models/board.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/board.dart';
import 'package:chan/pages/licenses.dart';
import 'package:chan/pages/settings/appearance.dart';
import 'package:chan/pages/settings/behavior.dart';
import 'package:chan/pages/settings/common.dart';
import 'package:chan/pages/settings/data.dart';
import 'package:chan/pages/settings/site.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/version.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/thread_row.dart';
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
	late Future<List<Thread>> stickyFuture;

	@override
	void initState() {
		super.initState();
		searchController = TextEditingController();
		searchFocusNode = FocusNode();
		stickyFuture = () async {
			final imageboard = context.read<Imageboard>();
			final list = (await imageboard.site.getCatalog('chance', priority: RequestPriority.interactive)).where((t) => t.isSticky).toList();
			for (final thread in list) {
				await thread.preinit(catalog: true);
				await imageboard.persistence.getThreadStateIfExists(thread.identifier)?.ensureThreadLoaded();
			}
			return list;
		}();
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
		return [
			GestureDetector(
				onDoubleTap: () {
					showAdaptiveDialog(
						context: context,
						barrierDismissible: true,
						builder: (context) => AdaptiveAlertDialog(
							content: SettingsLoginPanel(
								loginSystem: site.loginSystem!
							),
							actions: [
								AdaptiveDialogAction(
									onPressed: () {
										Settings.showPerformanceOverlaySetting.value = !settings.showPerformanceOverlay;
										Navigator.pop(context);
									},
									child: const Text('Toggle FPS Graph')
								),
								AdaptiveDialogAction(
									onPressed: () => Navigator.pop(context),
									child: const Text('Close')
								)
							]
						)
					);
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
					initialData: context.read<ThreadWatcher>().peekLastCatalog('chance')?.where((c) => c.isSticky).toList(),
					builder: (context, snapshot) {
						if (!snapshot.hasData) {
							return const SizedBox(
								height: 200,
								child: Center(
									child: CircularProgressIndicator.adaptive()
								)
							);
						}
						else if (snapshot.hasError) {
							return SizedBox(
								height: 200,
								child: Center(
									child: Text(snapshot.error.toString())
								)
							);
						}
						final children = (snapshot.data ?? []).map<Widget>((thread) => GestureDetector(
							onTap: () => Navigator.push(context, adaptivePageRoute(
								builder: (context) => ThreadPage(
									thread: thread.identifier,
									boardSemanticId: -1,
								)
							)),
							child: Container(
								constraints: const BoxConstraints(
									maxHeight: 125
								),
								foregroundDecoration: BoxDecoration(
									border: Border(
										top: BorderSide(color: settings.theme.primaryColorWithBrightness(0.2)),
										bottom: BorderSide(color: settings.theme.primaryColorWithBrightness(0.2))
									)
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
								child: AdaptiveThinButton(
									child: Row(
										mainAxisSize: MainAxisSize.min,
										children: [
											const Icon(CupertinoIcons.chat_bubble_2),
											const SizedBox(width: 16),
											const Expanded(
												child: Text('More discussion')
											),
											ValueListenableBuilder(
												valueListenable: context.watch<ThreadWatcher>().unseenCount,
												builder: (context, unseenCount, _) {
													final nonStickyUnseenCount = unseenCount - (snapshot.data?.map((t) {
														return imageboard.persistence.getThreadStateIfExists(t.identifier)?.unseenReplyCount() ?? 0;
													}).fold<int>(0, (a, b) => a + b) ?? 0);
													if (nonStickyUnseenCount <= 0) {
														return const SizedBox.shrink();
													}
													return Row(
														mainAxisSize: MainAxisSize.min,
														children: [
															const Icon(CupertinoIcons.reply_all, size: 17),
															Text(' +$nonStickyUnseenCount')
														]
													);
												}
											),
											ValueListenableBuilder(
												valueListenable: context.watch<ThreadWatcher>().unseenYouCount,
												builder: (context, unseenYouCount, _) {
													final nonStickyUnseenYouCount = unseenYouCount - (snapshot.data?.map((t) {
														return imageboard.persistence.getThreadStateIfExists(t.identifier)?.unseenReplyIdsToYouCount() ?? 0;
													}).fold<int>(0, (a, b) => a + b) ?? 0);
													if (nonStickyUnseenYouCount <= 0) {
														return const SizedBox.shrink();
													}
													return Text(' +$nonStickyUnseenYouCount', style: TextStyle(color: settings.theme.secondaryColor));
												}
											),
											const SizedBox(width: 8),
											const Icon(CupertinoIcons.chevron_forward)
										]
									),
									onPressed: () => Navigator.push(context, adaptivePageRoute(
										builder: (context) => BoardPage(
											initialBoard: ImageboardBoard(
												name: 'chance',
												title: 'Chance - Imageboard Browser',
												isWorksafe: true,
												webmAudioAllowed: false,
												maxImageSizeBytes: 8000000,
												maxWebmSizeBytes: 8000000
											),
											allowChangingBoard: false,
											semanticId: -1
										)
									))
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
			Center(
				child: AdaptiveButton(
					child: const Text('Licenses'),
					onPressed: () {
						Navigator.of(context).push(adaptivePageRoute(
							builder: (context) => const LicensesPage()
						));
					}
				)
			),
			const SizedBox(height: 8),
			Center(
				child: Text('Chance $kChanceVersion', style: TextStyle(color: ChanceTheme.primaryColorWithBrightness50Of(context)))
			)
		];
	}

	Iterable<Widget> _buildResults() {
		final q = query.toLowerCase();
		final results = topLevelSettings.expand((e) =>  e.search(q));
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
						padding: MediaQuery.paddingOf(context) + const EdgeInsets.all(16),
						key: scrollKey,
						children: [
							AdaptiveSearchTextField(
								placeholder: 'Search settings...',
								controller: searchController,
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
		color: filtersColor
	),
	PopupSubpageSettingWidget(
		settings: dataSettings,
		description: 'Data Settings',
		icon: Adaptive.icons.photos
	)
];

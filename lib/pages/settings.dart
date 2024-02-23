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
			AnimatedSize(
				duration: const Duration(milliseconds: 250),
				curve: Curves.ease,
				alignment: Alignment.topCenter,
				child: FutureBuilder<List<Thread>>(
					future: context.read<ImageboardSite>().getCatalog('chance', priority: RequestPriority.interactive),
					initialData: context.read<ThreadWatcher>().peekLastCatalog('chance'),
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
						final children = (snapshot.data ?? []).where((t) => t.isSticky).map<Widget>((thread) => GestureDetector(
							onTap: () => Navigator.push(context, adaptivePageRoute(
								builder: (context) => ThreadPage(
									thread: thread.identifier,
									boardSemanticId: -1,
								)
							)),
							child: ConstrainedBox(
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
						children.add(Center(
							child: AdaptiveFilledButton(
								child: const Text('See more discussion'),
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
						));
						return Column(
							mainAxisSize: MainAxisSize.min,
							children: children
						);
					}
				)
			),
			const SizedBox(height: 32),
			...topLevelSettings.map((s) => s.build()),
			const SizedBox(height: 16),
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
			const SizedBox(height: 16),
			Center(
				child: Text('Chance $kChanceVersion', style: TextStyle(color: ChanceTheme.primaryColorWithBrightness50Of(context)))
			)
		];
	}

	Iterable<Widget> _buildResults() {
		final q = query.toLowerCase();
		final results = topLevelSettings.expand((e) =>  e.search(q));
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

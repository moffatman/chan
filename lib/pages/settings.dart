import 'dart:io';

import 'package:chan/models/board.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/board.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/cupertino_page_route.dart';
import 'package:chan/widgets/thread_row.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tuple/tuple.dart';
import 'package:provider/provider.dart';
import 'package:extended_image_library/extended_image_library.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class SettingsPage extends StatelessWidget {
	const SettingsPage({
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<EffectiveSettings>();
		final firstPanePercent = (settings.twoPaneSplit / twoPaneSplitDenominator) * 100;
		return CupertinoPageScaffold(
			resizeToAvoidBottomInset: false,
			navigationBar: const CupertinoNavigationBar(
				transitionBetweenRoutes: false,
				middle: Text('Settings')
			),
			child: SafeArea(
				child: SingleChildScrollView(
					physics: const BouncingScrollPhysics(),
					child: Align(
						alignment: Alignment.center,
						child: ConstrainedBox(
							constraints: const BoxConstraints(
								maxWidth: 500
							),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.stretch,
								children: [
									const Padding(
										padding: EdgeInsets.all(16),
										child: Text('Development News')
									),
									SizedBox(
										height: 200,
										child: FutureBuilder<List<Thread>>(
											future: context.read<ImageboardSite>().getCatalog('chance'),
											builder: (context, snapshot) {
												if (!snapshot.hasData) {
													return const Center(
														child: CupertinoActivityIndicator()
													);
												}
												else if (snapshot.hasError) {
													return Center(
														child: Text(snapshot.error.toString())
													);
												}
												final children = (snapshot.data ?? []).where((t) => t.isSticky).map<Widget>((thread) => GestureDetector(
													onTap: () => Navigator.push(context, FullWidthCupertinoPageRoute(
														builder: (context) => ThreadPage(
															thread: thread.identifier,
															boardSemanticId: -1,
														)
													)),
													child: ThreadRow(
														thread: thread,
														isSelected: false
													)
												)).toList();
												if (children.isEmpty) {
													children.add(const Padding(
														padding: EdgeInsets.all(16),
														child: Center(
															child: Text('No current news', style: TextStyle(color: Colors.grey))
														)
													));
												}
												children.add(CupertinoButton(
													child: const Text('See more discussion'),
													onPressed: () => Navigator.push(context, FullWidthCupertinoPageRoute(
														builder: (context) => BoardPage(
															initialBoard: ImageboardBoard(
																name: 'chance',
																title: 'Chance - Imageboard Browser',
																isWorksafe: true,
																webmAudioAllowed: false
															),
															allowChangingBoard: false,
															semanticId: -1
														)
													))
												));
												return ListView(
													physics: const BouncingScrollPhysics(),
													children: children
												);
											}
										)
									),
									const Padding(
										padding: EdgeInsets.all(16),
										child: Text('Content Filtering')
									),
									Container(
										padding: const EdgeInsets.only(left: 16, right: 16),
										child: Table(
											children: {
												'Images': settings.contentSettings.images,
												'NSFW Boards': settings.contentSettings.nsfwBoards,
												'NSFW Images': settings.contentSettings.nsfwImages,
												'NSFW Text': settings.contentSettings.nsfwText
											}.entries.map((x) => TableRow(
												children: [
													Text(x.key),
													Text(x.value ? 'Allowed' : 'Blocked', textAlign: TextAlign.right)
												]
											)).toList()
										)
									),
									Container(
										padding: const EdgeInsets.only(left: 16, right: 16),
										alignment: Alignment.center,
										child: Wrap(
											children: [
												CupertinoButton(
													child: Row(
														mainAxisSize: MainAxisSize.min,
														children: const [
															Text('Synchronize '),
															Icon(Icons.sync_rounded, size: 16)
														]
													),
													onPressed: () {
														settings.updateContentSettings();
													}
												),
												CupertinoButton(
													child: Row(
														mainAxisSize: MainAxisSize.min,
														children: const [
															Text('Edit preferences '),
															Icon(Icons.launch_rounded, size: 16)
														]
													),
													onPressed: () => launch(settings.contentSettingsUrl, forceSafariVC: false)
												)
											]
										)
									),
									SettingsFilterPanel(
										initialConfiguration: settings.filterConfiguration,
									),
									Container(
										padding: const EdgeInsets.all(16),
										child: const Text('Use touchscreen layout'),
									),
									CupertinoSegmentedControl<bool>(
										children: const {
											false: Text('No'),
											true: Text('Yes')
										},
										groupValue: settings.useTouchLayout,
										onValueChanged: (newValue) {
											settings.useTouchLayout = newValue;
										}
									),
									const Padding(
										padding: EdgeInsets.all(16),
										child: Text('Active Theme'),
									),
									CupertinoSegmentedControl<ThemeSetting>(
										children: const {
											ThemeSetting.light: Text('Light'),
											ThemeSetting.system: Text('Follow System'),
											ThemeSetting.dark: Text('Dark')
										},
										groupValue: settings.themeSetting,
										onValueChanged: (newValue) {
											settings.themeSetting = newValue;
										}
									),
									...[
										Tuple3('Light Theme Colors', settings.lightTheme, defaultLightTheme),
										Tuple3('Dark Theme Colors', settings.darkTheme, defaultDarkTheme)
									].map((theme) => Container(
										margin: const EdgeInsets.only(top: 16, left: 16, right: 16),
										padding: const EdgeInsets.only(bottom: 16),
										decoration: BoxDecoration(
											color: theme.item2.backgroundColor,
											borderRadius: const BorderRadius.all(Radius.circular(8))
										),
										child: Column(
											mainAxisSize: MainAxisSize.min,
											children: [
												Padding(
													padding: const EdgeInsets.all(16),
													child: Center(
														child: Text(theme.item1, style: TextStyle(color: theme.item2.primaryColor))
													)
												),
												Wrap(
													alignment: WrapAlignment.center,
													spacing: 16,
													runSpacing: 16,
													children: <Tuple4<String, Color, ValueChanged<Color>, Color>>[
														Tuple4('Primary', theme.item2.primaryColor, (c) => theme.item2.primaryColor = c, theme.item3.primaryColor),
														Tuple4('Secondary', theme.item2.secondaryColor, (c) => theme.item2.secondaryColor = c, theme.item3.secondaryColor),
														Tuple4('Bar', theme.item2.barColor, (c) => theme.item2.barColor = c, theme.item3.barColor),
														Tuple4('Background', theme.item2.backgroundColor, (c) => theme.item2.backgroundColor = c, theme.item3.backgroundColor)
													].map((color) => Column(
														mainAxisSize: MainAxisSize.min,
														children: [
															Text(color.item1, style: TextStyle(color: theme.item2.primaryColor)),
															const SizedBox(height: 16),
															GestureDetector(
																child: Container(
																	decoration: BoxDecoration(
																		borderRadius: const BorderRadius.all(Radius.circular(8)),
																		border: Border.all(color: theme.item2.primaryColor),
																		color: color.item2
																	),
																	width: 50,
																	height: 50
																),
																onTap: () async {
																	await showCupertinoModalPopup(
																		barrierDismissible: true,
																		context: context,
																		builder: (context) => CupertinoActionSheet(
																			title: Text('Select ${color.item1} Color'),
																			message: Theme(
																				data: ThemeData(
																					textTheme: Theme.of(context).textTheme.apply(
																						bodyColor: CupertinoTheme.of(context).primaryColor,
																						displayColor: CupertinoTheme.of(context).primaryColor
																					)
																				),
																				child: Material(
																					color: Colors.transparent,
																					child: ColorPicker(
																						pickerColor: color.item2,
																						onColorChanged: color.item3,
																						enableAlpha: false,
																						portraitOnly: true,
																						displayThumbColor: true
																					)
																				)
																			)
																		)
																	);
																	settings.handleThemesAltered();
																}
															),
															CupertinoButton(
																child: Text('Reset', style: TextStyle(color: theme.item2.primaryColor)),
																onPressed: () {
																	color.item3(color.item4);
																	settings.handleThemesAltered();
																}
															)
														]
													)).toList()
												)
											]
										)
									)),
									const Padding(
										padding: EdgeInsets.all(16),
										child: Text('Automatically load attachments'),
									),
									CupertinoSegmentedControl<AutoloadAttachmentsSetting>(
										children: const {
											AutoloadAttachmentsSetting.always: Text('Always'),
											AutoloadAttachmentsSetting.wifi: Text('When on Wi-Fi'),
											AutoloadAttachmentsSetting.never: Text('Never')
										},
										groupValue: settings.autoloadAttachmentsSetting,
										onValueChanged: (newValue) {
											settings.autoloadAttachmentsSetting = newValue;
										}
									),
									const Padding(
										padding: EdgeInsets.all(16),
										child: Text('Hide old stickied threads'),
									),
									CupertinoSegmentedControl<bool>(
										children: const {
											false: Text('No'),
											true: Text('Yes')
										},
										groupValue: settings.hideOldStickiedThreads,
										onValueChanged: (newValue) {
											settings.hideOldStickiedThreads = newValue;
										}
									),
									const Padding(
										padding: EdgeInsets.all(16),
										child: Text('Catalog Layout'),
									),
									CupertinoSegmentedControl<bool>(
										children: const {
											false: Text('Rows'),
											true: Text('Grid'),
										},
										groupValue: settings.useCatalogGrid,
										onValueChanged: (newValue) {
											settings.useCatalogGrid = newValue;
										}
									),
									Padding(
										padding: const EdgeInsets.all(16),
										child: Text('Catalog grid item width: ${settings.catalogGridWidth.round()} pixels'),
									),
									CupertinoSlider(
										min: 50,
										max: 1000,
										divisions: 19,
										value: settings.catalogGridWidth,
										onChanged: (newValue) {
											settings.catalogGridWidth = newValue;
										}
									),
									Padding(
										padding: const EdgeInsets.all(16),
										child: Text('Catalog grid item height: ${settings.catalogGridHeight.round()} pixels'),
									),
									CupertinoSlider(
										min: 50,
										max: 1000,
										divisions: 19,
										value: settings.catalogGridHeight,
										onChanged: (newValue) {
											settings.catalogGridHeight = newValue;
										}
									),
									Padding(
										padding: const EdgeInsets.all(16),
										child: Text('Two-pane breakpoint: ${settings.twoPaneBreakpoint.round()} pixels'),
									),
									CupertinoSlider(
										min: 50,
										max: 3000,
										divisions: 59,
										value: settings.twoPaneBreakpoint,
										onChanged: (newValue) {
											settings.twoPaneBreakpoint = newValue;
										}
									),
									Padding(
										padding: const EdgeInsets.all(16),
										child: Text('Two-pane split: ${firstPanePercent.toStringAsFixed(0)}% catalog, ${(100 - firstPanePercent).toStringAsFixed(0)}% board'),
									),
									CupertinoSlider(
										min: 1,
										max: (twoPaneSplitDenominator - 1).toDouble(),
										divisions: twoPaneSplitDenominator - 1,
										value: settings.twoPaneSplit.toDouble(),
										onChanged: (newValue) {
											settings.twoPaneSplit = newValue.toInt();
										}
									),
									const Padding(
										padding: EdgeInsets.only(top: 16, left: 16),
										child: Text('Cached media')
									),
									const SettingsCachePanel(),
									const Padding(
										padding: EdgeInsets.only(top: 16, left: 16),
										child: Text('Cached threads and history')
									),
									const SettingsThreadsPanel(),
									CupertinoButton(
										child: const Text('Clear API cookies'),
										onPressed: () {
											Persistence.cookies.deleteAll();
										}
									)
								],
							)
						)
					)
				)
			)
		);
	}
}

class SettingsCachePanel extends StatefulWidget {
	const SettingsCachePanel({
		Key? key
	}) : super(key: key);

	@override
	createState() => _SettingsCachePanelState();
}

const _knownCacheDirs = {
	cacheImageFolderName: 'Images',
	'webmcache': 'Converted WEBM files',
	'sharecache': 'Media exported for sharing',
	'webpickercache': 'Images picked from web'
};

class _SettingsCachePanelState extends State<SettingsCachePanel> {
	Map<String, int>? folderSizes;
	bool clearing = false;

	@override
	void initState() {
		super.initState();
		_readFilesystemInfo();
	}

	Future<void> _readFilesystemInfo() async {
		folderSizes = {};
		final systemTempDirectory = Persistence.temporaryDirectory;
		for (final dirName in _knownCacheDirs.keys) {
			final directory = Directory(systemTempDirectory.path + '/' + dirName);
			if (await directory.exists()) {
				int size = 0;
				await for (final subentry in directory.list(recursive: true)) {
					size += (await subentry.stat()).size;
				}
				folderSizes![directory.path.split('/').last] = size;
			}
		}
		setState(() {});
	}

	Future<void> _clearCaches() async {
		setState(() {
			clearing = true;
		});
		await clearDiskCachedImages();
		final systemTempDirectory = Persistence.temporaryDirectory;
		for (final dirName in _knownCacheDirs.keys) {
			final directory = Directory(systemTempDirectory.path + '/' + dirName);
			if (await directory.exists()) {
				await directory.delete(recursive: true);
			}
		}
		await _readFilesystemInfo();
		setState(() {
			clearing = false;
		});
	}

	@override
	Widget build(BuildContext context) {
		return Container(
			decoration: BoxDecoration(
				borderRadius: const BorderRadius.all(Radius.circular(8)),
				color: CupertinoTheme.of(context).primaryColor.withOpacity(0.2)
			),
			margin: const EdgeInsets.all(16),
			padding: const EdgeInsets.all(16),
			child: Column(
				mainAxisSize: MainAxisSize.min,
				children: [
					if (folderSizes?.isEmpty ?? true) const Text('No cached media'),
					Table(
						children: (folderSizes ?? {}).entries.map((entry) {
							double megabytes = entry.value / 1000000;
							return TableRow(
								children: [
									Padding(
										padding: const EdgeInsets.only(bottom: 8),
										child: Text(_knownCacheDirs[entry.key]!, textAlign: TextAlign.left)
									),
									Text(megabytes.toStringAsFixed(1) + ' MB', textAlign: TextAlign.right)
								]
							);
						}).toList()
					),
					const SizedBox(height: 8),
					Row(
						mainAxisAlignment: MainAxisAlignment.spaceEvenly,
						children: [
							CupertinoButton(
								padding: EdgeInsets.zero,
								child: const Text('Recalculate'),
								onPressed: _readFilesystemInfo
							),
							CupertinoButton(
								padding: EdgeInsets.zero,
								child: Text(clearing ? 'Deleting...' : 'Delete all'),
								onPressed: (folderSizes?.isEmpty ?? true) ? null : (clearing ? null : _clearCaches)
							)
						]
					)
				]
			)
		);
	}
}

class SettingsThreadsPanel extends StatelessWidget {
	const SettingsThreadsPanel({
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return ValueListenableBuilder(
			valueListenable: context.watch<Persistence>().threadStateBox.listenable(),
			builder: (context, Box<PersistentThreadState> threadStateBox, child) {
				final oldThreadRows =[0, 7, 14, 30, 60, 90, 180].map((days) {
					final cutoff = DateTime.now().subtract(Duration(days: days));
					final oldThreads = threadStateBox.values.where((state) {
						return (state.savedTime == null) && state.lastOpenedTime.compareTo(cutoff).isNegative;
					}).toList();
					return Tuple2(days, oldThreads);
				}).toList();
				oldThreadRows.removeRange(oldThreadRows.lastIndexWhere((r) => r.item2.isNotEmpty) + 1, oldThreadRows.length);
				confirmDelete(List<PersistentThreadState> toDelete) async {
					final confirmed = await showCupertinoDialog<bool>(
						context: context,
						builder: (_context) => CupertinoAlertDialog(
							title: const Text('Confirm deletion'),
							content: Text('${toDelete.length} threads will be deleted'),
							actions: [
								CupertinoDialogAction(
									child: const Text('Cancel'),
									onPressed: () {
										Navigator.of(_context).pop();
									}
								),
								CupertinoDialogAction(
									child: const Text('Confirm'),
									isDestructiveAction: true,
									onPressed: () {
										Navigator.of(_context).pop(true);
									}
								)
							]
						)
					);
					if (confirmed == true) {
						for (final thread in toDelete) {
							thread.delete();
						}
					}
				}
				return Container(
					decoration: BoxDecoration(
						borderRadius: const BorderRadius.all(Radius.circular(8)),
						color: CupertinoTheme.of(context).primaryColor.withOpacity(0.2)
					),
					margin: const EdgeInsets.all(16),
					padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
					child: Table(
						defaultVerticalAlignment: TableCellVerticalAlignment.middle,
						children: [
							TableRow(
								children: [
									const Text('Saved threads', textAlign: TextAlign.left),
									Text(threadStateBox.values.where((t) => t.savedTime != null).length.toString(), textAlign: TextAlign.right),
									const CupertinoButton(
										padding: EdgeInsets.zero,
										child: Text('Delete'),
										onPressed: null
									)
								]
							),
							...oldThreadRows.map((entry) {
								return TableRow(
									children: [
										Text('Over ${entry.item1} days old', textAlign: TextAlign.left),
										Text(entry.item2.length.toString(), textAlign: TextAlign.right),
										CupertinoButton(
											padding: EdgeInsets.zero,
											child: const Text('Delete'),
											onPressed: entry.item2.isEmpty ? null : () => confirmDelete(entry.item2)
										)
									]
								);
							})
						]
					),
				);
			}
		);
	}
}

class SettingsFilterPanel extends StatefulWidget {
	final String initialConfiguration;
	const SettingsFilterPanel({
		required this.initialConfiguration,
		Key? key
	}) : super(key: key);
	@override
	createState() => _SettingsFilterPanelState();
}

class _SettingsFilterPanelState extends State<SettingsFilterPanel> {
	final regexController = TextEditingController();

	@override
	void initState() {
		super.initState();
		regexController.text = widget.initialConfiguration;
	}

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<EffectiveSettings>();
		return Column(
			mainAxisSize: MainAxisSize.min,
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				Padding(
					padding: const EdgeInsets.all(16),
					child: Wrap(
						crossAxisAlignment: WrapCrossAlignment.center,
						alignment: WrapAlignment.start,
						spacing: 16,
						runSpacing: 16,
						children: [
							const Text('RegEx filters'),
							CupertinoButton(
								minSize: 0,
								padding: EdgeInsets.zero,
								child: const Icon(Icons.help),
								onPressed: () {
									showCupertinoModalPopup(
										context: context,
										builder: (context) => CupertinoActionSheet(
											message: Text.rich(
												buildFakeMarkdown(context,
													'One regular expression per line, lines starting with # will be ignored\n'
													'Example: `/sneed/` will hide any thread or post containing "sneed"\n'
													'Example: `/bane/;boards:tv;thread` will hide any thread containing "sneed" in the OP on /tv/\n'
													'Add `i` after the regex to make it case-insensitive\n'
													'Example: `/sneed/i` will match `SNEED`\n'
													'\n'
													'Qualifiers may be added after the regex:\n'
													'`;boards:<list>` Only apply on certain boards\n'
													'Example: `;board:tv,mu` will only apply the filter on /tv/ and /mu/\n'
													'`;exclude:<list>` Don\'t apply on certain boards\n'
													'`;highlight` Highlight instead of hiding matches\n'
													'`;top` Highlight and pin match to top of list instead of hiding\n'
													'`;file:only` Only apply to posts with files\n'
													'`;file:no` Only apply to posts without files\n'
													'`;thread` Only apply to threads\n'
													'`;type:<list>` Only apply regex filter to certain fields\n'
													'The list of possible fields is `[text, subject, name, filename, postID, posterID, flag]`\n'
													'The default fields that are searched are `[text, subject, name, filename]`'
												),
												textAlign: TextAlign.left,
												style: const TextStyle(
													fontSize: 16,
													height: 1.5
												)
											)
										)
									);
								}
							),
							if (settings.filterError != null) Text('${settings.filterError}', style: const TextStyle(
								color: Colors.red
							))
						]
					)
				),
				StatefulBuilder(
					builder: (context, setInnerState) {
						return CupertinoTextField(
							style: GoogleFonts.ibmPlexMono(),
							minLines: 5,
							maxLines: 5,
							controller: regexController,
							onChanged: (string) {
								settings.filterConfiguration = string;
							},
						);
					}
				)
			]
		);
	}
}
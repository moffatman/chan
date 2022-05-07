import 'dart:io';

import 'package:chan/models/attachment.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/flag.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/board.dart';
import 'package:chan/pages/licenses.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/storage.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/cupertino_page_route.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/thread_row.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tuple/tuple.dart';
import 'package:provider/provider.dart';
import 'package:extended_image_library/extended_image_library.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class _SettingsPage extends StatelessWidget {
	final String title;
	final List<Widget> children;
	const _SettingsPage({
		required this.children,
		required this.title,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return CupertinoPageScaffold(
			resizeToAvoidBottomInset: false,
			navigationBar: CupertinoNavigationBar(
				transitionBetweenRoutes: false,
				middle: Text(title)
			),
			child: SafeArea(
				child: MaybeCupertinoScrollbar(
					child: SingleChildScrollView(
						physics: const BouncingScrollPhysics(),
						child: Align(
							alignment: Alignment.center,
							child: ConstrainedBox(
								constraints: const BoxConstraints(
									maxWidth: 500
								),
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.stretch,
										children: children
									)
								)
							)
						)
					)
				)
			)
		);
	}
}

class _SettingsPageButton extends StatelessWidget {
	final String title;
	final WidgetBuilder pageBuilder;
	const _SettingsPageButton({
		required this.title,
		required this.pageBuilder,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return GestureDetector(
			behavior: HitTestBehavior.opaque,
			child: Padding(
				padding: const EdgeInsets.all(16),
				child: Row(
					children: [
						Text(title),
						const Spacer(),
						const Icon(CupertinoIcons.chevron_forward)
					]
				)
			),
			onTap: () {
				Navigator.of(context).push(FullWidthCupertinoPageRoute(
					builder: pageBuilder,
					showAnimations: context.read<EffectiveSettings>().showAnimations
				));
			}
		);
	}
}

class SettingsPage extends StatelessWidget {
	final Persistence realPersistence;
	final ImageboardSite realSite;
	const SettingsPage({
		required this.realPersistence,
		required this.realSite,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<EffectiveSettings>();
		return _SettingsPage(
			title: 'Settings',
			children: [
				const Text('Development News'),
				AnimatedSize(
					duration: const Duration(milliseconds: 250),
					curve: Curves.ease,
					alignment: Alignment.topCenter,
					child: FutureBuilder<List<Thread>>(
						future: context.read<ImageboardSite>().getCatalog('chance'),
						initialData: context.read<ThreadWatcher>().peekLastCatalog('chance'),
						builder: (context, snapshot) {
							if (!snapshot.hasData) {
								return const SizedBox(
									height: 200,
									child: Center(
										child: CupertinoActivityIndicator()
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
								onTap: () => Navigator.push(context, FullWidthCupertinoPageRoute(
									builder: (context) => ThreadPage(
										thread: thread.identifier,
										boardSemanticId: -1,
									),
									showAnimations: context.read<EffectiveSettings>().showAnimations
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
								child: CupertinoButton.filled(
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
										),
										showAnimations: context.read<EffectiveSettings>().showAnimations
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
				const SizedBox(height: 24),
				const Text('Content Filtering'),
				const SizedBox(height: 16),
				Padding(
					padding: const EdgeInsets.only(left: 16, right: 16),
					child: Table(
						children: [
							TableRow(
								children: [
									const Text('Imageboard'),
									Text(realSite.name, textAlign: TextAlign.right)
								]
							),
								...{
								'Images': settings.contentSettings.images,
								'NSFW Boards': settings.contentSettings.nsfwBoards,
								'NSFW Images': settings.contentSettings.nsfwImages,
								'NSFW Text': settings.contentSettings.nsfwText
							}.entries.map((x) => TableRow(
								children: [
									Text(x.key),
									Text(x.value ? 'Allowed' : 'Blocked', textAlign: TextAlign.right)
								]
							))
						]
					)
				),
				const SizedBox(height: 16),
				Center(
					child: Wrap(
						spacing: 16,
						runSpacing: 16,
						children: [
							CupertinoButton.filled(
								padding: const EdgeInsets.all(8),
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
							CupertinoButton.filled(
								padding: const EdgeInsets.all(8),
								child: Row(
									mainAxisSize: MainAxisSize.min,
									children: const [
										Text('Edit preferences '),
										Icon(Icons.launch_rounded, size: 16)
									]
								),
								onPressed: () {
									launch(settings.contentSettingsUrl, forceSafariVC: false);
									settings.addAppResumeCallback(() async {
										await Future.delayed(const Duration(seconds: 1));
										settings.updateContentSettings();
									});
								}
							)
						]
					)
				),
				const SizedBox(height: 32),
				Divider(
					color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2)
				),
				_SettingsPageButton(
					title: 'Behavior Settings',
					pageBuilder: (context) => SettingsBehaviorPage(
						realSite: realSite,
						realPersistence: realPersistence
					)
				),
				Divider(
					color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2)
				),
				_SettingsPageButton(
					title: 'Appearance Settings',
					pageBuilder: (context) => const SettingsAppearancePage()
				),
				Divider(
					color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2)
				),
				_SettingsPageButton(
					title: 'Data Settings',
					pageBuilder: (context) => SettingsDataPage(
						realPersistence: realPersistence
					)
				),
				Divider(
					color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2)
				),
				const SizedBox(height: 16),
				Center(
					child: CupertinoButton(
						child: const Text('Licenses'),
						onPressed: () {
							Navigator.of(context).push(FullWidthCupertinoPageRoute(
								builder: (context) => const LicensesPage(),
								showAnimations: settings.showAnimations
							));
						}
					)
				),
				const SizedBox(height: 16),
			],
		);
	}
}

class SettingsBehaviorPage extends StatelessWidget {
	final ImageboardSite realSite;
	final Persistence realPersistence;
	const SettingsBehaviorPage({
		required this.realSite,
		required this.realPersistence,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<EffectiveSettings>();
		return _SettingsPage(
			title: 'Behavior Settings',
			children: [
				SettingsFilterPanel(
					initialConfiguration: settings.filterConfiguration,
				),
				const SizedBox(height: 16),
				const Text('Image filter'),
				Padding(
					padding: const EdgeInsets.all(16),
					child: Row(
						children: [
							Text('Ignoring ${describeCount(realPersistence.browserState.hiddenImageMD5s.length, 'image')}'),
							const Spacer(),
							CupertinoButton.filled(
								padding: const EdgeInsets.all(16),
								onPressed: () async {
									final md5sBefore = realPersistence.browserState.hiddenImageMD5s;
									await Navigator.of(context).push(FullWidthCupertinoPageRoute(
										showAnimations: settings.showAnimations,
										builder: (context) => SettingsImageFilterPage(
											browserState: realPersistence.browserState
										)
									));
									if (!setEquals(md5sBefore, realPersistence.browserState.hiddenImageMD5s)) {
										realPersistence.didUpdateBrowserState();
									}
								},
								child: const Text('Configure')
							)
						]
					)
				),
				if (realSite.getLoginSystemName() != null) ...[
					Text(realSite.getLoginSystemName()!),
					const SizedBox(height: 16),
					SettingsLoginPanel(
						site: realSite
					),
					const SizedBox(height: 32)
				],
				const Text('Automatically load attachments'),
				const SizedBox(height: 16),
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
				const SizedBox(height: 32),
				const Text('Hide old stickied threads'),
				const SizedBox(height: 16),
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
				const SizedBox(height: 32),
				const Text('Use new captcha interface'),
				const SizedBox(height: 16),
				CupertinoSegmentedControl<bool>(
					children: const {
						false: Text('No'),
						true: Text('Yes')
					},
					groupValue: settings.useNewCaptchaForm,
					onValueChanged: (newValue) {
						settings.useNewCaptchaForm = newValue;
					}
				),
				const SizedBox(height: 32)
			]
		);
	}
}

class SettingsImageFilterPage extends StatefulWidget {
	final PersistentBrowserState browserState;
	const SettingsImageFilterPage({
		required this.browserState,
		Key? key
	}) : super(key: key);

	@override
	createState() => _SettingsImageFilterPageState();
}

class _SettingsImageFilterPageState extends State<SettingsImageFilterPage> {
	late final TextEditingController controller;

	@override
	void initState() {
		super.initState();
		controller = TextEditingController(text: widget.browserState.hiddenImageMD5s.join('\n'));
	}

	@override
	Widget build(BuildContext context) {
		return _SettingsPage(
			title: 'Image Filter Settings',
			children: [
				const Text('One image MD5 per line'),
				const SizedBox(height: 8),
				CupertinoTextField(
					controller: controller,
					onChanged: (s) {
						widget.browserState.setHiddenImageMD5s(s.split('\n').where((x) => x.isNotEmpty));
					},
					minLines: 10,
					maxLines: 10
				)
			]
		);
	}
}

class SettingsAppearancePage extends StatelessWidget {
	const SettingsAppearancePage({
		Key? key
	}) : super(key: key);

	Thread _makeFakeThread() {
		final flag = ImageboardFlag(
			name: 'Canada',
			imageUrl: 'https://callum.crabdance.com/ca.gif',
			imageWidth: 16,
			imageHeight: 11
		);
		final attachment = Attachment(
			type: AttachmentType.image,
			board: 'tv',
			id: 99999,
			ext: '.png',
			width: 800,
			height: 800,
			filename: 'example.png',
			md5: '',
			sizeInBytes: 150634,
			url: Uri.parse('https://picsum.photos/800'),
			thumbnailUrl: Uri.parse('https://picsum.photos/200')
		);
		return Thread(
			attachment: attachment,
			board: 'tv',
			replyCount: 300,
			imageCount: 30,
			id: 99999,
			time: DateTime.now().subtract(const Duration(minutes: 5)),
			title: 'Example thread',
			isSticky: false,
			flag: flag,
			posts_: [
				Post(
					board: 'tv',
					text: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. ',
					name: 'Anonymous',
					trip: '!asdf',
					time: DateTime.now().subtract(const Duration(minutes: 5)),
					threadId: 99999,
					id: 99999,
					passSinceYear: 2020,
					flag: flag,
					attachment: attachment,
					spanFormat: PostSpanFormat.chan4
				)
			]
		);
	}

	Widget _buildFakeThreadRow({bool contentFocus = true}) {
		return ThreadRow(
			contentFocus: contentFocus,
			isSelected: false,
			thread: _makeFakeThread()
		);
	}

	Widget _buildFakePostRow() {
		final thread = _makeFakeThread();
		return ChangeNotifierProvider<PostSpanZoneData>(
			create: (context) => PostSpanRootZoneData(
				site: context.read<ImageboardSite>(),
				thread: thread,
				semanticRootIds: [-9]
			),
			child: PostRow(
				isSelected: false,
				post: thread.posts.first
			)
		);
	}

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<EffectiveSettings>();
		final firstPanePercent = (settings.twoPaneSplit / twoPaneSplitDenominator) * 100;
		return _SettingsPage(
			title: 'Appearance Settings',
			children: [
				const SizedBox(height: 16),
				Row(
					children: [
						const Text('Interface scale'),
						const Spacer(),
						CupertinoButton(
							child: const Icon(CupertinoIcons.minus),
							onPressed: settings.interfaceScale <= 0.5 ? null : () {
								settings.interfaceScale -= 0.05;
							}
						),
						Text('${(settings.interfaceScale * 100).round()}%'),
						CupertinoButton(
							child: const Icon(CupertinoIcons.plus),
							onPressed: settings.interfaceScale >= 2.0 ? null : () {
								settings.interfaceScale += 0.05;
							}
						),
						const SizedBox(width: 16)
					]
				),
				const SizedBox(height: 16),
				const Text('Interface Style'),
				const SizedBox(height: 16),
				CupertinoSegmentedControl<TristateSystemSetting>(
					children: const {
						TristateSystemSetting.a: Text('Touchscreen'),
						TristateSystemSetting.system: Text('Automatic'),
						TristateSystemSetting.b: Text('Mouse')
					},
					groupValue: settings.supportMouseSetting,
					onValueChanged: (newValue) {
						settings.supportMouseSetting = newValue;
					}
				),
				const SizedBox(height: 32),
				const Text('Animations'),
				const SizedBox(height: 16),
				CupertinoSegmentedControl<bool>(
					children: const {
						false: Text('Disabled'),
						true: Text('Enabled'),
					},
					groupValue: settings.showAnimations,
					onValueChanged: (newValue) {
						settings.showAnimations = newValue;
					}
				),
				const SizedBox(height: 32),
				const Text('Active Theme'),
				const SizedBox(height: 16),
				CupertinoSegmentedControl<TristateSystemSetting>(
					children: const {
						TristateSystemSetting.a: Text('Light'),
						TristateSystemSetting.system: Text('Follow System'),
						TristateSystemSetting.b: Text('Dark')
					},
					groupValue: settings.themeSetting,
					onValueChanged: (newValue) {
						settings.themeSetting = newValue;
					}
				),
				for (final theme in [
					Tuple3('Light Theme Colors', settings.lightTheme, defaultLightTheme),
					Tuple3('Dark Theme Colors', settings.darkTheme, defaultDarkTheme)
				]) ... [
					Padding(
						padding: const EdgeInsets.only(top: 16, bottom: 16),
						child: Text(theme.item1)
					),
					Container(
						margin: const EdgeInsets.only(left: 16, right: 16),
						decoration: BoxDecoration(
							color: theme.item2.barColor,
							borderRadius: const BorderRadius.all(Radius.circular(8))
						),
						child: SingleChildScrollView(
							scrollDirection: Axis.horizontal,
							child: Row(
								children: <Tuple4<String, Color, ValueChanged<Color>, Color>>[
									Tuple4('Primary', theme.item2.primaryColor, (c) => theme.item2.primaryColor = c, theme.item3.primaryColor),
									Tuple4('Secondary', theme.item2.secondaryColor, (c) => theme.item2.secondaryColor = c, theme.item3.secondaryColor),
									Tuple4('Bar', theme.item2.barColor, (c) => theme.item2.barColor = c, theme.item3.barColor),
									Tuple4('Background', theme.item2.backgroundColor, (c) => theme.item2.backgroundColor = c, theme.item3.backgroundColor),
									Tuple4('Quote', theme.item2.quoteColor, (c) => theme.item2.quoteColor = c, theme.item3.quoteColor)
								].map((color) => Column(
									mainAxisSize: MainAxisSize.min,
									children: [
										const SizedBox(height: 16),
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
																	displayColor: CupertinoTheme.of(context).primaryColor,
																),
																canvasColor: CupertinoTheme.of(context).scaffoldBackgroundColor
															),
															child: Padding(
																padding: MediaQuery.of(context).viewInsets,
																child: Material(
																	color: Colors.transparent,
																	child: ColorPicker(
																		pickerColor: color.item2,
																		onColorChanged: color.item3,
																		enableAlpha: false,
																		portraitOnly: true,
																		displayThumbColor: true,
																		hexInputBar: true
																	)
																)
															)
														)
													)
												);
												settings.handleThemesAltered();
											}
										),
										Padding(
											padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 16),
											child: CupertinoButton(
												padding: const EdgeInsets.all(8),
												color: theme.item2.primaryColor,
												child: Text('Reset', style: TextStyle(color: theme.item2.backgroundColor)),
												onPressed: () {
													color.item3(color.item4);
													settings.handleThemesAltered();
												}
											)
										),
									]
								)).toList()
							)
						)
					)
				],
				const SizedBox(height: 16),
				Text('Thumbnail size: ${settings.thumbnailSize.round()}x${settings.thumbnailSize.round()}'),
				Padding(
					padding: const EdgeInsets.all(16),
					child: CupertinoSlider(
						min: 50,
						max: 200,
						divisions: 30,
						value: settings.thumbnailSize,
						onChanged: (newValue) {
							settings.thumbnailSize = newValue;
						}
					)
				),
				const Text('Thumbnail location'),
				const SizedBox(height: 16),
				CupertinoSegmentedControl<bool>(
					children: const {
						false: Text('Left'),
						true: Text('Right')
					},
					groupValue: settings.imagesOnRight,
					onValueChanged: (newValue) {
						settings.imagesOnRight = newValue;
					}
				),
				const SizedBox(height: 32),
				const Text('Blur image thumbnails'),
				const SizedBox(height: 16),
				CupertinoSegmentedControl<bool>(
					children: const {
						false: Text('No'),
						true: Text('Yes')
					},
					groupValue: settings.blurThumbnails,
					onValueChanged: (newValue) {
						settings.blurThumbnails = newValue;
					}
				),
				const SizedBox(height: 32),
				Center(
					child: CupertinoButton.filled(
						child: const Text('Edit post details'),
						onPressed: () async {
							await showCupertinoModalPopup(
								context: context,
								builder: (_context) => StatefulBuilder(
									builder: (context, setDialogState) => CupertinoActionSheet(
										title: const Text('Edit post details'),
										actions: [
											CupertinoButton(
												child: const Text('Close'),
												onPressed: () => Navigator.pop(_context)
											)
										],
										message: DefaultTextStyle(
											style: DefaultTextStyle.of(context).style,
											child: Column(
												children: [
													SizedBox(
														 height: 125,
														 child: IgnorePointer(
															 child: _buildFakePostRow()
														 )
														),
													Row(
														children: [
															const Text('Show name'),
															const Spacer(),
															CupertinoSwitch(
																value: settings.showNameOnPosts,
																onChanged: (d) => settings.showNameOnPosts = d
															)
														]
													),
													Row(
														children: [
															const Text('Show trip'),
															const Spacer(),
															CupertinoSwitch(
																value: settings.showTripOnPosts,
																onChanged: (d) => settings.showTripOnPosts = d
															)
														]
													),
													Row(
														children: [
															const Text('Show filename'),
															const Spacer(),
															CupertinoSwitch(
																value: settings.showFilenameOnPosts,
																onChanged: (d) => settings.showFilenameOnPosts = d
															)
														]
													),
													Row(
														children: [
															const Text('Show filesize'),
															const Spacer(),
															CupertinoSwitch(
																value: settings.showFilesizeOnPosts,
																onChanged: (d) => settings.showFilesizeOnPosts = d
															)
														]
													),
													Row(
														children: [
															const Text('Show file dimensions'),
															const Spacer(),
															CupertinoSwitch(
																value: settings.showFileDimensionsOnPosts,
																onChanged: (d) => settings.showFileDimensionsOnPosts = d
															)
														]
													),
													Row(
														children: [
															const Text('Show pass'),
															const Spacer(),
															CupertinoSwitch(
																value: settings.showPassOnPosts,
																onChanged: (d) => settings.showPassOnPosts = d
															)
														]
													),
													Row(
														children: [
															const Text('Show flag'),
															const Spacer(),
															CupertinoSwitch(
																value: settings.showFlagOnPosts,
																onChanged: (d) => settings.showFlagOnPosts = d
															)
														]
													),
													Row(
														children: [
															const Text('Show country name'),
															const Spacer(),
															CupertinoSwitch(
																value: settings.showCountryNameOnPosts,
																onChanged: (d) => settings.showCountryNameOnPosts = d
															)
														]
													),
													Row(
														children: [
															const Text('Show exact time'),
															const Spacer(),
															CupertinoSwitch(
																value: settings.showAbsoluteTimeOnPosts,
																onChanged: (d) => settings.showAbsoluteTimeOnPosts = d
															)
														]
													),
													Row(
														children: [
															const Text('Show relative time'),
															const Spacer(),
															CupertinoSwitch(
																value: settings.showRelativeTimeOnPosts,
																onChanged: (d) => settings.showRelativeTimeOnPosts = d
															)
														]
													)
												]
											)
										)
									)
								)
							);
						}
					)
				),
				const SizedBox(height: 32),
				const Text('Show reply counts in gallery'),
				const SizedBox(height: 16),
				CupertinoSegmentedControl<bool>(
					children: const {
						false: Text('No'),
						true: Text('Yes')
					},
					groupValue: settings.showReplyCountsInGallery,
					onValueChanged: (newValue) {
						settings.showReplyCountsInGallery = newValue;
					}
				),
				const SizedBox(height: 32),
				const Text('Catalog Layout'),
				const SizedBox(height: 16),
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
				const SizedBox(height: 16),
				Center(
					child: CupertinoButton.filled(
						child: const Text('Edit catalog grid item size'),
						onPressed: () async {
							Size size = Size(settings.catalogGridWidth, settings.catalogGridHeight);
							await showCupertinoModalPopup(
								context: context,
								builder: (_context) => StatefulBuilder(
									builder: (context, setDialogState) => CupertinoActionSheet(
										title: const Text('Resize catalog grid item'),
										actions: [
											CupertinoButton(
												child: const Text('Close'),
												onPressed: () => Navigator.pop(_context)
											)
										],
										message: DefaultTextStyle(
											style: DefaultTextStyle.of(context).style,
											child: Column(
												children: [
													FittedBox(
														fit: BoxFit.contain,
														child: Column(
															mainAxisSize: MainAxisSize.min,
															children: [
																Row(
																	mainAxisAlignment: MainAxisAlignment.spaceBetween,
																	children: [
																		Text('Width: ${size.width.round()}px'),
																		CupertinoSlider(
																			value: size.width,
																			min: 100,
																			max: 600,
																			onChanged: (d) {
																				setDialogState(() {
																					size = Size(d, size.height);
																				});
																			}
																		),
																		CupertinoButton(
																			padding: EdgeInsets.zero,
																			child: const Icon(CupertinoIcons.minus),
																			onPressed: size.width <= 100 ? null : () {
																				setDialogState(() {
																					size = Size(size.width - 1, size.height);
																				});
																			}
																		),
																		CupertinoButton(
																			padding: EdgeInsets.zero,
																			child: const Icon(CupertinoIcons.plus),
																			onPressed: size.width >= 600 ? null : () {
																				setDialogState(() {
																					size = Size(size.width + 1, size.height);
																				});
																			}
																		)
																	]
																),
																Row(
																	mainAxisAlignment: MainAxisAlignment.spaceBetween,
																	children: [
																		Text('Height: ${size.height.round()}px'),
																		CupertinoSlider(
																			value: size.height,
																			min: 100,
																			max: 600,
																			onChanged: (d) {
																				setDialogState(() {
																					size = Size(size.width, d);
																				});
																			}
																		),
																		CupertinoButton(
																			padding: EdgeInsets.zero,
																			child: const Icon(CupertinoIcons.minus),
																			onPressed: size.height <= 100 ? null : () {
																				setDialogState(() {
																					size = Size(size.width, size.height - 1);
																				});
																			}
																		),
																		CupertinoButton(
																			padding: EdgeInsets.zero,
																			child: const Icon(CupertinoIcons.plus),
																			onPressed: size.height >= 600 ? null : () {
																				setDialogState(() {
																					size = Size(size.width, size.height + 1);
																				});
																			}
																		)
																	]
																)
															]
														)
													),
													SizedBox(
														width: 600,
														height: 600,
														child: Align(
															alignment: Alignment.topLeft,
															child: SizedBox.fromSize(
																size: size,
																child: ThreadRow(
																	contentFocus: true,
																	isSelected: false,
																	thread: _makeFakeThread()
																)
															)
														)
													)
												]
											)
										)
									)
								)
							);
							settings.catalogGridHeight = size.height;
							settings.catalogGridWidth = size.width;
						}
					)
				),
				const SizedBox(height: 16),
				Center(
					child: CupertinoButton.filled(
						child: const Text('Edit catalog item details'),
						onPressed: () async {
							await showCupertinoModalPopup(
								context: context,
								builder: (_context) => StatefulBuilder(
									builder: (context, setDialogState) => CupertinoActionSheet(
										title: const Text('Edit catalog item details'),
										actions: [
											CupertinoButton(
												child: const Text('Close'),
												onPressed: () => Navigator.pop(_context)
											)
										],
										message: DefaultTextStyle(
											style: DefaultTextStyle.of(context).style,
											child: Column(
												children: [
													SizedBox(
														height: 100,
														child: _buildFakeThreadRow(contentFocus: false)
													),
													const SizedBox(height: 16),
													Align(
														alignment: Alignment.topLeft,
														child: SizedBox.fromSize(
															size: Size(settings.catalogGridWidth, settings.catalogGridHeight),
															child: _buildFakeThreadRow()
														)
													),
													Row(
														children: [
															const Text('Show image count'),
															const Spacer(),
															CupertinoSwitch(
																value: settings.showImageCountInCatalog,
																onChanged: (d) => settings.showImageCountInCatalog = d
															)
														]
													),
													Row(
														children: [
															const Text('Show clock icon'),
															const Spacer(),
															CupertinoSwitch(
																value: settings.showClockIconInCatalog,
																onChanged: (d) => settings.showClockIconInCatalog = d
															)
														]
													),
													Row(
														children: [
															const Text('Show name'),
															const Spacer(),
															CupertinoSwitch(
																value: settings.showNameInCatalog,
																onChanged: (d) => settings.showNameInCatalog = d
															)
														]
													),
													Row(
														children: [
															const Text('Show exact time'),
															const Spacer(),
															CupertinoSwitch(
																value: settings.showTimeInCatalogHeader,
																onChanged: (d) => settings.showTimeInCatalogHeader = d
															)
														]
													),
													Row(
														children: [
															const Text('Show relative time'),
															const Spacer(),
															CupertinoSwitch(
																value: settings.showTimeInCatalogStats,
																onChanged: (d) => settings.showTimeInCatalogStats = d
															)
														]
													),
													Row(
														children: [
															const Text('Show ID'),
															const Spacer(),
															CupertinoSwitch(
																value: settings.showIdInCatalogHeader,
																onChanged: (d) => settings.showIdInCatalogHeader = d
															)
														]
													),
													Row(
														children: [
															const Text('Show flag'),
															const Spacer(),
															CupertinoSwitch(
																value: settings.showFlagInCatalogHeader,
																onChanged: (d) => settings.showFlagInCatalogHeader = d
															)
														]
													)
												]
											)
										)
									)
								)
							);
						}
					)
				),
				const SizedBox(height: 32),
				Row(
					children: [
						Text('Two-pane breakpoint: ${settings.twoPaneBreakpoint.round()} pixels'),
						const SizedBox(width: 8),
						CupertinoButton(
							minSize: 0,
							padding: EdgeInsets.zero,
							child: const Icon(CupertinoIcons.question_circle),
							onPressed: () {
								showCupertinoDialog<bool>(
									context: context,
									barrierDismissible: true,
									builder: (_context) => CupertinoAlertDialog(
										content: Text('When the screen is at least ${settings.twoPaneBreakpoint.round()} pixels wide, two columns will be used.\nThe board catalog will be on the left and the current thread will be on the right.'),
										actions: [
											CupertinoDialogAction(
												child: const Text('OK'),
												onPressed: () {
													Navigator.of(_context).pop();
												}
											)
										]
									)
								);
							}
						)
					]
				),
				Padding(
					padding: const EdgeInsets.all(16),
					child: CupertinoSlider(
						min: 50,
						max: 3000,
						divisions: 59,
						value: settings.twoPaneBreakpoint,
						onChanged: (newValue) {
							settings.twoPaneBreakpoint = newValue;
						}
					)
				),
				const SizedBox(height: 16),
				Text('Two-pane split: ${firstPanePercent.toStringAsFixed(0)}% catalog, ${(100 - firstPanePercent).toStringAsFixed(0)}% thread'),
				Padding(
					padding: const EdgeInsets.all(16),
					child: CupertinoSlider(
						min: 1,
						max: (twoPaneSplitDenominator - 1).toDouble(),
						divisions: twoPaneSplitDenominator - 1,
						value: settings.twoPaneSplit.toDouble(),
						onChanged: (newValue) {
							settings.twoPaneSplit = newValue.toInt();
						}
					)
				),
				const SizedBox(height: 16),
				const Text('Show scrollbars'),
				const SizedBox(height: 16),
				CupertinoSegmentedControl<bool>(
					children: const {
						false: Text('No'),
						true: Text('Yes')
					},
					groupValue: settings.showScrollbars,
					onValueChanged: (newValue) {
						settings.showScrollbars = newValue;
					}
				),
				const SizedBox(height: 16)
			]
		);
	}
}

class SettingsDataPage extends StatelessWidget {
	final Persistence realPersistence;
	const SettingsDataPage({
		required this.realPersistence,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<EffectiveSettings>();
		return _SettingsPage(
			title: 'Data Settings',
			children: [
				if (Platform.isAndroid) ...[
					const SizedBox(height: 16),
					CupertinoButton(
						child: Text((settings.androidGallerySavePath == null ? 'Set' : 'Change') + ' media save directory'),
						onPressed: () async {
							settings.androidGallerySavePath = await pickDirectory();
						}
					)
				],
				const SizedBox(height: 16),
				Row(
					children: [
						const Text('Contribute captcha data'),
						const SizedBox(width: 8),
						CupertinoButton(
							minSize: 0,
							padding: EdgeInsets.zero,
							child: const Icon(CupertinoIcons.question_circle),
							onPressed: () {
								showCupertinoDialog<bool>(
									context: context,
									barrierDismissible: true,
									builder: (_context) => CupertinoAlertDialog(
										content: const Text('Send the captcha images you solve to a database to improve the automated solver. No other information about your posts will be collected.'),
										actions: [
											CupertinoDialogAction(
												child: const Text('OK'),
												onPressed: () {
													Navigator.of(_context).pop();
												}
											)
										]
									)
								);
							}
						)
					]
				),
				const SizedBox(height: 16),
				CupertinoSegmentedControl<bool>(
					children: const {
						false: Text('No'),
						true: Text('Yes')
					},
					groupValue: settings.contributeCaptchas,
					onValueChanged: (setting) {
						settings.contributeCaptchas = setting;
					}
				),
				const SizedBox(height: 16),
				const Text('Cached media'),
				const SettingsCachePanel(),
				const SizedBox(height: 16),
				const Text('Cached threads and history'),
				SettingsThreadsPanel(
					persistence: realPersistence
				),
				const SizedBox(height: 16),
				Center(
					child: CupertinoButton.filled(
						child: const Text('Clear API cookies'),
						onPressed: () {
							Persistence.cookies.deleteAll();
						}
					)
				),
				const SizedBox(height: 16),
			]
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
					size += subentry.statSync().size;
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
					if (folderSizes == null) const Text('Calculating...')
					else if (folderSizes?.isEmpty ?? true) const Text('No cached media'),
					Table(
						columnWidths: const {
							0: FlexColumnWidth(),
							1: IntrinsicColumnWidth()
						},
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
						mainAxisAlignment: MainAxisAlignment.spaceBetween,
						children: [
							CupertinoButton.filled(
								padding: const EdgeInsets.all(16),
								child: const Text('Recalculate'),
								onPressed: _readFilesystemInfo
							),
							CupertinoButton.filled(
								padding: const EdgeInsets.all(16),
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
	final Persistence persistence;
	const SettingsThreadsPanel({
		required this.persistence,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return ValueListenableBuilder(
			valueListenable: persistence.threadStateBox.listenable(),
			builder: (context, Box<PersistentThreadState> threadStateBox, child) {
				final oldThreadRows = [0, 7, 14, 30, 60, 90, 180].map((days) {
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
							content: Text('${describeCount(toDelete.length, 'thread')} will be deleted'),
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
						columnWidths: const {
							0: FlexColumnWidth(2)
						},
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
	final regexFocusNode = FocusNode();

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
				const SizedBox(height: 16),
				Wrap(
					crossAxisAlignment: WrapCrossAlignment.center,
					alignment: WrapAlignment.start,
					spacing: 16,
					runSpacing: 16,
					children: [
						const Text('RegEx filters'),
						CupertinoButton(
							minSize: 0,
							padding: EdgeInsets.zero,
							child: const Icon(CupertinoIcons.question_circle),
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
												'`;save` Automatically save matching threads\n'
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
						AnimatedBuilder(
							animation: regexFocusNode,
							builder: (context, child) => regexFocusNode.hasFocus ? child! : const SizedBox(),
							child: CupertinoButton(
								padding: EdgeInsets.zero,
								minSize: 0,
								child: const Text('Done'),
								onPressed: () {
									settings.filterConfiguration = regexController.text;
									regexFocusNode.unfocus();
								}
							)
						),
						if (settings.filterError != null) Text('${settings.filterError}', style: const TextStyle(
							color: Colors.red
						))
					]
				),
				const SizedBox(height: 16),
				Padding(
					padding: const EdgeInsets.only(left: 16, right: 16),
					child: StatefulBuilder(
						builder: (context, setInnerState) {
							return CupertinoTextField(
								style: GoogleFonts.ibmPlexMono(),
								minLines: 5,
								maxLines: 5,
								focusNode: regexFocusNode,
								controller: regexController
							);
						}
					)
				),
				const SizedBox(height: 16),
				Row(
					mainAxisAlignment: MainAxisAlignment.end,
					children: [
						CupertinoButton.filled(
							padding: const EdgeInsets.all(16),
							minSize: 0,
							child: const Text('Test filter setup'),
							onPressed: () {
								Navigator.of(context).push(FullWidthCupertinoPageRoute(
									builder: (context) => const FilterTestPage(),
									showAnimations: settings.showAnimations
								));
							}
						),
						const SizedBox(width: 16)
					]
				)
			]
		);
	}
}

class FilterTestPage extends StatefulWidget {
	const FilterTestPage({
		Key? key
	}) : super(key: key);

	@override
	createState() => _FilterTestPageState();
}

class _FilterTestPageState extends State<FilterTestPage> implements Filterable {
	final _boardController = TextEditingController();
	final _idController = TextEditingController();
	final _textController = TextEditingController();
	final _subjectController = TextEditingController();
	final _nameController = TextEditingController();
	final _filenameController = TextEditingController();
	final _posterIdController = TextEditingController();
	final _flagController = TextEditingController();

	@override
	String get board => _boardController.text;

	@override
	int get id => -1;

	@override
	bool get hasFile => _filenameController.text.isNotEmpty;

	@override
	bool isThread = true;

	@override
	List<int> get repliedToIds => [];

	@override
	String? getFilterFieldText(String fieldName) {
		switch (fieldName) {
			case 'subject':
				return _subjectController.text;
			case 'name':
				return _nameController.text;
			case 'filename':
				return _filenameController.text;
			case 'text':
				return _textController.text;
			case 'postID':
				return _idController.text;
			case 'posterID':
				return _posterIdController.text;
			case 'flag':
				return _flagController.text;
			default:
				return null;
		}
	}

	FilterResult? result;

	void _recalculate() {
		result = makeFilter(context.read<EffectiveSettings>().filterConfiguration).filter(this);
		setState(() {});
	}

	String _filterResultType(FilterResultType? type) {
		switch (type) {
			case FilterResultType.autoSave:
				return 'Auto-saved';
			case FilterResultType.pinToTop:
				return 'Pinned to top of catalog';
			case FilterResultType.highlight:
				return 'Highlighted';
			case FilterResultType.hide:
				return 'Hidden';
			case null:
				return 'No action';
		}
	}

	@override
	Widget build(BuildContext context) {
		return _SettingsPage(
			title: 'Filter testing',
			children: [
				const Text('Fill the fields here to see how your filter setup will categorize threads and posts'),
				const SizedBox(height: 16),
				Text('Filter outcome:  ${_filterResultType(result?.type)}\nReason: ${result?.reason ?? 'No match'}'),
				const SizedBox(height: 16),
				CupertinoSegmentedControl<bool>(
					children: const {
						false: Text('Post'),
						true: Text('Thread')
					},
					groupValue: isThread,
					onValueChanged: (setting) {
						isThread = setting;
						_recalculate();
					}
				),
				const SizedBox(height: 16),
				for (final field in [
					Tuple3('Board', _boardController, null),
					Tuple3(isThread ? 'Thread no.' : 'Post no.', _idController, null),
					if (isThread) Tuple3('Subject', _subjectController, null),
					Tuple3('Name', _nameController, null),
					Tuple3('Poster ID', _posterIdController, null),
					Tuple3('Flag', _flagController, null),
					Tuple3('Filename', _filenameController, null),
					Tuple3('Text', _textController, 5)
				]) ...[
					Text(field.item1),
					Padding(
						padding: const EdgeInsets.all(16),
						child: CupertinoTextField(
							controller: field.item2,
							minLines: field.item3,
							maxLines: null,
							onChanged: (_) {
								_recalculate();
							}
						)
					)
				]
			]
		);
	}
}

class SettingsLoginPanel extends StatefulWidget {
	final ImageboardSite site;
	const SettingsLoginPanel({
		required this.site,
		Key? key
	}) : super(key: key);

	@override
	createState() => _SettingsLoginPanelState();
}

class _SettingsLoginPanelState extends State<SettingsLoginPanel> {
	Map<ImageboardSiteLoginField, String>? savedFields;
	bool loading = true;

	Future<void> _updateStatus() async {
		final newSavedFields = await widget.site.getSavedLoginFields();
		setState(() {
			savedFields = newSavedFields;
			loading = false;
		});
	}

	@override
	void initState() {
		super.initState();
		_updateStatus();
	}

	Future<void> _login() async {
		final fields = {
			for (final field in widget.site.getLoginFields()) field: ''
		};
		final cont = await showCupertinoDialog<bool>(
			context: context,
			builder: (context) => CupertinoAlertDialog(
				title: Text(widget.site.getLoginSystemName()! + ' Login'),
				content: ListBody(
					children: [
						const SizedBox(height: 8),
						for (final field in fields.keys) ...[
							Text(field.displayName, textAlign: TextAlign.left),
							const SizedBox(height: 8),
							CupertinoTextField(
								autofocus: field == fields.keys.first,
								onChanged: (value) {
									fields[field] = value;
								},
								keyboardType: field.inputType
							),
							const SizedBox(height: 16),
						]
					]
				),
				actions: [
					CupertinoDialogAction(
						child: const Text('Cancel'),
						onPressed: () => Navigator.pop(context)
					),
					CupertinoDialogAction(
						child: const Text('Login'),
						onPressed: () => Navigator.pop(context, true)
					)
				]
			)
		);
		if (cont == true) {
			print(fields);
			try {
				await widget.site.login(fields);
				widget.site.persistence?.browserState.loginFields.clear();
				widget.site.persistence?.browserState.loginFields.addAll({
					for (final field in fields.entries) field.key.formKey: field.value
				});
				widget.site.persistence?.didUpdateBrowserState();
			}
			catch (e) {
				alertError(context, e.toStringDio());
			}
			await _updateStatus();
		}
	}

	@override
	Widget build(BuildContext context) {
		return Column(
			mainAxisSize: MainAxisSize.min,
			children: [
				if (loading) const Center(
					child: CupertinoActivityIndicator()
				)
				else if (savedFields != null) ...[
					const Text('Credentials saved\n'),
					Wrap(
						spacing: 16,
						runSpacing: 16,
						children: [
							CupertinoButton.filled(
								child: const Text('Remove'),
								onPressed: () async {
									setState(() {
										loading = true;
									});
									try {
										await widget.site.clearLoginCookies();
										await widget.site.clearSavedLoginFields();
									}
									catch (e) {
										await alertError(context, e.toStringDio());
									}
									await _updateStatus();
								}
							)
						]
					)
				]
				else ...[
					CupertinoButton.filled(
						child: const Text('Login'),
						onPressed: () async {
							try {
								await _login();
							}
							catch (e) {
								await alertError(context, e.toStringDio());
							}
						}
					)
				],
				const SizedBox(height: 16),
				Padding(
					padding: const EdgeInsets.only(left: 16),
					child: Align(
						alignment: Alignment.topLeft,
						child: Text('Try to use ${widget.site.getLoginSystemName()} on mobile networks?')
					)
				),
				const SizedBox(height: 16),
				CupertinoSegmentedControl<bool>(
					children: const {
						false: Padding(
							padding: EdgeInsets.all(8),
							child: Text('No')
						),
						true: Padding(
							padding: EdgeInsets.all(8),
							child: Text('Yes')
						)
					},
					groupValue: context.watch<EffectiveSettings>().autoLoginOnMobileNetwork,
					onValueChanged: (setting) {
						context.read<EffectiveSettings>().autoLoginOnMobileNetwork = setting;
					}
				)
			]
		);
	}
}
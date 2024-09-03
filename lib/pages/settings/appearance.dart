import 'dart:io';
import 'dart:math' as math;

import 'package:chan/models/attachment.dart';
import 'package:chan/models/flag.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/settings/common.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/installed_fonts.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/screen_size_hacks.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/util.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/thread_row.dart';
import 'package:chan/widgets/util.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

bool _getDontSupportMouse(BuildContext context) => !context.read<MouseSettings>().supportMouse;
bool _watchDontSupportMouse(BuildContext context) => !context.select<MouseSettings, bool>((s) => s.supportMouse);
Future<void> _dummyDidMutater(BuildContext context) async {}
const _dontSupportMouse = CustomMutableSetting(
	reader: _getDontSupportMouse,
	watcher: _watchDontSupportMouse,
	didMutater: _dummyDidMutater
);

extension _UseTree on Imageboard {
	ImmutableSetting<bool> get useTree => SettingWithFallback(
		SavedSetting(
			ChainedFieldWriter(
				ChainedFieldReader(
					SavedSettingsFields.browserStateBySite,
					MapFieldWriter<String, PersistentBrowserState>(key: key)
				),
				PersistentBrowserStateFields.useTree
			)
		),
		site.useTree
	);
	ImmutableSetting<bool> get dontUseTree => MappedSetting(
		useTree,
		FieldMappers.invert,
		FieldMappers.invert
	);
}

Thread _makeFakeThread() {
	final flag = ImageboardFlag(
		name: 'Canada',
		imageUrl: 'https://boards.chance.surf/ca.gif',
		imageWidth: 16,
		imageHeight: 11
	);
	final attachment = Attachment(
		type: AttachmentType.image,
		board: 'tv',
		id: '123455',
		ext: '.png',
		width: 800,
		height: 800,
		filename: 'example.png',
		md5: '',
		sizeInBytes: 150634,
		url: 'https://picsum.photos/800/600',
		thumbnailUrl: 'https://picsum.photos/200/150',
		threadId: 123455
	);
	return Thread(
		attachments: [attachment],
		board: 'tv',
		replyCount: 300,
		imageCount: 30,
		id: 123455,
		time: DateTime.now().subtract(const Duration(minutes: 5)),
		title: 'Example thread',
		isSticky: false,
		flair: ImageboardFlag.text('Category'),
		posts_: [
			Post(
				board: 'tv',
				text: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
				name: 'Anonymous',
				trip: '!asdf',
				time: DateTime.now().subtract(const Duration(minutes: 5)),
				threadId: 123455,
				id: 123455,
				passSinceYear: 2020,
				flag: flag,
				attachments_: [attachment],
				spanFormat: PostSpanFormat.chan4,
				ipNumber: 1
			),
			Post(
				board: 'tv',
				text: '<a href="#p123455" class="quotelink">&gt;&gt;22568140</a>\nThis is the first reply to the OP.',
				name: 'User',
				trip: '!fdsa',
				time: DateTime.now().subtract(const Duration(minutes: 4)),
				threadId: 123455,
				id: 123456,
				passSinceYear: 2023,
				flag: flag,
				attachments_: [],
				spanFormat: PostSpanFormat.chan4,
				ipNumber: 2
			),
			Post(
				board: 'tv',
				text: 'This is the second reply to the OP.',
				name: 'User',
				trip: '!fdsa',
				time: DateTime.now().subtract(const Duration(minutes: 3)),
				threadId: 123455,
				id: 123457,
				passSinceYear: 2023,
				flag: flag,
				attachments_: [],
				spanFormat: PostSpanFormat.chan4,
				ipNumber: 2
			)
		]
	);
}

Widget _buildFakeThreadRow(ThreadRowStyle style) => Builder(
	builder: (context) {
		final theme = context.read<SavedTheme>();
		return HeroMode(
			enabled: false,
			child: Container(
				decoration: style.isGrid ? const BoxDecoration() : BoxDecoration(
					border: Border(
						top: BorderSide(color: theme.primaryColorWithBrightness(20)),
						bottom: BorderSide(color: theme.primaryColorWithBrightness(20))
					)
				),
				padding: style.isGrid ? EdgeInsets.zero : const EdgeInsets.symmetric(vertical: 1),
				child: ThreadRow(
					style: style,
					isSelected: false,
					thread: _makeFakeThread()
				)
			)
		);
	}
);

Widget _buildFakePostRow() {
	final thread = _makeFakeThread();
	return ChangeNotifierProvider<PostSpanZoneData>(
		create: (context) => PostSpanRootZoneData(
			imageboard: context.read<Imageboard>(),
			thread: thread,
			semanticRootIds: [-9],
			style: PostSpanZoneStyle.linear
		),
		child: PostRow(
			isSelected: false,
			post: thread.posts.first
		)
	);
}

BoxDecoration? _threadAndPostRowDecorationOf(BuildContext context) {
	final dividerColor = ChanceTheme.primaryColorOf(context);
	return Material.maybeOf(context) != null ? BoxDecoration(
		border: Border.all(color: dividerColor.withOpacity(0.5))
	) : null;
}

int _estimateGridModeColumns(double maxWidth) {
	double screenWidth = PlatformDispatcher.instance.views.first.physicalSize.width / PlatformDispatcher.instance.views.first.devicePixelRatio;
	screenWidth /= Settings.instance.interfaceScale;
	if (screenWidth > Settings.instance.twoPaneBreakpoint) {
		// Catalog is in mater pane
		screenWidth *= (Settings.instance.twoPaneSplit / twoPaneSplitDenominator);
	}
	return (screenWidth / maxWidth).ceil();
}

final appearanceSettings = [
	SteppableSettingWidget(
		description: 'Interface scale',
		icon: CupertinoIcons.zoom_in,
		min: 0.5,
		step: 0.05,
		max: 2.0,
		formatter: (v) => '${(v * 100).round()}%',
		setting: Settings.interfaceScaleSetting
	),
	SteppableSettingWidget(
		description: 'Font scale',
		icon: CupertinoIcons.textformat_size,
		min: 0.5,
		step: 0.05,
		max: 2.0,
		formatter: (v) => '${(v * 100).round()}%',
		setting: Settings.textScaleSetting
	),
	const SegmentedSettingWidget(
		description: 'Interaction Mode',
		icon: CupertinoIcons.macwindow,
		children: {
			TristateSystemSetting.a: (CupertinoIcons.hand_draw, 'Touch'),
			TristateSystemSetting.system: (null, 'Automatic'),
			TristateSystemSetting.b: (Icons.mouse, 'Mouse')
		},
		setting: Settings.supportMouseSetting
	),
	SettingHiding(
		hidden: _dontSupportMouse,
		setting: SteppableSettingWidget(
			description: 'Mouse hover popup delay',
			icon: Icons.mouse,
			min: 0,
			max: 1000,
			step: 50,
			formatter: (v) => '$v ms',
			setting: Settings.hoverPopupDelayMillisecondsSetting
		)
	),
	const SettingHiding(
		hidden: _dontSupportMouse,
		setting: SegmentedSettingWidget(
			description: 'Quotelink mouse click behavior',
			icon: CupertinoIcons.chevron_right_2,
			children: {
				MouseModeQuoteLinkBehavior.expandInline: (null, 'Expand inline'),
				MouseModeQuoteLinkBehavior.scrollToPost: (null, 'Scroll to post'),
				MouseModeQuoteLinkBehavior.popupPostsPage: (null, 'Popup')
			},
			setting: Settings.mouseModeQuoteLinkBehaviorSetting
		)
	),
	SegmentedSettingWidget(
		description: 'Interface Style',
		icon: CupertinoIcons.macwindow,
		children: const {
			false: (Icons.apple, 'iOS'),
			true: (Icons.android, 'Android')
		},
		setting: Settings.materialStyleSetting
	),
	SegmentedSettingWidget(
		description: 'Navigation Style',
		icon: CupertinoIcons.macwindow,
		children: const {
			false: (CupertinoIcons.squares_below_rectangle, 'Bottom bar'),
			true: (CupertinoIcons.sidebar_left, 'Side drawer')
		},
		setting: Settings.androidDrawerSetting
	),
	SwitchSettingWidget(
		disabled: MappedSetting(
			Settings.androidDrawerSetting,
			FieldMappers.invert,
			FieldMappers.invert
		),
		description: 'Drawer permanently visible',
		icon: CupertinoIcons.sidebar_left,
		helpText: 'The drawer will always be on the left side if there is enough space. On devices with a hinge, the drawer will size itself to fill the left screen.',
		setting: Settings.persistentDrawerSetting
	),
	const SegmentedSettingWidget(
		description: 'Page Style',
		icon: CupertinoIcons.doc,
		helpText: 'The animations and gestural behaviour when new interface pages open on top of others',
		children: {
			false: (Icons.apple, 'iOS'),
			true: (Icons.android, 'Android')
		},
		setting: Settings.materialRoutesSetting
	),
	const SwitchSettingWidget(
		description: 'Animations',
		icon: CupertinoIcons.wand_rays,
		setting: Settings.showAnimationsSetting
	),
	ImmutableButtonSettingWidget(
		description: 'Font',
		icon: CupertinoIcons.textformat_alt,
		setting: Settings.fontFamilySetting,
		injectButton: (fontLoadingError == null) ? null : (context, fontFamily, setFontFamily) => AdaptiveIconButton(
			icon: const Icon(CupertinoIcons.exclamationmark_circle, color: Colors.red),
			onPressed: () {
				showAdaptiveDialog<bool>(
					context: context,
					barrierDismissible: true,
					builder: (context) => AdaptiveAlertDialog(
						content: Text('Font loading failed:\n\n$fontLoadingError'),
						actions: [
							AdaptiveDialogAction(
								child: const Text('OK'),
								onPressed: () {
									Navigator.of(context).pop();
								}
							)
						]
					)
				);
			}
		),
		builder: (family) => Text(family ?? 'Default'),
		onPressed: (context, family, setFamily) async {
			final availableFonts = await showAdaptiveDialog<List<String>>(
				barrierDismissible: true,
				context: context,
				builder: (context) => AdaptiveAlertDialog(
					title: const Text('Choose a font source', textAlign: TextAlign.center),
					actions: [
						AdaptiveDialogAction(
							child: const Text('System Fonts'),
							onPressed: () async {
								try {
									final fonts = await getInstalledFontFamilies();
									if (context.mounted) {
										Navigator.pop(context, fonts);
									}
								}
								catch (e, st) {
									if (context.mounted) {
										alertError(context, e, st);
									}
								}
							}
						),
						AdaptiveDialogAction(
							child: const Text('Google Fonts'),
							onPressed: () => Navigator.pop(context, allowedGoogleFonts.keys.toList())
						),
						AdaptiveDialogAction(
							child: const Text('Pick font file...'),
							onPressed: () async {
								try {
									final pickerResult = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['ttf', 'otf']);
									final path = pickerResult?.files.tryFirst?.path;
									if (path == null) {
										return;
									}
									final basename = path.split('/').last;
									final ttfFolder = await Directory('${Persistence.documentsDirectory.path}/${Persistence.fontsDir}').create();
									await File(path).copy('${ttfFolder.path}/$basename');
									if (context.mounted) {
										Navigator.pop(context, [basename]);
									}
								}
								catch (e, st) {
									Future.error(e, st);
									if (context.mounted) {
										alertError(context, e, st);
									}
								}
							}
						),
						AdaptiveDialogAction(
							child: const Text('Reset to default'),
							onPressed: () => Navigator.pop(context, <String>[])
						),
						AdaptiveDialogAction(
							child: const Text('Cancel'),
							onPressed: () => Navigator.pop(context)
						)
					]
				)
			);
			if (!context.mounted || availableFonts == null) {
				return;
			}
			if (availableFonts.isEmpty) {
				if (family != null && (family.endsWith('.ttf') || family.endsWith('.otf'))) {
					// Cleanup previous picked font
					try {
						await File('${Persistence.documentsDirectory.path}/${Persistence.fontsDir}/$family').delete();
					}
					catch (e, st) {
						Future.error(e, st);
						if (context.mounted) {
							alertError(context, e, st);
						}
					}
				}
				fontLoadingError = null;
				setFamily(null);
				return;
			}
			final selectedFont = availableFonts.trySingle ?? await showAdaptiveDialog<String>(
				barrierDismissible: true,
				context: context,
				builder: (context) => AdaptiveAlertDialog(
					title: const Text('Choose a font', textAlign: TextAlign.center),
					content: SizedBox(
						width: 200,
						height: 350,
						child: CupertinoScrollbar(
							child: ListView.separated(
								itemCount: availableFonts.length,
								separatorBuilder: (context, i) => const ChanceDivider(),
								itemBuilder: (context, i) => AdaptiveDialogAction(
									onPressed: () => Navigator.pop(context, availableFonts[i]),
									child: Text(availableFonts[i], style: allowedGoogleFonts[availableFonts[i]]?.call() ?? TextStyle(
										fontFamily: availableFonts[i]
									))
								)
							)
						)
					),
					actions: [
						AdaptiveDialogAction(
							child: const Text('Close'),
							onPressed: () => Navigator.pop(context)
						)
					]
				)
			);
			if (selectedFont != null) {
				final oldFont = family;
				setFamily(selectedFont);
				if (oldFont != selectedFont && oldFont != null && (oldFont.endsWith('.ttf') || oldFont.endsWith('.otf'))) {
					// Cleanup previous picked font
					try {
						await File('${Persistence.documentsDirectory.path}/${Persistence.fontsDir}/$oldFont').delete();
					}
					catch (e, st) {
						Future.error(e, st);
						if (context.mounted) {
							alertError(context, e, st);
						}
					}
				}
				if (selectedFont.endsWith('.ttf') || selectedFont.endsWith('.otf')) {
					await initializeFonts();
				}
				else {
					fontLoadingError = null;
				}
			}
		}
	),
	const SegmentedSettingWidget(
		description: 'Active Theme',
		icon: CupertinoIcons.paintbrush,
		children: {
			TristateSystemSetting.a: (CupertinoIcons.sun_max, 'Light'),
			TristateSystemSetting.system: (null, 'Follow System'),
			TristateSystemSetting.b: (CupertinoIcons.moon, 'Dark')
		},
		setting: Settings.themeSetting
	),
	for (final theme in [
		(
			description: 'Light theme',
			icon: CupertinoIcons.sun_max,
			setting: Settings.lightThemeKeySetting
		),
		(
			description: 'Dark theme',
			icon: CupertinoIcons.moon,
			setting: Settings.darkThemeKeySetting
		)
	]) ...[
		ImmutableButtonSettingWidget(
			description: theme.description,
			icon: theme.icon,
			setting: theme.setting,
			builder: (themeKey) => Text(themeKey),
			onPressed: (context, currentKey, setNewKey) async {
				final selectedKey = await selectThemeKey(
					context: context,
					title: 'Picking ${theme.description.toLowerCase()}',
					currentKey: currentKey,
					allowEditing: true
				);
				if (selectedKey != null) {
					setNewKey(selectedKey);
				}
			}
		),
		CustomMutableSettingWidget<SavedTheme>(
			description: 'Theme',
			setting: CustomMutableSetting(
				reader: (context) => Settings.instance.themes[theme.setting.value] ?? Settings.instance.lightTheme,
				watcher: (context) {
					final key = theme.setting.watch(context);
					// Rebuild whenever a value changes
					context.select<Settings, String?>((s) => s.themes[key]?.encode());
					return Settings.instance.themes[key] ?? Settings.instance.lightTheme;
				},
				didMutater: (context) async {
					Settings.instance.didEdit();
				}
			),
			builder: (theme, didModify) => Container(
				margin: const EdgeInsets.only(left: 16, right: 16),
				decoration: BoxDecoration(
					color: theme.barColor,
					borderRadius: const BorderRadius.all(Radius.circular(8))
				),
				child: SingleChildScrollView(
					scrollDirection: Axis.horizontal,
					child: Row(
						children: <(String, Color, ValueChanged<Color>, Color?)>[
							('Primary', theme.primaryColor, (c) => theme.primaryColor = c, theme.copiedFrom?.primaryColor),
							('Secondary', theme.secondaryColor, (c) => theme.secondaryColor = c, theme.copiedFrom?.secondaryColor),
							('Bar', theme.barColor, (c) => theme.barColor = c, theme.copiedFrom?.barColor),
							('Background', theme.backgroundColor, (c) => theme.backgroundColor = c, theme.copiedFrom?.backgroundColor),
							('Quote', theme.quoteColor, (c) => theme.quoteColor = c, theme.copiedFrom?.quoteColor),
							('Title', theme.titleColor, (c) => theme.titleColor = c, theme.copiedFrom?.titleColor),
							('Text Field', theme.textFieldColor, (c) => theme.textFieldColor = c, theme.copiedFrom?.textFieldColor)
						].map((color) => Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								const SizedBox(height: 16),
								Text(color.$1, style: TextStyle(color: theme.primaryColor)),
								const SizedBox(height: 16),
								Builder(
									builder: (context) => CupertinoButton(
										padding: EdgeInsets.zero,
										child: Container(
											decoration: BoxDecoration(
												borderRadius: const BorderRadius.all(Radius.circular(8)),
												border: Border.all(color: color.$2 == theme.primaryColor ? theme.barColor : theme.primaryColor),
												color: color.$2
											),
											width: 50,
											height: 50,
											child: theme.locked ? Icon(CupertinoIcons.lock, color: color.$2 == theme.primaryColor ? theme.barColor : theme.primaryColor) : null
										),
										onPressed: () async {
											if (theme.locked) {
												alertError(context, 'This theme is locked. Make a copy of it if you want to change its colours.', null);
												return;
											}
											Color c = color.$2;
											await showAdaptiveModalPopup(
												context: context,
												builder: (context) => StatefulBuilder(
													builder: (context, setActionSheetState) {
														return AdaptiveActionSheet(
															title: Text('Select ${color.$1} Color'),
															message: Theme(
																data: ThemeData(
																	textTheme: Theme.of(context).textTheme.apply(
																		bodyColor: ChanceTheme.primaryColorOf(context),
																		displayColor: ChanceTheme.primaryColorOf(context),
																	),
																	canvasColor: ChanceTheme.backgroundColorOf(context)
																),
																child: Padding(
																	padding: MediaQuery.viewInsetsOf(context),
																	child: Column(
																		mainAxisSize: MainAxisSize.min,
																		children: [
																			Material(
																				color: Colors.transparent,
																				child: ColorPicker(
																					pickerColor: c,
																					onColorChanged: (newColor) {
																						c = newColor;
																						setActionSheetState(() {});
																					},
																					enableAlpha: false,
																					portraitOnly: true,
																					displayThumbColor: true,
																					hexInputBar: true
																				)
																			),
																			AdaptiveFilledButton(
																				padding: const EdgeInsets.all(8),
																				color: color.$4,
																				onPressed: (c == color.$4 || color.$4 == null) ? null : () {
																					c = color.$4!;
																					didModify();
																					setActionSheetState(() {});
																				},
																				child: Text('Reset to original color', style: TextStyle(color: (color.$4?.computeLuminance() ?? 0) > 0.5 ? Colors.black : Colors.white))
																			)
																		]
																	)
																)
															)
														);
													}
												)
											);
											color.$3(c);
											didModify();
										}
									)
								),
								Builder(
									builder: (context) => SizedBox(width: 88 * Settings.textScaleSetting.watch(context), height: 24)
								)
							]
						)).toList()
					)
				)
			)
		)
	],
	SliderSettingWidget(
		description: 'Thumbnail size',
		icon: CupertinoIcons.resize,
		min: 50,
		max: 400,
		step: 5,
		textFormatter: (s) => '${s.round()}x${s.round()}',
		setting: Settings.thumbnailSizeSetting
	),
	SliderSettingWidget(
		description: 'Centered post thumbnails',
		icon: CupertinoIcons.list_bullet_below_rectangle,
		setting: const MappedSetting(
			Settings.centeredPostThumbnailSizeSettingSetting,
			FieldMappers.doubleAbs,
			FieldMappers.doubleAbs
		),
		min: 100,
		max: 1000,
		step: 25,
		textFormatter: (s) => 'Size: ${s.abs().round()}x${s.abs().round()}',
		enabledSetting: MappedSetting(
			Settings.centeredPostThumbnailSizeSettingSetting,
			(size) => size > 0,
			(enabled) => Settings.instance.centeredPostThumbnailSizeSetting.abs() * (enabled ? 1 : -1)
		)
	),
	SliderSettingWidget(
		description: 'New post highlight brightness',
		icon: CupertinoIcons.brightness,
		min: 0,
		max: 0.5,
		step: 0.01,
		widgetFormatter: (brightness) => Builder(
			builder: (context) => Container(
				color: context.select<SavedTheme, Color>((t) => t.primaryColorWithBrightness(brightness)),
				margin: const EdgeInsets.only(left: 8),
				padding: const EdgeInsets.all(8),
				child: const Text('Example new post')
			)
		),
		setting: Settings.newPostHighlightBrightnessSetting
	),
	const SegmentedSettingWidget(
		description: 'Thumbnail location',
		icon: CupertinoIcons.square_fill_line_vertical_square,
		children: {
			false: (null, 'Left'),
			true: (null, 'Right')
		},
		setting: Settings.imagesOnRightSetting
	),
	const SwitchSettingWidget(
		description: 'Blur image thumbnails',
		icon: CupertinoIcons.eyeglasses,
		setting: Settings.blurThumbnailsSetting
	),
	SliderSettingWidget(
		description: 'Pixelate image thumbnails',
		icon: CupertinoIcons.square,
		setting: const MappedSetting(
			Settings.thumbnailPixelationSetting,
			FieldMappers.toDoubleAbs,
			FieldMappers.toIntAbs
		),
		min: 3,
		max: 75,
		step: 1,
		textFormatter: (s) => 'Size: ${s.abs().round()}x${s.abs().round()}',
		enabledSetting: MappedSetting(
			Settings.thumbnailPixelationSetting,
			(pixelation) => pixelation > 0,
			(enabled) => Settings.instance.thumbnailPixelation.abs() * (enabled ? 1 : -1)
		)
	),
	const SwitchSettingWidget(
		description: 'Square thumbnails',
		icon: CupertinoIcons.square,
		setting: Settings.squareThumbnailsSetting
	),
	PopupSubpageSettingWidget(
		description: 'Edit post details',
		icon: CupertinoIcons.square_list,
		preview: PanelSettingWidget(
			builder: (context) => Container(
				height: 200,
				decoration: _threadAndPostRowDecorationOf(context),
				child: IgnorePointer(
					child: _buildFakePostRow()
				)
			)
		),
		settings: [
			const SwitchSettingWidget(
				description: 'Clover-style replies button',
				setting: Settings.cloverStyleRepliesButtonSetting
			),
			const SwitchSettingWidget(
				description: 'Show Post #',
				setting: Settings.showPostNumberOnPostsSetting
			),
			const SwitchSettingWidget(
				description: 'Show IP address #',
				setting: Settings.showIPNumberOnPostsSetting
			),
			const SwitchSettingWidget(
				description: 'Show name',
				setting: Settings.showNameOnPostsSetting
			),
			const SwitchSettingWidget(
				description: 'Hide default names',
				setting: Settings.hideDefaultNamesOnPostsSetting
			),
			const SwitchSettingWidget(
				description: 'Show trip',
				setting: Settings.showTripOnPostsSetting
			),
			const SwitchSettingWidget(
				description: 'Show filename',
				setting: Settings.showFilenameOnPostsSetting
			),
			const SwitchSettingWidget(
				description: 'Truncate long filenames',
				setting: Settings.ellipsizeLongFilenamesOnPostsSetting
			),
			const SwitchSettingWidget(
				description: 'Show filesize',
				setting: Settings.showFilesizeOnPostsSetting
			),
			const SwitchSettingWidget(
				description: 'Show file dimensions',
				setting: Settings.showFileDimensionsOnPostsSetting
			),
			const SwitchSettingWidget(
				description: 'Show pass',
				setting: Settings.showPassOnPostsSetting
			),
			const SwitchSettingWidget(
				description: 'Show flag',
				setting: Settings.showFlagOnPostsSetting
			),
			const SwitchSettingWidget(
				description: 'Show country name',
				setting: Settings.showCountryNameOnPostsSetting
			),
			const SwitchSettingWidget(
				description: 'Show exact time',
				setting: Settings.showAbsoluteTimeOnPostsSetting
			),
			const SwitchSettingWidget(
				description: 'Show relative time',
				setting: Settings.showRelativeTimeOnPostsSetting
			),
			const SwitchSettingWidget(
				description: 'Show "No." before ID',
				setting: Settings.showNoBeforeIdOnPostsSetting
			),
			const SwitchSettingWidget(
				description: 'Include line break',
				setting: Settings.showLineBreakInPostInfoRowSetting
			),
			const SwitchSettingWidget(
				description: 'Highlight dubs (etc)',
				setting: Settings.highlightRepeatingDigitsInPostIdsSetting
			),
			ImmutableButtonSettingWidget(
				description: 'Field order',
				builder: (context) => const Text('Edit'),
				setting: Settings.postDisplayFieldOrderSetting,
				onPressed: (context, fieldOrder, setFieldOrder) async {
					final list = fieldOrder.toList();
					final settings = Settings.instance;
					await showAdaptiveDialog(
						barrierDismissible: true,
						context: context,
						builder: (context) => StatefulBuilder(
							builder: (context, setDialogState) => AdaptiveAlertDialog(
								title: const Text('Reorder post details'),
								actions: [
									AdaptiveDialogAction(
										child: const Text('Close'),
										onPressed: () => Navigator.pop(context)
									)
								],
								content: SizedBox(
									width: 100,
									height: 350,
									child: ReorderableListView(
										children: list.asMap().entries.map((pair) {
											final bool disabled;
											switch (pair.value) {
												case PostDisplayField.name:
													disabled = !settings.showNameOnPosts && !settings.showTripOnPosts;
													break;
												case PostDisplayField.attachmentInfo:
													disabled = !settings.showFilenameOnPosts && !settings.showFilesizeOnPosts && !settings.showFileDimensionsOnPosts;
													break;
												case PostDisplayField.pass:
													disabled = !settings.showPassOnPosts;
													break;
												case PostDisplayField.flag:
													disabled = !settings.showFlagOnPosts;
													break;
												case PostDisplayField.countryName:
													disabled = !settings.showCountryNameOnPosts;
													break;
												case PostDisplayField.absoluteTime:
													disabled = !settings.showAbsoluteTimeOnPosts;
													break;
												case PostDisplayField.relativeTime:
													disabled = !settings.showRelativeTimeOnPosts;
													break;
												case PostDisplayField.ipNumber:
													disabled = !settings.showIPNumberOnPosts;
													break;
												case PostDisplayField.postNumber:
													disabled = !settings.showPostNumberOnPosts;
													break;
												case PostDisplayField.lineBreak:
													disabled = !settings.showLineBreakInPostInfoRow;
													break;
												case PostDisplayField.posterId:
												case PostDisplayField.postId:
													disabled = false;
													break;
											}
											return ReorderableDragStartListener(
												index: pair.key,
												key: ValueKey(pair.key),
												child: Container(
													decoration: BoxDecoration(
														borderRadius: const BorderRadius.all(Radius.circular(4)),
														color: ChanceTheme.primaryColorOf(context).withOpacity(0.1)
													),
													margin: const EdgeInsets.symmetric(vertical: 2),
													padding: const EdgeInsets.all(8),
													alignment: Alignment.center,
													child: Text(
														pair.value.displayName,
														style: disabled ? TextStyle(
															color: ChanceTheme.primaryColorWithBrightness50Of(context)
														) : null
													)
												)
											);
										}).toList(),
										onReorder: (oldIndex, newIndex) {
											if (oldIndex < newIndex) {
												newIndex -= 1;
											}
											final item = list.removeAt(oldIndex);
											list.insert(newIndex, item);
											setFieldOrder(list.toList());
											setDialogState(() {});
										}
									)
								)
							)
						)
					);
				}
			)
		]
	),
	const SwitchSettingWidget(
		description: 'Show reply counts in gallery',
		icon: CupertinoIcons.number_square,
		setting: Settings.showReplyCountsInGallerySetting
	),
	const SwitchSettingWidget(
		description: 'Show thumbnails in gallery',
		icon: CupertinoIcons.rectangle_grid_2x2,
		setting: Settings.showThumbnailsInGallerySetting
	),
	SegmentedSettingWidget(
		description: 'Catalog Layout',
		icon: CupertinoIcons.rectangle_stack,
		setting: Settings.useCatalogGridSetting,
		children: const {
			false: (CupertinoIcons.rectangle_grid_1x2, 'Rows'),
			true: (CupertinoIcons.rectangle_split_3x3, 'Grid')
		},
		injectButton: (context, useGrid, setUseGrid) => (ImageboardRegistry.instance.count > 1) ? Builder(
			builder: (context) => AdaptiveIconButton(
				minSize: 0,
				onPressed: () => Navigator.push(context, adaptivePageRoute(
					builder: (context) => SettingListPage(
						title: 'Per-Site Catalog Layout',
						settings: ImageboardRegistry.instance.imageboards.map((imageboard) => SegmentedSettingWidget(
							description: imageboard.site.name,
							iconBuilder: (color) => ImageboardIcon(
								imageboardKey: imageboard.key
							),
							setting: MappedSetting(
								SavedSetting(
									ChainedFieldWriter(
										ChainedFieldReader(
											SavedSettingsFields.browserStateBySite,
											MapFieldWriter<String, PersistentBrowserState>(key: imageboard.key),
										),
										PersistentBrowserStateFields.useCatalogGrid
									)
								),
								FieldMappers.nullSafeOptionalify,
								FieldMappers.unNullSafeOptionalify
							),
							children: {
								NullSafeOptional.false_: (CupertinoIcons.rectangle_grid_1x2, 'Rows'),
								NullSafeOptional.null_: (null, 'Default (${useGrid ? 'Grid' : 'Rows'})'),
								NullSafeOptional.true_: (CupertinoIcons.rectangle_split_3x3, 'Grid'),
							}
						)).toList()
					)
				)),
				icon: const Icon(CupertinoIcons.settings)
			)
		) : const SizedBox.shrink()
	),
	PopupSubpageSettingWidget(
		description: 'Edit catalog row item layout',
		icon: CupertinoIcons.resize_v,
		preview: PanelSettingWidget(
			builder: (context) => Container(
				height: Settings.maxCatalogRowHeightSetting.watch(context),
				foregroundDecoration: BoxDecoration(
					border: Border(
						top: BorderSide(color: ChanceTheme.primaryColorWithBrightness20Of(context)),
						bottom: BorderSide(color: ChanceTheme.primaryColorWithBrightness20Of(context)),
					)
				),
				child: ThreadRow(
					style: ThreadRowStyle.row,
					isSelected: false,
					thread: _makeFakeThread(),
					showLastReplies: Settings.showLastRepliesInCatalogSetting.watch(context)
				)
			)
		),
		settings: [
			const SwitchSettingWidget(
				description: 'Show last replies',
				setting: Settings.showLastRepliesInCatalogSetting
			),
			SliderSettingWidget(
				description: 'Height',
				keywords: ['size'],
				setting: Settings.maxCatalogRowHeightSetting,
				min: 100,
				max: 600,
				step: 1,
				textFormatter: (height) => '${height.round()} px'
			)
		]
	),
	PopupSubpageSettingWidget(
		description: 'Edit catalog grid item layout',
		icon: CupertinoIcons.resize,
		preview: PanelSettingWidget(
			builder: (context) {
				final width = Settings.catalogGridWidthSetting.watch(context);
				final height = Settings.catalogGridHeightSetting.watch(context);
				final staggered = Settings.useStaggeredCatalogGridSetting.watch(context);
				final child = Container(
					constraints: BoxConstraints(
						minWidth: width,
						maxWidth: width,
						minHeight: staggered ? 0 : height,
						maxHeight: height
					),
					decoration: _threadAndPostRowDecorationOf(context),
					child: ThreadRow(
						style: staggered ? ThreadRowStyle.staggeredGrid : ThreadRowStyle.grid,
						isSelected: false,
						thread: _makeFakeThread()
					)
				);
				if (staggered) {
					return Stack(
						children: [
							Container(
								width: width,
								height: height,
								decoration: BoxDecoration(
									border: Border.all(
										color: ChanceTheme.primaryColorOf(context)
									)
								),
								alignment: Alignment.bottomCenter,
								child: const Row(
									mainAxisAlignment: MainAxisAlignment.center,
									children: [
										Icon(CupertinoIcons.arrow_down_to_line),
										Text(' Max height')
									]
								)
							),
							child
						]
					);
				}
				return child;
			}
		),
		settings: [
			const SwitchSettingWidget(
				description: 'Staggered grid',
				icon: CupertinoIcons.rectangle_3_offgrid,
				setting: Settings.useStaggeredCatalogGridSetting
			),
			SliderSettingWidget(
				description: 'Width',
				keywords: ['columns', 'size'],
				setting: Settings.catalogGridWidthSetting,
				min: 100,
				max: 600,
				step: 1,
				textFormatter: (width) => '${width.round()} px (${describeCount(_estimateGridModeColumns(width), 'column')})'
			),
			SliderSettingWidget(
				description: 'Height',
				keywords: ['size'],
				setting: Settings.catalogGridHeightSetting,
				min: 150,
				max: 1200,
				step: 1,
				textFormatter: (height) => '${height.round()} px'
			),
			NullableSteppableSettingWidget(
				description: 'Maximum text lines',
				min: 1,
				step: 1,
				max: 32,
				formatter: (maxLines) => maxLines?.toString() ?? 'Unlimited',
				setting: Settings.catalogGridModeTextLinesLimitSetting
			),
			const SwitchSettingWidget(
				description: 'Thumbnail behind text',
				setting: Settings.catalogGridModeAttachmentInBackgroundSetting
			),
			const SwitchSettingWidget(
				description: 'Rounded corners and margin',
				setting: Settings.catalogGridModeCellBorderRadiusAndMarginSetting
			),
			const SwitchSettingWidget(
				description: 'Fixed thumbnail height',
				setting: MappedSetting(
					Settings.catalogGridModeShowMoreImageIfLessTextSetting,
					FieldMappers.invert,
					FieldMappers.invert
				),
				disabled: Settings.catalogGridModeAttachmentInBackgroundSetting
			),
			SteppableSettingWidget(
				description: 'Font scale',
				min: 0.5,
				step: 0.05,
				max: 2.0,
				formatter: (v) => '${(v * 100).round()}%',
				setting: Settings.catalogGridModeTextScaleSetting
			),
			const SwitchSettingWidget(
				description: 'Crop image to fill',
				setting: Settings.catalogGridModeCropThumbnailsSetting,
			),
			const SwitchSettingWidget(
				description: 'Text above image',
				setting: Settings.catalogGridModeTextAboveAttachmentSetting
			)
		]
	),
	PopupSubpageSettingWidget(
		description: 'Edit catalog item details',
		icon: CupertinoIcons.square_list,
		preview: PanelSettingWidget(
			builder: (context) => Column(
				mainAxisSize: MainAxisSize.min,
				children: [
					Container(
						height: 100,
						decoration: _threadAndPostRowDecorationOf(context),
						child: _buildFakeThreadRow(ThreadRowStyle.row)
					),
					const SizedBox(height: 16),
					Container(
						width: Settings.catalogGridWidthSetting.watch(context),
						height: Settings.catalogGridHeightSetting.watch(context),
						decoration: _threadAndPostRowDecorationOf(context),
						child: _buildFakeThreadRow(ThreadRowStyle.grid)
					)
				]
			)
		),
		settings: [
			const SwitchSettingWidget(
				description: 'Show reply count',
				setting: Settings.showReplyCountInCatalogSetting
			),
			const SwitchSettingWidget(
				description: 'Show image count',
				setting: Settings.showImageCountInCatalogSetting
			),
			const SwitchSettingWidget(
				description: 'Show clock icon',
				setting: Settings.showClockIconInCatalogSetting
			),
			const SwitchSettingWidget(
				description: 'Show name',
				setting: Settings.showNameInCatalogSetting
			),
			const SwitchSettingWidget(
				description: 'Hide default names',
				setting: Settings.hideDefaultNamesInCatalogSetting
			),
			const SwitchSettingWidget(
				description: 'Show exact time',
				setting: Settings.showTimeInCatalogHeaderSetting
			),
			const SwitchSettingWidget(
				description: 'Show relative time',
				setting: Settings.showTimeInCatalogStatsSetting
			),
			const SwitchSettingWidget(
				description: 'Show ID',
				setting: Settings.showIdInCatalogHeaderSetting
			),
			const SwitchSettingWidget(
				description: 'Show flag',
				setting: Settings.showFlagInCatalogHeaderSetting
			),
			const SwitchSettingWidget(
				description: 'Show country name',
				setting: Settings.showCountryNameInCatalogHeaderSetting
			),
			const SwitchSettingWidget(
				description: 'Clover-style counter formatting',
				setting: Settings.cloverStyleCatalogCountersSetting,
			),
			const SwitchSettingWidget(
				description: 'Show counters in their own row',
				setting: Settings.useFullWidthForCatalogCountersSetting,
			)
		]
	),
	const SwitchSettingWidget(
		description: 'Dim read threads in catalog',
		icon: CupertinoIcons.lightbulb_slash,
		setting: Settings.dimReadThreadsSetting
	),
	SliderSettingWidget(
		description: 'Two-pane breakpoint',
		icon: CupertinoIcons.sidebar_left,
		setting: Settings.twoPaneBreakpointSetting,
		min: 50,
		step: 50,
		max: 3000,
		textFormatter: (twoPaneBreakpoint) => '${twoPaneBreakpoint.round()} pixels',
		helpText: 'When the screen is at least ${Settings.instance.twoPaneBreakpoint.round()} pixels wide, two columns will be used.\nThe board catalog will be on the left and the current thread will be on the right.'
	),
	SliderSettingWidget(
		description: 'Two-pane split',
		icon: CupertinoIcons.sidebar_left,
		setting: const MappedSetting(
			Settings.twoPaneSplitSetting,
			FieldMappers.toDouble,
			FieldMappers.toInt
		),
		min: 1,
		max: (twoPaneSplitDenominator - 1).toDouble(),
		step: 1,
		textFormatter: (twoPaneSplit) {
			final firstPanePercent = (twoPaneSplit / twoPaneSplitDenominator) * 100;
			return '${firstPanePercent.toStringAsFixed(0)}% catalog, ${(100 - firstPanePercent).toStringAsFixed(0)}% thread';
		}
	),
	SliderSettingWidget(
		description: 'Vertical two-pane split',
		iconBuilder: (color) => RotatedBox(
			quarterTurns: 1,
			child: Icon(CupertinoIcons.sidebar_left, color: color)
		),
		setting: const MappedSetting(
			Settings.verticalTwoPaneMinimumPaneSizeSetting,
			FieldMappers.doubleAbs,
			FieldMappers.doubleAbs
		),
		enabledSetting: MappedSetting(
			Settings.verticalTwoPaneMinimumPaneSizeSetting,
			(x) => x >= 0,
			(enabled) => Settings.instance.verticalTwoPaneMinimumPaneSize.abs() * (enabled ? 1 : -1)
		),
		min: 100,
		max: 1000,
		step: 25,
		textFormatter: (verticalTwoPaneMinimumPaneSize) => 'Minimum pane height: ${verticalTwoPaneMinimumPaneSize.abs().round()} px'
	),
	const SwitchSettingWidget(
		description: 'Scrollbar',
		icon: CupertinoIcons.arrow_up_down,
		setting: Settings.showScrollbarsSetting
	),
	SegmentedSettingWidget(
		description: 'Scrollbar location',
		icon: CupertinoIcons.arrow_up_down,
		setting: MappedSetting<(bool, bool), NullSafeOptional>(
			const CombinedSetting(
				Settings.showScrollbarsSetting,
				Settings.scrollbarsOnLeftSetting
			),
			(unmapped) => switch(unmapped) {
				(false, _) => NullSafeOptional.null_,
				(true, bool x) => x.value
			},
			(mapped) => switch (mapped) {
				NullSafeOptional.null_ => (false, false /* arbitrary */),
				NullSafeOptional.true_ => (true, true),
				NullSafeOptional.false_ => (true, false)
			}
		),
		children: const {
			NullSafeOptional.true_: (null, 'Left'),
			NullSafeOptional.null_: (null, 'Off'),
			NullSafeOptional.false_: (null, 'Right')
		}
	),
	SteppableSettingWidget(
		description: 'Scrollbar thickness',
		icon: CupertinoIcons.arrow_left_right,
		min: 1,
		step: 1,
		max: 32,
		formatter: (scrollbarThickness) => '${scrollbarThickness.round()} px',
		setting: Settings.scrollbarThicknessSetting
	),
	SegmentedSettingWidget(
		description: 'List position indicator location',
		iconBuilder: (color) => Builder(
			builder: (context) => Row(
				mainAxisSize: MainAxisSize.min,
				children: [
					Container(
						decoration: BoxDecoration(
							borderRadius: const BorderRadius.only(
								topLeft: Radius.circular(6),
								bottomLeft: Radius.circular(6),
							),
							color: ChanceTheme.primaryColorWithBrightness60Of(context)
						),
						padding: const EdgeInsets.all(3),
						width: 13,
						alignment: Alignment.center,
						child: Text('1', style: TextStyle(color: ChanceTheme.backgroundColorOf(context), fontSize: 13))
					),
					Container(
						decoration: BoxDecoration(
							borderRadius: const BorderRadius.only(
								topRight: Radius.circular(6),
								bottomRight: Radius.circular(6),
							),
							color: ChanceTheme.primaryColorOf(context)
						),
						padding: const EdgeInsets.all(3),
						width: 13,
						alignment: Alignment.center,
						child: Text('1', style: TextStyle(color: ChanceTheme.backgroundColorOf(context), fontSize: 13))
					)
				]
			)
		),
		setting: Settings.showListPositionIndicatorsOnLeftSetting,
		children: const {
			true: (null, 'Left'),
			false: (null, 'Right')
		}
	),
	if (Platform.isAndroid && Settings.featureStatusBarWorkaround) const SwitchSettingWidget(
		description: 'Use status bar workaround',
		icon: CupertinoIcons.device_phone_portrait,
		helpText: 'Some devices have a bug in their Android ROM, where the status bar cannot be properly hidden.\n\nIf this workaround is enabled, the status bar will not be hidden when opening the gallery.',
		setting: SettingWithFallback(Settings.useStatusBarWorkaroundSetting, false)
	),
	ImageboardScopedSettingGroup(
		title: 'Thread layout',
		settings: [
			ImageboardScopedSettingWidget(
				description: 'Default thread layout',
				builder: (threadLayoutImageboard) => SegmentedSettingWidget(
					description: 'Default thread layout',
					icon: CupertinoIcons.list_bullet_below_rectangle,
					setting: threadLayoutImageboard.useTree,
					children: const {
						false: (CupertinoIcons.list_bullet, 'Linear'),
						true: (CupertinoIcons.list_bullet_indent, 'Tree')
					}
				)
			),
			ImageboardScopedSettingWidget(
				description: 'Initially hide nested replies',
				builder: (threadLayoutImageboard) => SwitchSettingWidget(
					disabled: threadLayoutImageboard.dontUseTree,
					description: 'Initially hide nested replies',
					icon: CupertinoIcons.return_icon,
					setting: SavedSetting(
						ChainedFieldWriter(
							ChainedFieldReader(
								SavedSettingsFields.browserStateBySite,
								MapFieldWriter<String, PersistentBrowserState>(key: threadLayoutImageboard.key)
							),
							PersistentBrowserStateFields.treeModeInitiallyCollapseSecondLevelReplies
						)
					)
				)
			),
			ImageboardScopedSettingWidget(
				description: 'Collapsed posts show body',
				builder: (threadLayoutImageboard) => SwitchSettingWidget(
					disabled: threadLayoutImageboard.dontUseTree,
					description: 'Collapsed posts show body',
					icon: CupertinoIcons.chevron_right_2,
					setting: SavedSetting(
						ChainedFieldWriter(
							ChainedFieldReader(
								SavedSettingsFields.browserStateBySite,
								MapFieldWriter<String, PersistentBrowserState>(key: threadLayoutImageboard.key)
							),
							PersistentBrowserStateFields.treeModeCollapsedPostsShowBody
						)
					)
				)
			),
			ImageboardScopedSettingWidget(
				description: 'Show replies to OP at top level',
				builder: (threadLayoutImageboard) => SwitchSettingWidget(
					disabled: threadLayoutImageboard.dontUseTree,
					description: 'Show replies to OP at top level',
					icon: CupertinoIcons.increase_indent,
					setting: SavedSetting(
						ChainedFieldWriter(
							ChainedFieldReader(
								SavedSettingsFields.browserStateBySite,
								MapFieldWriter<String, PersistentBrowserState>(key: threadLayoutImageboard.key)
							),
							PersistentBrowserStateFields.treeModeRepliesToOPAreTopLevel
						)
					)
				)
			),
			ImageboardScopedSettingWidget(
				description: 'New posts inserted at bottom',
				builder: (threadLayoutImageboard) => SwitchSettingWidget(
					disabled: threadLayoutImageboard.dontUseTree,
					description: 'New posts inserted at bottom',
					icon: CupertinoIcons.asterisk_circle,
					helpText: 'New posts will be added below the main tree to make it easier to read them. Pulling to refresh will re-sort them into the main tree.',
					setting: SavedSetting(
						ChainedFieldWriter(
							ChainedFieldReader(
								SavedSettingsFields.browserStateBySite,
								MapFieldWriter<String, PersistentBrowserState>(key: threadLayoutImageboard.key)
							),
							PersistentBrowserStateFields.treeModeNewRepliesAreLinear
						)
					)
				)
			)
		]
	),
	const SwitchSettingWidget(
		description: 'Blur effects',
		icon: CupertinoIcons.wand_stars,
		setting: Settings.blurEffectsSetting
	),
	const SwitchSettingWidget(
		description: '12-hour time',
		icon: CupertinoIcons.clock,
		setting: Settings.exactTimeIsTwelveHourSetting
	),
	SegmentedSettingWidget<NullWrapper<String>>(
		description: 'Date formatting',
		icon: CupertinoIcons.calendar,
		setting: MappedSetting<(bool, String), NullWrapper<String>>(
			const CombinedSetting(
				Settings.exactTimeUsesCustomDateFormatSetting,
				Settings.customDateFormatSetting
			),
			(unmapped) => switch (unmapped) {
				(false, _) => const NullWrapper(null),
				(true, String format) => NullWrapper(format)
			},
			(mapped) => switch (mapped.value) {
				null => (false, DateTimeConversion.kISO8601DateFormat /* arbitrary */),
				String format => (true, format)
			}
		),
		children: {
			const NullWrapper(null): (null, 'Default (${DateTime.now().weekdayShortName})'),
			const NullWrapper(DateTimeConversion.kISO8601DateFormat): (null, 'ISO 8601 (${DateTime.now().formatDate(DateTimeConversion.kISO8601DateFormat)})'),
			const NullWrapper('MM/DD/YY'): (null, 'MM/DD/YY (${DateTime.now().formatDate('MM/DD/YY')})'),
			const NullWrapper('DD/MM/YY'): (null, 'DD/MM/YY (${DateTime.now().formatDate('DD/MM/YY')})')
		}
	),
	const SwitchSettingWidget(
		description: 'Show date even if today',
		icon: CupertinoIcons.calendar,
		setting: Settings.exactTimeShowsDateForTodaySetting
	),
	const SwitchSettingWidget(
		description: 'Overlay indicators and buttons in gallery',
		icon: CupertinoIcons.number_square,
		setting: Settings.showOverlaysInGallerySetting
	),
	const SwitchSettingWidget(
		description: 'Show gallery grid button in catalog and thread',
		icon: CupertinoIcons.square_grid_2x2,
		setting: Settings.showGalleryGridButtonSetting
	),
	const SwitchSettingWidget(
		description: 'Show filtered posts/threads at bottom of lists',
		icon: CupertinoIcons.eye_slash,
		setting: Settings.showHiddenItemsFooterSetting
	),
	const SegmentedSettingWidget(
		knownWidth: 300,
		description: 'Scrolling images layout',
		icon: CupertinoIcons.rectangle_split_3x1,
		children: {
			false: (null, 'Continuous grid'),
			true: (null, 'Paged')
		},
		setting: Settings.attachmentsPageUsePageViewSetting
	),
	SteppableSettingWidget(
		description: 'Scrolling images grid columns',
		icon: CupertinoIcons.rectangle_split_3x3,
		disabled: Settings.attachmentsPageUsePageViewSetting,
		min: 1,
		step: 1,
		max: 10,
		formatter: (cols) => cols.toString(),
		setting: 
		AssociatedSetting<double, double, int>(
			setting: Settings.attachmentsPageMaxCrossAxisExtentSetting,
			associated: CustomImmutableSetting(
				reader: (context) => estimateDetailWidth(context, listen: false),
				watcher: (context) => estimateDetailWidth(context, listen: true),
				writer: (context, v) async {}
			),
			forwards: (maxExtent, width) => (width / math.max(1, maxExtent)).ceil(),
			reverse: (columns, width) => (width / columns).ceilToDouble()
		)
	)
];

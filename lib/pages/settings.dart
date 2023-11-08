import 'dart:io';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/flag.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/board.dart';
import 'package:chan/pages/licenses.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/installed_fonts.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/storage.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/services/user_agents.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/version.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/filter_editor.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/scroll_tracker.dart';
import 'package:chan/widgets/thread_row.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class _SettingsPage extends StatefulWidget {
	final String title;
	final List<Widget> children;
	const _SettingsPage({
		required this.children,
		required this.title,
		Key? key
	}) : super(key: key);

	@override
	createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
	final scrollKey = GlobalKey(debugLabel: '_SettingsPageState.scrollKey');

	@override
	Widget build(BuildContext context) {
		return AdaptiveScaffold(
			resizeToAvoidBottomInset: false,
			bar: AdaptiveBar(
				title: Text(widget.title)
			),
			body: Builder(
				builder: (context) => MaybeScrollbar(
					child: ListView.builder(
						padding: MediaQuery.paddingOf(context) + const EdgeInsets.all(16),
						key: scrollKey,
						itemCount: widget.children.length,
						itemBuilder: (context, i) => Align(
							alignment: Alignment.center,
							child: ConstrainedBox(
								constraints: const BoxConstraints(
									minWidth: 500,
									maxWidth: 500
								),
								child: widget.children[i]
							)
						)
					)
				)
			)
		);
	}
}

class _SettingsPageButton extends StatelessWidget {
	final IconData icon;
	final String title;
	final WidgetBuilder pageBuilder;
	final Color? color;
	const _SettingsPageButton({
		required this.icon,
		required this.title,
		required this.pageBuilder,
		this.color,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return AdaptiveButton(
			child: Row(
				children: [
					Icon(icon, color: color),
					const SizedBox(width: 16),
					Expanded(
						child: Text(title, style: TextStyle(color: color))
					),
					Icon(CupertinoIcons.chevron_forward, color: color)
				]
			),
			onPressed: () {
				Navigator.of(context).push(adaptivePageRoute(
					builder: pageBuilder
				));
			}
		);
	}
}

class SettingsPage extends StatelessWidget {
	const SettingsPage({
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		final site = context.watch<ImageboardSite>();
		final settings = context.watch<EffectiveSettings>();
		return _SettingsPage(
			title: 'Settings',
			children: [
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
											settings.showPerformanceOverlay = !settings.showPerformanceOverlay;
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
						future: context.read<ImageboardSite>().getCatalog('chance', interactive: true),
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
				const SizedBox(height: 24),
				const Text('Content Filtering'),
				const SizedBox(height: 16),
				Padding(
					padding: const EdgeInsets.only(left: 16, right: 16),
					child: Table(
						children: [
							TableRow(
								children: [
									const Text('Imageboard(s)'),
									Text(ImageboardRegistry.instance.imageboardsIncludingUninitialized.map((b) => b.key).join(', '), textAlign: TextAlign.right)
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
				FittedBox(
					fit: BoxFit.scaleDown,
					child: Row(
						children: [
							AdaptiveFilledButton(
								padding: const EdgeInsets.all(8),
								child: const Row(
									mainAxisSize: MainAxisSize.min,
									children: [
										Text('Synchronize '),
										Icon(Icons.sync_rounded, size: 16)
									]
								),
								onPressed: () async {
									await modalLoad(context, 'Synchronizing...', (_) => settings.updateContentSettings());
									if (context.mounted) {
										showToast(
											context: context,
											icon: CupertinoIcons.check_mark,
											message: 'Synchronized'
										);
									}
								}
							),
							if (settings.contentSettings.sites.length > 1) ...[
								const SizedBox(width: 16),
								AdaptiveFilledButton(
									padding: const EdgeInsets.all(8),
									child: const Row(
										mainAxisSize: MainAxisSize.min,
										children: [
											Text('Remove site '),
											Icon(CupertinoIcons.delete, size: 16)
										]
									),
									onPressed: () async {
										try {
											final imageboards = {
												for (final i in ImageboardRegistry.instance.imageboardsIncludingUninitialized)
													i.key: i.initialized ? i.site.name : i.key
											};
											final toDelete = await showAdaptiveDialog<String>(
												context: context,
												barrierDismissible: true,
												builder: (context) => AdaptiveAlertDialog(
													title: const Text('Which site?'),
													actions: [
														for (final i in imageboards.entries) AdaptiveDialogAction(
															isDestructiveAction: true,
															onPressed: () {
																Navigator.of(context).pop(i.key);
															},
															child: Text(i.value)
														),
														AdaptiveDialogAction(
															isDefaultAction: true,
															child: const Text('Cancel'),
															onPressed: () {
																Navigator.of(context).pop();
															},
														)
													]
												)
											);
											if (toDelete != null && context.mounted) {
												await modalLoad(context, 'Cleaning up...', (_) async {
													ImageboardRegistry.instance.getImageboard(toDelete)?.deleteAllData();
													final response = await Dio().delete('$contentSettingsApiRoot/user/${Persistence.settings.userId}/site/$toDelete');
													if (response.data['error'] != null) {
														throw Exception(response.data['error']);
													}
													await settings.updateContentSettings();
												});
											}
										}
										catch (e) {
											if (context.mounted) {
												alertError(context, e.toStringDio());
											}
										}
									}
								)
							],
							const SizedBox(width: 16),
							AdaptiveFilledButton(
								padding: const EdgeInsets.all(8),
								child: const Row(
									mainAxisSize: MainAxisSize.min,
									children: [
										Text('Edit preferences '),
										Icon(Icons.launch_rounded, size: 16)
									]
								),
								onPressed: () {
									launchUrl(Uri.parse(settings.contentSettingsUrl), mode: LaunchMode.externalApplication);
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
					color: ChanceTheme.primaryColorWithBrightness20Of(context)
				),
				_SettingsPageButton(
					icon: CupertinoIcons.eye_slash,
					title: 'Behavior Settings',
					color: settings.filterError != null ? Colors.red : null,
					pageBuilder: (context) => const SettingsBehaviorPage()
				),
				Divider(
					color: ChanceTheme.primaryColorWithBrightness20Of(context)
				),
				_SettingsPageButton(
					icon: CupertinoIcons.paintbrush,
					title: 'Appearance Settings',
					pageBuilder: (context) => const SettingsAppearancePage()
				),
				Divider(
					color: ChanceTheme.primaryColorWithBrightness20Of(context)
				),
				_SettingsPageButton(
					icon: Adaptive.icons.photos,
					title: 'Data Settings',
					pageBuilder: (context) => const SettingsDataPage()
				),
				Divider(
					color: ChanceTheme.primaryColorWithBrightness20Of(context)
				),
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
				),
				const SizedBox(height: 16),
			],
		);
	}
}

class SettingsBehaviorPage extends StatefulWidget {
	const SettingsBehaviorPage({
		Key? key
	}) : super(key: key);

	@override
	createState() => _SettingsBehaviorPageState();
}

class _SettingsBehaviorPageState extends State<SettingsBehaviorPage> {
	Imageboard _loginSystemImageboard = ImageboardRegistry.instance.imageboards.first;

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<EffectiveSettings>();
		int filterCount = 0;
		for (final line in settings.filterConfiguration.split('\n').asMap().entries) {
			if (line.value.isEmpty) {
				continue;
			}
			try {
				CustomFilter.fromStringConfiguration(line.value);
				filterCount++;
			}
			on FilterException {
				// don't show
			}
		}
		return _SettingsPage(
			title: 'Behavior Settings',
			children: [
				const SizedBox(height: 16),
				Row(
					mainAxisSize: MainAxisSize.min,
					children: [
						const Icon(CupertinoIcons.scope),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Filters')
						),
						AdaptiveFilledButton(
							padding: const EdgeInsets.all(8),
							onPressed: () => Navigator.of(context).push(adaptivePageRoute(
								builder: (context) => const SettingsFilterPage()
							)),
							child: Text('${describeCount(filterCount, 'filter')}...')
						)
					]
				),
				const SizedBox(height: 16),
				Row(
					children: [
						const Icon(Icons.hide_image_outlined),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Image filter')
						),
						AdaptiveFilledButton(
							padding: const EdgeInsets.all(8),
							onPressed: () async {
								final md5sBefore = Persistence.settings.hiddenImageMD5s;
								await Navigator.of(context).push(adaptivePageRoute(
									builder: (context) => const SettingsImageFilterPage()
								));
								if (!setEquals(md5sBefore, Persistence.settings.hiddenImageMD5s)) {
									settings.didUpdateHiddenMD5s();
								}
							},
							child: Text('${describeCount(Persistence.settings.hiddenImageMD5s.length, 'image')}...')
						)
					]
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.lock),
						const SizedBox(width: 8),
						Expanded(
							child: Text(_loginSystemImageboard.site.loginSystem?.name ?? 'No login system')
						),
						if (_loginSystemImageboard.site.loginSystem != null) ...[
							AdaptiveFilledButton(
								padding: const EdgeInsets.all(8),
								onPressed: () {
									showAdaptiveDialog(
										context: context,
										barrierDismissible: true,
										builder: (context) => AdaptiveAlertDialog(
											content: SettingsLoginPanel(
												loginSystem: _loginSystemImageboard.site.loginSystem!
											),
											actions: [
												AdaptiveDialogAction(
													onPressed: () => Navigator.pop(context),
													child: const Text('Close')
												)
											]
										)
									);
								},
								child: Text(_loginSystemImageboard.site.loginSystem?.getSavedLoginFields() == null ? 'Logged out' : 'Logged in')
							),
							const SizedBox(width: 8)
						],
						AdaptiveFilledButton(
							padding: const EdgeInsets.all(8),
							onPressed: () async {
								final newImageboard = await _pickImageboard(context, _loginSystemImageboard);
								if (newImageboard != null) {
									setState(() {
										_loginSystemImageboard = newImageboard;
									});
								}
							},
							child: Row(
								mainAxisSize: MainAxisSize.min,
								children: [
									ImageboardIcon(
										imageboardKey: _loginSystemImageboard.key
									),
									const SizedBox(width: 8),
									Text(_loginSystemImageboard.site.name)
								]
							)
						)
					]
				),
				const SizedBox(height: 32),
				const Row(
					children: [
						Icon(CupertinoIcons.question_square),
						SizedBox(width: 8),
						Expanded(
							child: Text('Load thumbnails')
						)
					]
				),
				const SizedBox(height: 16),
				AdaptiveSegmentedControl<AutoloadAttachmentsSetting>(
					children: const {
						AutoloadAttachmentsSetting.never: (null, 'Never'),
						AutoloadAttachmentsSetting.wifi: (null, 'When on Wi\u200d-\u200dFi'),
						AutoloadAttachmentsSetting.always: (null, 'Always')
					},
					groupValue: settings.loadThumbnailsSetting,
					onValueChanged: (newValue) {
						settings.loadThumbnailsSetting = newValue;
					}
				),
				const SizedBox(height: 32),
				IgnorePointer(
					ignoring: settings.loadThumbnailsSetting == AutoloadAttachmentsSetting.never,
					child: Opacity(
						opacity: settings.loadThumbnailsSetting == AutoloadAttachmentsSetting.never ? 0.5 : 1.0,
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.stretch,
							mainAxisSize: MainAxisSize.min,
							children: [
								const Row(
									children: [
										Icon(Icons.high_quality),
										SizedBox(width: 8),
										Expanded(
											child: Text('Full-quality image thumbnails')
										)
									]
								),
								const SizedBox(height: 16),
								AdaptiveSegmentedControl<AutoloadAttachmentsSetting>(
									children: const {
										AutoloadAttachmentsSetting.never: (null, 'Never'),
										AutoloadAttachmentsSetting.wifi: (null, 'When on Wi\u200d-\u200dFi'),
										AutoloadAttachmentsSetting.always: (null, 'Always')
									},
									groupValue: settings.fullQualityThumbnailsSetting,
									onValueChanged: (newValue) {
										settings.fullQualityThumbnailsSetting = newValue;
									}
								)
							]
						)
					)
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.arrow_left_right_square_fill),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Allow swiping to change page in gallery')
						),
						AdaptiveSwitch(
							value: settings.allowSwipingInGallery,
							onChanged: (newValue) {
								settings.allowSwipingInGallery = newValue;
							}
						)
					]
				),
				const SizedBox(height: 32),
				const Row(
					children: [
						Icon(CupertinoIcons.cloud_download),
						SizedBox(width: 8),
						Expanded(
							child: Text('Automatically load attachments in gallery')
						)
					]
				),
				const SizedBox(height: 16),
				AdaptiveSegmentedControl<AutoloadAttachmentsSetting>(
					children: const {
						AutoloadAttachmentsSetting.never: (null, 'Never'),
						AutoloadAttachmentsSetting.wifi: (null, 'When on Wi\u200d-\u200dFi'),
						AutoloadAttachmentsSetting.always: (null, 'Always')
					},
					groupValue: settings.autoloadAttachmentsSetting,
					onValueChanged: (newValue) {
						settings.autoloadAttachmentsSetting = newValue;
					}
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(Icons.touch_app_outlined),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Always automatically load tapped attachment')
						),
						AdaptiveSwitch(
							value: settings.alwaysAutoloadTappedAttachment,
							onChanged: (newValue) {
								settings.alwaysAutoloadTappedAttachment = newValue;
							}
						)
					]
				),
				const SizedBox(height: 32),
				const Row(
					children: [
						Icon(CupertinoIcons.cloud_download),
						SizedBox(width: 8),
						Expanded(
							child: Text('Preload attachments when opening threads')
						)
					]
				),
				const SizedBox(height: 16),
				AdaptiveSegmentedControl<AutoloadAttachmentsSetting>(
					children: const {
						AutoloadAttachmentsSetting.never: (null, 'Never'),
						AutoloadAttachmentsSetting.wifi: (null, 'When on Wi\u200d-\u200dFi'),
						AutoloadAttachmentsSetting.always: (null, 'Always')
					},
					groupValue: settings.autoCacheAttachmentsSetting,
					onValueChanged: (newValue) async {
						if (newValue == AutoloadAttachmentsSetting.always) {
							final ok = await confirm(context, 'Are you sure? This will consume a large amount of mobile data.');
							if (!ok) {
								setState(() {}); // Fix stuck button press-state
								return;
							}
						}
						settings.autoCacheAttachmentsSetting = newValue;
					}
				),
				const SizedBox(height: 32),
				const Row(
					children: [
						Icon(CupertinoIcons.volume_off),
						SizedBox(width: 8),
						Expanded(
							child: Text('Automatically mute audio')
						)
					]
				),
				const SizedBox(height: 16),
				AdaptiveChoiceControl<TristateSystemSetting>(
					children: const {
						TristateSystemSetting.a: (null, 'Never'),
						TristateSystemSetting.system: (null, 'When opening gallery without headphones'),
						TristateSystemSetting.b: (null, 'When opening gallery')
					},
					groupValue: settings.muteAudioWhenOpeningGallery,
					onValueChanged: (newValue) {
						settings.muteAudioWhenOpeningGallery = newValue;
					}
				),
				if (EffectiveSettings.featureWebmTranscodingForPlayback) ...[
					const SizedBox(height: 32),
					const Row(
						children: [
							Icon(CupertinoIcons.play_rectangle),
							SizedBox(width: 8),
							Flexible(
								child: Text('Transcode WEBM videos before playback')
							),
							SizedBox(width: 8),
							_SettingsHelpButton(
								helpText: 'Some devices may have bugs in their media decoding engines during WEBM playback. Enabling transcoding here will make those WEBMs playable, at the cost of waiting for a transcode first.'
							)
						]
					),
					const SizedBox(height: 16),
					AdaptiveSegmentedControl<WebmTranscodingSetting>(
						children: const {
							WebmTranscodingSetting.never: (null, 'Never'),
							WebmTranscodingSetting.vp9: (null, 'VP9 only'),
							WebmTranscodingSetting.always: (null, 'Always')
						},
						groupValue: settings.webmTranscoding,
						onValueChanged: (newValue) {
							settings.webmTranscoding = newValue;
						}
					),
				],
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.pin_slash),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Hide old stickied threads')
						),
						AdaptiveSwitch(
							value: settings.hideOldStickiedThreads,
							onChanged: (newValue) {
								settings.hideOldStickiedThreads = newValue;
							}
						)
					]
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.keyboard),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Use old captcha interface')
						),
						AdaptiveSwitch(
							value: !settings.useNewCaptchaForm,
							onChanged: (newValue) {
								settings.useNewCaptchaForm = !newValue;
							}
						)
					]
				),
				const SizedBox(height: 32),
				const Row(
					children: [
						Icon(CupertinoIcons.globe),
						SizedBox(width: 8),
						Text('Links open...')
					]
				),
				const SizedBox(height: 16),
				AdaptiveSegmentedControl<NullSafeOptional>(
					children: const {
						NullSafeOptional.false_: (null, 'Externally'),
						NullSafeOptional.null_: (null, 'Ask'),
						NullSafeOptional.true_: (null, 'Internally')
					},
					groupValue: settings.useInternalBrowser.value,
					onValueChanged: (newValue) {
						settings.useInternalBrowser = newValue.value;
					}
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(Icons.launch_rounded),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Always open links externally')
						),
						AdaptiveFilledButton(
							padding: const EdgeInsets.all(16),
							onPressed: () async {
								await editStringList(
									context: context,
									list: settings.hostsToOpenExternally,
									name: 'site',
									title: 'Sites to open externally'
								);
								settings.didUpdateHostsToOpenExternally();
							},
							child: Text('For ${describeCount(settings.hostsToOpenExternally.length, 'site')}')
						)
					]
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.resize),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Limit uploaded file dimensions')
						),
						AdaptiveFilledButton(
							padding: const EdgeInsets.all(16),
							onPressed: () async {
								final controller = TextEditingController(text: settings.maximumImageUploadDimension?.toString());
								await showAdaptiveDialog(
									context: context,
									barrierDismissible: true,
									builder: (context) => AdaptiveAlertDialog(
										title: const Text('Set maximum file upload dimension'),
										actions: [
											AdaptiveDialogAction(
												child: const Text('Clear'),
												onPressed: () {
													controller.text = '';
													Navigator.pop(context);
												}
											),
											AdaptiveDialogAction(
												child: const Text('Close'),
												onPressed: () => Navigator.pop(context)
											)
										],
										content: Row(
											children: [
												Expanded(
													child: AdaptiveTextField(
														autofocus: true,
														controller: controller,
														keyboardType: TextInputType.number,
														onSubmitted: (s) {
															Navigator.pop(context);
														}
													)
												),
												const SizedBox(width: 16),
												const Text('px')
											]
										)
									)
								);
								settings.maximumImageUploadDimension = int.tryParse(controller.text);
								controller.dispose();
							},
							child: Text(settings.maximumImageUploadDimension == null ? 'No limit' : '${settings.maximumImageUploadDimension} px')
						)
					]
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.rectangle_stack),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Close tab switcher after use')
						),
						AdaptiveSwitch(
							value: settings.closeTabSwitcherAfterUse,
							onChanged: (newValue) {
								settings.closeTabSwitcherAfterUse = newValue;
							}
						)
					]
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.settings),
						const SizedBox(width: 8),
						const Text('Settings icon action'),
						const SizedBox(width: 16),
						Expanded(
							child: Align(
								alignment: Alignment.centerRight,
								child: AdaptiveFilledButton(
									padding: const EdgeInsets.all(16),
									onPressed: () async {
										bool tapped = false;
										final newAction = await showAdaptiveDialog<SettingsQuickAction>(
											context: context,
											barrierDismissible: true,
											builder: (context) => AdaptiveAlertDialog(
												title: const Text('Pick Settings icon long-press action'),
												actions: [
													...SettingsQuickAction.values,
													null
												].map((action) => AdaptiveDialogAction(
													isDefaultAction: action == settings.settingsQuickAction,
													onPressed: () {
														tapped = true;
														Navigator.pop(context, action);
													},
													child: Text(action.name)
												)).toList()
											)
										);
										if (tapped) {
											settings.settingsQuickAction = newAction;
										}
									},
									child: AutoSizeText(settings.settingsQuickAction.name, maxLines: 2, textAlign: TextAlign.center)
								)
							)
						)
					]
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(Icons.vibration),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Haptic feedback')
						),
						AdaptiveSwitch(
							value: settings.useHapticFeedback,
							onChanged: (newValue) {
								settings.useHapticFeedback = newValue;
							}
						)
					]
				),
				if (Platform.isAndroid) ...[
					const SizedBox(height: 32),
					Row(
						children: [
							const Icon(CupertinoIcons.keyboard),
							const SizedBox(width: 8),
							const Expanded(
								child: Text('Incognito keyboard')
							),
							AdaptiveSwitch(
								value: !settings.enableIMEPersonalizedLearning,
								onChanged: (newValue) {
									settings.enableIMEPersonalizedLearning = !newValue;
								}
							)
						]
					),
				],
				const SizedBox(height: 32),
				const Row(
					children: [
						Icon(CupertinoIcons.arrow_up_down),
						SizedBox(width: 8),
						Expanded(
							child: Text('Hide bars when scrolling down')
						)
					]
				),
				const SizedBox(height: 16),
				AdaptiveSegmentedControl<(bool, bool)>(
					children: {
						(false, false): (null, 'None'),
						(false, true): (null, 'Tab bar'),
						if (settings.hideBarsWhenScrollingDown && !settings.tabMenuHidesWhenScrollingDown) (true, false): (null, 'Only top and bottom bars (Don\'t use this!!!)'),
						(true, true): (null, settings.androidDrawer ? 'Navigation bar' : 'Top and bottom bars')
					},
					groupValue: (settings.hideBarsWhenScrollingDown, settings.tabMenuHidesWhenScrollingDown),
					onValueChanged: (pair) {
						if (!settings.hideBarsWhenScrollingDown && pair.$1) {
							// Don't immediately hide bars
							ScrollTracker.instance.slowScrollDirection.value = VerticalDirection.up;
						}
						settings.hideBarsWhenScrollingDown = pair.$1;
						settings.tabMenuHidesWhenScrollingDown = pair.$2;
					}
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.hand_point_right),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Double-tap scrolls to replies in thread')
						),
						AdaptiveSwitch(
							value: settings.doubleTapScrollToReplies,
							onChanged: (newValue) {
								settings.doubleTapScrollToReplies = newValue;
							}
						)
					]
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.rectangle_expand_vertical),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Tapping background closes all replies')
						),
						AdaptiveSwitch(
							value: settings.overscrollModalTapPopsAll,
							onChanged: (newValue) {
								settings.overscrollModalTapPopsAll = newValue;
							}
						)
					]
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.exclamationmark_octagon),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Always show spoilers')
						),
						AdaptiveSwitch(
							value: settings.alwaysShowSpoilers,
							onChanged: (newValue) {
								settings.alwaysShowSpoilers = newValue;
							}
						)
					]
				),
				const SizedBox(height: 32),
				const Row(
					children: [
						Icon(CupertinoIcons.exclamationmark_square),
						SizedBox(width: 8),
						Flexible(
							child: Text('Image peeking')
						),
						SizedBox(width: 8),
						_SettingsHelpButton(
							helpText: 'You can hold on an image thumbnail to preview it. This setting adjusts whether it is blurred and what size it starts at.'
						)
					]
				),
				Padding(
					padding: const EdgeInsets.all(16),
					child: AdaptiveChoiceControl<ImagePeekingSetting>(
						children: const {
							ImagePeekingSetting.disabled: (null, 'Off'),
							ImagePeekingSetting.standard: (null, 'Obscured'),
							ImagePeekingSetting.unsafe: (null, 'Small'),
							ImagePeekingSetting.ultraUnsafe: (null, 'Full size')
						},
						groupValue: context.watch<EffectiveSettings>().imagePeeking,
						onValueChanged: (setting) {
							context.read<EffectiveSettings>().imagePeeking = setting;
						}
					)
				),
				const SizedBox(height: 16),
				Row(
					children: [
						const Icon(CupertinoIcons.textformat_abc_dottedunderline),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Spellcheck')
						),
						AdaptiveSwitch(
							value: settings.enableSpellCheck,
							onChanged: (newValue) {
								settings.enableSpellCheck = newValue;
							}
						)
					]
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.rectangle_stack_badge_plus),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Open cross-thread links in new tabs')
						),
						AdaptiveSwitch(
							value: settings.openCrossThreadLinksInNewTab,
							onChanged: (newValue) {
								settings.openCrossThreadLinksInNewTab = newValue;
							}
						)
					]
				),
				const SizedBox(height: 32),
				const Row(
					children: [
						Icon(CupertinoIcons.refresh),
						SizedBox(width: 8),
						Expanded(
							child: Text('Current thread auto-updates every...')
						)
					]
				),
				Padding(
					padding: const EdgeInsets.all(16),
					child: AdaptiveChoiceControl<int>(
						children: const {
							5: (null, '5s'),
							10: (null, '10s'),
							15: (null, '15s'),
							30: (null, '30s'),
							60: (null, '60s'),
							1 << 50: (null, 'Off')
						},
						groupValue: context.watch<EffectiveSettings>().currentThreadAutoUpdatePeriodSeconds,
						onValueChanged: (setting) {
							context.read<EffectiveSettings>().currentThreadAutoUpdatePeriodSeconds = setting;
						}
					)
				),
				const Row(
					children: [
						SizedBox(width: 32),
						Expanded(
							child: Text('Background threads auto-update every...')
						)
					]
				),
				Padding(
					padding: const EdgeInsets.all(16),
					child: AdaptiveChoiceControl<int>(
						children: const {
							15: (null, '15s'),
							30: (null, '30s'),
							60: (null, '60s'),
							120: (null, '120s'),
							180: (null, '180s'),
							1 << 50: (null, 'Off')
						},
						groupValue: context.watch<EffectiveSettings>().backgroundThreadAutoUpdatePeriodSeconds,
						onValueChanged: (setting) {
							context.read<EffectiveSettings>().backgroundThreadAutoUpdatePeriodSeconds = setting;
						}
					)
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.bell),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Auto-watch thread when replying')
						),
						AdaptiveSwitch(
							value: settings.watchThreadAutomaticallyWhenReplying,
							onChanged: (newValue) {
								settings.watchThreadAutomaticallyWhenReplying = newValue;
							}
						)
					]
				),
				const SizedBox(height: 32),
				Row(
					children: [
						Icon(Adaptive.icons.bookmark),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Auto-save thread when replying')
						),
						AdaptiveSwitch(
							value: settings.saveThreadAutomaticallyWhenReplying,
							onChanged: (newValue) {
								settings.saveThreadAutomaticallyWhenReplying = newValue;
							}
						)
					]
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.reply_all),
						const SizedBox(width: 8),
						const Text('Cancellable replies swipe gesture'),
						const SizedBox(width: 8),
						const _SettingsHelpButton(
							helpText: 'When swiping from right to left to open a post\'s replies, only continuing the swipe will open the replies. Releasing the swipe in another direction will cancel the gesture.'
						),
						const Spacer(),
						AdaptiveSwitch(
							value: settings.cancellableRepliesSlideGesture,
							onChanged: (newValue) {
								settings.cancellableRepliesSlideGesture = newValue;
							}
						)
					]
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.arrow_right_square),
						const SizedBox(width: 8),
						const Text('Swipe to open board switcher'),
						const SizedBox(width: 8),
						_SettingsHelpButton(
							helpText: 'Swipe left-to-right ${settings.androidDrawer ? 'starting on the right side of the' : 'in the'} catalog to open the board switcher.'
						),
						const Spacer(),
						AdaptiveSwitch(
							value: settings.openBoardSwitcherSlideGesture,
							onChanged: (newValue) {
								settings.openBoardSwitcherSlideGesture = newValue;
							}
						)
					]
				),
				const SizedBox(height: 16)
			]
		);
	}
}

class SettingsImageFilterPage extends StatefulWidget {
	const SettingsImageFilterPage({
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
		controller = TextEditingController(text: Persistence.settings.hiddenImageMD5s.join('\n'));
	}

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<EffectiveSettings>();
		return AdaptiveScaffold(
			resizeToAvoidBottomInset: false,
			disableAutoBarHiding: true,
			bar: const AdaptiveBar(
				title: Text('Image Filter Settings')
			),
			body: SafeArea(
				child: Padding(
					padding: const EdgeInsets.all(16),
					child: Column(
						children: [
							Row(
								children: [
									const Icon(CupertinoIcons.list_bullet_below_rectangle),
									const SizedBox(width: 8),
									const Expanded(
										child: Text('Apply to thread OP images')
									),
									const SizedBox(width: 16),
									AdaptiveSwitch(
										value: settings.applyImageFilterToThreads,
										onChanged: (newValue) {
											settings.applyImageFilterToThreads = newValue;
										}
									)
								]
							),
							const SizedBox(height: 16),
							const Text('One image MD5 per line'),
							const SizedBox(height: 8),
							Expanded(
								child: AdaptiveTextField(
									controller: controller,
									enableIMEPersonalizedLearning: false,
									onChanged: (s) {
										context.read<EffectiveSettings>().setHiddenImageMD5s(s.split('\n').where((x) => x.isNotEmpty));
									},
									maxLines: null
								)
							)
						]
					)
				)
			)
		);
	}

	@override
	void dispose() {
		super.dispose();
		controller.dispose();
	}
}

class SettingsFilterPage extends StatefulWidget {
	const SettingsFilterPage({
		Key? key
	}) : super(key: key);

	@override
	createState() => _SettingsFilterPageState();
}

class _SettingsFilterPageState extends State<SettingsFilterPage> {
	bool showFilterRegex = false;

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<EffectiveSettings>();
		return AdaptiveScaffold(
			resizeToAvoidBottomInset: false,
			disableAutoBarHiding: true,
			bar: const AdaptiveBar(
				title: Text('Filter Settings')
			),
			body: SafeArea(
				child: Column(
					children: [
						const SizedBox(height: 16),
						Row(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								const SizedBox(width: 16),
								const Padding(
									padding: EdgeInsets.only(top: 4),
									child: Row(
										mainAxisSize: MainAxisSize.min,
										children: [
											Icon(CupertinoIcons.scope),
											SizedBox(width: 8),
											Text('Filters')
										]
									)
								),
								const SizedBox(width: 32),
								Expanded(
									child: Wrap(
										alignment: WrapAlignment.end,
										spacing: 16,
										runSpacing: 16,
										children: [
											AdaptiveFilledButton(
												padding: const EdgeInsets.all(8),
												borderRadius: BorderRadius.circular(4),
												minSize: 0,
												child: const Text('Test filter setup'),
												onPressed: () {
													Navigator.of(context).push(adaptivePageRoute(
														builder: (context) => const FilterTestPage()
													));
												}
											),
											AdaptiveSegmentedControl<bool>(
												padding: EdgeInsets.zero,
												groupValue: showFilterRegex,
												children: const {
													false: (null, 'Wizard'),
													true: (null, 'Regex')
												},
												onValueChanged: (v) => setState(() {
													showFilterRegex = v;
												})
											)
										]
									)
								),
								const SizedBox(width: 16)
							]
						),
						if (settings.filterError != null) Padding(
							padding: const EdgeInsets.only(top: 16),
							child: Text(
								settings.filterError!,
								style: const TextStyle(
									color: Colors.red
								)
							)
						),
						Expanded(
							child: FilterEditor(
								showRegex: showFilterRegex,
								fillHeight: true
							)
						)
					]
				)
			)
		);
	}
}

class SettingsAppearancePage extends StatefulWidget {
	const SettingsAppearancePage({
		Key? key
	}) : super(key: key);

	@override
	createState() => _SettingsAppearancePageState();
}

class _SettingsAppearancePageState extends State<SettingsAppearancePage> {
	Imageboard _threadLayoutImageboard = ImageboardRegistry.instance.imageboards.first;

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
					attachments: [attachment],
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
					attachments: [],
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
					attachments: [],
					spanFormat: PostSpanFormat.chan4,
					ipNumber: 2
				)
			]
		);
	}

	Widget _buildFakeThreadRow({bool contentFocus = true}) {
		return ThreadRow(
			contentFocus: contentFocus,
			contentFocusBorderRadiusAndPadding: context.watch<EffectiveSettings>().catalogGridModeCellBorderRadiusAndMargin,
			isSelected: false,
			thread: _makeFakeThread()
		);
	}

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

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<EffectiveSettings>();
		final theme = context.watch<SavedTheme>();
		final firstPanePercent = (settings.twoPaneSplit / twoPaneSplitDenominator) * 100;
		final dividerColor = ChanceTheme.primaryColorOf(context);
		final threadAndPostRowDecoration = ChanceTheme.materialOf(context) ? BoxDecoration(
			border: Border.all(color: dividerColor.withOpacity(0.5))
		) : null;
		return _SettingsPage(
			title: 'Appearance Settings',
			children: [
				const SizedBox(height: 16),
				Row(
					children: [
						const Icon(CupertinoIcons.zoom_in),
						const SizedBox(width: 8),
						const Text('Interface scale'),
						const Spacer(),
						AdaptiveIconButton(
							onPressed: settings.interfaceScale <= 0.5 ? null : () {
								settings.interfaceScale -= 0.05;
							},
							icon: const Icon(CupertinoIcons.minus)
						),
						Text('${(settings.interfaceScale * 100).round()}%'),
						AdaptiveIconButton(
							onPressed: settings.interfaceScale >= 2.0 ? null : () {
								settings.interfaceScale += 0.05;
							},
							icon: const Icon(CupertinoIcons.plus)
						)
					]
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.textformat_size),
						const SizedBox(width: 8),
						const Text('Font scale'),
						const Spacer(),
						AdaptiveIconButton(
							onPressed: settings.textScale <= 0.5 ? null : () {
								settings.textScale -= 0.05;
							},
							icon: const Icon(CupertinoIcons.minus)
						),
						Text('${(settings.textScale * 100).round()}%'),
						AdaptiveIconButton(
							onPressed: settings.textScale >= 2.0 ? null : () {
								settings.textScale += 0.05;
							},
							icon: const Icon(CupertinoIcons.plus)
						)
					]
				),
				const SizedBox(height: 32),
				const Row(
					children: [
						Icon(CupertinoIcons.macwindow),
						SizedBox(width: 8),
						Expanded(
							child: Text('Interaction Mode')
						)
					]
				),
				const SizedBox(height: 16),
				AdaptiveChoiceControl<TristateSystemSetting>(
					children: const {
						TristateSystemSetting.a: (CupertinoIcons.hand_draw, 'Touch'),
						TristateSystemSetting.system: (null, 'Automatic'),
						TristateSystemSetting.b: (Icons.mouse, 'Mouse')
					},
					groupValue: settings.supportMouseSetting,
					onValueChanged: (newValue) {
						settings.supportMouseSetting = newValue;
					}
				),
				const SizedBox(height: 32),
				AnimatedSize(
					duration: const Duration(milliseconds: 250),
					curve: Curves.ease,
					alignment: Alignment.topCenter,
					child: ValueListenableBuilder(
						valueListenable: settings.supportMouse,
						builder: (context, supportMouse, _) {
							if (!supportMouse) {
								return const SizedBox.shrink();
							}
							return Column(
								crossAxisAlignment: CrossAxisAlignment.stretch,
								children: [
									Row(
										children: [
											const Icon(Icons.mouse),
											const SizedBox(width: 8),
											Expanded(
												child: Text('Hover popup delay: ${settings.hoverPopupDelayMilliseconds} ms')
											)
										]
									),
									Padding(
										padding: const EdgeInsets.all(16),
										child: Slider.adaptive(
											min: 0,
											max: 1000,
											divisions: 20,
											value: settings.hoverPopupDelayMilliseconds.toDouble(),
											onChanged: (newValue) {
												settings.hoverPopupDelayMilliseconds = newValue.toInt();
											}
										)
									),
									const SizedBox(height: 16),
									const Row(
										children: [
											Icon(CupertinoIcons.chevron_right_2),
											SizedBox(width: 8),
											Expanded(
												child: Text('Quotelink click behavior')
											)
										]
									),
									const SizedBox(height: 16),
									AdaptiveChoiceControl<MouseModeQuoteLinkBehavior>(
										children: const {
											MouseModeQuoteLinkBehavior.expandInline: (null, 'Expand inline'),
											MouseModeQuoteLinkBehavior.scrollToPost: (null, 'Scroll to post'),
											MouseModeQuoteLinkBehavior.popupPostsPage: (null, 'Popup')
										},
										groupValue: settings.mouseModeQuoteLinkBehavior,
										onValueChanged: (newValue) {
											settings.mouseModeQuoteLinkBehavior = newValue;
										}
									),
									const SizedBox(height: 32),
								]
							);
						}
					)
				),
				const Row(
					children: [
						Icon(CupertinoIcons.macwindow),
						SizedBox(width: 8),
						Expanded(
							child: Text('Interface Style')
						)
					]
				),
				const SizedBox(height: 16),
				AdaptiveChoiceControl<bool>(
					children: const {
						false: (Icons.apple, 'iOS'),
						true: (Icons.android, 'Android')
					},
					groupValue: settings.materialStyle,
					onValueChanged: (newValue) {
						settings.materialStyle = newValue;
					}
				),
				const SizedBox(height: 32),
				const Row(
					children: [
						Icon(CupertinoIcons.macwindow),
						SizedBox(width: 8),
						Expanded(
							child: Text('Navigation Style')
						)
					]
				),
				const SizedBox(height: 16),
				AdaptiveChoiceControl<bool>(
					children: const {
						false: (CupertinoIcons.squares_below_rectangle, 'Bottom bar'),
						true: (CupertinoIcons.sidebar_left, 'Side drawer')
					},
					groupValue: settings.androidDrawer,
					onValueChanged: (newValue) {
						settings.androidDrawer = newValue;
					}
				),
				const SizedBox(height: 32),
				IgnorePointer(
					ignoring: !settings.androidDrawer,
					child: Opacity(
						opacity: settings.androidDrawer ? 1.0 : 0.5,
						child: Row(
							children: [
								const Icon(CupertinoIcons.sidebar_left),
								const SizedBox(width: 8),
								const Text('Drawer permanently visible'),
								const SizedBox(width: 8),
								const _SettingsHelpButton(
									helpText: 'The drawer will always be on the left side if there is enough space. On devices with a hinge, the drawer will size itself to fill the left screen.'
								),
								const Spacer(),
								AdaptiveSwitch(
									value: settings.persistentDrawer,
									onChanged: (v) {
										settings.persistentDrawer = v;
									}
								)
							]
						)
					)
				),
				const SizedBox(height: 32),
				const Row(
					children: [
						Icon(CupertinoIcons.doc),
						SizedBox(width: 8),
						Flexible(
							child: Text('Page Style')
						),
						SizedBox(width: 8),
						_SettingsHelpButton(
							helpText: 'The animations and gestural behaviour when new interface pages open on top of others'
						)
					]
				),
				const SizedBox(height: 16),
				AdaptiveChoiceControl<bool>(
					children: const {
						false: (Icons.apple, 'iOS'),
						true: (Icons.android, 'Android')
					},
					groupValue: settings.materialRoutes,
					onValueChanged: (newValue) {
						settings.materialRoutes = newValue;
					}
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.wand_rays),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Animations')
						),
						AdaptiveSwitch(
							value: settings.showAnimations,
							onChanged: (newValue) {
								settings.showAnimations = newValue;
							}
						)
					]
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.textformat_alt),
						const SizedBox(width: 8),
						Text('Font: ${settings.fontFamily ?? 'default'}'),
						if (fontLoadingError != null) Padding(
							padding: const EdgeInsets.only(left: 4),
							child: AdaptiveIconButton(
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
							)
						),
						Expanded(
							child: Row(
								mainAxisAlignment: MainAxisAlignment.end,
								children: [
									Flexible(
										child: Padding(
											padding: const EdgeInsets.only(left: 16),
											child: AdaptiveFilledButton(
												padding: const EdgeInsets.all(8),
												onPressed: () async {
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
																			Navigator.pop(context, await getInstalledFontFamilies());
																		}
																		catch (e) {
																			if (context.mounted) {
																				alertError(context, e.toStringDio());
																			}
																		}
																	}
																),
																AdaptiveDialogAction(
																	child: const Text('Google Fonts'),
																	onPressed: () => Navigator.pop(context, allowedGoogleFonts.keys.toList())
																),
																AdaptiveDialogAction(
																	child: const Text('Pick .ttf file...'),
																	onPressed: () async {
																		try {
																			final pickerResult = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['ttf']);
																			final path = pickerResult?.files.tryFirst?.path;
																			if (path == null) {
																				return;
																			}
																			final basename = path.split('/').last;
																			final ttfFolder = await Directory('${Persistence.documentsDirectory.path}/ttf').create();
																			await File(path).copy('${ttfFolder.path}/$basename');
																			if (context.mounted) {
																				Navigator.pop(context, [basename]);
																			}
																		}
																		catch (e, st) {
																			Future.error(e, st);
																			if (context.mounted) {
																				alertError(context, e.toStringDio());
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
													if (!mounted || availableFonts == null) {
														return;
													}
													if (availableFonts.isEmpty) {
														if (settings.fontFamily?.endsWith('.ttf') ?? false) {
															// Cleanup previous picked .ttf
															try {
																await File('${Persistence.documentsDirectory.path}/ttf/${settings.fontFamily}').delete();
															}
															catch (e, st) {
																Future.error(e, st);
																if (mounted) {
																	alertError(context, e.toStringDio());
																}
															}
														}
														settings.fontFamily = null;
														fontLoadingError = null;
														settings.handleThemesAltered();
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
																		separatorBuilder: (context, i) => Divider(
																			height: 0,
																			thickness: 0,
																			color: dividerColor
																		),
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
														final oldFont = settings.fontFamily;
														settings.fontFamily = selectedFont;
														if (oldFont != selectedFont && (oldFont?.endsWith('.ttf') ?? false)) {
															// Cleanup previous picked .ttf
															try {
																await File('${Persistence.documentsDirectory.path}/ttf/$oldFont').delete();
															}
															catch (e, st) {
																Future.error(e, st);
																if (mounted) {
																	alertError(context, e.toStringDio());
																}
															}
														}
														if (selectedFont.endsWith('.ttf')) {
															await initializeFonts();
														}
														else {
															fontLoadingError = null;
														}
														settings.handleThemesAltered();
													}
												},
												child: const Text('Pick font')
											)
										)
									),
								]
							)
						)
					]
				),
				const SizedBox(height: 32),
				const Row(
					children: [
						Icon(CupertinoIcons.paintbrush),
						SizedBox(width: 8),
						Expanded(
							child: Text('Active Theme')
						)
					]
				),
				const SizedBox(height: 16),
				AdaptiveSegmentedControl<TristateSystemSetting>(
					children: const {
						TristateSystemSetting.a: (CupertinoIcons.sun_max, 'Light'),
						TristateSystemSetting.system: (null, 'Follow System'),
						TristateSystemSetting.b: (CupertinoIcons.moon, 'Dark')
					},
					groupValue: settings.themeSetting,
					onValueChanged: (newValue) {
						settings.themeSetting = newValue;
					}
				),
				for (final theme in [
					('light theme', settings.lightTheme, settings.lightThemeKey, (key) {
						settings.lightThemeKey = key;
						settings.handleThemesAltered();
					}, CupertinoIcons.sun_max),
					('dark theme', settings.darkTheme, settings.darkThemeKey, (key) {
						settings.darkThemeKey = key;
						settings.handleThemesAltered();
					}, CupertinoIcons.moon)
				]) ... [
					Row(
						children: [
							const SizedBox(width: 16),
							Icon(theme.$5),
							const SizedBox(width: 8),
							Text(theme.$3),
							const SizedBox(width: 16),
							Expanded(
								child: Row(
									mainAxisAlignment: MainAxisAlignment.end,
									children: [
										Flexible(
											child: Padding(
												padding: const EdgeInsets.all(16),
												child: AdaptiveFilledButton(
													padding: const EdgeInsets.all(8),
													onPressed: () async {
														final selectedKey = await selectThemeKey(
															context: context,
															title: 'Picking ${theme.$1}',
															currentKey: theme.$3,
															allowEditing: true
														);
														if (selectedKey != null) {
															theme.$4(selectedKey);
														}
													},
													child: Text('Pick ${theme.$1}', textAlign: TextAlign.center)
												)
											)
										)
									]
								)
							)
						]
					),
					Container(
						margin: const EdgeInsets.only(left: 16, right: 16),
						decoration: BoxDecoration(
							color: theme.$2.barColor,
							borderRadius: const BorderRadius.all(Radius.circular(8))
						),
						child: SingleChildScrollView(
							scrollDirection: Axis.horizontal,
							child: Row(
								children: <(String, Color, ValueChanged<Color>, Color?)>[
									('Primary', theme.$2.primaryColor, (c) => theme.$2.primaryColor = c, theme.$2.copiedFrom?.primaryColor),
									('Secondary', theme.$2.secondaryColor, (c) => theme.$2.secondaryColor = c, theme.$2.copiedFrom?.secondaryColor),
									('Bar', theme.$2.barColor, (c) => theme.$2.barColor = c, theme.$2.copiedFrom?.barColor),
									('Background', theme.$2.backgroundColor, (c) => theme.$2.backgroundColor = c, theme.$2.copiedFrom?.backgroundColor),
									('Quote', theme.$2.quoteColor, (c) => theme.$2.quoteColor = c, theme.$2.copiedFrom?.quoteColor),
									('Title', theme.$2.titleColor, (c) => theme.$2.titleColor = c, theme.$2.copiedFrom?.titleColor),
									('Text Field', theme.$2.textFieldColor, (c) => theme.$2.textFieldColor = c, theme.$2.copiedFrom?.textFieldColor)
								].map((color) => Column(
									mainAxisSize: MainAxisSize.min,
									children: [
										const SizedBox(height: 16),
										Text(color.$1, style: TextStyle(color: theme.$2.primaryColor)),
										const SizedBox(height: 16),
										CupertinoButton(
											padding: EdgeInsets.zero,
											child: Container(
												decoration: BoxDecoration(
													borderRadius: const BorderRadius.all(Radius.circular(8)),
													border: Border.all(color: color.$2 == theme.$2.primaryColor ? theme.$2.barColor : theme.$2.primaryColor),
													color: color.$2
												),
												width: 50,
												height: 50,
												child: theme.$2.locked ? Icon(CupertinoIcons.lock, color: color.$2 == theme.$2.primaryColor ? theme.$2.barColor : theme.$2.primaryColor) : null
											),
											onPressed: () async {
												if (theme.$2.locked) {
													alertError(context, 'This theme is locked. Make a copy of it if you want to change its colours.');
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
																						settings.handleThemesAltered();
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
												settings.handleThemesAltered();
											}
										),
										SizedBox(width: 88 * settings.textScale, height: 24)
									]
								)).toList()
							)
						)
					)
				],
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.resize),
						const SizedBox(width: 8),
						Expanded(
							child: Text('Thumbnail size: ${settings.thumbnailSize.round()}x${settings.thumbnailSize.round()}')
						)
					]
				),
				Padding(
					padding: const EdgeInsets.all(16),
					child: Slider.adaptive(
						min: 50,
						max: 400,
						divisions: 70,
						value: settings.thumbnailSize,
						onChanged: (newValue) {
							settings.thumbnailSize = newValue;
						}
					)
				),
				Row(
					children: [
						const Icon(CupertinoIcons.list_bullet_below_rectangle),
						const SizedBox(width: 8),
						Expanded(
							child: Text.rich(
								TextSpan(
									children: [
										const TextSpan(text: 'Centered post thumbnails\n'),
										TextSpan(text: 'Size: ${settings.centeredPostThumbnailSizeSetting.abs().round()}x${settings.centeredPostThumbnailSizeSetting.abs().round()}', style: TextStyle(
											color: settings.centeredPostThumbnailSizeSetting.isNegative ? ChanceTheme.primaryColorWithBrightness50Of(context) : ChanceTheme.primaryColorWithBrightness80Of(context)
										))
									]
								)
							)
						),
						AdaptiveSwitch(
							value: !settings.centeredPostThumbnailSizeSetting.isNegative,
							onChanged: (newValue) {
								settings.centeredPostThumbnailSizeSetting = settings.centeredPostThumbnailSizeSetting.abs() * (newValue ? 1 : -1);
							}
						)
					]
				),
				Padding(
					padding: const EdgeInsets.all(16),
					child: Slider.adaptive(
						min: 100,
						max: 1000,
						divisions: 36,
						value: settings.centeredPostThumbnailSizeSetting.abs(),
						onChanged: settings.centeredPostThumbnailSizeSetting.isNegative ? null : (newValue) {
							settings.centeredPostThumbnailSizeSetting = newValue;
						}
					)
				),
				const SizedBox(height: 16),
				Row(
					children: [
						const Icon(CupertinoIcons.brightness),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('New post highlight brightness')
						),
						Container(
							color: theme.primaryColorWithBrightness(settings.newPostHighlightBrightness),
							padding: const EdgeInsets.all(8),
							child: const Text('Example new post')
						)
					]
				),
				Padding(
					padding: const EdgeInsets.all(16),
					child: Slider.adaptive(
						min: 0,
						max: 0.5,
						divisions: 50,
						value: settings.newPostHighlightBrightness,
						onChanged: (newValue) {
							settings.newPostHighlightBrightness = newValue;
						}
					)
				),
				const Row(
					children: [
						Icon(CupertinoIcons.square_fill_line_vertical_square),
						SizedBox(width: 8),
						Expanded(
							child: Text('Thumbnail location')
						)
					]
				),
				const SizedBox(height: 16),
				AdaptiveSegmentedControl<bool>(
					children: const {
						false: (null, 'Left'),
						true: (null, 'Right')
					},
					groupValue: settings.imagesOnRight,
					onValueChanged: (newValue) {
						settings.imagesOnRight = newValue;
					}
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.eyeglasses),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Blur image thumbnails')
						),
						AdaptiveSwitch(
							value: settings.blurThumbnails,
							onChanged: (newValue) {
								settings.blurThumbnails = newValue;
							}
						)
					]
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.square),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Square thumbnails')
						),
						AdaptiveSwitch(
							value: settings.squareThumbnails,
							onChanged: (newValue) {
								settings.squareThumbnails = newValue;
							}
						)
					]
				),
				const SizedBox(height: 32),
				Center(
					child: AdaptiveFilledButton(
						padding: const EdgeInsets.all(16),
						child: const Row(
							mainAxisSize: MainAxisSize.min,
							children: [
								Icon(CupertinoIcons.square_list),
								SizedBox(width: 8),
								Text('Edit post details')
							]
						),
						onPressed: () async {
							await showAdaptiveModalPopup(
								context: context,
								useRootNavigator: false,
								builder: (context) => StatefulBuilder(
									builder: (context, setDialogState) {
										final settings = context.watch<EffectiveSettings>();
										return AdaptiveActionSheet(
											title: const Text('Edit post details'),
											actions: [
												AdaptiveActionSheetAction(
													child: const Text('Close'),
													onPressed: () => Navigator.pop(context)
												)
											],
											message: DefaultTextStyle(
												style: DefaultTextStyle.of(context).style,
												child: Column(
													children: [
														Container(
															height: 200,
															decoration: threadAndPostRowDecoration,
															child: IgnorePointer(
																child: ClipRect(
																	child: _buildFakePostRow()
																)
															)
														),
														Row(
															children: [
																const Text('Clover-style replies button'),
																const Spacer(),
																AdaptiveSwitch(
																	value: settings.cloverStyleRepliesButton,
																	onChanged: (d) => settings.cloverStyleRepliesButton = d
																)
															]
														),
														Row(
															children: [
																const Text('Show Post #'),
																const Spacer(),
																AdaptiveSwitch(
																	value: settings.showPostNumberOnPosts,
																	onChanged: (d) => settings.showPostNumberOnPosts = d
																)
															]
														),
														Row(
															children: [
																const Text('Show IP address #'),
																const Spacer(),
																AdaptiveSwitch(
																	value: settings.showIPNumberOnPosts,
																	onChanged: (d) => settings.showIPNumberOnPosts = d
																)
															]
														),
														Row(
															children: [
																const Text('Show name'),
																const Spacer(),
																AdaptiveSwitch(
																	value: settings.showNameOnPosts,
																	onChanged: (d) => settings.showNameOnPosts = d
																)
															]
														),
														Row(
															children: [
																const Text('Hide default names'),
																const Spacer(),
																AdaptiveSwitch(
																	value: settings.hideDefaultNamesOnPosts,
																	onChanged: (d) => settings.hideDefaultNamesOnPosts = d
																)
															]
														),
														Row(
															children: [
																const Text('Show trip'),
																const Spacer(),
																AdaptiveSwitch(
																	value: settings.showTripOnPosts,
																	onChanged: (d) => settings.showTripOnPosts = d
																)
															]
														),
														Row(
															children: [
																const Text('Show filename'),
																const Spacer(),
																AdaptiveSwitch(
																	value: settings.showFilenameOnPosts,
																	onChanged: (d) => settings.showFilenameOnPosts = d
																)
															]
														),
														Row(
															children: [
																const Text('Truncate long filenames'),
																const Spacer(),
																AdaptiveSwitch(
																	value: settings.ellipsizeLongFilenamesOnPosts,
																	onChanged: (d) => settings.ellipsizeLongFilenamesOnPosts = d
																)
															]
														),
														Row(
															children: [
																const Text('Show filesize'),
																const Spacer(),
																AdaptiveSwitch(
																	value: settings.showFilesizeOnPosts,
																	onChanged: (d) => settings.showFilesizeOnPosts = d
																)
															]
														),
														Row(
															children: [
																const Text('Show file dimensions'),
																const Spacer(),
																AdaptiveSwitch(
																	value: settings.showFileDimensionsOnPosts,
																	onChanged: (d) => settings.showFileDimensionsOnPosts = d
																)
															]
														),
														Row(
															children: [
																const Text('Show pass'),
																const Spacer(),
																AdaptiveSwitch(
																	value: settings.showPassOnPosts,
																	onChanged: (d) => settings.showPassOnPosts = d
																)
															]
														),
														Row(
															children: [
																const Text('Show flag'),
																const Spacer(),
																AdaptiveSwitch(
																	value: settings.showFlagOnPosts,
																	onChanged: (d) => settings.showFlagOnPosts = d
																)
															]
														),
														Row(
															children: [
																const Text('Show country name'),
																const Spacer(),
																AdaptiveSwitch(
																	value: settings.showCountryNameOnPosts,
																	onChanged: (d) => settings.showCountryNameOnPosts = d
																)
															]
														),
														Row(
															children: [
																const Text('Show exact time'),
																const Spacer(),
																AdaptiveSwitch(
																	value: settings.showAbsoluteTimeOnPosts,
																	onChanged: (d) => settings.showAbsoluteTimeOnPosts = d
																)
															]
														),
														Row(
															children: [
																const Text('Show relative time'),
																const Spacer(),
																AdaptiveSwitch(
																	value: settings.showRelativeTimeOnPosts,
																	onChanged: (d) => settings.showRelativeTimeOnPosts = d
																)
															]
														),
														Row(
															children: [
																const Text('Show "No." before ID'),
																const Spacer(),
																AdaptiveSwitch(
																	value: settings.showNoBeforeIdOnPosts,
																	onChanged: (d) => settings.showNoBeforeIdOnPosts = d
																)
															]
														),
														Row(
															children: [
																const Text('Include line break'),
																const Spacer(),
																AdaptiveSwitch(
																	value: settings.showLineBreakInPostInfoRow,
																	onChanged: (d) => settings.showLineBreakInPostInfoRow = d
																)
															]
														),
														Row(
															children: [
																const Text('Highlight dubs (etc)'),
																const Spacer(),
																AdaptiveSwitch(
																	value: settings.highlightRepeatingDigitsInPostIds,
																	onChanged: (d) => settings.highlightRepeatingDigitsInPostIds = d
																)
															]
														),
														AdaptiveFilledButton(
															child: const Text('Adjust order'),
															onPressed: () async {
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
																					children: context.select<EffectiveSettings, List<PostDisplayField>>((s) => s.postDisplayFieldOrder).asMap().entries.map((pair) {
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
																						final list = settings.postDisplayFieldOrder.toList();
																						final item = list.removeAt(oldIndex);
																						list.insert(newIndex, item);
																						settings.postDisplayFieldOrder = list;
																					}
																				)
																			)
																		)
																	)
																);
															}
														)
													]
												)
											)
										);
									}
								)
							);
						}
					)
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.number_square),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Show reply counts in gallery')
						),
						AdaptiveSwitch(
							value: settings.showReplyCountsInGallery,
							onChanged: (newValue) {
								settings.showReplyCountsInGallery = newValue;
							}
						)
					]
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.rectangle_grid_2x2),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Show thumbnails in gallery')
						),
						AdaptiveSwitch(
							value: settings.showThumbnailsInGallery,
							onChanged: (newValue) {
								settings.showThumbnailsInGallery = newValue;
							}
						)
					]
				),
				const SizedBox(height: 32),
				const Row(
					children: [
						Icon(CupertinoIcons.rectangle_stack),
						SizedBox(width: 8),
						Expanded(
							child: Text('Catalog Layout')
						)
					]
				),
				const SizedBox(height: 16),
				Row(
					children: [
						Expanded(
							child: AdaptiveSegmentedControl<bool>(
								children: const {
									false: (CupertinoIcons.rectangle_grid_1x2, 'Rows'),
									true: (CupertinoIcons.rectangle_split_3x3, 'Grid')
								},
								groupValue: settings.useCatalogGrid,
								onValueChanged: (newValue) {
									settings.useCatalogGrid = newValue;
								}
							)
						),
						if (ImageboardRegistry.instance.count > 1) AdaptiveIconButton(
							minSize: 0,
							onPressed: () => showAdaptiveModalPopup(
								context: context,
								builder: (context) => StatefulBuilder(
									builder: (context, setDialogState) => AdaptiveActionSheet(
										title: const Text('Per-Site Catalog Layout'),
										message: Column(
											mainAxisSize: MainAxisSize.min,
											children: [
												for (final imageboard in ImageboardRegistry.instance.imageboards) ...[
													Row(
														mainAxisSize: MainAxisSize.min,
														children: [
															ImageboardIcon(
																imageboardKey: imageboard.key
															),
															const SizedBox(width: 8),
															Text(imageboard.site.name)
														]
													),
													const SizedBox(height: 8),
													AdaptiveChoiceControl(
														groupValue: imageboard.persistence.browserState.useCatalogGrid.value,
														knownWidth: MediaQuery.sizeOf(context).width,
														children: {
															NullSafeOptional.false_: (CupertinoIcons.rectangle_grid_1x2, 'Rows'),
															NullSafeOptional.null_: (null, 'Default (${settings.useCatalogGrid ? 'Grid' : 'Rows'})'),
															NullSafeOptional.true_: (CupertinoIcons.rectangle_split_3x3, 'Grid'),
														},
														onValueChanged: (v) {
															imageboard.persistence.browserState.useCatalogGrid = v.value;
															imageboard.persistence.didUpdateBrowserState();
															setDialogState(() {});
														},
													),
													const SizedBox(height: 16),
												]
											]
										),
										actions: [
											AdaptiveActionSheetAction(
												onPressed: () => Navigator.pop(context),
												child: const Text('Close')
											)
										]
									)
								)
							),
							icon: const Icon(CupertinoIcons.settings)
						)
					]
				),
				const SizedBox(height: 16),
				Row(
					children: [
						const SizedBox(width: 16),
						const Expanded(
							child: Text('Show counters in their own row'),
						),
						AdaptiveSwitch(
							value: settings.useFullWidthForCatalogCounters,
							onChanged: (d) => settings.useFullWidthForCatalogCounters = d
						),
						const SizedBox(width: 16)
					]
				),
				const SizedBox(height: 16),
				Center(
					child: settings.useCatalogGrid ? AdaptiveFilledButton(
						padding: const EdgeInsets.all(16),
						child: const Row(
							mainAxisSize: MainAxisSize.min,
							children: [
								Icon(CupertinoIcons.resize),
								SizedBox(width: 8),
								Text('Edit catalog grid item layout')
							]
						),
						onPressed: () async {
							Size size = Size(settings.catalogGridWidth, settings.catalogGridHeight);
							await showAdaptiveModalPopup(
								context: context,
								useRootNavigator: false,
								builder: (context) => StatefulBuilder(
									builder: (context, setDialogState) => AdaptiveActionSheet(
										title: const Text('Edit catalog grid item layout'),
										actions: [
											AdaptiveActionSheetAction(
												child: const Text('Close'),
												onPressed: () => Navigator.pop(context)
											)
										],
										message: DefaultTextStyle(
											style: DefaultTextStyle.of(context).style,
											child: Column(
												crossAxisAlignment: CrossAxisAlignment.start,
												children: [
													Text('Width: ${size.width.round()}px'),
													Row(
														mainAxisAlignment: MainAxisAlignment.end,
														children: [
															SizedBox(
																width: 150,
																child: Slider.adaptive(
																	value: size.width,
																	min: 100,
																	max: 600,
																	onChanged: (d) {
																		setDialogState(() {
																			size = Size(d, size.height);
																		});
																	}
																)
															),
															AdaptiveIconButton(
																onPressed: size.width <= 100 ? null : () {
																	setDialogState(() {
																		size = Size(size.width - 1, size.height);
																	});
																},
																icon: const Icon(CupertinoIcons.minus)
															),
															AdaptiveIconButton(
																onPressed: size.width >= 600 ? null : () {
																	setDialogState(() {
																		size = Size(size.width + 1, size.height);
																	});
																},
																icon: const Icon(CupertinoIcons.plus)
															)
														]
													),
													const SizedBox(height: 8),
													Text('Height: ${size.height.round()}px'),
													Row(
														mainAxisAlignment: MainAxisAlignment.end,
														children: [
															SizedBox(
																width: 150,
																child: Slider.adaptive(
																	value: size.height,
																	min: 100,
																	max: 600,
																	onChanged: (d) {
																		setDialogState(() {
																			size = Size(size.width, d);
																		});
																	}
																)
															),
															AdaptiveIconButton(
																onPressed: size.height <= 100 ? null : () {
																	setDialogState(() {
																		size = Size(size.width, size.height - 1);
																	});
																},
																icon: const Icon(CupertinoIcons.minus)
															),
															AdaptiveIconButton(
																onPressed: size.height >= 600 ? null : () {
																	setDialogState(() {
																		size = Size(size.width, size.height + 1);
																	});
																},
																icon: const Icon(CupertinoIcons.plus)
															)
														]
													),
													const SizedBox(height: 8),
													Text('Maximum text lines: ${settings.catalogGridModeTextLinesLimit?.toString() ?? 'Unlimited'}'),
													Row(
														mainAxisAlignment: MainAxisAlignment.end,
														children: [
															AdaptiveButton(
																padding: const EdgeInsets.only(left: 8, right: 8),
																onPressed: settings.catalogGridModeTextLinesLimit == null ? null : () {
																	setDialogState(() {
																		settings.catalogGridModeTextLinesLimit = null;
																	});
																},
																child: const Text('Reset')
															),
															AdaptiveIconButton(
																onPressed: (settings.catalogGridModeTextLinesLimit ?? 2) <= 1 ? null : () {
																	setDialogState(() {
																		settings.catalogGridModeTextLinesLimit = (settings.catalogGridModeTextLinesLimit ?? (settings.catalogGridHeight / (2 * MediaQuery.textScalerOf(context).scale(14))).round()) - 1;
																	});
																},
																icon: const Icon(CupertinoIcons.minus)
															),
															AdaptiveIconButton(
																onPressed: () {
																	setDialogState(() {
																		settings.catalogGridModeTextLinesLimit = (settings.catalogGridModeTextLinesLimit ?? 0) + 1;
																	});
																},
																icon: const Icon(CupertinoIcons.plus)
															)
														]
													),
													const SizedBox(height: 8),
													Row(
														children: [
															const Expanded(
																child: Text('Thumbnail behind text')
															),
															AdaptiveSwitch(
																value: settings.catalogGridModeAttachmentInBackground,
																onChanged: (v) {
																	setDialogState(() {
																		settings.catalogGridModeAttachmentInBackground = v;
																	});
																}
															)
														]
													),
													const SizedBox(height: 8),
													Row(
														children: [
															const Expanded(
																child: Text('Rounded corners and margin')
															),
															AdaptiveSwitch(
																value: settings.catalogGridModeCellBorderRadiusAndMargin,
																onChanged: (v) {
																	setDialogState(() {
																		settings.catalogGridModeCellBorderRadiusAndMargin = v;
																	});
																}
															)
														]
													),
													const SizedBox(height: 8),
													Row(
														children: [
															const Expanded(
																child: Text('Show more image if text is short')
															),
															AdaptiveSwitch(
																value: settings.catalogGridModeShowMoreImageIfLessText,
																onChanged: settings.catalogGridModeAttachmentInBackground ? null : (v) {
																	setDialogState(() {
																		settings.catalogGridModeShowMoreImageIfLessText = v;
																	});
																}
															)
														]
													),
													const SizedBox(height: 8),
													Container(
														width: size.width,
														height: size.height,
														decoration: threadAndPostRowDecoration,
														child: ThreadRow(
															contentFocus: true,
															contentFocusBorderRadiusAndPadding: settings.catalogGridModeCellBorderRadiusAndMargin,
															isSelected: false,
															thread: _makeFakeThread()
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
					) : AdaptiveFilledButton(
						padding: const EdgeInsets.all(16),
						child: const Row(
							mainAxisSize: MainAxisSize.min,
							children: [
								Icon(CupertinoIcons.resize_v),
								SizedBox(width: 8),
								Text('Edit catalog row item layout')
							]
						),
						onPressed: () async {
							await showAdaptiveModalPopup(
								context: context,
								useRootNavigator: false,
								builder: (context) => StatefulBuilder(
									builder: (context, setDialogState) => AdaptiveActionSheet(
										title: const Text('Edit catalog row item layout'),
										actions: [
											AdaptiveActionSheetAction(
												child: const Text('Close'),
												onPressed: () => Navigator.pop(context)
											)
										],
										message: DefaultTextStyle(
											style: DefaultTextStyle.of(context).style,
											child: Column(
												//crossAxisAlignment: CrossAxisAlignment.start,
												children: [
													Container(
														height: settings.maxCatalogRowHeight,
														decoration: threadAndPostRowDecoration,
														child: ClipRect(
															child: ThreadRow(
																contentFocus: false,
																isSelected: false,
																thread: _makeFakeThread(),
																showLastReplies: settings.showLastRepliesInCatalog
															)
														)
													),
													const SizedBox(height: 8),
													Row(
														children: [
															const Expanded(
																child: Text('Show last replies')
															),
															AdaptiveSwitch(
																value: settings.showLastRepliesInCatalog,
																onChanged: (d) {
																	settings.showLastRepliesInCatalog = d;
																	setDialogState(() {});
																}
															)
														]
													),
													const SizedBox(height: 8),
													Text('Height: ${settings.maxCatalogRowHeight.round()}px'),
													Row(
														mainAxisAlignment: MainAxisAlignment.end,
														children: [
															SizedBox(
																width: 150,
																child: Slider.adaptive(
																	value: settings.maxCatalogRowHeight,
																	min: 100,
																	max: 600,
																	onChanged: (d) {
																		setDialogState(() {
																			settings.maxCatalogRowHeight = d;
																		});
																	}
																)
															),
															AdaptiveIconButton(
																onPressed: settings.maxCatalogRowHeight <= 100 ? null : () {
																	setDialogState(() {
																		settings.maxCatalogRowHeight--;
																	});
																},
																icon: const Icon(CupertinoIcons.minus)
															),
															AdaptiveIconButton(
																onPressed: settings.maxCatalogRowHeight >= 600 ? null : () {
																	setDialogState(() {
																		settings.maxCatalogRowHeight++;
																	});
																},
																icon: const Icon(CupertinoIcons.plus)
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
				const SizedBox(height: 16),
				Center(
					child: AdaptiveFilledButton(
						padding: const EdgeInsets.all(16),
						child: const Row(
							mainAxisSize: MainAxisSize.min,
							children: [
								Icon(CupertinoIcons.square_list),
								SizedBox(width: 8),
								Text('Edit catalog item details')
							]
						),
						onPressed: () async {
							await showAdaptiveModalPopup(
								context: context,
								useRootNavigator: false,
								builder: (context) => StatefulBuilder(
									builder: (context, setDialogState) {
										final settings = context.watch<EffectiveSettings>();
										return AdaptiveActionSheet(
											title: const Text('Edit catalog item details'),
											actions: [
												AdaptiveActionSheetAction(
													child: const Text('Close'),
													onPressed: () => Navigator.pop(context)
												)
											],
											message: DefaultTextStyle(
												style: DefaultTextStyle.of(context).style,
												child: Column(
													children: [
														Container(
															height: 100,
															decoration: threadAndPostRowDecoration,
															child: _buildFakeThreadRow(contentFocus: false)
														),
														const SizedBox(height: 16),
														Align(
															alignment: Alignment.topLeft,
															child: Container(
																width: settings.catalogGridWidth,
																height: settings.catalogGridHeight,
																decoration: threadAndPostRowDecoration,
																child: _buildFakeThreadRow()
															)
														),
														Row(
															children: [
																const Text('Show image count'),
																const Spacer(),
																AdaptiveSwitch(
																	value: settings.showImageCountInCatalog,
																	onChanged: (d) => settings.showImageCountInCatalog = d
																)
															]
														),
														Row(
															children: [
																const Text('Show clock icon'),
																const Spacer(),
																AdaptiveSwitch(
																	value: settings.showClockIconInCatalog,
																	onChanged: (d) => settings.showClockIconInCatalog = d
																)
															]
														),
														Row(
															children: [
																const Text('Show name'),
																const Spacer(),
																AdaptiveSwitch(
																	value: settings.showNameInCatalog,
																	onChanged: (d) => settings.showNameInCatalog = d
																)
															]
														),
														Row(
															children: [
																const Text('Hide default names'),
																const Spacer(),
																AdaptiveSwitch(
																	value: settings.hideDefaultNamesInCatalog,
																	onChanged: (d) => settings.hideDefaultNamesInCatalog = d
																)
															]
														),
														Row(
															children: [
																const Text('Show exact time'),
																const Spacer(),
																AdaptiveSwitch(
																	value: settings.showTimeInCatalogHeader,
																	onChanged: (d) => settings.showTimeInCatalogHeader = d
																)
															]
														),
														Row(
															children: [
																const Text('Show relative time'),
																const Spacer(),
																AdaptiveSwitch(
																	value: settings.showTimeInCatalogStats,
																	onChanged: (d) => settings.showTimeInCatalogStats = d
																)
															]
														),
														Row(
															children: [
																const Text('Show ID'),
																const Spacer(),
																AdaptiveSwitch(
																	value: settings.showIdInCatalogHeader,
																	onChanged: (d) => settings.showIdInCatalogHeader = d
																)
															]
														),
														Row(
															children: [
																const Text('Show flag'),
																const Spacer(),
																AdaptiveSwitch(
																	value: settings.showFlagInCatalogHeader,
																	onChanged: (d) => settings.showFlagInCatalogHeader = d
																)
															]
														),
														Row(
															children: [
																const Text('Show country name'),
																const Spacer(),
																AdaptiveSwitch(
																	value: settings.showCountryNameInCatalogHeader,
																	onChanged: (d) => settings.showCountryNameInCatalogHeader = d
																)
															]
														)
													]
												)
											)
										);
									}
								)
							);
						}
					)
				),
				const SizedBox(height: 16),
				Row(
					children: [
						const Icon(CupertinoIcons.lightbulb_slash),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Dim read threads in catalog')
						),
						AdaptiveSwitch(
							value: settings.dimReadThreads,
							onChanged: (newValue) {
								settings.dimReadThreads = newValue;
							}
						)
					]
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.sidebar_left),
						const SizedBox(width: 8),
						Flexible(
							child: Text('Two-pane breakpoint: ${settings.twoPaneBreakpoint.round()} pixels')
						),
						const SizedBox(width: 8),
						_SettingsHelpButton(
							helpText: 'When the screen is at least ${settings.twoPaneBreakpoint.round()} pixels wide, two columns will be used.\nThe board catalog will be on the left and the current thread will be on the right.'
						)
					]
				),
				Padding(
					padding: const EdgeInsets.all(16),
					child: Slider.adaptive(
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
				Row(
					children: [
						const Icon(CupertinoIcons.sidebar_left),
						const SizedBox(width: 8),
						Expanded(
							child: Text('Two-pane split: ${firstPanePercent.toStringAsFixed(0)}% catalog, ${(100 - firstPanePercent).toStringAsFixed(0)}% thread')
						)
					]
				),
				Padding(
					padding: const EdgeInsets.all(16),
					child: Slider.adaptive(
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
				Row(
					children: [
						const RotatedBox(
							quarterTurns: 1,
							child: Icon(CupertinoIcons.sidebar_left)
						),
						const SizedBox(width: 8),
						Expanded(
							child: Text.rich(
								TextSpan(
									children: [
										const TextSpan(text: 'Vertical two-pane split\n'),
										TextSpan(text: 'Minimum pane height: ${settings.verticalTwoPaneMinimumPaneSize.abs().round()} px', style: TextStyle(
											color: settings.verticalTwoPaneMinimumPaneSize.isNegative ? ChanceTheme.primaryColorWithBrightness50Of(context) : ChanceTheme.primaryColorWithBrightness80Of(context)
										))
									]
								)
							)
						),
						AdaptiveSwitch(
							value: !settings.verticalTwoPaneMinimumPaneSize.isNegative,
							onChanged: (newValue) {
								settings.verticalTwoPaneMinimumPaneSize = settings.verticalTwoPaneMinimumPaneSize.abs() * (newValue ? 1 : -1);
							}
						)
					]
				),
				Padding(
					padding: const EdgeInsets.all(16),
					child: Slider.adaptive(
						min: 100,
						max: 1000,
						divisions: 36,
						value: settings.verticalTwoPaneMinimumPaneSize.abs(),
						onChanged: settings.verticalTwoPaneMinimumPaneSize.isNegative ? null : (newValue) {
							settings.verticalTwoPaneMinimumPaneSize = newValue;
						}
					)
				),
				const SizedBox(height: 16),
				const Row(
					children: [
						Icon(CupertinoIcons.arrow_up_down),
						SizedBox(width: 8),
						Expanded(
							child: Text('Scrollbar location')
						)
					]
				),
				const SizedBox(height: 16),
				AdaptiveSegmentedControl<(bool, bool?)>(
					children: const {
						(true, true): (null, 'Left'),
						(false, null): (null, 'Off'),
						(true, false): (null, 'Right')
					},
					groupValue: (settings.showScrollbars, settings.showScrollbars ? settings.scrollbarsOnLeft : null),
					onValueChanged: (newValue) {
						settings.showScrollbars = newValue.$1;
						if (newValue.$2 != null) {
							settings.scrollbarsOnLeft = newValue.$2!;
						}
					}
				),
				const SizedBox(height: 32),
				Row(
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
						),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('List position indicator location')
						)
					]
				),
				const SizedBox(height: 16),
				AdaptiveSegmentedControl<bool>(
					children: const {
						true: (null, 'Left'),
						false: (null, 'Right')
					},
					groupValue: settings.showListPositionIndicatorsOnLeft,
					onValueChanged: (newValue) {
						settings.showListPositionIndicatorsOnLeft = newValue;
					}
				),
				if (Platform.isAndroid && EffectiveSettings.featureStatusBarWorkaround) ...[
					const SizedBox(height: 32),
					Row(
						children: [
							const Icon(CupertinoIcons.device_phone_portrait),
							const SizedBox(width: 8),
							const Text('Use status bar workaround'),
							const SizedBox(width: 8),
							const _SettingsHelpButton(
								helpText: 'Some devices have a bug in their Android ROM, where the status bar cannot be properly hidden.\n\nIf this workaround is enabled, the status bar will not be hidden when opening the gallery.'
							),
							const Spacer(),
							AdaptiveSwitch(
								value: settings.useStatusBarWorkaround ?? false,
								onChanged: (newValue) {
									settings.useStatusBarWorkaround = newValue;
								}
							)
						]
					)
				],
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.list_bullet_below_rectangle),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Default thread layout')
						),
						AdaptiveFilledButton(
							padding: const EdgeInsets.all(8),
							onPressed: () async {
								final newImageboard = await _pickImageboard(context, _threadLayoutImageboard);
								if (newImageboard != null) {
									setState(() {
										_threadLayoutImageboard = newImageboard;
									});
								}
							},
							child: Row(
								mainAxisSize: MainAxisSize.min,
								children: [
									ImageboardIcon(
										imageboardKey: _threadLayoutImageboard.key
									),
									const SizedBox(width: 8),
									Text(_threadLayoutImageboard.site.name)
								]
							)
						)
					]
				),
				const SizedBox(height: 16),
				AdaptiveSegmentedControl<bool>(
					children: const {
						false: (CupertinoIcons.list_bullet, 'Linear'),
						true: (CupertinoIcons.list_bullet_indent, 'Tree')
					},
					groupValue: _threadLayoutImageboard.persistence.browserState.useTree ?? _threadLayoutImageboard.site.useTree,
					onValueChanged: (newValue) {
						_threadLayoutImageboard.persistence.browserState.useTree = newValue;
						_threadLayoutImageboard.persistence.didUpdateBrowserState();
						setState(() {});
					}
				),
				AnimatedSize(
					duration: const Duration(milliseconds: 250),
					curve: Curves.ease,
					alignment: Alignment.bottomCenter,
					child: (_threadLayoutImageboard.persistence.browserState.useTree ?? _threadLayoutImageboard.site.useTree) ? Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							const SizedBox(height: 16),
							Row(
								children: [
									const SizedBox(width: 16),
									const Icon(CupertinoIcons.return_icon),
									const SizedBox(width: 8),
									const Expanded(
										child: Text('Initially hide nested replies')
									),
									AdaptiveSwitch(
										value: _threadLayoutImageboard.persistence.browserState.treeModeInitiallyCollapseSecondLevelReplies,
										onChanged: (newValue) {
											_threadLayoutImageboard.persistence.browserState.treeModeInitiallyCollapseSecondLevelReplies = newValue;
											_threadLayoutImageboard.persistence.didUpdateBrowserState();
											setState(() {});
										}
									),
									const SizedBox(width: 16)
								]
							),
							const SizedBox(height: 16),
							Row(
								children: [
									const SizedBox(width: 16),
									const RotatedBox(
										quarterTurns: 1,
										child: Icon(CupertinoIcons.chevron_right_2)
									),
									const SizedBox(width: 8),
									const Expanded(
										child: Text('Collapsed posts show body')
									),
									AdaptiveSwitch(
										value: _threadLayoutImageboard.persistence.browserState.treeModeCollapsedPostsShowBody,
										onChanged: (newValue) {
											_threadLayoutImageboard.persistence.browserState.treeModeCollapsedPostsShowBody = newValue;
											_threadLayoutImageboard.persistence.didUpdateBrowserState();
											setState(() {});
										}
									),
									const SizedBox(width: 16)
								]
							),
							const SizedBox(height: 16),
							Row(
								children: [
									const SizedBox(width: 16),
									const Icon(CupertinoIcons.increase_indent),
									const SizedBox(width: 8),
									const Expanded(
										child: Text('Show replies to OP at top level')
									),
									AdaptiveSwitch(
										value: _threadLayoutImageboard.persistence.browserState.treeModeRepliesToOPAreTopLevel,
										onChanged: (newValue) {
											_threadLayoutImageboard.persistence.browserState.treeModeRepliesToOPAreTopLevel = newValue;
											_threadLayoutImageboard.persistence.didUpdateBrowserState();
											setState(() {});
										}
									),
									const SizedBox(width: 16)
								]
							),
							const SizedBox(height: 16),
							Row(
								children: [
									const SizedBox(width: 16),
									const Icon(CupertinoIcons.asterisk_circle),
									const SizedBox(width: 8),
									const Expanded(
										child: Text('New posts inserted at bottom')
									),
									AdaptiveSwitch(
										value: _threadLayoutImageboard.persistence.browserState.treeModeNewRepliesAreLinear,
										onChanged: (newValue) {
											_threadLayoutImageboard.persistence.browserState.treeModeNewRepliesAreLinear = newValue;
											_threadLayoutImageboard.persistence.didUpdateBrowserState();
											setState(() {});
										}
									),
									const SizedBox(width: 16)
								]
							)
						]
					) : const SizedBox(width: double.infinity)
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.wand_stars),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Blur effects')
						),
						AdaptiveSwitch(
							value: settings.blurEffects,
							onChanged: (newValue) {
								settings.blurEffects = newValue;
							}
						)
					]
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.clock),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('12-hour time')
						),
						AdaptiveSwitch(
							value: settings.exactTimeIsTwelveHour,
							onChanged: (newValue) {
								settings.exactTimeIsTwelveHour = newValue;
							}
						)
					]
				),
				const SizedBox(height: 32),
				const Row(
					children: [
						Icon(CupertinoIcons.calendar),
						SizedBox(width: 8),
						Expanded(
							child: Text('Date formatting')
						)
					]
				),
				const SizedBox(height: 16),
				AdaptiveChoiceControl<NullWrapper<String>>(
					children: {
						const NullWrapper(null): (null, 'Default (${DateTime.now().weekdayShortName})'),
						const NullWrapper(DateTimeConversion.kISO8601DateFormat): (null, 'ISO 8601 (${DateTime.now().formatDate(DateTimeConversion.kISO8601DateFormat)})'),
						const NullWrapper('MM/DD/YY'): (null, 'MM/DD/YY (${DateTime.now().formatDate('MM/DD/YY')})'),
						const NullWrapper('DD/MM/YY'): (null, 'DD/MM/YY (${DateTime.now().formatDate('DD/MM/YY')})')
					},
					groupValue: settings.exactTimeUsesCustomDateFormat ? NullWrapper(settings.customDateFormat) : const NullWrapper(null),
					onValueChanged: (newValue) {
						final newFormat = newValue.value;
						if (newFormat == null) {
							settings.exactTimeUsesCustomDateFormat = false;
						}
						else {
							settings.customDateFormat = newFormat;
							settings.exactTimeUsesCustomDateFormat = true;
						}
					}
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.calendar),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Show date even if today')
						),
						AdaptiveSwitch(
							value: settings.exactTimeShowsDateForToday,
							onChanged: (newValue) {
								settings.exactTimeShowsDateForToday = newValue;
							}
						)
					]
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.number_square),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Overlay indicators and buttons in gallery')
						),
						AdaptiveSwitch(
							value: settings.showOverlaysInGallery,
							onChanged: (newValue) {
								settings.showOverlaysInGallery = newValue;
							}
						)
					]
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.square_grid_2x2),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Show gallery grid button in catalog and thread')
						),
						AdaptiveSwitch(
							value: settings.showGalleryGridButton,
							onChanged: (newValue) {
								settings.showGalleryGridButton = newValue;
							}
						)
					]
				),
				const SizedBox(height: 16)
			]
		);
	}
}

class SettingsDataPage extends StatefulWidget {
	const SettingsDataPage({
		Key? key
	}) : super(key: key);

	@override
	createState() => _SettingsDataPageState();
}

class _SettingsDataPageState extends State<SettingsDataPage> {
	@override
	Widget build(BuildContext context) {
		final settings = context.watch<EffectiveSettings>();
		return _SettingsPage(
			title: 'Data Settings',
			children: [
				const SizedBox(height: 16),
				Row(
					children: [
						const Icon(CupertinoIcons.lock),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Require authentication on launch')
						),
						AdaptiveSwitch(
							value: settings.askForAuthenticationOnLaunch,
							onChanged: (newValue) async {
								try {
									final result = await LocalAuthentication().authenticate(localizedReason: 'Verify access to app', options: const AuthenticationOptions(stickyAuth: true));
									if (result) {
										settings.askForAuthenticationOnLaunch = newValue;
									}
									else if (mounted) {
										showToast(
											context: context,
											icon: CupertinoIcons.lock_slash,
											message: 'Authentication failed'
										);
									}
								}
								catch (e, st) {
									Future.error(e, st); // Report to crashlytics
									if (context.mounted) {
										showToast(
											context: context,
											icon: CupertinoIcons.lock_slash,
											message: 'Error authenticating'
										);
									}
								}
							}
						)
					]
				),
				const SizedBox(height: 32),
				if (Platform.isAndroid) ...[
					Center(
						child: AdaptiveFilledButton(
							padding: const EdgeInsets.all(16),
							child: Row(
								mainAxisSize: MainAxisSize.min,
								children: [
									const Icon(CupertinoIcons.floppy_disk),
									const SizedBox(width: 8),
									Text('${settings.androidGallerySavePath == null ? 'Set' : 'Change'} media save directory')
								]
							),
							onPressed: () async {
								settings.androidGallerySavePath = await pickDirectory();
							}
						)
					),
					const SizedBox(height: 32)
				],
				const Row(
					children: [
						Icon(CupertinoIcons.folder),
						SizedBox(width: 8),
						Expanded(
							child: Text('Media saving folder structure')
						)
					]
				),
				Padding(
					padding: const EdgeInsets.all(16),
					child: AdaptiveChoiceControl<GallerySavePathOrganizing>(
						children: {
							if (Platform.isIOS) GallerySavePathOrganizing.noFolder: (null, "No album"),
							GallerySavePathOrganizing.noSubfolders: (null, Platform.isIOS ? '"Chance" album' : 'No subfolders'),
							GallerySavePathOrganizing.boardSubfolders: (null, Platform.isIOS ? 'Per-board albums' : 'Per-board subfolders'),
							if (Platform.isAndroid) ...{
								GallerySavePathOrganizing.boardAndThreadSubfolders: (null, 'Per-board and per-thread subfolders'),
								GallerySavePathOrganizing.boardAndThreadNameSubfolders: (null, 'Per-board and per-thread (with name) subfolders')
							}
						},
						groupValue: settings.gallerySavePathOrganizing,
						onValueChanged: (setting) {
							settings.gallerySavePathOrganizing = setting;
						}
					)
				),
				const SizedBox(height: 16),
				Row(
					children: [
						const Icon(CupertinoIcons.textformat),
						const SizedBox(width: 8),
						const Text('Use cloud captcha solver'),
						const SizedBox(width: 8),
						const _SettingsHelpButton(
							helpText: 'Use a machine-learning captcha solving model which is hosted on a web server to provide better captcha solver guesses. This means the captchas you open will be sent to a first-party web service for predictions. No information will be retained.'
						),
						const Spacer(),
						AdaptiveSwitch(
							value: settings.useCloudCaptchaSolver ?? false,
							onChanged: (setting) {
								settings.useCloudCaptchaSolver = setting;
							}
						)
					]
				),
				const SizedBox(height: 8),
				Row(
					children: [
						const SizedBox(width: 16),
						const Icon(CupertinoIcons.checkmark_seal),
						const SizedBox(width: 8),
						const Text('Skip confirmation'),
						const SizedBox(width: 8),
						const _SettingsHelpButton(
							helpText: 'Cloud captcha solutions will be submitted directly without showing a popup and asking for confirmation.'
						),
						const Spacer(),
						AdaptiveSwitch(
							value: settings.useHeadlessCloudCaptchaSolver ?? false,
							onChanged: (settings.useCloudCaptchaSolver ?? false) ? (setting) {
								settings.useHeadlessCloudCaptchaSolver = setting;
							} : null
						),
						const SizedBox(width: 16)
					]
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.textformat),
						const SizedBox(width: 8),
						const Text('Contribute captcha data'),
						const SizedBox(width: 8),
						const _SettingsHelpButton(
							helpText: 'Send the captcha images you solve to a database to improve the automated solver. No other information about your posts will be collected.'
						),
						const Spacer(),
						AdaptiveSwitch(
							value: settings.contributeCaptchas ?? false,
							onChanged: (setting) {
								settings.contributeCaptchas = setting;
							}
						)
					]
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.burst),
						const SizedBox(width: 8),
						const Text('Contribute crash data'),
						const SizedBox(width: 8),
						const _SettingsHelpButton(
							helpText: 'Crash stack traces and uncaught exceptions will be used to help fix bugs. No personal information will be collected.'
						),
						const Spacer(),
						AdaptiveSwitch(
							value: FirebaseCrashlytics.instance.isCrashlyticsCollectionEnabled,
							onChanged: (setting) async {
								await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(setting);
								setState(() {});
							}
						)
					]
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.rectangle_paperclip),
						const SizedBox(width: 8),
						const Text('Show rich links'),
						const SizedBox(width: 8),
						const _SettingsHelpButton(
							helpText: 'Links to sites such as YouTube will show the thumbnail and title of the page instead of the link URL.'
						),
						const Spacer(),
						AdaptiveSwitch(
							value: settings.useEmbeds,
							onChanged: (setting) {
								settings.useEmbeds = setting;
							}
						)
					]
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.doc_person),
						const SizedBox(width: 8),
						const Text('Remove metadata from uploads'),
						const Spacer(),
						AdaptiveSwitch(
							value: settings.removeMetadataOnUploadedFiles,
							onChanged: (setting) {
								settings.removeMetadataOnUploadedFiles = setting;
							}
						)
					]
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.doc_checkmark),
						const SizedBox(width: 8),
						const Text('Randomize checksum on uploads'),
						const SizedBox(width: 8),
						const _SettingsHelpButton(
							helpText: 'Uploaded files will be re-encoded to prevent matching against other files.'
						),
						const Spacer(),
						AdaptiveSwitch(
							value: settings.randomizeChecksumOnUploadedFiles,
							onChanged: (setting) {
								settings.randomizeChecksumOnUploadedFiles = setting;
							}
						)
					]
				),
				const SizedBox(height: 32),
				const Row(
					children: [
						Icon(CupertinoIcons.calendar),
						SizedBox(width: 8),
						Expanded(
							child: Text('Automatically clear caches older than...')
						)
					]
				),
				Padding(
					padding: const EdgeInsets.all(16),
					child: AdaptiveChoiceControl<int>(
						children: const {
							1: (null, '1 day'),
							3: (null, '3 days'),
							7: (null, '7 days'),
							14: (null, '14 days'),
							30: (null, '30 days'),
							60: (null, '60 days'),
							100000: (null, 'Never')
						},
						groupValue: context.watch<EffectiveSettings>().automaticCacheClearDays,
						onValueChanged: (setting) {
							context.read<EffectiveSettings>().automaticCacheClearDays = setting;
						}
					)
				),
				const SizedBox(height: 16),
				Row(
					children: [
						Icon(Adaptive.icons.photos),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Cached media')
						)
					]
				),
				const SettingsCachePanel(),
				const SizedBox(height: 16),
				const Row(
					children: [
						Icon(CupertinoIcons.archivebox),
						SizedBox(width: 8),
						Expanded(
							child: Text('Cached threads and history')
						)
					]
				),
				const SettingsThreadsPanel(),
				const SizedBox(height: 16),
				Center(
					child: AdaptiveFilledButton(
						child: const Row(
							mainAxisSize: MainAxisSize.min,
							children: [
								Icon(CupertinoIcons.wifi),
								SizedBox(width: 8),
								Text('Clear Wi-Fi cookies')
							]
						),
						onPressed: () {
							CookieManager.instance().deleteAllCookies();
							Persistence.wifiCookies.deleteAll();
						}
					)
				),
				const SizedBox(height: 16),
				Center(
					child: AdaptiveFilledButton(
						child: const Row(
							mainAxisSize: MainAxisSize.min,
							children: [
								Icon(CupertinoIcons.antenna_radiowaves_left_right),
								SizedBox(width: 8),
								Text('Clear cellular cookies')
							]
						),
						onPressed: () {
							CookieManager.instance().deleteAllCookies();
							Persistence.cellularCookies.deleteAll();
						}
					)
				),
				const SizedBox(height: 16),
				Center(
					child: AdaptiveFilledButton(
						onPressed: () async {
							final controller = TextEditingController(text: settings.userAgent);
							final newUserAgent = await showAdaptiveDialog<String>(
								context: context,
								barrierDismissible: true,
								builder: (context) => AdaptiveAlertDialog(
									title: const Text('Edit User-Agent'),
									content: Column(
										mainAxisSize: MainAxisSize.min,
										children: [
											const SizedBox(height: 10),
											if (ImageboardRegistry.instance.getImageboard('4chan') != null) ...[
												const Text('This user-agent might be overridden for 4chan captcha requests to work with the Cloudflare check.'),
												const SizedBox(height: 10)
											],
											AdaptiveTextField(
												autofocus: true,
												controller: controller,
												smartDashesType: SmartDashesType.disabled,
												smartQuotesType: SmartQuotesType.disabled,
												minLines: 5,
												maxLines: 5,
												onSubmitted: (s) => Navigator.pop(context, s)
											)
										]
									),
									actions: [
										AdaptiveDialogAction(
											child: const Text('Random'),
											onPressed: () {
												final userAgents = getAppropriateUserAgents();
												final idx = userAgents.indexOf(controller.text) + 1;
												controller.text = userAgents[idx % userAgents.length];
											}
										),
										AdaptiveDialogAction(
											isDefaultAction: true,
											child: const Text('Save'),
											onPressed: () => Navigator.pop(context, controller.text.isEmpty ? null : controller.text)
										),
										AdaptiveDialogAction(
											child: const Text('Cancel'),
											onPressed: () => Navigator.pop(context)
										)
									]
								)
							);
							controller.dispose();
							if (newUserAgent != null) {
								settings.userAgent = newUserAgent;
							}
						},
						child: const Row(
							mainAxisSize: MainAxisSize.min,
							children: [
								Icon(CupertinoIcons.globe),
								SizedBox(width: 8),
								Text('Edit user agent')
							]
						)
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

class _SettingsCachePanelState extends State<SettingsCachePanel> {
	Map<String, int>? folderSizes;
	bool clearing = false;

	@override
	void initState() {
		super.initState();
		_readFilesystemInfo();
	}

	Future<void> _readFilesystemInfo() async {
		folderSizes = null;
		setState(() {});
		folderSizes = await Persistence.getFilesystemCacheSizes();
		if (!mounted) return;
		setState(() {});
	}

	Future<void> _clearCaches() async {
		setState(() {
			clearing = true;
		});
		try {
			await Persistence.clearFilesystemCaches(null);
		}
		catch (e, st) {
			Future.error(e, st); // Report to Crashlytics
			if (context.mounted) {
				alertError(context, e.toStringDio());
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
				color: ChanceTheme.primaryColorOf(context).withOpacity(0.2)
			),
			margin: const EdgeInsets.all(16),
			padding: const EdgeInsets.all(16),
			child: Column(
				mainAxisSize: MainAxisSize.min,
				children: [
					SizedBox(
						height: 160,
						child: SingleChildScrollView(
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
															child: Text(entry.key, textAlign: TextAlign.left)
														),
														Text('${megabytes.toStringAsFixed(1)} MB', textAlign: TextAlign.right)
													]
												);
											}).toList()
										)
									]
							)
						)
					),
					const SizedBox(height: 8),
					Row(
						mainAxisAlignment: MainAxisAlignment.spaceBetween,
						children: [
							AdaptiveFilledButton(
								padding: const EdgeInsets.all(16),
								onPressed: _readFilesystemInfo,
								child: const Text('Recalculate')
							),
							AdaptiveFilledButton(
								padding: const EdgeInsets.all(16),
								onPressed: (folderSizes?.isEmpty ?? true) ? null : (clearing ? null : _clearCaches),
								child: Text(clearing ? 'Deleting...' : 'Delete all')
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
			valueListenable: Persistence.sharedThreadStateBox.listenable(),
			builder: (context, Box<PersistentThreadState> threadStateBox, child) {
				final oldThreadRows = [0, 7, 14, 30, 60, 90, 180].map((days) {
					final cutoff = DateTime.now().subtract(Duration(days: days));
					final oldThreads = threadStateBox.values.where((state) {
						return (state.savedTime == null) && (state.threadWatch == null) && state.lastOpenedTime.compareTo(cutoff).isNegative;
					}).toList();
					return (days, oldThreads);
				}).toList();
				oldThreadRows.removeRange(oldThreadRows.lastIndexWhere((r) => r.$2.isNotEmpty) + 1, oldThreadRows.length);
				confirmDelete(List<PersistentThreadState> toDelete, {String itemType = 'thread'}) async {
					final confirmed = await showAdaptiveDialog<bool>(
						context: context,
						builder: (context) => AdaptiveAlertDialog(
							title: const Text('Confirm deletion'),
							content: Text('${describeCount(toDelete.length, itemType)} will be deleted'),
							actions: [
								AdaptiveDialogAction(
									isDestructiveAction: true,
									onPressed: () {
										Navigator.of(context).pop(true);
									},
									child: const Text('Delete')
								),
								AdaptiveDialogAction(
									child: const Text('Cancel'),
									onPressed: () {
										Navigator.of(context).pop();
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
				final savedThreads = threadStateBox.values.where((t) => t.savedTime != null).toList();
				final watchedThreads = threadStateBox.values.where((i) => i.threadWatch != null).toList();
				return Container(
					decoration: BoxDecoration(
						borderRadius: const BorderRadius.all(Radius.circular(8)),
						color: ChanceTheme.primaryColorOf(context).withOpacity(0.2)
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
									Text(savedThreads.length.toString(), textAlign: TextAlign.right),
									AdaptiveIconButton(
										onPressed: savedThreads.isEmpty ? null : () => confirmDelete(savedThreads, itemType: 'saved thread'),
										icon: const Text('Delete')
									)
								]
							),
							TableRow(
								children: [
									const Text('Watched threads', textAlign: TextAlign.left),
									Text(watchedThreads.length.toString(), textAlign: TextAlign.right),
									AdaptiveIconButton(
										onPressed: watchedThreads.isEmpty ? null : () => confirmDelete(watchedThreads, itemType: 'watched thread'),
										icon: const Text('Delete')
									)
								]
							),
							...oldThreadRows.map((entry) {
								return TableRow(
									children: [
										Text('Over ${entry.$1} days old', textAlign: TextAlign.left),
										Text(entry.$2.length.toString(), textAlign: TextAlign.right),
										AdaptiveIconButton(
											onPressed: entry.$2.isEmpty ? null : () => confirmDelete(entry.$2),
											icon: const Text('Delete')
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

class FilterTestPage extends StatefulWidget {
	const FilterTestPage({
		Key? key
	}) : super(key: key);

	@override
	createState() => _FilterTestPageState();
}

class _FilterTestPageState extends State<FilterTestPage> implements Filterable {
	late final TextEditingController _boardController;
	late final TextEditingController _idController;
	late final TextEditingController _textController;
	late final TextEditingController _subjectController;
	late final TextEditingController _nameController;
	late final TextEditingController _filenameController;
	late final TextEditingController _dimensionsController;
	late final TextEditingController _posterIdController;
	late final TextEditingController _flagController;
	late final TextEditingController _replyCountController;

	@override
	void initState() {
		super.initState();
		_boardController = TextEditingController();
		_idController = TextEditingController();
		_textController = TextEditingController();
		_subjectController = TextEditingController();
		_nameController = TextEditingController();
		_filenameController = TextEditingController();
		_dimensionsController = TextEditingController();
		_posterIdController = TextEditingController();
		_flagController = TextEditingController();
		_replyCountController = TextEditingController();
	}

	@override
	String get board => _boardController.text;

	@override
	int get id => -1;

	@override
	bool get hasFile => _filenameController.text.isNotEmpty;

	@override
	bool isThread = true;

	@override
	bool isDeleted = false;

	@override
	List<int> get repliedToIds => [];

	@override
	int get replyCount => int.tryParse(_replyCountController.text) ?? 0;

	@override
	Iterable<String> get md5s => [];

	@override
	String? getFilterFieldText(String fieldName) {
		switch (fieldName) {
			case 'subject':
				return _subjectController.text;
			case 'name':
				return _nameController.text;
			case 'filename':
				return _filenameController.text;
			case 'dimensions':
				return _dimensionsController.text;
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
		final results = <String>[];
		if (type?.hide == true) {
			results.add('Hidden');
		}
		if (type?.highlight == true) {
			results.add('Highlighted');
		}
		if (type?.pinToTop == true) {
			results.add('Pinned to top of catalog');
		}
		if (type?.autoSave == true) {
			results.add('Auto-saved');
		}
		if (type?.autoWatch != null) {
			results.add('Auto-watched');
		}
		if (type?.notify == true) {
			results.add('Notified');
		}
		if (type?.collapse == true) {
			results.add('Collapsed (tree mode)');
		}
		if (results.isEmpty) {
			return 'No action';
		}
		return results.join(', ');
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
				AdaptiveSegmentedControl<bool>(
					children: const {
						false: (null, 'Post'),
						true: (null, 'Thread')
					},
					groupValue: isThread,
					onValueChanged: (setting) {
						isThread = setting;
						_recalculate();
					}
				),
				const SizedBox(height: 16),
				AdaptiveSegmentedControl<bool>(
					children: const {
						false: (null, 'Not deleted'),
						true: (null, 'Deleted')
					},
					groupValue: isDeleted,
					onValueChanged: (setting) {
						isDeleted = setting;
						_recalculate();
					}
				),
				const SizedBox(height: 16),
				for (final field in [
					('Board', _boardController, null),
					(isThread ? 'Thread no.' : 'Post no.', _idController, null),
					('Reply Count', _replyCountController, null),
					if (isThread) ('Subject', _subjectController, null),
					('Name', _nameController, null),
					('Poster ID', _posterIdController, null),
					('Flag', _flagController, null),
					('Filename', _filenameController, null),
					('File dimensions', _dimensionsController, null),
					('Text', _textController, 5),
				]) ...[
					Text(field.$1),
					Padding(
						padding: const EdgeInsets.all(16),
						child: AdaptiveTextField(
							controller: field.$2,
							minLines: field.$3,
							maxLines: null,
							smartDashesType: SmartDashesType.disabled,
							smartQuotesType: SmartQuotesType.disabled,
							onChanged: (_) {
								_recalculate();
							}
						)
					)
				]
			]
		);
	}

	@override
	void dispose() {
		super.dispose();
		_boardController.dispose();
		_idController.dispose();
		_textController.dispose();
		_subjectController.dispose();
		_nameController.dispose();
		_filenameController.dispose();
		_dimensionsController.dispose();
		_posterIdController.dispose();
		_flagController.dispose();
	}
}

class SettingsLoginPanel extends StatefulWidget {
	final ImageboardSiteLoginSystem loginSystem;
	const SettingsLoginPanel({
		required this.loginSystem,
		Key? key
	}) : super(key: key);

	@override
	createState() => _SettingsLoginPanelState();
}

class _SettingsLoginPanelState extends State<SettingsLoginPanel> {
	Map<ImageboardSiteLoginField, String>? savedFields;
	bool loading = true;

	Future<void> _updateStatus() async {
		final newSavedFields = widget.loginSystem.getSavedLoginFields();
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
			for (final field in widget.loginSystem.getLoginFields()) field: ''
		};
		final cont = await showAdaptiveDialog<bool>(
			context: context,
			builder: (context) => AdaptiveAlertDialog(
				title: Text('${widget.loginSystem.name} Login'),
				content: ListBody(
					children: [
						const SizedBox(height: 8),
						for (final field in fields.keys) ...[
							Text(field.displayName, textAlign: TextAlign.left),
							const SizedBox(height: 8),
							AdaptiveTextField(
								autofocus: field == fields.keys.first,
								onChanged: (value) {
									fields[field] = value;
								},
								smartDashesType: SmartDashesType.disabled,
								smartQuotesType: SmartQuotesType.disabled,
								autofillHints: field.autofillHints,
								keyboardType: field.inputType
							),
							const SizedBox(height: 16),
						]
					]
				),
				actions: [
					AdaptiveDialogAction(
						child: const Text('Login'),
						onPressed: () => Navigator.pop(context, true)
					),
					AdaptiveDialogAction(
						child: const Text('Cancel'),
						onPressed: () => Navigator.pop(context)
					)
				]
			)
		);
		if (cont == true) {
			print(fields);
			try {
				await widget.loginSystem.login(null, fields);
				widget.loginSystem.parent.persistence.browserState.loginFields.clear();
				widget.loginSystem.parent.persistence.browserState.loginFields.addAll({
					for (final field in fields.entries) field.key.formKey: field.value
				});
				widget.loginSystem.parent.persistence.didUpdateBrowserState();
			}
			catch (e) {
				if (!mounted) return;
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
					child: CircularProgressIndicator.adaptive()
				)
				else if (savedFields != null) ...[
					const Text('Credentials saved\n'),
					Wrap(
						spacing: 16,
						runSpacing: 16,
						children: [
							AdaptiveFilledButton(
								child: const Text('Remove'),
								onPressed: () async {
									setState(() {
										loading = true;
									});
									try {
										await widget.loginSystem.clearLoginCookies(null, true);
										await widget.loginSystem.clearSavedLoginFields();
									}
									catch (e) {
										if (context.mounted) {
											await alertError(context, e.toStringDio());
										}
									}
									await _updateStatus();
								}
							)
						]
					)
				]
				else ...[
					AdaptiveFilledButton(
						child: const Text('Login'),
						onPressed: () async {
							try {
								await _login();
							}
							catch (e) {
								if (context.mounted) {
									await alertError(context, e.toStringDio());
								}
							}
						}
					)
				],
				const SizedBox(height: 16),
				Padding(
					padding: const EdgeInsets.only(left: 16),
					child: Align(
						alignment: Alignment.topLeft,
						child: Text('Try to use ${widget.loginSystem.name} on mobile networks?')
					)
				),
				const SizedBox(height: 16),
				AdaptiveSegmentedControl<NullSafeOptional>(
					children: const {
						NullSafeOptional.false_: (null, 'No'),
						NullSafeOptional.null_: (null, 'Ask'),
						NullSafeOptional.true_: (null, 'Yes')
					},
					groupValue: context.watch<EffectiveSettings>().autoLoginOnMobileNetwork.value,
					onValueChanged: (setting) {
						context.read<EffectiveSettings>().autoLoginOnMobileNetwork = setting.value;
					}
				)
			]
		);
	}
}

Future<Imageboard?> _pickImageboard(BuildContext context, Imageboard current) {
	return showAdaptiveModalPopup<Imageboard?>(
		context: context,
		builder: (context) => AdaptiveActionSheet(
			title: const Text('Select site'),
			actions: ImageboardRegistry.instance.imageboards.map((imageboard) => AdaptiveActionSheetAction(
				isSelected: imageboard == current,
				child: Row(
					mainAxisSize: MainAxisSize.min,
					children: [
						ImageboardIcon(imageboardKey: imageboard.key),
						const SizedBox(width: 8),
						Text(imageboard.site.name)
					]
				),
				onPressed: () {
					Navigator.of(context, rootNavigator: true).pop(imageboard);
				}
			)).toList(),
			cancelButton: AdaptiveActionSheetAction(
				child: const Text('Cancel'),
				onPressed: () => Navigator.of(context, rootNavigator: true).pop()
			)
		)
	);
}

class _SettingsHelpButton extends StatelessWidget {
	final String helpText;

	const _SettingsHelpButton({
		required this.helpText
	});

	@override
	Widget build(BuildContext context) {
		return AdaptiveIconButton(
			icon: const Icon(CupertinoIcons.question_circle),
			onPressed: () {
				showAdaptiveDialog<bool>(
					context: context,
					barrierDismissible: true,
					builder: (context) => AdaptiveAlertDialog(
						content: Text(helpText),
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
		);
	}
}
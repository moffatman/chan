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
import 'package:chan/services/apple.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/storage.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/version.dart';
import 'package:chan/widgets/cupertino_adaptive_segmented_control.dart';
import 'package:chan/widgets/cupertino_page_route.dart';
import 'package:chan/widgets/filter_editor.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/thread_row.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
	final scrollKey = GlobalKey();

	@override
	Widget build(BuildContext context) {
		return CupertinoPageScaffold(
			resizeToAvoidBottomInset: false,
			navigationBar: CupertinoNavigationBar(
				transitionBetweenRoutes: false,
				middle: Text(widget.title)
			),
			child: SafeArea(
				child: MaybeCupertinoScrollbar(
					child: SingleChildScrollView(
						key: scrollKey,
						physics: isOnMac ? const BouncingScrollPhysics(decelerationRate: ScrollDecelerationRate.fast) : const BouncingScrollPhysics(),
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
										children: widget.children
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
		return GestureDetector(
			behavior: HitTestBehavior.opaque,
			child: Padding(
				padding: const EdgeInsets.all(16),
				child: Row(
					children: [
						Icon(icon, color: color),
						const SizedBox(width: 16),
						Expanded(
							child: Text(title, style: TextStyle(color: color))
						),
						Icon(CupertinoIcons.chevron_forward, color: color)
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
						showCupertinoDialog(
							context: context,
							barrierDismissible: true,
							builder: (context) => CupertinoAlertDialog(
								content: SettingsLoginPanel(
									loginSystem: site.loginSystem!
								),
								actions: [
									CupertinoDialogAction(
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
												webmAudioAllowed: false,
												maxImageSizeBytes: 8000000,
												maxWebmSizeBytes: 8000000
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
							CupertinoButton.filled(
								padding: const EdgeInsets.all(8),
								child: const Row(
									mainAxisSize: MainAxisSize.min,
									children: [
										Text('Synchronize '),
										Icon(Icons.sync_rounded, size: 16)
									]
								),
								onPressed: () async {
									await modalLoad(context, 'Synchronizing...', () => settings.updateContentSettings());
									// ignore: use_build_context_synchronously
									showToast(
										context: context,
										icon: CupertinoIcons.check_mark,
										message: 'Synchronized'
									);
								}
							),
							if (settings.contentSettings.sites.length > 1) ...[
								const SizedBox(width: 16),
								CupertinoButton.filled(
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
											final toDelete = await showCupertinoDialog<String>(
												context: context,
												barrierDismissible: true,
												builder: (context) => CupertinoAlertDialog(
													title: const Text('Which site?'),
													actions: [
														for (final i in imageboards.entries) CupertinoDialogAction(
															isDestructiveAction: true,
															onPressed: () {
																Navigator.of(context).pop(i.key);
															},
															child: Text(i.value)
														),
														CupertinoDialogAction(
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
												await modalLoad(context, 'Cleaning up...', () async {
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
											alertError(context, e.toStringDio());
										}
									}
								)
							],
							const SizedBox(width: 16),
							CupertinoButton.filled(
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
					color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2)
				),
				_SettingsPageButton(
					icon: CupertinoIcons.eye_slash,
					title: 'Behavior Settings',
					color: settings.filterError != null ? Colors.red : null,
					pageBuilder: (context) => const SettingsBehaviorPage()
				),
				Divider(
					color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2)
				),
				_SettingsPageButton(
					icon: CupertinoIcons.paintbrush,
					title: 'Appearance Settings',
					pageBuilder: (context) => const SettingsAppearancePage()
				),
				Divider(
					color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2)
				),
				_SettingsPageButton(
					icon: CupertinoIcons.photo_on_rectangle,
					title: 'Data Settings',
					pageBuilder: (context) => const SettingsDataPage()
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
				Center(
					child: Text('Chance $kChanceVersion', style: TextStyle(color: settings.theme.primaryColorWithBrightness(0.5)))
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
	bool showFilterRegex = false;
	Imageboard _imageFilterImageboard = ImageboardRegistry.instance.imageboards.first;
	Imageboard _loginSystemImageboard = ImageboardRegistry.instance.imageboards.first;

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<EffectiveSettings>();
		return _SettingsPage(
			title: 'Behavior Settings',
			children: [
				const SizedBox(height: 16),
				Row(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						const Padding(
							padding: EdgeInsets.only(top: 4),
							child: Row(
								mainAxisSize: MainAxisSize.min,
								children: [
									Icon(CupertinoIcons.scope),
									SizedBox(width: 8),
									Text('Filters'),
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
									CupertinoButton.filled(
										padding: const EdgeInsets.all(8),
										borderRadius: BorderRadius.circular(4),
										minSize: 0,
										child: const Text('Test filter setup'),
										onPressed: () {
											Navigator.of(context).push(FullWidthCupertinoPageRoute(
												builder: (context) => const FilterTestPage(),
												showAnimations: settings.showAnimations
											));
										}
									),
									CupertinoSegmentedControl<bool>(
										padding: EdgeInsets.zero,
										groupValue: showFilterRegex,
										children: const {
											false: Padding(
												padding: EdgeInsets.all(8),
												child: Text('Wizard')
											),
											true: Padding(
												padding: EdgeInsets.all(8),
												child: Text('Regex')
											)
										},
										onValueChanged: (v) => setState(() {
											showFilterRegex = v;
										})
									)
								]
							)
						)
					]
				),
				const SizedBox(height: 16),
				if (settings.filterError != null) Padding(
					padding: const EdgeInsets.only(bottom: 16),
					child: Text(
						settings.filterError!,
						style: const TextStyle(
							color: Colors.red
						)
					)
				),
				FilterEditor(
					showRegex: showFilterRegex
				),
				const SizedBox(height: 16),
				Row(
					children: [
						const Icon(Icons.hide_image_outlined),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Image filter')
						),
						CupertinoButton.filled(
							padding: const EdgeInsets.all(8),
							onPressed: () async {
								final md5sBefore = _imageFilterImageboard.persistence.browserState.hiddenImageMD5s;
								await Navigator.of(context).push(FullWidthCupertinoPageRoute(
									showAnimations: settings.showAnimations,
									builder: (context) => SettingsImageFilterPage(
										browserState: _imageFilterImageboard.persistence.browserState
									)
								));
								if (!setEquals(md5sBefore, _imageFilterImageboard.persistence.browserState.hiddenImageMD5s)) {
									_imageFilterImageboard.persistence.didUpdateBrowserState();
								}
							},
							child: Text(describeCount(_imageFilterImageboard.persistence.browserState.hiddenImageMD5s.length, 'image'))
						),
						const SizedBox(width: 8),
						CupertinoButton.filled(
							padding: const EdgeInsets.all(8),
							onPressed: () async {
								final newImageboard = await _pickImageboard(context, _imageFilterImageboard);
								if (newImageboard != null) {
									setState(() {
										_imageFilterImageboard = newImageboard;
									});
								}
							},
							child: Row(
								mainAxisSize: MainAxisSize.min,
								children: [
									ImageboardIcon(
										imageboardKey: _imageFilterImageboard.key
									),
									const SizedBox(width: 8),
									Text(_imageFilterImageboard.site.name)
								]
							)
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
							CupertinoButton.filled(
								padding: const EdgeInsets.all(8),
								onPressed: () {
									showCupertinoDialog(
										context: context,
										barrierDismissible: true,
										builder: (context) => CupertinoAlertDialog(
											content: SettingsLoginPanel(
												loginSystem: _loginSystemImageboard.site.loginSystem!
											),
											actions: [
												CupertinoDialogAction(
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
						CupertinoButton.filled(
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
				Row(
					children: [
						const Icon(CupertinoIcons.arrow_left_right_square_fill),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Allow swiping to change page in gallery')
						),
						CupertinoSwitch(
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
				CupertinoSegmentedControl<AutoloadAttachmentsSetting>(
					children: const {
						AutoloadAttachmentsSetting.never: Padding(
							padding: EdgeInsets.all(8),
							child: Text('Never')
						),
						AutoloadAttachmentsSetting.wifi: Padding(
							padding: EdgeInsets.all(8),
							child: Text('When on Wi\u200d-\u200dFi', textAlign: TextAlign.center)
						),
						AutoloadAttachmentsSetting.always: Padding(
							padding: EdgeInsets.all(8),
							child: Text('Always')
						)
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
						CupertinoSwitch(
							value: settings.alwaysAutoloadTappedAttachment,
							onChanged: (newValue) {
								settings.alwaysAutoloadTappedAttachment = newValue;
							}
						)
					]
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.volume_off),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Always start videos with sound muted')
						),
						CupertinoSwitch(
							value: settings.alwaysStartVideosMuted,
							onChanged: (newValue) {
								settings.alwaysStartVideosMuted = newValue;
							}
						)
					]
				),
				const SizedBox(height: 32),
				if (Platform.isAndroid) ...[
					const Row(
						children: [
							Icon(CupertinoIcons.play_rectangle),
							SizedBox(width: 8),
							Expanded(
								child: Text('Transcode WEBM videos')
							)
						]
					),
					const SizedBox(height: 16),
					CupertinoSegmentedControl<WebmTranscodingSetting>(
						children: const {
							WebmTranscodingSetting.never: Padding(
								padding: EdgeInsets.all(8),
								child: Text('Never')
							),
							WebmTranscodingSetting.vp9: Padding(
								padding: EdgeInsets.all(8),
								child: Text('VP9 only', textAlign: TextAlign.center)
							),
							WebmTranscodingSetting.always: Padding(
								padding: EdgeInsets.all(8),
								child: Text('Always')
							)
						},
						groupValue: settings.webmTranscoding,
						onValueChanged: (newValue) {
							settings.webmTranscoding = newValue;
						}
					),
					const SizedBox(height: 32),
				],
				Row(
					children: [
						const Icon(CupertinoIcons.pin_slash),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Hide old stickied threads')
						),
						CupertinoSwitch(
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
						CupertinoSwitch(
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
				CupertinoSegmentedControl<NullSafeOptional>(
					children: const {
						NullSafeOptional.false_: Padding(
							padding: EdgeInsets.all(8),
							child: Text('Externally')
						),
						NullSafeOptional.null_: Padding(
							padding: EdgeInsets.all(8),
							child: Text('Ask')
						),
						NullSafeOptional.true_: Padding(
							padding: EdgeInsets.all(8),
							child: Text('Internally')
						)
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
						CupertinoButton.filled(
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
						CupertinoButton.filled(
							padding: const EdgeInsets.all(16),
							onPressed: () async {
								final controller = TextEditingController(text: settings.maximumImageUploadDimension?.toString());
								await showCupertinoDialog(
									context: context,
									barrierDismissible: true,
									builder: (context) => CupertinoAlertDialog(
										title: const Text('Set maximum file upload dimension'),
										actions: [
											CupertinoButton(
												child: const Text('Clear'),
												onPressed: () {
													controller.text = '';
													Navigator.pop(context);
												}
											),
											CupertinoButton(
												child: const Text('Close'),
												onPressed: () => Navigator.pop(context)
											)
										],
										content: Row(
											children: [
												Expanded(
													child: CupertinoTextField(
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
						CupertinoSwitch(
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
								child: CupertinoButton.filled(
									padding: const EdgeInsets.all(16),
									onPressed: () async {
										bool tapped = false;
										final newAction = await showCupertinoDialog<SettingsQuickAction>(
											context: context,
											barrierDismissible: true,
											builder: (context) => CupertinoAlertDialog(
												title: const Text('Pick Settings icon long-press action'),
												actions: [
													...SettingsQuickAction.values,
													null
												].map((action) => CupertinoDialogAction(
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
						CupertinoSwitch(
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
							CupertinoSwitch(
								value: !settings.enableIMEPersonalizedLearning,
								onChanged: (newValue) {
									settings.enableIMEPersonalizedLearning = !newValue;
								}
							)
						]
					),
				],
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.arrow_up_down),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Tab bar hides when scrolling down')
						),
						CupertinoSwitch(
							value: settings.tabMenuHidesWhenScrollingDown,
							onChanged: (newValue) {
								settings.tabMenuHidesWhenScrollingDown = newValue;
							}
						)
					]
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.hand_point_right),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Double-tap scrolls to replies in thread')
						),
						CupertinoSwitch(
							value: settings.doubleTapScrollToReplies,
							onChanged: (newValue) {
								settings.doubleTapScrollToReplies = newValue;
							}
						)
					]
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
					enableIMEPersonalizedLearning: false,
					onChanged: (s) {
						widget.browserState.setHiddenImageMD5s(s.split('\n').where((x) => x.isNotEmpty));
					},
					minLines: 10,
					maxLines: 10
				)
			]
		);
	}

	@override
	void dispose() {
		super.dispose();
		controller.dispose();
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
			id: '99999',
			ext: '.png',
			width: 800,
			height: 800,
			filename: 'example.png',
			md5: '',
			sizeInBytes: 150634,
			url: Uri.parse('https://picsum.photos/800'),
			thumbnailUrl: Uri.parse('https://picsum.photos/200'),
			threadId: 99999
		);
		return Thread(
			attachments: [attachment],
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
					attachments: [attachment],
					spanFormat: PostSpanFormat.chan4,
					ipNumber: 1
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
						const Icon(CupertinoIcons.zoom_in),
						const SizedBox(width: 8),
						const Text('Interface scale'),
						const Spacer(),
						CupertinoButton(
							padding: EdgeInsets.zero,
							onPressed: settings.interfaceScale <= 0.5 ? null : () {
								settings.interfaceScale -= 0.05;
							},
							child: const Icon(CupertinoIcons.minus)
						),
						Text('${(settings.interfaceScale * 100).round()}%'),
						CupertinoButton(
							padding: EdgeInsets.zero,
							onPressed: settings.interfaceScale >= 2.0 ? null : () {
								settings.interfaceScale += 0.05;
							},
							child: const Icon(CupertinoIcons.plus)
						)
					]
				),
				const SizedBox(height: 16),
				Row(
					children: [
						const Icon(CupertinoIcons.textformat_size),
						const SizedBox(width: 8),
						const Text('Font scale'),
						const Spacer(),
						CupertinoButton(
							padding: EdgeInsets.zero,
							onPressed: settings.textScale <= 0.5 ? null : () {
								settings.textScale -= 0.05;
							},
							child: const Icon(CupertinoIcons.minus)
						),
						Text('${(settings.textScale * 100).round()}%'),
						CupertinoButton(
							padding: EdgeInsets.zero,
							onPressed: settings.textScale >= 2.0 ? null : () {
								settings.textScale += 0.05;
							},
							child: const Icon(CupertinoIcons.plus)
						)
					]
				),
				const SizedBox(height: 16),
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
				CupertinoAdaptiveSegmentedControl<TristateSystemSetting>(
					children: const {
						TristateSystemSetting.a: Padding(
							padding: EdgeInsets.all(8),
							child: Wrap(
								alignment: WrapAlignment.center,
								spacing: 8,
								children: [
									Icon(CupertinoIcons.hand_draw),
									Text('Touch')
								]
							)
						),
						TristateSystemSetting.system: Padding(
							padding: EdgeInsets.all(8),
							child: Text('Automatic')
						),
						TristateSystemSetting.b: Padding(
							padding: EdgeInsets.all(8),
							child: Wrap(
								alignment: WrapAlignment.center,
								spacing: 8,
								children: [
									Icon(Icons.mouse),
									Text('Mouse')
								]
							)
						)
					},
					groupValue: settings.supportMouseSetting,
					onValueChanged: (newValue) {
						settings.supportMouseSetting = newValue;
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
						CupertinoSwitch(
							value: settings.showAnimations,
							onChanged: (newValue) {
								settings.showAnimations = newValue;
							}
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
				CupertinoSegmentedControl<TristateSystemSetting>(
					children: const {
						TristateSystemSetting.a: Padding(
							padding: EdgeInsets.all(8),
							child: Row(
								mainAxisSize: MainAxisSize.min,
								children: [
									Icon(CupertinoIcons.sun_max),
									SizedBox(width: 8),
									Text('Light')
								]
							)
						),
						TristateSystemSetting.system: Padding(
							padding: EdgeInsets.all(8),
							child: Text('Follow System', textAlign: TextAlign.center)
						),
						TristateSystemSetting.b: Padding(
							padding: EdgeInsets.all(8),
							child: Row(
								mainAxisSize: MainAxisSize.min,
								children: [
									Icon(CupertinoIcons.moon),
									SizedBox(width: 8),
									Text('Dark')
								]
							)
						)
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
												child: CupertinoButton.filled(
													padding: const EdgeInsets.all(8),
													onPressed: () async {
														final selectedKey = await showCupertinoDialog<String>(
															barrierDismissible: true,
															context: context,
															builder: (context) => CupertinoAlertDialog(
																title: Padding(
																	padding: const EdgeInsets.only(bottom: 16),
																	child: Row(
																		mainAxisAlignment: MainAxisAlignment.center,
																		children: [
																			const Icon(CupertinoIcons.paintbrush),
																			const SizedBox(width: 8),
																			Text('Picking ${theme.$1}')
																		]
																	)
																),
																content: StatefulBuilder(
																	builder: (context, setDialogState) {
																		final themeNames = settings.themes.keys.toList();
																		themeNames.sort();
																		return SizedBox(
																			width: 200,
																			height: 350,
																			child: ListView.separated(
																				itemCount: themeNames.length,
																				separatorBuilder: (context, i) => const SizedBox(height: 16),
																				itemBuilder: (context, i) => GestureDetector(
																					onTap: () {
																						Navigator.pop(context, themeNames[i]);
																					},
																					child: CupertinoTheme(
																						data: CupertinoTheme.of(context).copyWith(
																							primaryColor: settings.themes[themeNames[i]]?.primaryColor,
																							primaryContrastingColor: settings.themes[themeNames[i]]?.backgroundColor,
																							brightness: (settings.themes[themeNames[i]]?.primaryColor.computeLuminance() ?? 0) > 0.5 ? Brightness.dark : Brightness.light
																						),
																						child: Container(
																							decoration: BoxDecoration(
																								borderRadius: const BorderRadius.all(Radius.circular(8)),
																								color: settings.themes[themeNames[i]]?.backgroundColor
																							),
																							child: Column(
																								mainAxisSize: MainAxisSize.min,
																								children: [
																									Padding(
																										padding: const EdgeInsets.all(16),
																										child: AutoSizeText(themeNames[i], style: TextStyle(
																											fontSize: 18,
																											color: settings.themes[themeNames[i]]?.primaryColor,
																											fontWeight: themeNames[i] == theme.$3 ? FontWeight.bold : null
																										))
																									),
																									Container(
																										//margin: const EdgeInsets.all(4),
																										decoration: BoxDecoration(
																											color: settings.themes[themeNames[i]]?.barColor,
																											borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8))
																										),
																										child: Row(
																											mainAxisAlignment: MainAxisAlignment.spaceEvenly,
																											children: [
																												CupertinoButton(
																													child: const Icon(CupertinoIcons.share),
																													onPressed: () {
																														Clipboard.setData(ClipboardData(
																															text: Uri(
																																scheme: 'chance',
																																host: 'theme',
																																queryParameters: {
																																	'name': themeNames[i],
																																	'data': settings.themes[themeNames[i]]!.encode()
																																}
																															).toString()
																														));
																														showToast(
																															context: context,
																															message: 'Copied ${themeNames[i]} to clipboard',
																															icon: CupertinoIcons.doc_on_clipboard
																														);
																													}
																												),
																												CupertinoButton(
																													child: const Icon(CupertinoIcons.textformat),
																													onPressed: () async {
																														final controller = TextEditingController(text: themeNames[i]);
																														controller.selection = TextSelection(baseOffset: 0, extentOffset: themeNames[i].length);
																														final newName = await showCupertinoDialog<String>(
																															context: context,
																															barrierDismissible: true,
																															builder: (context) => CupertinoAlertDialog(
																																title: const Text('Enter new name'),
																																content: CupertinoTextField(
																																	autofocus: true,
																																	controller: controller,
																																	smartDashesType: SmartDashesType.disabled,
																																	smartQuotesType: SmartQuotesType.disabled,
																																	onSubmitted: (s) => Navigator.pop(context, s)
																																),
																																actions: [
																																	CupertinoDialogAction(
																																		child: const Text('Cancel'),
																																		onPressed: () => Navigator.pop(context)
																																	),
																																	CupertinoDialogAction(
																																		isDefaultAction: true,
																																		child: const Text('Rename'),
																																		onPressed: () => Navigator.pop(context, controller.text)
																																	)
																																]
																															)
																														);
																														if (newName != null) {
																															final effectiveName = settings.addTheme(newName, settings.themes[themeNames[i]]!);
																															settings.themes.remove(themeNames[i]);
																															if (settings.lightThemeKey == themeNames[i]) {
																																settings.lightThemeKey = effectiveName;
																															}
																															if (settings.darkThemeKey == themeNames[i]) {
																																settings.darkThemeKey = effectiveName;
																															}
																															settings.handleThemesAltered();
																															setDialogState(() {});
																														}
																														controller.dispose();
																													}
																												),
																												CupertinoButton(
																													child: const Icon(CupertinoIcons.doc_on_doc),
																													onPressed: () {
																														settings.addTheme(themeNames[i], settings.themes[themeNames[i]]!);
																														settings.handleThemesAltered();
																														setDialogState(() {});
																													}
																												),
																												CupertinoButton(
																													onPressed: (themeNames[i] == settings.darkThemeKey || themeNames[i] == settings.lightThemeKey) ? null : () async {
																														final consent = await showCupertinoDialog<bool>(
																															context: context,
																															barrierDismissible: true,
																															builder: (context) => CupertinoAlertDialog(
																																title: Text('Delete ${themeNames[i]}?'),
																																actions: [
																																	CupertinoDialogAction(
																																		child: const Text('Cancel'),
																																		onPressed: () {
																																			Navigator.of(context).pop();
																																		}
																																	),
																																	CupertinoDialogAction(
																																		isDestructiveAction: true,
																																		onPressed: () {
																																			Navigator.of(context).pop(true);
																																		},
																																		child: const Text('Delete')
																																	)
																																]
																															)
																														);
																														if (consent == true) {
																															settings.themes.remove(themeNames[i]);
																															settings.handleThemesAltered();
																															setDialogState(() {});
																														}
																													},
																													child: const Icon(CupertinoIcons.delete)
																												)
																											]
																										)
																									)
																								]
																							)
																						)
																					)
																				)
																			)
																		);
																	}
																),
																actions: [
																	CupertinoDialogAction(
																		child: const Text('Close'),
																		onPressed: () => Navigator.pop(context)
																	)
																]
															)
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
									('Quote', theme.$2.quoteColor, (c) => theme.$2.quoteColor = c, theme.$2.copiedFrom?.quoteColor)
								].map((color) => Column(
									mainAxisSize: MainAxisSize.min,
									children: [
										const SizedBox(height: 16),
										Text(color.$1, style: TextStyle(color: theme.$2.primaryColor)),
										const SizedBox(height: 16),
										GestureDetector(
											child: Container(
												decoration: BoxDecoration(
													borderRadius: const BorderRadius.all(Radius.circular(8)),
													border: Border.all(color: theme.$2.primaryColor),
													color: color.$2
												),
												width: 50,
												height: 50
											),
											onTap: () async {
												await showCupertinoModalPopup(
													barrierDismissible: true,
													context: context,
													builder: (context) => CupertinoActionSheet(
														title: Text('Select ${color.$1} Color'),
														message: Theme(
															data: ThemeData(
																textTheme: Theme.of(context).textTheme.apply(
																	bodyColor: CupertinoTheme.of(context).primaryColor,
																	displayColor: CupertinoTheme.of(context).primaryColor,
																),
																canvasColor: CupertinoTheme.of(context).scaffoldBackgroundColor
															),
															child: Padding(
																padding: MediaQuery.viewInsetsOf(context),
																child: Column(
																	mainAxisSize: MainAxisSize.min,
																	children: [
																		Material(
																			color: Colors.transparent,
																			child: ColorPicker(
																				pickerColor: color.$2,
																				onColorChanged: color.$3,
																				enableAlpha: false,
																				portraitOnly: true,
																				displayThumbColor: true,
																				hexInputBar: true
																			)
																		),
																		CupertinoButton(
																			padding: const EdgeInsets.all(8),
																			color: color.$4,
																			onPressed: color.$2 == color.$4 ? null : () {
																				color.$3(color.$4!);
																				settings.handleThemesAltered();
																			},
																			child: Text('Reset to original color', style: TextStyle(color: (color.$4?.computeLuminance() ?? 0) > 0.5 ? Colors.black : Colors.white))
																		)
																	]
																)
															)
														)
													)
												);
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
				CupertinoSegmentedControl<bool>(
					children: const {
						false: Padding(
							padding: EdgeInsets.all(8),
							child: Text('Left')
						),
						true: Padding(
							padding: EdgeInsets.all(8),
							child: Text('Right')
						)
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
						CupertinoSwitch(
							value: settings.blurThumbnails,
							onChanged: (newValue) {
								settings.blurThumbnails = newValue;
							}
						)
					]
				),
				const SizedBox(height: 32),
				Center(
					child: CupertinoButton.filled(
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
							await showCupertinoModalPopup(
								context: context,
								useRootNavigator: false,
								builder: (context) => StatefulBuilder(
									builder: (context, setDialogState) {
										final settings = context.watch<EffectiveSettings>();
										return CupertinoActionSheet(
											title: const Text('Edit post details'),
											actions: [
												CupertinoButton(
													child: const Text('Close'),
													onPressed: () => Navigator.pop(context)
												)
											],
											message: DefaultTextStyle(
												style: DefaultTextStyle.of(context).style,
												child: Column(
													children: [
														SizedBox(
															height: 175,
															child: IgnorePointer(
																child: _buildFakePostRow()
															)
														),
														Row(
															children: [
																const Text('Show IP address #'),
																const Spacer(),
																CupertinoSwitch(
																	value: settings.showIPNumberOnPosts,
																	onChanged: (d) => settings.showIPNumberOnPosts = d
																)
															]
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
																const Text('Hide default names'),
																const Spacer(),
																CupertinoSwitch(
																	value: settings.hideDefaultNamesOnPosts,
																	onChanged: (d) => settings.hideDefaultNamesOnPosts = d
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
														),
														Row(
															children: [
																const Text('Show "No." before ID'),
																const Spacer(),
																CupertinoSwitch(
																	value: settings.showNoBeforeIdOnPosts,
																	onChanged: (d) => settings.showNoBeforeIdOnPosts = d
																)
															]
														),
														CupertinoButton.filled(
															child: const Text('Adjust order'),
															onPressed: () async {
																await showCupertinoDialog(
																	barrierDismissible: true,
																	context: context,
																	builder: (context) => StatefulBuilder(
																		builder: (context, setDialogState) => CupertinoAlertDialog(
																			title: const Text('Reorder post details'),
																			actions: [
																				CupertinoButton(
																					child: const Text('Close'),
																					onPressed: () => Navigator.pop(context)
																				)
																			],
																			content: SizedBox(
																				width: 100,
																				height: 350,
																				child: ReorderableListView(
																					children: context.select<EffectiveSettings, List<PostDisplayField>>((s) => s.postDisplayFieldOrder).asMap().entries.map((pair) {
																						final disabled = (pair.value == PostDisplayField.name && !settings.showNameOnPosts && !settings.showTripOnPosts) ||
																							(pair.value == PostDisplayField.attachmentInfo && !settings.showFilenameOnPosts && !settings.showFilesizeOnPosts && !settings.showFileDimensionsOnPosts) ||
																							(pair.value == PostDisplayField.pass && !settings.showPassOnPosts) ||
																							(pair.value == PostDisplayField.flag && !settings.showFlagOnPosts) ||
																							(pair.value == PostDisplayField.countryName && !settings.showCountryNameOnPosts) ||
																							(pair.value == PostDisplayField.absoluteTime && !settings.showAbsoluteTimeOnPosts) ||
																							(pair.value == PostDisplayField.relativeTime && !settings.showRelativeTimeOnPosts);
																						return ReorderableDragStartListener(
																							index: pair.key,
																							key: ValueKey(pair.key),
																							child: Container(
																								decoration: BoxDecoration(
																									borderRadius: const BorderRadius.all(Radius.circular(4)),
																									color: CupertinoTheme.of(context).primaryColor.withOpacity(0.1)
																								),
																								margin: const EdgeInsets.symmetric(vertical: 2),
																								padding: const EdgeInsets.all(8),
																								alignment: Alignment.center,
																								child: Text(
																									pair.value.displayName,
																									style: disabled ? TextStyle(
																										color: CupertinoTheme.of(context).primaryColorWithBrightness(0.5)
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
						CupertinoSwitch(
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
						CupertinoSwitch(
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
				CupertinoSegmentedControl<bool>(
					children: const {
						false: Padding(
							padding: EdgeInsets.all(8),
							child: Row(
								mainAxisSize: MainAxisSize.min,
								children: [
									Icon(CupertinoIcons.rectangle_grid_1x2),
									SizedBox(width: 8),
									Text('Rows')
								]
							)
						),
						true: Padding(
							padding: EdgeInsets.all(8),
							child: Row(
								mainAxisSize: MainAxisSize.min,
								children: [
									Icon(CupertinoIcons.rectangle_split_3x3),
									SizedBox(width: 8),
									Text('Grid')
								]
							)
						)
					},
					groupValue: settings.useCatalogGrid,
					onValueChanged: (newValue) {
						settings.useCatalogGrid = newValue;
					}
				),
				const SizedBox(height: 16),
				Row(
					children: [
						const SizedBox(width: 16),
						const Expanded(
							child: Text('Show counters in their own row'),
						),
						CupertinoSwitch(
							value: settings.useFullWidthForCatalogCounters,
							onChanged: (d) => settings.useFullWidthForCatalogCounters = d
						),
						const SizedBox(width: 16)
					]
				),
				const SizedBox(height: 16),
				Center(
					child: settings.useCatalogGrid ? CupertinoButton.filled(
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
							await showCupertinoModalPopup(
								context: context,
								useRootNavigator: false,
								builder: (context) => StatefulBuilder(
									builder: (context, setDialogState) => CupertinoActionSheet(
										title: const Text('Edit catalog grid item layout'),
										actions: [
											CupertinoButton(
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
																onPressed: size.width <= 100 ? null : () {
																	setDialogState(() {
																		size = Size(size.width - 1, size.height);
																	});
																},
																child: const Icon(CupertinoIcons.minus)
															),
															CupertinoButton(
																padding: EdgeInsets.zero,
																onPressed: size.width >= 600 ? null : () {
																	setDialogState(() {
																		size = Size(size.width + 1, size.height);
																	});
																},
																child: const Icon(CupertinoIcons.plus)
															)
														]
													),
													const SizedBox(height: 8),
													Text('Height: ${size.height.round()}px'),
													Row(
														mainAxisAlignment: MainAxisAlignment.end,
														children: [
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
																onPressed: size.height <= 100 ? null : () {
																	setDialogState(() {
																		size = Size(size.width, size.height - 1);
																	});
																},
																child: const Icon(CupertinoIcons.minus)
															),
															CupertinoButton(
																padding: EdgeInsets.zero,
																onPressed: size.height >= 600 ? null : () {
																	setDialogState(() {
																		size = Size(size.width, size.height + 1);
																	});
																},
																child: const Icon(CupertinoIcons.plus)
															)
														]
													),
													const SizedBox(height: 8),
													Text('Maximum text lines: ${settings.catalogGridModeTextLinesLimit?.toString() ?? 'Unlimited'}'),
													Row(
														mainAxisAlignment: MainAxisAlignment.end,
														children: [
															CupertinoButton(
																padding: const EdgeInsets.only(left: 8, right: 8),
																onPressed: settings.catalogGridModeTextLinesLimit == null ? null : () {
																	setDialogState(() {
																		settings.catalogGridModeTextLinesLimit = null;
																	});
																},
																child: const Text('Reset')
															),
															CupertinoButton(
																padding: EdgeInsets.zero,
																onPressed: (settings.catalogGridModeTextLinesLimit ?? 2) <= 1 ? null : () {
																	setDialogState(() {
																		settings.catalogGridModeTextLinesLimit = (settings.catalogGridModeTextLinesLimit ?? (settings.catalogGridHeight / (2 * 14 * MediaQuery.textScaleFactorOf(context))).round()) - 1;
																	});
																},
																child: const Icon(CupertinoIcons.minus)
															),
															CupertinoButton(
																padding: EdgeInsets.zero,
																onPressed: () {
																	setDialogState(() {
																		settings.catalogGridModeTextLinesLimit = (settings.catalogGridModeTextLinesLimit ?? 0) + 1;
																	});
																},
																child: const Icon(CupertinoIcons.plus)
															)
														]
													),
													const SizedBox(height: 8),
													Row(
														children: [
															const Expanded(
																child: Text('Thumbnail behind text')
															),
															CupertinoSwitch(
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
															CupertinoSwitch(
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
													SizedBox.fromSize(
														size: size,
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
					) : CupertinoButton.filled(
						padding: const EdgeInsets.all(16),
						child: const Row(
							mainAxisSize: MainAxisSize.min,
							children: [
								Icon(CupertinoIcons.resize_v),
								SizedBox(width: 8),
								Text('Edit catalog row item height')
							]
						),
						onPressed: () async {
							await showCupertinoModalPopup(
								context: context,
								useRootNavigator: false,
								builder: (context) => StatefulBuilder(
									builder: (context, setDialogState) => CupertinoActionSheet(
										title: const Text('Edit catalog grid item layout'),
										actions: [
											CupertinoButton(
												child: const Text('Close'),
												onPressed: () => Navigator.pop(context)
											)
										],
										message: DefaultTextStyle(
											style: DefaultTextStyle.of(context).style,
											child: Column(
												crossAxisAlignment: CrossAxisAlignment.start,
												children: [
													SizedBox(
														height: settings.maxCatalogRowHeight,
														child: ThreadRow(
															contentFocus: false,
															isSelected: false,
															thread: _makeFakeThread()
														)
													),
													const SizedBox(height: 8),
													Text('Height: ${settings.maxCatalogRowHeight.round()}px'),
													Row(
														mainAxisAlignment: MainAxisAlignment.end,
														children: [
															CupertinoSlider(
																value: settings.maxCatalogRowHeight,
																min: 100,
																max: 600,
																onChanged: (d) {
																	setDialogState(() {
																		settings.maxCatalogRowHeight = d;
																	});
																}
															),
															CupertinoButton(
																padding: EdgeInsets.zero,
																onPressed: settings.maxCatalogRowHeight <= 100 ? null : () {
																	setDialogState(() {
																		settings.maxCatalogRowHeight--;
																	});
																},
																child: const Icon(CupertinoIcons.minus)
															),
															CupertinoButton(
																padding: EdgeInsets.zero,
																onPressed: settings.maxCatalogRowHeight >= 600 ? null : () {
																	setDialogState(() {
																		settings.maxCatalogRowHeight++;
																	});
																},
																child: const Icon(CupertinoIcons.plus)
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
					child: CupertinoButton.filled(
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
							await showCupertinoModalPopup(
								context: context,
								useRootNavigator: false,
								builder: (context) => StatefulBuilder(
									builder: (context, setDialogState) {
										final settings = context.watch<EffectiveSettings>();
										return CupertinoActionSheet(
											title: const Text('Edit catalog item details'),
											actions: [
												CupertinoButton(
													child: const Text('Close'),
													onPressed: () => Navigator.pop(context)
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
																const Text('Hide default names'),
																const Spacer(),
																CupertinoSwitch(
																	value: settings.hideDefaultNamesInCatalog,
																	onChanged: (d) => settings.hideDefaultNamesInCatalog = d
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
														),
														Row(
															children: [
																const Text('Show country name'),
																const Spacer(),
																CupertinoSwitch(
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
						CupertinoSwitch(
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
						CupertinoButton(
							minSize: 0,
							padding: EdgeInsets.zero,
							child: const Icon(CupertinoIcons.question_circle),
							onPressed: () {
								showCupertinoDialog<bool>(
									context: context,
									barrierDismissible: true,
									builder: (context) => CupertinoAlertDialog(
										content: Text('When the screen is at least ${settings.twoPaneBreakpoint.round()} pixels wide, two columns will be used.\nThe board catalog will be on the left and the current thread will be on the right.'),
										actions: [
											CupertinoDialogAction(
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
				CupertinoSegmentedControl<(bool, bool?)>(
					children: const {
						(true, true): Padding(
							padding: EdgeInsets.all(8),
							child: Text('Left')
						),
						(false, null): Padding(
							padding: EdgeInsets.all(8),
							child: Text('Off')
						),
						(true, false): Padding(
							padding: EdgeInsets.all(8),
							child: Text('Right')
						)
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
								color: CupertinoTheme.of(context).primaryColorWithBrightness(0.6)
							),
							padding: const EdgeInsets.all(3),
							width: 13,
							alignment: Alignment.center,
							child: Text('1', style: TextStyle(color: settings.theme.backgroundColor, fontSize: 13))
						),
						Container(
							decoration: BoxDecoration(
								borderRadius: const BorderRadius.only(
									topRight: Radius.circular(6),
									bottomRight: Radius.circular(6),
								),
								color: CupertinoTheme.of(context).primaryColor
							),
							padding: const EdgeInsets.all(3),
							width: 13,
							alignment: Alignment.center,
							child: Text('1', style: TextStyle(color: settings.theme.backgroundColor, fontSize: 13))
						),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('List position indicator location')
						)
					]
				),
				const SizedBox(height: 16),
				CupertinoSegmentedControl<bool>(
					children: const {
						true: Padding(
							padding: EdgeInsets.all(8),
							child: Text('Left')
						),
						false: Padding(
							padding: EdgeInsets.all(8),
							child: Text('Right')
						)
					},
					groupValue: settings.showListPositionIndicatorsOnLeft,
					onValueChanged: (newValue) {
						settings.showListPositionIndicatorsOnLeft = newValue;
					}
				),
				if (Platform.isAndroid) ...[
					const SizedBox(height: 32),
					Row(
						children: [
							const Icon(CupertinoIcons.device_phone_portrait),
							const SizedBox(width: 8),
							const Text('Use status bar workaround'),
							const SizedBox(width: 8),
							CupertinoButton(
								minSize: 0,
								padding: EdgeInsets.zero,
								child: const Icon(CupertinoIcons.question_circle),
								onPressed: () {
									showCupertinoDialog<bool>(
										context: context,
										barrierDismissible: true,
										builder: (context) => CupertinoAlertDialog(
											content: const Text('Some devices have a bug in their Android ROM, where the status bar cannot be properly hidden.\n\nIf this workaround is enabled, the status bar will not be hidden when opening the gallery.'),
											actions: [
												CupertinoDialogAction(
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
							const Spacer(),
							CupertinoSwitch(
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
						CupertinoButton.filled(
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
				CupertinoSegmentedControl<bool>(
					children: const {
						false: Padding(
							padding: EdgeInsets.all(8),
							child: Row(
								mainAxisSize: MainAxisSize.min,
								children: [
									Icon(CupertinoIcons.list_bullet),
									SizedBox(width: 8),
									Text('Linear')
								]
							)
						),
						true: Padding(
							padding: EdgeInsets.all(8),
							child: Row(
								mainAxisSize: MainAxisSize.min,
								children: [
									Icon(CupertinoIcons.list_bullet_indent),
									SizedBox(width: 8),
									Text('Tree')
								]
							)
						)
					},
					groupValue: _threadLayoutImageboard.persistence.browserState.useTree ?? _threadLayoutImageboard.site.useTree,
					onValueChanged: (newValue) {
						_threadLayoutImageboard.persistence.browserState.useTree = newValue;
						_threadLayoutImageboard.persistence.didUpdateBrowserState();
						setState(() {});
					}
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.wand_stars),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Blur effects')
						),
						CupertinoSwitch(
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
						CupertinoSwitch(
							value: settings.exactTimeIsTwelveHour,
							onChanged: (newValue) {
								settings.exactTimeIsTwelveHour = newValue;
							}
						)
					]
				),
				const SizedBox(height: 32),
				Row(
					children: [
						const Icon(CupertinoIcons.calendar),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Show day-of-week even if today')
						),
						CupertinoSwitch(
							value: settings.exactTimeShowsDayOfWeekForToday,
							onChanged: (newValue) {
								settings.exactTimeShowsDayOfWeekForToday = newValue;
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
	Imageboard _threadsPanelImageboard = ImageboardRegistry.instance.imageboards.first;

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<EffectiveSettings>();
		return _SettingsPage(
			title: 'Data Settings',
			children: [
				if (Platform.isAndroid) ...[
					const SizedBox(height: 16),
					Center(
						child: CupertinoButton.filled(
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
					)
				],
				const SizedBox(height: 16),
				Row(
					children: [
						const Icon(CupertinoIcons.textformat),
						const SizedBox(width: 8),
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
									builder: (context) => CupertinoAlertDialog(
										content: const Text('Send the captcha images you solve to a database to improve the automated solver. No other information about your posts will be collected.'),
										actions: [
											CupertinoDialogAction(
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
						const Spacer(),
						CupertinoSwitch(
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
						CupertinoButton(
							minSize: 0,
							padding: EdgeInsets.zero,
							child: const Icon(CupertinoIcons.question_circle),
							onPressed: () {
								showCupertinoDialog<bool>(
									context: context,
									barrierDismissible: true,
									builder: (context) => CupertinoAlertDialog(
										content: const Text('Crash stack traces and uncaught exceptions will be used to help fix bugs. No personal information will be collected.'),
										actions: [
											CupertinoDialogAction(
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
						const Spacer(),
						CupertinoSwitch(
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
						CupertinoButton(
							minSize: 0,
							padding: EdgeInsets.zero,
							child: const Icon(CupertinoIcons.question_circle),
							onPressed: () {
								showCupertinoDialog<bool>(
									context: context,
									barrierDismissible: true,
									builder: (context) => CupertinoAlertDialog(
										content: const Text('Links to sites such as YouTube will show the thumbnail and title of the page instead of the link URL.'),
										actions: [
											CupertinoDialogAction(
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
						const Spacer(),
						CupertinoSwitch(
							value: settings.useEmbeds,
							onChanged: (setting) {
								settings.useEmbeds = setting;
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
					child: CupertinoAdaptiveSegmentedControl<int>(
						children: const {
							7: Padding(
								padding: EdgeInsets.all(8),
								child: Text('7 days', textAlign: TextAlign.center)
							),
							14: Padding(
								padding: EdgeInsets.all(8),
								child: Text('14 days', textAlign: TextAlign.center)
							),
							30: Padding(
								padding: EdgeInsets.all(8),
								child: Text('30 days', textAlign: TextAlign.center)
							),
							60: Padding(
								padding: EdgeInsets.all(8),
								child: Text('60 days', textAlign: TextAlign.center)
							),
							100000: Padding(
								padding: EdgeInsets.all(8),
								child: Text('Never', textAlign: TextAlign.center)
							)
						},
						groupValue: context.watch<EffectiveSettings>().automaticCacheClearDays,
						onValueChanged: (setting) {
							context.read<EffectiveSettings>().automaticCacheClearDays = setting;
						}
					)
				),
				const SizedBox(height: 16),
				const Row(
					children: [
						Icon(CupertinoIcons.photo_on_rectangle),
						SizedBox(width: 8),
						Expanded(
							child: Text('Cached media')
						)
					]
				),
				const SettingsCachePanel(),
				const SizedBox(height: 16),
				Row(
					children: [
						const Icon(CupertinoIcons.archivebox),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Cached threads and history')
						),
						CupertinoButton.filled(
							padding: const EdgeInsets.all(8),
							onPressed: () async {
								final newImageboard = await _pickImageboard(context, _threadsPanelImageboard);
								if (newImageboard != null) {
									setState(() {
										_threadsPanelImageboard = newImageboard;
									});
								}
							},
							child: Row(
								mainAxisSize: MainAxisSize.min,
								children: [
									ImageboardIcon(
										imageboardKey: _threadsPanelImageboard.key
									),
									const SizedBox(width: 8),
									Text(_threadsPanelImageboard.site.name)
								]
							)
						)
					]
				),
				SettingsThreadsPanel(
					persistence: _threadsPanelImageboard.persistence
				),
				const SizedBox(height: 16),
				Center(
					child: CupertinoButton.filled(
						child: const Row(
							mainAxisSize: MainAxisSize.min,
							children: [
								Icon(CupertinoIcons.wifi),
								SizedBox(width: 8),
								Text('Clear Wi-Fi cookies')
							]
						),
						onPressed: () {
							Persistence.wifiCookies.deleteAll();
						}
					)
				),
				const SizedBox(height: 16),
				Center(
					child: CupertinoButton.filled(
						child: const Row(
							mainAxisSize: MainAxisSize.min,
							children: [
								Icon(CupertinoIcons.antenna_radiowaves_left_right),
								SizedBox(width: 8),
								Text('Clear cellular cookies')
							]
						),
						onPressed: () {
							Persistence.cellularCookies.deleteAll();
						}
					)
				),
				const SizedBox(height: 16),
				Center(
					child: CupertinoButton.filled(
						onPressed: () async {
							final controller = TextEditingController(text: settings.userAgent);
							final newUserAgent = await showCupertinoDialog<String>(
								context: context,
								barrierDismissible: true,
								builder: (context) => CupertinoAlertDialog(
									title: const Text('Edit User-Agent'),
									content: Column(
										mainAxisSize: MainAxisSize.min,
										children: [
											const SizedBox(height: 10),
											if (ImageboardRegistry.instance.getImageboard('4chan') != null) ...[
												const Text('This user-agent might be overridden for 4chan captcha requests to work with the Cloudflare check.'),
												const SizedBox(height: 10)
											],
											CupertinoTextField(
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
										CupertinoDialogAction(
											child: const Text('Random'),
											onPressed: () {
												final idx = userAgents.indexOf(controller.text) + 1;
												controller.text = userAgents[idx % userAgents.length];
											}
										),
										CupertinoDialogAction(
											isDefaultAction: true,
											child: const Text('Save'),
											onPressed: () => Navigator.pop(context, controller.text.isEmpty ? null : controller.text)
										),
										CupertinoDialogAction(
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
		await Persistence.clearFilesystemCaches(null);
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
							CupertinoButton.filled(
								padding: const EdgeInsets.all(16),
								onPressed: _readFilesystemInfo,
								child: const Text('Recalculate')
							),
							CupertinoButton.filled(
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
					return (days, oldThreads);
				}).toList();
				oldThreadRows.removeRange(oldThreadRows.lastIndexWhere((r) => r.$2.isNotEmpty) + 1, oldThreadRows.length);
				confirmDelete(List<PersistentThreadState> toDelete) async {
					final confirmed = await showCupertinoDialog<bool>(
						context: context,
						builder: (context) => CupertinoAlertDialog(
							title: const Text('Confirm deletion'),
							content: Text('${describeCount(toDelete.length, 'thread')} will be deleted'),
							actions: [
								CupertinoDialogAction(
									child: const Text('Cancel'),
									onPressed: () {
										Navigator.of(context).pop();
									}
								),
								CupertinoDialogAction(
									isDestructiveAction: true,
									onPressed: () {
										Navigator.of(context).pop(true);
									},
									child: const Text('Confirm')
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
										onPressed: null,
										child: Text('Delete')
									)
								]
							),
							...oldThreadRows.map((entry) {
								return TableRow(
									children: [
										Text('Over ${entry.$1} days old', textAlign: TextAlign.left),
										Text(entry.$2.length.toString(), textAlign: TextAlign.right),
										CupertinoButton(
											padding: EdgeInsets.zero,
											onPressed: entry.$2.isEmpty ? null : () => confirmDelete(entry.$2),
											child: const Text('Delete')
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
					('Board', _boardController, null),
					(isThread ? 'Thread no.' : 'Post no.', _idController, null),
					('Reply Count', _replyCountController, null),
					if (isThread) ('Subject', _subjectController, null),
					('Name', _nameController, null),
					('Poster ID', _posterIdController, null),
					('Flag', _flagController, null),
					('Filename', _filenameController, null),
					('Text', _textController, 5),
				]) ...[
					Text(field.$1),
					Padding(
						padding: const EdgeInsets.all(16),
						child: CupertinoTextField(
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
		final cont = await showCupertinoDialog<bool>(
			context: context,
			builder: (context) => CupertinoAlertDialog(
				title: Text('${widget.loginSystem.name} Login'),
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
								smartDashesType: SmartDashesType.disabled,
								smartQuotesType: SmartQuotesType.disabled,
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
				await widget.loginSystem.login(fields);
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
										await widget.loginSystem.clearLoginCookies(true);
										await widget.loginSystem.clearSavedLoginFields();
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
						child: Text('Try to use ${widget.loginSystem.name} on mobile networks?')
					)
				),
				const SizedBox(height: 16),
				CupertinoSegmentedControl<NullSafeOptional>(
					children: const {
						NullSafeOptional.false_: Padding(
							padding: EdgeInsets.all(8),
							child: Text('No')
						),
						NullSafeOptional.null_: Padding(
							padding: EdgeInsets.all(8),
							child: Text('Ask')
						),
						NullSafeOptional.true_: Padding(
							padding: EdgeInsets.all(8),
							child: Text('Yes')
						)
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
	return showCupertinoModalPopup<Imageboard?>(
		context: context,
		builder: (context) => CupertinoActionSheet(
			title: const Text('Select site'),
			actions: ImageboardRegistry.instance.imageboards.map((imageboard) => CupertinoActionSheetAction(
				child: Row(
					mainAxisSize: MainAxisSize.min,
					children: [
						ImageboardIcon(imageboardKey: imageboard.key),
						const SizedBox(width: 8),
						Text(imageboard.site.name, style: TextStyle(
							fontWeight: (imageboard == current) ? FontWeight.bold : null
						))
					]
				),
				onPressed: () {
					Navigator.of(context, rootNavigator: true).pop(imageboard);
				}
			)).toList(),
			cancelButton: CupertinoActionSheetAction(
				child: const Text('Cancel'),
				onPressed: () => Navigator.of(context, rootNavigator: true).pop()
			)
		)
	);
}
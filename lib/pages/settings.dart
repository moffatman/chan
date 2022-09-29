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
import 'package:chan/services/persistence.dart';
import 'package:chan/services/storage.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/cupertino_page_route.dart';
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
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tuple/tuple.dart';
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
									site: site
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
								child: Row(
									mainAxisSize: MainAxisSize.min,
									children: const [
										Text('Synchronize '),
										Icon(Icons.sync_rounded, size: 16)
									]
								),
								onPressed: () async {
									await settings.updateContentSettings();
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
									child: Row(
										mainAxisSize: MainAxisSize.min,
										children: const [
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
											if (toDelete != null) {
												ImageboardRegistry.instance.getImageboard(toDelete)?.deleteAllData();
												final response = await Dio().delete('$contentSettingsApiRoot/user/${Persistence.settings.userId}/site/$toDelete');
												if (response.data['error'] != null) {
													throw Exception(response.data['error']);
												}
												await settings.updateContentSettings();
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
								child: Row(
									mainAxisSize: MainAxisSize.min,
									children: const [
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
					title: 'Behavior Settings',
					pageBuilder: (context) => const SettingsBehaviorPage()
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
	Imageboard _imageFilterImageboard = ImageboardRegistry.instance.imageboards.first;
	Imageboard _loginSystemImageboard = ImageboardRegistry.instance.imageboards.first;

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<EffectiveSettings>();
		return _SettingsPage(
			title: 'Behavior Settings',
			children: [
				const SettingsFilterPanel(),
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
							child: Text('Ignoring ${describeCount(_imageFilterImageboard.persistence.browserState.hiddenImageMD5s.length, 'image')}')
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
							child: Text(_loginSystemImageboard.site.getLoginSystemName() ?? 'No login system')
						),
						if (_loginSystemImageboard.site.getLoginSystemName() != null) ...[
							CupertinoButton.filled(
								padding: const EdgeInsets.all(8),
								onPressed: () {
									showCupertinoDialog(
										context: context,
										barrierDismissible: true,
										builder: (context) => CupertinoAlertDialog(
											content: SettingsLoginPanel(
												site: _loginSystemImageboard.site
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
								child: Text(_loginSystemImageboard.site.getSavedLoginFields() == null ? 'Logged out' : 'Logged in')
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
				Row(
					children: const [
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
					Row(
						children: const [
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
				Row(
					children: const [
						Icon(CupertinoIcons.globe),
						SizedBox(width: 8),
						Text('Links open...')
					]
				),
				const SizedBox(height: 16),
				CupertinoSegmentedControl<_NullSafeOptional>(
					children: const {
						_NullSafeOptional.false_: Padding(
							padding: EdgeInsets.all(8),
							child: Text('Externally')
						),
						_NullSafeOptional.null_: Padding(
							padding: EdgeInsets.all(8),
							child: Text('Ask')
						),
						_NullSafeOptional.true_: Padding(
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
									child: AutoSizeText(settings.settingsQuickAction.name, maxLines: 1)
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

	@override
	void dispose() {
		super.dispose();
		controller.dispose();
	}
}

class SettingsAppearancePage extends StatelessWidget {
	const SettingsAppearancePage({
		Key? key
	}) : super(key: key);

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
				Row(
					children: const [
						Icon(CupertinoIcons.macwindow),
						SizedBox(width: 8),
						Expanded(
							child: Text('Interface Style')
						)
					]
				),
				const SizedBox(height: 16),
				CupertinoSegmentedControl<TristateSystemSetting>(
					children: {
						TristateSystemSetting.a: Padding(
							padding: const EdgeInsets.all(8),
							child: Row(
								mainAxisSize: MainAxisSize.min,
								children: const [
									Icon(CupertinoIcons.hand_draw),
									SizedBox(width: 8),
									Text('Touch')
								]
							)
						),
						TristateSystemSetting.system: const Padding(
							padding: EdgeInsets.all(8),
							child: Text('Automatic')
						),
						TristateSystemSetting.b: Padding(
							padding: const EdgeInsets.all(8),
							child: Row(
								mainAxisSize: MainAxisSize.min,
								children: const [
									Icon(Icons.mouse),
									SizedBox(width: 8),
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
				Row(
					children: const [
						Icon(CupertinoIcons.paintbrush),
						SizedBox(width: 8),
						Expanded(
							child: Text('Active Theme')
						)
					]
				),
				const SizedBox(height: 16),
				CupertinoSegmentedControl<TristateSystemSetting>(
					children: {
						TristateSystemSetting.a: Padding(
							padding: const EdgeInsets.all(8),
							child: Row(
								mainAxisSize: MainAxisSize.min,
								children: const [
									Icon(CupertinoIcons.sun_max),
									SizedBox(width: 8),
									Text('Light')
								]
							)
						),
						TristateSystemSetting.system: const Padding(
							padding: EdgeInsets.all(8),
							child: Text('Follow System', textAlign: TextAlign.center)
						),
						TristateSystemSetting.b: Padding(
							padding: const EdgeInsets.all(8),
							child: Row(
								mainAxisSize: MainAxisSize.min,
								children: const [
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
					Tuple5('light theme', settings.lightTheme, settings.lightThemeKey, (key) {
						settings.lightThemeKey = key;
						settings.handleThemesAltered();
					}, CupertinoIcons.sun_max),
					Tuple5('dark theme', settings.darkTheme, settings.darkThemeKey, (key) {
						settings.darkThemeKey = key;
						settings.handleThemesAltered();
					}, CupertinoIcons.moon)
				]) ... [
					Row(
						children: [
							const SizedBox(width: 16),
							Icon(theme.item5),
							const SizedBox(width: 8),
							Text(theme.item3),
							const Spacer(),
							Padding(
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
															Text('Picking ${theme.item1}')
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
																							fontWeight: themeNames[i] == theme.item3 ? FontWeight.bold : null
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
											theme.item4(selectedKey);
										}
									},
									child: Text('Pick ${theme.item1}')
								)
							)
						]
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
								children: <Tuple4<String, Color, ValueChanged<Color>, Color?>>[
									Tuple4('Primary', theme.item2.primaryColor, (c) => theme.item2.primaryColor = c, theme.item2.copiedFrom?.primaryColor),
									Tuple4('Secondary', theme.item2.secondaryColor, (c) => theme.item2.secondaryColor = c, theme.item2.copiedFrom?.secondaryColor),
									Tuple4('Bar', theme.item2.barColor, (c) => theme.item2.barColor = c, theme.item2.copiedFrom?.barColor),
									Tuple4('Background', theme.item2.backgroundColor, (c) => theme.item2.backgroundColor = c, theme.item2.copiedFrom?.backgroundColor),
									Tuple4('Quote', theme.item2.quoteColor, (c) => theme.item2.quoteColor = c, theme.item2.copiedFrom?.quoteColor)
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
																child: Column(
																	mainAxisSize: MainAxisSize.min,
																	children: [
																		Material(
																			color: Colors.transparent,
																			child: ColorPicker(
																				pickerColor: color.item2,
																				onColorChanged: color.item3,
																				enableAlpha: false,
																				portraitOnly: true,
																				displayThumbColor: true,
																				hexInputBar: true
																			)
																		),
																		CupertinoButton(
																			padding: const EdgeInsets.all(8),
																			color: color.item4,
																			onPressed: color.item2 == color.item4 ? null : () {
																				color.item3(color.item4!);
																				settings.handleThemesAltered();
																			},
																			child: Text('Reset to original color', style: TextStyle(color: (color.item4?.computeLuminance() ?? 0) > 0.5 ? Colors.black : Colors.white))
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
				Row(
					children: const [
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
						child: Row(
							mainAxisSize: MainAxisSize.min,
							children: const [
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
				Row(
					children: const [
						Icon(CupertinoIcons.rectangle_stack),
						SizedBox(width: 8),
						Expanded(
							child: Text('Catalog Layout')
						)
					]
				),
				const SizedBox(height: 16),
				CupertinoSegmentedControl<bool>(
					children: {
						false: Padding(
							padding: const EdgeInsets.all(8),
							child: Row(
								mainAxisSize: MainAxisSize.min,
								children: const [
									Icon(CupertinoIcons.rectangle_grid_1x2),
									SizedBox(width: 8),
									Text('Rows')
								]
							)
						),
						true: Padding(
							padding: const EdgeInsets.all(8),
							child: Row(
								mainAxisSize: MainAxisSize.min,
								children: const [
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
				Center(
					child: settings.useCatalogGrid ? CupertinoButton.filled(
						padding: const EdgeInsets.all(16),
						child: Row(
							mainAxisSize: MainAxisSize.min,
							children: const [
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
																		settings.catalogGridModeTextLinesLimit = (settings.catalogGridModeTextLinesLimit ?? (settings.catalogGridHeight / (2 * 14 * MediaQuery.of(context).textScaleFactor)).round()) - 1;
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
														mainAxisAlignment: MainAxisAlignment.spaceBetween,
														children: [
															const Text('Thumbnail behind text'),
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
													SizedBox.fromSize(
														size: size,
														child: ThreadRow(
															contentFocus: true,
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
						child: Row(
							mainAxisSize: MainAxisSize.min,
							children: const [
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
						child: Row(
							mainAxisSize: MainAxisSize.min,
							children: const [
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
																const Expanded(
																	child: Text('Show counters in their own row'),
																),
																CupertinoSwitch(
																	value: settings.useFullWidthForCatalogCounters,
																	onChanged: (d) => settings.useFullWidthForCatalogCounters = d
																)
															]
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
				Row(
					children: [
						const Icon(CupertinoIcons.arrow_up_down),
						const SizedBox(width: 8),
						const Expanded(
							child: Text('Show scrollbars')
						),
						CupertinoSwitch(
							value: settings.showScrollbars,
							onChanged: (newValue) {
								settings.showScrollbars = newValue;
							}
						)
					]
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
				const SizedBox(height: 16),
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
						const Text('Show rich links when possible'),
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
				Row(
					children: const [
						Icon(CupertinoIcons.calendar),
						SizedBox(width: 8),
						Expanded(
							child: Text('Automatically clear caches older than...')
						)
					]
				),
				Padding(
					padding: const EdgeInsets.all(16),
					child: CupertinoSegmentedControl<int>(
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
				Row(
					children: const [
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
						child: Row(
							mainAxisSize: MainAxisSize.min,
							children: const [
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
						child: Row(
							mainAxisSize: MainAxisSize.min,
							children: const [
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
					return Tuple2(days, oldThreads);
				}).toList();
				oldThreadRows.removeRange(oldThreadRows.lastIndexWhere((r) => r.item2.isNotEmpty) + 1, oldThreadRows.length);
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
										Text('Over ${entry.item1} days old', textAlign: TextAlign.left),
										Text(entry.item2.length.toString(), textAlign: TextAlign.right),
										CupertinoButton(
											padding: EdgeInsets.zero,
											onPressed: entry.item2.isEmpty ? null : () => confirmDelete(entry.item2),
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

class SettingsFilterPanel extends StatefulWidget {
	const SettingsFilterPanel({
		Key? key
	}) : super(key: key);
	@override
	createState() => _SettingsFilterPanelState();
}

class _SettingsFilterPanelState extends State<SettingsFilterPanel> {
	late final TextEditingController regexController;
	late final FocusNode regexFocusNode;
	bool showRegex = false;
	bool dirty = false;

	@override
	void initState() {
		super.initState();
		regexController = TextEditingController(text: context.read<EffectiveSettings>().filterConfiguration);
		regexFocusNode = FocusNode();
	}

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<EffectiveSettings>();
		final filters = <int, CustomFilter>{};
		for (final line in settings.filterConfiguration.split('\n').asMap().entries) {
			if (line.value.isEmpty) {
				continue;
			}
			try {
				filters[line.key] = CustomFilter.fromStringConfiguration(line.value);
			}
			on FilterException {
				// don't show
			}
		}
		Future<Tuple2<bool, CustomFilter?>?> editFilter(CustomFilter? originalFilter) {
			final filter = originalFilter ?? CustomFilter(
				configuration: '',
				pattern: RegExp('')
			);
			final patternController = TextEditingController(text: filter.pattern.pattern);
			final labelController = TextEditingController(text: filter.label);
			final patternFields = filter.patternFields.toList();
			bool? hasFile = filter.hasFile;
			bool threadOnly = filter.threadOnly;
			final List<String> boards = filter.boards.toList();
			final List<String> excludeBoards = filter.excludeBoards.toList();
			int? minRepliedTo = filter.minRepliedTo;
			FilterResultType outputType = filter.outputType;
			const labelStyle = TextStyle(fontWeight: FontWeight.bold);
			return showCupertinoModalPopup<Tuple2<bool, CustomFilter?>>(
				context: context,
				builder: (context) => StatefulBuilder(
					builder: (context, setInnerState) => CupertinoActionSheet(
						title: const Text('Edit filter'),
						message: DefaultTextStyle(
							style: DefaultTextStyle.of(context).style,
							child: Column(
								mainAxisSize: MainAxisSize.min,
								crossAxisAlignment: CrossAxisAlignment.center,
								children: [
									const Text('Label', style: labelStyle),
									Padding(
										padding: const EdgeInsets.all(16),
										child: SizedBox(
											width: 300,
											child: CupertinoTextField(
												controller: labelController
											)
										)
									),
									const Text('Pattern', style: labelStyle),
									Padding(
										padding: const EdgeInsets.all(16),
										child: SizedBox(
											width: 300,
											child: CupertinoTextField(
												controller: patternController
											)
										)
									),
									const Text('Search in fields', style: labelStyle),
									Padding(
										padding: const EdgeInsets.all(16),
										child: Column(
											mainAxisSize: MainAxisSize.min,
											children: [
												for (final field in allPatternFields) Row(
													mainAxisSize: MainAxisSize.min,
													children: [
														SizedBox(
															width: 200,
															child: Text(field)
														),
														CupertinoSwitch(
															value: patternFields.contains(field),
															onChanged: (v) {
																if (v) {
																	patternFields.add(field);
																}
																else {
																	patternFields.remove(field);
																}
																setInnerState(() {});
															}
														)
													]
												)
											]
										)
									),
									Container(
										padding: const EdgeInsets.all(16),
										alignment: Alignment.center,
										child: CupertinoSegmentedControl<_NullSafeOptional>(
											groupValue: hasFile.value,
											onValueChanged: (v) {
												setInnerState(() {
													hasFile = v.value;
												});
											},
											children: const {
												_NullSafeOptional.null_: Padding(
													padding: EdgeInsets.all(8),
													child: Text('All posts', textAlign: TextAlign.center)
												),
												_NullSafeOptional.false_: Padding(
													padding: EdgeInsets.all(8),
													child: Text('Without images', textAlign: TextAlign.center)
												),
												_NullSafeOptional.true_: Padding(
													padding: EdgeInsets.all(8),
													child: Text('With images', textAlign: TextAlign.center)
												)
											}
										)
									),
									Padding(
										padding: const EdgeInsets.all(16),
										child: CupertinoSegmentedControl<bool>(
											groupValue: threadOnly,
											onValueChanged: (v) {
												setInnerState(() {
													threadOnly = v;
												});
											},
											children: const {
												false: Padding(
													padding: EdgeInsets.all(8),
													child: Text('All posts')
												),
												true: Padding(
													padding: EdgeInsets.all(8),
													child: Text('Threads only')
												)
											}
										)
									),
									const SizedBox(height: 16),
									CupertinoButton.filled(
										padding: const EdgeInsets.all(16),
										onPressed: () async {
											await editStringList(
												context: context,
												list: boards,
												name: 'board',
												title: 'Edit boards'
											);
											setInnerState(() {});
										},
										child: Text(boards.isEmpty ? 'All boards' : 'Only on ${boards.map((b) => '/$b/').join(', ')}')
									),
									const SizedBox(height: 16),
									CupertinoButton.filled(
										padding: const EdgeInsets.all(16),
										onPressed: () async {
											await editStringList(
												context: context,
												list: excludeBoards,
												name: 'excluded board',
												title: 'Edit excluded boards'
											);
											setInnerState(() {});
										},
										child: Text(excludeBoards.isEmpty ? 'No excluded boards' : 'Exclude ${excludeBoards.map((b) => '/$b/').join(', ')}')
									),
									const SizedBox(height: 16),
									CupertinoButton.filled(
										padding: const EdgeInsets.all(16),
										onPressed: () async {
											final controller = TextEditingController(text: minRepliedTo?.toString());
											await showCupertinoDialog(
												context: context,
												barrierDismissible: true,
												builder: (context) => CupertinoAlertDialog(
													title: const Text('Set minimum replied-to posts count'),
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
													content: Padding(
														padding: const EdgeInsets.only(top: 16),
														child: CupertinoTextField(
															autofocus: true,
															controller: controller,
															onSubmitted: (s) {
																Navigator.pop(context);
															}
														)
													)
												)
											);
											minRepliedTo = int.tryParse(controller.text);
											controller.dispose();
											setInnerState(() {});
										},
										child: Text(minRepliedTo == null ? 'No replied-to criteria' : 'With at least $minRepliedTo replied-to posts')
									),
									const SizedBox(height: 16),
									const Text('Action', style: labelStyle),
									Container(
										padding: const EdgeInsets.all(16),
										alignment: Alignment.center,
										child: CupertinoSegmentedControl<FilterResultType>(
											groupValue: outputType,
											onValueChanged: (v) {
												setInnerState(() {
													outputType = v;
												});
											},
											children: const {
												FilterResultType.hide: Padding(
													padding: EdgeInsets.all(8),
													child: Text('Hide')
												),
												FilterResultType.highlight: Padding(
													padding: EdgeInsets.all(8),
													child: Text('Highlight', textAlign: TextAlign.center)
												),
												FilterResultType.pinToTop: Padding(
													padding: EdgeInsets.all(8),
													child: Text('Pin-to-top', textAlign: TextAlign.center)
												),
												FilterResultType.autoSave: Padding(
													padding: EdgeInsets.all(8),
													child: Text('Auto-save', textAlign: TextAlign.center)
												)
											}
										)
									)
								]
							)
						),
						actions: [
							if (originalFilter != null) CupertinoDialogAction(
								isDestructiveAction: true,
								onPressed: () => Navigator.pop(context, const Tuple2(true, null)),
								child: const Text('Delete')
							),
							CupertinoDialogAction(
								onPressed: () {
									Navigator.pop(context, Tuple2(false, CustomFilter(
										pattern: RegExp(patternController.text),
										patternFields: patternFields,
										boards: boards,
										excludeBoards: excludeBoards,
										hasFile: hasFile,
										threadOnly: threadOnly,
										minRepliedTo: minRepliedTo,
										outputType: outputType,
										label: labelController.text
									)));
								},
								child: originalFilter == null ? const Text('Add') : const Text('Save')
							)
						],
						cancelButton: CupertinoDialogAction(
							onPressed: () => Navigator.pop(context),
							child: const Text('Cancel')
						)
					)
				)
			);
		}
		return Column(
			mainAxisSize: MainAxisSize.min,
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				const SizedBox(height: 16),
				Row(
					children: [
						const Icon(CupertinoIcons.scope),
						const SizedBox(width: 8),
						const Text('Filters'),
						const Spacer(),
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
						const SizedBox(width: 8),
						CupertinoSegmentedControl<bool>(
							padding: EdgeInsets.zero,
							groupValue: showRegex,
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
								showRegex = v;
							})
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
				AnimatedSize(
					duration: const Duration(milliseconds: 350),
					curve: Curves.ease,
					alignment: Alignment.topCenter,
					child: AnimatedSwitcher(
						duration: const Duration(milliseconds: 350),
						switchInCurve: Curves.ease,
						switchOutCurve: Curves.ease,
						child: showRegex ? Column(
							mainAxisSize: MainAxisSize.min,
							crossAxisAlignment: CrossAxisAlignment.stretch,
							children: [
								Wrap(
									crossAxisAlignment: WrapCrossAlignment.center,
									alignment: WrapAlignment.start,
									spacing: 16,
									runSpacing: 16,
									children: [
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
																'You can write text before the opening slash to give the filter a label: `Funposting/bane/i`'
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
																'The list of possible fields is $allPatternFields\n'
																'The default fields that are searched are $defaultPatternFields'
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
										if (dirty) CupertinoButton(
											padding: EdgeInsets.zero,
											minSize: 0,
											child: const Text('Save'),
											onPressed: () {
												settings.filterConfiguration = regexController.text;
												regexFocusNode.unfocus();
												setState(() {
													dirty = false;
												});
											}
										)
									]
								),
								const SizedBox(height: 16),
								Padding(
									padding: const EdgeInsets.only(left: 16, right: 16),
									child: CupertinoTextField(
										style: GoogleFonts.ibmPlexMono(),
										minLines: 5,
										maxLines: 5,
										focusNode: regexFocusNode,
										controller: regexController,
										onChanged: (_) {
											if (!dirty) {
												setState(() {
													dirty = true;
												});
											}
										}
									)
								)
							]
						) : ClipRRect(
							borderRadius: BorderRadius.circular(8),
							child: CupertinoListSection(
								topMargin: 0,
								margin: EdgeInsets.zero,
								children: [
									...filters.entries.map((filter) {
										return Row(
											children: [
												Expanded(
													child: Opacity(
														opacity: filter.value.disabled ? 0.5 : 1,
														child: CupertinoListTile(
															title: Text(filter.value.label.isNotEmpty ? filter.value.label : '/${filter.value.pattern.pattern}/'),
															leading:  const {
																FilterResultType.hide: Icon(CupertinoIcons.eye_slash),
																FilterResultType.highlight: Icon(CupertinoIcons.sun_max_fill),
																FilterResultType.pinToTop: Icon(CupertinoIcons.arrow_up_to_line),
																FilterResultType.autoSave: Icon(CupertinoIcons.bookmark_fill)
															}[filter.value.outputType],
															additionalInfo: Wrap(
																children: [
																	if (filter.value.minRepliedTo != null) Text('Replying to >=${filter.value.minRepliedTo}'),
																	if (filter.value.threadOnly) const Text('Threads only'),
																	if (filter.value.hasFile == true) const Icon(CupertinoIcons.doc)
																	else if (filter.value.hasFile == false) Stack(
																		children: const [
																			Icon(CupertinoIcons.doc),
																			Icon(CupertinoIcons.xmark)
																		]
																	),
																	for (final board in filter.value.boards) Text('/$board/'),
																	for (final board in filter.value.excludeBoards) Text('not /$board/'),
																	if (!setEquals(filter.value.patternFields.toSet(), defaultPatternFields.toSet()))
																		for (final field in filter.value.patternFields) Text(field)
																].expand((x) => [const Text(', '), x]).skip(1).toList()
															),
															onTap: () async {
																final newFilter = await editFilter(filter.value);
																if (newFilter != null) {
																	final lines = settings.filterConfiguration.split('\n');
																	if (newFilter.item1) {
																		lines.removeAt(filter.key);
																	}
																	else {
																		lines[filter.key] = newFilter.item2!.toStringConfiguration();
																	}
																	settings.filterConfiguration = lines.join('\n');
																	regexController.text = settings.filterConfiguration;
																}
															}
														)
													)
												),
												Material(
													type: MaterialType.transparency,
													child: Checkbox(
														activeColor: CupertinoTheme.of(context).primaryColor,
														checkColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
														fillColor: MaterialStateColor.resolveWith((states) => CupertinoTheme.of(context).primaryColor),
														value: !filter.value.disabled,
														onChanged: (value) {
															filter.value.disabled = !filter.value.disabled;
															final lines = settings.filterConfiguration.split('\n');
															lines[filter.key] = filter.value.toStringConfiguration();
															settings.filterConfiguration = lines.join('\n');
															regexController.text = settings.filterConfiguration;
														}
													)
												)
											]
										);
									}),
									if (filters.isEmpty) CupertinoListTile(
										title: const Text('Suggestion: Add a mass-reply filter'),
										leading: const Icon(CupertinoIcons.lightbulb),
										onTap: () async {
											settings.filterConfiguration += '\nMass-reply//;minReplied:10';
											regexController.text = settings.filterConfiguration;
										}
									),
									CupertinoListTile(
										title: const Text('New filter'),
										leading: const Icon(CupertinoIcons.plus),
										onTap: () async {
											final newFilter = await editFilter(null);
											if (newFilter?.item2 != null) {
												settings.filterConfiguration += '\n${newFilter!.item2!.toStringConfiguration()}';
												regexController.text = settings.filterConfiguration;
											}
										}
									)
								]
							)
						)
					)
				),
				const SizedBox(height: 16)
			]
		);
	}

	@override
	void dispose() {
		super.dispose();
		regexController.dispose();
		regexFocusNode.dispose();
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

enum _NullSafeOptional {
	null_,
	false_,
	true_
}

extension _ToBool on _NullSafeOptional {
	bool? get value {
		switch (this) {
			case _NullSafeOptional.null_: return null;
			case _NullSafeOptional.false_: return false;
			case _NullSafeOptional.true_: return true;
		}
	}
}

extension _ToNullSafeOptional on bool? {
	_NullSafeOptional get value {
		switch (this) {
			case true: return _NullSafeOptional.true_;
			case false: return _NullSafeOptional.false_;
			default: return _NullSafeOptional.null_;
		}
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
		final newSavedFields = widget.site.getSavedLoginFields();
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
				title: Text('${widget.site.getLoginSystemName()!} Login'),
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
				widget.site.persistence.browserState.loginFields.clear();
				widget.site.persistence.browserState.loginFields.addAll({
					for (final field in fields.entries) field.key.formKey: field.value
				});
				widget.site.persistence.didUpdateBrowserState();
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
										await widget.site.clearLoginCookies(true);
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
				CupertinoSegmentedControl<_NullSafeOptional>(
					children: const {
						_NullSafeOptional.false_: Padding(
							padding: EdgeInsets.all(8),
							child: Text('No')
						),
						_NullSafeOptional.null_: Padding(
							padding: EdgeInsets.all(8),
							child: Text('Ask')
						),
						_NullSafeOptional.true_: Padding(
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
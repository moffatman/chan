import 'dart:math' as math;

import 'package:chan/pages/cookie_browser.dart';
import 'package:chan/pages/settings/common.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/json_cache.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

final siteSettings = [
	const SwitchSettingWidget(
		description: 'Images',
		setting: SavedSetting(ChainedFieldWriter(SavedSettingsFields.contentSettings, ContentSettingsFields.images))
	),
	const SwitchSettingWidget(
		description: 'NSFW Boards',
		setting: SavedSetting(ChainedFieldWriter(SavedSettingsFields.contentSettings, ContentSettingsFields.nsfwBoards))
	),
	const SwitchSettingWidget(
		description: 'NSFW Images',
		setting: SavedSetting(ChainedFieldWriter(SavedSettingsFields.contentSettings, ContentSettingsFields.nsfwImages))
	),
	const SwitchSettingWidget(
		description: 'NSFW Text',
		setting: SavedSetting(ChainedFieldWriter(SavedSettingsFields.contentSettings, ContentSettingsFields.nsfwText))
	),
	PanelSettingWidget(
		icon: CupertinoIcons.globe,
		description: 'Sites',
		builder: (context) => Column(
			mainAxisSize: MainAxisSize.min,
			children: [
				for (final imageboard in ImageboardRegistry.instance.imageboards) ...[
					const ChanceDivider(),
					Row(
						children: [
							ImageboardIcon(imageboardKey: imageboard.key),
							const SizedBox(width: 16),
							Expanded(
								child: Text(imageboard.site.name)
							),
							if (imageboard.site.hasEmailLinkCookieAuth) AdaptiveIconButton(
								icon: const Icon(CupertinoIcons.link),
								onPressed: () async {
									final controller = TextEditingController();
									final linkStr = await showAdaptiveDialog<String>(
										context: context,
										barrierDismissible: true,
										builder: (context) => AdaptiveAlertDialog(
											title: const Text('Verification Link'),
											content: Column(
												mainAxisSize: MainAxisSize.min,
												children: [
													const SizedBox(height: 10),
													AdaptiveTextField(
														controller: controller,
														autofocus: true,
														smartDashesType: SmartDashesType.disabled,
														smartQuotesType: SmartQuotesType.disabled,
														minLines: 1,
														maxLines: 1,
														onSubmitted: (s) => Navigator.pop(context, s)
													)
												]
											),
											actions: [
												AdaptiveDialogAction(
													isDefaultAction: true,
													child: const Text('Submit'),
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
									if (linkStr == null) {
										return;
									}
									final url = Uri.tryParse(linkStr);
									if (url == null) {
										if (context.mounted) {
											alertError(context, 'Invalid URL', null);
										}
										return;
									}
									await imageboard.site.loginSystem?.logout(false);
									if (!context.mounted) {
										return;
									}
									openCookieBrowser(
										context,
										url,
									);
								}
							),
							if (imageboard.site.archives.isNotEmpty) AdaptiveIconButton(
								icon: const Icon(CupertinoIcons.archivebox),
								onPressed: () => showAdaptiveDialog<bool>(
									context: context,
									barrierDismissible: true,
									builder: (context) => StatefulBuilder(
										builder: (context, setDialogState) => AdaptiveAlertDialog(
											title: const Text('Archives'),
											content: Column(
												mainAxisSize: MainAxisSize.min,
												children: [
													const SizedBox(height: 16),
													for (final archive in imageboard.site.archives) Row(
														children: [
															Expanded(
																child: Text(archive.name, textAlign: TextAlign.left)
															),
															AdaptiveSwitch(
																value: !imageboard.persistence.browserState.disabledArchiveNames.contains(archive.name),
																onChanged: (enable) {
																	if (enable) {
																		imageboard.persistence.browserState.disabledArchiveNames.remove(archive.name);
																	}
																	else {
																		imageboard.persistence.browserState.disabledArchiveNames.add(archive.name);
																	}
																	imageboard.persistence.didUpdateBrowserState();
																	setDialogState(() {});
																}
															)
														]
													)
												]
											),
											actions: [
												AdaptiveDialogAction(
													isDefaultAction: true,
													onPressed: () => Navigator.pop(context, true),
													child: const Text('Close'),
												)
											]
										)
									)
								)
							),
							AdaptiveIconButton(
								icon: const Icon(CupertinoIcons.delete),
								onPressed: () async {
									final really = await confirm(context, 'Really delete ${imageboard.site.name}? Data will be gone forever.', actionName: 'Delete');
									if (really && context.mounted) {
										await modalLoad(context, 'Cleaning up...', (_) async {
											await imageboard.deleteAllData();
											Settings.instance.removeSiteKey(imageboard.key);
										});
									}
								}
							)
						]
					)
				],
				const ChanceDivider(),
				Center(
					child: AdaptiveButton(
						padding: const EdgeInsets.all(8),
						onPressed: () async {
							final allSites = JsonCache.instance.sites.value ?? {};
							final locked = Settings.instance.contentSettings.siteKeys.trySingle == kTestchanKey;
							if (locked) {
								// Always generate same name for same userId
								final random = math.Random(Settings.instance.settings.userId.hashCode);
								T chooseRandom<T>(List<T> list) => list[random.nextInt(list.length)];
								String vowel() => chooseRandom(['a', 'e', 'i', 'o', 'u']);
								String consonant() => chooseRandom(['b', 'c', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'm', 'n', 'p', 'q', 'r', 's', 't', 'v', 'w', 'x', 'y', 'z']);
								String cv() => consonant() + vowel();
								String cvc() => cv() + consonant();
								String syllable() => chooseRandom([vowel(), cv(), cvc()]);
								final text = syllable() + syllable() + syllable();
								final controller = TextEditingController();
								final url = await showAdaptiveDialog<String>(
									context: context,
									barrierDismissible: true,
									builder: (context) => AdaptiveAlertDialog(
										title: const Text('Unlock new site'),
										content: Column(
											mainAxisSize: MainAxisSize.min,
											children: [
												Text.rich(
													TextSpan(
														children: [
															const TextSpan(text: 'Go to your site of choice and make a post containing the text "'),
															TextSpan(text: text, style: const TextStyle(fontWeight: FontWeight.bold)),
															const TextSpan(text: '". Then paste the URL to your post below.')
														]
													)
												),
												AdaptiveTextField(
													autofocus: true,
													autocorrect: false,
													placeholder: 'Post URL',
													enableIMEPersonalizedLearning: false,
													smartDashesType: SmartDashesType.disabled,
													smartQuotesType: SmartQuotesType.disabled,
													controller: controller,
													onSubmitted: (s) => Navigator.pop(context, s)
												)
											]
										),
										actions: [
											AdaptiveDialogAction(
												isDefaultAction: true,
												child: const Text('Submit'),
												onPressed: () => Navigator.pop(context, controller.text)
											),
											AdaptiveDialogAction(
												child: const Text('Cancel'),
												onPressed: () => Navigator.pop(context)
											)
										]
									)
								);
								if (url != null && context.mounted) {
									try {
										final siteKey = await modalLoad(context, 'Searching...', (_) async {
											final postNotFoundOn = <ImageboardSite>[];
											for (final entry in allSites.entries) {
												final ImageboardSite site;
												try {
													site = makeSite(entry.value);
												}
												catch (_) {
													// Must not be supported yet
													continue;
												}
												if (url == site.baseUrl) {
													// Cheat code
													final ok = context.mounted && await confirm(context, 'Add ${site.name}?', actionName: 'Add');
													if (ok) {
														return entry.key;
													}
												}
												final target = (await site.decodeUrl(url))?.threadIdentifier;
												if (target != null) {
													final thread = await site.getThread(target, priority: RequestPriority.interactive);
													if (thread.posts_.any((p) => p.text.toLowerCase().contains(text))) {
														final ok = context.mounted && await confirm(context, 'Add ${site.name}?', actionName: 'Add');
														if (ok) {
															return entry.key;
														}
													}
													postNotFoundOn.add(site);
												}
											}
											if (postNotFoundOn.isNotEmpty) {
												throw Exception('Text not found in $postNotFoundOn thread');
											}
											throw Exception('Unrecognized/unsupported site');
										});
										Settings.instance.addSiteKey(siteKey);
									}
									catch (e, st) {
										Future.error(e, st); // crashlytics
										if (context.mounted) {
											alertError(context, e, st);
										}
									}
								}
							}
							else {
								final sites = <String, ImageboardSite>{};
								for (final entry in allSites.entries) {
									if (Settings.instance.settings.contentSettings.siteKeys.contains(entry.key)) {
										// Already added
										continue;
									}
									if (entry.key == kTestchanKey) {
										// Don't allow adding testchan
										continue;
									}
									try {
										sites[entry.key] = makeSite(entry.value);
									}
									catch (e, st) {
										print(e);
										print(st);
										// Must not be supported yet
										continue;
									}
								}
								final key = await showAdaptiveDialog<String>(
									context: context,
									builder: (context) => AdaptiveAlertDialog(
										title: const Text('Add new site'),
										content: Column(
											mainAxisSize: MainAxisSize.min,
											children: sites.entries.expand((site) => [const ChanceDivider(), AdaptiveButton(
												onPressed: () => Navigator.pop(context, site.key),
												child: Row(
													mainAxisSize: MainAxisSize.min,
													children: [
														ImageboardIcon(
															site: site.value
														),
														const SizedBox(width: 8),
														Flexible(
															child: Text(site.value.name)
														)
													]
												)
											)]).skip(1).toList()
										),
										actions: [
											AdaptiveDialogAction(
												child: const Text('Cancel'),
												onPressed: () => Navigator.pop(context)
											)
										]
									)
								);
								if (key != null) {
									Settings.instance.addSiteKey(key);
								}
							}
						},
						child: const Row(
							mainAxisSize: MainAxisSize.min,
							children: [
								Text('Add site '),
								Icon(CupertinoIcons.add, size: 16)
							]
						)
					)
				),
				Center(
					child: AdaptiveButton(
						padding: const EdgeInsets.all(8),
						onPressed: () async {
							await modalLoad(context, 'Synchronizing...', (_) => JsonCache.instance.sites.update());
							if (context.mounted) {
								showToast(
									context: context,
									icon: CupertinoIcons.check_mark,
									message: 'Synchronized'
								);
							}
						},
						child: const Row(
							mainAxisSize: MainAxisSize.min,
							children: [
								Text('Synchronize '),
								Icon(Icons.sync_rounded, size: 16)
							]
						)
					)
				)
			]
		)
	)
];

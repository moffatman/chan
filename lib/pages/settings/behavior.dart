import 'dart:io';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:chan/models/board.dart';
import 'package:chan/pages/board_switcher.dart';
import 'package:chan/pages/settings/common.dart';
import 'package:chan/pages/settings/filter.dart';
import 'package:chan/pages/settings/image_filter.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/translation.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/scroll_tracker.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

const _wifiSegments = {
	AutoloadAttachmentsSetting.never: (null, 'Never'),
	AutoloadAttachmentsSetting.wifi: (null, 'When on Wi\u200d-\u200dFi'),
	AutoloadAttachmentsSetting.always: (null, 'Always')
};

final filtersColor = MappedMutableSetting(
	CustomMutableSetting(
		reader: (context) => Settings.instance.filterError,
		watcher: (context) => context.select<Settings, String?>((s) => s.filterError),
		didMutater: (context) async {}
	),
	(filterError) => filterError != null ? Colors.red : null
);

final behaviorSettings = [
	ImmutableButtonSettingWidget(
		description: 'Filters',
		color: filtersColor,
		icon: CupertinoIcons.scope,
		setting: CustomImmutableSetting(
			reader: (context) => context.read<Settings>().filterConfiguration,
			watcher: (context) => Settings.filterConfigurationSetting.watch(context),
			writer: (context, newValue) async => context.read<Settings>().filterConfiguration = newValue
		),
		onPressed: (context, filterConfiguration, didSet) => Navigator.of(context).push(adaptivePageRoute(
			builder: (context) => const SettingsFilterPage()
		)),
		builder: (filterConfiguration) {
			int filterCount = 0;
			for (final line in filterConfiguration.split('\n').asMap().entries) {
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
			return Text('${describeCount(filterCount, 'filter')}...');
		}
	),
	MutableButtonSettingWidget(
		description: 'Image filter',
		icon: Icons.hide_image_outlined,
		setting: CustomImmutableSetting(
			reader: (context) => context.read<Settings>().settings.hiddenImageMD5s,
			watcher: (context) => context.watch<Settings>().settings.hiddenImageMD5s,
			writer: (context, newValue) async => context.read<Settings>().setHiddenImageMD5s(newValue)
		),
		onPressed: (context, hiddenImageMD5s, didSet) async {
			final md5sBefore = hiddenImageMD5s.toSet();
			await Navigator.of(context).push(adaptivePageRoute(
				builder: (context) => const SettingsImageFilterPage()
			));
			if (!setEquals(md5sBefore, Persistence.settings.hiddenImageMD5s.toSet())) {
				didSet();
			}
		},
		builder: (hiddenImageMD5s) {
			return Text('${describeCount(hiddenImageMD5s.length, 'image')}...');
		}
	),
	ImageboardScopedSettingWidget(
		description: null,
		builder: (imageboard) => MutableButtonSettingWidget(
			description: imageboard.site.loginSystem?.name ?? 'No login system',
			setting: MutableSavedSetting(
				ChainedFieldReader(
					ChainedFieldReader(
						SavedSettingsFields.browserStateBySite,
						MapFieldWriter<String, PersistentBrowserState>(key: imageboard.key)
					),
					PersistentBrowserStateFields.loginFields
				)
			),
			onPressed: (context, fields, didChange) => showAdaptiveDialog(
				context: context,
				barrierDismissible: true,
				builder: (context) => AdaptiveAlertDialog(
					content: SettingsLoginPanel(
						loginSystem: imageboard.site.loginSystem!
					),
					actions: [
						AdaptiveDialogAction(
							onPressed: () => Navigator.pop(context),
							child: const Text('Close')
						)
					]
				)
			),
			builder: (fields) => AnimatedBuilder(
				animation: imageboard.persistence,
				builder: (context, _) => Text(fields.isEmpty ? 'Logged out' : 'Logged in')
			)
		)
	),
	const SegmentedSettingWidget<AutoloadAttachmentsSetting>(
		icon: CupertinoIcons.question_square,
		description: 'Load thumbnails',
		children: _wifiSegments,
		setting: Settings.loadThumbnailsSettingSetting
	),
	const SegmentedSettingWidget<AutoloadAttachmentsSetting>(
		disabled: SavedSettingEquals(SavedSettingsFields.loadThumbnails, AutoloadAttachmentsSetting.never),
		icon: Icons.high_quality,
		description: 'Full-quality image thumbnails',
		children: _wifiSegments,
		setting: Settings.fullQualityThumbnailsSettingSetting
	),
	const SwitchSettingWidget(
		description: 'Allow swiping to change page in gallery',
		icon: CupertinoIcons.arrow_left_right_square_fill,
		setting: Settings.allowSwipingInGallerySetting
	),
	const SegmentedSettingWidget(
		description: 'Automatically load attachments in gallery',
		icon: CupertinoIcons.cloud_download,
		children: _wifiSegments,
		setting: Settings.autoloadAttachmentsSetting
	),
	const SwitchSettingWidget(
		description: 'Auto-rotate attachments in gallery',
		icon: CupertinoIcons.rotate_right,
		setting: Settings.autoRotateInGallerySetting
	),
	const SwitchSettingWidget(
		description: 'Always automatically load tapped attachment',
		icon: Icons.touch_app_outlined,
		setting: Settings.alwaysAutoloadTappedAttachmentSetting
	),
	SegmentedSettingWidget(
		description: 'Preload attachments when opening threads',
		icon: CupertinoIcons.cloud_download,
		children: _wifiSegments,
		confirm: (context, newValue) async {
			if (newValue == AutoloadAttachmentsSetting.always) {
				final ok = await confirm(context, 'Are you sure? This will consume a large amount of mobile data.');
				if (!ok) {
					return false;
				}
			}
			return true;
		},
		setting: Settings.autoCacheAttachmentsSettingSetting
	),
	const SegmentedSettingWidget(
		description: 'Automatically mute audio',
		icon: CupertinoIcons.volume_off,
		children: {
			TristateSystemSetting.a: (null, 'Never'),
			TristateSystemSetting.system: (null, 'When opening gallery without headphones'),
			TristateSystemSetting.b: (null, 'When opening gallery')
		},
		setting: Settings.muteAudioWhenOpeningGallerySetting
	),
	if (Settings.featureWebmTranscodingForPlayback) const SegmentedSettingWidget(
		description: 'Transcode WEBM videos before playback',
		icon: CupertinoIcons.play_rectangle,
		helpText: 'Some devices may have bugs in their media decoding engines during WEBM playback. Enabling transcoding here will make those WEBMs playable, at the cost of waiting for a transcode first.',
		children: {
			WebmTranscodingSetting.never: (null, 'Never'),
			WebmTranscodingSetting.vp9: (null, 'VP9 only'),
			WebmTranscodingSetting.always: (null, 'Always')
		},
		setting: Settings.webmTranscodingSetting
	),
	const SwitchSettingWidget(
		description: 'Hide old stickied threads',
		icon: CupertinoIcons.pin_slash,
		setting: Settings.hideOldStickiedThreadsSetting
	),
	const SwitchSettingWidget(
		description: 'Use old captcha interface',
		icon: CupertinoIcons.keyboard,
		setting: MappedSetting(
			Settings.useNewCaptchaFormSetting,
			FieldMappers.invert,
			FieldMappers.invert
		)
	),
	const SegmentedSettingWidget(
		description: 'Links open...',
		icon: CupertinoIcons.globe,
		children: {
			NullSafeOptional.false_: (null, 'Externally'),
			NullSafeOptional.null_: (null, 'Ask'),
			NullSafeOptional.true_: (null, 'Internally')
		},
		setting: MappedSetting(
			Settings.useInternalBrowserSetting,
			FieldMappers.nullSafeOptionalify,
			FieldMappers.unNullSafeOptionalify
		)
	),
	MutableButtonSettingWidget(
		description: 'Always open links externally',
		icon: Icons.launch_rounded,
		setting: Settings.hostsToOpenExternallySetting,
		onPressed: (context, list, didChange) async {
			await editStringList(
				context: context,
				list: list,
				name: 'site',
				title: 'Sites to open externally'
			);
			didChange();
		},
		builder: (hostsToOpenExternally) => Text('For ${describeCount(hostsToOpenExternally.length, 'site')}')
	),
	ImmutableButtonSettingWidget(
		description: 'Limit uploaded file dimensions',
		icon: CupertinoIcons.resize,
		setting: Settings.maximumImageUploadDimensionSetting,
		builder: (maximumImageUploadDimension) => Text(maximumImageUploadDimension == null ? 'No limit' : '$maximumImageUploadDimension px'),
		onPressed: (context, dimension, setDimension) async {
			final controller = TextEditingController(text: dimension.toString());
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
			setDimension(int.tryParse(controller.text));
			controller.dispose();
		}
	),
	const SwitchSettingWidget(
		description: 'Close tab switcher after use',
		icon: CupertinoIcons.rectangle_stack,
		setting: Settings.closeTabSwitcherAfterUseSetting
	),
	ImmutableButtonSettingWidget(
		description: 'Settings icon action',
		icon: CupertinoIcons.settings,
		setting: Settings.settingsQuickActionSetting,
		builder: (settingsQuickAction) => AutoSizeText(settingsQuickAction.name, maxLines: 2, textAlign: TextAlign.center),
		onPressed: (context, quickAction, setQuickAction) async {
			final newAction = await showAdaptiveDialog<SettingsQuickAction>(
				context: context,
				barrierDismissible: true,
				builder: (context) => AdaptiveAlertDialog(
					title: const Text('Pick Settings icon long-press action'),
					actions: [
						...SettingsQuickAction.values.map((action) => AdaptiveDialogAction(
							isDefaultAction: action == quickAction,
							onPressed: () => Navigator.pop(context, action),
							child: Text(action.name)
						)),
						AdaptiveDialogAction(
							onPressed: () => Navigator.pop(context),
							child: const Text('Cancel')
						)
					]
				)
			);
			if (newAction != null) {
				setQuickAction(newAction);
			}
		}
	),
	const SwitchSettingWidget(
		description: 'Haptic feedback',
		icon: Icons.vibration,
		setting: Settings.useHapticFeedbackSetting
	),
	if (Platform.isAndroid) const SwitchSettingWidget(
		description: 'Incognito keyboard',
		icon: CupertinoIcons.keyboard,
		setting: MappedSetting(
			Settings.enableIMEPersonalizedLearningSetting,
			FieldMappers.invert,
			FieldMappers.invert
		)
	),
	SegmentedSettingWidget(
		description: 'Hide bars when scrolling down',
		icon: CupertinoIcons.arrow_up_down,
		setting: HookedSetting(
			setting: const CombinedSetting(
				Settings.hideBarsWhenScrollingDownSetting,
				Settings.tabMenuHidesWhenScrollingDownSetting
			),
			beforeChange: (context, oldValue, newValue) async {
				if (!oldValue.$1 && newValue.$1) {
					// Don't immediately hide bars
					ScrollTracker.instance.slowScrollDirection.value = VerticalDirection.up;
				}
				return true;
			}
		),
		children: {
			(false, false): (null, 'None'),
			(false, true): (null, 'Tab bar'),
			(true, true): (null, 'Top and bottom bars')
		}
	),
	const SwitchSettingWidget(
		description: 'Double-tap scrolls to replies in thread',
		icon: CupertinoIcons.hand_point_right,
		setting: Settings.doubleTapScrollToRepliesSetting
	),
	const SwitchSettingWidget(
		description: 'Tapping background closes all replies',
		icon: CupertinoIcons.rectangle_expand_vertical,
		setting: Settings.overscrollModalTapPopsAllSetting
	),
	const SwitchSettingWidget(
		description: 'Always show spoilers',
		icon: CupertinoIcons.exclamationmark_octagon,
		setting: Settings.alwaysShowSpoilersSetting
	),
	const SegmentedSettingWidget(
		description: 'Image peeking',
		icon: CupertinoIcons.exclamationmark_square,
		helpText: 'You can hold on an image thumbnail to preview it. This setting adjusts whether it is blurred and what size it starts at.',
		children: {
			ImagePeekingSetting.disabled: (null, 'Off'),
			ImagePeekingSetting.standard: (null, 'Obscured'),
			ImagePeekingSetting.unsafe: (null, 'Small'),
			ImagePeekingSetting.ultraUnsafe: (null, 'Full size')
		},
		setting: Settings.imagePeekingSetting
	),
	const SwitchSettingWidget(
		description: 'Spellcheck',
		icon: CupertinoIcons.textformat_abc_dottedunderline,
		setting: Settings.enableSpellCheckSetting
	),
	const SwitchSettingWidget(
		description: 'Open cross-thread links in new tabs',
		icon: CupertinoIcons.rectangle_stack_badge_plus,
		setting: Settings.openCrossThreadLinksInNewTabSetting
	),
	const SegmentedSettingWidget(
		description: 'Current thread auto-updates every...',
		icon: CupertinoIcons.refresh,
		children: {
			5: (null, '5s'),
			10: (null, '10s'),
			15: (null, '15s'),
			30: (null, '30s'),
			60: (null, '60s'),
			1 << 50: (null, 'Off')
		},
		setting: Settings.currentThreadAutoUpdatePeriodSecondsSetting
	),
	const SegmentedSettingWidget(
		description: 'Background threads auto-update every...',
		children: {
			15: (null, '15s'),
			30: (null, '30s'),
			60: (null, '60s'),
			120: (null, '120s'),
			180: (null, '180s'),
			1 << 50: (null, 'Off')
		},
		setting: Settings.backgroundThreadAutoUpdatePeriodSecondsSetting
	),
	const SwitchSettingWidget(
		description: 'Auto-watch thread when replying',
		icon: CupertinoIcons.bell,
		setting: Settings.watchThreadAutomaticallyWhenReplyingSetting
	),
	SwitchSettingWidget(
		description: 'Auto-save thread when replying',
		icon: Adaptive.icons.bookmark,
		setting: Settings.saveThreadAutomaticallyWhenReplyingSetting
	),
	const SwitchSettingWidget(
		description: 'Cancellable replies swipe gesture',
		icon: CupertinoIcons.reply_all,
		helpText: 'When swiping from right to left to open a post\'s replies, only continuing the swipe will open the replies. Releasing the swipe in another direction will cancel the gesture.',
		setting: Settings.cancellableRepliesSlideGestureSetting
	),
	SwitchSettingWidget(
		description: 'Swipe to open board switcher',
		icon: CupertinoIcons.arrow_right_square,
		helpTextBuilder: (context) => 'Swipe left-to-right ${Settings.androidDrawerSetting.watch(context) ? 'starting on the right side of the' : 'in the'} catalog to open the board switcher.',
		setting: Settings.openBoardSwitcherSlideGestureSetting
	),
	ImmutableButtonSettingWidget(
		description: 'Post translation',
		icon: Icons.translate,
		setting: Settings.translationTargetLanguageSetting,
		builder: (translationTargetLanguage) => Text(translationSupportedTargetLanguages[translationTargetLanguage] ?? translationTargetLanguage),
		onPressed: (context, currentLanguage, setLanguage) async {
			final newLanguageCode = await showAdaptiveModalPopup<String>(
				context: context,
				builder: (context) => AdaptiveActionSheet(
					title: const Text('Select language'),
					actions: translationSupportedTargetLanguages.entries.map((pair) => AdaptiveActionSheetAction(
						isSelected: pair.key == currentLanguage,
						child: Row(
							mainAxisSize: MainAxisSize.min,
							children: [
								Text(pair.value)
							]
						),
						onPressed: () {
							Navigator.of(context, rootNavigator: true).pop(pair.key);
						}
					)).toList(),
					cancelButton: AdaptiveActionSheetAction(
						child: const Text('Cancel'),
						onPressed: () => Navigator.of(context, rootNavigator: true).pop()
					)
				)
			);
			if (newLanguageCode != null) {
				setLanguage(newLanguageCode);
			}
		}
	),
	ImmutableButtonSettingWidget(
		description: 'Home board',
		icon: CupertinoIcons.home,
		helpText: 'Chance will always open to this site or board on a fresh launch',
		setting: const CombinedSetting(
			Settings.homeImageboardKeySetting,
			Settings.homeBoardNameSetting
		),
		onPressed: (context, currentHome, setNewHome) async {
			final newBoard = await Navigator.of(context).push<ImageboardScoped<ImageboardBoard>>(TransparentRoute(
				builder: (ctx) => BoardSwitcherPage(
					initialImageboardKey: currentHome.$1,
					allowPickingWholeSites: true
				)
			));
			if (newBoard != null) {
				setNewHome((newBoard.imageboard.key, newBoard.item.name));
			}
		},
		injectButton: (context, pair, setPair) => (pair.$1 != null) ? AdaptiveIconButton(
			icon: const Icon(CupertinoIcons.xmark),
			onPressed: () => setPair((null, ''))
		) : const SizedBox.shrink(),
		builder: (pair) {
			final homeImageboard = ImageboardRegistry.instance.getImageboard(pair.$1);
			return Row(
				mainAxisSize: MainAxisSize.min,
				children: [
					if (pair.$1 == '') const Text('Board switcher')
					else if (pair.$1 != null) ...[
						ImageboardIcon(
							imageboardKey: pair.$1
						),
						const SizedBox(width: 8),
						Text((pair.$2.isEmpty ? homeImageboard?.site.name : homeImageboard?.site.formatBoardName(pair.$2)) ?? pair.$1 ?? 'null')
					]
					else const Text('None')
				]
			);
		}
	),
	const SwitchSettingWidget(
		description: 'Tap post IDs to reply',
		icon: CupertinoIcons.reply,
		setting: Settings.tapPostIdToReplySetting
	),
	const SwitchSettingWidget(
		description: 'Spam-filter workarounds',
		icon: CupertinoIcons.exclamationmark_shield,
		helpText: 'Automatic waiting to use captcha after spam-filter encountered on current IP, automatic refresh of post ticket in background.',
		setting: Settings.useSpamFilterWorkaroundsSetting
	),
	const SwitchSettingWidget(
		description: 'Bottom-bar swipe gestures',
		icon: CupertinoIcons.arrow_left_right_square,
		helpText: 'Swipe left and right to switch tabs. Swipe up and down to show and hide the tab bar.',
		setting: Settings.swipeGesturesOnBottomBarSetting
	),
	MutableButtonSettingWidget(
		description: 'MPV options',
		icon: CupertinoIcons.play_rectangle,
		helpText: 'MPV is used as the video player in Chance. You can set some custom flags to pass to MPV here.',
		setting: Settings.mpvOptionsSetting,
		builder: (map) => Text(map.isEmpty ? 'Set up' : describeCount(map.length, 'option')),
		onPressed: (context, map, didEdit) async {
			await editStringMap(
				context: context,
				map: map,
				name: 'Option',
				title: 'MPV Options',
				formatter: (e) => '--${e.key}${e.value.isEmpty ? '' : '='}${e.value}'
			);
			didEdit();
		}
	),
	SliderSettingWidget(
		description: 'Dynamic IP workaround',
		icon: CupertinoIcons.globe,
		setting: const MappedSetting(
			Settings.dynamicIPKeepAlivePeriodSecondsSetting,
			FieldMappers.toDoubleAbs,
			FieldMappers.toIntAbs
		),
		min: 3,
		max: 120,
		step: 1,
		textFormatter: (s) => 'Interval: ${s.abs().round()}s',
		helpText: 'Some ISPs (T-Mobile, for one) use network routing "solutions" that cause IP addresses to change on every connection. You can try using this setting to have Chance keep making requests to keep your IP stable, as some sites require a stable IP to complete the posting flow.',
		enabledSetting: MappedSetting(
			Settings.dynamicIPKeepAlivePeriodSecondsSetting,
			(seconds) => seconds > 0,
			(enabled) => Settings.instance.dynamicIPKeepAlivePeriodSeconds.abs() * (enabled ? 1 : -1)
		)
	),
	SliderSettingWidget(
		description: 'Wait before posting',
		icon: CupertinoIcons.clock,
		setting: const MappedSetting(
			Settings.postingRegretDelaySecondsSetting,
			FieldMappers.toDoubleAbs,
			FieldMappers.toIntAbs
		),
		min: 1,
		max: 30,
		step: 1,
		textFormatter: (s) => '${s.abs().round()}s',
		helpText: 'Adds a wait period before submitting each post, so you can cancel it in case of a typo.',
		enabledSetting: MappedSetting(
			Settings.postingRegretDelaySecondsSetting,
			(seconds) => seconds > 0,
			(enabled) => Settings.instance.postingRegretDelaySeconds.abs() * (enabled ? 1 : -1)
		)
	),
	ImageboardScopedSettingWidget(
		description: 'Default post sorting method',
		builder: (imageboard) => ImmutableButtonSettingWidget(
			description: 'Default post sorting method',
			icon: CupertinoIcons.sort_down,
			setting: SettingWithFallback(
				SavedSetting(
					ChainedFieldWriter(
						ChainedFieldReader(
							SavedSettingsFields.browserStateBySite,
							MapFieldWriter<String, PersistentBrowserState>(key: imageboard.key)
						),
						PersistentBrowserStateFields.postSortingMethod
					)
				),
				PostSortingMethod.none
			),
			builder: (method) => Text(method.displayName),
			onPressed: (context, currentMethod, setMethod) async {
				final newMethod = await showAdaptiveDialog<PostSortingMethod>(
					context: context,
					barrierDismissible: true,
					builder: (context) => AdaptiveAlertDialog(
						title: Text('Pick default post sorting method for ${imageboard.site.name}'),
						actions: [
							...PostSortingMethod.values.map((method) => AdaptiveDialogAction(
								isDefaultAction: method == currentMethod,
								onPressed: () => Navigator.pop(context, method),
								child: Text(method.displayName)
							)),
							AdaptiveDialogAction(
								onPressed: () => Navigator.pop(context),
								child: const Text('Cancel')
							)
						]
					)
				);
				if (newMethod != null) {
					setMethod(newMethod);
				}
			}
		)
	)
];
import 'dart:io';

import 'package:chan/pages/settings/common.dart';
import 'package:chan/services/default_user_agent.dart';
import 'package:chan/services/edit_site_board_map.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/import_export.dart';
import 'package:chan/services/network_logging.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/pick_attachment.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/share.dart';
import 'package:chan/services/storage.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/user_agents.dart';
import 'package:chan/services/util.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/util.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

bool _exportIncludeSavedAttachments = true;

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
		Future.microtask(_readFilesystemInfo);
	}

	Future<void> _readFilesystemInfo() async {
		folderSizes = null;
		if (!mounted) return;
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
			if (mounted) {
				alertError(context, e, st);
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
				color: ChanceTheme.primaryColorOf(context).withValues(alpha: 0.2)
			),
			padding: const EdgeInsets.all(16),
			child: Column(
				mainAxisSize: MainAxisSize.min,
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					// SizedBox is used here to avoid changing layout when deleting (rows will be gone)
					SizedBox(
						height: 175,
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
												double megabytes = entry.value / kMB;
												return TableRow(
													children: [
														Padding(
															padding: const EdgeInsets.only(bottom: 8, right: 8),
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
					Wrap(
						alignment: WrapAlignment.spaceBetween,
						runAlignment: WrapAlignment.end,
						spacing: 16,
						runSpacing: 16,
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
		return ListenableBuilder(
			listenable: Persistence.sharedThreadStateListenable,
			builder: (context, child) {
				final threadStateBox = Persistence.sharedThreadStateBox;
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
						color: ChanceTheme.primaryColorOf(context).withValues(alpha: 0.2)
					),
					padding: const EdgeInsets.all(16),
					child: Table(
						columnWidths: const {
							0: FlexColumnWidth(1),
							1: IntrinsicColumnWidth(),
							2: IntrinsicColumnWidth()
						},
						defaultVerticalAlignment: TableCellVerticalAlignment.middle,
						children: [
							TableRow(
								children: [
									const Text('Saved threads', textAlign: TextAlign.left),
									Padding(
										padding: const EdgeInsets.symmetric(horizontal: 16),
										child: Text(savedThreads.length.toString(), textAlign: TextAlign.right)
									),
									AdaptiveIconButton(
										onPressed: savedThreads.isEmpty ? null : () => confirmDelete(savedThreads, itemType: 'saved thread'),
										icon: const Text('Delete')
									)
								]
							),
							TableRow(
								children: [
									const Text('Watched threads', textAlign: TextAlign.left),
									Padding(
										padding: const EdgeInsets.symmetric(horizontal: 16),
										child: Text(watchedThreads.length.toString(), textAlign: TextAlign.right)
									),
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
										Padding(
											padding: const EdgeInsets.symmetric(horizontal: 16),
											child: Text(entry.$2.length.toString(), textAlign: TextAlign.right)
										),
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

class ImportLogSummaryWidget extends StatelessWidget {
	final ImportLogSummary summary;

	const ImportLogSummaryWidget({
		required this.summary,
		super.key
	});

	@override
	Widget build(BuildContext context) {
		return Row(
			children: [
				Flexible(
					flex: 3,
					fit: FlexFit.tight,
					child: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Text(summary.type, style: const TextStyle(fontSize: 16)),
							Row(
								children: [
									const Icon(CupertinoIcons.doc, size: 14),
									const SizedBox(width: 4),
									Text(summary.filename, style: const TextStyle(fontSize: 14))
								]
							)
						]
					)
				),
				Flexible(
					flex: 1,
					fit: FlexFit.tight,
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							Text(summary.newCount.toString()),
							const Text('New')
						]
					)
				),
				Flexible(
					flex: 1,
					fit: FlexFit.tight,
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							Text(summary.modifiedCount.toString()),
							const Text('Changed')
						]
					)
				),
				Flexible(
					flex: 1,
					fit: FlexFit.tight,
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							Text(summary.identicalCount.toString()),
							const Text('Same')
						]
					)
				)
			]
		);
	}
}

class ImportLogFailureWidget extends StatelessWidget {
	final ImportLogFailure failure;

	const ImportLogFailureWidget({
		required this.failure,
		super.key
	});

	@override
	Widget build(BuildContext context) {
		final color = ChanceTheme.secondaryColorOf(context);
		return Column(
			mainAxisSize: MainAxisSize.min,
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				Text('${failure.type} Failure', style: TextStyle(fontSize: 16, color: color)),
				Row(
					children: [
						Icon(CupertinoIcons.doc, size: 14, color: color),
						const SizedBox(width: 4),
						Expanded(
							child: Text(failure.filename, style: TextStyle(fontSize: 14, color: color), textAlign: TextAlign.left)
						)
					]
				),
				const SizedBox(height: 4),
				Row(
					children: [
						Icon(CupertinoIcons.exclamationmark_triangle, size: 14, color: color),
						const SizedBox(width: 4),
						Expanded(
							child: Text(failure.message, style: TextStyle(fontSize: 14, color: color), textAlign: TextAlign.left)
						)
					]
				),
			]
		);
	}
}

InlineSpan _importFieldValue<T>(T value) => switch (value) {
	Color color => TextSpan(children: [
		WidgetSpan(
			child: Container(
				width: 20,
				height: 20,
				decoration: BoxDecoration(
					color: color,
					borderRadius: BorderRadius.circular(10)
				)
			)
		),
		TextSpan(text: ' ${color.toCssHex()}')
	]),
	dynamic x => TextSpan(text: x.toString())
};

class ImportLogConflictWidget<Ancestor, T> extends StatefulWidget {
	final ImportLogConflict<Ancestor, T> conflict;

	const ImportLogConflictWidget({
		required this.conflict,
		super.key
	});

	@override
	createState() => _ImportLogConflictWidgetState();
}

class _ImportLogConflictWidgetState<Ancestor, T> extends State<ImportLogConflictWidget<Ancestor, T>> {
	bool accepted = false;
	late final T originalYours;

	@override
	void initState() {
		super.initState();
		originalYours = widget.conflict.conflict.get(widget.conflict.yours);
	}

	@override
	Widget build(BuildContext context) {
		return Column(
			mainAxisSize: MainAxisSize.min,
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				Text('${widget.conflict.type} Conflict', style: const TextStyle(fontSize: 16)),
				Row(
					children: [
						const Icon(CupertinoIcons.doc, size: 14),
						const SizedBox(width: 4),
						Expanded(
							child: Text([
								widget.conflict.filename,
								if (widget.conflict.key != null) widget.conflict.key!,
								widget.conflict.conflict.path
							].join(' -> '), style: const TextStyle(fontSize: 14), textAlign: TextAlign.left)
						)
					]
				),
				const SizedBox(height: 4),
				IntrinsicHeight(
					child: Row(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							Flexible(
								fit: FlexFit.tight,
								child: AdaptiveThinButton(
									onPressed: accepted ? () {
										widget.conflict.conflict.set(widget.conflict.yours, originalYours);
										// Hack
										if (widget.conflict.yours is SavedSettings) {
											Settings.instance.didEdit();
										}
										setState(() {
											accepted = false;
										});
									} : null,
									filled: !accepted,
									child: Column(
										mainAxisSize: MainAxisSize.min,
										mainAxisAlignment: MainAxisAlignment.center,
										children: [
											const Text('Yours', style: TextStyle(fontSize: 15)),
											Text.rich(_importFieldValue(originalYours))
										]
									)
								)
							),
							const SizedBox(width: 8),
							Flexible(
								fit: FlexFit.tight,
								child: AdaptiveThinButton(
									onPressed: accepted ? null : () {
										widget.conflict.conflict.set(widget.conflict.yours, widget.conflict.conflict.get(widget.conflict.theirs));
										// Hack
										if (widget.conflict.yours is SavedSettings) {
											Settings.instance.didEdit();
										}
										setState(() {
											accepted = true;
										});
									},
									filled: accepted,
									child: Column(
										mainAxisSize: MainAxisSize.min,
										mainAxisAlignment: MainAxisAlignment.center,
										children: [
											const Text('Imported', style: TextStyle(fontSize: 15)),
											Text.rich(_importFieldValue(widget.conflict.conflict.get(widget.conflict.theirs)))
										]
									)
								)
							)
						]
					)
				)
			]
		);
	}
}

final dataSettings = [
	SwitchSettingWidget(
		description: 'Require authentication on launch',
		icon: CupertinoIcons.lock,
		setting: HookedSetting(
			beforeChange: (context, oldValue, newValue) async {
				try {
					final result = await LocalAuthentication().authenticate(localizedReason: 'Verify access to app', options: const AuthenticationOptions(stickyAuth: true));
					if (result) {
						return true;
					}
					else if (context.mounted) {
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
				return false;
			},
			setting: Settings.askForAuthenticationOnLaunchSetting
		)
	),
	ImmutableButtonSettingWidget(
		description: 'Media save directory',
		icon: CupertinoIcons.floppy_disk,
		setting: Settings.gallerySavePathSetting,
		builder: (gallerySavePath) => Text(gallerySavePath == null ? 'Set' : 'Change'),
		onPressed: (context, currentPath, setPath) async {
			final newPath = await pickGallerySavePath(context);
			if (!context.mounted) {
				return;
			}
			if (newPath != null) {
				if (newPath.startsWith(kGallerySavePathGalleryPrefix)) {
					final newSavePathOrganizing = switch (Settings.gallerySavePathOrganizingSetting.read(context)) {
						GallerySavePathOrganizing.boardAndThreadSubfolders
							|| GallerySavePathOrganizing.boardAndThreadNameSubfolders => (GallerySavePathOrganizing.boardSubfolders, 'Per-board'),
						GallerySavePathOrganizing.threadNameSubfolders => (GallerySavePathOrganizing.noSubfolders, 'One album'),
						GallerySavePathOrganizing.siteBoardAndThreadSubfolders
							|| GallerySavePathOrganizing.siteBoardAndThreadNameSubfolders
							|| GallerySavePathOrganizing.siteAndThreadNameSubfolders => (GallerySavePathOrganizing.siteSubfolders, 'Per-site'),
						_ => null
					};
					if (newSavePathOrganizing != null) {
						final reallyChange = await confirm(context, 'Warning', content: 'Your current save path organizing structure is not compatible with gallery saving. It will be changed to ${newSavePathOrganizing.$2}');
						if (!reallyChange || !context.mounted) {
							return;
						}
						Settings.gallerySavePathOrganizingSetting.write(context, newSavePathOrganizing.$1);
					}
				}
				setPath(newPath);
			}
		}
	),
	if (Platform.isAndroid) ImmutableButtonSettingWidget(
		description: 'Media picker',
		icon: CupertinoIcons.photo,
		setting: Settings.androidGalleryPickerSetting,
		builder: (androidGalleryPicker) => Text(androidGalleryPicker == null ? 'Set' : 'Change'),
		onPressed: (context, currentPicker, setPicker) async {
			setPicker(await chooseAndroidPicker(context) ?? currentPicker);
		}
	),
	const SegmentedSettingWidget(
		description: 'Media saving filenames',
		icon: CupertinoIcons.doc_text,
		setting: Settings.downloadUsingServerSideFilenamesSetting,
		children: {
			false: (null, 'User-submitted'),
			true: (null, 'Server-side')
		}
	),
	SettingBuilder(
		otherSetting: Settings.gallerySavePathSetting,
		builder: (gallerySavePath) {
			if (gallerySavePath == null) {
				return NullSettingWidget();
			}
			final usingGallery = gallerySavePath.startsWith(kGallerySavePathGalleryPrefix);
			final albumName = usingGallery ? Uri.decodeFull(gallerySavePath.substring(kGallerySavePathGalleryPrefix.length)) : '';
			return SegmentedSettingWidget(
				description: 'Media saving folder structure',
				icon: CupertinoIcons.folder,
				setting: Settings.gallerySavePathOrganizingSetting,
				children: {
					GallerySavePathOrganizing.noSubfolders: (null, usingGallery ? (albumName.isEmpty ? 'No album' : '"$albumName" album') : 'No subfolders'),
					GallerySavePathOrganizing.siteSubfolders: (null, usingGallery ? 'Per-site albums' : 'Per-site subfolders'),
					GallerySavePathOrganizing.boardSubfolders: (null, usingGallery ? 'Per-board albums' : 'Per-board subfolders'),
					if (!usingGallery) ...{
						GallerySavePathOrganizing.boardAndThreadSubfolders: (null, 'Per-board and per-thread subfolders'),
						GallerySavePathOrganizing.boardAndThreadNameSubfolders: (null, 'Per-board and per-thread (with name) subfolders'),
						GallerySavePathOrganizing.threadNameSubfolders: (null, 'Per-thread (with name) subfolders')
					},
					GallerySavePathOrganizing.siteAndBoardSubfolders: (null, usingGallery ? 'Per-site+board albums' : 'Per-site and per-board subfolders'),
					if (!usingGallery) ...{
						GallerySavePathOrganizing.siteBoardAndThreadSubfolders: (null, 'Per-site, per-board, and per-thread subfolders'),
						GallerySavePathOrganizing.siteBoardAndThreadNameSubfolders: (null, 'Per-site, per-board, and per-thread (with name) subfolders'),
						GallerySavePathOrganizing.siteAndThreadNameSubfolders: (null, 'Per-site and per-thread (with name) subfolders')
					}
				},
				injectButton: (context, _, __) {
					return AdaptiveFilledButton(
						padding: const EdgeInsets.all(8),
						onPressed: () async {
							await editSiteBoardMap(
								context: context,
								field: PersistentBrowserStateFields.downloadSubfoldersPerBoard,
								editor: const TextMapValueEditor(),
								name: usingGallery ? 'Album' : 'Subfolder',
								title: usingGallery ? 'Per-board albums' : 'Per-board subfolders'
							);
						},
						child: const Text('Per-board...')
					);
				}
			);
		}
	),
	const SwitchSettingWidget(
		description: 'Use cloud captcha solver',
		icon: CupertinoIcons.textformat,
		helpText: 'Use a machine-learning captcha solving model which is hosted on a web server to provide better captcha solver guesses. This means the captchas you open will be sent to a first-party web service for predictions. No information will be retained.',
		setting: SettingWithFallback(Settings.useCloudCaptchaSolverSetting, false)
	),
	const SwitchSettingWidget(
		subsetting: true,
		description: 'Skip confirmation',
		icon: CupertinoIcons.checkmark_seal,
		helpText: 'Cloud captcha solutions will be submitted directly without showing a popup and asking for confirmation.',
		setting: SettingWithFallback(Settings.useHeadlessCloudCaptchaSolverSetting, false),
		disabled: MappedSetting(
			SettingWithFallback(Settings.useCloudCaptchaSolverSetting, false),
			FieldMappers.invert,
			FieldMappers.invert
		)
	),
	const SwitchSettingWidget(
		description: 'Contribute captcha data',
		icon: CupertinoIcons.textformat,
		helpText: 'Send the captcha images you solve to a database to improve the automated solver. No other information about your posts will be collected.',
		setting: SettingWithFallback(Settings.contributeCaptchasSetting, false)
	),
	SwitchSettingWidget(
		description: 'Contribute crash data',
		icon: CupertinoIcons.burst,
		helpText: 'Crash stack traces and uncaught exceptions will be used to help fix bugs. No personal information will be collected.',
		setting: CustomImmutableSetting(
			reader: (context) => Settings.instance.isCrashlyticsCollectionEnabled,
			watcher: (context) => context.select<Settings, bool>((s) => s.isCrashlyticsCollectionEnabled),
			writer: (context, setting) async {
				Settings.instance.isCrashlyticsCollectionEnabled = setting;
			},
		)
	),
	const SwitchSettingWidget(
		description: 'Show rich links',
		icon: CupertinoIcons.rectangle_paperclip,
		helpText: 'Links to sites such as YouTube will show the thumbnail and title of the page instead of the link URL.',
		setting: Settings.useEmbedsSetting
	),
	const SwitchSettingWidget(
		description: 'Remove metadata from uploads',
		icon: CupertinoIcons.doc_person,
		setting: Settings.removeMetadataOnUploadedFilesSetting
	),
	const SwitchSettingWidget(
		description: 'Randomize checksum on uploads',
		icon: CupertinoIcons.doc_checkmark,
		helpText: 'Uploaded files will be re-encoded to prevent matching against other files.',
		setting: Settings.randomizeChecksumOnUploadedFilesSetting
	),
	const SegmentedSettingWidget(
		description: 'Automatically clear caches older than...',
		icon: CupertinoIcons.calendar,
		setting: Settings.automaticCacheClearDaysSetting,
		children: {
			1: (null, '1 day'),
			3: (null, '3 days'),
			7: (null, '7 days'),
			14: (null, '14 days'),
			30: (null, '30 days'),
			60: (null, '60 days'),
			100000: (null, 'Never')
		}
	),
	PanelSettingWidget(
		description: 'Cached media',
		icon: Adaptive.icons.photos,
		builder: (context) => const SettingsCachePanel()
	),
	PanelSettingWidget(
		description: 'Cached threads and history',
		icon: CupertinoIcons.archivebox,
		builder: (context) => const SettingsThreadsPanel()
	),
	const SwitchSettingWidget(
		description: 'Separate cookies for Wi-Fi and cellular data',
		icon: Icons.cookie,
		setting: Settings.separateWiFiAndCellularCookiesSetting
	),
	SettingHiding(
		hidden: Settings.separateWiFiAndCellularCookiesSetting,
		setting: SimpleButtonSettingWidget(
			description: 'Clear cookies',
			icon: CupertinoIcons.trash,
			onPressed: (context) {
				Persistence.clearCookies(fromWifi: true);
			}
		)
	),
	SettingHiding(
		hidden: const MappedSetting(Settings.separateWiFiAndCellularCookiesSetting, FieldMappers.invert, FieldMappers.invert),
		setting: SimpleButtonSettingWidget(
			description: 'Clear Wi-Fi cookies',
			icon: CupertinoIcons.wifi,
			onPressed: (context) {
				Persistence.clearCookies(fromWifi: true);
			}
		)
	),
	SettingHiding(
		hidden: const MappedSetting(Settings.separateWiFiAndCellularCookiesSetting, FieldMappers.invert, FieldMappers.invert),
		setting: SimpleButtonSettingWidget(
			description: 'Clear cellular cookies',
			icon: CupertinoIcons.antenna_radiowaves_left_right,
			onPressed: (context) {
				Persistence.clearCookies(fromWifi: false);
			}
		)
	),
	ImmutableButtonSettingWidget(
		description: 'User-Agent',
		icon: CupertinoIcons.globe,
		setting: Settings.userAgentSetting,
		builder: (userAgent) => userAgent != null ? const Text('Edit*') : const Text('Set'),
		onPressed: (context, userAgent, setUserAgent) async {
			final controller = TextEditingController(text: userAgent);
			final save = await showAdaptiveDialog<bool>(
				context: context,
				barrierDismissible: true,
				builder: (context) => StatefulBuilder(
					builder: (context, setDialogState) => AdaptiveAlertDialog(
						title: const Text('Edit User-Agent'),
						content: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								const SizedBox(height: 10),
								const Text('Cloudflare clearance will probably only work on the default user-agent'),
								const SizedBox(height: 10),
								Visibility.maintain(
									visible: (userAgent?.isEmpty ?? true),
									child: const Text('You are currently using your system\'s default User-Agent (recommended)')
								),
								const SizedBox(height: 10),
								AdaptiveTextField(
									autofocus: true,
									controller: controller,
									smartDashesType: SmartDashesType.disabled,
									smartQuotesType: SmartQuotesType.disabled,
									minLines: 6,
									maxLines: 6,
									placeholder: defaultUserAgent,
									onChanged: (s) {
										userAgent = s;
										setDialogState(() {});
									},
									onSubmitted: (s) {
										userAgent = s;
										Navigator.pop(context, true);
									}
								)
							]
						),
						actions: [
							AdaptiveDialogAction(
								child: const Text('Reset to Default'),
								onPressed: () {
									userAgent = null;
									Navigator.pop(context, true);
								}
							),
							AdaptiveDialogAction(
								child: const Text('Random'),
								onPressed: () {
									final userAgents = getAppropriateUserAgents();
									final idx = userAgents.indexOf(controller.text) + 1;
									userAgent = controller.text = userAgents[idx % userAgents.length];
									setDialogState(() {});
								}
							),
							AdaptiveDialogAction(
								isDefaultAction: true,
								child: const Text('Save'),
								onPressed: () => Navigator.pop(context, true)
							),
							AdaptiveDialogAction(
								child: const Text('Cancel'),
								onPressed: () => Navigator.pop(context, false)
							)
						]
					)
				)
			);
			controller.dispose();
			if (save == true) {
				setUserAgent(userAgent?.nonEmptyOrNull);
			}
		}
	),
	SimpleButtonSettingWidget(
		description: 'Send network logs',
		icon: CupertinoIcons.share,
		onPressed: (context) async {
			final choice = await showAdaptiveDialog<Future<void> Function(BuildContext)>(
				context: context,
				barrierDismissible: true,
				builder: (context) => AdaptiveAlertDialog(
					actions: [
						AdaptiveDialogAction(
							child: const Text('Share...'),
							onPressed: () => Navigator.pop<Future<void> Function(BuildContext)>(context, LoggingInterceptor.instance.reportViaShareSheet)
						),
						AdaptiveDialogAction(
							child: const Text('Save as...'),
							onPressed: () => Navigator.pop<Future<void> Function(BuildContext)>(context, LoggingInterceptor.instance.reportViaSaveAs)
						),
						AdaptiveDialogAction(
							child: const Text('Email to developer'),
							onPressed: () => Navigator.pop<Future<void> Function(BuildContext)>(context, (_) => LoggingInterceptor.instance.reportViaEmail())
						),
						AdaptiveDialogAction(
							child: const Text('Cancel'),
							onPressed: () => Navigator.pop(context)
						)
					]
				)
			);
			if (context.mounted) {
				choice?.call(context);
			}
		}
	),
	SimpleButtonSettingWidget(
		description: 'Export data to JSON',
		icon: CupertinoIcons.chevron_left_slash_chevron_right,
		onPressed: (context) async {
			final globalRect = context.globalPaintBounds;
			try {
				final file = await modalLoad(context, 'Exporting...', (_) => exportJson());
				if (!context.mounted) {
					return;
				}
				await alert(context, 'Warning', 'This is NOT a backup. You won\'t be able to restore it if you reinstall the app. It\'s for your personal curiosity only.', barrierDismissible: false);
				if (!context.mounted) {
					return;
				}
				if (isSaveFileAsSupported) {
					await saveFileAs(
						context: context,
						type: SaveAsFileType.other,
						sourcePath: file.path,
						destinationName: file.basename
					);
				}
				else {
					await shareOne(
						context: context,
						text: file.path,
						type: 'file',
						sharePositionOrigin: globalRect
					);
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
	SimpleButtonSettingWidget(
		description: 'Backup data',
		icon: CupertinoIcons.share_up,
		onPressed: (context) async {
			final globalRect = context.globalPaintBounds;
			final attachmentsSizeInBytes = await modalLoad(context, 'Scanning...', (_) async {
				int total = 0;
				await for (final file in Persistence.savedAttachmentsDirectory.list(recursive: true)) {
					total += (await file.stat()).size;
				}
				return total;
			}, wait: const Duration(milliseconds: 100));
			if (!context.mounted) return;
			final cb = await showAdaptiveDialog<Future<void> Function(File)>(
				context: context,
				builder: (context) => AdaptiveAlertDialog(
					title: const Text('Export Options'),
					content: StatefulBuilder(
						builder: (context, setDialogState) => Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								if (attachmentsSizeInBytes > 0) Row(
									children: [
										Expanded(
											child: Text('Include saved attachments (${formatFilesize(attachmentsSizeInBytes)})')
										),
										AdaptiveSwitch(
											value: _exportIncludeSavedAttachments,
											onChanged: (v) {
												setDialogState(() {
													_exportIncludeSavedAttachments = v;
												});
											}
										)
									]
								)
							]
						)
					),
					actions: [
						AdaptiveDialogAction(
							onPressed: () => Navigator.pop<Future<void> Function(File)>(context, (File file) => shareOne(
									context: context,
									text: file.path,
									type: 'file',
									sharePositionOrigin: globalRect
							)),
							child: const Text('Export')
						),
						if (isSaveFileAsSupported) AdaptiveDialogAction(
							onPressed: () => Navigator.pop<Future<void> Function(File)>(context, (File file) => saveFileAs(
								context: context,
								type: SaveAsFileType.other,
								sourcePath: file.path,
								destinationName: file.basename
							)),
							child: const Text('Export as...')
						),
						AdaptiveDialogAction(
							onPressed: () => Navigator.pop(context, null),
							child: const Text('Cancel')
						)
					]
				)
			);
			if (cb == null) return;
			if (!context.mounted) return;
			try {
				final file = await modalLoad(context, 'Exporting...', (_) => export(
					includeSavedAttachments: attachmentsSizeInBytes > 0 && _exportIncludeSavedAttachments,
					includeFullHistory: true
				));
				if (!context.mounted) {
					return;
				}
				await cb(file);
			}
			catch (e, st) {
				Future.error(e, st);
				if (context.mounted) {
					alertError(context, e, st);
				}
			}
		}
	),
	SimpleButtonSettingWidget(
		description: 'Import data',
		icon: CupertinoIcons.folder_open,
		onPressed: (context) async {
			final picked = (await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['zip']))?.files.trySingle?.path;
			if (picked == null) {
				return;
			}
			if (!context.mounted) {
				return;
			}
			try {
				final log = await modalLoad(context, 'Importing...', (_) => import(File(picked)));
				// Propagate new Settings
				await Settings.instance.didEdit();
				// ImageboardRegistry.handleSites should be called by ChanApp
				await Future.microtask(() {});
				// Load needed new threads from disk
				await ImageboardRegistry.instance.didImport();
				if (!context.mounted) {
					return;
				}
				await showAdaptiveModalPopup(
					context: context,
					builder: (context) => AdaptiveActionSheet(
						title: const Text('Import results'),
						message: Column(
							mainAxisSize: MainAxisSize.min,
							children: log.map((e) => Padding(
								key: ValueKey(e),
								padding: const EdgeInsets.all(8),
								child: switch(e) {
									ImportLogSummary() => ImportLogSummaryWidget(summary: e),
									ImportLogFailure() => ImportLogFailureWidget(failure: e),
									ImportLogConflict() => ImportLogConflictWidget(conflict: e)
								}
							)).toList()
						),
						actions: [
							AdaptiveActionSheetAction(
								onPressed: () => Navigator.pop(context),
								child: const Text('Close')
							)
						]
					)
				);
			}
			catch (e, st) {
				Future.error(e, st);
				if (context.mounted) {
					alertError(context, e, st);
				}
			}
		}
	)
];

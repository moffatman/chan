import 'dart:io';

import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tuple/tuple.dart';
import 'package:provider/provider.dart';
import 'package:extended_image_library/extended_image_library.dart';

class SettingsPage extends StatelessWidget {
	@override
	Widget build(BuildContext context) {
		final settings = context.read<EffectiveSettings>();
		return CupertinoPageScaffold(
			resizeToAvoidBottomInset: false,
			navigationBar: CupertinoNavigationBar(
				transitionBetweenRoutes: false,
				middle: Text('Settings')
			),
			child: SafeArea(
				child: Align(
					alignment: Alignment.center,
					child: ConstrainedBox(
						constraints: BoxConstraints(
							maxWidth: 500
						),
						child: ListView(
							physics: ClampingScrollPhysics(),
							children: [
								Container(
									padding: EdgeInsets.all(16),
									child: Text('Use touchscreen layout'),
								),
								CupertinoSegmentedControl<bool>(
									children: {
										false: Text('No'),
										true: Text('Yes')
									},
									groupValue: settings.useTouchLayout,
									onValueChanged: (newValue) {
										settings.useTouchLayout = newValue;
									}
								),
								Container(
									padding: EdgeInsets.all(16),
									child: Text('Theme'),
								),
								CupertinoSegmentedControl<ThemeSetting>(
									children: {
										ThemeSetting.Light: Text('Light'),
										ThemeSetting.System: Text('Follow System'),
										ThemeSetting.Dark: Text('Dark')
									},
									groupValue: settings.themeSetting,
									onValueChanged: (newValue) {
										settings.themeSetting = newValue;
									}
								),
								Container(
									padding: EdgeInsets.all(16),
									child: Text('Automatically load attachments'),
								),
								CupertinoSegmentedControl<AutoloadAttachmentsSetting>(
									children: {
										AutoloadAttachmentsSetting.Always: Text('Always'),
										AutoloadAttachmentsSetting.WiFi: Text('When on Wi-Fi'),
										AutoloadAttachmentsSetting.Never: Text('Never')
									},
									groupValue: settings.autoloadAttachmentsSetting,
									onValueChanged: (newValue) {
										settings.autoloadAttachmentsSetting = newValue;
									}
								),
								Container(
									padding: EdgeInsets.all(16),
									child: Text('Darker dark theme (for OLED)'),
								),
								CupertinoSegmentedControl<bool>(
									children: {
										false: Text('No'),
										true: Text('Yes')
									},
									groupValue: settings.darkThemeIsPureBlack,
									onValueChanged: (newValue) {
										settings.darkThemeIsPureBlack = newValue;
									}
								),
								Container(
									padding: EdgeInsets.all(16),
									child: Text('Hide stickied threads'),
								),
								CupertinoSegmentedControl<bool>(
									children: {
										false: Text('No'),
										true: Text('Yes')
									},
									groupValue: settings.hideStickiedThreads,
									onValueChanged: (newValue) {
										settings.hideStickiedThreads = newValue;
									}
								),
								Container(
									padding: EdgeInsets.only(top: 16, left: 16),
									child: Text('Cached media')
								),
								SettingsCachePanel(),
								Container(
									padding: EdgeInsets.only(top: 16, left: 16),
									child: Text('Cached threads and history')
								),
								SettingsThreadsPanel(),
								CupertinoButton(
									child: Text('Clear API cookies'),
									onPressed: () {
										Persistence.cookies.deleteAll();
									}
								)
							],
						)
					)
				)
			)
		);
	}
}

class SettingsCachePanel extends StatefulWidget {
	createState() => _SettingsCachePanelState();
}

const _KNOWN_CACHE_DIRS = {
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
		for (final dirName in _KNOWN_CACHE_DIRS.keys) {
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
		for (final dirName in _KNOWN_CACHE_DIRS.keys) {
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
				borderRadius: BorderRadius.all(Radius.circular(8)),
				color: CupertinoTheme.of(context).primaryColor.withOpacity(0.2)
			),
			margin: EdgeInsets.all(16),
			padding: EdgeInsets.all(16),
			child: Column(
				mainAxisSize: MainAxisSize.min,
				children: [
					if (folderSizes?.isEmpty ?? true) Text('No cached media'),
					Table(
						children: (folderSizes ?? {}).entries.map((entry) {
							double megabytes = entry.value / 1000000;
							return TableRow(
								children: [
									Padding(
										padding: EdgeInsets.only(bottom: 8),
										child: Text(_KNOWN_CACHE_DIRS[entry.key]!, textAlign: TextAlign.left)
									),
									Text(megabytes.toStringAsFixed(1) + ' MB', textAlign: TextAlign.right)
								]
							);
						}).toList()
					),
					SizedBox(height: 8),
					Row(
						mainAxisAlignment: MainAxisAlignment.spaceEvenly,
						children: [
							CupertinoButton(
								padding: EdgeInsets.zero,
								child: Text('Recalculate'),
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
	@override
	Widget build(BuildContext context) {
		return ValueListenableBuilder(
			valueListenable: Persistence.threadStateBox.listenable(),
			builder: (context, Box<PersistentThreadState> threadStateBox, child) {
				final oldThreadRows =[7, 14, 30, 60, 90, 180].map((days) {
					final cutoff = DateTime.now().subtract(Duration(days: days));
					final oldThreads = threadStateBox.values.where((state) {
						return (state.savedTime == null) && state.lastOpenedTime.compareTo(cutoff).isNegative;
					}).toList();
					return Tuple2(days, oldThreads);
				}).toList();
				oldThreadRows.removeRange(oldThreadRows.lastIndexWhere((r) => r.item2.isNotEmpty) + 1, oldThreadRows.length);
				final confirmDelete = (List<PersistentThreadState> toDelete) async {
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
				};
				return Container(
					decoration: BoxDecoration(
						borderRadius: BorderRadius.all(Radius.circular(8)),
						color: CupertinoTheme.of(context).primaryColor.withOpacity(0.2)
					),
					margin: EdgeInsets.all(16),
					padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
					child: Table(
						defaultVerticalAlignment: TableCellVerticalAlignment.middle,
						children: [
							TableRow(
								children: [
									Text('Saved threads', textAlign: TextAlign.left),
									Text(threadStateBox.values.where((t) => t.savedTime != null).length.toString(), textAlign: TextAlign.right),
									CupertinoButton(
										padding: EdgeInsets.zero,
										child: const Text('Delete'),
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
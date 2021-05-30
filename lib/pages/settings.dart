import 'dart:io';

import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:extended_image_library/extended_image_library.dart';

class SettingsPage extends StatelessWidget {
	@override
	Widget build(BuildContext context) {
		final settings = context.read<EffectiveSettings>();
		return CupertinoPageScaffold(
			navigationBar: CupertinoNavigationBar(
				transitionBetweenRoutes: false,
				middle: Text('Settings')
			),
			child: SafeArea(
				child: ListView(
					physics: ClampingScrollPhysics(),
					children: [
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
						SettingsCachePanel()
					],
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
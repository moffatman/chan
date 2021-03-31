import 'dart:io';

import 'package:chan/services/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:extended_image_library/extended_image_library.dart';

class SettingsPage extends StatelessWidget {
	@override
	Widget build(BuildContext context) {
		final settings = context.read<EffectiveSettings>();
		return CupertinoPageScaffold(
			navigationBar: CupertinoNavigationBar(
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
						SizedBox(height: 16),
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

const _KNOWN_CACHE_DIRS = ['sharecache', 'webmcache'];

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
		final systemTempDirectory = await getTemporaryDirectory();
		/*await for (final directory in systemTempDirectory.list()) {
			if (directory is Directory) {
				int size = 0;
				await for (final subentry in directory.list(recursive: true)) {
					size += (await subentry.stat()).size;
				}
				folderSizes![directory.path.split('/').last] = size;
			}
		}*/
		setState(() {});
	}

	Future<void> _clearCaches() async {
		setState(() {
			clearing = true;
		});
		await clearDiskCachedImages();
		final systemTempDirectory = await getTemporaryDirectory();
		await for (final directory in systemTempDirectory.list()) {
			if (directory is Directory && _KNOWN_CACHE_DIRS.contains(directory.path.split('/').last)) {
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
		return Column(
			mainAxisSize: MainAxisSize.min,
			children: [
				Container(
					padding: EdgeInsets.all(16),
					width: double.infinity,
					child: Text('Cached media'),
				),
				Table(
					children: (folderSizes ?? {}).entries.map((entry) {
						double megabytes = entry.value / 1000000;
						return TableRow(
							children: [
								Text(entry.key, textAlign: TextAlign.center),
								Text(megabytes.toStringAsFixed(1) + ' MB', textAlign: TextAlign.center)
							]
						);
					}).toList()
				),
				CupertinoButton(
					child: Text(clearing ? 'Clearing...' : 'Clear cached media'),
					onPressed: clearing ? null : _clearCaches
				)
			]
		);
	}
}
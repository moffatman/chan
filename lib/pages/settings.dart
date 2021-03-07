import 'package:chan/services/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatelessWidget {
	@override
	Widget build(BuildContext context) {
		final settings = context.read<Settings>();
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
							child: Text("Theme"),
						),
						CupertinoSegmentedControl<Setting_Theme>(
							children: {
								Setting_Theme.Light: Text('Light'),
								Setting_Theme.System: Text('Follow System'),
								Setting_Theme.Dark: Text('Dark')
							},
							groupValue: settings.themePreference,
							onValueChanged: (newValue) {
								settings.themePreference = newValue;
							}
						),
						Container(
							padding: EdgeInsets.all(16),
							child: Text("Automatically load attachments"),
						),
						CupertinoSegmentedControl<Setting_AutoloadAttachments>(
							children: {
								Setting_AutoloadAttachments.Always: Text('Always'),
								Setting_AutoloadAttachments.WiFi: Text('When on Wi-Fi'),
								Setting_AutoloadAttachments.Never: Text('Never')
							},
							groupValue: settings.autoloadAttachmentsPreference,
							onValueChanged: (newValue) {
								settings.autoloadAttachmentsPreference = newValue;
							}
						),
						Container(
							padding: EdgeInsets.all(16),
							child: Text("Hide stickied threads"),
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
					],
				)
			)
		);
	}
}
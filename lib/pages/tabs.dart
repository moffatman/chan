import 'package:chan/main.dart';
import 'package:chan/pages/popup_drawer.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/widgets/drawer.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TabsPage extends StatelessWidget {
	const TabsPage({
		super.key
	});

	@override
	Widget build(BuildContext context) {
		final tabs = context.watch<ChanTabs>();
		final settings = context.watch<Settings>();
		final list = DrawerList.tabs(
			tabs: tabs,
			settings: settings,
			afterUse: () => Navigator.pop(context),
			menuAxisDirection: AxisDirection.up
		);
		return PopupDrawerPage(list: list, title: 'Tabs');
	}
}
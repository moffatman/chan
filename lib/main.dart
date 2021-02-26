// @dart=2.9
import 'package:chan/services/settings.dart';
import 'package:chan/widgets/chan_site.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/io_client.dart';
import 'providers/provider.dart';
import 'providers/4chan.dart';
import 'pages/tab.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
	@override
	createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
	GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
	Provider4Chan provider;
	@override
	void initState() {
		super.initState();
		provider = Provider4Chan(
			apiUrl: 'https://a.4cdn.org',
			imageUrl: 'https://i.4cdn.org',
			name: '4chan',
			client: IOClient(),
			archives: Map<String, ImageboardProvider>()
		);
	}

	@override
	Widget build(BuildContext context) {
		return SettingsHandler(
			settingsBuilder: () {
				return Settings(
					autoloadAttachmentsPreference: Setting_AutoloadAttachments.WiFi
				);
			},
			child: ChanSite(
				provider: provider,
				child: CupertinoApp(
					title: 'Chan',
					theme: CupertinoThemeData(
						primaryColor: Colors.green,
					),
					home: ChanHomePage()
				)
			)
		);
	}
}

class ChanHomePage extends StatelessWidget {
	@override
	Widget build(BuildContext context) {
		return ImageboardTab(
			initialBoard: 'tv',
			isInTabletLayout: MediaQuery.of(context).size.width > 700
		);
	}
}
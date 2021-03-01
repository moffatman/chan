// @dart=2.9
import 'package:chan/services/settings.dart';
import 'package:cupertino_back_gesture/cupertino_back_gesture.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/io_client.dart';
import 'sites/imageboard_site.dart';
import 'sites/4chan.dart';
import 'pages/tab.dart';
import 'package:provider/provider.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
	@override
	createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
	GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
	ImageboardSite provider;
	@override
	void initState() {
		super.initState();
		provider = Site4Chan(
			apiUrl: 'https://a.4cdn.org',
			imageUrl: 'https://i.4cdn.org',
			name: '4chan',
			client: IOClient()
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
			child: BackGestureWidthTheme(
				backGestureWidth: BackGestureWidth.fraction(1),
				child: Provider<ImageboardSite>.value(
					value: provider,
					child: CupertinoApp(
						title: 'Chan',
						theme: CupertinoThemeData(
							primaryColor: Colors.black,
						),
						home: Builder(
							builder: (BuildContext context) {
								return DefaultTextStyle(
									style: CupertinoTheme.of(context).textTheme.textStyle,
									child: ChanHomePage()
								);
							}
						)
					)
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
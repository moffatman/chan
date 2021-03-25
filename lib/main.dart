import 'package:chan/services/settings.dart';
import 'package:cupertino_back_gesture/cupertino_back_gesture.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/io_client.dart';
import 'sites/imageboard_site.dart';
import 'sites/4chan.dart';
import 'pages/tab.dart';
import 'package:provider/provider.dart';

void main() => runApp(ChanApp());

class ChanApp extends StatelessWidget {
	@override
	Widget build(BuildContext context) {
		return BackGestureWidthTheme(
			backGestureWidth: BackGestureWidth.fraction(1),
			child: MultiProvider(
				providers: [
					ChangeNotifierProvider<Settings>(create: (_) => Settings()),
					Provider<ImageboardSite>(create: (_) => Site4Chan(
						apiUrl: 'https://a.4cdn.org',
						imageUrl: 'https://i.4cdn.org',
						name: '4chan',
						client: IOClient()
					))
				],
				child: SettingsSystemListener(
					child: Builder(
						builder: (BuildContext context) {
							final brightness = context.watch<Settings>().theme;
							CupertinoThemeData theme = CupertinoThemeData(brightness: Brightness.light, primaryColor: Colors.black);
							if (brightness == Brightness.dark) {
								theme = CupertinoThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: Color.fromRGBO(20, 20, 20, 1), primaryColor: Colors.white);
							}
							return CupertinoApp(
								title: 'Chan',
								theme: theme,
								home: Builder(
									builder: (BuildContext context) {
										return DefaultTextStyle(
											style: CupertinoTheme.of(context).textTheme.textStyle,
											child: ChanHomePage()
										);
									}
								)
							);
						}
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
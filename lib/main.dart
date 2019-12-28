import 'package:flutter/material.dart';
import 'widgets/data_stream_provider.dart';
import 'widgets/thread_list.dart';
import 'models/thread.dart';
import 'providers/provider.dart';
import 'providers/4chan.dart';
import 'widgets/provider_provider.dart';
import 'pages/tab.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          primarySwatch: Colors.green,
          textTheme: TextTheme(
        
          )
        ),
        home: MyHomePage(title: 'Tab 1'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
	GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
	ImageboardProvider provider;
	@override
	void initState() {
		super.initState();
		provider = Provider4Chan(apiUrl: 'https://a.4cdn.org', imageUrl: 'https://i.4cdn.org', name: '4chan');
	}
  @override
  Widget build(BuildContext context) {
    return Material(
      child: ImageboardTab(
        initialSite: provider,
        initialBoard: 'tv',
        isInTabletLayout: MediaQuery.of(context).size.width > 700
      )
    );
  }
}

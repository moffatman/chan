import 'package:chan/pages/history.dart';
import 'package:chan/pages/search.dart';
import 'package:chan/pages/settings.dart';
import 'package:chan/pages/saved.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/sites/foolfuuka.dart';
import 'package:chan/sites/lainchan.dart';
import 'package:chan/widgets/notifying_icon.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'sites/imageboard_site.dart';
import 'sites/4chan.dart';
import 'package:chan/pages/tab.dart';
import 'package:provider/provider.dart';
import 'package:chan/widgets/sticky_media_query.dart';

void main() async {
	await Persistence.initializeStatic();
	runApp(ChanApp());
}

class ChanApp extends StatefulWidget {
	createState() => _ChanAppState();
}

class _ChanAppState extends State<ChanApp> {
	ImageboardSite? site;
	Persistence? persistence;
	ThreadWatcher? threadWatcher;
	final settings = EffectiveSettings();
	late dynamic _lastSite;

	@override
	void initState() {
		super.initState();
		_lastSite = settings.contentSettings.site;
		setSite(_lastSite);
		settings.addListener(_onSettingsUpdate);
	}

	void _onSettingsUpdate() {
		if (settings.contentSettings.site != _lastSite) {
			_lastSite = settings.contentSettings.site;
			setSite(_lastSite);
		}
	}

	Future<void> setSite(dynamic data) async {
		ImageboardSite? _site;
		if (data['type'] == 'lainchan') {
			_site = SiteLainchan(
				name: data['name'],
				baseUrl: data['baseUrl']
			);
		}
		else if (data['type'] == '4chan') {
			_site = Site4Chan(
				name: data['name'],
				imageUrl: data['imageUrl'],
				captchaKey: data['captchaKey'],
				apiUrl: data['apiUrl'],
				sysUrl: data['sysUrl'],
				baseUrl: data['baseUrl'],
				staticUrl: data['staticUrl'],
				archives: (data['archives'] ?? []).map<ImageboardSiteArchive>((archive) {
					if (archive['type'] == 'foolfuuka') {
						return FoolFuukaArchive(
							name: archive['name'],
							baseUrl: archive['baseUrl'],
							staticUrl: archive['staticUrl']
						);
					}
					else {
						print(archive);
						throw UnsupportedError('Unknown archive type "${archive['type']}"');
					}
				}).toList()
			);
		}
		else {
			print(data);
			throw UnsupportedError('Unknown site type "${data['type']}"');
		}
		Persistence _persistence = Persistence(_site.name);
		await _persistence.initialize();
		_site.persistence = _persistence;
		site = _site;
		persistence = _persistence;
		final oldThreadWatcher = threadWatcher;
		threadWatcher = ThreadWatcher(site: _site, persistence: _persistence);
		setState(() {});
		await Future.delayed(const Duration(seconds: 5));
		oldThreadWatcher?.dispose();
	}

	@override
	Widget build(BuildContext context) {
		SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
		SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
			systemNavigationBarColor: Colors.transparent,
			systemNavigationBarDividerColor: Colors.transparent
		));
		return MultiProvider(
			providers: [
				ChangeNotifierProvider.value(value: settings),
				if (threadWatcher != null) ...[
					Provider<ImageboardSite>.value(value: site!),
					Provider<Persistence>.value(value: persistence!),
					ChangeNotifierProvider<ThreadWatcher>.value(value: threadWatcher!)
				]
			],
			child: SettingsSystemListener(
				child: Builder(
					builder: (BuildContext context) {
						final settings = context.watch<EffectiveSettings>();
						CupertinoThemeData theme = CupertinoThemeData(brightness: Brightness.light, primaryColor: Colors.black);
						if (settings.theme == Brightness.dark) {
							theme = CupertinoThemeData(
								brightness: Brightness.dark,
								scaffoldBackgroundColor: settings.darkThemeIsPureBlack ? Colors.black : Color.fromRGBO(20, 20, 20, 1),
								barBackgroundColor: settings.darkThemeIsPureBlack ? Color.fromRGBO(20, 20, 20, 1) : null,
								primaryColor: Colors.white
							);
						}
						return CupertinoApp(
							title: 'Chance',
							theme: theme,
							home: Builder(
								builder: (BuildContext context) {
									return DefaultTextStyle(
										style: CupertinoTheme.of(context).textTheme.textStyle,
										child: StickyMediaQuery(
											top: true,
											child: threadWatcher != null ? ChanHomePage(key: ValueKey(site!.name)) : Center(
												child: CupertinoActivityIndicator()
											)
										)
									);
								}
							),
							localizationsDelegates: [
								DefaultCupertinoLocalizations.delegate,
								DefaultMaterialLocalizations.delegate
							],
							scrollBehavior: CupertinoScrollBehavior().copyWith(dragDevices: {...PointerDeviceKind.values})
						);
					}
				)
			)
		);
	}
}

class ChanHomePage extends StatefulWidget {
	ChanHomePage({Key? key}) : super(key: key);

	createState() => _ChanHomePageState();
}
class _ChanHomePageState extends State<ChanHomePage> {
	late bool initialized;
	String? boardFetchErrorMessage;
	late bool isInTabletLayout;
	int tabletIndex = 0;

	void _setupBoards() async {
		try {
			setState(() {
				boardFetchErrorMessage = null;
			});
			final freshBoards = await context.read<ImageboardSite>().getBoards();
			await context.read<Persistence>().boardBox.clear();
			await context.read<Persistence>().boardBox.putAll({
				for (final board in freshBoards) board.name: board
			});
			setState(() {
				initialized = true;
			});
		}
		catch (error) {
			print(error);
			if (!initialized) {
				setState(() {
					boardFetchErrorMessage = error.toString();
				});
			}
		}
	}

	@override
	void initState() {
		super.initState();
		_setupBoards();
	}

	@override
	void didChangeDependencies() {
		super.didChangeDependencies();
		initialized = context.read<Persistence>().boardBox.length > 0;
	}

	Widget _buildTab(BuildContext context, int index) {
		if (index == 0) {
			return ImageboardTab(
				initialBoardName: context.read<EffectiveSettings>().currentBoardName,
				onBoardChanged: (newBoard) {
					context.read<EffectiveSettings>().currentBoardName = newBoard.name;
				}
			);
		}
		else if (index == 1) {
			return SavedPage();
		}
		else if (index == 2) {
			return HistoryPage();
		}
		else if (index == 3) {
			return SearchPage();
		}
		else {
			return SettingsPage();
		}
	}

	@override
	Widget build(BuildContext context) {
		isInTabletLayout = MediaQuery.of(context).size.width > 700;
		if (!initialized) {
			if (boardFetchErrorMessage != null) {
				return Center(
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							ErrorMessageCard(this.boardFetchErrorMessage!),
							CupertinoButton(
								child: Text('Retry'),
								onPressed: _setupBoards
							)
						]
					)
				);
			}
			else {
				return Center(
					child: CupertinoActivityIndicator()
				);
			}
		}
		else if (isInTabletLayout) {
			return CupertinoPageScaffold(
				child: Row(
					children: [
						Container(
							padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
							color: CupertinoTheme.of(context).barBackgroundColor,
							child: NavigationRail(
								backgroundColor: CupertinoTheme.of(context).barBackgroundColor,
								unselectedIconTheme: IconThemeData(
									color: CupertinoTheme.of(context).primaryColor.withOpacity(0.5)
								),
								selectedIconTheme: IconThemeData(
									color: CupertinoTheme.of(context).primaryColor
								),
								unselectedLabelTextStyle: TextStyle(
									color: CupertinoTheme.of(context).primaryColor.withOpacity(0.5)
								),
								selectedLabelTextStyle: TextStyle(
									color: CupertinoTheme.of(context).primaryColor
								),
								selectedIndex: tabletIndex,
								onDestinationSelected: (index) {
									setState(() {
										tabletIndex = index;
									});
								},
								labelType: NavigationRailLabelType.all,
								destinations: [
									NavigationRailDestination(
										icon: Icon(Icons.topic),
										label: Text('Browse')
									),
									NavigationRailDestination(
										icon: NotifyingIcon(
											icon: Icons.bookmark,
											primaryCount: context.watch<ThreadWatcher>().unseenYouCount,
											secondaryCount: context.watch<ThreadWatcher>().unseenCount
										),
										label: Text('Saved')
									),
									NavigationRailDestination(
										icon: Icon(Icons.history),
										label: Text('History')
									),
									NavigationRailDestination(
										icon: Icon(Icons.search),
										label: Text('Search')
									),
									NavigationRailDestination(
										icon: Icon(Icons.settings),
										label: Text('Settings')
									)
								]
							)
						),
						Expanded(
							child: IndexedStack(
								index: tabletIndex,
								children: List.generate(5, (i) => ExcludeFocus(
									excluding: i != tabletIndex,
									child: _buildTab(context, i)
								))
							)
						)
					]
				)
			);
		}
		else {
			return CupertinoTabScaffold(
				tabBar: CupertinoTabBar(
					items: [
						BottomNavigationBarItem(
							icon: Icon(Icons.topic),
							label: 'Browse'
						),
						BottomNavigationBarItem(
							icon: NotifyingIcon(
								icon: Icons.bookmark,
								primaryCount: context.watch<ThreadWatcher>().unseenYouCount,
								secondaryCount: context.watch<ThreadWatcher>().unseenCount,
								topOffset: 10
							),
							label: 'Saved'
						),
						BottomNavigationBarItem(
							icon: Icon(Icons.history),
							label: 'History'
						),
						BottomNavigationBarItem(
							icon: Icon(Icons.search),
							label: 'Search'
						),
						BottomNavigationBarItem(
							icon: Icon(Icons.settings),
							label: 'Settings'
						)
					]
				),
				tabBuilder: (context, index) => CupertinoTabView(
					builder: (context) => _buildTab(context, index)
				)
			);
		}
	}
}
import 'package:chan/pages/history.dart';
import 'package:chan/pages/search.dart';
import 'package:chan/pages/settings.dart';
import 'package:chan/pages/saved.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/sites/foolfuuka.dart';
import 'package:chan/widgets/notifying_icon.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'sites/imageboard_site.dart';
import 'sites/4chan.dart';
import 'package:chan/pages/tab.dart';
import 'package:provider/provider.dart';

void main() async {
	await Persistence.initialize();
	runApp(ChanApp());
}

class ChanApp extends StatelessWidget {
	@override
	Widget build(BuildContext context) {
		return MultiProvider(
			providers: [
				ChangeNotifierProvider<EffectiveSettings>(create: (_) => EffectiveSettings()),
				Provider<ImageboardSite>(create: (_) => Site4Chan(
					baseUrl: 'boards.4chan.org',
					staticUrl: 's.4cdn.org',
					sysUrl: 'sys.4chan.org',
					apiUrl: 'a.4cdn.org',
					imageUrl: 'i.4cdn.org',
					name: '4chan',
					captchaKey: '6Ldp2bsSAAAAAAJ5uyx_lx34lJeEpTLVkP5k04qc',
					archives: [
						FoolFuukaArchive(baseUrl: 'archive.4plebs.org', staticUrl: 's.4cdn.org', name: '4plebs'),
						FoolFuukaArchive(baseUrl: 'archive.rebeccablacktech.com', staticUrl: 's.4cdn.org', name: 'RebeccaBlackTech'),
						FoolFuukaArchive(baseUrl: 'archive.nyafuu.org', staticUrl: 's.4cdn.org', name: 'Nyafuu'),
						FoolFuukaArchive(baseUrl: 'desuarchive.org', staticUrl: 's.4cdn.org', name: 'Desuarchive'),
						FoolFuukaArchive(baseUrl: 'archived.moe', staticUrl: 's.4cdn.org', name: 'Archived.Moe')
					]
				))
			],
			child: SettingsSystemListener(
				child: Builder(
					builder: (BuildContext context) {
						final brightness = context.watch<EffectiveSettings>().theme;
						CupertinoThemeData theme = CupertinoThemeData(brightness: Brightness.light, primaryColor: Colors.black);
						if (brightness == Brightness.dark) {
							theme = CupertinoThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: Color.fromRGBO(20, 20, 20, 1), primaryColor: Colors.white);
						}
						return ChangeNotifierProvider(
							create: (ctx) => ThreadWatcher(site: ctx.read<ImageboardSite>()),
							child: CupertinoApp(
								title: 'Chan',
								theme: theme,
								home: Builder(
									builder: (BuildContext context) {
										return DefaultTextStyle(
											style: CupertinoTheme.of(context).textTheme.textStyle,
											child: ChanHomePage()
										);
									}
								),
								localizationsDelegates: [
									DefaultCupertinoLocalizations.delegate,
									DefaultMaterialLocalizations.delegate
								],
							)
						);
					}
				)
			)
		);
	}
}

class ChanHomePage extends StatefulWidget {
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
			Persistence.boardBox.putAll({
				for (final board in freshBoards) board.name: board
			});
			setState(() {
				initialized = true;
			});
		}
		catch (error) {
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
		initialized = Persistence.boardBox.length > 0;
		_setupBoards();
	}

	Widget _buildTab(BuildContext context, int index) {
		if (index == 0) {
			return ImageboardTab(
				initialBoardName: 'tv'
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
						NavigationRail(
							backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
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
									icon: Icon(Icons.list),
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
						),
						Expanded(
							child: IndexedStack(
								index: tabletIndex,
								children: List.generate(5, (i) => _buildTab(context, i))
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
							icon: Icon(Icons.list),
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
import 'dart:math';

import 'package:chan/pages/history.dart';
import 'package:chan/pages/search.dart';
import 'package:chan/pages/settings.dart';
import 'package:chan/pages/saved.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/sites/foolfuuka.dart';
import 'package:chan/sites/lainchan.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/notifying_icon.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tuple/tuple.dart';
import 'sites/imageboard_site.dart';
import 'sites/4chan.dart';
import 'package:chan/pages/tab.dart';
import 'package:provider/provider.dart';
import 'package:chan/widgets/sticky_media_query.dart';

void main() async {
	await Persistence.initializeStatic();
	runApp(const ChanApp());
}

class ChanApp extends StatefulWidget {
	const ChanApp({Key? key}) : super(key: key);

	@override
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
						CupertinoThemeData theme = const CupertinoThemeData(brightness: Brightness.light, primaryColor: Colors.black);
						if (settings.theme == Brightness.dark) {
							theme = CupertinoThemeData(
								brightness: Brightness.dark,
								scaffoldBackgroundColor: settings.darkThemeIsPureBlack ? Colors.black : const Color.fromRGBO(20, 20, 20, 1),
								barBackgroundColor: settings.darkThemeIsPureBlack ? const Color.fromRGBO(20, 20, 20, 1) : null,
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
											child: threadWatcher != null ? ChanHomePage(key: ValueKey(site!.name)) : Container(
												color: CupertinoTheme.of(context).scaffoldBackgroundColor,
												child: const Center(
													child: CupertinoActivityIndicator()
												)
											)
										)
									);
								}
							),
							localizationsDelegates: const [
								DefaultCupertinoLocalizations.delegate,
								DefaultMaterialLocalizations.delegate
							],
							scrollBehavior: const CupertinoScrollBehavior().copyWith(dragDevices: {...PointerDeviceKind.values})
						);
					}
				)
			)
		);
	}
}

class ChanHomePage extends StatefulWidget {
	const ChanHomePage({Key? key}) : super(key: key);

	@override
	createState() => _ChanHomePageState();
}
class _ChanHomePageState extends State<ChanHomePage> {
	bool initialized = false;
	String? boardFetchErrorMessage;
	late bool isInTabletLayout;
	int tabletIndex = 0;
	final _keys = <int, GlobalKey>{};
	final _tabController = CupertinoTabController();
	bool showTabPopup = false;
	late final PersistentBrowserState browserState;
	final tabs = <Tuple2<PersistentBrowserTab, Key>>[];
	final activeBrowserTab = ValueNotifier<int>(0);
	final _tabListController = ScrollController();

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
		initialized = context.read<Persistence>().boardBox.length > 0;
		browserState = context.read<Persistence>().browserState;
		tabs.addAll(browserState.tabs.map((tab) => Tuple2(tab, GlobalKey())));
		activeBrowserTab.value = browserState.currentTab;
		_setupBoards();
	}

	Widget _buildTab(BuildContext context, int index, bool active) {
		Widget child;
		if (index <= 0) {
			child = ValueListenableBuilder(
				valueListenable: activeBrowserTab,
				builder: (context, int index, child) {
					return IndexedStack(
						index: index,
						children: List.generate(tabs.length, (i) => ExcludeFocus(
							excluding: i != activeBrowserTab.value,
							child: ImageboardTab(
								key: tabs[i].item2,
								initialBoard: tabs[i].item1.board,
								initialThread: tabs[i].item1.thread,
								onBoardChanged: (newBoard) {
									tabs[i].item1.board = newBoard;
									browserState.save();
									setState(() {});
								},
								onThreadChanged: (newThread) {
									tabs[i].item1.thread = newThread;
									browserState.save();
									setState(() {});
								},
								id: 'tab${tabs[index].item2.hashCode}'
							)
						))
					);
				}
			);
		}
		else if (index == 1) {
			child = const SavedPage();
		}
		else if (index == 2) {
			child = const HistoryPage();
		}
		else if (index == 3) {
			child = const SearchPage();
		}
		else {
			child = const SettingsPage();
		}
		return KeyedSubtree(
			key: _keys.putIfAbsent(index, () => GlobalKey()),
			child: active ? child : PrimaryScrollController.none(child: child)
		);
	}

	Widget _buildTabletIcon(int index, Widget icon, String label, {bool reorderable = false, Axis axis = Axis.vertical}) {
		final child = CupertinoButton(
			padding: axis == Axis.vertical ? const EdgeInsets.only(top: 16, bottom: 16, left: 8, right: 8) : const EdgeInsets.only(top: 8, bottom: 8, left: 16, right: 16),
			child: Opacity(
				opacity: (index <= 0 ? (tabletIndex == 0 && index == -1*activeBrowserTab.value) : index == tabletIndex) ? 1.0 : 0.5,
				child: Column(
					children: [
						icon,
						const SizedBox(height: 4),
						Text(label, style: const TextStyle(fontSize: 15))
					]
				)
			),
			onPressed: () async {
				if (index <= 0) {
					if (activeBrowserTab.value == -1 * index && _tabController.index == 0) {
						if (tabs.length > 1) {
							final shouldClose = await showCupertinoDialog<bool>(
								context: context,
								barrierDismissible: true,
								builder: (context) => CupertinoAlertDialog(
									title: const Text('Close tab?'),
									actions: [
										CupertinoDialogAction(
											child: const Text('No'),
											onPressed: () {
												Navigator.of(context).pop(false);
											}
										),
										CupertinoDialogAction(
											child: const Text('Yes'),
											isDestructiveAction: true,
											onPressed: () {
												Navigator.of(context).pop(true);
											}
										)
									]
								)
							);
							if (shouldClose == true) {
								tabs.removeAt(-1 * index);
								browserState.tabs.removeAt(-1 * index);
								final newActiveTabIndex = min(activeBrowserTab.value, tabs.length - 1);
								activeBrowserTab.value = newActiveTabIndex;
								browserState.currentTab = newActiveTabIndex;
								browserState.save();
								setState(() {});
							}
						}
					}
					else {
						activeBrowserTab.value = -1 * index;
						browserState.currentTab = -1 * index;
						browserState.save();
					}
				}
				_tabController.index = max(0, index);
				setState(() {
					tabletIndex = _tabController.index;
				});
			}
		);
		if (reorderable) {
			return ReorderableDelayedDragStartListener(
				index: index.abs(),
				key: ValueKey(index),
				child: child
			);
		}
		else {
			return child;
		}
	}

	Widget _buildNewTabIcon() {
		return CupertinoButton(
			padding: const EdgeInsets.only(top: 16, bottom: 16, left: 8, right: 8),
			child: Opacity(
				opacity: 0.5,
				child: Column(
					children: const [
						Icon(Icons.add),
						SizedBox(height: 4),
						Text("New", style: TextStyle(fontSize: 15))
					]
				)
			),
			onPressed: () {
				final tab = PersistentBrowserTab();
				browserState.tabs.add(tab);
				tabs.add(Tuple2(tab, GlobalKey()));
				activeBrowserTab.value = tabs.length - 1;
				browserState.currentTab = browserState.tabs.length - 1;
				browserState.save();
				setState(() {});
				Future.delayed(const Duration(milliseconds: 100), () => _tabListController.animateTo(_tabListController.position.maxScrollExtent, duration: const Duration(milliseconds: 500), curve: Curves.ease));
			}
		);
	}

	Widget _buildTabList(Axis axis) {
		return ReorderableList(
			controller: _tabListController,
			scrollDirection: axis,
			physics: const BouncingScrollPhysics(),
			onReorder: (oldIndex, newIndex) {
				final currentTab = tabs[activeBrowserTab.value];
				if (oldIndex < newIndex) {
					newIndex -= 1;
				}
				final tab = tabs.removeAt(oldIndex);
				tabs.insert(newIndex, tab);
				browserState.tabs.removeAt(oldIndex);
				browserState.tabs.insert(newIndex, tab.item1);
				activeBrowserTab.value = tabs.indexOf(currentTab);
				browserState.currentTab = activeBrowserTab.value;
				browserState.save();
				setState(() {});
			},
			itemCount: tabs.length,
			itemBuilder: (context, i) {
				const _icon = SizedBox(
					width: 30,
					height: 30,
					child: Icon(Icons.topic)
				);
				Widget icon = _icon;
				if (tabs[i].item1.thread != null) {
					icon = ValueListenableBuilder(
						valueListenable: context.read<Persistence>().listenForPersistentThreadStateChanges(tabs[i].item1.thread!),
						builder: (context, box, child) {
							final attachment = context.read<Persistence>().getThreadStateIfExists(tabs[i].item1.thread!)?.thread?.attachment;
							if (attachment != null) {
								return ClipRRect(
									borderRadius: const BorderRadius.all(Radius.circular(4)),
									child: AttachmentThumbnail(
										fit: BoxFit.cover,
										attachment: attachment,
										width: 30,
										height: 30
									)
								);
							}
							else {
								return const Icon(Icons.topic);
							}
						}
					);
				}
				return _buildTabletIcon(i * -1, icon, tabs[i].item1.board != null ? '/${tabs[i].item1.board?.name}/' : 'None', reorderable: true, axis: axis);
			}
		);
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
							ErrorMessageCard(boardFetchErrorMessage!, remedies: {
								'Retry': _setupBoards
							})
						]
					)
				);
			}
			else {
				return const Center(
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
							width: 85,
							child: Column(
								children: [
									Expanded(
										child: Column(
											children: [
												Expanded(
													child: _buildTabList(Axis.vertical)
												),
												_buildNewTabIcon()
											]
										)
									),
									_buildTabletIcon(1, NotifyingIcon(
											icon: Icons.bookmark,
											primaryCount: context.watch<ThreadWatcher>().unseenYouCount,
											secondaryCount: context.watch<ThreadWatcher>().unseenCount
										), 'Saved'),
									_buildTabletIcon(2, const Icon(Icons.history), 'History'),
									_buildTabletIcon(3, const Icon(Icons.search), 'Search'),
									_buildTabletIcon(4, const Icon(Icons.settings), 'Settings')
								]
							)
						),
						Expanded(
							child: IndexedStack(
								index: max(0, tabletIndex),
								children: List.generate(5, (i) => ExcludeFocus(
									excluding: i != tabletIndex,
									child: _buildTab(context, i, i == tabletIndex)
								))
							)
						)
					]
				)
			);
		}
		else {
			return Stack(
				children: [
					CupertinoTabScaffold(
						controller: _tabController,
						tabBar: CupertinoTabBar(
							items: [
								const BottomNavigationBarItem(
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
								const BottomNavigationBarItem(
									icon: Icon(Icons.history),
									label: 'History'
								),
								const BottomNavigationBarItem(
									icon: Icon(Icons.search),
									label: 'Search'
								),
								const BottomNavigationBarItem(
									icon: Icon(Icons.settings),
									label: 'Settings'
								)
							],
							onTap: (index) {
								if (index == tabletIndex && index == 0) {
									setState(() {
										showTabPopup = !showTabPopup;
									});
								}
								else {
									setState(() {
										tabletIndex = index;
										showTabPopup = false;
									});
								}
							}
						),
						tabBuilder: (context, index) => CupertinoTabView(
							builder: (context) => _buildTab(context, index, true)
						)
					),
					Column(
							mainAxisAlignment: MainAxisAlignment.end,
							children: [
								Expander(
									duration: const Duration(milliseconds: 2000),
									height: 80,
									bottomSafe: false,
									expanded: showTabPopup,
									child: Container(
										color: CupertinoTheme.of(context).barBackgroundColor,
										child: Row(
											children: [
												Expanded(
													child: _buildTabList(Axis.horizontal)
												),
												_buildNewTabIcon()
											]
										)
									)
								),
								const SizedBox(
									height: 50.0
								)
							]
						)
				]
			);
		}
	}
}
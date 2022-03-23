import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:chan/models/thread.dart';
import 'package:chan/pages/history.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/search.dart';
import 'package:chan/pages/settings.dart';
import 'package:chan/pages/saved.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/cupertino_page_route.dart';
import 'package:chan/widgets/notifying_icon.dart';
import 'package:chan/widgets/tab_switching_view.dart';
import 'package:chan/widgets/util.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tuple/tuple.dart';
import 'package:url_launcher/url_launcher.dart';
import 'sites/imageboard_site.dart';
import 'package:chan/pages/tab.dart';
import 'package:provider/provider.dart';
import 'package:chan/widgets/sticky_media_query.dart';
import 'package:uni_links/uni_links.dart';

void main() async {
	WidgetsFlutterBinding.ensureInitialized();
	final imageHttpClient = (ExtendedNetworkImageProvider.httpClient as HttpClient);
	imageHttpClient.connectionTimeout = const Duration(seconds: 10);
	imageHttpClient.idleTimeout = const Duration(seconds: 10);
	imageHttpClient.maxConnectionsPerHost = 10;
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
	SavedThreadWatcher? threadWatcher;
	final settings = EffectiveSettings();
	late dynamic _lastSite;
	final Map<String, GlobalKey> _siteKeys = {};
	String? siteSetupError;
	String? siteSetupStackTrace;

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
		setState(() {
			siteSetupError = null;
		});
		try {
			final _site = makeSite(context, data);
			Persistence? _persistence = persistence;
			if (_persistence == null || site?.name != _site.name) {
				_persistence = Persistence(_site.name);
				await _persistence.initialize();
			}
			_site.persistence = _persistence;
			site = _site;
			persistence = _persistence;
			final oldThreadWatcher = threadWatcher;
			threadWatcher = SavedThreadWatcher(
				site: _site,
				persistence: _persistence,
				settings: settings
			);
			setState(() {});
			await Future.delayed(const Duration(seconds: 5));
			oldThreadWatcher?.dispose();
		}
		catch (e, st) {
			siteSetupError = 'Fatal setup error\n' + e.toStringDio();
			siteSetupStackTrace = st.toStringDio();
			print(e);
			print(st);
		}
	}

	@override
	Widget build(BuildContext context) {
		SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
		SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
			systemNavigationBarColor: Colors.transparent,
			systemNavigationBarDividerColor: Colors.transparent
		));
		return CallbackShortcuts(
			bindings: {
				LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.equal): () {
					if (settings.interfaceScale < 2.0) {
						settings.interfaceScale += 0.05;
					}
				},
				LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.minus): () {
					if (settings.interfaceScale > 0.5) {
						settings.interfaceScale -= 0.05;
					}
				}
			},
			child: MultiProvider(
				providers: [
					ChangeNotifierProvider.value(value: settings),
					if (threadWatcher != null) ...[
						Provider<ImageboardSite>.value(value: site!),
						ChangeNotifierProvider<Persistence>.value(value: persistence!),
						ChangeNotifierProvider<SavedThreadWatcher>.value(value: threadWatcher!)
					]
				],
				child: SettingsSystemListener(
					child: MediaQuery.fromWindow(
						child: StickyMediaQuery(
							top: true,
							child: Builder(
								builder: (BuildContext context) {
									final settings = context.watch<EffectiveSettings>();
									final mq = MediaQuery.of(context);
									CupertinoThemeData theme = settings.makeLightTheme(context);
									if (settings.whichTheme == Brightness.dark) {
										theme = settings.makeDarkTheme(context);
									}
									return MediaQuery(
										data: mq.copyWith(boldText: false),
										child: CupertinoApp(
											title: 'Chance',
											useInheritedMediaQuery: true,
											debugShowCheckedModeBanner: false,
											theme: theme,
											home: FilterZone(
												filter: settings.filter,
												child: Builder(
													builder: (BuildContext context) {
														site?.context = context;
														return DefaultTextStyle(
															style: CupertinoTheme.of(context).textTheme.textStyle,
															child: RootCustomScale(
																scale: ((Platform.isMacOS || Platform.isWindows || Platform.isLinux) ? 1.3 : 1.0) / settings.interfaceScale,
																child: threadWatcher != null ? ChanHomePage(key: _siteKeys.putIfAbsent(site!.name, () => GlobalKey())) : Container(
																	color: CupertinoTheme.of(context).scaffoldBackgroundColor,
																	child: Center(
																		child: siteSetupError != null ? ErrorMessageCard(siteSetupError!, remedies: {
																			if (siteSetupStackTrace != null) 'More details': () {
																				alertError(context, siteSetupStackTrace!);
																			},
																			'Resynchronize': () {
																				setState(() {
																					siteSetupError = null;
																				});
																				settings.updateContentSettings();
																			},
																			'Edit content preferences': () {
																				launch(settings.contentSettingsUrl, forceSafariVC: false);
																				settings.addAppResumeCallback(() async {
																					await Future.delayed(const Duration(seconds: 1));
																					settings.updateContentSettings();
																				});
																			}
																		}) : const CupertinoActivityIndicator()
																	)
																)
															)
														);
													}
												)
											),
											localizationsDelegates: const [
												DefaultCupertinoLocalizations.delegate,
												DefaultMaterialLocalizations.delegate
											]
										)
									);
								}
							)
						)
					)
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
	int tabletIndex = 0;
	final _keys = <int, GlobalKey>{};
	final _tabController = CupertinoTabController();
	bool showTabPopup = false;
	late final PersistentBrowserState browserState;
	final tabs = <Tuple3<PersistentBrowserTab, GlobalKey, ValueNotifier<int>>>[];
	late Listenable browseCountListenable;
	final activeBrowserTab = ValueNotifier<int>(0);
	final _tabListController = ScrollController();
	ImageboardSite? devSite;
	Persistence? devPersistence;
	StickyThreadWatcher? devThreadWatcher;
	Timer? _saveBrowserTabsDuringDraftEditingTimer;
	final _tabNavigatorKeys = <int, GlobalKey<NavigatorState>>{};
	final _tabletWillPopZones = <int, WillPopZone>{};
	final _settingsNavigatorKey = GlobalKey<NavigatorState>();
	bool _queuedUpdateBrowserState = false;
	bool _isScrolling = false;

	void _didUpdateBrowserState() {
		if (_isScrolling) {
			_queuedUpdateBrowserState = true;
		}
		else {
			context.read<Persistence>().didUpdateBrowserState();
		}
	}

	bool _onScrollNotification(Notification notification) {
		if (notification is ScrollStartNotification) {
			_isScrolling = true;
		}
		else if (notification is ScrollEndNotification) {
			_isScrolling = false;
			if (_queuedUpdateBrowserState) {
				context.read<Persistence>().didUpdateBrowserState();
				_queuedUpdateBrowserState = false;
			}
		}
		return false;
	}

	void _setupDevSite() async {
		devSite = makeSite(context, defaultSite);
		devPersistence = Persistence('devsite');
		await devPersistence!.initialize();
		devThreadWatcher = StickyThreadWatcher(
			persistence: devPersistence!,
			site: devSite!,
			settings: context.read<EffectiveSettings>(),
			board: 'chance'
		);
		setState(() {});
	}

	void _setupBoards() async {
		try {
			setState(() {
				boardFetchErrorMessage = null;
			});
			final freshBoards = await context.read<ImageboardSite>().getBoards();
			await context.read<Persistence>().reinitializeBoards(freshBoards);
			setState(() {
				initialized = true;
			});
		}
		catch (error, st) {
			print(error);
			print(st);
			if (!initialized) {
				setState(() {
					boardFetchErrorMessage = error.toStringDio();
				});
			}
		}
	}

	void _onNewLink(String? link) {
		if (link != null) {
			print(link);
			final threadLink = RegExp(r'chance:\/\/([^\/]+)\/thread\/(\d+)').firstMatch(link);
			if (threadLink != null) {
				_addNewTab(
					withThread: ThreadIdentifier(
						board: threadLink.group(1)!,
						id: int.parse(threadLink.group(2)!)
					),
					activate: true
				);
			}
			else {
				alertError(context, 'Unrecognized link\n$link');
			}
		}
	}

	@override
	void initState() {
		super.initState();
		initialized = context.read<Persistence>().boards.isNotEmpty;
		browserState = context.read<Persistence>().browserState;
		tabs.addAll(browserState.tabs.map((tab) => Tuple3(tab, GlobalKey(debugLabel: 'tab $tab'), ValueNotifier<int>(0))));
		browseCountListenable = Listenable.merge([activeBrowserTab, ...tabs.map((x) => x.item3)]);
		activeBrowserTab.value = browserState.currentTab;
		_setupBoards();
		_setupDevSite();
		getInitialLink().then(_onNewLink);
		linkStream.listen(_onNewLink);
	}

	void _addNewTab({
		int? atPosition,
		ThreadIdentifier? withThread,
		bool activate = false
	}) {
		final pos = atPosition ?? tabs.length;
		final tab = withThread == null ? PersistentBrowserTab() : PersistentBrowserTab(
			board: context.read<Persistence>().getBoard(withThread.board),
			thread: withThread
		);
		browserState.tabs.insert(pos, tab);
		tabs.insert(pos, Tuple3(tab, GlobalKey(debugLabel: 'tab $tab'), ValueNotifier<int>(0)));
		browseCountListenable = Listenable.merge([activeBrowserTab, ...tabs.map((x) => x.item3)]);
		if (activate) {
			activeBrowserTab.value = pos;
			browserState.currentTab = pos;
		}
		showTabPopup = true;
		_didUpdateBrowserState();
		setState(() {});
		Future.delayed(const Duration(milliseconds: 100), () => _tabListController.animateTo((_tabListController.position.maxScrollExtent / tabs.length) * (pos + 1), duration: const Duration(milliseconds: 500), curve: Curves.ease));
	}

	Widget _buildTab(BuildContext context, int index, bool active) {
		final site = context.watch<ImageboardSite>();
		final persistence = context.watch<Persistence>();
		Widget child;
		if (index <= 0) {
			child = TabSwitchingView(
				currentTabIndex: activeBrowserTab.value,
				tabCount: tabs.length,
				tabBuilder: (context, i) {
					final tab = ImageboardTab(
						key: tabs[i].item2,
						initialBoard: tabs[i].item1.board,
						initialThread: tabs[i].item1.thread,
						onBoardChanged: (newBoard) {
							tabs[i].item1.board = newBoard;
							// Don't run I/O during the animation
							Future.delayed(const Duration(seconds: 1), () => _didUpdateBrowserState());
							setState(() {});
						},
						onThreadChanged: (newThread) {
							tabs[i].item1.thread = newThread;
							// Don't run I/O during the animation
							Future.delayed(const Duration(seconds: 1), () => _didUpdateBrowserState());
							setState(() {});
						},
						initialThreadDraftText: tabs[i].item1.draftThread,
						onThreadDraftTextChanged: (newText) {
							tabs[i].item1.draftThread = newText;
							_saveBrowserTabsDuringDraftEditingTimer?.cancel();
							_saveBrowserTabsDuringDraftEditingTimer = Timer(const Duration(seconds: 3), () => _didUpdateBrowserState());
						},
						initialThreadDraftSubject: tabs[i].item1.draftSubject,
						onThreadDraftSubjectChanged: (newSubject) {
							tabs[i].item1.draftSubject = newSubject;
							_saveBrowserTabsDuringDraftEditingTimer?.cancel();
							_saveBrowserTabsDuringDraftEditingTimer = Timer(const Duration(seconds: 3), () => _didUpdateBrowserState());
						},
						onWantOpenThreadInNewTab: (thread) {
							_addNewTab(
								atPosition: i + 1,
								withThread: thread
							);
						},
						id: -1 * (i + 10)
					);
					return Provider.value(
						value: _tabletWillPopZones.putIfAbsent(index, () => WillPopZone()),
						child: ValueListenableBuilder(
							valueListenable: activeBrowserTab,
							builder: (context, int activeIndex, child) {
								return i == activeIndex ? tab : PrimaryScrollController.none(
									child: tab
								);
							}
						)
					);
				}
			);
		}
		else if (index == 1) {
			child = SavedPage(
				isActive: active
			);
		}
		else if (index == 2) {
			child = HistoryPage(
				isActive: active
			);
		}
		else if (index == 3) {
			child = const SearchPage();
		}
		else {
			if (devThreadWatcher == null) {
				child = const Center(
					child: CupertinoActivityIndicator()
				);
			}
			else {
				return Actions(
					actions: {
						ExtendSelectionToLineBreakIntent: CallbackAction(
							onInvoke: (intent) {
								_settingsNavigatorKey.currentState?.maybePop();
								return null;
							}
						)
					},
					child: WillPopScope(
						onWillPop: () async {
							return !(await _settingsNavigatorKey.currentState?.maybePop() ?? false);
						},
						child: MultiProvider(
							providers: [
								Provider.value(value: devSite!),
								ChangeNotifierProvider.value(value: devPersistence!),
								ChangeNotifierProvider.value(value: devThreadWatcher!)
							],
							child: ClipRect(
								child: Navigator(
									key: _settingsNavigatorKey,
									initialRoute: '/',
									onGenerateRoute: (settings) => FullWidthCupertinoPageRoute(
										builder: (_) => SettingsPage(
											realPersistence: persistence,
											realSite: site
										),
										showAnimations: context.read<EffectiveSettings>().showAnimations
									)
								)
							)
						)
					)
				);
			}
		}
		child = KeyedSubtree(
			key: _keys.putIfAbsent(index, () => GlobalKey(debugLabel: '_keys[$index]')),
			child: child
		);
		if (index > 0) {
			child = Provider.value(
				value: _tabletWillPopZones.putIfAbsent(index, () => WillPopZone()),
				child: child
			);
		}
		return active ? child : PrimaryScrollController.none(child: child);
	}

	Widget _buildTabletIcon(int index, Widget icon, String? label, {
		bool reorderable = false,
		Axis axis = Axis.vertical,
		Widget Function(BuildContext, Widget)? opacityParentBuilder,
	}) {
		final content = Opacity(
			opacity: (index <= 0 ? (tabletIndex == 0 && index == -1*activeBrowserTab.value) : index == tabletIndex) ? 1.0 : 0.5,
			child: Column(
				children: [
					icon,
					if (label != null) ...[
						const SizedBox(height: 4),
						Text(label, style: const TextStyle(fontSize: 15))
					]
				]
			)
		);
		final child = CupertinoButton(
			padding: axis == Axis.vertical ? const EdgeInsets.only(top: 16, bottom: 16, left: 8, right: 8) : const EdgeInsets.only(top: 8, bottom: 8, left: 16, right: 16),
			child: opacityParentBuilder != null ? opacityParentBuilder(context, content) : content,
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
								browseCountListenable = Listenable.merge([activeBrowserTab, ...tabs.map((x) => x.item3)]);
								final newActiveTabIndex = min(activeBrowserTab.value, tabs.length - 1);
								activeBrowserTab.value = newActiveTabIndex;
								browserState.currentTab = newActiveTabIndex;
								_didUpdateBrowserState();
								setState(() {});
							}
						}
					}
					else {
						activeBrowserTab.value = -1 * index;
						browserState.currentTab = -1 * index;
						_didUpdateBrowserState();
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

	Widget _buildNewTabIcon({bool hideLabel = false}) {
		return CupertinoButton(
			padding: const EdgeInsets.only(top: 16, bottom: 16, left: 8, right: 8),
			child: Opacity(
				opacity: 0.5,
				child: Column(
					children: [
						const Icon(CupertinoIcons.add),
						if (!hideLabel) ...[
							const SizedBox(height: 4),
							const Text("New", style: TextStyle(fontSize: 15))
						]
					]
				)
			),
			onPressed: () => _addNewTab(activate: true)
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
				_didUpdateBrowserState();
				setState(() {});
			},
			itemCount: tabs.length,
			itemBuilder: (context, i) {
				const _icon = SizedBox(
					width: 30,
					height: 30,
					child: Icon(CupertinoIcons.rectangle_stack)
				);
				Widget? child;
				if (tabs[i].item1.thread != null) {
					child = ValueListenableBuilder(
						valueListenable: context.read<Persistence>().listenForPersistentThreadStateChanges(tabs[i].item1.thread!),
						builder: (context, box, child) {
							final threadState = context.read<Persistence>().getThreadStateIfExists(tabs[i].item1.thread!);
							Future.microtask(() => tabs[i].item3.value = threadState?.unseenReplyCount(Filter.of(context, listen: false)) ?? 0);
							final attachment = threadState?.thread?.attachment;
							_build() => _buildTabletIcon(i * -1, attachment == null ? _icon : ClipRRect(
									borderRadius: const BorderRadius.all(Radius.circular(4)),
									child: AttachmentThumbnail(
										gaplessPlayback: true,
										fit: BoxFit.cover,
										attachment: attachment,
										width: 30,
										height: 30
									)
								),
								tabs[i].item1.board != null ? '/${tabs[i].item1.board?.name}/' : 'None',
								reorderable: false,
								axis: axis,
								opacityParentBuilder: (context, child) => StationaryNotifyingIcon(
								icon: child,
									primary: threadState?.unseenReplyIdsToYou(Filter.of(context))?.length ?? 0,
									secondary: threadState?.unseenReplyCount(Filter.of(context)) ?? 0
								)
							);
							if (threadState != null) {
								return ValueListenableBuilder(
									valueListenable: threadState.lastSeenPostIdNotifier,
									builder: (context, _, __) => _build()
								);
							}
							return _build();
						}
					);
				}
				else {
					Future.microtask(() => tabs[i].item3.value = 0);
					child = _buildTabletIcon(i * -1, _icon, tabs[i].item1.board != null ? '/${tabs[i].item1.board?.name}/' : 'None', reorderable: false, axis: axis);
				}
				return ReorderableDelayedDragStartListener(
					index: i,
					key: ValueKey(i),
					child: child
				);
			}
		);
	}

	Future<bool> confirmExit() async {
		return (await showCupertinoDialog<bool>(
			context: context,
			barrierDismissible: true,
			builder: (context) => CupertinoAlertDialog(
				title: const Text('Exit the app?'),
				actions: [
					CupertinoDialogAction(
						child: const Text('Cancel'),
						onPressed: () {
							Navigator.of(context).pop(false);
						}
					),
					CupertinoDialogAction(
						child: const Text('Exit'),
						isDestructiveAction: true,
						onPressed: () {
							Navigator.of(context).pop(true);
						}
					)
				]
			)
		) ?? false);
	}

	@override
	Widget build(BuildContext context) {
		final isInTabletLayout = (MediaQuery.of(context).size.width - 85) > (MediaQuery.of(context).size.height - 50);
		final hideTabletLayoutLabels = MediaQuery.of(context).size.height < 600;
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
			return FilterZone(
				filter: context.watch<Persistence>().browserState.imageMD5Filter,
				child: NotificationListener<ScrollNotification>(
					onNotification: _onScrollNotification,
					child: Actions(
						actions: {
							ExtendSelectionToLineBreakIntent: CallbackAction(
								onInvoke: (intent) {
									_tabletWillPopZones[tabletIndex]?.callback?.call();
									return null;
								}
							)
						},
						child: WillPopScope(
							onWillPop: () async {
								return ((await _tabletWillPopZones[tabletIndex]?.callback?.call() ?? false) && (await confirmExit()));
							},
							child: CupertinoPageScaffold(
								child: Container(
									color: CupertinoTheme.of(context).barBackgroundColor,
									child: SafeArea(
										top: false,
										bottom: false,
										child: Row(
											children: [
												Container(
													padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
													width: 85,
													child: Column(
														children: [
															Expanded(
																child: Column(
																	children: [
																		Expanded(
																			child: _buildTabList(Axis.vertical)
																		),
																		_buildNewTabIcon(hideLabel: hideTabletLayoutLabels)
																	]
																)
															),
															_buildTabletIcon(1, const Icon(CupertinoIcons.bookmark), hideTabletLayoutLabels ? null : 'Saved',
																opacityParentBuilder: (context, child) => NotifyingIcon(
																	icon: child,
																	primaryCount: context.watch<SavedThreadWatcher>().unseenYouCount,
																	secondaryCount: context.watch<SavedThreadWatcher>().unseenCount
																)
															),
															_buildTabletIcon(2, const Icon(CupertinoIcons.archivebox), hideTabletLayoutLabels ? null : 'History'),
															_buildTabletIcon(3, const Icon(CupertinoIcons.search), hideTabletLayoutLabels ? null : 'Search'),
															_buildTabletIcon(4, const Icon(CupertinoIcons.settings), hideTabletLayoutLabels ? null : 'Settings',
																opacityParentBuilder: (context, child) => NotifyingIcon(
																	icon: child,
																	primaryCount: devThreadWatcher?.unseenYouCount ?? ValueNotifier(0),
																	secondaryCount: devThreadWatcher?.unseenStickyThreadCount ?? ValueNotifier(0),
																)
															)
														]
													)
												),
												Expanded(
													child: TabSwitchingView(
														currentTabIndex: max(0, tabletIndex),
														tabCount: 5,
														tabBuilder: (context, i) => _buildTab(context, i, i == tabletIndex)
													)
												)
											]
										)
									)
								)
							)
						)
					)
				)
			);
		}
		else {
			return FilterZone(
				filter: context.watch<Persistence>().browserState.imageMD5Filter,
				child: NotificationListener<ScrollNotification>(
					onNotification: _onScrollNotification,
					child: Actions(
						actions: {
							ExtendSelectionToLineBreakIntent: CallbackAction(
								onInvoke: (intent) {
									_tabNavigatorKeys[_tabController.index]?.currentState?.maybePop();
									return null;
								}
							)
						},
						child: WillPopScope(
							onWillPop: () async {
								return (!(await _tabNavigatorKeys[_tabController.index]?.currentState?.maybePop() ?? false) && (await confirmExit()));
							},
							child: CupertinoTabScaffold(
								controller: _tabController,
								tabBar: CupertinoTabBar(
									items: [
										BottomNavigationBarItem(
											icon: AnimatedBuilder(
												animation: browseCountListenable,
												builder: (context, child) => StationaryNotifyingIcon(
													icon: const Icon(CupertinoIcons.rectangle_stack, size: 28),
													primary: 0,
													secondary: (tabs.length == 1) ? 0 : tabs.asMap().entries.where((x) => x.key != activeBrowserTab.value || tabletIndex > 0).map((x) => x.value.item3.value).reduce((a, b) => a + b)
												)
											),
											label: 'Browse'
										),
										BottomNavigationBarItem(
											icon: Builder(
												builder: (context) => NotifyingIcon(
													icon: const Icon(CupertinoIcons.bookmark, size: 28),
													primaryCount: context.watch<SavedThreadWatcher>().unseenYouCount,
													secondaryCount: context.watch<SavedThreadWatcher>().unseenCount
												)
											),
											label: 'Saved'
										),
										const BottomNavigationBarItem(
											icon: Icon(CupertinoIcons.archivebox, size: 28),
											label: 'History'
										),
										const BottomNavigationBarItem(
											icon: Icon(CupertinoIcons.search, size: 28),
											label: 'Search'
										),
										BottomNavigationBarItem(
											icon: NotifyingIcon(
												icon: const Icon(CupertinoIcons.settings, size: 28),
												primaryCount: devThreadWatcher?.unseenYouCount ?? ValueNotifier(0),
												secondaryCount: devThreadWatcher?.unseenStickyThreadCount ?? ValueNotifier(0),
											),
											label: 'Settings'
										)
									],
									onTap: (index) {
										if (index == tabletIndex && index == 0) {
											setState(() {
												showTabPopup = !showTabPopup;
											});
										}
										else if (index == tabletIndex) {
											if (tabletIndex == 4) {
												_settingsNavigatorKey.currentState?.maybePop();
											}
											else {
												_tabletWillPopZones[tabletIndex]?.callback?.call();
											}
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
									navigatorKey: _tabNavigatorKeys.putIfAbsent(index, () => GlobalKey<NavigatorState>()),
									builder: (context) => Column(
										children: [
											Expanded(
												child: AnimatedBuilder(
													animation: _tabController,
													builder: (context, child) => _buildTab(context, index, _tabController.index == index)
												)
											),
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
											)
										]
									)
								)
							)
						)
					)
				)
			);
		}
	}
}
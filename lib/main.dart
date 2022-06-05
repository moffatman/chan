import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:chan/models/thread.dart';
import 'package:chan/pages/history.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/search.dart';
import 'package:chan/pages/settings.dart';
import 'package:chan/pages/saved.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/notifications.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/pick_attachment.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/cupertino_page_route.dart';
import 'package:chan/widgets/notifications_overlay.dart';
import 'package:chan/widgets/notifying_icon.dart';
import 'package:chan/widgets/tab_switching_view.dart';
import 'package:chan/widgets/util.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'sites/imageboard_site.dart';
import 'package:chan/pages/tab.dart';
import 'package:provider/provider.dart';
import 'package:chan/widgets/sticky_media_query.dart';
import 'package:uni_links/uni_links.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

bool _initialLinkConsumed = false;
bool _initialMediaConsumed = false;

void main() async {
	WidgetsFlutterBinding.ensureInitialized();
	final imageHttpClient = (ExtendedNetworkImageProvider.httpClient as HttpClient);
	imageHttpClient.connectionTimeout = const Duration(seconds: 10);
	imageHttpClient.idleTimeout = const Duration(seconds: 10);
	imageHttpClient.maxConnectionsPerHost = 10;
	await Persistence.initializeStatic();
	await Notifications.initializeStatic();
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
	final Map<String, GlobalKey> _siteKeys = {};
	String? siteSetupError;
	String? siteSetupStackTrace;
	Notifications? notifications;

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
			final tmpSite = makeSite(context, data);
			Persistence? tmpPersistence = persistence;
			if (tmpPersistence == null || site?.name != tmpSite.name) {
				tmpPersistence = Persistence(tmpSite.name);
				await tmpPersistence.initialize();
				notifications = Notifications(
					persistence: tmpPersistence,
					site: tmpSite
				);
				await notifications?.initialize();
				// Only try to reauth on wifi
				Future.microtask(() async {
					final savedFields = await tmpSite.getSavedLoginFields();
					if (savedFields != null && settings.connectivity == ConnectivityResult.wifi) {
						try {
							await tmpSite.login(savedFields);
							print('Auto-logged in');
						}
						catch (e) {
							showToast(
								context: context,
								icon: CupertinoIcons.exclamationmark_triangle,
								message: 'Failed to log in to ${tmpSite.getLoginSystemName()}'
							);
							print('Problem auto-logging in: $e');
						}
					}
				});
			}
			tmpSite.persistence = tmpPersistence;
			site = tmpSite;
			persistence = tmpPersistence;
			final oldThreadWatcher = threadWatcher;
			threadWatcher = ThreadWatcher(
				site: tmpSite,
				persistence: tmpPersistence,
				settings: settings,
				notifications: notifications!
			);
			notifications?.localWatcher = threadWatcher!;
			setState(() {});
			await Future.delayed(const Duration(seconds: 5));
			oldThreadWatcher?.dispose();
		}
		catch (e, st) {
			siteSetupError = 'Fatal setup error\n${e.toStringDio()}';
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
						ChangeNotifierProvider<ThreadWatcher>.value(value: threadWatcher!),
						Provider<Notifications>.value(value: notifications!)
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
																				launchUrl(Uri.parse(settings.contentSettingsUrl), mode: LaunchMode.externalApplication);
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

final notificationsOverlayKey = GlobalKey<NotificationsOverlayState>();
void clearOverlayNotifications(Notifications notifications, Watch watch) {
	/*final overlay = notificationsOverlayKey.currentState;
	if (overlay != null) {
		for (final n in overlay.shown.toList()) {
			if (n.notifications != notifications) {
				continue;
			}
			if (watch is ThreadWatch && watch.threadIdentifier == n.target.threadIdentifier) {
				overlay.closeNotification(n);
			}
		}
	}*/
}

class _ChanBrowseTab extends ChangeNotifier {
	final PersistentBrowserTab tab;
	final tabKey = GlobalKey();
	final boardKey = GlobalKey();
	final unseen = ValueNotifier(0);

	_ChanBrowseTab(this.tab);

	void didUpdate() {
		notifyListeners();
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
	int _lastIndex = 0;
	final _keys = <int, GlobalKey>{};
	final _tabController = CupertinoTabController();
	bool showTabPopup = false;
	late final PersistentBrowserState browserState;
	final tabs = <_ChanBrowseTab>[];
	late Listenable browseCountListenable;
	final activeBrowserTab = ValueNotifier<int>(0);
	final _tabListController = ScrollController();
	ImageboardSite? devSite;
	Persistence? devPersistence;
	ThreadWatcher? devThreadWatcher;
	Notifications? devNotifications;
	Timer? _saveBrowserTabsDuringDraftEditingTimer;
	final _tabNavigatorKeys = <int, GlobalKey<NavigatorState>>{};
	final _tabletWillPopZones = <int, WillPopZone>{};
	final _settingsNavigatorKey = GlobalKey<NavigatorState>();
	bool _queuedUpdateBrowserState = false;
	bool _isScrolling = false;
	final _savedMasterDetailKey = GlobalKey<MultiMasterDetailPageState>();
	final PersistentBrowserTab _savedFakeTab = PersistentBrowserTab();

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

	void _onDevNotificationTapped(ThreadOrPostIdentifier id) async {
		_tabController.index = 4;
		_lastIndex = 4;
		final settings = context.read<EffectiveSettings>();
		for (int i = 0; i < 200 && _settingsNavigatorKey.currentState == null; i++) {
			await Future.delayed(const Duration(milliseconds: 50));
		}
		_settingsNavigatorKey.currentState?.popUntil((r) => r.isFirst);
		_settingsNavigatorKey.currentState?.push(
			FullWidthCupertinoPageRoute(
				builder: (context) => ThreadPage(
					thread: id.threadIdentifier,
					initialPostId: id.postId,
					boardSemanticId: -1
				),
				showAnimations: settings.showAnimations
			)
		);
		if (showTabPopup) {
			setState(() {
				showTabPopup = false;
			});
		}
	}

	void _setupDevSite() async {
		final settings = context.read<EffectiveSettings>();
		devSite = makeSite(context, defaultSite);
		devPersistence = Persistence('devsite');
		await devPersistence!.initialize();
		devNotifications = Notifications(
			site: devSite!,
			persistence: devPersistence!
		);
		await devNotifications!.initialize();
		devNotifications!.tapStream.listen(_onDevNotificationTapped);
		devThreadWatcher = ThreadWatcher(
			persistence: devPersistence!,
			site: devSite!,
			settings: settings,
			notifications: devNotifications!,
			watchForStickyOnBoards: ['chance'],
			interval: const Duration(minutes: 10)
		);
		devNotifications?.localWatcher = devThreadWatcher!;
		setState(() {});
	}

	void _setupBoards() async {
		final persistence = context.read<Persistence>();
		try {
			setState(() {
				boardFetchErrorMessage = null;
			});
			final freshBoards = await context.read<ImageboardSite>().getBoards();
			await persistence.reinitializeBoards(freshBoards);
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
		if (link != null && link.startsWith('chance:')) {
			print(link);
			final threadLink = RegExp(r'chance:\/\/([^\/]+)\/thread\/(\d+)').firstMatch(link);
			if (threadLink != null) {
				_addNewTab(
					withThread: ThreadIdentifier(
						threadLink.group(1)!,
						int.parse(threadLink.group(2)!)
					),
					activate: true
				);
			}
			else {
				alertError(context, 'Unrecognized link\n$link');
			}
		}
	}

	void _animateTabToPost(PersistentBrowserTab tab, int postId) async {
		if (!(tab.threadController?.items.any((p) => p.id == postId) ?? false)) {
			await tab.threadController?.update();
		}
		tab.threadController?.animateTo((p) => p.id == postId, alignment: 1.0);
		if (tab.threadController == null) {
			await Future.delayed(const Duration(seconds: 1));
			tab.threadController?.animateTo((p) => p.id == postId, alignment: 1.0);
		}
	}

	void _onNotificationTapped(ThreadOrPostIdentifier notification) async {
		if (!_goToPost(
			board: notification.board,
			threadId: notification.threadId,
			postId: notification.postId,
			openNewTabIfNeeded: false
		)) {
			final watch = context.read<Persistence>().browserState.threadWatches.tryFirstWhere((w) => w.threadIdentifier == notification.threadIdentifier);
			if (watch != null) {
				_tabController.index = 1;
				_lastIndex = 1;
				for (int i = 0; i < 200 && _savedMasterDetailKey.currentState == null; i++) {
					await Future.delayed(const Duration(milliseconds: 50));
				}
				_savedMasterDetailKey.currentState?.setValue(0, watch);
				if (showTabPopup) {
					setState(() {
						showTabPopup = false;
					});
				}
				if (notification.postId != null) {
					_animateTabToPost(_savedFakeTab, notification.postId!);
				}
			}
		}
	}

	void _consumeLink(String? link) {
		if (link != null) {
			final dest = context.read<ImageboardSite>().decodeUrl(link);
			if (dest != null) {
				_onNotificationTapped(dest);
			}
		}
	}

	void _consumeFiles(List<SharedMediaFile> files) {
		if (files.isNotEmpty) {
			showToast(
				context: context,
				message: '${(files.length > 1 ? 'Files' : 'File')} added to upload selector',
				icon: CupertinoIcons.paperclip
			);
			for (final file in files) {
				receivedFilePaths.add(file.path);
			}
		}
	}

	@override
	void initState() {
		super.initState();
		initialized = context.read<Persistence>().boards.isNotEmpty;
		browserState = context.read<Persistence>().browserState;
		tabs.addAll(browserState.tabs.map((tab) => _ChanBrowseTab(tab)));
		browseCountListenable = Listenable.merge([activeBrowserTab, ...tabs.map((x) => x.unseen)]);
		activeBrowserTab.value = browserState.currentTab;
		_setupBoards();
		_setupDevSite();
		getInitialLink().then(_onNewLink);
		linkStream.listen(_onNewLink);
		context.read<Notifications>().tapStream.listen(_onNotificationTapped);
		if (!_initialLinkConsumed) {
			ReceiveSharingIntent.getInitialText().then(_consumeLink);
		}
		if (!_initialMediaConsumed) {
			ReceiveSharingIntent.getInitialMedia().then(_consumeFiles).then((_) {
				_initialMediaConsumed = true;
			});
		}
		ReceiveSharingIntent.getMediaStream().listen(_consumeFiles);
		ReceiveSharingIntent.getTextStream().listen(_consumeLink);
	}

	PersistentBrowserTab _addNewTab({
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
		tabs.insert(pos, _ChanBrowseTab(tab));
		browseCountListenable = Listenable.merge([activeBrowserTab, ...tabs.map((x) => x.unseen)]);
		if (activate) {
			_tabController.index = 0;
			activeBrowserTab.value = pos;
			browserState.currentTab = pos;
		}
		showTabPopup = true;
		_didUpdateBrowserState();
		setState(() {});
		Future.delayed(const Duration(milliseconds: 100), () => _tabListController.animateTo((_tabListController.position.maxScrollExtent / tabs.length) * (pos + 1), duration: const Duration(milliseconds: 500), curve: Curves.ease));
		return tab;
	}

	bool _goToPost({
		required String board,
		required int threadId,
		int? postId,
		required bool openNewTabIfNeeded
	}) {
		PersistentBrowserTab? tab = browserState.tabs.tryFirstWhere((tab) => tab.thread?.board == board && tab.thread?.id == threadId);
		if (openNewTabIfNeeded) {
			tab ??= _addNewTab(
				activate: false,
				withThread: ThreadIdentifier(board, threadId)
			);
		}
		if (tab != null) {
			final index = browserState.tabs.indexOf(tab);
			_tabController.index = 0;
			activeBrowserTab.value = index;
			browserState.currentTab = index;
			_didUpdateBrowserState();
			setState(() {});
			if (postId != null) {
				_animateTabToPost(tab, postId);
			}
			return true;
		}
		return false;
	}

	Widget _buildTab(BuildContext context, int index, bool active) {
		final site = context.watch<ImageboardSite>();
		final persistence = context.select<Persistence, Persistence>((p) => p);
		Widget child;
		if (index <= 0) {
			child = AnimatedBuilder(
				animation: activeBrowserTab,
				builder: (context, _) => TabSwitchingView(
					currentTabIndex: activeBrowserTab.value,
					tabCount: tabs.length,
					tabBuilder: (context, i) {
						final tabObject = tabs[i];
						final tab = ImageboardTab(
							key: tabObject.tabKey,
							boardKey: tabObject.boardKey,
							initialBoard: tabObject.tab.board,
							initialThread: tabObject.tab.thread,
							onBoardChanged: (newBoard) {
								tabObject.tab.board = newBoard;
								// Don't run I/O during the animation
								Future.delayed(const Duration(seconds: 1), () => _didUpdateBrowserState());
								tabObject.didUpdate();
							},
							onThreadChanged: (newThread) {
								tabObject.tab.thread = newThread;
								// Don't run I/O during the animation
								Future.delayed(const Duration(seconds: 1), () => _didUpdateBrowserState());
								tabObject.didUpdate();
							},
							getInitialThreadDraftText: () => tabObject.tab.draftThread,
							onThreadDraftTextChanged: (newText) {
								tabObject.tab.draftThread = newText;
								_saveBrowserTabsDuringDraftEditingTimer?.cancel();
								_saveBrowserTabsDuringDraftEditingTimer = Timer(const Duration(seconds: 3), () => _didUpdateBrowserState());
							},
							getInitialThreadDraftSubject: () => tabObject.tab.draftSubject,
							onThreadDraftSubjectChanged: (newSubject) {
								tabObject.tab.draftSubject = newSubject;
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
						return ChangeNotifierProvider.value(
							value: tabObject,
							child: Provider.value(
								value: _tabletWillPopZones.putIfAbsent(index, () => WillPopZone()),
								child: ValueListenableBuilder(
									valueListenable: activeBrowserTab,
									builder: (context, int activeIndex, child) {
										return i == activeIndex ? tab : PrimaryScrollController.none(
											child: tab
										);
									}
								)
							)
						);
					}
				)
			);
		}
		else if (index == 1) {
			child = Provider.value(
				value: _savedFakeTab,
				child: SavedPage(
					isActive: active,
					masterDetailKey: _savedMasterDetailKey,
					onWantOpenThreadInNewTab: (thread) {
						_addNewTab(
							withThread: thread,
							activate: true
						);
					}
				)
			);
		}
		else if (index == 2) {
			child = HistoryPage(
				isActive: active,
				onWantOpenThreadInNewTab: (thread) {
					_addNewTab(
						withThread: thread,
						activate: true
					);
				}
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
								ChangeNotifierProvider.value(value: devThreadWatcher!),
								Provider.value(value: devNotifications!)
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
		Widget Function(BuildContext, Widget)? opacityParentBuilder
	}) {
		final content = Opacity(
			opacity: (index <= 0 ? (_tabController.index == 0 && index == -1 * activeBrowserTab.value) : index == _tabController.index) ? 1.0 : 0.5,
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
											isDestructiveAction: true,
											onPressed: () {
												Navigator.of(context).pop(true);
											},
											child: const Text('Yes')
										)
									]
								)
							);
							if (shouldClose == true) {
								tabs.removeAt(-1 * index);
								browserState.tabs.removeAt(-1 * index);
								browseCountListenable = Listenable.merge([activeBrowserTab, ...tabs.map((x) => x.unseen)]);
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
				browserState.tabs.insert(newIndex, tab.tab);
				activeBrowserTab.value = tabs.indexOf(currentTab);
				browserState.currentTab = activeBrowserTab.value;
				_didUpdateBrowserState();
				setState(() {});
			},
			itemCount: tabs.length,
			itemBuilder: (context, i) {
				const blankIcon = SizedBox(
					width: 30,
					height: 30,
					child: Icon(CupertinoIcons.rectangle_stack)
				);
				return ReorderableDelayedDragStartListener(
					index: i,
					key: ValueKey(i),
					child: AnimatedBuilder(
						animation: tabs[i],
						builder: (context, _) {
							if (tabs[i].tab.thread != null) {
								return AnimatedBuilder(
									animation: context.read<Persistence>().listenForPersistentThreadStateChanges(tabs[i].tab.thread!),
									builder: (context, _) {
										final threadState = context.read<Persistence>().getThreadStateIfExists(tabs[i].tab.thread!);
										Future.microtask(() => tabs[i].unseen.value = threadState?.unseenReplyCount(Filter.of(context, listen: false)) ?? 0);
										final attachment = threadState?.thread?.attachment;
										buildIcon() => _buildTabletIcon(i * -1, attachment == null ? blankIcon : ClipRRect(
												borderRadius: const BorderRadius.all(Radius.circular(4)),
												child: AttachmentThumbnail(
													gaplessPlayback: true,
													fit: BoxFit.cover,
													attachment: attachment,
													width: 30,
													height: 30
												)
											),
											tabs[i].tab.board != null ? '/${tabs[i].tab.board?.name}/' : 'None',
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
												builder: (context, _, __) => buildIcon()
											);
										}
										return buildIcon();
									}
								);
							}
							else {
								Future.microtask(() => tabs[i].unseen.value = 0);
								return _buildTabletIcon(i * -1, blankIcon, tabs[i].tab.board != null ? '/${tabs[i].tab.board?.name}/' : 'None', reorderable: false, axis: axis);
							}
						}
					)
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
						isDestructiveAction: true,
						onPressed: () {
							Navigator.of(context).pop(true);
						},
						child: const Text('Exit')
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
		final child = isInTabletLayout ? NotificationListener<ScrollNotification>(
			onNotification: _onScrollNotification,
			child: Actions(
				actions: {
					ExtendSelectionToLineBreakIntent: CallbackAction(
						onInvoke: (intent) {
							_tabletWillPopZones[_tabController.index]?.callback?.call();
							return null;
						}
					)
				},
				child: WillPopScope(
					onWillPop: () async {
						return ((await _tabletWillPopZones[_tabController.index]?.callback?.call() ?? false) && (await confirmExit()));
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
																	child: AnimatedBuilder(
																		animation: activeBrowserTab,
																		builder: (context, _) => _buildTabList(Axis.vertical)
																	)
																),
																_buildNewTabIcon(hideLabel: hideTabletLayoutLabels)
															]
														)
													),
													_buildTabletIcon(1, const Icon(CupertinoIcons.bookmark), hideTabletLayoutLabels ? null : 'Saved',
														opacityParentBuilder: (context, child) => NotifyingIcon(
															icon: child,
															primaryCount: context.read<ThreadWatcher>().unseenYouCount,
															secondaryCount: context.read<ThreadWatcher>().unseenCount
														)
													),
													_buildTabletIcon(2, browserState.enableHistory ? const Icon(CupertinoIcons.archivebox) : const Icon(CupertinoIcons.eye_slash), hideTabletLayoutLabels ? null : 'History'),
													_buildTabletIcon(3, const Icon(CupertinoIcons.search), hideTabletLayoutLabels ? null : 'Search'),
													_buildTabletIcon(4, const Icon(CupertinoIcons.settings), hideTabletLayoutLabels ? null : 'Settings',
														opacityParentBuilder: (context, child) => NotifyingIcon(
															icon: child,
															primaryCount: devThreadWatcher?.unseenYouCount ?? ValueNotifier(0),
															secondaryCount: devThreadWatcher?.unseenCount ?? ValueNotifier(0),
														)
													)
												]
											)
										),
										Expanded(
											child: AnimatedBuilder(
												animation: _tabController,
												builder: (context, _) => TabSwitchingView(
													currentTabIndex: _tabController.index,
													tabCount: 5,
													tabBuilder: (context, i) => _buildTab(context, i, i == _tabController.index)
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
		) : NotificationListener<ScrollNotification>(
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
											secondary: (tabs.length == 1) ? 0 : tabs.asMap().entries.where((x) => x.key != activeBrowserTab.value || _tabController.index > 0).map((x) => x.value.unseen.value).reduce((a, b) => a + b)
										)
									),
									label: 'Browse'
								),
								BottomNavigationBarItem(
									icon: Builder(
										builder: (context) => NotifyingIcon(
											icon: const Icon(CupertinoIcons.bookmark, size: 28),
											primaryCount: context.read<ThreadWatcher>().unseenYouCount,
											secondaryCount: context.read<ThreadWatcher>().unseenCount
										)
									),
									label: 'Saved'
								),
								BottomNavigationBarItem(
									icon: browserState.enableHistory ? const Icon(CupertinoIcons.archivebox, size: 28) : const Icon(CupertinoIcons.eye_slash, size: 28),
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
										secondaryCount: devThreadWatcher?.unseenCount ?? ValueNotifier(0),
									),
									label: 'Settings'
								)
							],
							onTap: (index) {
								if (index == _lastIndex && index == 0) {
									setState(() {
										showTabPopup = !showTabPopup;
									});
								}
								else if (index == _lastIndex) {
									if (index == 4) {
										_settingsNavigatorKey.currentState?.maybePop();
									}
									else {
										_tabletWillPopZones[index]?.callback?.call();
									}
								}
								else if (showTabPopup) {
									setState(() {
										showTabPopup = false;
									});
								}
								_lastIndex = index;
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
														child: AnimatedBuilder(
															animation: activeBrowserTab,
															builder: (context, _) => _buildTabList(Axis.horizontal)
														)
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
		);
		return NotificationsOverlay(
			onePane: !isInTabletLayout,
			key: notificationsOverlayKey,
			notifications: [
				context.watch<Notifications>(),
				if (devNotifications != null) devNotifications!
			],
			child: FilterZone(
				filter: context.select<Persistence, Filter>((p) => p.browserState.imageMD5Filter),
				child: child
			)
		);
	}
}
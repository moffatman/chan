import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:chan/firebase_options.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/search.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/board.dart';
import 'package:chan/pages/history.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/search.dart';
import 'package:chan/pages/settings.dart';
import 'package:chan/pages/saved.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/apple.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/installed_fonts.dart';
import 'package:chan/services/json_cache.dart';
import 'package:chan/services/media.dart';
import 'package:chan/services/notifications.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/pick_attachment.dart';
import 'package:chan/services/rlimit.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/share.dart';
import 'package:chan/services/storage.dart';
import 'package:chan/services/streaming_mp4.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/services/util.dart';
import 'package:chan/util.dart';
import 'package:chan/version.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/drawer.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/injecting_navigator.dart';
import 'package:chan/widgets/notifications_overlay.dart';
import 'package:chan/widgets/notifying_icon.dart';
import 'package:chan/widgets/saved_theme_thumbnail.dart';
import 'package:chan/widgets/scroll_tracker.dart';
import 'package:chan/widgets/tab_menu.dart';
import 'package:chan/widgets/tab_switching_view.dart';
import 'package:chan/widgets/thread_widget_builder.dart';
import 'package:chan/widgets/util.dart';
import 'package:chan/widgets/weak_gesture_recognizer.dart';
import 'package:extended_image/extended_image.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:local_auth/local_auth.dart';
import 'package:media_kit/media_kit.dart';
import 'package:native_drag_n_drop/native_drag_n_drop.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/subjects.dart';
import 'package:chan/pages/tab.dart';
import 'package:provider/provider.dart';
import 'package:chan/widgets/sticky_media_query.dart';
import 'package:uni_links/uni_links.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

final fakeLinkStream = PublishSubject<String?>();
bool _initialConsume = false;
final zeroValueNotifier = ValueNotifier(0);
bool _promptedAboutCrashlytics = false;
bool developerMode = false;

void main() async {
	runZonedGuarded<Future<void>>(() async {
		try {
			await initializeRLimit();
			WidgetsFlutterBinding.ensureInitialized();
			await initializeIsDevelopmentBuild();
			await initializeIsOnMac();
			await initializeHandoff();
			final imageHttpClient = (ExtendedNetworkImageProvider.httpClient as HttpClient);
			imageHttpClient.connectionTimeout = const Duration(seconds: 10);
			imageHttpClient.idleTimeout = const Duration(seconds: 10);
			imageHttpClient.maxConnectionsPerHost = 10;
			if (Platform.isAndroid || Platform.isIOS) {
				await Firebase.initializeApp(
					options: DefaultFirebaseOptions.currentPlatform
				);
				FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
			}
			await Persistence.initializeStatic();
			VideoServer.initializeStatic(Persistence.webmCacheDirectory, Persistence.httpCacheDirectory);
			await Notifications.initializeStatic();
			await updateDynamicColors();
			await initializeFonts();
			MediaKit.ensureInitialized();
			await JsonCache.instance.initialize();
			await MediaScan.initializeStatic();
			if (kDebugMode) {
				await resetAdditionalSafeAreaInsets();
			}
			runApp(const ChanApp());
		}
		catch (e, st) {
			runApp(ChanFailedApp(e, st));
		}
	}, (error, stack) => FirebaseCrashlytics.instance.recordError(error, stack, fatal: true));
}

class ChanFailedApp extends StatelessWidget {
	final Object error;
	final StackTrace stackTrace;
	const ChanFailedApp(this.error, this.stackTrace, {Key? key}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return Provider.value(
			value: defaultDarkTheme,
			child: CupertinoApp(
				theme: const CupertinoThemeData(
					primaryColor: Colors.white,
					brightness: Brightness.dark
				),
				home: Center(
					child: StatefulBuilder(
						builder: (context, setState) => ErrorMessageCard(
							'Sorry, an unrecoverable error has occured:\n${error.toStringDio()}\n$stackTrace',
							remedies: {
								if (Settings.featureDumpData && Platform.isAndroid) 'Dump data': () async {
									try {
										final src = await getApplicationDocumentsDirectory();
										final dst = await pickDirectory();
										if (dst == null) {
											return;
										}
										await for (final child in src.list(recursive: true)) {
											if (child.statSync().type != FileSystemEntityType.file) {
												continue;
											}
											final path = child.path.replaceFirst(src.path, '/');
											final parts = path.split('/');
											parts.removeWhere((p) => p.isEmpty);
											final filename = parts.removeLast();
											await saveFile(
												destinationDir: dst,
												destinationSubfolders: parts,
												sourcePath: child.absolute.path,
												destinationName: filename
											);
										}
										if (context.mounted) {
											showCupertinoDialog(
												context: context,
												builder: (context) => CupertinoAlertDialog(
													title: const Text('Export successful!'),
													actions: [
														CupertinoDialogAction(
															onPressed: () => Navigator.pop(context),
															child: const Text('OK')
														)
													]
												)
											);
										}
									}
									catch (e, st) {
										print(e);
										print(st);
										if (context.mounted) {
											showCupertinoDialog(
												context: context,
												builder: (context) => CupertinoAlertDialog(
													title: const Text('Error'),
													content: Text(e.toStringDio()),
													actions: [
														CupertinoDialogAction(
															onPressed: () => Navigator.pop(context),
															child: const Text('OK')
														)
													]
												)
											);
										}
									}
								},
								'Report via Email': () {
									FlutterEmailSender.send(Email(
										subject: 'Unrecoverable Chance Error',
										recipients: ['callum@moffatman.com'],
										isHTML: true,
										body: '''<p>Hi Callum,</p>
														<p>Chance v$kChanceVersion isn't starting and is giving the following error:</p>
														<p>$error</p>
														<p>${const LineSplitter().convert(stackTrace.toString()).join('</p><p>')}</p>
														<p>Thanks!</p>'''
									));
								},
								if (Persistence.doesCachedThreadBoxExist) 'Clear cached thread database': () async {
									final ok = await showCupertinoDialog<bool>(
										context: context,
										builder: (context) => CupertinoAlertDialog(
											title: const Text('Delete threads data'),
											content: const Text('The local threads database might be corrupt. No user data is in this file, just thread data which could probably be redownloaded from its site or an archive. If Chance is stuck at this error page, this might fix it.'),
											actions: [
												CupertinoDialogAction(
													onPressed: () => Navigator.pop(context, false),
													child: const Text('Cancel')
												),
												CupertinoDialogAction(
													onPressed: () => Navigator.pop(context, true),
													isDefaultAction: true,
													isDestructiveAction: true,
													child: const Text('Clear')
												)
											]
										)
									);
									if (ok ?? false) {
										try {
											await Persistence.deleteCachedThreadBoxAndBackup();
											if (context.mounted) {
												showCupertinoDialog<bool>(
													context: context,
													builder: (context) => CupertinoAlertDialog(
														title: const Text('Cleared'),
														content: const Text('Now quit Chance via your multitasking switcher and relaunch it.'),
														actions: [
															CupertinoDialogAction(
																onPressed: () => Navigator.pop(context),
																isDefaultAction: true,
																child: const Text('OK')
															)
														]
													)
												);
											}
										}
										catch (e, st) {
											Future.error(e, st); // Crashlytics
											if (context.mounted) {
												showCupertinoDialog<bool>(
													context: context,
													builder: (context) => CupertinoAlertDialog(
														title: const Text('Error'),
														content: Text(e.toStringDio()),
														actions: [
															CupertinoDialogAction(
																onPressed: () => Navigator.pop(context),
																isDefaultAction: true,
																child: const Text('OK')
															)
														]
													)
												);
											}
										}
										setState(() {});
									}
								}
							}
						)
					)
				)
			)
		);
	}
}

class ChanApp extends StatefulWidget {
	const ChanApp({Key? key}) : super(key: key);

	@override
	createState() => _ChanAppState();
}

class _ChanAppState extends State<ChanApp> {
	late Map<String, Map> _lastSites;
	late Set<String> _lastSiteKeys;
	final _navigatorKey = GlobalKey<NavigatorState>();
	final _homePageKey = GlobalKey<_ChanHomePageState>();

	void _onImageboardRegistryUpdate() {
		setState(() {});
	}

	@override
	void initState() {
		super.initState();
		_lastSites = Map.from(JsonCache.instance.sites.value ?? defaultSites);
		_lastSiteKeys = Set.from(Settings.instance.settings.contentSettings.siteKeys);
		ImageboardRegistry.instance.addListener(_onImageboardRegistryUpdate);
		ImageboardRegistry.instance.initializeDev();
		ImageboardRegistry.instance.handleSites(
			context: context,
			sites: _lastSites,
			keys: _lastSiteKeys
		);
		Settings.instance.addListener(_onSettingsUpdate);
		JsonCache.instance.sites.addListener(_onSitesUpdate);
	}

	@override
	void dispose() {
		super.dispose();
		ImageboardRegistry.instance.removeListener(_onImageboardRegistryUpdate);
		Settings.instance.removeListener(_onSettingsUpdate);
		JsonCache.instance.sites.removeListener(_onSitesUpdate);
	}

	void _onSitesUpdate() {
		if (!mapEquals(JsonCache.instance.sites.value, _lastSites)) {
			_lastSites = Map.from(JsonCache.instance.sites.value ?? _lastSites);
			ImageboardRegistry.instance.handleSites(
				context: context,
				sites: _lastSites,
				keys: _lastSiteKeys
			);
		}
	}

	void _onSettingsUpdate() {
		if (!setEquals(Settings.instance.settings.contentSettings.siteKeys, _lastSiteKeys)) {
			_lastSiteKeys = Set.from(Settings.instance.settings.contentSettings.siteKeys);
			ImageboardRegistry.instance.handleSites(
				context: context,
				sites: _lastSites,
				keys: _lastSiteKeys
			);
		}
	}

	@override
	Widget build(BuildContext context) {
		SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
		SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
			systemNavigationBarColor: Colors.transparent,
			systemNavigationBarDividerColor: Colors.transparent,
			statusBarColor: Colors.transparent
		));
		return CallbackShortcuts(
			bindings: {
				LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.equal): () {
					if (Settings.instance.interfaceScale < 2.0) {
						Settings.interfaceScaleSetting.value += 0.05;
					}
				},
				LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.minus): () {
					if (Settings.instance.interfaceScale > 0.5) {
						Settings.interfaceScaleSetting.value -= 0.05;
					}
				}
			},
			child: MultiProvider(
				providers: [
					ChangeNotifierProvider.value(value: Settings.instance),
					ProxyProvider<Settings, SavedTheme>(
						update: (context, settings, result) => settings.theme
					),
					ProxyProvider<Settings, ChanceThemeKey>(
						update: (context, settings, result) => ChanceThemeKey(settings.themeKey)
					)
				],
				child: SettingsSystemListener(
					child: MediaQuery.fromView(
						view: View.of(context),
						child: StickyMediaQuery(
							top: true,
							bottom: Platform.isAndroid, // Look more at it
							child: Builder(
								builder: (BuildContext context) {
									final scrollBehavior = const CupertinoScrollBehavior().copyWith(
										physics: Platform.isAndroid ? const HybridScrollPhysics() :
											(isOnMac ? const BouncingScrollPhysics(decelerationRate: ScrollDecelerationRate.fast) : const BouncingScrollPhysics())
									);
									final home = Builder(
										builder: (BuildContext context) {
											ImageboardRegistry.instance.context = context;
											final showPerformanceOverlay = Settings.showPerformanceOverlaySetting.watch(context);
											return ImageboardRegistry.instance.initialized ? Stack(
												children: [
													// For some unexplained reason this improves performance
													// Maybe related to querying the framerate each frame?
													if (!showPerformanceOverlay) Positioned(
														top: 0,
														left: 0,
														right: 0,
														child: PerformanceOverlay.allEnabled()
													),
													ChanHomePage(key: _homePageKey),
													if (showPerformanceOverlay) Positioned(
														top: 0,
														left: 0,
														right: 0,
														child: PerformanceOverlay.allEnabled()
													)
												]
											) : Container(
												color: ChanceTheme.backgroundColorOf(context),
												child: Center(
													child: ImageboardRegistry.instance.setupError != null ? Builder(
														builder: (context) => ErrorMessageCard(ImageboardRegistry.instance.setupError!, remedies: {
															if (ImageboardRegistry.instance.setupStackTrace != null) 'More details': () {
																alertError(context, ImageboardRegistry.instance.setupStackTrace!);
															},
															'Try editing sites': () async {
																final list = Settings.instance.settings.contentSettings.siteKeys.toList();
																await editStringList(
																	context: context,
																	name: 'site key',
																	title: 'Site keys',
																	list: list
																);
																Settings.instance.settings.contentSettings.siteKeys = list.toSet();
																Settings.instance.didEdit();
															},
															if (_lastSites.keys.where(_lastSiteKeys.contains).isEmpty) 'Add dummy site': () {
																Settings.instance.addSiteKey(kTestchanKey);
															},
															'Resynchronize': () {
																JsonCache.instance.sites.update();
															}
														})
													) : const ChanSplashPage()
												)
											);
										}
									);
									const localizationsDelegates = [
										DefaultCupertinoLocalizations.delegate,
										DefaultMaterialLocalizations.delegate
									];
									final materialStyle = Settings.materialStyleSetting.watch(context);
									final (theme, _) = context.select<Settings, (SavedTheme, String?)>((s) => (s.theme, s.fontFamily));
									final globalFilter = context.select<Settings, Filter>((s) => s.globalFilter);
									final interfaceScale = Settings.interfaceScaleSetting.watch(context);
									return TransformedMediaQuery(
										transformation: (context, mq) {
											final additionalSafeAreaInsets = sumAdditionalSafeAreaInsets();
											return mq.copyWith(
												boldText: false,
												textScaler: ChainedLinearTextScaler(
													parent: mq.textScaler,
													textScaleFactor: Settings.textScaleSetting.watch(context)
												),
												padding: (mq.padding - additionalSafeAreaInsets).clamp(EdgeInsets.zero, EdgeInsetsGeometry.infinity).resolve(null),
												viewPadding: (mq.viewPadding - additionalSafeAreaInsets).clamp(EdgeInsets.zero, EdgeInsetsGeometry.infinity).resolve(null)
											);
										},
										child: RootCustomScale(
											scale: ((Platform.isMacOS || Platform.isWindows || Platform.isLinux) ? 1.3 : 1.0) / interfaceScale,
											child: FilterZone(
												filter: globalFilter,
												child: materialStyle ? MaterialApp(
													title: 'Chance',
													debugShowCheckedModeBanner: false,
													theme: theme.materialThemeData,
													scrollBehavior: scrollBehavior,
													home: home,
													localizationsDelegates: localizationsDelegates,
													navigatorKey: _navigatorKey
												) : Theme(
													data: theme.materialThemeData,
													child: CupertinoApp(
														title: 'Chance',
														debugShowCheckedModeBanner: false,
														theme: theme.cupertinoThemeData,
														scrollBehavior: scrollBehavior,
														home: home,
														localizationsDelegates: localizationsDelegates,
														navigatorKey: _navigatorKey
													)
												)
											)
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

final splashStage = ValueNotifier<String?>(null);

class ChanSplashPage extends StatelessWidget {
	const ChanSplashPage({
		super.key
	});

	@override
	Widget build(BuildContext context) {
		return Container(
			width: double.infinity,
			height: double.infinity,
			alignment: Alignment.center,
			color: ChanceTheme.backgroundColorOf(context),
			child: Column(
				mainAxisSize: MainAxisSize.min,
				children: [
					const SizedBox(height: 50),
					Transform.scale(
						scale: 1 / (
							2.0 * MediaQuery.of(context).devicePixelRatio *
							Settings.interfaceScaleSetting.watch(context)
						),
						child: ColorFiltered(
							colorFilter: ColorFilter.mode(
								ChanceTheme.barColorOf(context),
								BlendMode.srcATop
							),
							child: const Image(
								image: AssetImage('assets/splash.png')
							)
						)
					),
					ValueListenableBuilder<String?>(
						valueListenable: splashStage,
						builder: (context, stage, _) => SizedBox(
							height: 50,
							child: stage == null ? null : Text(
								stage,
								style: TextStyle(
									color: ChanceTheme.primaryColorOf(context),
									fontSize: 18
								)
							)
						)
					)
				]
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

class OpenInNewTabZone {
	final void Function(String, ThreadIdentifier, {bool incognito, bool activate}) onWantOpenThreadInNewTab;

	const OpenInNewTabZone({
		required this.onWantOpenThreadInNewTab
	});
}

class ChanHomePage extends StatefulWidget {
	const ChanHomePage({Key? key}) : super(key: key);

	@override
	createState() => _ChanHomePageState();
}

enum _AuthenticationStatus {
	ok,
	inProgress,
	failed
}

class ChanTabs extends ChangeNotifier {
	final ValueChanged<bool> onShouldShowTabPopup;
	final activeBrowserTab = ValueNotifier<int>(Persistence.currentTabIndex);
	late Listenable browseCountListenable = Listenable.merge([activeBrowserTab, ...Persistence.tabs.map((x) => x.unseen)]);
	final _tabController = CupertinoTabController();
	final _tabListController = ScrollController();
	int _lastIndex = 0;
	final _savedMasterDetailKey = GlobalKey<MultiMasterDetailPageState>();
	final _tabButtonKeys = <int, GlobalKey>{};
	final _tabNavigatorKeys = <int, GlobalKey<NavigatorState>>{};
	final _searchPageKey = GlobalKey<SearchPageState>();
	final _historyPageKey = GlobalKey<HistoryPageState>();
	final _settingsNavigatorKey = GlobalKey<NavigatorState>();

	ChanTabs({
		required this.onShouldShowTabPopup
	}) {
		Persistence.globalTabMutator.addListener(_onGlobalTabMutatorUpdate);
		ScrollTracker.instance.someNavigatorNavigated.addListener(_onSomeNavigatorNavigated);
		for (final tab in Persistence.tabs) {
			tab.addListener(_onTabUpdate);
		}
	}

	void _onGlobalTabMutatorUpdate() {
		browseTabIndex = Persistence.globalTabMutator.value;
	}

	void _onTabUpdate() {
		notifyListeners();
	}

	void _onSomeNavigatorNavigated() {
		// Recalculate shouldEnableWideDrawerGesture
		Future.microtask(notifyListeners);
	}

	Future<void> _didModifyPersistentTabData() async {
		await Persistence.settings.save();
	}

	int get mainTabIndex => _tabController.index;
	set mainTabIndex(int index) {
		_tabController.index = index;
		_lastIndex = index;
		notifyListeners();
	}

	int get browseTabIndex => activeBrowserTab.value;
	set browseTabIndex(int index) {
		if (index < 0 || index >= Persistence.tabs.length) {
			return;
		}
		activeBrowserTab.value = index;
		Persistence.currentTabIndex = index;
		notifyListeners();
		_didModifyPersistentTabData();
	}

	bool get shouldEnableWideDrawerGesture {
		if (_tabNavigatorKeys[mainTabIndex]?.currentState?.canPop() ?? false) {
			// Something covering the current navigator
			return false;
		}
		if (mainTabIndex == 0) {
			final tab = Persistence.tabs[Persistence.currentTabIndex];
			final masterNavigatorState = tab.masterDetailKey.currentState?.masterKey.currentState;
			if (masterNavigatorState != null) {
				return !masterNavigatorState.canPop();
			}
		}
		else if (mainTabIndex == 1) {
			final state = _savedMasterDetailKey.currentState;
			if (state != null) {
				if (state.selectedPane != 0) {
					// Priority is swiping left to previous pane
					return false;
				}
				final masterNavigatorState = state.masterKey.currentState;
				if (masterNavigatorState != null) {
					return !masterNavigatorState.canPop();
				}
			}
		}
		else if (mainTabIndex == 2) {
			final masterNavigatorState = _historyPageKey.currentState?.masterDetailKey.currentState?.masterKey.currentState;
			if (masterNavigatorState != null) {
				return !masterNavigatorState.canPop();
			}
		}
		else if (mainTabIndex == 3) {
			final masterNavigatorState = _searchPageKey.currentState?.masterDetailKey.currentState?.masterKey.currentState;
			if (masterNavigatorState != null) {
				return !masterNavigatorState.canPop();
			}
		}
		else if (mainTabIndex == 4) {
			final state = _settingsNavigatorKey.currentState;
			if (state != null) {
				return !state.canPop();
			}
		}
		return true;
	}

	@override
	void dispose() {
		super.dispose();
		activeBrowserTab.dispose();
		_tabListController.dispose();
		Persistence.globalTabMutator.removeListener(_onGlobalTabMutatorUpdate);
		ScrollTracker.instance.someNavigatorNavigated.removeListener(_onSomeNavigatorNavigated);
		for (final tab in Persistence.tabs) {
			tab.removeListener(_onTabUpdate);
		}
	}

	PersistentBrowserTab addNewTab({
		String? withImageboardKey,
		int? atPosition,
		String? withBoard,
		ThreadIdentifier? withThread,
		int? withThreadId,
		bool activate = false,
		bool incognito = false,
		int? withInitialPostId,
		String? withInitialSearch,
		bool keepTabPopupOpen = false,
		bool initiallyUseArchive = false
	}) {
		final pos = atPosition ?? Persistence.tabs.length;
		final tab = PersistentBrowserTab(
			imageboardKey: withImageboardKey,
			board: withImageboardKey == null || withBoard == null ? null : withBoard,
			thread: withThread ?? (withThreadId == null ? null : ThreadIdentifier(withBoard!, withThreadId)),
			incognito: incognito,
			initialSearch: withInitialSearch
		);
		tab.initialize();
		if (withBoard != null && withThreadId != null && withInitialPostId != null) {
			tab.initialPostId[ThreadIdentifier(withBoard, withThreadId)] = withInitialPostId;
		}
		if (withBoard != null && withThreadId != null && initiallyUseArchive) {
			tab.initiallyUseArchive[ThreadIdentifier(withBoard, withThreadId)] = true;
		}
		insertInitializedTab(pos, tab,
			keepTabPopupOpen: keepTabPopupOpen,
			activate: activate
		);
		return tab;
	}
	
	void insertInitializedTab(int pos, PersistentBrowserTab tab, {
		bool keepTabPopupOpen = false,
		bool activate = false
	}) {
		tab.addListener(_onTabUpdate);
		Persistence.tabs.insert(pos, tab);
		browseCountListenable = Listenable.merge([activeBrowserTab, ...Persistence.tabs.map((x) => x.unseen)]);
		if (activate) {
			_tabController.index = 0;
			activeBrowserTab.value = pos;
			Persistence.currentTabIndex = pos;
		}
		onShouldShowTabPopup(keepTabPopupOpen || !activate || !Persistence.settings.closeTabSwitcherAfterUse);
		_didModifyPersistentTabData();
		notifyListeners();
		Future.delayed(const Duration(milliseconds: 100), () {
			_animateTabList(index: pos);
		});
	}

	void onReorder(int oldIndex, int newIndex) {
		final currentTab = Persistence.tabs[activeBrowserTab.value];
		if (oldIndex < newIndex) {
			newIndex -= 1;
		}
		final tab = Persistence.tabs.removeAt(oldIndex);
		Persistence.tabs.insert(newIndex, tab);
		activeBrowserTab.value = Persistence.tabs.indexOf(currentTab);
		Persistence.currentTabIndex = activeBrowserTab.value;
		_didModifyPersistentTabData();
		notifyListeners();
	}

	void closeBrowseTab(int browseIndex) {
		final removed = Persistence.tabs.removeAt(browseIndex);
		removed.removeListener(_onTabUpdate);
		browseCountListenable = Listenable.merge([activeBrowserTab, ...Persistence.tabs.map((x) => x.unseen)]);
		final newActiveTabIndex = min(activeBrowserTab.value, Persistence.tabs.length - 1);
		activeBrowserTab.value = newActiveTabIndex;
		Persistence.currentTabIndex = newActiveTabIndex;
		_didModifyPersistentTabData();
		notifyListeners();
	}

	Future<void> showNewTabPopup({
		required BuildContext context,
		required AxisDirection direction,
		required Axis? titles
	}) async {
		lightHapticFeedback();
		final ro = context.findRenderObject()! as RenderBox;
		showTabMenu(
			context: context,
			direction: direction,
			titles: titles,
			origin: Rect.fromPoints(
				ro.localToGlobal(ro.semanticBounds.topLeft),
				ro.localToGlobal(ro.semanticBounds.bottomRight)
			),
			actions: [
				TabMenuAction(
					icon: CupertinoIcons.eyeglasses,
					title: 'Private',
					onPressed: () {
						lightHapticFeedback();
						addNewTab(activate: true, incognito: true);
					}
				),
				TabMenuAction(
					icon: CupertinoIcons.xmark_square,
					title: 'Close others',
					isDestructiveAction: true,
					onPressed: Persistence.tabs.length == 1 ? null : () async {
						lightHapticFeedback();
						final shouldCloseOthers = await showAdaptiveDialog<bool>(
							context: context,
							barrierDismissible: true,
							builder: (context) => AdaptiveAlertDialog(
								title: const Text('Close all other tabs?'),
								actions: [
									AdaptiveDialogAction(
										onPressed: () => Navigator.of(context).pop(true),
										isDestructiveAction: true,
										child: Text('Close ${Persistence.tabs.length - 1 - (Settings.instance.usingHomeBoard && Persistence.currentTabIndex != 0 ? 1 : 0)}')
									),
									AdaptiveDialogAction(
										onPressed: () => Navigator.of(context).pop(false),
										child: const Text('Cancel')
									)
								]
							)
						);
						if (shouldCloseOthers == true) {
							final beforeRemove = {...Persistence.tabs.asMap()};
							final indexToPreserve = browseTabIndex;
							PersistentBrowserTab? homeTabToPreserve;
							if (indexToPreserve != 0 && Settings.instance.usingHomeBoard) {
								homeTabToPreserve = Persistence.tabs.first;
								beforeRemove.remove(0); // Nothing to undo
							}
							final tabToPreserve = Persistence.tabs[indexToPreserve];
							for (final tab in Persistence.tabs) {
								tab.removeListener(_onTabUpdate);
							}
							Persistence.tabs.clear();
							if (homeTabToPreserve != null) {
								Persistence.tabs.add(homeTabToPreserve);
							}
							Persistence.tabs.add(tabToPreserve);
							tabToPreserve.addListener(_onTabUpdate);
							homeTabToPreserve?.addListener(_onTabUpdate);
							browseCountListenable = Listenable.merge([activeBrowserTab, ...Persistence.tabs.map((x) => x.unseen)]);
							browseTabIndex = homeTabToPreserve == null ? 0 : 1;
							if (Persistence.settings.closeTabSwitcherAfterUse) {
								onShouldShowTabPopup(false);
							}
							if (context.mounted) {
								showUndoToast(
									context: context,
									message: 'Closed ${describeCount(beforeRemove.length - 1, 'tab')}',
									onUndo: () {
										for (final pair in beforeRemove.entries) {
											if (pair.key != indexToPreserve) {
												insertInitializedTab(pair.key, pair.value);
											}
										}
										browseTabIndex = indexToPreserve;
									},
									padding: const EdgeInsets.only(bottom: 50)
								);
							}
						}
					}
				)
			]
		);
	}

	ImageboardScoped<ThreadIdentifier>? get currentBrowserThread {
		final tab = Persistence.tabs[Persistence.currentTabIndex];
		final thread = tab.thread;
		if (thread == null) {
			return null;
		}
		return tab.imageboard?.scope(thread);
	}

	void setCurrentBrowserThread(ImageboardScoped<ThreadIdentifier>? newThread, {
		bool showAnimationsForward = true
	}) {
		final tab = Persistence.tabs[Persistence.currentTabIndex];
		if (newThread != null && tab.imageboardKey != newThread.imageboard.key) {
			tab.imageboardKey = newThread.imageboard.key;
			// Old master-pane is no longer applicable
			tab.board = newThread.item.board;
			tab.boardKey.currentState?.swapBoard(newThread.imageboard.scope(newThread.imageboard.persistence.getBoard(newThread.item.board)));
		}
		tab.masterDetailKey.currentState?.setValue(0, newThread?.item, showAnimationsForward: showAnimationsForward);
		tab.didUpdate();
		runWhenIdle(const Duration(seconds: 1), Persistence.saveTabs);
	}
	

	ImageboardScoped<ThreadWatch>? get selectedWatchedThread {
		return _savedMasterDetailKey.currentState?.getValue<ImageboardScoped<ThreadWatch>>(0);
	}
	set selectedWatchedThread(ImageboardScoped<ThreadWatch>? newWatchedThread) {
		_savedMasterDetailKey.currentState?.setValue(0, newWatchedThread);
	}
	set selectedWatchedThreadWithoutAnimation(ImageboardScoped<ThreadWatch>? newWatchedThread) {
		_savedMasterDetailKey.currentState?.setValue(0, newWatchedThread, showAnimationsForward: false);
	}

	Future<void> openSavedTab() async {
		mainTabIndex = 1;
		for (int i = 0; i < 200 && _savedMasterDetailKey.currentState == null; i++) {
			await Future.delayed(const Duration(milliseconds: 50));
		}
	}

	void _animateTabList({int? index, Duration duration = const Duration(milliseconds: 500)}) {
		final pos = index ?? browseTabIndex;
		final ctx = _tabButtonKeys[pos]?.currentContext;
		if (ctx == null) {
			return;
		}
		Scrollable.ensureVisible(
			ctx,
			alignmentPolicy: pos < 3 ? // Kind of a hack guess, mainly to handle cloning the home tab
				ScrollPositionAlignmentPolicy.keepVisibleAtStart :
				ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
			duration: duration
		);
	}
}

class _ChanHomePageState extends State<ChanHomePage> {
	late final ChanTabs _tabs;
	final _keys = <int, GlobalKey>{};
	bool _showTabPopup = false;
	({Notifications notifications, StreamSubscription<PostIdentifier> subscription})? _devNotificationsSubscription;
	Imageboard? get devImageboard => ImageboardRegistry.instance.dev;
	final devTab = PersistentBrowserTab();
	final _willPopZones = <int, WillPopZone>{};
	final PersistentBrowserTab _savedFakeTab = PersistentBrowserTab();
	final Map<String, ({Notifications notifications, StreamSubscription<PostIdentifier> subscription})> _notificationsSubscriptions = {};
	late StreamSubscription<String?> _linkSubscription;
	late StreamSubscription<String?> _fakeLinkSubscription;
	late StreamSubscription<List<SharedMediaFile>> _sharedFilesSubscription;
	late StreamSubscription<String> _sharedTextSubscription;
	// Sometimes duplicate links are received due to use of multiple link handling packages
	({DateTime time, String link})? _lastLink;
	bool _hideTabPopupAutomatically = false;
	_AuthenticationStatus _authenticationStatus = _AuthenticationStatus.ok;
	final _drawerScaffoldKey = GlobalKey<AdaptiveScaffoldState>(debugLabel: '_ChanHomePageState._drawerScaffoldKey');

	bool get showTabPopup => _showTabPopup;
	set showTabPopup(bool setting) {
		_showTabPopup = setting;
		_setAdditionalSafeAreaInsets();
	}

	void _onSlowScrollDirectionChange() async {
		if (!Settings.instance.tabMenuHidesWhenScrollingDown) {
			return;
		}
		if (_tabs.mainTabIndex != 0) {
			return;
		}
		await SchedulerBinding.instance.endOfFrame;
		_setAdditionalSafeAreaInsets();
		if (ScrollTracker.instance.slowScrollDirection.value == VerticalDirection.down && showTabPopup) {
			setState(() {
				showTabPopup = false;
				_hideTabPopupAutomatically = true;
			});
		}
		else if (ScrollTracker.instance.slowScrollDirection.value == VerticalDirection.up && _hideTabPopupAutomatically) {
			setState(() {
				showTabPopup = true;
				_hideTabPopupAutomatically = false;
			});
		}
	}

	void _onDevNotificationTapped(BoardThreadOrPostIdentifier id) async {
		_tabs.mainTabIndex = 4;
		if (showTabPopup) {
			setState(() {
				_hideTabPopupAutomatically = true;
				showTabPopup = false;
			});
		}
		for (int i = 0; i < 200 && _tabs._settingsNavigatorKey.currentState == null; i++) {
			await Future.delayed(const Duration(milliseconds: 50));
		}
		final thread = id.threadIdentifier;
		final postId = id.postId;
		if (thread == null) {
			// Load board page
			_tabs._settingsNavigatorKey.currentState?.popUntil((r) => r.isFirst);
			_tabs._settingsNavigatorKey.currentState?.push(
				adaptivePageRoute(
					builder: (context) => BoardPage(
						initialBoard: ImageboardRegistry.instance.dev!.persistence.getBoard(id.board),
						allowChangingBoard: false,
						semanticId: -1
					)
				)
			);
		}
		else if (devTab.threadPageState?.widget.thread != thread) {
			_tabs._settingsNavigatorKey.currentState?.popUntil((r) => r.isFirst);
			_tabs._settingsNavigatorKey.currentState?.push(
				adaptivePageRoute(
					builder: (context) => ThreadPage(
						thread: thread,
						initialPostId: postId,
						boardSemanticId: -1
					)
				)
			);
		}
		else if (postId != null) {
			await devTab.threadPageState?.scrollToPost(postId);
		}
	}

	Future<void> _consumeLink(String? link) async {
		final settings = Settings.instance;
		if (link == null) {
			return;
		}
		if (_lastLink != null && link == _lastLink?.link && DateTime.now().isBefore(_lastLink!.time.add(const Duration(seconds: 1)))) {
			return;
		}
		_lastLink = (time: DateTime.now(), link: link);
		if (link.startsWith('chance:')) {
			final uri = Uri.parse(link);
			if (uri.host == 'theme') {
				try {
					final name = uri.queryParameters['name']!;
					final theme = SavedTheme.decode(uri.queryParameters['data']!);
					final match = settings.themes.entries.tryFirstWhere((e) => e.value == theme);
					await showAdaptiveDialog(
						context: context,
						barrierDismissible: true,
						builder: (dialogContext) => AdaptiveAlertDialog(
							title: Text('Import $name?'),
							content: Column(
								mainAxisSize: MainAxisSize.min,
								children: [
									const SizedBox(height: 16),
									ClipRRect(
										borderRadius: BorderRadius.circular(8),
										child: SizedBox(
											height: 150,
											child: SavedThemeThumbnail(
												theme: theme,
												showTitleAndTextField: true
											)
										)
									),
									const SizedBox(height: 16),
									if (match?.key == name) const Text('This theme has already been added.')
									else if (match != null) Text('This theme has already been added as ${match.key}.')
								]
							),
							actions: [
								AdaptiveDialogAction(
									isDefaultAction: settings.whichTheme == Brightness.light,
									onPressed: settings.lightTheme == theme ? null : () {
										String effectiveName = name;
										if (match == null) {
											effectiveName = settings.addTheme(name, theme);
										}
										Settings.lightThemeKeySetting.value = match?.key ?? effectiveName;
										settings.handleThemesAltered();
										Navigator.of(dialogContext).pop();
									},
									child: const Text('Use as light theme')
								),
								AdaptiveDialogAction(
									isDefaultAction: settings.whichTheme == Brightness.dark,
									onPressed: settings.darkTheme == theme ? null : () {
										String effectiveName = name;
										if (match == null) {
											effectiveName = settings.addTheme(name, theme);
										}
										Settings.darkThemeKeySetting.value = match?.key ?? effectiveName;
										settings.handleThemesAltered();
										Navigator.of(dialogContext).pop();
									},
									child: const Text('Use as dark theme')
								),
								AdaptiveDialogAction(
									onPressed: match != null ? null : () {
										settings.addTheme(name, theme);
										settings.handleThemesAltered();
										Navigator.of(dialogContext).pop();
									},
									child: const Text('Just import')
								),
								AdaptiveDialogAction(
									child: const Text('Cancel'),
									onPressed: () {
										Navigator.of(dialogContext).pop();
									}
								),
							]
						)
					);
				}
				catch (e) {
					if (mounted) {
						alertError(context, 'Error adding theme: $e');
					}
				}
			}
			else if (uri.pathSegments.length >= 2 && uri.pathSegments[1] == 'thread') {
				_tabs.addNewTab(
					withImageboardKey: uri.host,
					withBoard: uri.pathSegments[0],
					withThreadId: int.parse(uri.pathSegments[2]),
					activate: true
				);
			}
			else if (uri.host == 'site') {
				final siteKey = uri.pathSegments[0];
				try {
					if (ImageboardRegistry.instance.getImageboard(siteKey) == null) {
						if (Settings.instance.contentSettings.siteKeys.trySingle == kTestchanKey) {
							throw Exception('Not allowed to add arbitrary sites');
						}
						final consent = await confirm(context, 'Add site $siteKey?');
						if (consent != true) {
							return;
						}
						if (!mounted) return;
						await modalLoad(context, 'Setting up...', (_) async {
							Settings.instance.addSiteKey(siteKey);
							await Future.delayed(const Duration(milliseconds: 500)); // wait for rebuild of ChanHomePage
						});
					}
					_tabs.addNewTab(
						withImageboardKey: siteKey,
						activate: true,
						keepTabPopupOpen: true
					);
				}
				catch (e) {
					if (mounted) {
						alertError(context, 'Error adding site: $e');
					}
				}
			}
			else if (link != 'chance://') {
				alertError(context, 'Unrecognized link\n$link');
			}
		}
		else if (link.toLowerCase().startsWith('sharemedia-com.moffatman.chan://')) {
			// ignore this, it is handled elsewhere
		}
		else {
			final devDest = await devImageboard?.site.decodeUrl(link);
			if (devDest != null) {
				_onDevNotificationTapped(devDest);
				return;
			}
			if (!mounted) return;
			final dest = await modalLoad(context, 'Checking url...', (_) => ImageboardRegistry.instance.decodeUrl(link), wait: const Duration(milliseconds: 50));
			if (dest != null) {
				_onNotificationTapped(dest.$1, dest.$2, initiallyUseArchive: dest.$3);
				return;
			}
			if (!mounted) return;
			final open = await showAdaptiveDialog<bool>(
				context: context,
				barrierDismissible: true,
				builder: (context) => AdaptiveAlertDialog(
					title: const Text('Unrecognized link'),
					content: Text('No site supports opening "$link"'),
					actions: [
						AdaptiveDialogAction(
							onPressed: () => Navigator.pop(context, true),
							child: const Text('Open in browser')
						),
						AdaptiveDialogAction(
							onPressed: () => Navigator.pop(context, false),
							child: const Text('Cancel')
						)
					]
				)
			);
			if (open == true && mounted) {
				await shareOne(
					context: context,
					type: 'text',
					text: link,
					sharePositionOrigin: null
				);
			}
		}
	}

	void _scrollExistingTab(PersistentBrowserTab tab, int postId) async {
		for (int i = 0; i < 200 && tab.threadPageState == null; i++) {
			await Future.delayed(const Duration(milliseconds: 50));
		}
		tab.threadPageState?.scrollToPost(postId);
	}

	void _onNotificationTapped(Imageboard imageboard, BoardThreadOrPostIdentifier notification, {
		bool initiallyUseArchive = false
	}) async {
		if (!_goToPost(
			imageboardKey: imageboard.key,
			board: notification.board,
			threadId: notification.threadId,
			postId: notification.postId,
			openNewTabIfNeeded: false,
			initiallyUseArchive: initiallyUseArchive
		)) {
			final watch = imageboard.persistence.browserState.threadWatches[notification.threadIdentifier];
			if (watch == null) {
				_goToPost(
					imageboardKey: imageboard.key,
					board: notification.board,
					threadId: notification.threadId,
					postId: notification.postId,
					openNewTabIfNeeded: true,
					initiallyUseArchive: initiallyUseArchive
				);
			}
			else {
				await _tabs.openSavedTab();
				if (_tabs.selectedWatchedThread?.item == watch && notification.postId != null) {
					_scrollExistingTab(_savedFakeTab, notification.postId!);
				}
				else {
					if (notification.postId != null) {
						_savedFakeTab.initialPostId[notification.threadIdentifier!] = notification.postId!;
					}
					_tabs._savedMasterDetailKey.currentState?.setValue(0, imageboard.scope(watch));
				}
				if (showTabPopup) {
					setState(() {
						_hideTabPopupAutomatically = true;
						showTabPopup = false;
					});
				}
			}
		}
	}

	void _consumeFiles(List<String> paths) {
		if (paths.isNotEmpty) {
			showToast(
				context: context,
				message: '${(paths.length > 1 ? 'Files' : 'File')} added to upload selector',
				icon: CupertinoIcons.paperclip
			);
			receivedFilePaths.addAll(paths);
			attachmentSourceNotifier.didUpdate();
		}
	}

	void _tabsListener() {
		if (mounted) {
			setState(() {});
		}
	}

	Future<void> _setAdditionalSafeAreaInsets() async {
		await setAdditionalSafeAreaInsets('main', EdgeInsets.only(
			bottom: 60 + 44 + (showTabPopup ? 80 : 0)
		) * Settings.instance.interfaceScale);
	}

	void _onShouldShowTabPopup(bool newShowTabPopup) {
		showTabPopup = newShowTabPopup;
	}

	@override
	void initState() {
		super.initState();
		_tabs = ChanTabs(
			onShouldShowTabPopup: _onShouldShowTabPopup
		);
		_tabs.addListener(_tabsListener);
		if (!_initialConsume) {
			getInitialLink().then(_consumeLink);
			ReceiveSharingIntent.getInitialText().then(_consumeLink);
			ReceiveSharingIntent.getInitialMedia().then((f) => _consumeFiles(f.map((x) => x.path).toList()));
		}
		_linkSubscription = linkStream.listen(_consumeLink);
		_fakeLinkSubscription = fakeLinkStream.listen(_consumeLink);
		_sharedFilesSubscription = ReceiveSharingIntent.getMediaStream().listen((f) => _consumeFiles(f.map((x) => x.path).toList()));
		_sharedTextSubscription = ReceiveSharingIntent.getTextStream().listen(_consumeLink);
		_initialConsume = true;
		_setAdditionalSafeAreaInsets();
		ScrollTracker.instance.slowScrollDirection.addListener(_onSlowScrollDirectionChange);
		if (Persistence.settings.launchCount > 5 && !Persistence.settings.promptedAboutCrashlytics && !_promptedAboutCrashlytics) {
			_promptedAboutCrashlytics = true;
			Future.delayed(const Duration(milliseconds: 300), () async {
				if (!mounted) return;
				final choice = await showAdaptiveDialog<bool>(
					context: context,
					builder: (context) => AdaptiveAlertDialog(
						title: const Text('Contribute crash data?'),
						content: const Text('Crash stack traces and uncaught exceptions will be used to help fix bugs. No personal information will be collected.'),
						actions: [
							AdaptiveDialogAction(
								child: const Text('Yes'),
								onPressed: () {
									Navigator.of(context).pop(true);
								}
							),
							AdaptiveDialogAction(
								child: const Text('No'),
								onPressed: () {
									Navigator.of(context).pop(false);
								}
							)
						]
					)
				);
				if (choice != null) {
					FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(choice);
					if (!mounted) return;
					Settings.promptedAboutCrashlyticsSetting.value = true;
				}
			});
		}
		WidgetsBinding.instance.addPostFrameCallback((_) {
			_tabs._animateTabList();
		});
		if (Settings.instance.askForAuthenticationOnLaunch) {
			_authenticate();
		}
	}

	Future<void> _authenticate() async {
		_authenticationStatus = _AuthenticationStatus.inProgress;
		try {
			final result = await LocalAuthentication().authenticate(localizedReason: 'Verify access to app', options: const AuthenticationOptions(stickyAuth: true));
			_authenticationStatus = result ? _AuthenticationStatus.ok : _AuthenticationStatus.failed;
		}
		catch (e, st) {
			Future.error(e, st); // Report to crashlytics
			_authenticationStatus = _AuthenticationStatus.failed;
		}
		if (mounted) {
			setState(() {});
		}
	}


	bool _goToPost({
		required String imageboardKey,
		required String board,
		required int? threadId,
		int? postId,
		required bool openNewTabIfNeeded,
		bool initiallyUseArchive = false
	}) {
		PersistentBrowserTab? tab = Persistence.tabs.tryFirstWhere((tab) => tab.imageboardKey == imageboardKey && tab.thread?.board == board && tab.thread?.id == threadId);
		final tabAlreadyExisted = tab != null;
		if (openNewTabIfNeeded) {
			tab ??= _tabs.addNewTab(
				activate: false,
				withImageboardKey: imageboardKey,
				withBoard: board,
				withThreadId: threadId,
				withInitialPostId: postId,
				initiallyUseArchive: initiallyUseArchive
			);
		}
		if (tab != null) {
			_tabs.mainTabIndex = 0;
			_tabs.browseTabIndex = Persistence.tabs.indexOf(tab);
			if (tabAlreadyExisted && postId != null) {
				_scrollExistingTab(tab, postId);
			}
			return true;
		}
		return false;
	}

	Widget _buildTab(BuildContext context, int index, bool active) {
		Widget child;
		if (index <= 0) {
			child = AnimatedBuilder(
				animation: _tabs.activeBrowserTab,
				builder: (context, _) => TabSwitchingView(
					currentTabIndex: _tabs.activeBrowserTab.value,
					tabCount: Persistence.tabs.length,
					tabBuilder: (context, i) {
						final tabObject = Persistence.tabs[i];
						return AnimatedBuilder(
							animation: tabObject,
							builder: (context, _) {
								final tab = ImageboardTab(
									tab: tabObject,
									key: tabObject.tabKey,
									onWantArchiveSearch: (imageboardKey, board, query) async {
										_tabs.mainTabIndex = 3;
										for (int i = 0; i < 200 && _tabs._searchPageKey.currentState == null; i++) {
											await Future.delayed(const Duration(milliseconds: 50));
										}
										_tabs._searchPageKey.currentState?.onSearchComposed(ImageboardArchiveSearchQuery(
											imageboardKey: imageboardKey,
											boards: [board],
											query: query
										));
									},
									id: -1 * (i + 20)
								);
								return MultiProvider(
									providers: [
										ChangeNotifierProvider.value(value: tabObject),
										Provider.value(
											value: OpenInNewTabZone(
												onWantOpenThreadInNewTab: (imageboardKey, thread, {bool incognito = false, bool activate = true}) {
													_tabs.addNewTab(
														withImageboardKey: imageboardKey,
														atPosition: Persistence.tabs.indexOf(tabObject) + 1,
														withBoard: thread.board,
														withThreadId: thread.id,
														activate: activate,
														incognito: incognito
													);
												}
											)
										)
									],
									child: ValueListenableBuilder(
										valueListenable: _tabs.activeBrowserTab,
										builder: (context, int activeIndex, child) {
											return i == activeIndex ? child! : PrimaryScrollController.none(
												child: child!
											);
										},
										child: tabObject.imageboardKey == null ? tab : ImageboardScope(
											imageboardKey: tabObject.imageboardKey!,
											overridePersistence: tabObject.incognitoPersistence,
											loaderOffset: _androidDrawer ? Offset.zero : (isScreenWide ? const Offset(-42.5, 0) : const Offset(0, 25)),
											child: tab
										)
									),
								);
							}
						);
					}
				)
			);
		}
		else if (index == 1) {
			child = MultiProvider(
				providers: [
					ChangeNotifierProvider.value(
						value: _savedFakeTab
					),
					Provider.value(
						value: OpenInNewTabZone(
							onWantOpenThreadInNewTab: (imageboardKey, thread, {bool incognito = false, bool activate = true}) => _tabs.addNewTab(
								withImageboardKey: imageboardKey,
								withBoard: thread.board,
								withThreadId: thread.id,
								activate: activate,
								incognito: incognito
							)
						)
					)
				],
				child: SavedPage(
					isActive: active,
					masterDetailKey: _tabs._savedMasterDetailKey
				)
			);
		}
		else if (index == 2) {
			child = Provider.value(
				value: OpenInNewTabZone(
					onWantOpenThreadInNewTab: (imageboardKey, thread, {bool incognito = false, bool activate = true}) => _tabs.addNewTab(
						withImageboardKey: imageboardKey,
						withBoard: thread.board,
						withThreadId: thread.id,
						activate: activate,
						incognito: incognito
					)
				),
				child: HistoryPage(
					isActive: active,
					key: _tabs._historyPageKey
				)
			);
		}
		else if (index == 3) {
			child = Provider.value(
				value: OpenInNewTabZone(
					onWantOpenThreadInNewTab: (imageboardKey, thread, {bool incognito = false, bool activate = true}) => _tabs.addNewTab(
						withImageboardKey: imageboardKey,
						withBoard: thread.board,
						withThreadId: thread.id,
						activate: activate,
						incognito: incognito
					)
				),
				child: SearchPage(
					key: _tabs._searchPageKey
				)
			);
		}
		else {
			if (devImageboard?.threadWatcher == null) {
				child = const Center(
					child: CircularProgressIndicator.adaptive()
				);
			}
			else {
				child = Actions(
					actions: {
						ExtendSelectionToLineBreakIntent: CallbackAction<ExtendSelectionToLineBreakIntent>(
							onInvoke: (intent) {
								if ((FocusManager.instance.primaryFocus?.rect.height ?? 0) < (MediaQuery.sizeOf(context).height * 0.75)) {
									// Likely a text field is focused
									return;
								}
								_tabs._settingsNavigatorKey.currentState?.maybePop();
								return null;
							}
						)
					},
					child: Provider.value(
						value: OpenInNewTabZone(
							onWantOpenThreadInNewTab: (imageboardKey, thread, {bool incognito = false, bool activate = true}) => _tabs.addNewTab(
								withImageboardKey: imageboardKey,
								withBoard: thread.board,
								withThreadId: thread.id,
								activate: activate,
								incognito: incognito
							)
						),
						child: ImageboardScope(
							imageboardKey: devImageboard?.key,
							child: ChangeNotifierProvider.value(
								value: devTab,
								child: ClipRect(
									child: PrimaryScrollControllerInjectingNavigator(
										navigatorKey: _tabs._settingsNavigatorKey,
										observers: [
											HeroController(),
											ScrollTrackerNavigatorObserver()
										],
										buildRoot: (context) => const SettingsPage()
									)
								)
							)
						)
					)
				);
			}
		}
		child = Provider.value(
			value: _willPopZones.putIfAbsent(index, () => WillPopZone()),
			child: KeyedSubtree(
				key: _keys.putIfAbsent(index, () => GlobalKey(debugLabel: '_keys[$index]')),
				child: child
			)
		);
		return active ? child : PrimaryScrollController.none(child: child);
	}

	Widget _buildTabletIcon(int index, Widget icon, String? label, {
		Axis axis = Axis.vertical,
		Widget? preLabelInjection
	}) {
		final content = AnimatedBuilder(
			animation: _tabs._tabController,
			builder: (context, _) => Opacity(
				opacity: (index <= 0 ? (_tabs.mainTabIndex == 0 && index == -1 * _tabs.activeBrowserTab.value) : index == _tabs.mainTabIndex) ? 1.0 : 0.5,
				child: Column(
					mainAxisAlignment: MainAxisAlignment.center,
					children: [
						icon,
						if (label != null) ...[
							const SizedBox(height: 4),
							FittedBox(
								fit: BoxFit.contain,
								child: Row(
									mainAxisSize: MainAxisSize.min,
									mainAxisAlignment: MainAxisAlignment.center,
									children: [
										if (preLabelInjection != null) ...[
											preLabelInjection,
											const SizedBox(width: 4)
										],
										Text(label, style: const TextStyle(fontSize: 15))
									]
								)
							)
						]
					]
				)
			)
		);
		return Builder(
			builder: (context) {
				void showThisTabMenu() {
					final ro = context.findRenderObject()! as RenderBox;
					showTabMenu(
						context: context,
						direction: axis == Axis.horizontal ? AxisDirection.up : AxisDirection.right,
						titles: Axis.vertical,
						origin: Rect.fromPoints(
							ro.localToGlobal(ro.semanticBounds.topLeft),
							ro.localToGlobal(ro.semanticBounds.bottomRight)
						),
						actions: [
							if (!Settings.instance.usingHomeBoard || index < 0) TabMenuAction(
								icon: CupertinoIcons.xmark,
								title: 'Close',
								isDestructiveAction: true,
								onPressed: Persistence.tabs.length == 1 ? null : () {
									final previouslyActiveTab = _tabs.browseTabIndex;
									final closedTab = Persistence.tabs[-1 * index];
									_tabs.closeBrowseTab(-1 * index);
									if (closedTab.board != null) {
										showUndoToast(
											context: context,
											message: 'Closed tab',
											onUndo: () {
												_tabs.insertInitializedTab(-1 * index, closedTab);
												_tabs.browseTabIndex = previouslyActiveTab;
											},
											padding: const EdgeInsets.only(bottom: 50)
										);
									}
								}
							),
							TabMenuAction(
								icon: CupertinoIcons.doc_on_doc,
								title: 'Clone',
								onPressed: () {
									final i = -1 * index;
									_tabs.addNewTab(
										withImageboardKey: Persistence.tabs[i].imageboardKey,
										atPosition: i + 1,
										withBoard: Persistence.tabs[i].board,
										withThread: Persistence.tabs[i].thread,
										incognito: Persistence.tabs[i].incognito,
										withInitialSearch: Persistence.tabs[i].initialSearch,
										activate: true
									);
								}
							)
						]
					);
				}
				return RawGestureDetector(
					gestures: {
						WeakVerticalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<WeakVerticalDragGestureRecognizer>(
							() => WeakVerticalDragGestureRecognizer(weakness: 2, sign: -1),
							(recognizer) {
								recognizer.onEnd = (details) {
									lightHapticFeedback();
									showThisTabMenu();
								};
							}
						)
					},
					child: AdaptiveButton(
						padding: axis == Axis.vertical ? const EdgeInsets.only(top: 16, bottom: 16, left: 8, right: 8) : const EdgeInsets.only(top: 8, bottom: 8, left: 16, right: 16),
						child: content,
						onPressed: () async {
							lightHapticFeedback();
							if (index <= 0) {
								if (_tabs.browseTabIndex == -1 * index && _tabs.mainTabIndex == 0) {
									showThisTabMenu();
								}
								else {
									_tabs.browseTabIndex = -1 * index;
									if (Persistence.settings.closeTabSwitcherAfterUse) {
										setState(() {
											showTabPopup = false;
										});
									}
								}
							}
							else if (index == _tabs._lastIndex) {
								if (index == 4) {
									_tabs._settingsNavigatorKey.currentState?.maybePop();
								}
								else {
									_willPopZones[index]?.maybePop?.call();
								}
							} else if (index == 2) {
								await _tabs._historyPageKey.currentState?.updateList();
							}
							_tabs.mainTabIndex = max(0, index);
						}
					)
				);
			}
		);
	}

	Widget _buildNewTabIcon({required Axis axis, bool hideLabel = false}) {
		return Builder(
			builder: (context) {
				return GestureDetector(
					onVerticalDragEnd: (details) {
						final velocity = details.primaryVelocity ?? 0;
						if (velocity < 0) {
							_tabs.showNewTabPopup(
								context: context,
								direction: axis == Axis.horizontal ? AxisDirection.up : AxisDirection.right,
								titles: Axis.vertical,
							);
						}
					},
					onLongPress: () => _tabs.showNewTabPopup(
						context: context,
						direction: axis == Axis.horizontal ? AxisDirection.up : AxisDirection.right,
						titles: Axis.vertical,
					),
					child: AdaptiveButton(
						padding: const EdgeInsets.all(16),
						child: Opacity(
							opacity: 0.5,
							child: FittedBox(
								child: Column(
									mainAxisSize: MainAxisSize.min,
									children: [
										const Icon(CupertinoIcons.add),
										if (!hideLabel) ...[
											const SizedBox(height: 4),
											const Text("New", style: TextStyle(fontSize: 15))
										]
									]
								)
							)
						),
						onPressed: () {
							lightHapticFeedback();
							_tabs.addNewTab(activate: true);
						}
					)
				);
			}
		);
	}

	Widget _buildTabList(Axis axis) {
		final usingHomeBoard = Settings.instance.usingHomeBoard;
		buildTabIcon(int i) => TabWidgetBuilder(
			tab: Persistence.tabs[i],
			builder: (context, data) => DecoratedBox(
				decoration: BoxDecoration(
					color: usingHomeBoard && i == 0 ?
						ChanceTheme.primaryColorWithBrightness30Of(context) :
						(data.isArchived ? ChanceTheme.primaryColorWithBrightness10Of(context) : null),
				),
				child: _buildTabletIcon(
					i * -1,
					StationaryNotifyingIcon(
						icon: data.primaryIcon,
						primary: data.unseenYouCount,
						secondary: data.unseenCount
					),
					data.shortTitle,
					axis: axis,
					preLabelInjection: data.secondaryIcon
				)
			)
		);
		return Flex(
			direction: axis,
			children: [
				if (usingHomeBoard) buildTabIcon(0),
				Expanded(
					child: ReorderableList(
						controller: _tabs._tabListController,
						// Take the performance hit, ensure everything is laid out for _animateTabList to work
						cacheExtent: 9000,
						scrollDirection: axis,
						onReorder: _tabs.onReorder,
						itemCount: usingHomeBoard ? Persistence.tabs.length - 1 : Persistence.tabs.length,
						itemBuilder: (context, index) {
							final i = usingHomeBoard ? index + 1 : index;
							return ReorderableDelayedDragStartListener(
								index: i,
								key: _tabs._tabButtonKeys.putIfAbsent(i, () => GlobalKey(debugLabel: '_tabs._tabButtonKeys[$i]')),
								child: buildTabIcon(i)
							);
						}
					)
				)
			]
		);
	}

	Future<bool> confirmExit() async {
		return (await showAdaptiveDialog<bool>(
			context: context,
			barrierDismissible: true,
			builder: (context) => AdaptiveAlertDialog(
				title: const Text('Exit the app?'),
				actions: [
					AdaptiveDialogAction(
						isDestructiveAction: true,
						onPressed: () {
							Navigator.of(context).pop(true);
						},
						child: const Text('Exit')
					),
					AdaptiveDialogAction(
						child: const Text('Cancel'),
						onPressed: () {
							Navigator.of(context).pop(false);
						}
					)
				]
			)
		) ?? false);
	}

	void _toggleHistory() {
		mediumHapticFeedback();
		Settings.recordThreadsInHistorySetting.value = !Settings.instance.recordThreadsInHistory;
		showToast(
			context: context,
			message: Settings.instance.recordThreadsInHistory ? 'History resumed' : 'History stopped',
			icon: Settings.instance.recordThreadsInHistory ? CupertinoIcons.play : CupertinoIcons.stop
		);
	}

	Future<void> _backButton() async {
		final navigator = Navigator.of(context);
		if (_drawerScaffoldKey.currentState?.isDrawerOpen ?? false) {
			_drawerScaffoldKey.currentState?.closeDrawer();
			// Closed the side drawer
		}
		else if (_tabs.mainTabIndex == 4 && (await _tabs._settingsNavigatorKey.currentState?.maybePop() ?? false)) {
			// Popped something in Settings page
		}
		else if (await _willPopZones[_tabs.mainTabIndex]?.maybePop?.call() ?? false) {
			// Popped something generically
		}
		else if (await _tabs._tabNavigatorKeys[_tabs.mainTabIndex]?.currentState?.maybePop() ?? false) {
			// Popped something on the CupertinoTabView (this shouldn't happen)
		}
		else if (_tabs.mainTabIndex != 0) {
			_tabs.mainTabIndex = 0;
			// Returned to the browse pane
		}
		else if (await confirmExit()) {
			navigator.pop();
			// Exited the app
		}
	}

	bool get isScreenWide => (MediaQuery.sizeOf(context).width - 85) > (MediaQuery.sizeOf(context).height - 50);

	bool get _androidDrawer => Settings.instance.androidDrawer;
	bool get androidDrawer => Settings.androidDrawerSetting.watch(context);

	Rect? get hingeBounds => MediaQuery.displayFeaturesOf(context).tryFirstWhere((f) => f.type == DisplayFeatureType.hinge && f.bounds.left > 0 /* Only when hinge is vertical */)?.bounds;

	bool get persistentDrawer {
		return androidDrawer && Settings.persistentDrawerSetting.watch(context) && (hingeBounds != null || MediaQuery.sizeOf(context).width > 650);
	}

	double get persistentDrawerWidth {
		return hingeBounds?.left ?? 304;
	}

	@override
	Widget build(BuildContext context) {
		final hideTabletLayoutLabels = MediaQuery.sizeOf(context).height < 600;
		if (!ImageboardRegistry.instance.initialized || _authenticationStatus == _AuthenticationStatus.inProgress) {
			return const ChanSplashPage();
		}
		if (_authenticationStatus == _AuthenticationStatus.failed) {
			return Container(
				width: double.infinity,
				height: double.infinity,
				alignment: Alignment.center,
				color: ChanceTheme.backgroundColorOf(context),
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						const Icon(CupertinoIcons.lock, size: 50),
						const SizedBox(height: 16),
						const Text('Authentication failed', style: TextStyle(fontSize: 20)),
						const SizedBox(height: 16),
						AdaptiveFilledButton(
							onPressed: _authenticate,
							child: const Text('Retry')
						)
					]
				)
			);
		}
		for (final board in ImageboardRegistry.instance.imageboards) {
			if (_notificationsSubscriptions[board.key]?.notifications != board.notifications) {
				_notificationsSubscriptions[board.key]?.subscription.cancel();
				_notificationsSubscriptions[board.key] = (notifications: board.notifications, subscription: board.notifications.tapStream.listen((target) {
					_onNotificationTapped(board, target.boardThreadOrPostId);
				}));
			}
		}
		final dev = devImageboard;
		if (dev != null && _devNotificationsSubscription?.notifications != dev.notifications) {
			_devNotificationsSubscription?.subscription.cancel();
			_devNotificationsSubscription = (notifications: dev.notifications, subscription: dev.notifications.tapStream.listen((target) {
				_onDevNotificationTapped(target.boardThreadOrPostId);
			}));
		}
		final filterError = context.select<Settings, String?>((s) => s.filterError);
		Widget child = (androidDrawer || isScreenWide) ? NotificationListener2<ScrollNotification, ScrollMetricsNotification>(
			onNotification: ScrollTracker.instance.onNotification,
			child: Actions(
				actions: {
					ExtendSelectionToLineBreakIntent: CallbackAction<ExtendSelectionToLineBreakIntent>(
						onInvoke: (intent) {
							if ((FocusManager.instance.primaryFocus?.rect.height ?? 0) < (MediaQuery.sizeOf(context).height * 0.75)) {
								// Likely a text field is focused
								return;
							}
							_willPopZones[_tabs.mainTabIndex]?.maybePop?.call();
							return null;
						}
					)
				},
				child: DescendantNavigatorPopScope(
					canPop: () => false, // confirmExit always blocks
					onPopInvoked: (didPop) {
						if (didPop) {
							return;
						}
						_backButton();
					},
					child: AdaptiveScaffold(
						key: _drawerScaffoldKey,
						drawer: (androidDrawer && !persistentDrawer) ? const ChanceDrawer(persistent: false) : null,
						body: SafeArea(
							top: false,
							bottom: false,
							child: Row(
								children: [
									if (!androidDrawer || persistentDrawer) Container(
										color: ChanceTheme.barColorOf(context),
										width: persistentDrawer ? persistentDrawerWidth : 85,
										child: persistentDrawer ? const ChanceDrawer(
											persistent: true
										) : Column(
											children: [
												SizedBox(height: MediaQuery.paddingOf(context).top),
												Expanded(
													child: AnimatedBuilder(
														animation: _tabs.activeBrowserTab,
														builder: (context, _) => _buildTabList(Axis.vertical)
													)
												),
												_buildNewTabIcon(
													axis: Axis.vertical,
													hideLabel: hideTabletLayoutLabels
												),
												_buildTabletIcon(1, NotifyingIcon(
														icon: Icon(Adaptive.icons.bookmark),
														primaryCount: CombiningValueListenable<int>(
															children: ImageboardRegistry.instance.imageboards.map((x) => x.threadWatcher.unseenYouCount).toList(),
															combine: (list) => list.fold(0, (a, b) => a + b)
														),
														secondaryCount: CombiningValueListenable<int>(
															children: ImageboardRegistry.instance.imageboards.map((x) => x.threadWatcher.unseenCount).toList(),
															combine: (list) => list.fold(0, (a, b) => a + b)
														)
													), hideTabletLayoutLabels ? null : 'Saved',
												),
												GestureDetector(
													onLongPress: _toggleHistory,
													child: _buildTabletIcon(2, Settings.recordThreadsInHistorySetting.watch(context) ? const Icon(CupertinoIcons.archivebox) : const Icon(CupertinoIcons.eye_slash), hideTabletLayoutLabels ? null : 'History')
												),
												_buildTabletIcon(3, const Icon(CupertinoIcons.search), hideTabletLayoutLabels ? null : 'Search'),
												GestureDetector(
													onLongPress: () => Settings.instance.runQuickAction(context),
													child: _buildTabletIcon(4, NotifyingIcon(
															icon: Icon(CupertinoIcons.settings, color: filterError != null ? Colors.red : null),
															primaryCount: devImageboard?.threadWatcher.unseenYouCount ?? zeroValueNotifier,
															secondaryCount: devImageboard?.threadWatcher.unseenCount ?? zeroValueNotifier
														), hideTabletLayoutLabels ? null : 'Settings'
													)
												),
												SizedBox(height: MediaQuery.paddingOf(context).bottom)
											]
										)
									),
									if (persistentDrawer) VerticalDivider(
										width: 0,
										thickness: 0,
										color: ChanceTheme.primaryColorWithBrightness20Of(context)
									),
									Expanded(
										child: AnimatedBuilder(
											animation: _tabs._tabController,
											builder: (context, _) => TabSwitchingView(
												currentTabIndex: _tabs.mainTabIndex,
												tabCount: 5,
												tabBuilder: (context, i) => _buildTab(context, i, i == _tabs.mainTabIndex)
											)
										)
									)
								]
							)
						)
					)
				)
			)
		) : NotificationListener2<ScrollNotification, ScrollMetricsNotification>(
			onNotification: ScrollTracker.instance.onNotification,
			child: Actions(
				actions: {
					ExtendSelectionToLineBreakIntent: CallbackAction<ExtendSelectionToLineBreakIntent>(
						onInvoke: (intent) {
							if ((FocusManager.instance.primaryFocus?.rect.height ?? 0) < (MediaQuery.sizeOf(context).height * 0.75)) {
								// Likely a text field is focused
								return;
							}
							_backButton();
							return null;
						}
					)
				},
				child: DescendantNavigatorPopScope(
					canPop: () => false, // confirmExit always blocks
					onPopInvoked: (didPop) {
						if (didPop) {
							return;
						}
						_backButton();
					},
					child: CupertinoTabScaffold(
						controller: _tabs._tabController,
						tabBar: ChanceCupertinoTabBar(
							visible: !androidDrawer,
							height: androidDrawer ? 0 : 50,
							inactiveColor: ChanceTheme.primaryColorOf(context).withOpacity(0.4),
							items: [
								BottomNavigationBarItem(
									icon: AnimatedBuilder(
										animation: _tabs.browseCountListenable,
										builder: (context, child) => StationaryNotifyingIcon(
											icon: const Icon(CupertinoIcons.rectangle_stack, size: 28),
											primary: 0,
											secondary: (Persistence.tabs.length == 1) ? 0 : Persistence.tabs.asMap().entries.where((x) => x.key != _tabs.browseTabIndex || _tabs.mainTabIndex > 0).map((x) => x.value.unseen.value).reduce((a, b) => a + b)
										)
									),
									label: 'Browse'
								),
								BottomNavigationBarItem(
									icon: Builder(
										builder: (context) => NotifyingIcon(
											icon: Icon(Adaptive.icons.bookmark, size: 28),
											primaryCount: CombiningValueListenable<int>(
												children: ImageboardRegistry.instance.imageboards.map((x) => x.threadWatcher.unseenYouCount).toList(),
												combine: (list) => list.fold(0, (a, b) => a + b)
											),
											secondaryCount: CombiningValueListenable<int>(
												children: ImageboardRegistry.instance.imageboards.map((x) => x.threadWatcher.unseenCount).toList(),
												combine: (list) => list.fold(0, (a, b) => a + b)
											)
										)
									),
									label: 'Saved'
								),
								BottomNavigationBarItem(
									icon: GestureDetector(
										onLongPress: _toggleHistory,
										child: Settings.recordThreadsInHistorySetting.watch(context) ? const Icon(CupertinoIcons.archivebox, size: 28) : const Icon(CupertinoIcons.eye_slash, size: 28)
									),
									label: 'History'
								),
								const BottomNavigationBarItem(
									icon: Icon(CupertinoIcons.search, size: 28),
									label: 'Search'
								),
								BottomNavigationBarItem(
									icon: GestureDetector(
										onLongPress: () => Settings.instance.runQuickAction(context),
										child: NotifyingIcon(
											icon: Icon(CupertinoIcons.settings, size: 28, color: filterError != null ? Colors.red : null),
											primaryCount: devImageboard?.threadWatcher.unseenYouCount ?? zeroValueNotifier,
											secondaryCount: devImageboard?.threadWatcher.unseenCount ?? zeroValueNotifier
										)
									),
									label: 'Settings'
								)
							],
							onUpSwipe: () {
								if (showTabPopup || _tabs.mainTabIndex != 0) {
									return;
								}
								mediumHapticFeedback();
								setState(() {
									showTabPopup = true;
								});
							},
							onDownSwipe: () {
								if (!showTabPopup || _tabs.mainTabIndex != 0) {
									return;
								}
								mediumHapticFeedback();
								setState(() {
									showTabPopup = false;
								});
							},
							onLeftSwipe: () {
								mediumHapticFeedback();
								if (_tabs.mainTabIndex > 0) {
									_tabs.mainTabIndex--;
								}
								else if (_tabs.browseTabIndex > 0) {
									_tabs.browseTabIndex--;
								}
								else {
									// Not possible, do a second haptic for feedback
									Future.delayed(const Duration(milliseconds: 100), mediumHapticFeedback);
								}
							},
							onRightSwipe: () {
								mediumHapticFeedback();
								if (_tabs.mainTabIndex > 0 && _tabs.mainTabIndex < 4) {
									_tabs.mainTabIndex++;
								}
								else if (_tabs.mainTabIndex == 0 && _tabs.browseTabIndex < Persistence.tabs.length - 1) {
									_tabs.browseTabIndex++;
								}
								else {
									// Not possible, do a second haptic for feedback
									Future.delayed(const Duration(milliseconds: 100), mediumHapticFeedback);
								}
							},
							beforeCopiedOnTap: (index) async {
								if (index == 2) {
									await _tabs._historyPageKey.currentState?.updateList();
								}
							},
							onTap: (index) {
								lightHapticFeedback();
								if (index == _tabs._lastIndex && index == 0) {
									setState(() {
										showTabPopup = !showTabPopup;
									});
								}
								else if (index == _tabs._lastIndex) {
									if (index == 4) {
										_tabs._settingsNavigatorKey.currentState?.maybePop();
									}
									else {
										_willPopZones[index]?.maybePop?.call();
									}
								}
								else if (showTabPopup) {
									setState(() {
										_hideTabPopupAutomatically = true;
										showTabPopup = false;
									});
								}
								_tabs._lastIndex = index;
							}
						),
						tabBuilder: (context, index) => Stack(
							children: [
								Column(
									children: [
										Expanded(
											child: CupertinoTabView(
												navigatorKey: _tabs._tabNavigatorKeys.putIfAbsent(index, () => GlobalKey<NavigatorState>(debugLabel: '_ChanHomePageState._tabNavigatorKeys[$index]')),
												navigatorObservers: [
													ScrollTrackerNavigatorObserver()
												],
												builder: (context) {
													final child = AnimatedBuilder(
														animation: _tabs._tabController,
														builder: (context, child) => _buildTab(context, index, _tabs.mainTabIndex == index)
													);
													if (Settings.materialStyleSetting.watch(context)) {
														return Material(
															child: child
														);
													}
													return child;
												}
											)
										),
										if (index == 0) Expander(
											height: 80,
											bottomSafe: true,
											expanded: showTabPopup,
											duration: const Duration(milliseconds: 200),
											curve: Curves.ease,
											child: const SizedBox.shrink()
										)
									]
								),
								if (index == 0) Column(
									mainAxisAlignment: MainAxisAlignment.end,
									children: [
										Expander(
											height: 80,
											bottomSafe: false,
											expanded: showTabPopup,
											duration: const Duration(milliseconds: 200),
											curve: Curves.ease,
											child: RawGestureDetector(
												behavior: HitTestBehavior.translucent,
												gestures: {
													WeakVerticalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<WeakVerticalDragGestureRecognizer>(
														() => WeakVerticalDragGestureRecognizer(weakness: 1, sign: 1),
														(recognizer) {
															recognizer.onEnd = (details) {
																if (details.velocity.pixelsPerSecond.dy > 0 && showTabPopup) {
																	mediumHapticFeedback();
																	setState(() {
																		showTabPopup = false;
																	});
																}
															};
														}
													)
												},
												child: Container(
													color: ChanceTheme.barColorOf(context),
													child: Row(
														children: [
															Expanded(
																child: AnimatedBuilder(
																	animation: _tabs.activeBrowserTab,
																	builder: (context, _) => _buildTabList(Axis.horizontal)
																)
															),
															_buildNewTabIcon(axis: Axis.horizontal)
														]
													)
												)
											)
										)
									]
								)
							]
						)
					)
				)
			)
		);
		child = NotificationsOverlay(
			onePane: !isScreenWide,
			key: notificationsOverlayKey,
			imageboards: [
				...ImageboardRegistry.instance.imageboards,
				if (devImageboard?.notifications != null) devImageboard!
			],
			child: child
		);
		if (isOnMac) {
			child = NativeDropView(
				loading: (_) {

				},
				dataReceived: (data) async {
					final List<String> paths = [];
					for (final datum in data) {
						if (datum.dropFile != null) {
							if (datum.dropFile!.path.startsWith(Persistence.documentsDirectory.path)) {
								// The file has been placed in our Documents dir, this isn't appropriate for temporary storage
								paths.add((await datum.dropFile!.rename('${Persistence.temporaryDirectory.path}/${datum.dropFile!.path.split('/').last}')).path);
							}
							else {
								paths.add(datum.dropFile!.path);
							}
						}
						else if (datum.dropText != null) {
							_consumeLink(datum.dropText);
						}
					}
					if (paths.isNotEmpty) {
						_consumeFiles(paths);
					}
				},
				allowedDropDataTypes: const [DropDataType.url, DropDataType.image, DropDataType.video],
				receiveNonAllowedItems: false,
				child: child
			);
		}
		child = ChangeNotifierProvider.value(
			value: _tabs,
			child: child
		);
		return child;
	}

	@override
	void dispose() {
		super.dispose();
		_tabs.removeListener(_tabsListener);
		_tabs.dispose();
		devImageboard?.dispose();
		_linkSubscription.cancel();
		_fakeLinkSubscription.cancel();
		_sharedFilesSubscription.cancel();
		_sharedTextSubscription.cancel();
		_devNotificationsSubscription?.subscription.cancel();
		ScrollTracker.instance.slowScrollDirection.removeListener(_onSlowScrollDirectionChange);
		for (final subscription in _notificationsSubscriptions.values) {
			subscription.subscription.cancel();
		}
	}
}

class ChanceCupertinoTabBar extends CupertinoTabBar {
	final bool visible;
	final VoidCallback onLeftSwipe;
	final VoidCallback onRightSwipe;
	final VoidCallback onUpSwipe;
	final VoidCallback onDownSwipe;
	final FutureOr Function(int index)? beforeCopiedOnTap;

  const ChanceCupertinoTabBar({
		required super.items,
		required this.onLeftSwipe,
		required this.onRightSwipe,
		required this.onUpSwipe,
		required this.onDownSwipe,
		required this.beforeCopiedOnTap,
		this.visible = true,
		super.backgroundColor,
		super.activeColor,
		super.inactiveColor,
		super.iconSize,
		super.height,
		super.border,
		super.currentIndex,
		super.onTap,
		super.key
	});

	@override
	CupertinoTabBar copyWith({
    Key? key,
    List<BottomNavigationBarItem>? items,
    Color? backgroundColor,
    Color? activeColor,
    Color? inactiveColor,
    double? iconSize,
    double? height,
    Border? border,
    int? currentIndex,
    ValueChanged<int>? onTap,
  }) {
    return ChanceCupertinoTabBar(
			onLeftSwipe: onLeftSwipe,
			onRightSwipe: onRightSwipe,
			onUpSwipe: onUpSwipe,
			onDownSwipe: onDownSwipe,
			beforeCopiedOnTap: beforeCopiedOnTap,
      key: key ?? this.key,
			visible: visible,
      items: items ?? this.items,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      activeColor: activeColor ?? this.activeColor,
      inactiveColor: inactiveColor ?? this.inactiveColor,
      iconSize: iconSize ?? this.iconSize,
      height: height ?? this.height,
      border: border ?? this.border,
      currentIndex: currentIndex ?? this.currentIndex,
      onTap: (index) async {
					await beforeCopiedOnTap?.call(index);
					(onTap ?? this.onTap)?.call(index);
			},
    );
  }

	static bool _skipNextSwipe = false;

	@override
	Widget build(BuildContext context) {
		if (!visible) {
			return const SizedBox.shrink();
		}
		return GestureDetector(
			behavior: HitTestBehavior.translucent,
			onPanStart: (details) {
				_skipNextSwipe = eventTooCloseToEdge(details.globalPosition);
			},
			onPanEnd: (details) {
				if (_skipNextSwipe || !Settings.instance.swipeGesturesOnBottomBar) {
					return;
				}
				if ((-1 * details.velocity.pixelsPerSecond.dy) > details.velocity.pixelsPerSecond.dx.abs()) {
					onUpSwipe();
				}
				else if (details.velocity.pixelsPerSecond.dy > details.velocity.pixelsPerSecond.dx.abs()) {
					onDownSwipe();
				}
				else if (details.velocity.pixelsPerSecond.dx > 0) {
					onLeftSwipe();
				}
				else if (details.velocity.pixelsPerSecond.dx < 0) {
					onRightSwipe();
				}
			},
			child: Settings.hideBarsWhenScrollingDownSetting.watch(context) ? AncestorScrollBuilder(
				builder: (context, direction, _) => AnimatedOpacity(
					opacity: direction == VerticalDirection.up ? 1.0 : 0.0,
					duration: const Duration(milliseconds: 350),
					curve: Curves.ease,
					child: IgnorePointer(
						ignoring: direction == VerticalDirection.down,
						child: super.build(context)
					)
				)
			) : super.build(context)
		);
	}

	@override
	bool opaque(BuildContext context) {
		       // No hiding OR
		return !Settings.hideBarsWhenScrollingDownSetting.watch(context) ||
		       // Hack - If we always return false, we will get a ClipRect in super.build
		       context.widget is! CupertinoTabScaffold;
	}
}
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:chan/firebase_options.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/search.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/board.dart';
import 'package:chan/pages/history.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/search.dart';
import 'package:chan/pages/settings.dart';
import 'package:chan/pages/saved.dart';
import 'package:chan/pages/tabs.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/android.dart';
import 'package:chan/services/apple.dart';
import 'package:chan/services/bad_certificate.dart';
import 'package:chan/services/default_user_agent.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/global_pointer_tracker.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/installed_fonts.dart';
import 'package:chan/services/json_cache.dart';
import 'package:chan/services/media.dart';
import 'package:chan/services/network_image_provider.dart';
import 'package:chan/services/network_logging.dart';
import 'package:chan/services/notifications.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/pick_attachment.dart';
import 'package:chan/services/report_bug.dart';
import 'package:chan/services/rlimit.dart';
import 'package:chan/services/screen_size_hacks.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/share.dart';
import 'package:chan/services/storage.dart';
import 'package:chan/services/streaming_mp4.dart';
import 'package:chan/services/taskgraph.dart';
import 'package:chan/services/taskstack.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/services/tls.dart';
import 'package:chan/services/translation.dart';
import 'package:chan/services/util.dart';
import 'package:chan/util.dart';
import 'package:chan/version.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/floating_tab_controls.dart';
import 'package:chan/widgets/drawer.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/injecting_navigator.dart';
import 'package:chan/widgets/notifications_overlay.dart';
import 'package:chan/widgets/notifying_icon.dart';
import 'package:chan/widgets/paginated_reorderable_list.dart';
import 'package:chan/widgets/saved_theme_thumbnail.dart';
import 'package:chan/widgets/sidebar_tab_label.dart';
import 'package:chan/widgets/scroll_tracker.dart';
import 'package:chan/widgets/tab_menu.dart';
import 'package:chan/widgets/switching_view.dart';
import 'package:chan/widgets/thread_widget_builder.dart';
import 'package:chan/widgets/util.dart';
import 'package:chan/widgets/weak_gesture_recognizer.dart';
import 'package:dio/dio.dart';
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
import 'package:chan/pages/tab.dart';
import 'package:provider/provider.dart';
import 'package:chan/widgets/sticky_media_query.dart';
import 'package:share_handler/share_handler.dart';

final fakeLinkStream = StreamController<String?>.broadcast();
bool _initialConsume = false;
final zeroValueNotifier = ValueNotifier(0);
bool _promptedAboutCrashlytics = false;
bool developerMode = false;

Future<void> innerMain() async {
	try {
		final start = DateTime.now();
		initializeRLimit();
		WidgetsFlutterBinding.ensureInitialized();
		GlobalPointerTracker.instance.initialize();
		final initializeIsDevelopmentBuildTask = Task('initializeIsDevelopmentBuildTask', initializeIsDevelopmentBuild);
		final initializeIsOnMacTask = Task('initializeIsOnMac', initializeIsOnMac);
		final initializeAppleChannelTask = Task('initializeAppleChannel', initializeAppleChannel);
		final initializeAndroidTask = Task('initializeAndroid', initializeAndroid);
		final imageHttpClient = (ExtendedNetworkImageProvider.httpClient as HttpClient);
		imageHttpClient.connectionTimeout = const Duration(seconds: 10);
		imageHttpClient.idleTimeout = const Duration(seconds: 10);
		imageHttpClient.maxConnectionsPerHost = 10;
		imageHttpClient.badCertificateCallback = badCertificateCallback;
		final firebaseTask = Task('firebase', () async {
			if (Platform.isAndroid || Platform.isIOS) {
				await Firebase.initializeApp(
					options: DefaultFirebaseOptions.currentPlatform
				);
				FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
			}
		});
		final hiveTask = Task('hive', Persistence.initializeHive);
		final directoriesTask = Task('directories', Persistence.initializeDirectories);
		final persistenceTask = Task('persistence', Persistence.initializeStatic, [hiveTask, directoriesTask, firebaseTask]);
		final resetAdditionalSafeAreaInsetsTask = Task('resetAdditionalSafeAreaInsets', resetAdditionalSafeAreaInsets);
		final configureDuoLayoutTask = Task('configureDuoLayout', () => configureDuoLayout(
			barWidth: 85 * Persistence.settings.interfaceScale
		), [
			persistenceTask,
			initializeAppleChannelTask,
			if (kDebugMode) resetAdditionalSafeAreaInsetsTask
		]);
		final initializeDefaultUserAgentTask = Task('initializeDefaultUserAgent', initializeDefaultUserAgent, [persistenceTask]);
		final tlsTask = Task('tls', initializeTls, [initializeDefaultUserAgentTask, persistenceTask]);
		final networkLoggingTask = Task('networkLogging', LoggingInterceptor.instance.initialize, [directoriesTask]);
		final videoServerTask = Task('videoServer', () async {
			VideoServer.initializeStatic(Persistence.webmCacheDirectory, Persistence.httpCacheDirectory);
		}, [directoriesTask]);
		final notificationsTask = Task('notifications', Notifications.initializeStatic, [persistenceTask, networkLoggingTask, tlsTask, firebaseTask]);
		final updateDynamicColorsTask = Task('updateDynamicColors', updateDynamicColors, [persistenceTask]);
		final initializeFontsTask = Task('initializeFonts', initializeFonts, [persistenceTask]);
		final initializeNativeTranslationTask = Task('initializeNativeTranslation', initializeNativeTranslation);
		final mediaKitTask = Task('mediaKit', MediaKit.ensureInitialized);
		final jsonCacheTask = Task('jsonCache', JsonCache.instance.initialize, [
			networkLoggingTask,
			tlsTask,
			initializeIsDevelopmentBuildTask,
			initializeDefaultUserAgentTask,
			// Depends on Settings.instance
			persistenceTask
		]);
		final mediaScanTask = Task('mediaScan', MediaScan.initializeStatic, [hiveTask]);
		await executeTaskGraph([
			initializeIsDevelopmentBuildTask,
			initializeIsOnMacTask,
			initializeAppleChannelTask,
			configureDuoLayoutTask,
			initializeAndroidTask,
			initializeDefaultUserAgentTask,
			hiveTask,
			persistenceTask,
			networkLoggingTask,
			videoServerTask,
			notificationsTask,
			updateDynamicColorsTask,
			initializeFontsTask,
			initializeNativeTranslationTask,
			mediaKitTask,
			jsonCacheTask,
			mediaScanTask,
			tlsTask,
			if (kDebugMode)
				resetAdditionalSafeAreaInsetsTask
		]);
		print('before runApp: ${DateTime.now().difference(start)}');
		runApp(const ChanApp());
	}
	catch (e, st) {
		runApp(ChanFailedApp(e, st));
	}
}

void main() async {
	if ((Platform.isAndroid || Platform.isIOS) && !developerMode) {
		runZonedGuarded<Future<void>>(
			innerMain,
			(error, stack) => FirebaseCrashlytics.instance.recordError(
				error, stack,
				information: [
					if (error is ExtendedException) error.additionalFiles.entries.map((entry) => '${entry.key}: ${base64.encode(entry.value)}')
				],
				fatal: true
			)
		);
	}
	else {
		await innerMain();
	}
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
		SchedulerBinding.instance.addPostFrameCallback((_) async {
			await precacheImage(ChanSplashPage._kImage, context);
			await SchedulerBinding.instance.endOfFrame;
			await SchedulerBinding.instance.endOfFrame;
			ImageboardRegistry.instance.initializeDev();
			ImageboardRegistry.instance.handleSites(
				// ignore: use_build_context_synchronously
				context: context,
				sites: _lastSites,
				keys: _lastSiteKeys
			).then(_precacheIcons);
		});
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
			).then(_precacheIcons);
		}
	}

	void _onSettingsUpdate() {
		if (!setEquals(Settings.instance.settings.contentSettings.siteKeys, _lastSiteKeys)) {
			_lastSiteKeys = Set.from(Settings.instance.settings.contentSettings.siteKeys);
			ImageboardRegistry.instance.handleSites(
				context: context,
				sites: _lastSites,
				keys: _lastSiteKeys
			).then(_precacheIcons);
		}
	}

	/// Try to get instant icons in the board switcher
	void _precacheIcons(void _) {
		for (final imageboard in ImageboardRegistry.instance.imageboards) {
			for (final url in [
				imageboard.site.iconUrl,
				...imageboard.persistence.browserState.favouriteBoards
					.tryMap((b) => imageboard.persistence.maybeGetBoard(b.s)?.icon)
			]) {
				if (url != null) {
					precacheImage(CNetworkImageProvider(url.toString(), cache: true, client: imageboard.site.client), context, onError: (e, st) {
						// Do nothing
					});
				}
			}
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
						showToast(
							context: ImageboardRegistry.instance.context!,
							icon: CupertinoIcons.zoom_in,
							message: 'Zoom: ${(Settings.instance.interfaceScale * 100).round()}%'
						);
					}
				},
				LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.minus): () {
					if (Settings.instance.interfaceScale > 0.5) {
						Settings.interfaceScaleSetting.value -= 0.05;
						showToast(
							context: ImageboardRegistry.instance.context!,
							icon: CupertinoIcons.zoom_out,
							message: 'Zoom: ${(Settings.instance.interfaceScale * 100).round()}%'
						);
					}
				}
			},
			child: MultiProvider(
				providers: [
					ValueListenableProvider<DuoLayout?>.value(value: duoLayout),
					ChangeNotifierProvider.value(value: ImageboardRegistry.instance),
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
							top: duoLayout.value == null,
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
														builder: (context) => ErrorMessageCard('Fatal setup error\n${ImageboardRegistry.instance.setupError!.$1.toStringDio()}', remedies: {
															...generateBugRemedies(ImageboardRegistry.instance.setupError!.$1, ImageboardRegistry.instance.setupError!.$2, context),
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
									final (theme, _, _) = context.select<Settings, (SavedTheme, String?, String?)>((s) => (SavedTheme.copyFrom(s.theme), s.fontFamily, s.fontFamilyFallback));
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
													navigatorKey: _navigatorKey,
													navigatorObservers: [ScrollTrackerNavigatorObserver()]
												) : Theme(
													data: theme.materialThemeData,
													child: CupertinoApp(
														title: 'Chance',
														debugShowCheckedModeBanner: false,
														theme: theme.cupertinoThemeData,
														scrollBehavior: scrollBehavior,
														home: home,
														localizationsDelegates: localizationsDelegates,
														navigatorKey: _navigatorKey,
														navigatorObservers: [ScrollTrackerNavigatorObserver()]
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

	static const _kImage = AssetImage('assets/splash.png');

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
						scale: (Platform.isAndroid ? 1 : 1.5) / (
							2.0 * MediaQuery.of(context).devicePixelRatio *
							Settings.interfaceScaleSetting.watch(context)
						),
						child: ColorFiltered(
							colorFilter: ColorFilter.mode(
								ChanceTheme.barColorOf(context),
								BlendMode.srcATop
							),
							child: const Image(
								image: _kImage
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
	final void Function(String, ThreadIdentifier, {bool incognito, bool activate, int? initialPostId, String? initiallyHintArchive}) onWantOpenThreadInNewTab;
	@override
	final int hashCode;

	const OpenInNewTabZone({
		required this.onWantOpenThreadInNewTab,
		required this.hashCode
	});

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is OpenInNewTabZone &&
		other.hashCode == hashCode;
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
	final _ChanHomePageState _homePageState;
	final _initializer = TaskStack();
	bool get initialized => _initializer.isCompleted;
	final activeBrowserTab = ValueNotifier<int>(Persistence.currentTabIndex);
	late Listenable browseCountListenable = Listenable.merge([activeBrowserTab, ...Persistence.tabs.map((x) => x.unseen)]);
	final _tabController = CupertinoTabController();
	final _paginatedTabListController = PaginatedReorderableListController();
	final _legacyTabListController = ScrollController();
	int _lastIndex = 0;
	final _savedMasterDetailKey = GlobalKey<SavedPageMasterDetailPanesState>();
	final _tabButtonKeys = <int, GlobalKey>{};
	final _tabNavigatorKeys = <int, GlobalKey<NavigatorState>>{};
	final _searchPageKey = GlobalKey<SearchPageState>();
	final _historyPageKey = GlobalKey<HistoryPageState>();
	final _settingsNavigatorKey = GlobalKey<NavigatorState>();
	final _settingsPageKey = GlobalKey<SettingsPageState>();
	late final OwnedChangeNotifierSubscription _settingsSubscription;
	bool _didHideTabPopupFromReplyBox = false;
	final _willPopZones = <int, WillPopZone>{};
	final _devFakeTab = PersistentBrowserTab();
	final PersistentBrowserTab _savedFakeTab = PersistentBrowserTab();
	final Map<String, ({Notifications notifications, StreamSubscription<TappedNotification> subscription})> _notificationsSubscriptions = {};
	late StreamSubscription<String?> _linkSubscription;
	late StreamSubscription<String?> _fakeLinkSubscription;
	late StreamSubscription<SharedMedia> _sharedFilesSubscription;
	// Sometimes duplicate links are received due to use of multiple link handling packages
	({DateTime time, String link})? _lastLink;
	late (String?, String) _lastHomeBoard;
	late bool _lastUsePaginatedTabBar;
	static const _tabListPaginationDelegate = PaginatedReorderableListDelegateWithMaxMainAxisExtent(
		maxMainAxisExtent: 120
	);
	static const _sidebarTabListPaginationDelegate = PaginatedReorderableListDelegateWithMaxMainAxisExtent(
		maxMainAxisExtent: 108
	);

	ChanTabs._(this._homePageState) {
		Persistence.globalTabMutator.addListener(_onGlobalTabMutatorUpdate);
		ScrollTracker.instance.someNavigatorNavigated.addListener(_onSomeNavigatorNavigated);
		ImageboardRegistry.instance.addListener(_onImageboardRegistryUpdate);
		// Set up notification subscriptions
		_onImageboardRegistryUpdate();
		for (final tab in Persistence.tabs) {
			tab.addListener(_onTabUpdate);
			tab.threadForPullTab = tab.thread;
		}
		_lastHomeBoard = (Settings.instance.homeImageboardKey, Settings.instance.homeBoardName);
		_lastUsePaginatedTabBar = Settings.instance.usePaginatedTabBar;
		Settings.instance.addListener(_onSettingsUpdate);
		_settingsSubscription = SelectListenable(Settings.instance, (s) => (
			s.alwaysUseWideDrawerGesture,
			s.openBoardSwitcherSlideGesture,
		)).subscribeOwned(notifyListeners);
		_linkSubscription = AppLinks().stringLinkStream.listen(_consumeLink);
		_fakeLinkSubscription = fakeLinkStream.stream.listen(_consumeLink);
		_sharedFilesSubscription = ShareHandlerPlatform.instance.sharedMediaStream.listen(_consumeSharedMediaFiles);
		if (!_initialConsume) {
			_initializer.holdFor(AppLinks().getInitialLinkString()).then((x) => _consumeLink(x, showAnimationsForward: false));
			_initializer.holdFor(ShareHandlerPlatform.instance.getInitialSharedMedia()).then((x) => _consumeSharedMediaFiles(x, showAnimationsForward: false));
			_initialConsume = true;
		}

		/// Some minimum time to wait for stuff to start (notification subscriptions may be drained)
		_initializer.holdFor(Future.delayed(const Duration(milliseconds: 10)));
		_initializer.future.then((_) {
			notifyListeners();
		});
	}

	void _onGlobalTabMutatorUpdate() {
		browseTabIndex = Persistence.globalTabMutator.value;
	}

	void _onTabUpdate() {
		notifyListeners();
	}

	void _onImageboardRegistryUpdate() {
		for (final board in ImageboardRegistry.instance.imageboardsIncludingDev) {
			if (_notificationsSubscriptions[board.key]?.notifications != board.notifications) {
				_notificationsSubscriptions[board.key]?.subscription.cancel();
				_notificationsSubscriptions[board.key] = (notifications: board.notifications, subscription: board.notifications.tapStream.stream.listen((notification) {
					_onNotificationTapped(board, notification.target.boardThreadOrPostIdentifier, showAnimationsForward: !notification.isLaunch);
				}));
			}
		}
	}

	void _onSettingsUpdate() async {
		final usePaginatedTabBar = Settings.instance.usePaginatedTabBar;
		if (usePaginatedTabBar != _lastUsePaginatedTabBar) {
			_lastUsePaginatedTabBar = usePaginatedTabBar;
			WidgetsBinding.instance.addPostFrameCallback((_) {
				_animateTabList(duration: Duration.zero);
			});
		}
		final newHomeBoard = (Settings.instance.homeImageboardKey, Settings.instance.homeBoardName);
		if (newHomeBoard != _lastHomeBoard) {
			if (Persistence.tabs.first.imageboardKey == _lastHomeBoard.$1
			 		&& Persistence.tabs.first.board == _lastHomeBoard.$2
					&& !Persistence.tabs.first.incognito
			) {
				if (newHomeBoard.$1 != null) {
					// Edit existing tab
					final tab = Persistence.tabs.first;
					tab.board = newHomeBoard.$2;
					final didChangeSite = tab.imageboardKey != newHomeBoard.$1;
					tab.imageboardKey = newHomeBoard.$1;
					tab.initialSearch = null;
					if (didChangeSite) {
						tab.masterDetailKey.currentState?.setValue(null, showAnimationsForward: false);
					}
					else {
						Future.delayed(const Duration(seconds: 1), Persistence.saveTabs);
						tab.didUpdate();
					}
				}
				else if (Persistence.tabs.first.thread == null) {
					// Close existing tab
					closeBrowseTab(0);
				}
			}
			else if (
				newHomeBoard.$1 != null
				&& !(Persistence.tabs.first.imageboardKey == newHomeBoard.$1
							&& Persistence.tabs.first.board == newHomeBoard.$2
							&& Persistence.tabs.first.thread == null
							&& !Persistence.tabs.first.incognito
				)
			) {
				// Insert new tab
				final tab = PersistentBrowserTab(
					imageboardKey: newHomeBoard.$1,
					board: newHomeBoard.$2
				);
				await tab.initialize();
				insertInitializedTab(0, tab, keepTabPopupOpen: true, activate: false);
			}
			_lastHomeBoard = newHomeBoard;
		}
	}

	void _onSomeNavigatorNavigated() {
		// Recalculate shouldEnableWideDrawerGesture
		if (Settings.instance.androidDrawer) {
			Future.microtask(notifyListeners);
		}
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
		Future.microtask(_animateTabList);
	}

	double? get drawerEdgeGestureWidthFactor {
		if (_tabNavigatorKeys[mainTabIndex]?.currentState?.canPop() ?? false) {
			// Something covering the current navigator
			return null;
		}
		bool canPop = true; // assume something covering the screen
		if (mainTabIndex == 0) {
			final tab = Persistence.tabs[Persistence.currentTabIndex];
			final masterNavigatorState = tab.masterDetailKey.currentState?.masterKey.currentState;
			if (masterNavigatorState != null) {
				if (masterNavigatorState.canPop()) {
					return Settings.instance.alwaysUseWideDrawerGesture ? 0.5 : null;
				}
				else {
					return Settings.instance.openBoardSwitcherSlideGesture ? 0.5 : 1.0;
				}
			}
		}
		else if (mainTabIndex == 1) {
			final state = _savedMasterDetailKey.currentState;
			if (state != null) {
				if (state.selectedPane != 0) {
					// Priority is swiping left to previous pane
					return null;
				}
				final masterNavigatorState = state.masterKey.currentState;
				if (masterNavigatorState != null) {
					canPop = masterNavigatorState.canPop();
				}
			}
		}
		else if (mainTabIndex == 2) {
			final masterNavigatorState = _historyPageKey.currentState?.masterDetailKey.currentState?.masterKey.currentState;
			if (masterNavigatorState != null) {
				canPop = masterNavigatorState.canPop();
			}
		}
		else if (mainTabIndex == 3) {
			final masterNavigatorState = _searchPageKey.currentState?.masterDetailKey.currentState?.masterKey.currentState;
			if (masterNavigatorState != null) {
				canPop = masterNavigatorState.canPop();
			}
		}
		else if (mainTabIndex == 4) {
			final state = _settingsNavigatorKey.currentState;
			if (state != null) {
				canPop = state.canPop();
			}
		}
		if (!canPop) {
			// nothing to swipe back to
			return 1.0;
		}
		else if (Settings.instance.alwaysUseWideDrawerGesture) {
			return 0.5;
		}
		else {
			// swipe pop gesture exists + no explicit setting to coexist
			return null;
		}
	}

	@override
	void dispose() {
		super.dispose();
		activeBrowserTab.dispose();
		_paginatedTabListController.dispose();
		_legacyTabListController.dispose();
		Persistence.globalTabMutator.removeListener(_onGlobalTabMutatorUpdate);
		ScrollTracker.instance.someNavigatorNavigated.removeListener(_onSomeNavigatorNavigated);
		for (final tab in Persistence.tabs) {
			tab.removeListener(_onTabUpdate);
		}
		Settings.instance.removeListener(_onSettingsUpdate);
		_settingsSubscription.dispose();
		_linkSubscription.cancel();
		_fakeLinkSubscription.cancel();
		_sharedFilesSubscription.cancel();
		ImageboardRegistry.instance.removeListener(_onImageboardRegistryUpdate);
		for (final subscription in _notificationsSubscriptions.values) {
			subscription.subscription.cancel();
		}
	}

	Future<PersistentBrowserTab> addNewTab({
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
		String? initiallyHintArchive,
		String? initiallyForceArchive
	}) async {
		final pos = atPosition ?? Persistence.tabs.length;
		final thread = withThread ?? (withThreadId == null ? null : ThreadIdentifier(withBoard!, withThreadId));
		final tab = PersistentBrowserTab(
			imageboardKey: withImageboardKey,
			board: withImageboardKey == null || withBoard == null ? null : withBoard,
			thread: thread,
			incognito: incognito,
			initialSearch: withInitialSearch
		);
		await tab.initialize();
		if (thread != null && withInitialPostId != null) {
			tab.initialPostId[thread] = withInitialPostId;
		}
		if (thread != null && initiallyForceArchive != null) {
			tab.initiallyForceArchive[thread] = initiallyForceArchive;
		}
		if (thread != null && initiallyHintArchive != null) {
			tab.initiallyHintArchive[thread] = initiallyHintArchive;
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
		if (pos <= browseTabIndex) {
			// Keep the same current tab afterwards
			Persistence.currentTabIndex++;
			activeBrowserTab.value++;
		}
		browseCountListenable = Listenable.merge([activeBrowserTab, ...Persistence.tabs.map((x) => x.unseen)]);
		if (activate) {
			_tabController.index = 0;
			activeBrowserTab.value = pos;
			Persistence.currentTabIndex = pos;
		}
		_homePageState._onShouldShowTabPopup(keepTabPopupOpen || !activate || !Persistence.settings.closeTabSwitcherAfterUse);
		_didModifyPersistentTabData();
		notifyListeners();
		Future.delayed(const Duration(milliseconds: 100), () {
			_animateTabList(index: pos);
		});
	}

	void onReorderItem(int oldIndex, int newIndex) {
		final currentTab = Persistence.tabs[activeBrowserTab.value];
		if (Settings.instance.usingHomeBoard) {
			newIndex += 1;
			oldIndex += 1;
		}
		final tab = Persistence.tabs.removeAt(oldIndex);
		Persistence.tabs.insert(newIndex, tab);
		activeBrowserTab.value = Persistence.tabs.indexOf(currentTab);
		Persistence.currentTabIndex = activeBrowserTab.value;
		_didModifyPersistentTabData();
		notifyListeners();
	}

	void closeBrowseTab(int browseIndex) {
		if (Persistence.tabs.length == 1) {
			throw StateError('Tried to close last tab');
		}
		final removed = Persistence.tabs.removeAt(browseIndex);
		removed.removeListener(_onTabUpdate);
		browseCountListenable = Listenable.merge([activeBrowserTab, ...Persistence.tabs.map((x) => x.unseen)]);
		final int newActiveTabIndex;
		if (browseIndex > browseTabIndex) {
			// The removed tab was after our current tab, don't have to do anything
			newActiveTabIndex = browseTabIndex;
		}
		else if (browseIndex == browseTabIndex) {
			// The current tab was removed
			newActiveTabIndex = (browseTabIndex - 1).clamp(0, Persistence.tabs.length - 1);
		}
		else {
			// A tab before the current one was removed, need to fix the index
			newActiveTabIndex = browseTabIndex - 1;
		}
		browseTabIndex = newActiveTabIndex;
		notifyListeners();
	}

	Future<void> showNewTabPopup({
		required BuildContext context,
		required AxisDirection direction,
		required Axis? titles
	}) async {
		lightHapticFeedback();
		showTabMenu(
			context: context,
			direction: direction,
			titles: titles,
			origin: context.globalSemanticBounds!,
			actions: newTabActions(context)
		);
	}

	List<TabMenuAction> newTabActions(BuildContext context) => [
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
						_homePageState._onShouldShowTabPopup(false);
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
							},
							padding: const EdgeInsets.only(bottom: 50)
						);
					}
				}
			}
		)
	];

	ImageboardScoped<ThreadIdentifier>? get currentForegroundThread {
		switch (mainTabIndex) {
			case 0:
				return currentBrowserThread;
			case 1:
				switch (_savedMasterDetailKey.currentState?.selectedPane) {
					case 0:
						final watched = _savedMasterDetailKey.currentState?.getValue1();
						if (watched != null) {
							return watched.imageboard.scope(watched.item.threadIdentifier);
						}
					case 1:
						final saved = _savedMasterDetailKey.currentState?.getValue2();
						if (saved != null) {
							return saved.imageboard.scope(saved.item.thread);
						}
					case 2:
						final yourPost = _savedMasterDetailKey.currentState?.getValue3();
						if (yourPost != null) {
							return yourPost.imageboard.scope(yourPost.thread.identifier);
						}
					case 3:
						final savedPost = _savedMasterDetailKey.currentState?.getValue4();
						if (savedPost != null) {
							return savedPost.imageboard.scope(savedPost.item.post.threadIdentifier);
						}
					case 4:
						// Saved Attachments
						return null;
				}
			case 2:
				final value = _historyPageKey.currentState?.masterDetailKey.currentState?.getValue();
				if (value != null) {
					return value.imageboard.scope(value.item.thread);
				}
			case 3:
				final value = _searchPageKey.currentState?.masterDetailKey.currentState?.getValue();
				if (value != null) {
					return value.imageboard.scope(value.result.thread);
				}
			case 4:
				final zone = _devFakeTab.threadPageState?.zone;
				if (zone != null) {
					return zone.imageboard.scope(zone.primaryThread);
				}
 		}
		return null;
	}

	ImageboardScoped<ThreadIdentifier>? get currentBrowserThread {
		final tab = Persistence.tabs[Persistence.currentTabIndex];
		final thread = tab.thread;
		if (thread == null) {
			return null;
		}
		return tab.imageboard?.scope(thread);
	}

	Future<void> setCurrentBrowserThread(ImageboardScoped<ThreadIdentifier>? newThread, {
		bool showAnimationsForward = true
	}) async {
		final tab = Persistence.tabs[Persistence.currentTabIndex];
		if (newThread != null) {
			await newThread.imageboard.persistence.getThreadStateIfExists(newThread.item)?.ensureThreadLoaded();
		}
		if (newThread != null && tab.imageboardKey != newThread.imageboard.key) {
			tab.imageboardKey = newThread.imageboard.key;
			// Old master-pane is no longer applicable
			tab.board = newThread.item.board;
			tab.boardPageKey.currentState?.swapBoard(newThread.imageboard.scope(newThread.imageboard.persistence.getBoard(newThread.item.board)));
		}
		tab.masterDetailKey.currentState?.setValue(newThread?.item, showAnimationsForward: showAnimationsForward);
		tab.didUpdate();
		runWhenIdle(const Duration(seconds: 1), Persistence.saveTabs);
	}
	
	Future<bool> goToPost({
		required String imageboardKey,
		required String board,
		required int? threadId,
		int? postId,
		required bool openNewTabIfNeeded,
		String? initiallyForceArchive,
		bool showAnimationsForward = true
	}) async {
		if (threadId != null) {
			await ImageboardRegistry.instance.getImageboard(imageboardKey)?.persistence.getThreadStateIfExists(ThreadIdentifier(board, threadId))?.ensureThreadLoaded();
		}
		final boardKey = ImageboardBoard.getKey(board);
		PersistentBrowserTab? tab = Persistence.tabs.tryFirstWhere((tab) => tab.imageboardKey == imageboardKey && tab.thread?.boardKey == boardKey && tab.thread?.id == threadId);
		final tabAlreadyExisted = tab != null;
		if (openNewTabIfNeeded) {
			if (tab == null && threadId != null) {
				// Maybe we can reuse a tab sitting at catalog for this board
				bool pred(PersistentBrowserTab tab) => tab.imageboardKey == imageboardKey && tab.boardKey == boardKey && tab.thread == null;
				final catalogTab = Persistence.tabs[Persistence.currentTabIndex].tryIf(pred) ?? Persistence.tabs.tryFirstWhere(pred);
				if (catalogTab != null) {
					tab = catalogTab;
					catalogTab.thread = ThreadIdentifier(board, threadId);
					if (initiallyForceArchive != null) {
						catalogTab.initiallyForceArchive[catalogTab.thread!] = initiallyForceArchive;
					}
					if (postId != null) {
						catalogTab.initialPostId[ThreadIdentifier(board, threadId)] = postId;
					}
					catalogTab.masterDetailKey.currentState?.setValue(ThreadIdentifier(board, threadId), showAnimationsForward: showAnimationsForward);
					catalogTab.didUpdate();
				}
			}
			tab ??= await addNewTab(
				activate: false,
				withImageboardKey: imageboardKey,
				withBoard: board,
				withThreadId: threadId,
				withInitialPostId: postId,
				initiallyForceArchive: initiallyForceArchive
			);
		}
		if (tab != null) {
			mainTabIndex = 0;
			browseTabIndex = Persistence.tabs.indexOf(tab);
			if (tabAlreadyExisted && threadId != null && initiallyForceArchive != null) {
				tab.initiallyForceArchive[ThreadIdentifier(board, threadId)] = initiallyForceArchive;
				await tab.threadPageState?.loadFromArchive(initiallyForceArchive);
			}
			if (tabAlreadyExisted && threadId != null && postId != null) {
				tab.initialPostId[ThreadIdentifier(board, threadId)] = postId;
				tab.threadPageState?.scrollToPost(postId);
			}
			return true;
		}
		return false;
	}

	ImageboardScoped<ThreadWatch>? get selectedWatchedThread {
		return _savedMasterDetailKey.currentState?.getValue1();
	}
	set selectedWatchedThread(ImageboardScoped<ThreadWatch>? newWatchedThread) {
		_savedMasterDetailKey.currentState?.setValue1(newWatchedThread);
	}
	set selectedWatchedThreadWithoutAnimation(ImageboardScoped<ThreadWatch>? newWatchedThread) {
		_savedMasterDetailKey.currentState?.setValue1(newWatchedThread, showAnimationsForward: false);
	}

	Future<void> _animateTabList({int? index, Duration duration = const Duration(milliseconds: 500)}) async {
		if (!Settings.instance.usePaginatedTabBar) {
			return _animateLegacyTabList(index: index, duration: duration);
		}
		final viewportDimension = _paginatedTabListController.tryPosition?.viewportDimension;
		if (viewportDimension == null) {
			return;
		}
		final paginationDelegate = _paginatedTabListController.position.axis == Axis.vertical ? _sidebarTabListPaginationDelegate : _tabListPaginationDelegate;
		final itemsPerPage = paginationDelegate.getMainAxisCount(viewportDimension);
		final usingHomeBoard = Settings.instance.usingHomeBoard;
		final globalIndex = index ?? browseTabIndex;
		final listIndex = usingHomeBoard ? max(0, globalIndex - 1) : globalIndex;
		final listItemCount = max(0, Persistence.tabs.length - (usingHomeBoard ? 1 : 0));
		if ((_homePageState._paginatedTabListKey.currentState?.widget.obscuredExtent ?? 0) > 0) {
			// The shrinking viewport already reveals the active tab during layout.
			if (globalIndex != browseTabIndex) {
				await _paginatedTabListController.ensureItemVisible(listIndex, duration: duration, curve: Curves.ease);
			}
			return;
		}
		final lastPage = listItemCount == 0 ? 0 : (_paginatedTabListController.pageForItem(listItemCount - 1) ?? ((listItemCount - 1) ~/ itemsPerPage));
		final targetPage = min(_paginatedTabListController.pageForItem(listIndex) ?? (listIndex ~/ itemsPerPage), lastPage);
		if (duration > Duration.zero) {
			await _paginatedTabListController.animateToPage(targetPage, curve: Curves.ease, duration: duration);
		}
		else {
			_paginatedTabListController.jumpToPage(targetPage);
		}
	}

	Future<void> _animateLegacyTabList({
		int? index,
		Duration duration = const Duration(milliseconds: 500),
		bool inner = false
	}) async {
		final pos = index ?? browseTabIndex;
		if (_tabButtonKeys[pos]?.currentContext?.ifMounted case BuildContext ctx) {
			await Scrollable.ensureVisible(
				ctx,
				alignmentPolicy: pos < 3 ?
					ScrollPositionAlignmentPolicy.keepVisibleAtStart :
					ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
				duration: duration
			);
			return;
		}
		(int, double)? firstKnownItem;
		(int, double)? lastKnownItem;
		final viewportDimension = _legacyTabListController.tryPosition?.viewportDimension;
		if (viewportDimension == null) {
			return;
		}
		for (final entry in _tabButtonKeys.entries) {
			final offset = entry.value.currentContext?.getOffsetToReveal(0);
			if (offset != null) {
				final item = (entry.key, offset);
				firstKnownItem ??= item;
				lastKnownItem = item;
			}
		}
		final double estimate;
		if (firstKnownItem != null && pos < firstKnownItem.$1) {
			estimate = (firstKnownItem.$2 / firstKnownItem.$1) * pos;
		}
		else if (lastKnownItem != null && pos > lastKnownItem.$1) {
			final averageItemExtent = lastKnownItem.$2 / lastKnownItem.$1;
			final estimateAtAlignment0 = averageItemExtent * pos;
			estimate = min(
				estimateAtAlignment0 + (viewportDimension - averageItemExtent),
				(averageItemExtent * Persistence.tabs.length) - viewportDimension,
			);
		}
		else {
			return;
		}
		if (duration > Duration.zero) {
			await _legacyTabListController.animateTo(estimate, curve: Curves.ease, duration: duration);
			await SchedulerBinding.instance.endOfFrame;
		}
		else {
			_legacyTabListController.jumpTo(estimate);
			await SchedulerBinding.instance.endOfFrame;
		}
		if (!inner) {
			_animateLegacyTabList(index: index, duration: duration, inner: true);
		}
	}

	Future<void> searchArchives(String imageboardKey, String board, String query) async {
		mainTabIndex = 3;
		for (int i = 0; i < 200 && _searchPageKey.currentState == null; i++) {
			await SchedulerBinding.instance.endOfFrame;
		}
		_searchPageKey.currentState?.onSearchComposed(ImageboardArchiveSearchQuery(
			imageboardKey: imageboardKey,
			boards: [board],
			query: query
		));
	}

	void didOpenReplyBox() {
		if (mainTabIndex == 0 && _homePageState._showTabPopup.value) {
			_homePageState._onShouldShowTabPopup(false);
			_didHideTabPopupFromReplyBox = true;
		}
	}

	void didCloseReplyBox() {
		if (mainTabIndex == 0 && !_homePageState._showTabPopup.value && _didHideTabPopupFromReplyBox) {
			_homePageState._onShouldShowTabPopup(true);
			_didHideTabPopupFromReplyBox = false;
		}
	}

	Future<void> willActivatePane(int index) async {
		if (index == _lastIndex) {
			if (index == 4) {
				if (await _settingsNavigatorKey.currentState?.maybePop() != true) {
					_settingsPageKey.currentState?.unfocusSearch();
				}
			}
			else {
				_willPopZones[index]?.maybePop?.call();
			}
		} else if (index == 2) {
			await _historyPageKey.currentState?.updateList();
		}
	}

	void _onNotificationTapped(Imageboard imageboard, BoardThreadOrPostIdentifier notification, {
		String? initiallyForceArchive,
		bool showAnimationsForward = true
	}) => _initializer.holdForFunction(() async {
		// Close any gallery or other popup
		Navigator.of(_homePageState.context, rootNavigator: true).popUntil((r) => r.isFirst);
		if (notification.threadIdentifier case final thread? when !initialized) {
			await imageboard.persistence.getThreadStateIfExists(thread)?.ensureThreadLoaded(syncIO: true);
		}
		if (imageboard == ImageboardRegistry.instance.dev) {
			mainTabIndex = 4;
			if (notification.threadIdentifier case final thread?) {
				_devFakeTab.thread = thread;
				if (notification.postId case final postId?) {
					_devFakeTab.initialPostId[thread] = postId;
					if (_devFakeTab.threadPageState?.widget.thread == thread) {
						await _devFakeTab.threadPageState?.scrollToPost(postId);
					}
				}
			}
			_devFakeTab.board = notification.board;
			if (_settingsNavigatorKey.currentState case final state?) {
				final thread = notification.threadIdentifier;
				final postId = notification.postId;
				if (thread == null) {
					// Load board page
					state.popUntil((r) => r.isFirst);
					state.push(
						adaptivePageRoute(
							builder: (context) => BoardPage(
								initialBoard: ImageboardRegistry.instance.dev!.persistence.getBoard(notification.board),
								allowChangingBoard: false,
								semanticId: -1
							),
							showAnimationsForward: showAnimationsForward
						)
					);
				}
				else if (_devFakeTab.threadPageState?.widget.thread != thread) {
					state.popUntil((r) => r.isFirst);
					state.push(
						adaptivePageRoute(
							builder: (context) => ThreadPage(
								thread: thread,
								initialPostId: postId,
								boardSemanticId: -1
							),
							showAnimationsForward: showAnimationsForward
						)
					);
				}
			}
		}
		else if (!await goToPost(
			imageboardKey: imageboard.key,
			board: notification.board,
			threadId: notification.threadId,
			postId: notification.postId,
			openNewTabIfNeeded: false,
			initiallyForceArchive: initiallyForceArchive,
			showAnimationsForward: showAnimationsForward
		)) {
			final thread = notification.threadIdentifier;
			final watch = imageboard.persistence.browserState.threadWatches[thread];
			if (watch == null || thread == null) {
				await goToPost(
					imageboardKey: imageboard.key,
					board: notification.board,
					threadId: notification.threadId,
					postId: notification.postId,
					openNewTabIfNeeded: true,
					initiallyForceArchive: initiallyForceArchive,
					showAnimationsForward: showAnimationsForward
				);
			}
			else {
				_savedFakeTab.imageboardKey = imageboard.key;
				_savedFakeTab.thread = thread;
				if (notification.postId case final postId?) {
					_savedFakeTab.initialPostId[thread] = postId;
					if (selectedWatchedThread?.item == watch) {
						_savedFakeTab.threadPageState?.scrollToPost(postId);
					}
				}
				mainTabIndex = 1;
				_savedMasterDetailKey.currentState?.setValue1(imageboard.scope(watch), showAnimationsForward: showAnimationsForward);
			}
		}
	});

	Future<void> _consumeLink(String? link, {
		bool showAnimationsForward = true
	}) async {
		final settings = Settings.instance;
		if (link == null || link.isEmpty) {
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
					await _initializer.future;
					if (!_homePageState.mounted) {
						return;
					}
					await showAdaptiveDialog(
						context: _homePageState.context,
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
												showAllColors: true
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
				catch (e, st) {
					if (_homePageState.mounted) {
						alertError(_homePageState.context, e, st);
					}
				}
			}
			else if (uri.pathSegments.length >= 2 && uri.pathSegments[1] == 'thread') {
				await goToPost(
					imageboardKey: uri.host,
					board: uri.pathSegments[0],
					threadId: int.parse(uri.pathSegments[2]),
					postId: uri.queryParameters['postId']?.tryParseInt,
					openNewTabIfNeeded: true,
					showAnimationsForward: showAnimationsForward
				);
			}
			else if (uri.host == 'site') {
				await _initializer.future;
				if (!_homePageState.mounted) {
					return;
				}
				final siteKey = uri.pathSegments[0];
				try {
					if (ImageboardRegistry.instance.getImageboard(siteKey) == null) {
						if (Settings.instance.contentSettings.siteKeys.trySingle == kTestchanKey) {
							throw Exception('Not allowed to add arbitrary sites');
						}
						final consent = await confirm(_homePageState.context, 'Add site $siteKey?');
						if (consent != true) {
							return;
						}
						if (!_homePageState.mounted) return;
						await modalLoad(_homePageState.context, 'Setting up...', (_) async {
							Settings.instance.addSiteKey(siteKey);
							await Future.delayed(const Duration(milliseconds: 500)); // wait for rebuild of ChanHomePage
						});
					}
					addNewTab(
						withImageboardKey: siteKey,
						activate: true,
						keepTabPopupOpen: true
					);
				}
				catch (e, st) {
					if (_homePageState.mounted) {
						alertError(_homePageState.context, e, st);
					}
				}
			}
			else if (link != 'chance://') {
				await _initializer.future;
				if (!_homePageState.mounted) {
					return;
				}
				alertError(_homePageState.context, 'Unrecognized link\n$link', null);
			}
		}
		else if (link.toLowerCase().startsWith('sharemedia-com.moffatman.chan')) {
			// ignore this, it is handled elsewhere
		}
		else {
			if (Uri.tryParse(link) case Uri url) {
				// Custom [wait] handling to start before [initialized]
				final cancelToken = CancelToken();
				final future = ImageboardRegistry.instance.decodeUrl(url, cancelToken: cancelToken);
				(Imageboard, BoardThreadOrPostIdentifier, String?)? dest;
				try {
					dest = await _initializer.holdFor(future.timeout(const Duration(milliseconds: 50)));
				}
				on TimeoutException {
					// Wait for initialization to use context
					await _initializer.future;
					if (!_homePageState.mounted) {
						return;
					}
					dest = await modalLoad(_homePageState.context, 'Checking url...', (controller) {
						controller.cancelToken.whenCancel.then(cancelToken.cancel);
						return future;
					}, cancellable: true);
				}
				if (dest != null) {
					_onNotificationTapped(dest.$1, dest.$2, initiallyForceArchive: dest.$3, showAnimationsForward: showAnimationsForward);
					return;
				}
			}
			await _initializer.future;
			if (!_homePageState.mounted) {
				return;
			}
			if ([
				'.webm',
				'.mkv',
				'.mov',
				'.mp4',
				'.png',
				'.jpg',
				'.jpeg',
				'.gif'
			].any(link.endsWith)) {
				openBrowser(_homePageState.context, Uri.parse(link));
				return;
			}
			final open = await showAdaptiveDialog<bool>(
				context: _homePageState.context,
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
			if (open == true && _homePageState.mounted) {
				await shareOne(
					context: _homePageState.context,
					type: 'text',
					text: link,
					sharePositionOrigin: null
				);
			}
		}
	}

	void _consumeFiles(List<String> paths) {
		if (paths.isNotEmpty) {
			showToast(
				context: _homePageState.context,
				message: '${(paths.length > 1 ? 'Files' : 'File')} added to upload selector',
				icon: CupertinoIcons.paperclip
			);
			receivedFilePaths.addAll(paths);
			attachmentSourceNotifier.didUpdate();
		}
	}

	void _consumeSharedMediaFiles(SharedMedia? media, {bool showAnimationsForward = true}) {
		final files = (media?.attachments ?? []).tryMap((f) {
			if (f?.type == SharedAttachmentType.file ||
				  f?.type == SharedAttachmentType.image ||
				  f?.type == SharedAttachmentType.video) {
				return f?.path;
			}
		}).toList();
		if (files.isNotEmpty) {
			_consumeFiles(files);
		}
		if (media?.content case final text? when text.isNotEmpty) {
			_consumeLink(text, showAnimationsForward: showAnimationsForward);
		}
	}
}

class _ChanHomePageState extends State<ChanHomePage> {
	static const _sidebarButtonVerticalPadding = 10.0;
	static const _bottomBarHeight = 50.0;
	bool _skipSidebarTabSwipe = false;
	late final ChanTabs _tabs;
	late final _tabListChanges = Listenable.merge([_tabs.activeBrowserTab, _tabs._tabController]);
	final _keys = <int, GlobalKey>{};
	late final ValueNotifier<bool> _showTabPopup;
	late final _visibleTabPopup = Combining2ValueListenable(
		child1: _showTabPopup,
		child2: ScrollTracker.instance.tabPopupHidden,
		combine: (show, hidden) => show &&
			!(hidden && Settings.instance.tabMenuHidesWhenScrollingDown)
	);
	Imageboard? get devImageboard => ImageboardRegistry.instance.dev;
	_AuthenticationStatus _authenticationStatus = _AuthenticationStatus.ok;
	final _drawerScaffoldKey = GlobalKey<AdaptiveScaffoldState>(debugLabel: '_ChanHomePageState._drawerScaffoldKey');
	final _paginatedTabListKey = GlobalKey<PaginatedReorderableListState>(debugLabel: '_ChanHomePageState._paginatedTabListKey');
	final _floatingTabControlsKey = GlobalKey<FloatingTabControlsState>(debugLabel: '_ChanHomePageState._floatingTabControlsKey');

	void _swipeTab(int delta) {
		mediumHapticFeedback();
		final switchingPane = _tabs.mainTabIndex > 0;
		final target = (switchingPane ? _tabs.mainTabIndex : _tabs.browseTabIndex) + delta;
		final last = switchingPane ? 4 : Persistence.tabs.length - 1;
		if (target < 0 || target > last) {
			Future.delayed(const Duration(milliseconds: 100), mediumHapticFeedback);
		}
		else if (switchingPane) {
			_tabs.mainTabIndex = target;
		}
		else {
			_tabs.browseTabIndex = target;
		}
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
		if (ScrollTracker.instance.slowScrollDirection.value == VerticalDirection.down && _showTabPopup.value) {
			Persistence.settings.didHideTabPopupAutomatically = true;
			_showTabPopup.value = false;
		}
		else if (ScrollTracker.instance.slowScrollDirection.value == VerticalDirection.up && Persistence.settings.didHideTabPopupAutomatically) {
			Persistence.settings.didHideTabPopupAutomatically = false;
			_showTabPopup.value = true;
		}
	}

	void _tabsListener() {
		if (mounted) {
			setState(() {});
		}
	}

	Future<void> _setAdditionalSafeAreaInsets() async {
		await setAdditionalSafeAreaInsets('main', EdgeInsets.only(
			bottom: 60 + 44 + (_visibleTabPopup.value ? 80 : 0)
		) * Settings.instance.interfaceScale);
	}

	void _onShouldShowTabPopup(bool newShowTabPopup) {
		if (newShowTabPopup && !_showTabPopup.value) {
			// Force show nav bars
			ScrollTracker.instance.slowScrollDirection.value = VerticalDirection.up;
		}
		_showTabPopup.value = newShowTabPopup;
	}

	@override
	void initState() {
		super.initState();
		_tabs = ChanTabs._(this);
		_tabs.addListener(_tabsListener);
		_showTabPopup = ValueNotifier(false)
			..addListener(() {
				Persistence.settings.showTabPopup = _showTabPopup.value;
				Persistence.settings.save();
				if (_showTabPopup.value && !Settings.instance.usePaginatedTabBar) {
					Future.microtask(() => _tabs._animateTabList(duration: Duration.zero));
				}
			});
		_visibleTabPopup.addListener(_setAdditionalSafeAreaInsets);
		if (Persistence.settings.showTabPopup) {
			Future.delayed(const Duration(milliseconds: 50), () {
				SchedulerBinding.instance.addPostFrameCallback((_) {
					_showTabPopup.value = true;
				});
			});
		}
		// The paginated list positions its selected item during its first layout.
		if (!Settings.instance.usePaginatedTabBar) {
			Future.microtask(() => _tabs._animateTabList(duration: Duration.zero));
		}
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
			if (!Settings.instance.usePaginatedTabBar) {
				_tabs._animateTabList();
			}
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

	Widget _buildTab(int index) {
		Widget child;
		if (index <= 0) {
			child = ListenableBuilder(
				listenable: _tabs,
				builder: (context, _) => ValueListenableBuilder(
					valueListenable: _tabs.activeBrowserTab,
					builder: (context, activeBrowserTab, _) => SwitchingView(
						currentIndex: activeBrowserTab,
						items: Persistence.tabs,
						builder: (tabObject) => ImageboardTab(
							key: tabObject.tabKey,
							tab: tabObject
						)
					)
				)
			);
		}
		else if (index == 1) {
			child = MultiProvider(
				providers: [
					ChangeNotifierProvider.value(
						value: _tabs._savedFakeTab
					),
					Provider.value(
						value: OpenInNewTabZone(
							hashCode: 0,
							onWantOpenThreadInNewTab: (imageboardKey, thread, {bool incognito = false, bool activate = true, int? initialPostId, String? initiallyHintArchive}) => _tabs.addNewTab(
								withImageboardKey: imageboardKey,
								withBoard: thread.board,
								withThreadId: thread.id,
								withInitialPostId: initialPostId,
								initiallyHintArchive: initiallyHintArchive,
								activate: activate,
								incognito: incognito
							)
						)
					)
				],
				child: SavedPage(
					masterDetailKey: _tabs._savedMasterDetailKey,
					initialThreadWatch: switch (_tabs._savedFakeTab.thread) {
						ThreadIdentifier thread => switch (_tabs._savedFakeTab.imageboard?.persistence.browserState.threadWatches[thread]) {
							ThreadWatch watch => _tabs._savedFakeTab.imageboard?.scope(watch),
							null => null
						},
						null => null
					}
				)
			);
		}
		else if (index == 2) {
			child = Provider.value(
				value: OpenInNewTabZone(
					hashCode: 0,
					onWantOpenThreadInNewTab: (imageboardKey, thread, {bool incognito = false, bool activate = true, int? initialPostId, String? initiallyHintArchive}) => _tabs.addNewTab(
						withImageboardKey: imageboardKey,
						withBoard: thread.board,
						withThreadId: thread.id,
						withInitialPostId: initialPostId,
						initiallyHintArchive: initiallyHintArchive,
						activate: activate,
						incognito: incognito
					)
				),
				child: HistoryPage(
					key: _tabs._historyPageKey
				)
			);
		}
		else if (index == 3) {
			child = Provider.value(
				value: OpenInNewTabZone(
					hashCode: 0,
					onWantOpenThreadInNewTab: (imageboardKey, thread, {bool incognito = false, bool activate = true, int? initialPostId, String? initiallyHintArchive}) => _tabs.addNewTab(
						withImageboardKey: imageboardKey,
						withBoard: thread.board,
						withThreadId: thread.id,
						withInitialPostId: initialPostId,
						initiallyHintArchive: initiallyHintArchive,
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
							hashCode: 0,
							onWantOpenThreadInNewTab: (imageboardKey, thread, {bool incognito = false, bool activate = true, int? initialPostId, String? initiallyHintArchive}) => _tabs.addNewTab(
								withImageboardKey: imageboardKey,
								withBoard: thread.board,
								withThreadId: thread.id,
								withInitialPostId: initialPostId,
								initiallyHintArchive: initiallyHintArchive,
								activate: activate,
								incognito: incognito
							)
						),
						child: ImageboardScope(
							imageboardKey: devImageboard?.key,
							child: ChangeNotifierProvider.value(
								value: _tabs._devFakeTab,
								child: ClipRect(
									child: PrimaryScrollControllerInjectingNavigator(
										navigatorKey: _tabs._settingsNavigatorKey,
										observers: [
											HeroController(),
											ScrollTrackerNavigatorObserver()
										],
										buildRoot: (context) => SettingsPage(
											key: _tabs._settingsPageKey
										),
										buildInitialAboveRoot: switch ((_tabs._devFakeTab.thread, _tabs._devFakeTab.board)) {
											(ThreadIdentifier thread, _) => ((context) =>
													ThreadPage(
														thread: thread,
														initialPostId: _tabs._devFakeTab.initialPostId[thread],
														boardSemanticId: -1,
													), (_) {}, (builder, settings) => adaptivePageRoute(
														builder: builder,
														settings: settings,
														showAnimationsForward: false
													)),
											(_, String board) => ((context) =>
													BoardPage(
														initialBoard: devImageboard!.persistence.getBoard(board),
														allowChangingBoard: false,
														semanticId: -1
													), (_) {}, (builder, settings) => adaptivePageRoute(
														builder: builder,
														settings: settings,
														showAnimationsForward: false
													)),
											_ => null
										},
									)
								)
							)
						)
					)
				);
			}
		}
		return Provider.value(
			value: _tabs._willPopZones.putIfAbsent(index, () => WillPopZone()),
			child: KeyedSubtree(
				key: _keys.putIfAbsent(index, () => GlobalKey(debugLabel: '_keys[$index]')),
				child: child
			)
		);
	}

	double _tabletTabPreferredContentExtent(BuildContext context, String? label, bool hasPreLabelInjection) {
		if (label == null) return 24;
		final painter = TextPainter(
			text: TextSpan(text: label, style: DefaultTextStyle.of(context).style.copyWith(fontSize: 12)),
			textDirection: Directionality.of(context),
			textScaler: MediaQuery.textScalerOf(context),
			maxLines: 1
		)..layout();
		final extent = max(24.0, painter.width + (hasPreLabelInjection ? 28 : 0));
		painter.dispose();
		return extent;
	}

	AxisDirection _tabMenuDirection(BuildContext context, Axis axis) {
		if (axis == Axis.horizontal) return AxisDirection.up;
		return context.watch<DuoLayout?>()?.side == AxisDirection.right ? AxisDirection.left : AxisDirection.right;
	}

	Widget _buildTabletIcon(int index, Widget icon, String? label, {
		Axis axis = Axis.vertical,
		EdgeInsets iconPadding = EdgeInsets.zero,
		Widget? preLabelInjection,
		VoidCallback? onPressed
	}) {
		final content = AnimatedBuilder(
			animation: _tabs._tabController,
			builder: (context, _) {
				final labelRow = label == null ? null : Row(
					mainAxisSize: MainAxisSize.min,
					mainAxisAlignment: axis == Axis.vertical ? MainAxisAlignment.start : MainAxisAlignment.center,
					children: [
						if (preLabelInjection != null) ...[
							preLabelInjection,
							const SizedBox(width: 4)
						],
						const Text('', style: TextStyle(fontSize: 15)),
						Flexible(
							child: AutoSizeText(
								label,
								style: const TextStyle(fontSize: 15),
								maxLines: 1,
								stepGranularity: 0.1,
								overflow: TextOverflow.ellipsis,
								textAlign: axis == Axis.vertical ? TextAlign.left : TextAlign.center,
								minFontSize: switch (axis) {
									Axis.vertical => 11,
									Axis.horizontal => 12
								},
							)
						)
					]
				);
				final selected = (index <= 0 ? (_tabs.mainTabIndex == 0 && index == -1 * _tabs.activeBrowserTab.value) : index == _tabs.mainTabIndex);
				return Opacity(
					opacity: selected ? 1.0 : 0.5,
					child: Column(
						mainAxisAlignment: MainAxisAlignment.center,
						mainAxisSize: MainAxisSize.min,
						children: [
							if (axis == Axis.horizontal) Flexible(child: icon)
							else Padding(padding: iconPadding, child: icon),
							if (label != null) ...[
								const SizedBox(height: 4),
								if (axis == Axis.vertical) SidebarTabLabel(
									// The button already supplies 8px horizontal padding.
									contentPadding: EdgeInsets.only(left: max(0, iconPadding.left - 8), right: max(0, iconPadding.right - 8)),
									child: labelRow!
								)
								else labelRow!
							]
						]
					)
				);
			}
		);
		return Builder(
			builder: (context) {
				final menuDirection = _tabMenuDirection(context, axis);
				final horizontalSwipeSign = menuDirection == AxisDirection.left ? -1.0 : 1.0;
				final selectedItemDelta = axis == Axis.horizontal ? PaginatedReorderableListItem.selectedItemDeltaOf(context) : null;
				final shrinkWeights = switch (selectedItemDelta) {
					1 => const Offset(1, 0),
					-1 => const Offset(0, 1),
					null => Offset.zero,
					_ => const Offset(1, 1)
				};
				final preferredContentExtent = axis == Axis.horizontal ? _tabletTabPreferredContentExtent(context, label, preLabelInjection != null) : 0.0;
				final paddedContent = axis == Axis.horizontal ? TweenAnimationBuilder<Offset>(
					tween: Tween(begin: shrinkWeights, end: shrinkWeights),
					duration: const Duration(milliseconds: 350),
					curve: Curves.ease,
					builder: (context, weights, child) => PaginatedReorderableListItemPadding(
						preferredContentExtent: preferredContentExtent,
						shrinkWeights: weights,
						child: child!
					),
					child: content
				) : content;
				void showThisTabMenu() {
					showTabMenu(
						context: context,
						direction: menuDirection,
						titles: Axis.vertical,
						origin: context.globalSemanticBounds!,
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
						if (index <= 0 && axis == Axis.horizontal) WeakVerticalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<WeakVerticalDragGestureRecognizer>(
							() => WeakVerticalDragGestureRecognizer(debugOwner: this, weakness: 2, sign: -1),
							(recognizer) {
								recognizer.onEnd = (details) {
									if ((details.primaryVelocity ?? 0) >= 0) {
										// Not an up swipe
										return;
									}
									lightHapticFeedback();
									showThisTabMenu();
								};
							}
						),
						if (index <= 0 && axis == Axis.vertical) WeakHorizontalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<WeakHorizontalDragGestureRecognizer>(
							() => WeakHorizontalDragGestureRecognizer(debugOwner: this, weakness: 2),
							(recognizer) {
								recognizer.sign = horizontalSwipeSign;
								recognizer.onEnd = (details) {
									if ((details.primaryVelocity ?? 0) * horizontalSwipeSign <= 0) {
										// Not a swipe toward the content
										return;
									}
									lightHapticFeedback();
									showThisTabMenu();
								};
							}
						)
					},
					child: AdaptiveButton(
						padding: axis == Axis.vertical ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3) : EdgeInsets.zero,
						onPressed: onPressed ?? () async {
							lightHapticFeedback();
							if (index <= 0) {
								if (_tabs.browseTabIndex == -1 * index && _tabs.mainTabIndex == 0) {
									showThisTabMenu();
								}
								else {
									_tabs.browseTabIndex = -1 * index;
									if (Persistence.settings.closeTabSwitcherAfterUse) {
										_showTabPopup.value = false;
									}
								}
								_tabs.mainTabIndex = 0;
							}
							else {
								await _tabs.willActivatePane(index);
								_tabs.mainTabIndex = index;
							}
						},
						child: paddedContent
					)
				);
			}
		);
	}

	Widget _buildNewTabIcon({required Axis axis, bool hideLabel = false}) {
		return Builder(
			builder: (context) {
				void showMenu() {
					_tabs.showNewTabPopup(
						context: context,
						direction: AxisDirection.up,
						titles: Axis.vertical
					);
				}
				return SizedBox(
					width: axis == Axis.vertical ? double.infinity : null,
					child: GestureDetector(
						onVerticalDragEnd: (details) {
							if ((details.primaryVelocity ?? 0) < 0) showMenu();
						},
						onLongPress: showMenu,
						child: AdaptiveButton(
							padding: axis == Axis.vertical ? const EdgeInsets.symmetric(horizontal: 16, vertical: _sidebarButtonVerticalPadding) : const EdgeInsets.all(16),
							child: Opacity(
								opacity: 0.5,
								child: FittedBox(
									child: Column(
										mainAxisSize: MainAxisSize.min,
										children: [
											const Icon(CupertinoIcons.add),
											if (!hideLabel) ...[
												const SizedBox(height: 4),
												const Text(" New ", style: TextStyle(fontSize: 15))
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
					)
				);
			}
		);
	}

	Widget _buildTabList(Axis axis, ValueListenable<bool> isShowing, {double topPadding = 0, double bottomPadding = 0, EdgeInsets? targetPadding, double obscuredExtent = 0, bool floatingControls = false, EdgeInsets iconPadding = EdgeInsets.zero}) {
		final usingHomeBoard = Settings.instance.usingHomeBoard;
		final usePaginatedTabBar = Settings.instance.usePaginatedTabBar;
		buildTabIcon(int i) => ValueListenableBuilder(
			valueListenable: isShowing,
			builder: (context, showing, child) {
				return TickerMode(
					enabled: showing,
					child: child!
				);
			},
			child: TabWidgetBuilder(
				tab: Persistence.tabs[i],
				builder: (context, data) => DecoratedBox(
					decoration: BoxDecoration(
						color: (_tabs.mainTabIndex == 0 && _tabs.browseTabIndex == i)
											// Don't set color if selected, it will break boxShadow
											? null
											: (usingHomeBoard && i == 0
													? ChanceTheme.primaryColorWithBrightness30Of(context)
													: (data.isArchived ? ChanceTheme.primaryColorWithBrightness10Of(context) : null)
											),
						boxShadow: (_tabs.mainTabIndex == 0 && _tabs.browseTabIndex == i) ? [
							BoxShadow(
								color: ChanceTheme.primaryColorOf(context).withValues(
									alpha: usingHomeBoard && i == 0
													? 0.4
													: (data.isArchived ? 0.3 : 0.2)
								)
							),
							BoxShadow(
								color: usingHomeBoard && i == 0
												? ChanceTheme.primaryColorWithBrightness30Of(context)
												: (data.isArchived ? ChanceTheme.primaryColorWithBrightness10Of(context) : ChanceTheme.barColorOf(context)),
								spreadRadius: 0,
								blurRadius: 24
							),
						] : [],
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
						iconPadding: iconPadding,
						preLabelInjection: data.secondaryIcon
					)
				)
			)
		);
		return Flex(
			direction: axis,
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				if (usingHomeBoard) buildTabIcon(0),
				Expanded(
					child: usePaginatedTabBar ? PaginatedReorderableList(
						key: _paginatedTabListKey,
						controller: _tabs._paginatedTabListController,
						physics: const FasterSnappingPageScrollPhysics(),
						paginationDelegate: axis == Axis.vertical ? ChanTabs._sidebarTabListPaginationDelegate : ChanTabs._tabListPaginationDelegate,
						// Floating controls provide the bleed; other layouts retain the half-tab peek.
						gutterExtent: floatingControls ? 0 : 0.5,
						leadingGutterExtent: floatingControls || topPadding > 0 ? 0 : 0.5,
						padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
						targetPadding: targetPadding,
						obscuredExtent: obscuredExtent,
						pageSnapping: obscuredExtent == 0,
						pageIndicatorPadding: EdgeInsets.fromLTRB(12 + iconPadding.left, 12 + topPadding, 12 + iconPadding.right, 12 + bottomPadding),
						allowTrailingAlignmentOverpull: obscuredExtent == 0,
						initialPagesAlignedToEnd: Settings.tabBarPagesAlignedToEndSetting.read(context),
						onPagesAlignedToEndChanged: (value) {
							Settings.tabBarPagesAlignedToEndSetting.write(context, value);
						},
						selectedItemExtentFactor: axis == Axis.vertical ? 1 : 2,
						selectedIndex: switch ((usingHomeBoard, _tabs.browseTabIndex)) {
							(true, 0) => null,
							(true, int i) => i - 1,
							(false, int i) => i
						},
						scrollDirection: axis,
						onReorderItem: _tabs.onReorderItem,
						itemCount: usingHomeBoard ? Persistence.tabs.length - 1 : Persistence.tabs.length,
						itemBuilder: (context, index) {
							final i = usingHomeBoard ? index + 1 : index;
							return PaginatedReorderableListItem(
								key: _tabs._tabButtonKeys.putIfAbsent(i, () => GlobalKey(debugLabel: '_tabs._tabButtonKeys[$i]')),
								index: index,
								child: ReorderableDelayedDragStartListener(
									index: index,
									child: buildTabIcon(i)
								)
							);
						}
					) : ReorderableList(
						padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
						controller: _tabs._legacyTabListController,
						scrollDirection: axis,
						onReorderItem: _tabs.onReorderItem,
						itemCount: usingHomeBoard ? Persistence.tabs.length - 1 : Persistence.tabs.length,
						itemBuilder: (context, index) {
							final i = usingHomeBoard ? index + 1 : index;
							return ReorderableDelayedDragStartListener(
								index: index,
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

	void _popUpDrawer() {
		Navigator.push(context, TransparentRoute(
			builder: (context) => ChangeNotifierProvider.value(
				value: _tabs,
				child: const TabsPage()
			)
		));
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
		if (_floatingTabControlsKey.currentState?.collapse() ?? false) return;
		closeAllOpenTabMenus();
		if (_drawerScaffoldKey.currentState?.isDrawerOpen ?? false) {
			_drawerScaffoldKey.currentState?.closeDrawer();
			// Closed the side drawer
		}
		else if (_tabs.mainTabIndex == 4 && (await _tabs._settingsNavigatorKey.currentState?.maybePop() ?? false)) {
			// Popped something in Settings page
		}
		else if (await _tabs._willPopZones[_tabs.mainTabIndex]?.maybePop?.call() ?? false) {
			// Popped something generically
		}
		else if (await _tabs._tabNavigatorKeys[_tabs.mainTabIndex]?.currentState?.maybePop() ?? false) {
			// Popped something on the CupertinoTabView (this shouldn't happen)
		}
		else if (_tabs.mainTabIndex != 0) {
			_tabs.mainTabIndex = 0;
			// Returned to the browse pane
		}
		else if (Platform.isAndroid && await confirmExit()) {
			await SystemNavigator.pop();
			// Exited the app
		}
	}

	double _duoBarWidth = 85 * Settings.instance.interfaceScale;

	bool get androidDrawer => Settings.androidDrawerSetting.watch(context);

	bool get persistentDrawer {
		return androidDrawer && navigationSidebarWidthOf(context) > 0;
	}

	double get persistentDrawerWidth {
		return navigationSidebarWidthOf(context);
	}

	@override
	Widget build(BuildContext context) {
		if (!ImageboardRegistry.instance.initialized || _authenticationStatus == _AuthenticationStatus.inProgress || !_tabs.initialized) {
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
		final notificationErrors = context.watch<ImageboardRegistry>().notificationErrors;
		final filterError = context.select<Settings, String?>((s) => s.filterError);
		final androidDrawer = this.androidDrawer;
		final persistentDrawer = this.persistentDrawer;
		final layout = context.watch<DuoLayout?>();
		final duo = androidDrawer || layout?.hasSidebar != true ? null : layout;
		final interfaceScale = Settings.interfaceScaleSetting.watch(context);
		final barWidth = 85 * interfaceScale;
		if (_duoBarWidth != barWidth) {
			_duoBarWidth = barWidth;
			configureDuoLayout(barWidth: barWidth);
		}
		final sidebarPadding = (duo?.padding ?? EdgeInsets.zero) / interfaceScale;
		final sidebarIconPadding = EdgeInsets.only(left: sidebarPadding.left, right: sidebarPadding.right);
		final sidebarIconOffset = (sidebarPadding.left - sidebarPadding.right) / 2;
		final wideScreen = isScreenWide(context);
		Widget child = (androidDrawer || wideScreen) ? NotificationListener2<ScrollNotification, ScrollMetricsNotification>(
			onNotification: ScrollTracker.instance.onNotification,
			child: Actions(
				actions: {
					ExtendSelectionToLineBreakIntent: CallbackAction<ExtendSelectionToLineBreakIntent>(
						onInvoke: (intent) {
							if ((FocusManager.instance.primaryFocus?.rect.height ?? 0) < (MediaQuery.sizeOf(context).height * 0.75)) {
								// Likely a text field is focused
								return;
							}
							_tabs._willPopZones[_tabs.mainTabIndex]?.maybePop?.call();
							return null;
						}
					)
				},
				child: DescendantNavigatorPopScope(
					canPop: () => false, // confirmExit always blocks
					onPopInvokedWithResult: (didPop, result) {
						if (didPop) {
							return;
						}
						_backButton();
					},
					child: AdaptiveScaffold(
						key: _drawerScaffoldKey,
						drawer: (androidDrawer && !persistentDrawer) ? const ChanceDrawer(persistent: false) : null,
						resizeToAvoidBottomInset: !wideScreen,
						body: TransformedMediaQuery(
							transformation: (context, mq) => wideScreen ? mq.copyWith(
								padding: EdgeInsets.only(
									right: duo?.side == AxisDirection.right ? 0 : max(mq.viewPadding.right, mq.viewInsets.right),
									top: max(mq.viewPadding.top, mq.viewInsets.top),
									left: duo?.side == AxisDirection.left ? 0 : max(mq.viewPadding.left, mq.viewInsets.left),
									bottom: max(mq.viewPadding.bottom, mq.viewInsets.bottom),
								),
								viewPadding: (mq.viewPadding + mq.viewInsets).copyWith(
									left: duo?.side == AxisDirection.left ? 0 : null,
									right: duo?.side == AxisDirection.right ? 0 : null
								),
								viewInsets: EdgeInsets.zero
							) : mq,
							child: Builder(
								builder: (context) => SafeArea(
									left: duo?.side != AxisDirection.left,
									right: duo?.side != AxisDirection.right,
									top: false,
									bottom: false,
									child: Row(
										textDirection: duo?.side == AxisDirection.right ? TextDirection.rtl : TextDirection.ltr,
										children: [
											if (!androidDrawer || persistentDrawer) Container(
												color: ChanceTheme.barColorOf(context),
												width: persistentDrawer ? persistentDrawerWidth : 85,
												child: persistentDrawer ? const ChanceDrawer(
													persistent: true
												) : Builder(
													builder: (context) {
														final padding = MediaQuery.paddingOf(context);
														final targetTopPadding = duo == null ? padding.top : sidebarPadding.top;
														final safeBottomPadding = duo == null ? MediaQuery.viewPaddingOf(this.context).bottom : sidebarPadding.bottom;
														final bottomPadding = max(safeBottomPadding, MediaQuery.viewInsetsOf(this.context).bottom);
														final obscuredExtent = bottomPadding - safeBottomPadding;
														// System bar and keyboard insets should not change the controls' layout mode.
														final screenHeight = MediaQuery.sizeOf(context).height;
														final bleedUnderStatus = duo != null && targetTopPadding > 0 && Settings.usePaginatedTabBarSetting.watch(context) && !context.select<Settings, bool>((s) => s.usingHomeBoard);
														final hideTabletLayoutLabels = screenHeight < 800;
														// Icon (24), vertical padding (20), and optional label plus gap (22).
														final estimatedButtonHeight = 24 + 2 * _sidebarButtonVerticalPadding + (hideTabletLayoutLabels ? 0 : 22);
														Future<void> activatePane(int index) async {
															lightHapticFeedback();
															await _tabs.willActivatePane(index);
															if (!mounted) return;
															_tabs.mainTabIndex = index;
														}
														final sidebarActions = <int, TabMenuAction>{
															1: TabMenuAction(
																icon: Adaptive.icons.bookmark,
																title: 'Saved',
																isSelected: _tabs.mainTabIndex == 1,
																onPressed: () => activatePane(1),
																primaryCount: CombiningValueListenable<int>(
																	children: ImageboardRegistry.instance.imageboards.map((x) => x.threadWatcher.unseenYouCount).toList(),
																	combine: (list) => list.fold(0, (a, b) => a + b)
																),
																secondaryCount: CombiningValueListenable<int>(
																	children: ImageboardRegistry.instance.imageboards.map((x) => x.threadWatcher.unseenCount).toList(),
																	combine: (list) => list.fold(0, (a, b) => a + b)
																)
															),
															2: TabMenuAction(
																icon: Settings.recordThreadsInHistorySetting.watch(context) ? CupertinoIcons.archivebox : CupertinoIcons.eye_slash,
																title: 'History',
																isSelected: _tabs.mainTabIndex == 2,
																onPressed: () => activatePane(2),
																onLongPress: _toggleHistory
															),
															3: TabMenuAction(
																icon: CupertinoIcons.search,
																title: 'Search',
																isSelected: _tabs.mainTabIndex == 3,
																onPressed: () => activatePane(3)
															),
															4: TabMenuAction(
																icon: CupertinoIcons.settings,
																title: 'Settings',
																isSelected: _tabs.mainTabIndex == 4,
																onPressed: () => activatePane(4),
																onLongPress: () => Settings.instance.runQuickAction(context),
																color: (notificationErrors.isNotEmpty || filterError != null) ? Colors.red : null,
																primaryCount: devImageboard?.threadWatcher.unseenYouCount ?? zeroValueNotifier,
																secondaryCount: devImageboard?.threadWatcher.unseenCount ?? zeroValueNotifier
															)
														};
														Widget buildMenuIcon(bool expanded) => NotifyingIcon(
															constrainBadge: true,
															showBadge: !expanded,
															badgeAnimationDuration: const Duration(milliseconds: 250),
															icon: Icon(expanded ? CupertinoIcons.chevron_down : (sidebarActions[_tabs.mainTabIndex]?.icon ?? CupertinoIcons.ellipsis), color: sidebarActions.values.map((action) => action.color).whereType<Color>().firstOrNull),
															primaryCount: CombiningValueListenable<int>(
																children: sidebarActions.values.map((action) => action.primaryCount).whereType<ValueListenable<int>>().toList(),
																combine: (list) => list.fold(0, (a, b) => a + b)
															),
															secondaryCount: CombiningValueListenable<int>(
																children: sidebarActions.values.map((action) => action.secondaryCount).whereType<ValueListenable<int>>().toList(),
																combine: (list) => list.fold(0, (a, b) => a + b)
															)
														);
														final showNavigation = screenHeight >= 700;
														final controlsExtent = FloatingTabControls.restingExtent(estimatedButtonHeight, showNavigation ? sidebarActions.length : 1) + FloatingTabControls.inset;
														final targetClearance = EdgeInsets.only(top: targetTopPadding, bottom: controlsExtent);
														return TweenAnimationBuilder<EdgeInsets>(
															key: ValueKey(duo?.side),
															tween: EdgeInsetsTween(begin: targetClearance, end: targetClearance),
															duration: duo == null || MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 250),
															curve: Curves.easeInOutCubic,
															child: Align(
																alignment: Alignment.bottomCenter,
																child: AnimatedBuilder(
																	animation: _tabs._tabController,
																	builder: (context, _) => FloatingTabControls(
																		key: _floatingTabControlsKey,
																		navigationActions: sidebarActions.values.toList(),
																		newTabActions: _tabs.newTabActions(context),
																		menuIconBuilder: buildMenuIcon,
																		onNewTab: () { lightHapticFeedback(); _tabs.addNewTab(activate: true); },
																		onQuickAction: sidebarActions[4]!.onLongPress,
																		buttonExtent: estimatedButtonHeight,
																		showLabels: !hideTabletLayoutLabels,
																		showNavigation: showNavigation
																	)
																)
															),
															builder: (context, clearance, controls) {
																final topPadding = clearance.top;
																return Stack(children: [
																	Positioned.fill(
																		bottom: bottomPadding,
																		child: Padding(
																			padding: EdgeInsets.only(top: bleedUnderStatus ? 0 : topPadding),
																			child: AnimatedBuilder(
																				animation: _tabListChanges,
																				builder: (context, _) => _buildTabList(
																					Axis.vertical, const StoppedValueListenable(true),
																					topPadding: bleedUnderStatus ? topPadding : 0,
																					bottomPadding: clearance.bottom,
																					targetPadding: EdgeInsets.only(top: bleedUnderStatus ? targetTopPadding : 0, bottom: controlsExtent),
																					obscuredExtent: obscuredExtent,
																					floatingControls: true,
																					iconPadding: sidebarIconPadding
																				)
																			)
																		)
																	),
																	Positioned(
																		left: FloatingTabControls.horizontalInset + sidebarIconOffset,
																		right: FloatingTabControls.horizontalInset - sidebarIconOffset,
																		top: topPadding + FloatingTabControls.inset,
																		bottom: bottomPadding + FloatingTabControls.inset,
																		child: controls!
																	)
																]);
															}
														);
													}
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
													builder: (context, _) => Stack(children: [
														Positioned.fill(child: SwitchingView(
															currentIndex: _tabs.mainTabIndex,
															items: const [0, 1, 2, 3, 4],
															builder: (i) => _buildTab(i)
														)),
														if (!androidDrawer && Settings.swipeGesturesOnBottomBarSetting.watch(context)) Positioned(
															left: 0,
															right: 0,
															bottom: MediaQuery.paddingOf(context).bottom,
															height: _bottomBarHeight,
															child: GestureDetector(
																behavior: HitTestBehavior.translucent,
																onHorizontalDragStart: (details) {
																	_skipSidebarTabSwipe = eventTooCloseToEdge(details.globalPosition);
																},
																onHorizontalDragEnd: (details) {
																	if (_skipSidebarTabSwipe || !Settings.instance.swipeGesturesOnBottomBar) return;
																	final velocity = details.primaryVelocity ?? 0;
																	if (velocity != 0) _swipeTab(velocity > 0 ? -1 : 1);
																},
																child: const SizedBox.expand()
															)
														)
													])
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
					onPopInvokedWithResult: (didPop, result) {
						if (didPop) {
							return;
						}
						_backButton();
					},
					child: ValueListenableBuilder(
						valueListenable: _visibleTabPopup,
						builder: (context, showTabPopup, child) {
							final theme = context.watch<SavedTheme>();
							return DecoratedBox(
								decoration: BoxDecoration(
									color: showTabPopup ? theme.barColor : theme.backgroundColor
								),
								child: child
							);
						},
						child: CupertinoTabScaffold(
							controller: _tabs._tabController,
							tabBar: ChanceCupertinoTabBar(
								visible: !androidDrawer,
								height: androidDrawer ? 0 : _bottomBarHeight,
								inactiveColor: ChanceTheme.primaryColorOf(context).withValues(alpha: 0.4),
								items: [
									BottomNavigationBarItem(
										icon: GestureDetector(
											onLongPress: () {
												mediumHapticFeedback();
												_popUpDrawer();
											},
											child: AnimatedBuilder(
												animation: _tabs.browseCountListenable,
												builder: (context, child) => StationaryNotifyingIcon(
													icon: const Icon(CupertinoIcons.rectangle_stack, size: 28),
													primary: (Persistence.tabs.length == 1) ? 0 : Persistence.tabs.asMap().entries.where((x) => x.key != _tabs.browseTabIndex || _tabs.mainTabIndex > 0).map((x) => x.value.unseenYous.value).reduce((a, b) => a + b),
													secondary: (Persistence.tabs.length == 1) ? 0 : Persistence.tabs.asMap().entries.where((x) => x.key != _tabs.browseTabIndex || _tabs.mainTabIndex > 0).map((x) => x.value.unseen.value).reduce((a, b) => a + b)
												)
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
												icon: Icon(
													CupertinoIcons.settings,
													size: 28,
													color: (notificationErrors.isNotEmpty || filterError != null) ? Colors.red : null
												),
												primaryCount: devImageboard?.threadWatcher.unseenYouCount ?? zeroValueNotifier,
												secondaryCount: devImageboard?.threadWatcher.unseenCount ?? zeroValueNotifier
											)
										),
										label: 'Settings'
									)
								],
								onUpSwipe: () {
									if (_tabs.mainTabIndex != 0) {
										return;
									}
									mediumHapticFeedback();
									if (_showTabPopup.value) {
										_popUpDrawer();
										return;
									}
									_showTabPopup.value = true;
								},
								onDownSwipe: () {
									if (!_showTabPopup.value || _tabs.mainTabIndex != 0) {
										return;
									}
									mediumHapticFeedback();
									_showTabPopup.value = false;
								},
								onLeftSwipe: () => _swipeTab(-1),
								onRightSwipe: () => _swipeTab(1),
								beforeCopiedOnTap: (index) async {},
								onTap: (index) {
									lightHapticFeedback();
									if (index == _tabs._lastIndex && index == 0) {
										_showTabPopup.value = !_showTabPopup.value;
									}
									else {
										_tabs.willActivatePane(index);
									}
									_tabs._lastIndex = index;
								}
							),
							backgroundColor: Colors.transparent,
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
														final child = _buildTab(index);
														if (Settings.materialStyleSetting.watch(context)) {
															return Material(
																child: child
															);
														}
														return child;
													}
												)
											),
											if (index == 0) ValueListenableBuilder(
												valueListenable: _visibleTabPopup,
												builder: (context, showTabPopup, _) => Expander(
													bottomSafe: true,
													expanded: showTabPopup,
													duration: const Duration(milliseconds: 200),
													curve: Curves.ease,
													child: const SizedBox(height: 80)
												)
											)
										]
									),
									if (index == 0) Column(
										mainAxisAlignment: MainAxisAlignment.end,
										children: [
											ValueListenableBuilder(
												valueListenable: _visibleTabPopup,
												builder: (context, showTabPopup, child) => Expander(
													bottomSafe: false,
													keepTickersEnabledWhenCollapsed: true,
													expanded: showTabPopup,
													duration: const Duration(milliseconds: 200),
													curve: Curves.ease,
													child: child!
												),
												child: RawGestureDetector(
													behavior: HitTestBehavior.translucent,
													gestures: {
														WeakVerticalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<WeakVerticalDragGestureRecognizer>(
															() => WeakVerticalDragGestureRecognizer(debugOwner: this, weakness: 1, sign: 1),
															(recognizer) {
																recognizer.onEnd = (details) {
																	if (details.velocity.pixelsPerSecond.dy > 0 && _showTabPopup.value) {
																		mediumHapticFeedback();
																		_showTabPopup.value = false;
																	}
																};
															}
														)
													},
													child: Container(
														color: ChanceTheme.barColorOf(context),
														height: 80,
														child: Row(
															children: [
																Expanded(
																	child: AnimatedBuilder(
																	animation: _tabListChanges,
																		builder: (context, _) => Selector<Settings, bool>(
																			selector: (context, settings) => settings.usingHomeBoard,
																			builder: (context, _, __) => _buildTabList(Axis.horizontal, _visibleTabPopup)
																		)
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
			)
		);
		child = NotificationsOverlay(
			onePane: !wideScreen,
			key: notificationsOverlayKey,
			imageboards: [
				...ImageboardRegistry.instance.imageboards,
				if (devImageboard?.initialized ?? false) devImageboard!
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
								paths.add((await datum.dropFile!.rename('${Persistence.temporaryDirectory.path}/${datum.dropFile!.basename}')).path);
							}
							else {
								paths.add(datum.dropFile!.path);
							}
						}
						else if (datum.dropText != null) {
							_tabs._consumeLink(datum.dropText);
						}
					}
					if (paths.isNotEmpty) {
						_tabs._consumeFiles(paths);
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
		// The whole NavigationNotification system seems a bit broken right now.
		// I think multiple parallel Navigators are overwriting each other
		// Just override it here
		child = NotificationListener(
			onNotification: (notification) {
				const NavigationNotification nextNotification = NavigationNotification(
					canHandlePop: true
				);
				nextNotification.dispatch(context);
				return true;
			},
			child: child
		);
		return child;
	}

	@override
	void dispose() {
		super.dispose();
		_tabs.removeListener(_tabsListener);
		_tabs.dispose();
		_visibleTabPopup.removeListener(_setAdditionalSafeAreaInsets);
		ScrollTracker.instance.slowScrollDirection.removeListener(_onSlowScrollDirectionChange);
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
			child: Settings.hideBarsWhenScrollingDownSetting.watch(context) ? ValueListenableBuilder(
				valueListenable: ScrollTracker.instance.tabPopupHidden,
				builder: (context, hidden, child) => AncestorScrollBuilder(
					builder: (context, direction, _) {
						final show = !hidden && direction == VerticalDirection.up;
						return AnimatedOpacity(
							opacity: show ? 1.0 : 0.0,
							duration: const Duration(milliseconds: 350),
							curve: Curves.ease,
							child: IgnorePointer(ignoring: !show, child: child)
						);
					}
				),
				child: SafeArea(
					top: false,
					bottom: false,
					child: super.build(context)
				)
			) : SafeArea(
				top: false,
				bottom: false,
				child: super.build(context)
			)
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

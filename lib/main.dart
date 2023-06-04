import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:chan/firebase_options.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/search.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/history.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/search.dart';
import 'package:chan/pages/settings.dart';
import 'package:chan/pages/saved.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/apple.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/notifications.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/pick_attachment.dart';
import 'package:chan/services/rlimit.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/share.dart';
import 'package:chan/services/streaming_mp4.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/version.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/cupertino_dialog.dart';
import 'package:chan/widgets/cupertino_page_route.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/injecting_navigator.dart';
import 'package:chan/widgets/notifications_overlay.dart';
import 'package:chan/widgets/notifying_icon.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:chan/widgets/saved_theme_thumbnail.dart';
import 'package:chan/widgets/tab_menu.dart';
import 'package:chan/widgets/tab_switching_view.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:local_auth/local_auth.dart';
import 'package:native_drag_n_drop/native_drag_n_drop.dart';
import 'package:rxdart/subjects.dart';
import 'package:url_launcher/url_launcher.dart';
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
			final webmcache = await Directory('${Persistence.temporaryDirectory.path}/webmcache').create(recursive: true);
			final oldHttpCache = Directory('${webmcache.path}/httpcache');
			if (oldHttpCache.statSync().type == FileSystemEntityType.directory) {
				await oldHttpCache.rename('${Persistence.temporaryDirectory.path}/httpcache');
			}
			final httpcache = await Directory('${Persistence.temporaryDirectory.path}/httpcache').create(recursive: true);
			VideoServer.initializeStatic(webmcache, httpcache);
			await Notifications.initializeStatic();
			await updateDynamicColors();
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
					child: ErrorMessageCard(
						'Sorry, an unrecoverable error has occured:\n${error.toStringDio()}\n$stackTrace',
						remedies: {
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
							}
						}
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

final settings = EffectiveSettings();
class _ChanAppState extends State<ChanApp> {
	late Map<String, dynamic> _lastSites;

	void _onImageboardRegistryUpdate() {
		setState(() {});
	}

	@override
	void initState() {
		super.initState();
		_lastSites = settings.contentSettings.sites;
		ImageboardRegistry.instance.addListener(_onImageboardRegistryUpdate);
		ImageboardRegistry.instance.handleSites(
			settings: settings,
			context: context,
			data: _lastSites
		);
		settings.addListener(_onSettingsUpdate);
	}

	@override
	void dispose() {
		super.dispose();
		ImageboardRegistry.instance.removeListener(_onImageboardRegistryUpdate);
		settings.removeListener(_onSettingsUpdate);
	}

	void _onSettingsUpdate() {
		if (settings.contentSettings.sites != _lastSites) {
			_lastSites = settings.contentSettings.sites;
			ImageboardRegistry.instance.handleSites(
				settings: settings,
				context: context,
				data: _lastSites
			);
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
					ProxyProvider<EffectiveSettings, SavedTheme>(
						update: (context, settings, result) => settings.theme
					),
					ProxyProvider<EffectiveSettings, ChanceThemeKey>(
						update: (context, settings, result) => ChanceThemeKey(settings.themeKey)
					)
				],
				child: SettingsSystemListener(
					child: MediaQuery.fromView(
						view: View.of(context),
						child: StickyMediaQuery(
							top: true,
							child: Builder(
								builder: (BuildContext context) {
									final settings = context.watch<EffectiveSettings>();
									final mq = MediaQuery.of(context);
									final additionalSafeAreaInsets = sumAdditionalSafeAreaInsets();
									return MediaQuery(
										data: mq.copyWith(
											boldText: false,
											textScaleFactor: mq.textScaleFactor * settings.textScale,
											padding: (mq.padding - additionalSafeAreaInsets).clamp(EdgeInsets.zero, EdgeInsetsGeometry.infinity).resolve(null),
											viewPadding: (mq.viewPadding - additionalSafeAreaInsets).clamp(EdgeInsets.zero, EdgeInsetsGeometry.infinity).resolve(null)
										),
										child: RootCustomScale(
											scale: ((Platform.isMacOS || Platform.isWindows || Platform.isLinux) ? 1.3 : 1.0) / settings.interfaceScale,
											child: FilterZone(
												filter: settings.globalFilter,
												child: CupertinoApp(
													title: 'Chance',
													debugShowCheckedModeBanner: false,
													theme: settings.theme.cupertinoThemeData,
													scrollBehavior: const CupertinoScrollBehavior().copyWith(
														physics: Platform.isAndroid ? const HybridScrollPhysics() :
															(isOnMac ? const BouncingScrollPhysics(decelerationRate: ScrollDecelerationRate.fast) : const BouncingScrollPhysics())
													),
													home: Builder(
														builder: (BuildContext context) {
															ImageboardRegistry.instance.context = context;
															return DefaultTextStyle(
																style: CupertinoTheme.of(context).textTheme.textStyle,
																child: ImageboardRegistry.instance.initialized ? Stack(
																	children: [
																		// For some unexplained reason this improves performance
																		// Maybe related to querying the framerate each frame?
																		Positioned(
																			top: 0,
																			left: 0,
																			right: 0,
																			child: PerformanceOverlay.allEnabled()
																		),
																		const ChanHomePage()
																	]
																) : Container(
																	color: ChanceTheme.backgroundColorOf(context),
																	child: Center(
																		child: ImageboardRegistry.instance.setupError != null ? ErrorMessageCard(ImageboardRegistry.instance.setupError!, remedies: {
																			if (ImageboardRegistry.instance.setupStackTrace != null) 'More details': () {
																				alertError(context, ImageboardRegistry.instance.setupStackTrace!);
																			},
																			'Resynchronize': () {
																				settings.updateContentSettings();
																			},
																			'Edit content preferences': () {
																				launchUrl(Uri.parse(settings.contentSettingsUrl), mode: LaunchMode.externalApplication);
																				settings.addAppResumeCallback(() async {
																					await Future.delayed(const Duration(seconds: 1));
																					settings.updateContentSettings();
																				});
																			}
																		}) : const ChanSplashPage()
																	)
																)
															);
														}
													),
													localizationsDelegates: const [
														DefaultCupertinoLocalizations.delegate,
														DefaultMaterialLocalizations.delegate
													]
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
							context.select<EffectiveSettings, double>((s) => s.interfaceScale)
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

final isScrolling = ValueNotifier(false);

enum _AuthenticationStatus {
	ok,
	inProgress,
	failed
}

class _ChanHomePageState extends State<ChanHomePage> {
	int _lastIndex = 0;
	final _keys = <int, GlobalKey>{};
	final _tabController = CupertinoTabController();
	bool _showTabPopup = false;
	late Listenable browseCountListenable;
	final activeBrowserTab = ValueNotifier<int>(0);
	final _tabListController = ScrollController();
	StreamSubscription<PostIdentifier>? _devNotificationsSubscription;
	Imageboard? devImageboard;
	final devTab = PersistentBrowserTab();
	final _tabNavigatorKeys = <int, GlobalKey<NavigatorState>>{};
	final _tabletWillPopZones = <int, WillPopZone>{};
	final _settingsNavigatorKey = GlobalKey<NavigatorState>();
	bool _queuedUpdateTabs = false;
	final _savedMasterDetailKey = GlobalKey<MultiMasterDetailPageState>();
	final PersistentBrowserTab _savedFakeTab = PersistentBrowserTab();
	final Map<String, ({Notifications notifications, StreamSubscription<PostIdentifier> subscription})> _notificationsSubscriptions = {};
	late StreamSubscription<String?> _linkSubscription;
	late StreamSubscription<String?> _fakeLinkSubscription;
	late StreamSubscription<List<SharedMediaFile>> _sharedFilesSubscription;
	late StreamSubscription<String> _sharedTextSubscription;
	final _searchPageKey = GlobalKey<SearchPageState>();
	final _historyPageKey = GlobalKey<HistoryPageState>();
	// Sometimes duplicate links are received due to use of multiple link handling packages
	({DateTime time, String link})? _lastLink;
	bool _hidTabPopupFromScroll = false;
	double _accumulatedScrollDelta = 0;
	bool _thisScrollHasDragDetails = false;
	_AuthenticationStatus _authenticationStatus = _AuthenticationStatus.ok;

	bool get showTabPopup => _showTabPopup;
	set showTabPopup(bool setting) {
		_showTabPopup = setting;
		_setAdditionalSafeAreaInsets();
	}

	void _didUpdateTabs() {
		if (isScrolling.value) {
			_queuedUpdateTabs = true;
		}
		else {
			Persistence.didUpdateTabs();
		}
	}

	bool _onScrollNotification(Notification notification) {
		if (notification is ScrollStartNotification) {
			isScrolling.value = true;
			_thisScrollHasDragDetails = false;
		}
		else if (notification is ScrollEndNotification) {
			isScrolling.value = false;
			if (_queuedUpdateTabs) {
				Persistence.didUpdateTabs();
			}
		}
		else if (settings.tabMenuHidesWhenScrollingDown && notification is ScrollUpdateNotification) {
			_thisScrollHasDragDetails |= notification.dragDetails != null;
			if (notification.metrics.axis == Axis.vertical && _thisScrollHasDragDetails && notification.metrics.extentAfter > 100) {
				_accumulatedScrollDelta += notification.scrollDelta ?? 0;
				_accumulatedScrollDelta = _accumulatedScrollDelta.clamp(-51, 51);
				if (_accumulatedScrollDelta > 50 && showTabPopup) {
					setState(() {
						_accumulatedScrollDelta = 0;
						showTabPopup = false;
						_hidTabPopupFromScroll = true;
					});
				}
				else if (_accumulatedScrollDelta < -50 && _hidTabPopupFromScroll) {
					setState(() {
						_accumulatedScrollDelta = 0;
						showTabPopup = true;
						_hidTabPopupFromScroll = false;
					});
				}
			}
		}
		return false;
	}

	void _onDevNotificationTapped(PostIdentifier id) async {
		_tabController.index = 4;
		_lastIndex = 4;
		if (showTabPopup) {
			setState(() {
				showTabPopup = false;
			});
		}
		for (int i = 0; i < 200 && _settingsNavigatorKey.currentState == null; i++) {
			await Future.delayed(const Duration(milliseconds: 50));
		}
		if (devTab.threadController?.items.tryFirst?.item.threadIdentifier != id.thread) {
			_settingsNavigatorKey.currentState?.popUntil((r) => r.isFirst);
			_settingsNavigatorKey.currentState?.push(
				FullWidthCupertinoPageRoute(
					builder: (context) => ThreadPage(
						thread: id.thread,
						initialPostId: id.postId,
						boardSemanticId: -1
					)
				)
			);
		}
		else if (id.postId != id.threadId) {
			try {
				await devTab.threadController?.animateTo((p) => p.id == id.postId);
			}
			on ItemNotFoundException {
				await devTab.threadController?.update();
				await Future.delayed(const Duration(milliseconds: 100));
				await devTab.threadController?.animateTo((p) => p.id == id.postId, orElseLast: (p) => true);
			}
		}
	}

	void _setupDevSite() async {
		final settings = context.read<EffectiveSettings>();
		final tmpDevImageboard = Imageboard(
			key: 'devsite',
			siteData: defaultSite,
			settings: settings,
			threadWatcherController: ThreadWatcherController(interval: const Duration(minutes: 10))
		);
		await tmpDevImageboard.initialize(
			threadWatcherWatchForStickyOnBoards: ['chance']
		);
		if (!mounted) {
			tmpDevImageboard.dispose();
			return;
		}
		_devNotificationsSubscription?.cancel();
		_devNotificationsSubscription = tmpDevImageboard.notifications.tapStream.listen(_onDevNotificationTapped);
		setState(() {
			devImageboard?.dispose();
			devImageboard = tmpDevImageboard;
		});
	}

	Future<void> _consumeLink(String? link) async {
		final settings = context.read<EffectiveSettings>();
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
					await showCupertinoDialog(
						context: context,
						barrierDismissible: true,
						builder: (dialogContext) => CupertinoAlertDialog2(
							title: Text('Import $name?'),
							content: DefaultTextStyle(
								style: DefaultTextStyle.of(context).style,
								child: Column(
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
								)
							),
							actions: [
								CupertinoDialogAction2(
									isDefaultAction: settings.whichTheme == Brightness.light,
									onPressed: settings.lightTheme == theme ? null : () {
										String effectiveName = name;
										if (match == null) {
											effectiveName = settings.addTheme(name, theme);
										}
										settings.lightThemeKey = match?.key ?? effectiveName;
										settings.handleThemesAltered();
										Navigator.of(dialogContext).pop();
									},
									child: const Text('Use as light theme')
								),
								CupertinoDialogAction2(
									isDefaultAction: settings.whichTheme == Brightness.dark,
									onPressed: settings.darkTheme == theme ? null : () {
										String effectiveName = name;
										if (match == null) {
											effectiveName = settings.addTheme(name, theme);
										}
										settings.darkThemeKey = match?.key ?? effectiveName;
										settings.handleThemesAltered();
										Navigator.of(dialogContext).pop();
									},
									child: const Text('Use as dark theme')
								),
								CupertinoDialogAction2(
									onPressed: match != null ? null : () {
										settings.addTheme(name, theme);
										settings.handleThemesAltered();
										Navigator.of(dialogContext).pop();
									},
									child: const Text('Just import')
								),
								CupertinoDialogAction2(
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
					alertError(context, 'Error adding theme: $e');
				}
			}
			else if (uri.pathSegments.length >= 2 && uri.pathSegments[1] == 'thread') {
				_addNewTab(
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
						final consent = await confirm(context, 'Add site $siteKey?');
						if (consent != true) {
							return;
						}
						final siteResponse = await Dio().get('$contentSettingsApiRoot/site/$siteKey');
						if (siteResponse.data['error'] != null) {
							throw Exception(siteResponse.data['error']);
						}
						final site = makeSite(siteResponse.data['data']);
						String platform = Platform.operatingSystem;
						if (Platform.isIOS && isDevelopmentBuild) {
							platform += '-dev';
						}
						final response = await Dio().put('$contentSettingsApiRoot/user/${Persistence.settings.userId}/site/$siteKey', queryParameters: {
							'platform': platform
						});
						if (response.data['error'] != null) {
							throw Exception(response.data['error']);
						}
						if (!mounted) return;
						await modalLoad(context, 'Setting up ${site.name}...', (_) async {
							await settings.updateContentSettings();
							await Future.delayed(const Duration(milliseconds: 500)); // wait for rebuild of ChanHomePage
						});
					}
					_addNewTab(
						withImageboardKey: siteKey,
						activate: true,
						keepTabPopupOpen: true
					);
				}
				catch (e) {
					alertError(context, 'Error adding site: $e');
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
			final dest = await modalLoad(context, 'Checking url...', (_) => ImageboardRegistry.instance.decodeUrl(link), wait: const Duration(milliseconds: 50));
			if (dest != null) {
				_onNotificationTapped(dest.$1, dest.$2);
				return;
			}
			final devDest = (await devImageboard?.site.decodeUrl(link))?.postIdentifier;
			if (devDest != null) {
				_onDevNotificationTapped(devDest);
				return;
			}
			if (!mounted) return;
			final open = await showCupertinoDialog<bool>(
				context: context,
				barrierDismissible: true,
				builder: (context) => CupertinoAlertDialog2(
					title: const Text('Unrecognized link'),
					content: Text('No site supports opening "$link"'),
					actions: [
						CupertinoDialogAction2(
							onPressed: () => Navigator.pop(context, true),
							child: const Text('Open in browser')
						),
						CupertinoDialogAction2(
							onPressed: () => Navigator.pop(context, false),
							child: const Text('Close')
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
		if (tab.threadController?.items.any((p) => p.item.id == postId) == false) {
			await Future.any([tab.threadController!.update(), Future.delayed(const Duration(milliseconds: 500))]);
		}
		tab.threadController?.animateTo((p) => p.id == postId, alignment: 1.0, orElseLast: (p) => true);
	}

	void _onNotificationTapped(Imageboard imageboard, BoardThreadOrPostIdentifier notification) async {
		if (!_goToPost(
			imageboardKey: imageboard.key,
			board: notification.board,
			threadId: notification.threadId,
			postId: notification.postId,
			openNewTabIfNeeded: false
		)) {
			final watch = imageboard.persistence.browserState.threadWatches.tryFirstWhere((w) => w.threadIdentifier == notification.threadIdentifier);
			if (watch == null) {
				_goToPost(
					imageboardKey: imageboard.key,
					board: notification.board,
					threadId: notification.threadId,
					postId: notification.postId,
					openNewTabIfNeeded: true
				);
			}
			else {
				_tabController.index = 1;
				_lastIndex = 1;
				for (int i = 0; i < 200 && _savedMasterDetailKey.currentState == null; i++) {
					await Future.delayed(const Duration(milliseconds: 50));
				}
				if (_savedMasterDetailKey.currentState?.getValue<ImageboardScoped<ThreadWatch>>(0)?.item == watch && notification.postId != null) {
					_scrollExistingTab(_savedFakeTab, notification.postId!);
				}
				else {
					if (notification.postId != null) {
						_savedFakeTab.initialPostId[notification.threadIdentifier!] = notification.postId!;
					}
					_savedMasterDetailKey.currentState?.setValue(0, imageboard.scope(watch));
				}
				if (showTabPopup) {
					setState(() {
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
			activeBrowserTab.value = Persistence.currentTabIndex;
		}
	}

	Future<void> _setAdditionalSafeAreaInsets() async {
		await setAdditionalSafeAreaInsets('main', EdgeInsets.only(
			bottom: 60 + (_isInTabletLayout ? 0 : 44 + (showTabPopup ? 80 : 0))
		) * settings.interfaceScale);
	}

	@override
	void initState() {
		super.initState();
		browseCountListenable = Listenable.merge([activeBrowserTab, ...Persistence.tabs.map((x) => x.unseen)]);
		activeBrowserTab.value = Persistence.currentTabIndex;
		Persistence.tabsListenable.addListener(_tabsListener);
		_setupDevSite();
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
		if (Persistence.settings.launchCount > 5 && !Persistence.settings.promptedAboutCrashlytics && !_promptedAboutCrashlytics) {
			_promptedAboutCrashlytics = true;
			Future.delayed(const Duration(milliseconds: 300), () async {
				if (!mounted) return;
				final choice = await showCupertinoDialog<bool>(
					context: context,
					builder: (context) => CupertinoAlertDialog2(
						title: const Text('Contribute crash data?'),
						content: const Text('Crash stack traces and uncaught exceptions will be used to help fix bugs. No personal information will be collected.'),
						actions: [
							CupertinoDialogAction2(
								child: const Text('No'),
								onPressed: () {
									Navigator.of(context).pop(false);
								}
							),
							CupertinoDialogAction2(
								child: const Text('Yes'),
								onPressed: () {
									Navigator.of(context).pop(true);
								}
							)
						]
					)
				);
				if (choice != null) {
					FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(choice);
					if (!mounted) return;
					context.read<EffectiveSettings>().promptedAboutCrashlytics = true;
				}
			});
		}
		WidgetsBinding.instance.addPostFrameCallback((_) {
			if (_tabListController.hasOnePosition) {
				_tabListController.jumpTo(((Persistence.currentTabIndex + 1) / Persistence.tabs.length) * _tabListController.position.maxScrollExtent);
			}
		});
		if (settings.askForAuthenticationOnLaunch) {
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

	PersistentBrowserTab _addNewTab({
		String? withImageboardKey,
		int? atPosition,
		String? withBoard,
		ThreadIdentifier? withThread,
		int? withThreadId,
		bool activate = false,
		bool incognito = false,
		int? withInitialPostId,
		bool keepTabPopupOpen = false
	}) {
		final pos = atPosition ?? Persistence.tabs.length;
		final tab = PersistentBrowserTab(
			imageboardKey: withImageboardKey,
			board: withImageboardKey == null || withBoard == null ? null : ImageboardRegistry.instance.getImageboard(withImageboardKey)?.persistence.getBoard(withBoard),
			thread: withThread ?? (withThreadId == null ? null : ThreadIdentifier(withBoard!, withThreadId)),
			incognito: incognito
		);
		tab.initialize();
		if (withBoard != null && withThreadId != null && withInitialPostId != null) {
			tab.initialPostId[ThreadIdentifier(withBoard, withThreadId)] = withInitialPostId;
		}
		Persistence.tabs.insert(pos, tab);
		browseCountListenable = Listenable.merge([activeBrowserTab, ...Persistence.tabs.map((x) => x.unseen)]);
		if (activate) {
			_tabController.index = 0;
			activeBrowserTab.value = pos;
			Persistence.currentTabIndex = pos;
		}
		showTabPopup = keepTabPopupOpen || !activate || !Persistence.settings.closeTabSwitcherAfterUse;
		Persistence.didUpdateTabs();
		setState(() {});
		Future.delayed(const Duration(milliseconds: 100), () {
			if (!_tabListController.hasOnePosition) {
				return;
			}
			_tabListController.animateTo((_tabListController.position.maxScrollExtent / Persistence.tabs.length) * (pos + 1), duration: const Duration(milliseconds: 500), curve: Curves.ease);
		});
		return tab;
	}

	bool _goToPost({
		required String imageboardKey,
		required String board,
		required int? threadId,
		int? postId,
		required bool openNewTabIfNeeded
	}) {
		PersistentBrowserTab? tab = Persistence.tabs.tryFirstWhere((tab) => tab.imageboardKey == imageboardKey && tab.thread?.board == board && tab.thread?.id == threadId);
		final tabAlreadyExisted = tab != null;
		if (openNewTabIfNeeded) {
			tab ??= _addNewTab(
				activate: false,
				withImageboardKey: imageboardKey,
				withBoard: board,
				withThreadId: threadId,
				withInitialPostId: postId
			);
		}
		if (tab != null) {
			final index = Persistence.tabs.indexOf(tab);
			_tabController.index = 0;
			activeBrowserTab.value = index;
			Persistence.currentTabIndex = index;
			Persistence.didUpdateTabs();
			setState(() {});
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
				animation: activeBrowserTab,
				builder: (context, _) => TabSwitchingView(
					currentTabIndex: activeBrowserTab.value,
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
										_tabController.index = 3;
										_lastIndex = 3;
										for (int i = 0; i < 200 && _searchPageKey.currentState == null; i++) {
											await Future.delayed(const Duration(milliseconds: 50));
										}
										_searchPageKey.currentState?.onSearchComposed(ImageboardArchiveSearchQuery(
											imageboardKey: imageboardKey,
											boards: [board],
											query: query
										));
									},
									id: -1 * (i + 10)
								);
								return MultiProvider(
									providers: [
										Provider.value(
											value: _tabletWillPopZones.putIfAbsent(index, () => WillPopZone())
										),
										ChangeNotifierProvider.value(value: tabObject),
										Provider.value(
											value: OpenInNewTabZone(
												onWantOpenThreadInNewTab: (imageboardKey, thread, {bool incognito = false, bool activate = true}) {
													_addNewTab(
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
										valueListenable: activeBrowserTab,
										builder: (context, int activeIndex, child) {
											return i == activeIndex ? child! : PrimaryScrollController.none(
												child: child!
											);
										},
										child: tabObject.imageboardKey == null ? tab : ImageboardScope(
											imageboardKey: tabObject.imageboardKey!,
											overridePersistence: tabObject.incognitoPersistence,
											loaderOffset: isInTabletLayout ? const Offset(-42.5, 0) : const Offset(0, 25),
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
							onWantOpenThreadInNewTab: (imageboardKey, thread, {bool incognito = false, bool activate = true}) => _addNewTab(
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
					masterDetailKey: _savedMasterDetailKey
				)
			);
		}
		else if (index == 2) {
			child = Provider.value(
				value: OpenInNewTabZone(
					onWantOpenThreadInNewTab: (imageboardKey, thread, {bool incognito = false, bool activate = true}) => _addNewTab(
						withImageboardKey: imageboardKey,
						withBoard: thread.board,
						withThreadId: thread.id,
						activate: activate,
						incognito: incognito
					)
				),
				child: HistoryPage(
					isActive: active,
					key: _historyPageKey
				)
			);
		}
		else if (index == 3) {
			child = Provider.value(
				value: OpenInNewTabZone(
					onWantOpenThreadInNewTab: (imageboardKey, thread, {bool incognito = false, bool activate = true}) => _addNewTab(
						withImageboardKey: imageboardKey,
						withBoard: thread.board,
						withThreadId: thread.id,
						activate: activate,
						incognito: incognito
					)
				),
				child: SearchPage(
					key: _searchPageKey
				)
			);
		}
		else {
			if (devImageboard?.threadWatcher == null) {
				child = const Center(
					child: CupertinoActivityIndicator()
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
								ChangeNotifierProvider.value(value: devImageboard!),
								Provider.value(value: devImageboard!.site),
								ChangeNotifierProvider.value(value: devImageboard!.persistence),
								ChangeNotifierProvider.value(value: devImageboard!.threadWatcher),
								Provider.value(value: devImageboard!.notifications),
								ChangeNotifierProvider.value(value: devTab)
							],
							child: ClipRect(
								child: PrimaryScrollControllerInjectingNavigator(
									navigatorKey: _settingsNavigatorKey,
									observers: [HeroController()],
									buildRoot: (context) => const SettingsPage()
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
		Widget? preLabelInjection
	}) {
		final content = AnimatedBuilder(
			animation: _tabController,
			builder: (context, _) => Opacity(
				opacity: (index <= 0 ? (_tabController.index == 0 && index == -1 * activeBrowserTab.value) : index == _tabController.index) ? 1.0 : 0.5,
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
		final child = Builder(
			builder: (context) => CupertinoButton(
				padding: axis == Axis.vertical ? const EdgeInsets.only(top: 16, bottom: 16, left: 8, right: 8) : const EdgeInsets.only(top: 8, bottom: 8, left: 16, right: 16),
				child: content,
				onPressed: () async {
					lightHapticFeedback();
					if (index <= 0) {
						if (activeBrowserTab.value == -1 * index && _tabController.index == 0) {
							final ro = context.findRenderObject()! as RenderBox;
							showTabMenu(
								context: context,
								direction: axis == Axis.horizontal ? AxisDirection.up : AxisDirection.right,
								origin: Rect.fromPoints(
									ro.localToGlobal(ro.semanticBounds.topLeft),
									ro.localToGlobal(ro.semanticBounds.bottomRight)
								),
								actions: [
									TabMenuAction(
										icon: CupertinoIcons.xmark,
										title: 'Close',
										isDestructiveAction: true,
										disabled: Persistence.tabs.length == 1,
										onPressed: () {
											Persistence.tabs.removeAt(-1 * index);
											browseCountListenable = Listenable.merge([activeBrowserTab, ...Persistence.tabs.map((x) => x.unseen)]);
											final newActiveTabIndex = min(activeBrowserTab.value, Persistence.tabs.length - 1);
											activeBrowserTab.value = newActiveTabIndex;
											Persistence.currentTabIndex = newActiveTabIndex;
											_didUpdateTabs();
											setState(() {});
										}
									),
									TabMenuAction(
										icon: CupertinoIcons.doc_on_doc,
										title: 'Clone',
										onPressed: () {
											final i = -1 * index;
											_addNewTab(
												withImageboardKey: Persistence.tabs[i].imageboardKey,
												atPosition: i + 1,
												withBoard: Persistence.tabs[i].board?.name,
												withThread: Persistence.tabs[i].thread,
												incognito: Persistence.tabs[i].incognito
											);
											activeBrowserTab.value = i + 1;
											Persistence.currentTabIndex = i + 1;
											_didUpdateTabs();
											setState(() {});
										}
									)
								]
							);
						}
						else {
							activeBrowserTab.value = -1 * index;
							Persistence.currentTabIndex = -1 * index;
							if (Persistence.settings.closeTabSwitcherAfterUse) {
								setState(() {
									showTabPopup = false;
								});
							}
							_didUpdateTabs();
							setState(() {});
						}
					}
					else if (index == _lastIndex) {
						if (index == 4) {
							_settingsNavigatorKey.currentState?.maybePop();
						}
						else {
							_tabletWillPopZones[index]?.callback?.call();
						}
					} else if (index == 2) {
						await _historyPageKey.currentState?.updateList();
					}
					_tabController.index = max(0, index);
					_lastIndex = max(0, index);
				}
			)
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

	Widget _buildNewTabIcon({required Axis axis, bool hideLabel = false}) {
		return Builder(
			builder: (context) {
				Future<void> showNewTabPopup() async {
					lightHapticFeedback();
					final ro = context.findRenderObject()! as RenderBox;
					showTabMenu(
						context: context,
						direction: axis == Axis.horizontal ? AxisDirection.up : AxisDirection.right,
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
									_addNewTab(activate: true, incognito: true);
								}
							),
							TabMenuAction(
								icon: CupertinoIcons.xmark_square,
								title: 'Close others',
								isDestructiveAction: true,
								onPressed: () async {
									lightHapticFeedback();
									final shouldCloseOthers = await showCupertinoDialog<bool>(
										context: context,
										barrierDismissible: true,
										builder: (context) => CupertinoAlertDialog2(
											title: const Text('Close all other tabs?'),
											actions: [
												CupertinoDialogAction2(
													onPressed: () => Navigator.of(context).pop(false),
													child: const Text('No')
												),
												CupertinoDialogAction2(
													onPressed: () => Navigator.of(context).pop(true),
													isDestructiveAction: true,
													child: const Text('Yes')
												)
											]
										)
									);
									if (shouldCloseOthers == true) {
										final tabToPreserve = Persistence.tabs[activeBrowserTab.value];
										Persistence.tabs.clear();
										Persistence.tabs.add(tabToPreserve);
										browseCountListenable = Listenable.merge([activeBrowserTab, ...Persistence.tabs.map((x) => x.unseen)]);
										activeBrowserTab.value = 0;
										Persistence.currentTabIndex = 0;
										_didUpdateTabs();
										if (Persistence.settings.closeTabSwitcherAfterUse) {
											showTabPopup = false;
										}
										setState(() {});
									}
								}
							)
						]
					);
				}
				return GestureDetector(
					onVerticalDragEnd: (details) {
						final velocity = details.primaryVelocity ?? 0;
						if (velocity < 0) {
							showNewTabPopup();
						}
					},
					onLongPress: showNewTabPopup,
					child: CupertinoButton(
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
							_addNewTab(activate: true);
						}
					)
				);
			}
		);
	}

	Widget _buildTabList(Axis axis) {
		return ReorderableList(
			controller: _tabListController,
			scrollDirection: axis,
			onReorder: (oldIndex, newIndex) {
				final currentTab = Persistence.tabs[activeBrowserTab.value];
				if (oldIndex < newIndex) {
					newIndex -= 1;
				}
				final tab = Persistence.tabs.removeAt(oldIndex);
				Persistence.tabs.insert(newIndex, tab);
				activeBrowserTab.value = Persistence.tabs.indexOf(currentTab);
				Persistence.currentTabIndex = activeBrowserTab.value;
				_didUpdateTabs();
				setState(() {});
			},
			itemCount: Persistence.tabs.length,
			itemBuilder: (context, i) {
				const blankIcon = SizedBox(
					width: 30,
					height: 30,
					child: Icon(CupertinoIcons.rectangle_stack)
				);
				buildStationaryIcon() {
					Widget icon = blankIcon;
					bool injectIcon = false;
					if (Persistence.tabs[i].imageboardKey != null) {
						if (ImageboardRegistry.instance.getImageboard(Persistence.tabs[i].imageboardKey!)?.seemsOk == true) {
							icon = SizedBox(
								width: 30,
								height: 30,
								child: FittedBox(
									fit: BoxFit.contain,
									child: ImageboardIcon(
										imageboardKey: Persistence.tabs[i].imageboardKey,
										boardName: Persistence.tabs[i].board?.name
									)
								)
							);
							final threadState = Persistence.tabs[i].thread == null ? null : Persistence.tabs[i].persistence?.getThreadStateIfExists(Persistence.tabs[i].thread!);
							Future.microtask(() => Persistence.tabs[i].unseen.value = threadState?.unseenReplyCount() ?? 0);
							if (threadState != null) {
								final attachment = threadState.thread?.attachments.tryFirst;
								injectIcon = attachment != null;
								icon = StationaryNotifyingIcon(
									icon: attachment == null ? icon : ClipRRect(
										borderRadius: const BorderRadius.all(Radius.circular(4)),
										child: AttachmentThumbnail(
											gaplessPlayback: true,
											fit: BoxFit.cover,
											attachment: attachment,
											width: 30,
											height: 30,
											site: Persistence.tabs[i].imageboard?.site
										)
									),
									primary: threadState.unseenReplyIdsToYouCount() ?? 0,
									secondary: threadState.unseenReplyCount() ?? 0
								);
							}
						}
						else {
							icon = ImageboardRegistry.instance.getImageboard(Persistence.tabs[i].imageboardKey!)?.boardsLoading == true ? const SizedBox(
								width: 30,
								height: 30,
								child: CupertinoActivityIndicator()
							) : const SizedBox(
								width: 30,
								height: 30,
								child: Icon(CupertinoIcons.exclamationmark_triangle_fill)
							);
						}
					}
					if (Persistence.tabs[i].incognito) {
						icon = Stack(
							alignment: Alignment.center,
							clipBehavior: Clip.none,
							children: [
								icon,
								Positioned(
									bottom: -5,
									child: DecoratedBox(
										decoration: BoxDecoration(
											color: ChanceTheme.primaryColorOf(context),
											borderRadius: BorderRadius.circular(8)
										),
										child: Padding(
											padding: const EdgeInsets.symmetric(horizontal: 4),
											child: Icon(CupertinoIcons.eyeglasses, size: 20, color: ChanceTheme.barColorOf(context))
										)
									)
								)
							]
						);
					}
					return _buildTabletIcon(
						i * -1,
						icon,
						Persistence.tabs[i].board != null ? Persistence.tabs[i].imageboard?.site.formatBoardName(Persistence.tabs[i].board!) : (Persistence.tabs[i].imageboard?.site.name ?? Persistence.tabs[i].imageboardKey ?? 'None'),
						reorderable: false,
						axis: axis,
						preLabelInjection: injectIcon ? AnimatedBuilder(
							animation: Persistence.tabs[i],
							builder: (context, _) => ImageboardIcon(
								imageboardKey: Persistence.tabs[i].imageboardKey,
								boardName: Persistence.tabs[i].board?.name
							)
						) : null
					);
				}
				return ReorderableDelayedDragStartListener(
					index: i,
					key: ValueKey(i),
					child: AnimatedBuilder(
						animation: Persistence.tabs[i],
						builder: (context, _) {
							final imageboard = Persistence.tabs[i].imageboard;
							final persistence = Persistence.tabs[i].persistence;
							if (imageboard == null || persistence == null) {
								return buildStationaryIcon();
							}
							return AnimatedBuilder(
								animation: imageboard,
								builder: (context, _) {
									final thread = Persistence.tabs[i].thread;
									if (thread == null) {
										return buildStationaryIcon();
									}
									return AnimatedBuilder(
										animation: persistence.listenForPersistentThreadStateChanges(thread),
										builder: (context, _) {
											final threadState = persistence.getThreadStateIfExists(thread);
											if (threadState == null) {
												return buildStationaryIcon();
											}
											else {
												return AnimatedBuilder(
													animation: threadState,
													builder: (context, _) => buildStationaryIcon()
												);
											}
										}
									);
								}
							);
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
			builder: (context) => CupertinoAlertDialog2(
				title: const Text('Exit the app?'),
				actions: [
					CupertinoDialogAction2(
						child: const Text('Cancel'),
						onPressed: () {
							Navigator.of(context).pop(false);
						}
					),
					CupertinoDialogAction2(
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

	void _runSettingsQuickAction() {
		mediumHapticFeedback();
		final settings = context.read<EffectiveSettings>();
		switch (settings.settingsQuickAction) {
			case SettingsQuickAction.toggleTheme:
				settings.themeSetting = settings.whichTheme == Brightness.light ? TristateSystemSetting.b : TristateSystemSetting.a;
				showToast(
					context: context,
					icon: CupertinoIcons.paintbrush,
					message: settings.whichTheme == Brightness.light ? 'Switched to light theme' : 'Switched to dark theme'
				);
				break;
			case SettingsQuickAction.toggleBlurredThumbnails:
				settings.blurThumbnails = !settings.blurThumbnails;
				showToast(
					context: context,
					icon: CupertinoIcons.paintbrush,
					message: settings.blurThumbnails ? 'Blurred thumbnails enabled' : 'Blurred thumbnails disabled'
				);
				break;
			case SettingsQuickAction.toggleCatalogLayout:
				settings.useCatalogGrid = !settings.useCatalogGrid;
				showToast(
					context: context,
					icon: CupertinoIcons.rectangle_stack,
					message: settings.useCatalogGrid ? 'Switched to catalog grid' : 'Switched to catalog rows'
				);
				break;
			case SettingsQuickAction.toggleInterfaceStyle:
				settings.supportMouseSetting = settings.supportMouse.value ? TristateSystemSetting.a : TristateSystemSetting.b;
				showToast(
					context: context,
					icon: settings.supportMouse.value ? Icons.mouse : CupertinoIcons.hand_draw,
					message: settings.supportMouse.value ? 'Switched to mouse layout' : 'Switched to touch layout'
				);
				break;
			case SettingsQuickAction.toggleListPositionIndicatorLocation:
				settings.showListPositionIndicatorsOnLeft = !settings.showListPositionIndicatorsOnLeft;
				showToast(
					context: context,
					icon: settings.showListPositionIndicatorsOnLeft ? CupertinoIcons.arrow_left_to_line : CupertinoIcons.arrow_right_to_line,
					message: settings.showListPositionIndicatorsOnLeft ? 'Moved list position indicators to left' : 'Moved list position indicators to right'
				);
				break;
			case SettingsQuickAction.toggleVerticalTwoPaneSplit:
				settings.verticalTwoPaneMinimumPaneSize = -1 * settings.verticalTwoPaneMinimumPaneSize;
				showToast(
					context: context,
					icon: settings.verticalTwoPaneMinimumPaneSize.isNegative ? CupertinoIcons.rectangle : CupertinoIcons.rectangle_grid_1x2,
					message: settings.verticalTwoPaneMinimumPaneSize.isNegative ? 'Disabled vertical two-pane layout' : 'Enabled vertical two-pane layout'
				);
				break;
			case null:
				break;
		}
	}

	void _toggleHistory() {
		mediumHapticFeedback();
		settings.recordThreadsInHistory = !settings.recordThreadsInHistory;
		showToast(
			context: context,
			message: settings.recordThreadsInHistory ? 'History resumed' : 'History stopped',
			icon: settings.recordThreadsInHistory ? CupertinoIcons.play : CupertinoIcons.stop
		);
	}

	bool get _isInTabletLayout => (context.findAncestorWidgetOfExactType<MediaQuery>()!.data.size.width - 85) > (context.findAncestorWidgetOfExactType<MediaQuery>()!.data.size.height - 50);
	bool get isInTabletLayout => (MediaQuery.sizeOf(context).width - 85) > (MediaQuery.sizeOf(context).height - 50);

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
						CupertinoButton.filled(
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
		Widget child = isInTabletLayout ? NotificationListener<ScrollNotification>(
			onNotification: _onScrollNotification,
			child: Actions(
				actions: {
					ExtendSelectionToLineBreakIntent: CallbackAction<ExtendSelectionToLineBreakIntent>(
						onInvoke: (intent) {
							if ((FocusManager.instance.primaryFocus?.rect.height ?? 0) < (MediaQuery.sizeOf(context).height * 0.75)) {
								// Likely a text field is focused
								return;
							}
							_tabletWillPopZones[_tabController.index]?.callback?.call();
							return null;
						}
					)
				},
				child: WillPopScope(
					onWillPop: () async {
						if (_tabController.index == 4) {
							if ((await _settingsNavigatorKey.currentState?.maybePop()) ?? false) {
								return false;
							}
						}
						else if (!((await _tabletWillPopZones[_tabController.index]?.callback?.call()) ?? true)) {
							return false;
						}
						if (_tabController.index != 0) {
							_tabController.index = 0;
							_lastIndex = 0;
							return false;
						}
						return await confirmExit();
					},
					child: CupertinoPageScaffold(
						child: SafeArea(
							top: false,
							bottom: false,
							child: Row(
								children: [
									Container(
										padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
										color: ChanceTheme.barColorOf(context),
										width: 85,
										child: Column(
											children: [
												Expanded(
													child: AnimatedBuilder(
														animation: activeBrowserTab,
														builder: (context, _) => _buildTabList(Axis.vertical)
													)
												),
												_buildNewTabIcon(
													axis: Axis.vertical,
													hideLabel: hideTabletLayoutLabels
												),
												_buildTabletIcon(1, NotifyingIcon(
														icon: const Icon(CupertinoIcons.bookmark),
														primaryCount: CombiningValueListenable<int>(
															children: ImageboardRegistry.instance.imageboards.map((x) => x.threadWatcher.unseenYouCount).toList(),
															combine: (a, b) => a + b,
															noChildrenValue: 0
														),
														secondaryCount: CombiningValueListenable<int>(
															children: ImageboardRegistry.instance.imageboards.map((x) => x.threadWatcher.unseenCount).toList(),
															combine: (a, b) => a + b,
															noChildrenValue: 0
														)
													), hideTabletLayoutLabels ? null : 'Saved',
												),
												GestureDetector(
													onLongPress: _toggleHistory,
													child: _buildTabletIcon(2, context.select<EffectiveSettings, bool>((s) => s.recordThreadsInHistory) ? const Icon(CupertinoIcons.archivebox) : const Icon(CupertinoIcons.eye_slash), hideTabletLayoutLabels ? null : 'History')
												),
												_buildTabletIcon(3, const Icon(CupertinoIcons.search), hideTabletLayoutLabels ? null : 'Search'),
												GestureDetector(
													onLongPress: _runSettingsQuickAction,
													child: _buildTabletIcon(4, NotifyingIcon(
															icon: Icon(CupertinoIcons.settings, color: settings.filterError != null ? Colors.red : null),
															primaryCount: devImageboard?.threadWatcher.unseenYouCount ?? zeroValueNotifier,
															secondaryCount: devImageboard?.threadWatcher.unseenCount ?? zeroValueNotifier
														), hideTabletLayoutLabels ? null : 'Settings'
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
		) : NotificationListener<ScrollNotification>(
			onNotification: _onScrollNotification,
			child: Actions(
				actions: {
					ExtendSelectionToLineBreakIntent: CallbackAction<ExtendSelectionToLineBreakIntent>(
						onInvoke: (intent) {
							if ((FocusManager.instance.primaryFocus?.rect.height ?? 0) < (MediaQuery.sizeOf(context).height * 0.75)) {
								// Likely a text field is focused
								return;
							}
							_tabNavigatorKeys[_tabController.index]?.currentState?.maybePop();
							return null;
						}
					)
				},
				child: WillPopScope(
					onWillPop: () async {
						if (await _tabNavigatorKeys[_tabController.index]?.currentState?.maybePop() ?? false) {
							return false;
						}
						if (_tabController.index != 0) {
							_tabController.index = 0;
							_lastIndex = 0;
							return false;
						}
						return await confirmExit();
					},
					child: CupertinoTabScaffold(
						controller: _tabController,
						tabBar: ChanceCupertinoTabBar(
							inactiveColor: ChanceTheme.primaryColorOf(context).withOpacity(0.4),
							items: [
								BottomNavigationBarItem(
									icon: AnimatedBuilder(
										animation: browseCountListenable,
										builder: (context, child) => StationaryNotifyingIcon(
											icon: const Icon(CupertinoIcons.rectangle_stack, size: 28),
											primary: 0,
											secondary: (Persistence.tabs.length == 1) ? 0 : Persistence.tabs.asMap().entries.where((x) => x.key != activeBrowserTab.value || _tabController.index > 0).map((x) => x.value.unseen.value).reduce((a, b) => a + b)
										)
									),
									label: 'Browse'
								),
								BottomNavigationBarItem(
									icon: Builder(
										builder: (context) => NotifyingIcon(
											icon: const Icon(CupertinoIcons.bookmark, size: 28),
											primaryCount: CombiningValueListenable<int>(
												children: ImageboardRegistry.instance.imageboards.map((x) => x.threadWatcher.unseenYouCount).toList(),
												combine: (a, b) => a + b,
												noChildrenValue: 0
											),
											secondaryCount: CombiningValueListenable<int>(
												children: ImageboardRegistry.instance.imageboards.map((x) => x.threadWatcher.unseenCount).toList(),
												combine: (a, b) => a + b,
												noChildrenValue: 0
											)
										)
									),
									label: 'Saved'
								),
								BottomNavigationBarItem(
									icon: GestureDetector(
										onLongPress: _toggleHistory,
										child: context.select<EffectiveSettings, bool>((s) => s.recordThreadsInHistory) ? const Icon(CupertinoIcons.archivebox, size: 28) : const Icon(CupertinoIcons.eye_slash, size: 28)
									),
									label: 'History'
								),
								const BottomNavigationBarItem(
									icon: Icon(CupertinoIcons.search, size: 28),
									label: 'Search'
								),
								BottomNavigationBarItem(
									icon: GestureDetector(
										onLongPress: _runSettingsQuickAction,
										child: NotifyingIcon(
											icon: Icon(CupertinoIcons.settings, size: 28, color: settings.filterError != null ? Colors.red : null),
											primaryCount: devImageboard?.threadWatcher.unseenYouCount ?? zeroValueNotifier,
											secondaryCount: devImageboard?.threadWatcher.unseenCount ?? zeroValueNotifier
										)
									),
									label: 'Settings'
								)
							],
							onUpSwipe: () {
								if (showTabPopup) {
									return;
								}
								mediumHapticFeedback();
								setState(() {
									showTabPopup = true;
								});
							},
							onDownSwipe: () {
								if (!showTabPopup) {
									return;
								}
								mediumHapticFeedback();
								setState(() {
									showTabPopup = false;
								});
							},
							onLeftSwipe: () {
								if (_tabController.index != 0) {
									return;
								}
								mediumHapticFeedback();
								if (Persistence.currentTabIndex <= 0) {
									Future.delayed(const Duration(milliseconds: 100), mediumHapticFeedback);
									return;
								}
								activeBrowserTab.value--;
								Persistence.currentTabIndex--;
								_didUpdateTabs();
								setState(() {});
							},
							onRightSwipe: () {
								if (_tabController.index != 0) {
									return;
								}
								mediumHapticFeedback();
								if (Persistence.currentTabIndex >= Persistence.tabs.length - 1) {
									Future.delayed(const Duration(milliseconds: 100), mediumHapticFeedback);
									return;
								}
								activeBrowserTab.value++;
								Persistence.currentTabIndex++;
								_didUpdateTabs();
								setState(() {});
							},
							beforeCopiedOnTap: (index) async {
								if (index == 2) {
									await _historyPageKey.currentState?.updateList();
								}
							},
							onTap: (index) {
								lightHapticFeedback();
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
							builder: (context) => index == 0 ? Column(
								children: [
									Expanded(
										child: AnimatedBuilder(
											animation: _tabController,
											builder: (context, child) => _buildTab(context, index, _tabController.index == index)
										)
									),
									Expander(
										height: 80,
										bottomSafe: false,
										expanded: showTabPopup,
										duration: const Duration(milliseconds: 200),
										curve: Curves.ease,
										child: GestureDetector(
											behavior: HitTestBehavior.translucent,
											onVerticalDragEnd: (details) {
												if (details.velocity.pixelsPerSecond.dy > 0 && showTabPopup) {
													mediumHapticFeedback();
													setState(() {
														showTabPopup = false;
													});
												}
											},
											child: Container(
												color: ChanceTheme.barColorOf(context),
												child: Row(
													children: [
														Expanded(
															child: AnimatedBuilder(
																animation: activeBrowserTab,
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
							) : AnimatedBuilder(
								animation: _tabController,
								builder: (context, child) => _buildTab(context, index, _tabController.index == index)
							)
						)
					)
				)
			)
		);
		child = NotificationsOverlay(
			onePane: !isInTabletLayout,
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
							paths.add(datum.dropFile!.path);
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
		return child;
	}

	@override
	void dispose() {
		super.dispose();
		Persistence.tabsListenable.removeListener(_tabsListener);
		devImageboard?.dispose();
		_tabListController.dispose();
		_tabController.dispose();
		activeBrowserTab.dispose();
		_linkSubscription.cancel();
		_fakeLinkSubscription.cancel();
		_sharedFilesSubscription.cancel();
		_sharedTextSubscription.cancel();
		_devNotificationsSubscription?.cancel();
		for (final subscription in _notificationsSubscriptions.values) {
			subscription.subscription.cancel();
		}
	}
}

class ChanceCupertinoTabBar extends CupertinoTabBar {
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
	
	@override
	Widget build(BuildContext context) {
		return GestureDetector(
			behavior: HitTestBehavior.translucent,
			onPanEnd: (details) {
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
			child: super.build(context)
		);
	}
}
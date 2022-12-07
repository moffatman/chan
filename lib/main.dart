import 'dart:async';
import 'dart:io';
import 'dart:math';

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
import 'package:chan/services/settings.dart';
import 'package:chan/services/share.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/cupertino_page_route.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/injecting_navigator.dart';
import 'package:chan/widgets/notifications_overlay.dart';
import 'package:chan/widgets/notifying_icon.dart';
import 'package:chan/widgets/saved_theme_thumbnail.dart';
import 'package:chan/widgets/tab_menu.dart';
import 'package:chan/widgets/tab_switching_view.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:native_drag_n_drop/native_drag_n_drop.dart';
import 'package:rxdart/subjects.dart';
import 'package:tuple/tuple.dart';
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
			WidgetsFlutterBinding.ensureInitialized();
			await initializeIsDevelopmentBuild();
			await initializeIsOnMac();
			await initializeHandoff();
			final imageHttpClient = (ExtendedNetworkImageProvider.httpClient as HttpClient);
			imageHttpClient.connectionTimeout = const Duration(seconds: 10);
			imageHttpClient.idleTimeout = const Duration(seconds: 10);
			await Persistence.initializeStatic();
			await Notifications.initializeStatic();
			if (Platform.isAndroid || Platform.isIOS) {
				FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
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
		return CupertinoApp(
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
												 <p>Chance isn't starting and is giving the following error:</p>
												 <p>$error</p>
												 <p>$stackTrace</p>
												 <p>Thanks!</p>'''
							));
						}
					}
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
					ChangeNotifierProvider.value(value: settings)
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
										data: mq.copyWith(
											boldText: false,
											textScaleFactor: mq.textScaleFactor * settings.textScale
										),
										child: RootCustomScale(
											scale: ((Platform.isMacOS || Platform.isWindows || Platform.isLinux) ? 1.3 : 1.0) / settings.interfaceScale,
											child: FilterZone(
												filter: settings.filter,
												child: CupertinoApp(
													title: 'Chance',
													useInheritedMediaQuery: true,
													debugShowCheckedModeBanner: false,
													theme: theme,
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
																	color: CupertinoTheme.of(context).scaffoldBackgroundColor,
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
			color: context.select<EffectiveSettings, Color>((s) => s.theme.backgroundColor),
			child: Transform.scale(
				scale: 1 / (
					2.0 * MediaQuery.of(context).devicePixelRatio *
					context.select<EffectiveSettings, double>((s) => s.interfaceScale)
				),
				child: ColorFiltered(
					colorFilter: ColorFilter.mode(
						context.select<EffectiveSettings, Color>((s) => s.theme.barColor),
						BlendMode.srcATop
					),
					child: const Image(
						image: AssetImage('assets/splash.png')
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

class ChanHomePage extends StatefulWidget {
	const ChanHomePage({Key? key}) : super(key: key);

	@override
	createState() => _ChanHomePageState();
}
class _ChanHomePageState extends State<ChanHomePage> {
	int _lastIndex = 0;
	final _keys = <int, GlobalKey>{};
	final _tabController = CupertinoTabController();
	bool showTabPopup = false;
	late Listenable browseCountListenable;
	final activeBrowserTab = ValueNotifier<int>(0);
	final _tabListController = ScrollController();
	StreamSubscription<BoardThreadOrPostIdentifier>? _devNotificationsSubscription;
	Imageboard? devImageboard;
	final _tabNavigatorKeys = <int, GlobalKey<NavigatorState>>{};
	final _tabletWillPopZones = <int, WillPopZone>{};
	final _settingsNavigatorKey = GlobalKey<NavigatorState>();
	bool _queuedUpdateTabs = false;
	bool _isScrolling = false;
	final _savedMasterDetailKey = GlobalKey<MultiMasterDetailPageState>();
	final PersistentBrowserTab _savedFakeTab = PersistentBrowserTab();
	final Map<String, Tuple2<Notifications, StreamSubscription<BoardThreadOrPostIdentifier>>> _notificationsSubscriptions = {};
	late StreamSubscription<String?> _linkSubscription;
	late StreamSubscription<String?> _fakeLinkSubscription;
	late StreamSubscription<List<SharedMediaFile>> _sharedFilesSubscription;
	late StreamSubscription<String> _sharedTextSubscription;
	final _searchPageKey = GlobalKey<SearchPageState>();
	// Sometimes duplicate links are received due to use of multiple link handling packages
	Tuple2<DateTime, String>? _lastLink;

	void _didUpdateTabs() {
		if (_isScrolling) {
			_queuedUpdateTabs = true;
		}
		else {
			Persistence.didUpdateTabs();
		}
	}

	bool _onScrollNotification(Notification notification) {
		if (notification is ScrollStartNotification) {
			_isScrolling = true;
		}
		else if (notification is ScrollEndNotification) {
			_isScrolling = false;
			if (_queuedUpdateTabs) {
				Persistence.didUpdateTabs();
			}
		}
		return false;
	}

	void _onDevNotificationTapped(BoardThreadOrPostIdentifier id) async {
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
					thread: id.threadIdentifier!,
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
		if (_lastLink != null && link == _lastLink?.item2 && DateTime.now().isBefore(_lastLink!.item1.add(const Duration(seconds: 1)))) {
			return;
		}
		_lastLink = Tuple2(DateTime.now(), link);
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
						builder: (dialogContext) => CupertinoAlertDialog(
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
													theme: theme
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
								CupertinoDialogAction(
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
								CupertinoDialogAction(
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
								CupertinoDialogAction(
									onPressed: match != null ? null : () {
										settings.addTheme(name, theme);
										settings.handleThemesAltered();
										Navigator.of(dialogContext).pop();
									},
									child: const Text('Just import')
								),
								CupertinoDialogAction(
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
						final consent = await showCupertinoDialog<bool>(
							context: context,
							barrierDismissible: true,
							builder: (context) => CupertinoAlertDialog(
								title: Text('Add site $siteKey?'),
								actions: [
									CupertinoDialogAction(
										child: const Text('Cancel'),
										onPressed: () {
											Navigator.of(context).pop();
										}
									),
									CupertinoDialogAction(
										isDefaultAction: true,
										onPressed: () {
											Navigator.of(context).pop(true);
										},
										child: const Text('OK')
									)
								]
							)
						);
						if (consent != true) {
							return;
						}
						final siteResponse = await Dio().get('$contentSettingsApiRoot/site/$siteKey');
						if (siteResponse.data['error'] != null) {
							throw Exception(siteResponse.data['error']);
						}
						makeSite(siteResponse.data['data']);
						final response = await Dio().put('$contentSettingsApiRoot/user/${Persistence.settings.userId}/site/$siteKey');
						if (response.data['error'] != null) {
							throw Exception(response.data['error']);
						}
						await settings.updateContentSettings();
						await Future.delayed(const Duration(milliseconds: 500)); // wait for rebuild of ChanHomePage
					}
					_addNewTab(
						withImageboardKey: siteKey,
						activate: true
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
			for (final imageboard in ImageboardRegistry.instance.imageboards) {
				BoardThreadOrPostIdentifier? dest = imageboard.site.decodeUrl(link);
				for (final archive in imageboard.site.archives) {
					if (dest != null) {
						break;
					}
					dest = archive.decodeUrl(link);
				}
				if (dest != null) {
					_onNotificationTapped(imageboard, dest);
					return;
				}
			}
			final dest = devImageboard?.site.decodeUrl(link);
			if (dest != null) {
				_onDevNotificationTapped(dest);
				return;
			}
			final open = await showCupertinoDialog<bool>(
				context: context,
				barrierDismissible: true,
				builder: (context) => CupertinoAlertDialog(
					title: const Text('Unrecognized link'),
					content: Text('No site supports opening "$link"'),
					actions: [
						CupertinoDialogAction(
							onPressed: () => Navigator.pop(context, true),
							child: const Text('Open in browser')
						),
						CupertinoDialogAction(
							onPressed: () => Navigator.pop(context, false),
							child: const Text('Close')
						)
					]
				)
			);
			if (open == true) {
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
					_savedMasterDetailKey.currentState?.setValue(0, ImageboardScoped(
						imageboard: imageboard,
						item: watch
					));
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

	void _browserHistoryStatusListener() {
		if (mounted) {
			setState(() {});
		}
	}

	void _tabsListener() {
		if (mounted) {
			activeBrowserTab.value = Persistence.currentTabIndex;
		}
	}

	@override
	void initState() {
		super.initState();
		browseCountListenable = Listenable.merge([activeBrowserTab, ...Persistence.tabs.map((x) => x.unseen)]);
		activeBrowserTab.value = Persistence.currentTabIndex;
		Persistence.browserHistoryStatusListenable.addListener(_browserHistoryStatusListener);
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
		if (!Persistence.settings.promptedAboutCrashlytics && !_promptedAboutCrashlytics) {
			_promptedAboutCrashlytics = true;
			Future.delayed(const Duration(milliseconds: 300), () async {
				if (!mounted) return;
				final choice = await showCupertinoDialog<bool>(
					context: context,
					builder: (context) => CupertinoAlertDialog(
						title: const Text('Contribute crash data?'),
						content: const Text('Crash stack traces and uncaught exceptions will be used to help fix bugs. No personal information will be collected.'),
						actions: [
							CupertinoDialogAction(
								child: const Text('No'),
								onPressed: () {
									Navigator.of(context).pop(false);
								}
							),
							CupertinoDialogAction(
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
	}

	PersistentBrowserTab _addNewTab({
		String? withImageboardKey,
		int? atPosition,
		String? withBoard,
		int? withThreadId,
		bool activate = false,
		int? withInitialPostId
	}) {
		final pos = atPosition ?? Persistence.tabs.length;
		final tab = PersistentBrowserTab(
			imageboardKey: withImageboardKey,
			board: withImageboardKey == null || withBoard == null ? null : ImageboardRegistry.instance.getImageboard(withImageboardKey)?.persistence.getBoard(withBoard),
			thread: withThreadId == null ? null : ThreadIdentifier(withBoard!, withThreadId)
		);
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
		showTabPopup = !activate || !Persistence.settings.closeTabSwitcherAfterUse;
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
									onWantOpenThreadInNewTab: (imageboardKey, thread) {
										_addNewTab(
											withImageboardKey: imageboardKey,
											atPosition: Persistence.tabs.indexOf(tabObject) + 1,
											withBoard: thread.board,
											withThreadId: thread.id
										);
									},
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
										ChangeNotifierProvider.value(value: tabObject)
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
			child = ChangeNotifierProvider.value(
				value: _savedFakeTab,
				child: SavedPage(
					isActive: active,
					masterDetailKey: _savedMasterDetailKey,
					onWantOpenThreadInNewTab: (imageboardKey, thread) {
						_addNewTab(
							withImageboardKey: imageboardKey,
							withBoard: thread.board,
							withThreadId: thread.id,
							activate: true
						);
					}
				)
			);
		}
		else if (index == 2) {
			child = HistoryPage(
				isActive: active,
				onWantOpenThreadInNewTab: (imageboardKey, thread) {
					_addNewTab(
						withImageboardKey: imageboardKey,
						withBoard: thread.board,
						withThreadId: thread.id,
						activate: true
					);
				}
			);
		}
		else if (index == 3) {
			child = SearchPage(
				key: _searchPageKey
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
								ChangeNotifierProvider.value(value: devImageboard!),
								Provider.value(value: devImageboard!.site),
								ChangeNotifierProvider.value(value: devImageboard!.persistence),
								ChangeNotifierProvider.value(value: devImageboard!.threadWatcher),
								Provider.value(value: devImageboard!.notifications)
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
							if (Persistence.tabs.length > 1) {
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
											isDestructiveAction: true,
											onPressed: () {
												Persistence.tabs.removeAt(-1 * index);
												browseCountListenable = Listenable.merge([activeBrowserTab, ...Persistence.tabs.map((x) => x.unseen)]);
												final newActiveTabIndex = min(activeBrowserTab.value, Persistence.tabs.length - 1);
												activeBrowserTab.value = newActiveTabIndex;
												Persistence.currentTabIndex = newActiveTabIndex;
												_didUpdateTabs();
												setState(() {});
											}
										)
									]
								);
							}
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

	Widget _buildNewTabIcon({bool hideLabel = false}) {
		return GestureDetector(
			onLongPress: () async {
				lightHapticFeedback();
				final shouldCloseOthers = await showCupertinoDialog<bool>(
					context: context,
					barrierDismissible: true,
					builder: (context) => CupertinoAlertDialog(
						title: const Text('Close all other tabs?'),
						actions: [
							CupertinoDialogAction(
								onPressed: () => Navigator.of(context).pop(false),
								child: const Text('No')
							),
							CupertinoDialogAction(
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
			},
			child: CupertinoButton(
				padding: const EdgeInsets.only(top: 16, bottom: 16, left: 8, right: 8),
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

	Widget _buildTabList(Axis axis) {
		return ReorderableList(
			controller: _tabListController,
			scrollDirection: axis,
			physics: const BouncingScrollPhysics(),
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
							final threadState = Persistence.tabs[i].thread == null ? null : Persistence.tabs[i].imageboard?.persistence.getThreadStateIfExists(Persistence.tabs[i].thread!);
							if (threadState != null) {
								Future.microtask(() => Persistence.tabs[i].unseen.value = threadState.unseenReplyCount(Filter.of(context, listen: false)) ?? 0);
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
									primary: threadState.unseenReplyIdsToYouCount(Filter.of(context)) ?? 0,
									secondary: threadState.unseenReplyCount(Filter.of(context)) ?? 0
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
					return _buildTabletIcon(
						i * -1,
						icon,
						Persistence.tabs[i].board != null ? '/${Persistence.tabs[i].board?.name}/' : (Persistence.tabs[i].imageboardKey ?? 'None'),
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
							if (imageboard == null) {
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
										animation: imageboard.persistence.listenForPersistentThreadStateChanges(thread),
										builder: (context, _) {
											final threadState = imageboard.persistence.getThreadStateIfExists(thread);
											if (threadState == null) {
												return buildStationaryIcon();
											}
											else {
												return AnimatedBuilder(
													animation: threadState.lastSeenPostIdNotifier,
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
			case null:
				break;
		}
	}

	void _toggleHistory() {
		mediumHapticFeedback();
		Persistence.enableHistory = !Persistence.enableHistory;
		Persistence.didChangeBrowserHistoryStatus();
		showToast(
			context: context,
			message: Persistence.enableHistory ? 'History resumed' : 'History stopped',
			icon: Persistence.enableHistory ? CupertinoIcons.play : CupertinoIcons.stop
		);
	}

	bool get isInTabletLayout => (MediaQuery.of(context).size.width - 85) > (MediaQuery.of(context).size.height - 50);

	@override
	Widget build(BuildContext context) {
		final hideTabletLayoutLabels = MediaQuery.of(context).size.height < 600;
		if (!ImageboardRegistry.instance.initialized) {
			return const ChanSplashPage();
		}
		for (final board in ImageboardRegistry.instance.imageboards) {
			if (_notificationsSubscriptions[board.key]?.item1 != board.notifications) {
				_notificationsSubscriptions[board.key]?.item2.cancel();
				_notificationsSubscriptions[board.key] = Tuple2(board.notifications, board.notifications.tapStream.listen((target) {
					_onNotificationTapped(board, target);
				}));
			}
		}
		Widget child = isInTabletLayout ? NotificationListener<ScrollNotification>(
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
						child: SafeArea(
							top: false,
							bottom: false,
							child: Row(
								children: [
									Container(
										padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
										color: context.select<EffectiveSettings, Color>((s) => s.theme.barColor),
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
													child: _buildTabletIcon(2, Persistence.enableHistory ? const Icon(CupertinoIcons.archivebox) : const Icon(CupertinoIcons.eye_slash), hideTabletLayoutLabels ? null : 'History')
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
							inactiveColor: CupertinoTheme.of(context).primaryColor.withOpacity(0.4),
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
										child: Persistence.enableHistory ? const Icon(CupertinoIcons.archivebox, size: 28) : const Icon(CupertinoIcons.eye_slash, size: 28)
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
							builder: (context) => Column(
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
				dataReceived: (data) {
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
		Persistence.browserHistoryStatusListenable.removeListener(_browserHistoryStatusListener);
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
			subscription.item2.cancel();
		}
	}
}
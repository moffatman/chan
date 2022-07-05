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
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/notifications.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/pick_attachment.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/cupertino_page_route.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/notifications_overlay.dart';
import 'package:chan/widgets/notifying_icon.dart';
import 'package:chan/widgets/tab_switching_view.dart';
import 'package:chan/widgets/util.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chan/pages/tab.dart';
import 'package:provider/provider.dart';
import 'package:chan/widgets/sticky_media_query.dart';
import 'package:uni_links/uni_links.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

bool _initialLinkConsumed = false;
bool _initialMediaConsumed = false;

void main() async {
	try {
		WidgetsFlutterBinding.ensureInitialized();
		final imageHttpClient = (ExtendedNetworkImageProvider.httpClient as HttpClient);
		imageHttpClient.connectionTimeout = const Duration(seconds: 10);
		imageHttpClient.idleTimeout = const Duration(seconds: 10);
		imageHttpClient.maxConnectionsPerHost = 10;
		await Persistence.initializeStatic();
		await Notifications.initializeStatic();
		runApp(const ChanApp());
	}
	catch (e, st) {
		runApp(ChanFailedApp(e, st));
	}
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

class _ChanAppState extends State<ChanApp> {
	final settings = EffectiveSettings();
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
														ImageboardRegistry.instance.context = context;
														return DefaultTextStyle(
															style: CupertinoTheme.of(context).textTheme.textStyle,
															child: RootCustomScale(
																scale: ((Platform.isMacOS || Platform.isWindows || Platform.isLinux) ? 1.3 : 1.0) / settings.interfaceScale,
																child: ImageboardRegistry.instance.initialized ? const ChanHomePage() : Container(
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
	Imageboard? devImageboard;
	Timer? _saveBrowserTabsDuringDraftEditingTimer;
	final _tabNavigatorKeys = <int, GlobalKey<NavigatorState>>{};
	final _tabletWillPopZones = <int, WillPopZone>{};
	final _settingsNavigatorKey = GlobalKey<NavigatorState>();
	bool _queuedUpdateTabs = false;
	bool _isScrolling = false;
	final _savedMasterDetailKey = GlobalKey<MultiMasterDetailPageState>();
	final PersistentBrowserTab _savedFakeTab = PersistentBrowserTab();
	final Map<String, StreamSubscription<ThreadOrPostIdentifier>> _notificationsSubscriptions = {};

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
		final tmpDevImageboard = Imageboard(
			key: 'dev',
			siteData: defaultSite,
			settings: settings
		);
		await tmpDevImageboard.initialize(
			threadWatcherInterval: const Duration(minutes: 10),
			threadWatcherWatchForStickyOnBoards: ['chance']
		);
		tmpDevImageboard.notifications.tapStream.listen(_onDevNotificationTapped);
		setState(() {
			devImageboard = tmpDevImageboard;
		});
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

	void _scrollExistingTab(PersistentBrowserTab tab, int postId) async {
		if (tab.threadController?.items.any((p) => p.id == postId) == false) {
			await Future.any([tab.threadController!.update(), Future.delayed(const Duration(milliseconds: 500))]);
		}
		tab.threadController?.animateTo((p) => p.id == postId, alignment: 1.0, orElseLast: (p) => true);
	}

	void _onNotificationTapped(Imageboard imageboard, ThreadOrPostIdentifier notification) async {
		if (!_goToPost(
			board: notification.board,
			threadId: notification.threadId,
			postId: notification.postId,
			openNewTabIfNeeded: false
		)) {
			final watch = imageboard.persistence.browserState.threadWatches.tryFirstWhere((w) => w.threadIdentifier == notification.threadIdentifier);
			if (watch != null) {
				_tabController.index = 1;
				_lastIndex = 1;
				for (int i = 0; i < 200 && _savedMasterDetailKey.currentState == null; i++) {
					await Future.delayed(const Duration(milliseconds: 50));
				}
				if (_savedMasterDetailKey.currentState?.getValue(0) == watch && notification.postId != null) {
					_scrollExistingTab(_savedFakeTab, notification.postId!);
				}
				else {
					if (notification.postId != null) {
						_savedFakeTab.initialPostId[notification.threadIdentifier] = notification.postId!;
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

	void _consumeLink(String? link) {
		for (final imageboard in ImageboardRegistry.instance.imageboards) {
			if (link != null) {
				final dest = imageboard.site.decodeUrl(link);
				if (dest != null) {
					_onNotificationTapped(imageboard, dest);
					return;
				}
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
		browseCountListenable = Listenable.merge([activeBrowserTab, ...Persistence.tabs.map((x) => x.unseen)]);
		activeBrowserTab.value = Persistence.currentTabIndex;
		_setupDevSite();
		getInitialLink().then(_onNewLink);
		linkStream.listen(_onNewLink);
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
		String? withImageboardKey,
		int? atPosition,
		ThreadIdentifier? withThread,
		bool activate = false,
		int? withInitialPostId
	}) {
		final pos = atPosition ?? Persistence.tabs.length;
		final tab = withThread == null ? PersistentBrowserTab(
			imageboardKey: withImageboardKey
		) : PersistentBrowserTab(
			imageboardKey: withImageboardKey,
			board: context.read<Persistence>().getBoard(withThread.board),
			thread: withThread
		);
		if (withThread != null && withInitialPostId != null) {
			tab.initialPostId[withThread] = withInitialPostId;
		}
		Persistence.tabs.insert(pos, tab);
		browseCountListenable = Listenable.merge([activeBrowserTab, ...Persistence.tabs.map((x) => x.unseen)]);
		if (activate) {
			_tabController.index = 0;
			activeBrowserTab.value = pos;
			Persistence.currentTabIndex = pos;
		}
		showTabPopup = true;
		Persistence.didUpdateTabs();
		setState(() {});
		Future.delayed(const Duration(milliseconds: 100), () => _tabListController.animateTo((_tabListController.position.maxScrollExtent / Persistence.tabs.length) * (pos + 1), duration: const Duration(milliseconds: 500), curve: Curves.ease));
		return tab;
	}

	bool _goToPost({
		required String board,
		required int threadId,
		int? postId,
		required bool openNewTabIfNeeded
	}) {
		PersistentBrowserTab? tab = Persistence.tabs.tryFirstWhere((tab) => tab.thread?.board == board && tab.thread?.id == threadId);
		final tabAlreadyExisted = tab != null;
		if (openNewTabIfNeeded) {
			tab ??= _addNewTab(
				activate: false,
				withThread: ThreadIdentifier(board, threadId),
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
									key: tabObject.tabKey,
									boardKey: tabObject.boardKey,
									initialBoard: tabObject.board,
									initialThread: tabObject.thread,
									onBoardChanged: (newBoard) {
										tabObject.board = newBoard.item;
										tabObject.imageboardKey = newBoard.imageboard.key;
										// Don't run I/O during the animation
										Future.delayed(const Duration(seconds: 1), Persistence.didUpdateTabs);
										tabObject.didUpdate();
									},
									onThreadChanged: (newThread) {
										tabObject.thread = newThread;
										// Don't run I/O during the animation
										Future.delayed(const Duration(seconds: 1), Persistence.didUpdateTabs);
										tabObject.didUpdate();
									},
									getInitialThreadDraftText: () => tabObject.draftThread,
									onThreadDraftTextChanged: (newText) {
										tabObject.draftThread = newText;
										_saveBrowserTabsDuringDraftEditingTimer?.cancel();
										_saveBrowserTabsDuringDraftEditingTimer = Timer(const Duration(seconds: 3), Persistence.didUpdateTabs);
									},
									getInitialThreadDraftSubject: () => tabObject.draftSubject,
									onThreadDraftSubjectChanged: (newSubject) {
										tabObject.draftSubject = newSubject;
										_saveBrowserTabsDuringDraftEditingTimer?.cancel();
										_saveBrowserTabsDuringDraftEditingTimer = Timer(const Duration(seconds: 3), Persistence.didUpdateTabs);
									},
									onWantOpenThreadInNewTab: (imageboardKey, thread) {
										_addNewTab(
											withImageboardKey: imageboardKey,
											atPosition: Persistence.tabs.indexOf(tabObject) + 1,
											withThread: thread
										);
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
											child: Builder(
												builder: (context) => FilterZone(
													filter: context.select<Persistence, Filter>((p) => p.browserState.imageMD5Filter),
													child: tab
												)
											)
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
				onWantOpenThreadInNewTab: (imageboardKey, thread) {
					_addNewTab(
						withImageboardKey: imageboardKey,
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
			if (devImageboard?.threadWatcher == null) {
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
								ChangeNotifierProvider.value(value: devImageboard!),
								Provider.value(value: devImageboard!.site),
								ChangeNotifierProvider.value(value: devImageboard!.persistence),
								ChangeNotifierProvider.value(value: devImageboard!.threadWatcher),
								Provider.value(value: devImageboard!.notifications)
							],
							child: ClipRect(
								child: Navigator(
									key: _settingsNavigatorKey,
									initialRoute: '/',
									onGenerateRoute: (settings) => FullWidthCupertinoPageRoute(
										builder: (_) => const SettingsPage(),
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
		Widget? preLabelInjection
	}) {
		final content = AnimatedBuilder(
			animation: _tabController,
			builder: (context, _) => Opacity(
				opacity: (index <= 0 ? (_tabController.index == 0 && index == -1 * activeBrowserTab.value) : index == _tabController.index) ? 1.0 : 0.5,
				child: Column(
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
		final child = CupertinoButton(
			padding: axis == Axis.vertical ? const EdgeInsets.only(top: 16, bottom: 16, left: 8, right: 8) : const EdgeInsets.only(top: 8, bottom: 8, left: 16, right: 16),
			child: content,
			onPressed: () async {
				if (index <= 0) {
					if (activeBrowserTab.value == -1 * index && _tabController.index == 0) {
						if (Persistence.tabs.length > 1) {
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
								Persistence.tabs.removeAt(-1 * index);
								browseCountListenable = Listenable.merge([activeBrowserTab, ...Persistence.tabs.map((x) => x.unseen)]);
								final newActiveTabIndex = min(activeBrowserTab.value, Persistence.tabs.length - 1);
								activeBrowserTab.value = newActiveTabIndex;
								Persistence.currentTabIndex = newActiveTabIndex;
								_didUpdateTabs();
								setState(() {});
							}
						}
					}
					else {
						activeBrowserTab.value = -1 * index;
						Persistence.currentTabIndex = -1 * index;
						_didUpdateTabs();
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
				_lastIndex = index;
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
		return GestureDetector(
			onLongPress: () async {
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
					setState(() {});
				}
			},
			child: CupertinoButton(
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
				return ReorderableDelayedDragStartListener(
					index: i,
					key: ValueKey(i),
					child: AnimatedBuilder(
						animation: Persistence.tabs[i],
						builder: (context, _) {
							if (Persistence.tabs[i].thread != null) {
								final child = AnimatedBuilder(
									animation: Persistence.tabs[i].imageboard?.persistence.listenForPersistentThreadStateChanges(Persistence.tabs[i].thread!) ?? const AlwaysStoppedAnimation(0),
									builder: (context, _) {
										final threadState = Persistence.tabs[i].imageboard?.persistence.getThreadStateIfExists(Persistence.tabs[i].thread!);
										Future.microtask(() => Persistence.tabs[i].unseen.value = threadState?.unseenReplyCount(Filter.of(context, listen: false)) ?? 0);
										final attachment = threadState?.thread?.attachment;
										buildIcon() => _buildTabletIcon(i * -1, StationaryNotifyingIcon(
												icon: attachment == null ? blankIcon : ClipRRect(
												borderRadius: const BorderRadius.all(Radius.circular(4)),
												child: AttachmentThumbnail(
													gaplessPlayback: true,
													fit: BoxFit.cover,
													attachment: attachment,
													width: 30,
													height: 30
												)
											),
												primary: threadState?.unseenReplyIdsToYou(Filter.of(context))?.length ?? 0,
												secondary: threadState?.unseenReplyCount(Filter.of(context)) ?? 0
											),
											Persistence.tabs[i].board != null ? '/${Persistence.tabs[i].board?.name}/' : 'None',
											reorderable: false,
											axis: axis,
											preLabelInjection: (ImageboardRegistry.instance.count < 2 || Persistence.tabs[i].imageboardKey == null) ? null : ImageboardIcon(imageboardKey: Persistence.tabs[i].imageboardKey!)
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
								if (Persistence.tabs[i].imageboardKey == null) {
									return child;
								}
								if (ImageboardRegistry.instance.getImageboard(Persistence.tabs[i].imageboardKey!) == null) {
									return _buildTabletIcon(
										i * -1,
										const SizedBox(
											width: 30,
											height: 30,
											child: Icon(CupertinoIcons.exclamationmark_triangle_fill)
										),
										Persistence.tabs[i].imageboardKey,
										axis: axis
									);
								}
								return ImageboardScope(
									imageboardKey: Persistence.tabs[i].imageboardKey!,
									child: child
								);
							}
							else {
								Future.microtask(() => Persistence.tabs[i].unseen.value = 0);
								return _buildTabletIcon(i * -1, blankIcon, Persistence.tabs[i].board != null ? '/${Persistence.tabs[i].board?.name}/' : 'None', reorderable: false, axis: axis);
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
		if (!ImageboardRegistry.instance.initialized) {
			return const Center(
				child: CupertinoActivityIndicator()
			);
		}
		for (final board in ImageboardRegistry.instance.imageboards) {
			if (!board.initialized) {
				continue;
			}
			_notificationsSubscriptions[board.key]?.cancel();
			_notificationsSubscriptions[board.key] = board.notifications.tapStream.listen((target) {
				_onNotificationTapped(board, target);
			});
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
													_buildTabletIcon(1, NotifyingIcon(
															icon: const Icon(CupertinoIcons.bookmark),
															primaryCount: CombiningValueListenable<int>(
																children: ImageboardRegistry.instance.imageboards.where((x) => x.initialized).map((x) => x.threadWatcher.unseenYouCount).toList(),
																combine: (a, b) => a + b,
																noChildrenValue: 0
															),
															secondaryCount: CombiningValueListenable<int>(
																children: ImageboardRegistry.instance.imageboards.where((x) => x.initialized).map((x) => x.threadWatcher.unseenCount).toList(),
																combine: (a, b) => a + b,
																noChildrenValue: 0
															)
														), hideTabletLayoutLabels ? null : 'Saved',
													),
													_buildTabletIcon(2, Persistence.enableHistory ? const Icon(CupertinoIcons.archivebox) : const Icon(CupertinoIcons.eye_slash), hideTabletLayoutLabels ? null : 'History'),
													_buildTabletIcon(3, const Icon(CupertinoIcons.search), hideTabletLayoutLabels ? null : 'Search'),
													_buildTabletIcon(4, NotifyingIcon(
															icon: const Icon(CupertinoIcons.settings),
															primaryCount: devImageboard?.threadWatcher.unseenYouCount ?? ValueNotifier(0),
															secondaryCount: devImageboard?.threadWatcher.unseenCount ?? ValueNotifier(0),
														), hideTabletLayoutLabels ? null : 'Settings'
													)
												]
											)
										),
										Expanded(
											child: Container(
												color: CupertinoTheme.of(context).scaffoldBackgroundColor,
												child: AnimatedBuilder(
													animation: _tabController,
													builder: (context, _) => TabSwitchingView(
														currentTabIndex: _tabController.index,
														tabCount: 5,
														tabBuilder: (context, i) => _buildTab(context, i, i == _tabController.index)
													)
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
												children: ImageboardRegistry.instance.imageboards.where((x) => x.initialized).map((x) => x.threadWatcher.unseenYouCount).toList(),
												combine: (a, b) => a + b,
												noChildrenValue: 0
											),
											secondaryCount: CombiningValueListenable<int>(
												children: ImageboardRegistry.instance.imageboards.where((x) => x.initialized).map((x) => x.threadWatcher.unseenCount).toList(),
												combine: (a, b) => a + b,
												noChildrenValue: 0
											)
										)
									),
									label: 'Saved'
								),
								BottomNavigationBarItem(
									icon: Persistence.enableHistory ? const Icon(CupertinoIcons.archivebox, size: 28) : const Icon(CupertinoIcons.eye_slash, size: 28),
									label: 'History'
								),
								const BottomNavigationBarItem(
									icon: Icon(CupertinoIcons.search, size: 28),
									label: 'Search'
								),
								BottomNavigationBarItem(
									icon: NotifyingIcon(
										icon: const Icon(CupertinoIcons.settings, size: 28),
										primaryCount: devImageboard?.threadWatcher.unseenYouCount ?? ValueNotifier(0),
										secondaryCount: devImageboard?.threadWatcher.unseenCount ?? ValueNotifier(0),
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
			imageboards: [
				...ImageboardRegistry.instance.imageboards.where((x) => x.initialized),
				if (devImageboard?.notifications != null) devImageboard!
			],
			child: child
		);
	}
}
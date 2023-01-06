

import 'dart:math';

import 'package:chan/models/board.dart';
import 'package:chan/services/notifications.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/util.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:mutex/mutex.dart';

class ImageboardNotFoundException implements Exception {
	String board;
	ImageboardNotFoundException(this.board);
	@override
	String toString() => 'Imageboard not found: $board';
}

class Imageboard extends ChangeNotifier {
	final EffectiveSettings settings;
	dynamic siteData;
	late ImageboardSite site;
	late final Persistence persistence;
	late final ThreadWatcher threadWatcher;
	late final Notifications notifications;
	String? setupErrorMessage;
	String? boardFetchErrorMessage;
	bool boardsLoading = false;
	bool initialized = false;
	bool _persistenceInitialized = false;
	bool _threadWatcherInitialized = false;
	bool _notificationsInitialized = false;
	final String key;
	bool get seemsOk => initialized && !(boardsLoading && persistence.boards.isEmpty) && setupErrorMessage == null && boardFetchErrorMessage == null;
	final ThreadWatcherController? threadWatcherController;

	Imageboard({
		required this.key,
		required this.settings,
		required this.siteData,
		this.threadWatcherController
	});
	
	void updateSiteData(dynamic siteData) {
		try {
			final oldSite = site;
			site = makeSite(siteData);
			site.persistence = persistence;
			if (site != oldSite) {
				notifyListeners();
			}
		}
		catch (e) {
			setupErrorMessage = e.toStringDio();
			notifyListeners();
		}
	}

	Future<void> initialize({
		List<String> threadWatcherWatchForStickyOnBoards = const []
	}) async {
		try {
			site = makeSite(siteData);
			persistence = Persistence(key);
			await persistence.initialize();
			site.persistence = persistence;
			_persistenceInitialized = true;
			notifications = Notifications(
				persistence: persistence,
				site: site
			);
			await notifications.initialize();
			_notificationsInitialized = true;
			threadWatcher = ThreadWatcher(
				imageboardKey: key,
				site: site,
				persistence: persistence,
				settings: settings,
				notifications: notifications,
				watchForStickyOnBoards: threadWatcherWatchForStickyOnBoards,
				controller: threadWatcherController ?? ImageboardRegistry.threadWatcherController
			);
			notifications.localWatcher = threadWatcher;
			_threadWatcherInitialized = true;
			setupBoards(); // don't await
			initialized = true;
		}
		catch (e, st) {
			setupErrorMessage = e.toStringDio();
			print('Error initializing $key');
			print(e);
			print(st);
		}
		notifyListeners();
	}

	Future<void> deleteAllData() async {
		await notifications.deleteAllNotificationsFromServer();
		await persistence.deleteAllData();
	}

	Future<void> setupBoards() async {
		try {
			boardsLoading = true;
			boardFetchErrorMessage = null;
			notifyListeners();
			final freshBoards = await site.getBoards();
			if (freshBoards.isEmpty) {
				throw('No boards found');
			}
			await persistence.storeBoards(freshBoards);
		}
		catch (error, st) {
			print('Error setting up boards for $key');
			print(error);
			print(st);
			boardFetchErrorMessage = error.toStringDio();
		}
		boardsLoading = false;
		notifyListeners();
	}

	Future<List<ImageboardBoard>> refreshBoards() async {
		final freshBoards = await site.getBoards();
		await persistence.storeBoards(freshBoards);
		return freshBoards;
	}

	@override
	void dispose() {
		super.dispose();
		if (_threadWatcherInitialized) {
			threadWatcher.dispose();
		}
		if (_persistenceInitialized) {
			persistence.dispose();
		}
		if (_notificationsInitialized) {
			notifications.dispose();
		}
	}

	ImageboardScoped<T> scope<T>(T item) => ImageboardScoped(
		imageboard: this,
		item: item
	);
}

class ImageboardRegistry extends ChangeNotifier {
	static ImageboardRegistry? _instance;
	static ImageboardRegistry get instance {
		_instance ??= ImageboardRegistry._();
		return _instance!;
	}

	ImageboardRegistry._();
	
	String? setupError;
	String? setupStackTrace;
	final Map<String, Imageboard> _sites = {};
	int get count => _sites.length;
	Iterable<Imageboard> get imageboardsIncludingUninitialized => _sites.values;
	Iterable<Imageboard> get imageboards => _sites.values.where((s) => s.initialized);
	bool initialized = false;
	BuildContext? context;
	final _mutex = Mutex();
	static final threadWatcherController = ThreadWatcherController();

	Future<void> handleSites({
		required EffectiveSettings settings,
		required Map<String, dynamic> data,
		required BuildContext context
	}) {
		return _mutex.protect(() async {
			initialized = false;
			context = context;
			setupError = null;
			try {
				final siteKeysToRemove = _sites.keys.toList();
				final initializations = <Future<void>>[];
				final microtasks = <Future<void> Function()>[];
				for (final entry in data.entries) {
					siteKeysToRemove.remove(entry.key);
					if (_sites.containsKey(entry.key)) {
						// Site not changed
						_sites[entry.key]?.updateSiteData(entry.value);
					}
					else {
						_sites[entry.key] = Imageboard(
							settings: settings,
							siteData: entry.value,
							key: entry.key
						);
						initializations.add(_sites[entry.key]!.initialize());
					}
					// Only try to reauth on wifi
					microtasks.add(() async {
						if (!_sites[entry.key]!.initialized) {
							return;
						}
						final site = _sites[entry.key]!.site;
						final savedFields = site.getSavedLoginFields();
						if (savedFields != null && settings.connectivity == ConnectivityResult.wifi) {
							try {
								await site.login(savedFields);
								print('Auto-logged in');
							}
							catch (e) {
								showToast(
									context: context,
									icon: CupertinoIcons.exclamationmark_triangle,
									message: 'Failed to log in to ${site.getLoginSystemName()}'
								);
								print('Problem auto-logging in: $e');
							}
						}
					});
				}
				await Future.wait(initializations);
				microtasks.forEach(Future.microtask);
				final initialTabsLength = Persistence.tabs.length;
				final initialTab = Persistence.tabs[Persistence.currentTabIndex];
				final initialTabIndex = Persistence.currentTabIndex;
				for (final key in siteKeysToRemove) {
					_sites[key]?.dispose();
					_sites.remove(key);
					Persistence.tabs.removeWhere((t) => t.imageboardKey == key);
				}
				if (Persistence.tabs.contains(initialTab)) {
					Persistence.currentTabIndex = Persistence.tabs.indexOf(initialTab);
				}
				else if (Persistence.tabs.isEmpty) {
					Persistence.tabs.add(PersistentBrowserTab());
					Persistence.currentTabIndex = 0;
				}
				else {
					Persistence.currentTabIndex = min(Persistence.tabs.length - 1, initialTabIndex);
				}
				for (final tab in Persistence.tabs) {
					tab.initialize();
				}
				if (initialTabsLength != Persistence.tabs.length) {
					Persistence.didUpdateTabs();
				}
			}
			catch (e, st) {
				setupError = 'Fatal setup error\n${e.toStringDio()}';
				setupStackTrace = st.toStringDio();
				print(e);
				print(st);
			}
			initialized = true;
			notifyListeners();
		});
	}

	Imageboard? getImageboard(String key) {
		if (_sites[key]?.initialized == true) {
			return _sites[key];
		}
		return null;
	}

	Imageboard? getImageboardUnsafe(String key) {
		return _sites[key];
	}

	Future<void> retryFailedBoardSetup() async {
		final futures = <Future>[];
		for (final i in imageboards) {
			if (i.boardFetchErrorMessage != null) {
				futures.add(i.setupBoards());
			}
		}
		await Future.wait(futures);
	}
}

class ImageboardScoped<T> {
	final Imageboard imageboard;
	final T item;

	ImageboardScoped({
		required this.imageboard,
		required this.item
	});

	@override
	bool operator == (dynamic other) => (other is ImageboardScoped) && (other.imageboard == imageboard) && (other.item == item);
	@override
	int get hashCode => Object.hash(imageboard, item);
}
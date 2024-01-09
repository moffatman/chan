import 'dart:async';

import 'package:chan/models/thread.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/notifications.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:mutex/mutex.dart';

part 'thread_watcher.g.dart';

enum WatchAction {
	notify,
	save
}

abstract class Watch {
	String get type;
	Map<String, dynamic> toMap() {
		return {
			'type': type,
			..._toMap()
		};
	}
	Map<String, dynamic> _toMap();
	@override
	String toString() => 'Watch(${toMap()})';
	bool get push => true;
}

@HiveType(typeId: 28)
class ThreadWatch extends Watch {
	@HiveField(0)
	final String board;
	@HiveField(1)
	final int threadId;
	@HiveField(2)
	int lastSeenId;
	@HiveField(3, defaultValue: true)
	bool localYousOnly;
	@HiveField(4, defaultValue: [])
	List<int> youIds;
	@HiveField(5, defaultValue: false)
	bool zombie;
	@HiveField(6, defaultValue: true)
	bool pushYousOnly;
	@HiveField(7, defaultValue: true)
	@override
	bool push;
	@HiveField(8, defaultValue: false)
	bool foregroundMuted;
	ThreadWatch({
		required this.board,
		required this.threadId,
		required this.lastSeenId,
		required this.localYousOnly,
		required this.youIds,
		this.zombie = false,
		bool? pushYousOnly,
		this.push = true,
		this.foregroundMuted = false
	}) : pushYousOnly = pushYousOnly ?? localYousOnly;
	@override
	String get type => 'thread';
	@override
	Map<String, dynamic> _toMap() => {
		'lastSeenId': lastSeenId,
		'board': board,
		'threadId': threadId.toString(),
		'yousOnly': pushYousOnly,
		'youIds': youIds
	};
	ThreadIdentifier get threadIdentifier => ThreadIdentifier(board, threadId);

	bool settingsEquals(ThreadWatch other) {
		return other.push == push &&
		       other.foregroundMuted == foregroundMuted &&
					 other.localYousOnly == localYousOnly &&
					 other.pushYousOnly == pushYousOnly;
	}
}

@HiveType(typeId: 29)
class BoardWatch extends Watch {
	@HiveField(0)
	String board;
	@HiveField(3)
	bool threadsOnly;
	BoardWatch({
		required this.board,
		required this.threadsOnly
	});
	@override
	String get type => 'board';
	@override
	Map<String, dynamic> _toMap() => {
		'board': board,
		'threadsOnly': threadsOnly
	};
}

const _briefInterval = Duration(seconds: 1);

class ThreadWatcher extends ChangeNotifier {
	final String imageboardKey;
	final ImageboardSite site;
	final Persistence persistence;
	final Notifications notifications;
	final Map<ThreadIdentifier, int> cachedUnseen = {};
	final Map<ThreadIdentifier, int> cachedUnseenYous = {};
	StreamSubscription<BoxEvent>? _boxSubscription;
	final fixBrokenLock = Mutex();
	final Set<ThreadIdentifier> fixedThreads = {};
	final List<String> watchForStickyOnBoards;
	final Map<String, List<Thread>> _lastCatalogs = {};
	final List<ThreadIdentifier> _unseenStickyThreads = [];
	final ThreadWatcherController controller;
	final unseenCount = ValueNotifier<int>(0);
	final unseenYouCount = ValueNotifier<int>(0);

	final _initialCountsDone = Completer<void>();
	late Set<String> _lastHiddenImageMD5s;
	
	ThreadWatcher({
		required this.imageboardKey,
		required this.site,
		required this.persistence,
		required this.notifications,
		required this.controller,
		this.watchForStickyOnBoards = const []
	}) {
		controller.registerWatcher(this);
		_boxSubscription = Persistence.sharedThreadStateBox.watch().listen(_threadUpdated);
		_setInitialCounts();
		EffectiveSettings.instance.filterListenable.addListener(_didUpdateFilter);
		EffectiveSettings.instance.addListener(_didUpdateSettings);
		_lastHiddenImageMD5s = Persistence.settings.hiddenImageMD5s.toSet();
	}

	void _didUpdateFilter() {
		_setInitialCounts();
	}

	void _didUpdateSettings() {
		if (!setEquals(_lastHiddenImageMD5s, Persistence.settings.hiddenImageMD5s)) {
			_didUpdateFilter();
			_lastHiddenImageMD5s = Persistence.settings.hiddenImageMD5s.toSet();
		}
	}

	Future<void> _setInitialCounts() async {
		for (final watch in persistence.browserState.threadWatches.values) {
			await persistence.getThreadStateIfExists(watch.threadIdentifier)?.ensureThreadLoaded();
			cachedUnseenYous[watch.threadIdentifier] = persistence.getThreadStateIfExists(watch.threadIdentifier)?.unseenReplyIdsToYouCount() ?? 0;
			if (!watch.localYousOnly) {
				cachedUnseen[watch.threadIdentifier] = persistence.getThreadStateIfExists(watch.threadIdentifier)?.unseenReplyCount() ?? 0;
			}
			await Future.microtask(() => {});
		}
		_updateCounts();
		if (!_initialCountsDone.isCompleted) {
			_initialCountsDone.complete();
		}
	}

	void _updateCounts() {
		if (cachedUnseen.isNotEmpty) {
			unseenCount.value = cachedUnseen.values.reduce((a, b) => a + b) + _unseenStickyThreads.length;
		}
		else {
			unseenCount.value = 0;
		}
		if (cachedUnseenYous.isNotEmpty) {
			unseenYouCount.value = cachedUnseenYous.values.reduce((a, b) => a + b);
		}
		else {
			unseenYouCount.value = 0;
		}
	}

	void onWatchUpdated(Watch watch) async {
		await _initialCountsDone.future;
		if (watch is ThreadWatch) {
			cachedUnseenYous[watch.threadIdentifier] = persistence.getThreadStateIfExists(watch.threadIdentifier)?.unseenReplyIdsToYouCount() ?? 0;
			if (watch.localYousOnly) {
				cachedUnseen.remove(watch.threadIdentifier);
			}
			else {
				cachedUnseen[watch.threadIdentifier] = persistence.getThreadStateIfExists(watch.threadIdentifier)?.unseenReplyCount() ?? 0;
			}
			_updateCounts();
		}
		else if (watch is BoardWatch) {

		}
	}

	void onWatchRemoved(Watch watch) {
		if (watch is ThreadWatch) {
			cachedUnseenYous.remove(watch.threadIdentifier);
			cachedUnseen.remove(watch.threadIdentifier);
			_updateCounts();
		}
		else if (watch is BoardWatch) {

		}
	}

	void _threadUpdated(BoxEvent event) async {
		await _initialCountsDone.future;
		// Update notification counters when last-seen-id is saved to disk
		if (event.value is PersistentThreadState) {
			final newThreadState = event.value as PersistentThreadState;
			if (newThreadState.imageboardKey != imageboardKey) {
				return;
			}
			if (newThreadState.thread != null) {
				if (_unseenStickyThreads.contains(newThreadState.identifier)) {
					_unseenStickyThreads.remove(newThreadState.identifier);
					_updateCounts();
				}
				final watch = persistence.browserState.threadWatches[newThreadState.identifier];
				if (watch != null) {
					cachedUnseenYous[watch.threadIdentifier] = persistence.getThreadStateIfExists(watch.threadIdentifier)?.unseenReplyIdsToYouCount() ?? 0;
					if (!watch.localYousOnly) {
						cachedUnseen[watch.threadIdentifier] = persistence.getThreadStateIfExists(watch.threadIdentifier)?.unseenReplyCount() ?? 0;
					}
					_updateCounts();
					if (newThreadState.thread!.isArchived && !watch.zombie) {
						notifications.zombifyThreadWatch(watch);
					}
					if (!listEquals(watch.youIds, newThreadState.youIds)) {
						watch.youIds = newThreadState.youIds;
						notifications.didUpdateWatch(watch);
					}
					if (watch.lastSeenId < newThreadState.thread!.posts.last.id) {
						notifications.updateLastKnownId(watch, newThreadState.thread!.posts.last.id);
					}
				}
			}
		}
	}

	Future<void> updateThread(ThreadIdentifier identifier) async {
		await _updateThread(persistence.getThreadState(identifier));
	}

	Future<bool> _updateThread(PersistentThreadState threadState) async {
		Thread? newThread;
		try {
			newThread = await site.getThread(threadState.identifier, priority: RequestPriority.functional);
		}
		on ThreadNotFoundException {
			final watch = persistence.browserState.threadWatches[threadState.identifier];
			// Ensure that the thread has been loaded at least once to avoid deleting upon creation due to a race condition
			if (watch != null && threadState.thread != null) {
				print('Zombifying watch for ${threadState.identifier} since it is in 404 state');
				notifications.zombifyThreadWatch(watch);
			}
			if (site.archives.isEmpty) {
				// No archives possible
				threadState.thread?.isDeleted = true;
				threadState.save();
				return true;
			}
			try {
				newThread = await site.getThreadFromArchive(threadState.identifier, priority: RequestPriority.functional);
			}
			on ThreadNotFoundException {
				return false;
			}
			on BoardNotFoundException {
				// Board not archived
				return false;
			}
			on BoardNotArchivedException {
				return false;
			}
		}
		if (newThread != threadState.thread) {
			newThread.mergePosts(threadState.thread, threadState.thread?.posts_ ?? [], site.placeOrphanPost);
			threadState.thread = newThread;
			threadState.save();
			return true;
		}
		return false;
	}

	Future<void> update() async {
		if (ImageboardRegistry.instance.getImageboard(imageboardKey)?.seemsOk == false) {
			return;
		}
		// Could be concurrently-modified
		for (final watch in notifications.threadWatches.values) {
			if (watch.zombie) {
				continue;
			}
			final threadState = persistence.getThreadState(watch.threadIdentifier);
			if (threadState.identifier == ThreadIdentifier('', 0)) {
				print('Cleaning up watch for deleted thread ${persistence.imageboardKey}/${watch.board}/${watch.threadId}');
				await threadState.delete();
				notifications.removeWatch(watch);
			}
			else {
				await _updateThread(threadState);
			}
		}
		for (final tab in Persistence.tabs) {
			if (tab.imageboardKey == imageboardKey && tab.threadPageState == null && tab.thread != null) {
				// Thread page widget hasn't yet been instantiated
				final threadState = persistence.getThreadStateIfExists(tab.thread!);
				if (threadState != null && threadState.thread?.isArchived != true && threadState.thread?.isDeleted != true) {
					await _updateThread(threadState);
				}
			}
		}
		_lastCatalogs.clear();
		_unseenStickyThreads.clear();
		for (final board in watchForStickyOnBoards) {
			_lastCatalogs[board] ??= await site.getCatalog(board, priority: RequestPriority.functional);
			_unseenStickyThreads.addAll(_lastCatalogs[board]!.where((t) => t.isSticky).where((t) => persistence.getThreadStateIfExists(t.identifier) == null).map((t) => t.identifier).toList());
			// Update sticky threads for (you)s
			final stickyThreadStates = _lastCatalogs[board]!.where((t) => t.isSticky).map((t) => persistence.getThreadStateIfExists(t.identifier)).where((s) => s != null).map((s) => s!).toList();
			for (final threadState in stickyThreadStates) {
				await threadState.ensureThreadLoaded(preinit: false);
				if (threadState.youIds.isNotEmpty) {
					try {
						final newThread = await site.getThread(threadState.thread!.identifier, priority: RequestPriority.functional);
						if (newThread != threadState.thread) {
							newThread.mergePosts(threadState.thread, threadState.thread?.posts_ ?? [], site.placeOrphanPost);
							threadState.thread = newThread;
							await threadState.save();
						}
					}
					on ThreadNotFoundException {
						threadState.thread?.isSticky = false;
						await threadState.save();
					}
				}
			}
		}
		bool savedAnyThread = false;
		for (final line in EffectiveSettings.instance.customFilterLines) {
			if (line.disabled || (!line.outputType.autoSave && line.outputType.autoWatch == null)) {
				continue;
			}
			for (final board in line.boards) {
				final imageboardBoard = persistence.maybeGetBoard(board);
				if (imageboardBoard == null) {
					continue;
				}
				final catalog = _lastCatalogs[board] ??= await site.getCatalog(board, priority: RequestPriority.functional);
				for (final thread in catalog) {
					if (line.filter(thread)?.type.autoSave ?? false) {
						if (!(persistence.browserState.autosavedIds[board]?.contains(thread.id) ?? false)) {
							final threadState = persistence.getThreadState(thread.identifier);
							threadState.savedTime = DateTime.now();
							threadState.thread = thread;
							persistence.browserState.autosavedIds.putIfAbsent(thread.board, () => []).add(thread.id);
							await threadState.save();
							savedAnyThread = true;
						}
					}
					final autoWatch = line.filter(thread)?.type.autoWatch;
					if (autoWatch != null) {
						if (!(persistence.browserState.autowatchedIds[board]?.contains(thread.id) ?? false)) {
							final threadState = persistence.getThreadState(thread.identifier);
							threadState.thread = thread;
							final defaultThreadWatch = EffectiveSettings.instance.defaultThreadWatch;
							notifications.subscribeToThread(
								thread: thread.identifier,
								lastSeenId: thread.posts_.last.id,
								localYousOnly: defaultThreadWatch?.localYousOnly ?? false,
								pushYousOnly: defaultThreadWatch?.pushYousOnly ?? false,
								push: autoWatch.push ?? defaultThreadWatch?.push ?? true,
								youIds: threadState.youIds,
								foregroundMuted: defaultThreadWatch?.foregroundMuted ?? false
							);
							persistence.browserState.autowatchedIds.putIfAbsent(thread.board, () => []).add(thread.id);
							savedAnyThread = true;
						}
					}
				}
			}
		}
		if (savedAnyThread) {
			await persistence.didUpdateBrowserState();
		}
		_updateCounts();
	}

	Future<void> fixBrokenThread(ThreadIdentifier thread) async {
		await fixBrokenLock.protect(() async {
			if (fixedThreads.contains(thread)) {
				// fixed while we were waiting
				return;
			}
			final state = persistence.getThreadStateIfExists(thread);
			if (state != null) {
				if (await _updateThread(state)) {
					fixedThreads.add(thread);
				}
			}
		});
	}

	List<Thread>? peekLastCatalog(String board) => _lastCatalogs[board];

	@override
	void dispose() {
		controller.unregisterWatcher(this);
		_boxSubscription?.cancel();
		_boxSubscription = null;
		unseenCount.dispose();
		unseenYouCount.dispose();
		EffectiveSettings.instance.filterListenable.removeListener(_didUpdateFilter);
		EffectiveSettings.instance.removeListener(_didUpdateSettings);
		super.dispose();
	}
}

class ThreadWatcherController extends ChangeNotifier {
	final Duration interval;
	DateTime? lastUpdate;
	Timer? nextUpdateTimer;
	DateTime? nextUpdate;
	bool get active => updatingNow || (nextUpdateTimer?.isActive ?? false);
	bool disposed = false;
	final Set<ThreadWatcher> _watchers = {};
	final Set<ThreadWatcher> _doghouse = {};
	bool updatingNow = false;
	bool _addedResumeCallback = false;

	ThreadWatcherController({
		this.interval = const Duration(seconds: 90),
	}) {
		nextUpdateTimer = Timer(_briefInterval, update);
	}

	void registerWatcher(ThreadWatcher watcher) {
		_watchers.add(watcher);
	}
	
	void unregisterWatcher(ThreadWatcher watcher) {
		_watchers.remove(watcher);
	}

	Future<void> update() async {
		if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
			// Don't update when app is in background
			if (!_addedResumeCallback) {
				EffectiveSettings.instance.addAppResumeCallback(update);
			}
			_addedResumeCallback = true;
			return;
		}
		_addedResumeCallback = false;
		updatingNow = true;
		notifyListeners();
		if (!ImageboardRegistry.instance.initialized || _watchers.isEmpty) {
			lastUpdate = DateTime.now();
			nextUpdate = lastUpdate!.add(_briefInterval);
			nextUpdateTimer?.cancel();
			nextUpdateTimer = Timer(_briefInterval, update);
		}
		else {
			updateNotificationsBadgeCount();
			for (final watcher in _watchers) {
				if (_doghouse.contains(watcher)) {
					_doghouse.remove(watcher);
					continue;
				}
				try {
					await watcher.update();
				}
				catch (e, st) {
					print(e);
					print(st);
					_doghouse.add(watcher);
				}
			}
			lastUpdate = DateTime.now();
			nextUpdate = lastUpdate!.add(interval);
			nextUpdateTimer?.cancel();
			nextUpdateTimer = Timer(interval, update);
		}
		updatingNow = false;
		if (disposed) {
			nextUpdateTimer?.cancel();
		}
		else {
			notifyListeners();
		}
	}

	void cancel() {
		nextUpdateTimer?.cancel();
		nextUpdate = null;
		notifyListeners();
	}

	@override
	void dispose() {
		disposed = true;
		nextUpdateTimer?.cancel();
		nextUpdateTimer = null;
		super.dispose();
	}
}
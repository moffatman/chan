import 'dart:async';

import 'package:chan/models/thread.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/notifications.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:mutex/mutex.dart';

part 'thread_watcher.g.dart';

enum WatchAction {
	notify,
	save
}

abstract class Watch {
	int get lastSeenId;
	set lastSeenId(int id);
	String get _type;
	Map<String, dynamic> toMap() {
		return {
			'type': _type,
			'lastSeenId': lastSeenId,
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
	@override
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
	static const type = 'thread';
	@override
	String get _type => type;
	@override
	Map<String, dynamic> _toMap() => {
		'board': board,
		'threadId': threadId.toString(),
		'yousOnly': pushYousOnly,
		'youIds': youIds
	};
	ThreadIdentifier get threadIdentifier => ThreadIdentifier(board, threadId);
}

@HiveType(typeId: 29)
class NewThreadWatch extends Watch {
	@HiveField(0)
	String board;
	@HiveField(1)
	String filter;
	@HiveField(2)
	@override
	int lastSeenId;
	@HiveField(3)
	bool allStickies;
	@HiveField(4)
	String uniqueId;
	NewThreadWatch({
		required this.board,
		required this.filter,
		required this.lastSeenId,
		required this.allStickies,
		required this.uniqueId
	});
	static const type = 'newThread';
	@override
	String get _type => type;
	@override
	Map<String, dynamic> _toMap() => {
		'board': board,
		'filter': filter,
		'allStickies': allStickies,
		'uniqueId': uniqueId
	};
}

const _briefInterval = Duration(seconds: 1);

class ThreadWatcher extends ChangeNotifier {
	final String imageboardKey;
	final ImageboardSite site;
	final Persistence persistence;
	final EffectiveSettings settings;
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

	Filter get __filter => FilterGroup([settings.filter, persistence.browserState.imageMD5Filter]);
	late final FilterCache _filter = FilterCache(__filter);
	final _initialCountsDone = Completer<void>();
	
	ThreadWatcher({
		required this.imageboardKey,
		required this.site,
		required this.persistence,
		required this.settings,
		required this.notifications,
		required this.controller,
		this.watchForStickyOnBoards = const []
	}) {
		controller.registerWatcher(this);
		_boxSubscription = persistence.threadStateBox.watch().listen(_threadUpdated);
		_setInitialCounts();
	}

	Future<void> _setInitialCounts() async {
		for (final watch in persistence.browserState.threadWatches) {
			cachedUnseenYous[watch.threadIdentifier] = persistence.getThreadStateIfExists(watch.threadIdentifier)?.unseenReplyIdsToYouCount(_filter) ?? 0;
			if (!watch.localYousOnly) {
				cachedUnseen[watch.threadIdentifier] = persistence.getThreadStateIfExists(watch.threadIdentifier)?.unseenReplyCount(_filter) ?? 0;
			}
			await Future.microtask(() => {});
		}
		_updateCounts();
		_initialCountsDone.complete();
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
			cachedUnseenYous[watch.threadIdentifier] = persistence.getThreadStateIfExists(watch.threadIdentifier)?.unseenReplyIdsToYouCount(_filter) ?? 0;
			if (watch.localYousOnly) {
				cachedUnseen.remove(watch.threadIdentifier);
			}
			else {
				cachedUnseen[watch.threadIdentifier] = persistence.getThreadStateIfExists(watch.threadIdentifier)?.unseenReplyCount(_filter) ?? 0;
			}
			_updateCounts();
		}
		else if (watch is NewThreadWatch) {

		}
	}

	void onWatchRemoved(Watch watch) {
		if (watch is ThreadWatch) {
			cachedUnseenYous.remove(watch.threadIdentifier);
			cachedUnseen.remove(watch.threadIdentifier);
			_updateCounts();
		}
		else if (watch is NewThreadWatch) {

		}
	}

	void _threadUpdated(BoxEvent event) async {
		await _initialCountsDone.future;
		// Update notification counters when last-seen-id is saved to disk
		if (event.value is PersistentThreadState) {
			final newThreadState = event.value as PersistentThreadState;
			if (newThreadState.thread != null) {
				if (_unseenStickyThreads.contains(newThreadState.identifier)) {
					_unseenStickyThreads.remove(newThreadState.identifier);
					_updateCounts();
				}
				final watch = persistence.browserState.threadWatches.tryFirstWhere((w) => w.threadIdentifier == newThreadState.identifier);
				if (watch != null) {
					cachedUnseenYous[watch.threadIdentifier] = persistence.getThreadStateIfExists(watch.threadIdentifier)?.unseenReplyIdsToYouCount(_filter) ?? 0;
					if (!watch.localYousOnly) {
						cachedUnseen[watch.threadIdentifier] = persistence.getThreadStateIfExists(watch.threadIdentifier)?.unseenReplyCount(_filter) ?? 0;
					}
					_updateCounts();
					if (newThreadState.thread!.isArchived) {
						notifications.zombifyThreadWatch(watch);
					}
					if (!listEquals(watch.youIds, newThreadState.youIds)) {
						watch.youIds = newThreadState.youIds;
						notifications.didUpdateThreadWatch(watch);
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
			newThread = await site.getThread(threadState.identifier);
		}
		on ThreadNotFoundException {
			final watch = persistence.browserState.threadWatches.tryFirstWhere((w) => w.threadIdentifier == threadState.identifier);
			// Ensure that the thread has been loaded at least once to avoid deleting upon creation due to a race condition
			if (watch != null && threadState.thread != null) {
				print('Zombifying watch for ${threadState.identifier} since it is in 404 state');
				notifications.zombifyThreadWatch(watch);
			}
			try {
				newThread = await site.getThreadFromArchive(threadState.identifier);
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
		final watches = persistence.browserState.threadWatches.toList();
		for (final watch in watches) {
			if (watch.zombie) {
				continue;
			}
			final threadState = persistence.getThreadState(watch.threadIdentifier);
			if (threadState.identifier == ThreadIdentifier('', 0)) {
				print('Cleaning up watch for deleted thread ${persistence.id}/${watch.board}/${watch.threadId}');
				await threadState.delete();
				notifications.removeThreadWatch(watch);
			}
			else {
				await _updateThread(threadState);
			}
		}
		for (final tab in Persistence.tabs) {
			if (tab.imageboardKey == imageboardKey && tab.threadController == null && tab.thread != null) {
				// Thread page widget hasn't yet been instantiated
				final threadState = persistence.getThreadStateIfExists(tab.thread!);
				if (threadState != null && threadState.thread?.isArchived != true) {
					await _updateThread(threadState);
				}
			}
		}
		_lastCatalogs.clear();
		_unseenStickyThreads.clear();
		for (final board in watchForStickyOnBoards) {
			_lastCatalogs[board] ??= await site.getCatalog(board);
			_unseenStickyThreads.addAll(_lastCatalogs[board]!.where((t) => t.isSticky).where((t) => persistence.getThreadStateIfExists(t.identifier) == null).map((t) => t.identifier).toList());
			// Update sticky threads for (you)s
			final stickyThreadStates = persistence.threadStateBox.values.where((s) => s.board == board && s.thread != null && s.thread!.isSticky);
			for (final threadState in stickyThreadStates) {
				if (threadState.youIds.isNotEmpty) {
					try {
						final newThread = await site.getThread(threadState.thread!.identifier);
						if (newThread != threadState.thread) {
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
		_updateCounts();
	}

	void fixBrokenThread(ThreadIdentifier thread) {
		fixBrokenLock.protect(() async {
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
		updatingNow = true;
		notifyListeners();
		if (!ImageboardRegistry.instance.initialized) {
			lastUpdate = DateTime.now();
			nextUpdate = lastUpdate!.add(_briefInterval);
			nextUpdateTimer?.cancel();
			nextUpdateTimer = Timer(_briefInterval, update);
		}
		else {
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
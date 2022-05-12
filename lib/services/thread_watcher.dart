import 'dart:async';

import 'package:chan/models/thread.dart';
import 'package:chan/services/filtering.dart';
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
	bool yousOnly;
	@HiveField(4, defaultValue: [])
	List<int> youIds;
	@HiveField(5, defaultValue: false)
	bool zombie;
	ThreadWatch({
		required this.board,
		required this.threadId,
		required this.lastSeenId,
		required this.yousOnly,
		required this.youIds,
		this.zombie = false
	});
	static const type = 'thread';
	@override
	String get _type => type;
	@override
	Map<String, dynamic> _toMap() => {
		'board': board,
		'threadId': threadId.toString(),
		'yousOnly': yousOnly,
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

class ThreadWatcher extends ChangeNotifier {
	final ImageboardSite site;
	final Persistence persistence;
	final EffectiveSettings settings;
	final Notifications notifications;
	final Map<ThreadIdentifier, int> cachedUnseen = {};
	final Map<ThreadIdentifier, int> cachedUnseenYous = {};
	StreamSubscription<BoxEvent>? _boxSubscription;
	DateTime? lastUpdate;
	Timer? nextUpdateTimer;
	DateTime? nextUpdate;
	String? updateErrorMessage;
	bool get active => nextUpdateTimer?.isActive ?? false;
	final fixBrokenLock = Mutex();
	final Set<ThreadIdentifier> fixedThreads = {};
	bool disposed = false;
	final Duration interval;
	final Duration errorInterval;
	final List<String> watchForStickyOnBoards;
	final Map<String, List<Thread>> _lastCatalogs = {};
	final List<ThreadIdentifier> _unseenStickyThreads = [];

	final unseenCount = ValueNotifier<int>(0);
	final unseenYouCount = ValueNotifier<int>(0);

	Filter get __filter => FilterGroup([settings.filter, persistence.browserState.imageMD5Filter]);
	late final FilterCache _filter = FilterCache(__filter);
	
	ThreadWatcher({
		required this.site,
		required this.persistence,
		required this.settings,
		required this.notifications,
		this.interval = const Duration(seconds: 90),
		this.watchForStickyOnBoards = const []
	}) : errorInterval = interval * 2 {
		_boxSubscription = persistence.threadStateBox.watch().listen(_threadUpdated);
		// Set initial counts
		for (final watch in persistence.browserState.threadWatches) {
			cachedUnseenYous[watch.threadIdentifier] = persistence.getThreadStateIfExists(watch.threadIdentifier)?.unseenReplyIdsToYou(_filter)?.length ?? 0;
			if (!watch.yousOnly) {
				cachedUnseen[watch.threadIdentifier] = persistence.getThreadStateIfExists(watch.threadIdentifier)?.unseenReplyCount(_filter) ?? 0;
			}
		}
		_updateCounts();
		update();
	}

	void _updateCounts() {
		if (cachedUnseen.isNotEmpty) {
			unseenCount.value = cachedUnseen.values.reduce((a, b) => a + b) + _unseenStickyThreads.length;
			unseenYouCount.value = cachedUnseenYous.values.reduce((a, b) => a + b);
		}
	}

	void onWatchUpdated(Watch watch) {
		if (watch is ThreadWatch) {
			cachedUnseenYous[watch.threadIdentifier] = persistence.getThreadStateIfExists(watch.threadIdentifier)?.unseenReplyIdsToYou(_filter)?.length ?? 0;
			if (!watch.yousOnly) {
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

	void _threadUpdated(BoxEvent event) {
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
					cachedUnseenYous[watch.threadIdentifier] = persistence.getThreadStateIfExists(watch.threadIdentifier)?.unseenReplyIdsToYou(_filter)?.length ?? 0;
					if (!watch.yousOnly) {
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

	Future<bool> _updateThread(PersistentThreadState threadState) async {
		Thread? newThread;
		try {
			newThread = await site.getThread(threadState.identifier);
		}
		on ThreadNotFoundException {
			final watch = persistence.browserState.threadWatches.tryFirstWhere((w) => w.threadIdentifier == threadState.identifier);
			if (watch != null) {
				print('Removing watch for ${threadState.identifier} since it is in 404 state');
				notifications.removeThreadWatch(watch);
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
		}
		if (newThread != threadState.thread) {
			threadState.thread = newThread;
			threadState.save();
			return true;
		}
		return false;
	}

	Future<void> update() async {
		try {
			// Could be concurrently-modified
			final watches = persistence.browserState.threadWatches.toList();
			for (final watch in watches) {
				if (watch.zombie) {
					continue;
				}
				await _updateThread(persistence.getThreadState(watch.threadIdentifier));
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
			lastUpdate = DateTime.now();
			nextUpdate = lastUpdate!.add(interval);
			nextUpdateTimer = Timer(interval, update);
		}
		catch (e, st) {
			print(e);
			print(st);
			updateErrorMessage = e.toStringDio();
			lastUpdate = DateTime.now();
			nextUpdate = lastUpdate!.add(errorInterval);
			nextUpdateTimer = Timer(errorInterval, update);
		}
		if (disposed) {
			nextUpdateTimer?.cancel();
			_boxSubscription?.cancel();
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
		disposed = true;
		nextUpdateTimer?.cancel();
		nextUpdateTimer = null;
		_boxSubscription?.cancel();
		_boxSubscription = null;
		super.dispose();
	}
}
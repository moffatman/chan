import 'dart:async';

import 'package:chan/models/thread.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:mutex/mutex.dart';

const _normalInterval = Duration(seconds: 90);
const _errorInterval = Duration(seconds: 180);

class StickyThreadWatcher extends ChangeNotifier {
	final ImageboardSite site;
	final Persistence persistence;
	final String board;
	final Duration interval;
	final EffectiveSettings settings;
	StreamSubscription<BoxEvent>? _boxSubscription;
	final Map<ThreadIdentifier, int> cachedUnseenYous = {};
	Timer? nextUpdateTimer;
	List<Thread> unseenStickyThreads = [];
	bool disposed = false;

	final unseenStickyThreadCount = ValueNotifier<int>(0);
	final unseenYouCount = ValueNotifier<int>(0);
	List<Thread>? lastCatalog;

	StickyThreadWatcher({
		required this.site,
		required this.persistence,
		required this.board,
		required this.settings,
		this.interval = const Duration(minutes: 10)
	}) {
		_boxSubscription = persistence.threadStateBox.watch().listen(_threadUpdated);
		update();
	}

	Filter get __filter => FilterGroup([settings.filter, persistence.browserState.imageMD5Filter]);
	late final FilterCache _filter = FilterCache(__filter);

	void _threadUpdated(BoxEvent event) {
		if (event.value is PersistentThreadState) {
			final newThreadState = event.value as PersistentThreadState;
			unseenStickyThreads.removeWhere((t) => t.identifier == newThreadState.thread?.identifier);
			unseenStickyThreadCount.value = unseenStickyThreads.length;
			_filter.setFilter(__filter);
			cachedUnseenYous[newThreadState.thread!.identifier] = newThreadState.unseenReplyIdsToYou(_filter)?.length ?? 0;
			if (!disposed) {
				unseenYouCount.value = cachedUnseenYous.values.reduce((a, b) => a + b);
				notifyListeners();
			}
		}
	}

	Future<void> update() async {
		try {
			lastCatalog = await site.getCatalog(board);
			unseenStickyThreads = lastCatalog!.where((t) => t.isSticky).where((t) => persistence.getThreadStateIfExists(t.identifier) == null).toList();
			unseenStickyThreadCount.value = unseenStickyThreads.length;
			// Update sticky threads for (you)s
			final stickyThreadStates = persistence.threadStateBox.values.where((s) => s.thread != null && s.thread!.isSticky);
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
		catch (e, st) {
			print(e);
			print(st);
		}
		nextUpdateTimer = Timer(interval, update);
		if (disposed) {
			nextUpdateTimer?.cancel();
			_boxSubscription?.cancel();
		}
		else {
			notifyListeners();
		}
	}

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

class SavedThreadWatcher extends ChangeNotifier {
	final ImageboardSite site;
	final Persistence persistence;
	final EffectiveSettings settings;
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

	final unseenCount = ValueNotifier<int>(0);
	final unseenYouCount = ValueNotifier<int>(0);

	Filter get __filter => FilterGroup([settings.filter, persistence.browserState.imageMD5Filter]);
	late final FilterCache _filter = FilterCache(__filter);
	
	SavedThreadWatcher({
		required this.site,
		required this.persistence,
		required this.settings
	}) {
		_boxSubscription = persistence.threadStateBox.watch().listen(_threadUpdated);
		final liveSavedThreads = persistence.threadStateBox.values.where((s) => s.thread != null && s.savedTime != null);
		for (final liveSavedThread in liveSavedThreads) {
			cachedUnseen[liveSavedThread.thread!.identifier] = liveSavedThread.unseenReplyCount(_filter) ?? 0;
			cachedUnseenYous[liveSavedThread.thread!.identifier] = (liveSavedThread.unseenReplyIdsToYou(_filter) ?? []).length;
		}
		if (liveSavedThreads.isNotEmpty) {
			_updateCounts();
		}
		update();
	}

	void _updateCounts() {
		if (cachedUnseen.isNotEmpty) {
			unseenCount.value = cachedUnseen.values.reduce((a, b) => a + b);
			unseenYouCount.value = cachedUnseenYous.values.reduce((a, b) => a + b);
		}
	}

	void _threadUpdated(BoxEvent event) {
		if (event.value is PersistentThreadState) {
			final newThreadState = event.value as PersistentThreadState;
			if (newThreadState.thread != null) {
				if (newThreadState.savedTime != null) {
					_filter.setFilter(__filter);
					final newUnseen = newThreadState.unseenReplyCount(_filter) ?? newThreadState.thread!.replyCount;
					final newUnseenYous = newThreadState.unseenReplyIdsToYou(_filter)!.length;
					if (cachedUnseen[newThreadState.thread!.identifier] != newUnseen || cachedUnseenYous[newThreadState.thread!.identifier] != newUnseenYous) {
						cachedUnseen[newThreadState.thread!.identifier] = newUnseen;
						cachedUnseenYous[newThreadState.thread!.identifier] = newUnseenYous;
						_updateCounts();
					}
				}
				else {
					cachedUnseen.remove(newThreadState.thread!.identifier);
					cachedUnseenYous.remove(newThreadState.thread!.identifier);
					_updateCounts();
				}
			}
		}
	}

	Future<bool> _updateThread(PersistentThreadState threadState) async {
		Thread? newThread;
		try {
			newThread = await site.getThread(threadState.thread!.identifier);
		}
		on ThreadNotFoundException {
			try {
				newThread = await site.getThreadFromArchive(threadState.thread!.identifier);
			}
			on ThreadNotFoundException {
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
			final liveThreadStates = persistence.threadStateBox.values.where((s) => s.thread != null && !s.thread!.isArchived && s.savedTime != null);
			for (final threadState in liveThreadStates) {
				await _updateThread(threadState);
			}
			_updateCounts();
			lastUpdate = DateTime.now();
			nextUpdate = lastUpdate!.add(_normalInterval);
			nextUpdateTimer = Timer(_normalInterval, update);
		}
		catch (e) {
			updateErrorMessage = e.toStringDio();
			lastUpdate = DateTime.now();
			nextUpdate = lastUpdate!.add(_errorInterval);
			nextUpdateTimer = Timer(_errorInterval, update);
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
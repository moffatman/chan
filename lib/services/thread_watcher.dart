import 'dart:async';

import 'package:chan/models/thread.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/sites/imageboard_site.dart';
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
	StreamSubscription<BoxEvent>? _boxSubscription;
	Timer? nextUpdateTimer;
	List<Thread> unseenStickyThreads = [];

	final unseenCount = ValueNotifier<int>(0);

	StickyThreadWatcher({
		required this.site,
		required this.persistence,
		required this.board,
		this.interval = const Duration(minutes: 10)
	}) {
		_boxSubscription = persistence.threadStateBox.watch().listen(_threadUpdated);
		update();
	}

	void _threadUpdated(BoxEvent event) {
		if (event.value is PersistentThreadState) {
			final newThreadState = event.value as PersistentThreadState;
			unseenStickyThreads.removeWhere((t) => t.identifier == newThreadState.thread?.identifier);
			unseenCount.value = unseenStickyThreads.length;
		}
	}

	Future<void> update() async {
		try {
			final catalog = await site.getCatalog(board);
			unseenStickyThreads = catalog.where((t) => t.isSticky).where((t) => persistence.getThreadStateIfExists(t.identifier) == null).toList();
			unseenCount.value = unseenStickyThreads.length;
		}
		catch (e) {
			print(e);
		}
		nextUpdateTimer = Timer(interval, update);
		notifyListeners();
	}

	@override
	void dispose() {
		nextUpdateTimer?.cancel();
		_boxSubscription?.cancel();
		super.dispose();
	}
}

class SavedThreadWatcher extends ChangeNotifier {
	final ImageboardSite site;
	final Persistence persistence;
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

	final unseenCount = ValueNotifier<int>(0);
	final unseenYouCount = ValueNotifier<int>(0);
	
	SavedThreadWatcher({
		required this.site,
		required this.persistence
	}) {
		_boxSubscription = persistence.threadStateBox.watch().listen(_threadUpdated);
		final liveSavedThreads = persistence.threadStateBox.values.where((s) => s.thread != null && s.savedTime != null);
		for (final liveSavedThread in liveSavedThreads) {
			cachedUnseen[liveSavedThread.thread!.identifier] = liveSavedThread.unseenReplyCount ?? 0;
			cachedUnseenYous[liveSavedThread.thread!.identifier] = (liveSavedThread.unseenReplyIdsToYou ?? []).length;
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
					final newUnseen = newThreadState.unseenReplyCount!;
					final newUnseenYous = newThreadState.unseenReplyIdsToYou!.length;
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
			updateErrorMessage = e.toString();
			lastUpdate = DateTime.now();
			nextUpdate = lastUpdate!.add(_errorInterval);
			nextUpdateTimer = Timer(_errorInterval, update);
		}
		notifyListeners();
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
		nextUpdateTimer?.cancel();
		_boxSubscription?.cancel();
		super.dispose();
	}
}
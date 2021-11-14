import 'dart:async';

import 'package:chan/models/thread.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

const _NORMAL_INTERVAL = const Duration(seconds: 90);
const _ERROR_INTERVAL = const Duration(seconds: 180);

class ThreadWatcher extends ChangeNotifier {
	final ImageboardSite site;
	final Persistence persistence;
	final cachedUnseen = Map<ThreadIdentifier, int>();
	final cachedUnseenYous = Map<ThreadIdentifier, int>();
	StreamSubscription<BoxEvent>? _boxSubscription;
	DateTime? lastUpdate;
	Timer? nextUpdateTimer;
	DateTime? nextUpdate;
	String? updateErrorMessage;
	bool get active => nextUpdateTimer?.isActive ?? false;

	final unseenCount = ValueNotifier<int>(0);
	final unseenYouCount = ValueNotifier<int>(0);
	
	ThreadWatcher({
		required this.site,
		required this.persistence
	}) {
		_boxSubscription = persistence.threadStateBox.watch().listen(_threadUpdated);
		final liveSavedThreads = persistence.threadStateBox.values.where((s) => s.thread != null && s.savedTime != null);
		for (final liveSavedThread in liveSavedThreads) {
			cachedUnseen[liveSavedThread.thread!.identifier] = liveSavedThread.unseenReplyCount ?? 0;
			cachedUnseenYous[liveSavedThread.thread!.identifier] = (liveSavedThread.unseenRepliesToYou ?? []).length;
		}
		if (liveSavedThreads.length > 0) {
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
					final newUnseenYous = newThreadState.unseenRepliesToYou!.length;
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

	Future<void> _updateThread(PersistentThreadState threadState) async {
		Thread? newThread;
		try {
			newThread = await site.getThread(threadState.thread!.identifier);
		}
		on ThreadNotFoundException {
			try {
				newThread = await site.getThreadFromArchive(threadState.thread!.identifier);
			}
			on ThreadNotFoundException {
				return;
			}
		}
		if (newThread != threadState.thread) {
			threadState.thread = newThread;
			threadState.save();
		}
	}

	Future<void> update() async {
		try {
			final liveThreadStates = persistence.threadStateBox.values.where((s) => s.thread != null && !s.thread!.isArchived && s.savedTime != null);
			for (final threadState in liveThreadStates) {
				await _updateThread(threadState);
			}
			_updateCounts();
			lastUpdate = DateTime.now();
			nextUpdate = lastUpdate!.add(_NORMAL_INTERVAL);
			nextUpdateTimer = Timer(_NORMAL_INTERVAL, update);
		}
		catch (e) {
			updateErrorMessage = e.toString();
			lastUpdate = DateTime.now();
			nextUpdate = lastUpdate!.add(_ERROR_INTERVAL);
			nextUpdateTimer = Timer(_ERROR_INTERVAL, update);
		}
		notifyListeners();
	}

	void cancel() {
		nextUpdateTimer?.cancel();
		notifyListeners();
	}

	void fixBrokenThread(ThreadIdentifier thread) {
		final state = persistence.getThreadStateIfExists(thread);
		if (state != null) {
			_updateThread(state);
		}
	}

	@override
	void dispose() {
		nextUpdateTimer?.cancel();
		_boxSubscription?.cancel();
		super.dispose();
	}
}
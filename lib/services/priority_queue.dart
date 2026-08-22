import 'dart:async';

import 'package:chan/services/imageboard.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/foundation.dart' show mergeSort;
import 'package:mutex/mutex.dart';

class _PriorityQueueEntry<Key> {
	final Key key;
	int priority;
	Completer<void> completer = Completer();
	_PriorityQueueEntry(this.key, this.priority);

	@override
	String toString() => '_PriorityQueueEntry<$Key>($key, priority: $priority)';
}

class _PriorityQueueGroup<Key, GroupKey> {
	final GroupKey groupKey;
	final PriorityQueue<Key, GroupKey> parent;
	final _stack = <_PriorityQueueEntry<Key>>[];
	final _lock = Mutex();
	Timer? _timer;
	DateTime? delayUntil;
	_PriorityQueueGroup(this.groupKey, this.parent);

	Future<void> start(Key key, {int priority = 0}) async {
		final completer = await _lock.protect(() async {
			if (delayUntil != null) {
				print('[$groupKey] Add $key');
			}
			final entry = _PriorityQueueEntry(key, priority);
			_stack.add(entry);
			Future.microtask(_process);
			return entry.completer;
		});
		return completer.future;
	}

	Future<void> delay(Key key, Duration delay) async {
		if (delay > const Duration(minutes: 1)) {
			alert(
				ImageboardRegistry.instance.context!,
				'Rate-Limited!',
				'Received an extremely long delay request (${formatTimeDiff(delay)}) trying to access:\n$key\n\n$groupKey has probably added new restrictions.',
				actions: {
					'Try clearing': () {
						delayUntil = DateTime.now();
						Future.microtask(_process);
					}
				}
			);
		}
		final completer = await _lock.protect(() async {
			delayUntil = DateTime.now().add(delay);
			final entry = _stack.tryFirstWhere((e) => e.key == key);
			if (entry == null) {
				throw ArgumentError.value(key, 'key', 'Queue entry to delay not found');
			}
			if (!entry.completer.isCompleted) {
				throw StateError('Tried to delay while already waiting on a completer');
			}
			entry.completer = Completer();
			print('[$groupKey] Delay $key by $delay');
			Future.microtask(_process);
			return entry.completer;
		});
		return completer.future;
	}

	Future<void> end(Key key) => _lock.protect(() async {
		if (delayUntil != null) {
			print('[$groupKey] End $key');
		}
		final index = _stack.indexWhere((e) => e.key == key);
		if (index == -1) {
			throw ArgumentError.value(key, 'key', 'Queue entry to end not found');
		}
		final removed = _stack.removeAt(index);
		if (!removed.completer.isCompleted) {
			removed.completer.completeError(Exception('Queue entry interrupted'), StackTrace.current);
		}
		Future.microtask(_process);
	});

	Future<bool> prioritize(Key key) => _lock.protect(() async {
		if (delayUntil != null) {
			print('[$groupKey] Prioritizing $key');
		}
		final index = _stack.indexWhere((e) => e.key == key);
		if (index == -1) {
			return false;
		}
		final removed = _stack.removeAt(index);
		_stack.insert(0, removed);
		Future.microtask(_process);
		return true;
	});

	Future<void> reset() => _lock.protect(() async {
		print('[$groupKey] Resetting');
		// Stay in series mode but allow it to continue
		delayUntil = DateTime.now();
		// Give a chance for highest priority url request to establish itself at top of queue
		Future.delayed(const Duration(milliseconds: 50), _process);
	});

	Future<void> _process() => _lock.protect(() async {
		if (delayUntil?.isAfter(DateTime.now()) ?? false) {
			// Kick it
			final delay = delayUntil?.difference(DateTime.now());
			print('[$groupKey] Kicking it $delay');
			_timer?.cancel();
			_timer = Timer(delay ?? Duration.zero, _process);
			return;
		}
		if (delayUntil == null) {
			//print('[$groupKey] Parallel mode');
			for (final entry in _stack) {
				if (!entry.completer.isCompleted) {
					//print('[$groupKey] Allowing ${_stack.first.key} to continue');
					entry.completer.complete();
				}
			}
			return;
		}
		print('[$groupKey] Series mode');
		if (_stack.isEmpty) {
			print('[$groupKey] Nothing to do');
			delayUntil = null;
			return;
		}
		// Merge sort to keep stuff as most recent first
		mergeSort(_stack, compare: (a, b) {
			// First put wait "completed" (request in progress) task(s)
			if (a.completer.isCompleted && !b.completer.isCompleted) {
				return -1;
			}
			if (b.completer.isCompleted && !a.completer.isCompleted) {
				return 1;
			}
			// Then sort based on priority (higher first)
			return b.priority - a.priority;
		});
		if (!_stack.first.completer.isCompleted) {
			print('[$groupKey] Allowing ${_stack.first.key} to continue');
			_stack.first.completer.complete();
		}
		else {
			print('[$groupKey] Still waiting for ${_stack.first.key}');
		}
	});

	@override
	String toString() => '_PriorityQueueGroup<$Key, $GroupKey>(groupKey: $groupKey, _stack: $_stack, delayUntil: $delayUntil)';
}

class PriorityQueue<Key, GroupKey> {
	final GroupKey Function(Key) groupKeyer;
	final Map<GroupKey, _PriorityQueueGroup<Key, GroupKey>> _groups = {};
	late final Timer _reapTimer;

	PriorityQueue({
		required this.groupKeyer
	}) {
		_reapTimer = Timer.periodic(const Duration(minutes: 3), _reap);
	}

	void dispose() {
		_reapTimer.cancel();
		// One final reap
		_reap(_reapTimer);
	}

	void _reap(Timer _) {
		// Use .toList() to avoid ConcurrentModificationException
		for (final group in _groups.values.toList()) {
			// Check if group is not busy and nothing is outstanding
			if (!group._lock.isLocked && group._stack.isEmpty) {
				group._timer?.cancel();
				_groups.remove(group.groupKey);
			}
		}
	}

	_PriorityQueueGroup<Key, GroupKey> _getGroup(Key key) {
		final groupKey = groupKeyer(key);
		return _groups[groupKey] ??= _PriorityQueueGroup(groupKey, this);
	}

	Future<void> start(Key key, {int priority = 0}) => _getGroup(key).start(key, priority: priority);

	Future<void> delay(Key key, Duration delay) => _getGroup(key).delay(key, delay);

	Future<void> end(Key key) => _getGroup(key).end(key);

	Future<bool> prioritize(Key key) async => await _groups[groupKeyer(key)]?.prioritize(key) ?? false;

	Duration getCurrentDelay(Key key) {
		return _groups[groupKeyer(key)]?.delayUntil?.difference(DateTime.now()) ?? Duration.zero;
	}

	Future<void> reset(Key key) => _getGroup(key).reset();

	Future<T> task<T>(Key key, Future<T> Function() cb) async {
		try {
			await start(key);
			return await cb();
		}
		finally {
			await end(key);
		}
	}

	@override
	String toString() => 'PriorityQueue<$Key, $GroupKey>(_groups: $_groups)';
}

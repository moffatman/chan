import 'dart:async';

import 'package:chan/util.dart';
import 'package:mutex/mutex.dart';

class _PriorityQueueEntry<Key> {
	final Key key;
	Completer<void> completer = Completer();
	_PriorityQueueEntry(this.key);
}

class _PriorityQueueGroup<Key, GroupKey> {
	final GroupKey groupKey;
	final PriorityQueue<Key, GroupKey> parent;
	final _stack = <_PriorityQueueEntry<Key>>[];
	final _lock = Mutex();
	Timer? _timer;
	DateTime? delayUntil;
	_PriorityQueueGroup(this.groupKey, this.parent);

	Future<void> start(Key key) async {
		final completer = await _lock.protect(() async {
			if (delayUntil != null) {
				print('[$groupKey] Add $key');
			}
			final entry = _PriorityQueueEntry(key);
			_stack.add(entry);
			Future.microtask(_process);
			return entry.completer;
		});
		return completer.future;
	}

	Future<void> delay(Key key, Duration delay) async {
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
			if (_stack.isEmpty) {
				parent._reap(this);
			}
			return;
		}
		print('[$groupKey] Series mode');
		if (_stack.isEmpty) {
			print('[$groupKey] Nothing to do');
			delayUntil = null;
			if (_stack.isEmpty) {
				parent._reap(this);
			}
			return;
		}
		if (!_stack.first.completer.isCompleted) {
			print('[$groupKey] Allowing ${_stack.first.key} to continue');
			_stack.first.completer.complete();
		}
		else {
			print('[$groupKey] Still waiting for ${_stack.first.key}');
		}
	});
}

class PriorityQueue<Key, GroupKey> {
	final GroupKey Function(Key) groupKeyer;
	final Map<GroupKey, _PriorityQueueGroup<Key, GroupKey>> _groups = {};

	PriorityQueue({
		required this.groupKeyer
	});

	void _reap(_PriorityQueueGroup<Key, GroupKey> group) {
		group._timer?.cancel();
		_groups.remove(group.groupKey);
	}

	_PriorityQueueGroup<Key, GroupKey> _getGroup(Key key) {
		final groupKey = groupKeyer(key);
		return _groups[groupKey] ??= _PriorityQueueGroup(groupKey, this);
	}

	Future<void> start(Key key) => _getGroup(key).start(key);

	Future<void> delay(Key key, Duration delay) => _getGroup(key).delay(key, delay);

	Future<void> end(Key key) => _getGroup(key).end(key);

	Future<bool> prioritize(Key key) async => await _groups[groupKeyer(key)]?.prioritize(key) ?? false;

	Future<T> task<T>(Key key, Future<T> Function() cb) async {
		try {
			await start(key);
			return await cb();
		}
		finally {
			await end(key);
		}
	}
}

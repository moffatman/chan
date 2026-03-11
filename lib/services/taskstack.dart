import 'dart:async';

extension _Safe<T> on Future<T> {
	Future<void> get safe => onError(Future.error);
}

/// Sloppy code for initialization waiting
class TaskStack {
	int _index = 0;
	Future _lastFuture = Future.value();
	final _completer = Completer<void>();
	Future<void> get future => _completer.future;
	bool get isCompleted => _completer.isCompleted;
	TaskStack();

	Future<T> holdFor<T>(Future<T>? future) {
		if (future == null) {
			return Future.value();
		}
		final index = ++_index;
		_lastFuture = _lastFuture.then((_) => future.safe).then((_) {
			// Give some time for another hold to start
			Future.microtask(() {
				if (index == _index) {
					_completer.complete();
				}
			});
		});
		return future;
	}

	Future<T> holdForFunction<T>(Future<T> Function() func) {
		return holdFor(func());
	}
}

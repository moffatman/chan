import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:mutex/mutex.dart';

extension SafeWhere<T> on Iterable<T> {
	T? tryFirstWhere(bool Function(T v) f) => cast<T?>().firstWhere((v) => f(v as T), orElse: () => null);
	T? tryLastWhere(bool Function(T v) f) => cast<T?>().lastWhere((v) => f(v as T), orElse: () => null);
	T? get tryFirst => isNotEmpty ? first : null;
	T? get tryLast => isNotEmpty ? last : null;
	T? get trySingle => length == 1 ? single : null;
}

extension MapOnce<T> on Iterable<T> {
	U? tryMapOnce<U extends Object>(U? Function(T v) f) {
		for (final item in this) {
			final mapped = f(item);
			if (mapped != null) {
				return mapped;
			}
		}
		return null;
	}
}

extension BinarySafeWhere<T> on List<T> {
	int binarySearchFirstIndexWhere(bool Function(T v) f) {
		if (isEmpty) {
			return -1;
		}
		int min = 0;
		int max = length - 1;
		while (min < max) {
			final int mid = min + ((max - min) >> 1);
			final T element = this[mid];
			final T next = this[mid + 1];
			final bool elementPasses = f(element);
			final bool nextElementPasses = f(next);
			if (!elementPasses && nextElementPasses) {
				return mid + 1;
			}
			else if (elementPasses) {
				max = mid;
			}
			else {
				min = mid + 1;
			}
		}
		if (f(first)) {
			return 0;
		}
		else if (f(last)) {
			return length - 1;
		}
		return -1;
	}
	T? binarySearchTryFirstWhere(bool Function(T v) f) {
		final index = binarySearchFirstIndexWhere(f);
		if (index == -1) {
			return null;
		}
		return this[index];
	}
	int binarySearchLastIndexWhere(bool Function(T v) f) {
		if (isEmpty) {
			return -1;
		}
		int min = 0;
		int max = length - 1;
		while (min < max) {
			final int mid = min + ((max - min) >> 1);
			final T element = this[mid];
			final T next = this[mid + 1];
			final bool elementPasses = f(element);
			final bool nextElementPasses = f(next);
			if (elementPasses && !nextElementPasses) {
				return mid;
			}
			else if (elementPasses) {
				min = mid + 1;
			}
			else {
				max = mid;
			}
		}
		if (f(last)) {
			return length - 1;
		}
		else if (f(first)) {
			return 0;
		}
		return -1;
	}
	T? binarySearchTryLastWhere(bool Function(T v) f) {
		final index = binarySearchLastIndexWhere(f);
		if (index == -1) {
			return null;
		}
		return this[index];
	}
	int binarySearchCountBefore(bool Function(T v) f) {
		final index = binarySearchFirstIndexWhere(f);
		if (index == -1) {
			return length;
		}
		else {
			return length - index;
		}
	}
	int binarySearchCountAfter(bool Function(T v) f) {
		final index = binarySearchFirstIndexWhere(f);
		if (index == -1) {
			return 0;
		}
		else {
			return length - index;
		}
	}
}

class ExpiringMutexResource<T> {
	final Future<T> Function() _initializer;
	final Future Function(T resource) _deinitializer;
	final Duration _interval;
	ExpiringMutexResource(this._initializer, this._deinitializer, {
		Duration? interval
	}) : _interval = interval ?? const Duration(minutes: 1);
	final _mutex = Mutex();
	T? _resource;
	Timer? _timer;
	Future<T> _getInitialized() async {
		_resource ??= await _initializer();
		return _resource!;
	}
	void _deinitialize() {
		_mutex.protect(() async {
			if (_timer == null) {
				return;
			}
			if (_resource != null) {
				_deinitializer(_resource as T);
				_resource = null;
			}
		});
	}
	Future<void> runWithResource(Future Function(T resource) work) {
		return _mutex.protect(() async {
			_timer?.cancel();
			_timer = null;
			await work(await _getInitialized());
			_timer = Timer(_interval, _deinitialize);
		});
	}
}

extension ToStringDio on Object {
	String toStringDio() {
		if (this is DioError) {
			return '${(this as DioError).message}\nURL: ${(this as DioError).requestOptions.uri}';
		}
		else {
			return toString();
		}
	}
}

extension Filtering on Listenable {
	Listenable filter(bool Function() filter) {
		return FilteringListenable(this, filter);
	}
}

class FilteringListenable extends ChangeNotifier {
  FilteringListenable(this._child, this._filter) {
		_child.addListener(_listen);
	}

  final Listenable _child;
	final bool Function() _filter;

	void _listen() {
		if (_filter()) {
			notifyListeners();
		}
	}

	@override
	void dispose() {
		super.dispose();
		_child.removeListener(_listen);
	}

  @override
  String toString() {
    return 'FilteringListenable(child: $_child, filter: $_filter)';
  }
}

class CombiningValueListenable<T> extends ChangeNotifier implements ValueListenable<T> {
	final List<ValueListenable<T>> children;
	final T Function(T, T) combine;
	final T noChildrenValue;
	CombiningValueListenable({
		required this.children,
		required this.combine,
		required this.noChildrenValue
	}) {
		for (final child in children) {
			child.addListener(_listen);
		}
	}

	void _listen() {
		notifyListeners();
	}

	@override
	void dispose() {
		super.dispose();
		for (final child in children) {
			child.removeListener(_listen);
		}
	}

	@override
	T get value => children.isEmpty ? noChildrenValue : children.map((c) => c.value).reduce(combine);
}

final Map<Function, ({Timer timer, Completer<void> completer})> _functionIdleTimers = {};
Future<void> runWhenIdle(Duration duration, FutureOr Function() function) {
	final completer = _functionIdleTimers[function]?.completer ?? Completer();
	_functionIdleTimers[function]?.timer.cancel();
	_functionIdleTimers[function] = (timer: Timer(duration, () async {
		_functionIdleTimers.remove(function);
		await function();
		completer.complete();
	}), completer: completer);
	return completer.future;
}

enum NullSafeOptional {
	null_,
	false_,
	true_
}

extension ToBool on NullSafeOptional {
	bool? get value {
		switch (this) {
			case NullSafeOptional.null_: return null;
			case NullSafeOptional.false_: return false;
			case NullSafeOptional.true_: return true;
		}
	}
}

extension ToNullSafeOptional on bool? {
	NullSafeOptional get value {
		switch (this) {
			case true: return NullSafeOptional.true_;
			case false: return NullSafeOptional.false_;
			default: return NullSafeOptional.null_;
		}
	}
}

class EasyListenable extends ChangeNotifier {
	void didUpdate() {
		notifyListeners();
	}
}

extension LazyCeil on double {
	int lazyCeil() {
		if (isFinite) {
			return ceil();
		}
		return 99999999;
	}
}

void insertIntoSortedList<T>({
	required List<T> list,
	required List<Comparator<T>> sortMethods,
	required bool reverseSort,
	required T item
}) {
	if (list.isEmpty) {
		list.add(item);
		return;
	}
	try {
		int i = 0;
		for (final originalMethod in sortMethods) {
			method(a, b) => originalMethod(a, b) * (reverseSort ? -1 : 1);
			final comp = i == list.length ? -1 : method(item, list[i]);
			if (comp > 0) {
				// go forwards
				while (i < list.length && method(item, list[i]) > 0) {
					i++;
				}
			}
			else if (comp < 0) {
				// go backwards
				while (i > 0 && method(item, list[min(list.length - 1, i)]) < 0) {
					i--;
				}
				if (method(item, list[i]) >= 0) {
					i++;
				}
			}
		}
		list.insert(i, item);
	}
	catch (e) {
		list.add(item);
		// Let it be caught by crashlytics
		Future.error(e);
	}
}

extension WaitUntil<T> on ValueListenable<T> {
	Future<void> waitUntil(bool Function(T) predicate) {
		final completer = Completer<void>();
		void closure() {
			if (predicate(value)) {
				completer.complete();
				removeListener(closure);
			}
		}
		addListener(closure);
		return completer.future;
	}
}

extension Conversions on DateTime {
	DateTime get startOfDay => DateTime(year, month, day, 0, 0, 0);
	DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59);
	String get toISO8601Date => '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:mutex/mutex.dart';

final lineSeparatorPattern = RegExp(r'\r?\n');
final kInUnitTest = Platform.environment.containsKey('FLUTTER_TEST');

/// Syntactic sugar
T? tryIf<T>(T obj, bool Function(T v) f) {
	if (f(obj)) {
		return obj;
	}
	return null;
}

extension SafeWhere<T> on Iterable<T> {
	T? tryFirstWhere(bool Function(T v) f) {
		for (final v in this) {
			if (f(v)) {
				return v;
			}
		}
		return null;
	}
	T? tryLastWhere(bool Function(T v) f) {
		if (this is List<T>) {
			final list = this as List<T>;
			for (final v in list.reversed) {
				if (f(v)) {
					return v;
				}
			}
			return null;
		}
		else {
			T? result;
			for (final v in this) {
				if (f(v)) {
					result = v;
				}
			}
			return result;
		}
	}
	T? get tryFirst => isNotEmpty ? first : null;
	T? get tryLast => isNotEmpty ? last : null;
	T? get trySingle => length == 1 ? single : null;
	Iterable<U> tryMap<U>(U? Function(T v) f) sync* {
		for (final v in this) {
			final mapped = f(v);
			if (mapped != null) {
				yield mapped;
			}
		}
	}
}

extension SafeRemoveFirst<T> on List<T> {
	T? tryRemoveFirst() {
		if (isEmpty) {
			return null;
		}
		return removeAt(0);
	}
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

extension CountOf<T> on Iterable<T> {
	int countOf(T item) {
		int ret = 0;
		for (final i in this) {
			if (item == i) {
				ret++;
			}
		}
		return ret;
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
	Future<int> binarySearchFirstIndexWhereAsync(Future<bool> Function(T v) f) async {
		if (isEmpty) {
			return -1;
		}
		int min = 0;
		int max = length - 1;
		while (min < max) {
			final int mid = min + ((max - min) >> 1);
			final T element = this[mid];
			final T next = this[mid + 1];
			final bool elementPasses = await f(element);
			final bool nextElementPasses = await f(next);
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
		if (await f(first)) {
			return 0;
		}
		else if (await f(last)) {
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
	Future<int> binarySearchLastIndexWhereAsync(Future<bool> Function(T v) f) async {
		if (isEmpty) {
			return -1;
		}
		int min = 0;
		int max = length - 1;
		while (min < max) {
			final int mid = min + ((max - min) >> 1);
			final T element = this[mid];
			final T next = this[mid + 1];
			final bool elementPasses = await f(element);
			final bool nextElementPasses = await f(next);
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
		if (await f(last)) {
			return length - 1;
		}
		else if (await f(first)) {
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

extension MaybeAdd<T> on List<T> {
	void maybeAdd(T? value) {
		if (value != null) {
			add(value);
		}
	}
}

extension MaybeReversed<T> on List<T> {
	List<T> maybeReversed(bool shouldReverse) {
		if (shouldReverse) {
			return reversed.toList(growable: false);
		}
		return this;
	}
}

extension AsyncPutIfAbsent<K, V> on Map<K, V> {
	Future<V> putIfAbsentAsync(K key, Future<V> Function() ifAbsent) async {
		final currentValue = this[key];
		if (currentValue != null) {
			return currentValue;
		}
		final newValue = await ifAbsent();
		this[key] = newValue;
		return newValue;
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

class CombiningValueListenable<T> implements ValueListenable<T> {
	final List<ValueListenable<T>> children;
	final T Function(Iterable<T>) combine;
	CombiningValueListenable({
		required this.children,
		required this.combine
	});

	@override
	void addListener(VoidCallback listener) {
		for (final child in children) {
			child.addListener(listener);
		}
	}

	@override
	void removeListener(VoidCallback listener) {
		for (final child in children) {
			child.removeListener(listener);
		}
	}

	@override
	T get value => combine(children.map((c) => c.value));
}

class Combining2ValueListenable<X, Y, T> implements ValueListenable<T> {
	final ValueListenable<X> child1;
	final ValueListenable<Y> child2;
	final T Function(X, Y) combine;
	Combining2ValueListenable({
		required this.child1,
		required this.child2,
		required this.combine
	});

	@override
	void addListener(VoidCallback listener) {
		child1.addListener(listener);
		child2.addListener(listener);
	}

	@override
	void removeListener(VoidCallback listener) {
		child1.removeListener(listener);
		child2.removeListener(listener);
	}

	@override
	T get value => combine(child1.value, child2.value);
}

class MappingValueListenable<B extends Listenable, T> implements ValueListenable<T> {
	final B parent;
	final T Function(B) mapper;
	MappingValueListenable({
		required this.parent,
		required this.mapper
	});

	@override
	void addListener(VoidCallback listener) {
		parent.addListener(listener);
	}

	@override
	void removeListener(VoidCallback listener) {
		parent.removeListener(listener);
	}

	@override
	T get value => mapper(parent);
}

class StoppedValueListenable<T> implements ValueListenable<T> {
	@override
	final T value;

	const StoppedValueListenable(this.value);
	
	@override
	void addListener(VoidCallback listener) { }

	@override
	void removeListener(VoidCallback listener) { }	
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

class NullWrapper<T extends Object> {
	final T? value;
	const NullWrapper(this.value);

	@override
	String toString() => 'NullWrapper($value)';

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is NullWrapper &&
		other.value == value;
	@override
	int get hashCode => value.hashCode;
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

class BufferedListenable extends ChangeNotifier {
	final Duration bufferTime;
	BufferedListenable(this.bufferTime);
	Timer? _timer;

	void didUpdate({bool now = false}) {
		if (now) {
			_timer?.cancel();
			_timer = null;
			notifyListeners();
		}
		else {
			_timer ??= Timer(bufferTime, _onTimerFire);
		}
	}

	void _onTimerFire() {
		_timer = null;
		notifyListeners();
	}

	@override
	void dispose() {
		super.dispose();
		_timer?.cancel();
	}
}

class BufferedValueNotifier<T> extends BufferedListenable implements ValueNotifier<T> {
	T _value;
	BufferedValueNotifier(super.bufferTime, T value) : _value = value;

	@override
	T get value => _value;
	@override
	set value(T newValue) {
		if (newValue == _value) {
			return;
		}
		_value = newValue;
		didUpdate();
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
			method(T a, T b) => originalMethod(a, b) * (reverseSort ? -1 : 1);
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
		closure();
		return completer.future;
	}
}

extension WaitUntilValue<T> on ValueNotifier<T> {
	Future<void> waitUntilValue(T expectedValue) {
		final completer = Completer<void>();
		void closure() {
			if (value == expectedValue) {
				completer.complete();
				removeListener(closure);
			}
		}
		addListener(closure);
		closure();
		return completer.future;
	}
}

extension DateTimeConversion on DateTime {
	DateTime get startOfDay => DateTime(year, month, day, 0, 0, 0);
	DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59);
	static const kISO8601DateFormat = 'YYYY-MM-DD';
	String get toISO8601Date => formatDate(kISO8601DateFormat);
	String get weekdayShortName {
		const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
		return days[weekday];
	}
	static final _yearPattern = RegExp('Y+');
	String formatDate(String format) {
		return format
			.replaceAllMapped(_yearPattern, (m) => (year % pow(10, m.end - m.start)).toString())
			.replaceAll('MM', month.toString().padLeft(2, '0'))
			.replaceAll('M', month.toString())
			.replaceAll('DD', day.toString().padLeft(2, '0'))
			.replaceAll('D', day.toString());
	}
}

final Map<String, Mutex> _ephemeralLocks = {};
Future<T> runEphemerallyLocked<T>(String key, Future<T> Function() criticalSection) async {
	final lock = _ephemeralLocks.putIfAbsent(key, () {
		return Mutex();
	});
	try {
		return await lock.protect(criticalSection);
	}
	finally {
		if (!(_ephemeralLocks[key]?.isLocked ?? false)) {
			// No one else waiting
			_ephemeralLocks.remove(key);
		}
	}
}

extension FriendlyCompare on String {
	/// Compare case-insensitively, ignoring leading symbols
	int friendlyCompareTo(String other) {
		int thisStart;
		for (thisStart = 0; thisStart < length; thisStart++) {
			final c = codeUnitAt(thisStart);
			if ((c >= 65 && c <= 90) || (c >= 97 && c <= 122)) {
				break;
			}
		}
		int otherStart = 0;
		for (otherStart = 0; otherStart < other.length; otherStart++) {
			final c = other.codeUnitAt(otherStart);
			if ((c >= 65 && c <= 90) || (c >= 97 && c <= 122)) {
				break;
			}
		}
		final thisLen = length - thisStart;
		final otherLen = other.length - otherStart;
		final len = (thisLen < otherLen) ? thisLen : otherLen;
		for (int i = 0; i < len; i++) {
			int thisC = codeUnitAt(thisStart + i);
			int otherC = other.codeUnitAt(otherStart + i);
			// To upper case
			if ((thisC >= 97 && thisC <= 122)) {
				thisC -= 32;
			}
			if ((otherC >= 97 && otherC <= 122)) {
				otherC -= 32;
			}
			if (thisC < otherC) {
				return -1;
			}
			if (thisC > otherC) {
				return 1;
			}
		}
		if (thisLen < otherLen) {
			return -1;
		}
		if (thisLen > otherLen) {
			return 1;
		}
		return 0;
	}
}

extension NonEmptyOrNull on String {
	String? get nonEmptyOrNull {
		if (isEmpty) {
			return null;
		}
		return this;
	}
}

T dprint<T>(T obj, {String label = 'dprint'}) {
	print('$label: $obj');
	return obj;
}

VoidCallback? bind1<In, Out>(Out Function(In)? f, In v) => switch (f) {
	Out Function(In) func => () => func(v),
	null => null
};

extension LooksForeign on String {
	bool get looksForeign => codeUnits.any((i) => i >= 128);
}

T identity<T>(T x) => x;

class SelectListenable<T extends Listenable, X> extends ChangeNotifier {
  SelectListenable(this._child, this._map) {
		_child.addListener(_listen);
	}

  final T _child;
	final X Function(T) _map;
	X? _lastValue;

	void _listen() {
		final value = _map(_child);
		if (value != _lastValue) {
			_lastValue = value;
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
    return 'SelectListenable(child: $_child)';
  }
}

class OwnedChangeNotifierSubscription {
	final VoidCallback _callback;
	final ChangeNotifier _changeNotifier;
	OwnedChangeNotifierSubscription._(this._changeNotifier, this._callback) {
		_changeNotifier.addListener(_callback);
	}
	void dispose() {
		_changeNotifier.removeListener(_callback);
		_changeNotifier.dispose();
	}
}

extension SubscribeOwned on ChangeNotifier {
	OwnedChangeNotifierSubscription subscribeOwned(VoidCallback callback) {
		return OwnedChangeNotifierSubscription._(this, callback);
	}
}

extension ClampAboveZero on Duration {
	Duration get clampAboveZero {
		if (isNegative) {
			return Duration.zero;
		}
		return this;
	}
}

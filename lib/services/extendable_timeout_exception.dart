import 'dart:async';
import 'dart:math' as math;

import 'package:chan/services/util.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/widgets.dart' hide WeakMap;
import 'package:weak_map/weak_map.dart';

class ExtendableTimeoutException extends ExtendedException {
	static final _extensions = WeakMap<Object, int?>();
	final Object _key;
	final Duration duration;

	ExtendableTimeoutException._(this._key, this.duration);

	factory ExtendableTimeoutException.forKey(Object key, Duration baseDuration) {
		final ext = _extensions[key] ?? 0;
		return ExtendableTimeoutException._(key, baseDuration * math.pow(2, ext));
	}

	@override
	Map<String, FutureOr<void> Function(BuildContext)> get remedies => {
		'Extend timeout to ${formatTimeDiff(duration * 2, milliseconds: true)}': (context) {
			_extensions[_key] = (_extensions[_key] ?? 0) + 1;
		}
	};
	
	@override
	bool get isReportable => true;

	@override
	String toString() => 'Timeout after ${formatTimeDiff(duration, milliseconds: true)}';

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is ExtendableTimeoutException &&
		other._key == _key &&
		other.duration == duration;
	
	@override
	int get hashCode => Object.hash(_key, duration);
}

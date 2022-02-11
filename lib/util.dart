import 'dart:async';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:mutex/mutex.dart';
import 'package:share_extend/share_extend.dart';
import 'package:share_plus/share_plus.dart';

extension SafeWhere<T> on Iterable<T> {
	T? tryFirstWhere(bool Function(T v) f) => cast<T?>().firstWhere((v) => f(v!), orElse: () => null);
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
				_deinitializer(_resource!);
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
			return (this as DioError).message;
		}
		else {
			return toString();
		}
	}
}

Future<void> shareOne({
	required String text,
	required String type,
	String? subject,
	required Rect? sharePositionOrigin
}) async {
	if (type == 'file') {
		try {
			await ShareExtend.share(
				text,
				type,
				subject: subject ?? '',
				sharePositionOrigin: sharePositionOrigin
			);
		}
		on MissingPluginException {
			await Share.shareFiles(
				[text],
				subject: subject,
				sharePositionOrigin: sharePositionOrigin
			);
		}
	}
	else {
		await Share.share(
			text,
			subject: subject,
			sharePositionOrigin: sharePositionOrigin
		);
	}
}
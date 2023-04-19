import 'dart:async';
import 'dart:io';

import 'package:chan/main.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

const _platform = MethodChannel('com.moffatman.chan/apple');

bool isOnMac = false;
bool isDevelopmentBuild = false;

Future<void> initializeIsOnMac() async {
	if (!Platform.isIOS) {
		return;
	}
  try {
		isOnMac = await _platform.invokeMethod('isOnMac');
	}
	on MissingPluginException {
		return;
	}
	catch (e, st) {
		print(e);
		print(st);
	}
}

Future<void> initializeIsDevelopmentBuild() async {
	if (!Platform.isIOS) {
		return;
	}
	try {
		isDevelopmentBuild = await _platform.invokeMethod('isDevelopmentBuild');
	}
	on MissingPluginException {
		return;
	}
	catch (e, st) {
		print(e);
		print(st);
	}
}

Future<void> initializeHandoff() async {
	if (!Platform.isIOS) {
		return;
	}
	_platform.setMethodCallHandler((call) async {
		if (call.method == 'receivedHandoffUrl') {
			final url = call.arguments['url'];
			if (url is String) {
				fakeLinkStream.add(url);
			}
		}
	});
}

Timer? _nullUrlTimer;

Future<void> setHandoffUrl(String? url) async {
	if (!Platform.isIOS) {
		return;
	}
	try {
		if (url != null) {
			_nullUrlTimer?.cancel();
			_nullUrlTimer = null;
			await _platform.invokeMethod('setHandoffUrl', {
				'url': url
			});
		}
		else {
			_nullUrlTimer ??= Timer(const Duration(seconds: 1), () {
				_platform.invokeMethod('setHandoffUrl');
				_nullUrlTimer = null;
			});
		}
	}
	on MissingPluginException {
		return;
	}
	catch (e, st) {
		print(e);
		print(st);
	}
}

final _additionalSafeAreaInsetsMap = <String, EdgeInsets>{};
EdgeInsets sumAdditionalSafeAreaInsets() => _additionalSafeAreaInsetsMap.values.fold(EdgeInsets.zero, (sum, a) => sum + a);
Future<void> setAdditionalSafeAreaInsets(String key, EdgeInsets insetsForKey) async {
	if (!Platform.isIOS) {
		return;
	}
	if (_additionalSafeAreaInsetsMap[key] == insetsForKey) {
		return;
	}
	_additionalSafeAreaInsetsMap[key] = insetsForKey;
	final insets = sumAdditionalSafeAreaInsets();
	await _platform.invokeMethod('setAdditionalSafeAreaInsets', {
		'top': insets.top,
		'left': insets.left,
		'right': insets.right,
		'bottom': insets.bottom
	});
}

Future<List<String>> getUIFontFamilyNames() async {
	final result = await _platform.invokeListMethod<String>('getUIFontFamilyNames');
	if (result == null) {
		throw Exception('Error listing local fonts');
	}
	return result;
}
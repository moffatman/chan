import 'dart:async';
import 'dart:io';

import 'package:chan/main.dart';
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
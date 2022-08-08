import 'dart:async';

import 'package:flutter/services.dart';

const _platform = MethodChannel('com.moffatman.chan/apple');

bool isOnMac = false;
bool isDevelopmentBuild = false;

Future<void> initializeIsOnMac() async {
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

Timer? _nullUrlTimer;

Future<void> setHandoffUrl(String? url) async {
	print('setHandoffUrl $url');
	try {
		if (url != null) {
			_nullUrlTimer?.cancel();
			_nullUrlTimer = null;
			await _platform.invokeMethod('setHandoffUrl', {
				'url': url
			});
		}
		else if (_nullUrlTimer == null) {
			print('arming null url timer');
			_nullUrlTimer = Timer(const Duration(seconds: 1), () {
				print('firing null url timer');
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
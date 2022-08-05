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

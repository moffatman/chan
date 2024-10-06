import 'package:flutter/services.dart';

const _platform = MethodChannel('com.moffatman.chan/audio');

Future<bool> areHeadphonesPluggedIn() async {
	try {
		return await _platform.invokeMethod<bool>('areHeadphonesPluggedIn') ?? false;
	}
	on MissingPluginException {
		return false;
	}
	catch (e, st) {
		Future.error(e, st); // Crashlytics
		return false;
	}
}
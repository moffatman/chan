import 'dart:io';

import 'package:flutter/services.dart';

const _platform = MethodChannel('com.moffatman.chan/android');

bool? impellerEnabled;

Future<void> initializeImpeller() async {
	if (!Platform.isAndroid) {
		return;
	}
	try {
		impellerEnabled = await _platform.invokeMethod<bool>('getImpeller');
	}
	on MissingPluginException {
		// Do nothing
	}
	catch (e, st) {
		Future.error(e, st); // Crashlytics
	}
}

/// Will crash the app
Future<void> setImpellerEnabled(bool enabled) async {
	await _platform.invokeMethod('setImpeller', {
		'enabled': enabled
	});
}

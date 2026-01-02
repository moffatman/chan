import 'dart:io';

import 'package:flutter/services.dart';

const _platform = MethodChannel('com.moffatman.chan/android');

bool? impellerEnabled;
bool? legacyStatusBarsEnabled;

Future<void> initializeAndroid() async {
	if (!Platform.isAndroid) {
		return;
	}
	try {
		impellerEnabled = await _platform.invokeMethod<bool>('getImpeller');
		legacyStatusBarsEnabled = await _platform.invokeMethod<bool>('getLegacyStatusBars');
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

Future<void> setLegacyStatusBarsEnabled(bool enabled) async {
	await _platform.invokeMethod('setLegacyStatusBars', {
		'enabled': enabled
	});
	legacyStatusBarsEnabled = enabled;
}

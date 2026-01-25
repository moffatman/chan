import 'dart:io';

import 'package:flutter/services.dart';

const _platform = MethodChannel('com.moffatman.chan/android');

bool? impellerEnabled;
bool? legacyStatusBarsEnabled;
bool canOpenGoogleTranslate = false;

Future<void> initializeAndroid() async {
	if (!Platform.isAndroid) {
		return;
	}
	try {
		impellerEnabled = await _platform.invokeMethod<bool>('getImpeller');
		legacyStatusBarsEnabled = await _platform.invokeMethod<bool>('getLegacyStatusBars');
		canOpenGoogleTranslate = await _platform.invokeMethod<bool>('canOpenGoogleTranslate') ?? false;
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

Future<void> openGoogleTranslate(String text) async {
	await _platform.invokeMethod('openGoogleTranslate', {
		'text': text
	});
}

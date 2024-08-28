import 'package:flutter/services.dart';

const _platform = MethodChannel('com.moffatman.chan/userAgent');

Future<String?> _getDefaultUserAgent() async {
	try {
		return await _platform.invokeMethod('getDefaultUserAgent');
	}
	on MissingPluginException {
		return null;
	}
	catch (e, st) {
		Future.error(e, st); // Crashlytics
		return null;
	}
}

String? defaultUserAgent;

Future<void> initializeDefaultUserAgent() async {
	defaultUserAgent = await _getDefaultUserAgent();
}

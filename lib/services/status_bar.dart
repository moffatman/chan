import 'dart:io';

import 'package:chan/services/persistence.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const _platform = MethodChannel('com.moffatman.chan/statusBar');

Future<void> showStatusBar() async {
	if (Platform.isIOS) {
		await _platform.invokeMethod('showStatusBar');
	}
	else {
		if (Persistence.settings.useStatusBarWorkaround == true) {
			await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
		}
		else {
			_guessWorkaround();
			await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [
				...SystemUiOverlay.values
			]);
		}
	}
}

Future<void> hideStatusBar() async {
	if (Platform.isIOS) {
		await _platform.invokeMethod('hideStatusBar');
	}
	else {
		if (Persistence.settings.useStatusBarWorkaround == true) {
			await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
		}
		else {
			_guessWorkaround();
			await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
		}
	}
}

Size? _lastSize;

void _guessWorkaround() {
	final currentSize = MediaQueryData.fromWindow(WidgetsBinding.instance.window).size;
	Persistence.settings.useStatusBarWorkaround = currentSize != _lastSize && _lastSize != null;
	if (Persistence.settings.useStatusBarWorkaround == true) {
		Persistence.settings.save();
	}
	_lastSize = currentSize;
}
import 'dart:io';

import 'package:flutter/services.dart';

const _platform = MethodChannel('com.moffatman.chan/statusBar');

Future<void> showStatusBar() async {
	if (Platform.isIOS) {
		await _platform.invokeMethod('showStatusBar');
	}
	else {
		await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [
			...SystemUiOverlay.values
		]);
	}
}

Future<void> hideStatusBar() async {
	if (Platform.isIOS) {
		await _platform.invokeMethod('hideStatusBar');
	}
	else {
		await SystemChrome.setEnabledSystemUIMode((Platform.environment['BOOTCLASSPATH'] ?? '').contains('miui-framework') ? SystemUiMode.edgeToEdge : SystemUiMode.immersive);
	}
}
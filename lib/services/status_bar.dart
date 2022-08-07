import 'dart:io';

import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';

const _platform = MethodChannel('com.moffatman.chan/statusBar');

Future<void> showStatusBar() async {
	if (Platform.isIOS) {
		await _platform.invokeMethod('showStatusBar');
	}
	else if (await _workaround()) {
		await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
		await SystemChrome.setEnabledSystemUIMode(await _workaround() ? SystemUiMode.edgeToEdge : SystemUiMode.immersive);
	}
}

Future<bool> _workaround() async {
	if (!Platform.isAndroid) {
		return false;
	}
	final androidInfo = await DeviceInfoPlugin().androidInfo;
	final version = int.tryParse(androidInfo.version.release ?? '') ?? 0;
	return version >= 12 && androidInfo.brand == 'Xiaomi';
}
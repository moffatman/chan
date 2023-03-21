import 'dart:io';

import 'package:flutter/services.dart';

const _platform = MethodChannel('com.moffatman.chan/storage');

Future<String> pickDirectory() async {
	if (Platform.isAndroid) {
		return await _platform.invokeMethod('pickDirectory');
	}
	else {
		throw UnsupportedError('Platform not supported');
	}
}

Future<void> saveFile({
	required String sourcePath,
	required String destinationDir,
	required List<String> destinationSubfolders,
	required String destinationName
}) async {
	await _platform.invokeMethod('saveFile', {
		'sourcePath': sourcePath,
		'destinationDir': destinationDir,
		'destinationSubfolders': destinationSubfolders,
		'destinationName': destinationName
	});
}
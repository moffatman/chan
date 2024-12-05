import 'dart:convert';
import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

const _platform = MethodChannel('com.moffatman.chan/storage');

Future<String?> pickDirectory() async {
	if (Platform.isAndroid) {
		return await _platform.invokeMethod('pickDirectory');
	}
	else {
		throw UnsupportedError('Platform not supported');
	}
}

class DirectoryNotFoundException implements Exception {
	final String directory;
	const DirectoryNotFoundException(this.directory);
	@override
	String toString() => 'Directory not found: $directory';
}

class InsufficientPermissionException implements Exception {
	final String directory;
	const InsufficientPermissionException(this.directory);
	@override
	String toString() => 'Storage permission expired or needs to be re-acquired for "$directory"';
}

Future<String> saveFile({
	required String sourcePath,
	required String destinationDir,
	required List<String> destinationSubfolders,
	required String destinationName
}) async {
	try {
		return (await _platform.invokeMethod<String>('saveFile', {
			'sourcePath': sourcePath,
			'destinationDir': destinationDir,
			'destinationSubfolders': destinationSubfolders,
			'destinationName': destinationName
		}))!;
	}
	on PlatformException catch (e) {
		if (e.code == 'DirectoryNotFound') {
			throw DirectoryNotFoundException(destinationDir);
		}
		if (e.code == 'InsufficientPermission') {
			throw InsufficientPermissionException(destinationDir);
		}
		rethrow;
	}
}

final bool isSaveFileAsSupported = Platform.isAndroid;

Future<String?> saveFileAs({
	required String sourcePath,
	required String destinationName
}) async {
	return await _platform.invokeMethod<String>('saveFileAs', {
		'sourcePath': sourcePath,
		'destinationName': destinationName
	});
}

typedef AndroidPickerIntent = ({String label, MemoryImage? icon, String package});

Future<List<AndroidPickerIntent>> getPickerList() async {
	if (!Platform.isAndroid) {
		return [];
	}
	return (await _platform.invokeListMethod<Map>('getPickerList') ?? []).map((intent) => (
		label: intent['label'] as String,
		package: intent['package'] as String,
		icon: switch (intent['icon']) {
			'' => null,
			String base64 => MemoryImage(base64Decode(base64)),
			_ => null
		}
	)).toList();
}

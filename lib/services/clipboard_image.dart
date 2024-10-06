import 'dart:io';

import 'package:chan/services/persistence.dart';
import 'package:flutter/services.dart';
import 'package:mime/mime.dart';

const _platform = MethodChannel('com.moffatman.chan/clipboard');

Future<bool> doesClipboardContainImage() async {
	try {
		return await _platform.invokeMethod<bool>('doesClipboardContainImage') ?? false;
	}
	on Exception {
		return false;
	}
}

Future<Uint8List?> getClipboardImage() async {
	return await _platform.invokeMethod('getClipboardImage');
}

Future<File?> getClipboardImageAsFile() async {
	final image = await getClipboardImage();
	if (image != null) {
		String? ext = lookupMimeType('', headerBytes: image)?.split('/').last;
		if (ext == 'jpeg') {
			ext = 'jpg';
		}
		if (ext != null) {
			final f = File('${Persistence.shareCacheDirectory.path}/${DateTime.now().millisecondsSinceEpoch}.$ext');
			await f.create(recursive: true);
			await f.writeAsBytes(image, flush: true);
			return f;
		}
	}
	return null;
}

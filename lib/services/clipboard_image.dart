import 'dart:io';

import 'package:chan/services/persistence.dart';
import 'package:chan/services/pick_attachment.dart';
import 'package:chan/services/util.dart';
import 'package:chan/util.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mime/mime.dart';

const _platform = MethodChannel('com.moffatman.chan/clipboard');

Future<void> copyImageToClipboard(File image) async {
	final input = await image.open();
	late final List<int> headerBytes;
	try {
		headerBytes = await input.read(defaultMagicNumbersMaxLength);
	}
	finally {
		await input.close();
	}
	final mimeType = lookupMimeType(image.path, headerBytes: headerBytes);
	if (mimeType == null || !mimeType.startsWith('image/')) {
		throw UnsupportedError('Could not determine the image type');
	}
	final extension = extensionFromMime(mimeType);
	final clipboardDirectory = Persistence.temporaryDirectory.dir('clipboard');
	await clipboardDirectory.create(recursive: true);
	final clipboardFile = await image.copy(clipboardDirectory.child(
		'clipboard_${DateTime.now().microsecondsSinceEpoch}.$extension'
	));
	try {
		await _platform.invokeMethod<void>('setClipboardImage', {
			'path': clipboardFile.path,
			'mimeType': mimeType
		});
	}
	catch (_) {
		await clipboardFile.delete();
		rethrow;
	}
	await for (final entry in clipboardDirectory.list()) {
		if (entry is File) {
			try {
				if (!await FileSystemEntity.identical(entry.path, clipboardFile.path)) {
					await entry.delete();
				}
			}
			on FileSystemException {
				// The clipboard still works if an older cache file is in use.
			}
		}
	}
}

Future<bool> doesClipboardContainImage() async {
	try {
		return await _platform.invokeMethod<bool>('doesClipboardContainImage') ?? false;
	}
	on Exception {
		return false;
	}
}

Future<File?> getClipboardImageAsFile(BuildContext context) async {
	final image = await _platform.invokeMethod('getClipboardImage');
	if (image case Uint8List bytes) {
		String? ext = lookupMimeType('', headerBytes: bytes)?.afterLast('/');
		if (ext == 'jpeg') {
			ext = 'jpg';
		}
		if (ext != null) {
			final f = Persistence.shareCacheDirectory.file('${DateTime.now().millisecondsSinceEpoch}.$ext');
			await f.create(recursive: true);
			await f.writeAsBytes(bytes, flush: true);
			return f;
		}
	}
	else if (image case String text) {
		Uri? url = Uri.tryParse(text);
		if (url == null || url.host.isEmpty) {
			return null;
		}
		if (!supportedFileExtensions.contains('.${url.path.afterLast('.')}')) {
			return null;
		}
		if (url.scheme.isEmpty) {
			url = url.replace(scheme: 'https');
		}
		if (!context.mounted) {
			return null;
		}
		return await downloadToShareCache(context: context, url: url);
	}
	return null;
}

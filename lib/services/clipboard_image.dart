import 'dart:io';

import 'package:chan/services/persistence.dart';
import 'package:chan/services/pick_attachment.dart';
import 'package:chan/services/util.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
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

Future<File?> getClipboardImageAsFile(BuildContext context) async {
	final image = await _platform.invokeMethod('getClipboardImage');
	if (image case Uint8List bytes) {
		String? ext = lookupMimeType('', headerBytes: bytes)?.split('/').last;
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

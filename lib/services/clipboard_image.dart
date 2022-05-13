import 'dart:io';
import 'dart:typed_data';

import 'package:chan/services/persistence.dart';
import 'package:chan/widgets/reply_box.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:mime/mime.dart';

const _platform = MethodChannel('com.moffatman.chan/clipboard');

Future<bool> doesClipboardContainImage() async {
	try {
		return await _platform.invokeMethod('doesClipboardContainImage');
	}
	on MissingPluginException {
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
			final f = File('${Persistence.temporaryDirectory.path}/sharecache/${DateTime.now().millisecondsSinceEpoch}.$ext');
			await f.create(recursive: true);
			await f.writeAsBytes(image, flush: true);
			return f;
		}
	}
	return null;
}

class CupertinoTextSelectionControlsWithClipboardImage extends CupertinoTextSelectionControls {
	final ReplyBoxState replyBox;

	CupertinoTextSelectionControlsWithClipboardImage(this.replyBox);

	@override
	Future<void> handlePaste(TextSelectionDelegate delegate) async {
		await super.handlePaste(delegate);
		final file = await getClipboardImageAsFile();
		if (file != null) {			
			replyBox.setAttachment(file);
		}
	}
}
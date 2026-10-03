import 'dart:async';

import 'package:chan/models/attachment.dart';
import 'package:chan/services/media.dart';
import 'package:chan/services/streaming_mp4.dart';
import 'package:chan/util.dart';
import 'package:extended_image_library/extended_image_library.dart';

class AttachmentCache {
	static final _streamController = StreamController<(Attachment, Object)>.broadcast();
	static Stream<(Attachment, Object)> get stream => _streamController.stream;
	static onCached(Attachment attachment, Object source) {
		_streamController.add((attachment, source));
	}
	static Future<File?> optimisticallyFindFile(Attachment attachment) async {
		if (attachment.type == AttachmentType.pdf || attachment.type == AttachmentType.url) {
			// Not cacheable
			return null;
		}
		if (attachment.type == AttachmentType.image) {
			return await getCachedImageFile(attachment.url);
		}
		final uri = Uri.parse(attachment.url);
		final isM3u8 = uri.path.afterLast('.').toLowerCase() == 'm3u8';
		if (attachment.type == AttachmentType.webm || isM3u8) {
			final conversion = MediaConversion.toMp4(uri);
			final file = conversion.getDestination();
			if (await file.exists()) {
				return file;
			}
			if (isM3u8) {
				// If we don't have the converted file, the m3u8 alone is useless
				return null;
			}
			// Fall through in case WEBM is directly playing
		}
		final file = VideoServer.instance.optimisticallyGetFile(uri);
		if (file != null && await file.exists()) {
			return file;
		}
		return null;
	}
}

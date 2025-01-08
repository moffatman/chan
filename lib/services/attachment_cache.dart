import 'dart:async';

import 'package:chan/models/attachment.dart';
import 'package:chan/services/media.dart';
import 'package:chan/services/streaming_mp4.dart';
import 'package:extended_image_library/extended_image_library.dart';

class AttachmentCache {
	static final _streamController = StreamController<Attachment>.broadcast();
	static Stream<Attachment> get stream => _streamController.stream;
	static onCached(Attachment attachment) {
		_streamController.add(attachment);
	}
	static Future<File?> optimisticallyFindFile(Attachment attachment) async {
		if (attachment.type == AttachmentType.pdf || attachment.type == AttachmentType.url) {
			// Not cacheable
			return null;
		}
		if (attachment.type == AttachmentType.image) {
			return await getCachedImageFile(attachment.url);
		}
		if (attachment.type == AttachmentType.webm) {
			final conversion = MediaConversion.toMp4(Uri.parse(attachment.url));
			final file = conversion.getDestination();
			if (await file.exists()) {
				return file;
			}
			// Fall through in case WEBM is directly playing
		}
		final file = VideoServer.instance.optimisticallyGetFile(Uri.parse(attachment.url));
		if (file != null && await file.exists()) {
			return file;
		}
		return null;
	}
}

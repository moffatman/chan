import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// iOS adds junk EXIF blocks after saving, need to strip them
Future<Digest?> _calculateJpegMD5(File file) async {
	final stat = file.statSync();
	if (stat.size < 4) {
		return null;
	}
	final handle = await file.open();
	try {
		final header = await handle.read(2);
		if (!(header[0] == 0xFF && header[1] == 0xD8)) {
			// Not JPEG
			return null;
		}
		final completer = Completer<Digest>();
		final conversion = md5.startChunkedConversion(ChunkedConversionSink.withCallback(
			(digests) => completer.complete(digests.first)
		));
		conversion.add(header);
		while (true) {
			final marker = await handle.read(2);
			if (marker.isEmpty) {
				// EOF
				break;
			}
			if (marker[0] != 0xFF) {
				// Something went wrong
				return null;
			}
			if (marker[1] == 0xDA) {
				// Start of scan, read rest of image
				conversion.add(marker);
				final restChunk = await handle.read(stat.size - await handle.position());
				conversion.add(restChunk);
				break;
			}
			final lengthChunk = await handle.read(2);
			final length = (256 * lengthChunk[0]) + lengthChunk[1] - 2;
			final data = await handle.read(length);
			if (marker[1] != 0xE1) {
				// Not EXIF block, copy it
				conversion.add(marker);
				conversion.add(lengthChunk);
				conversion.add(data);
			}
		}
		conversion.close();
		return await completer.future;
	}
	finally {
		handle.close();
	}
}

/// Returns MD5 in archive format
Future<String> calculateMD5(File file) async {
	Digest? digest;
	if (file.path.endsWith('.jpeg') || file.path.endsWith('.jpg')) {
		try {
			digest = await _calculateJpegMD5(file);
		}
		catch (e, st) {
			Future.error(e, st);
		}
	}
	digest ??= await md5.bind(file.openRead()).first;
	return base64Encode(digest.bytes);
}

import 'dart:io';
import 'dart:ui';

import 'package:chan/services/media.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

class ThumbnailImageProvider extends ImageProvider<ThumbnailImageProvider> {
	final File file;
	final double scale;

	ThumbnailImageProvider({
		required this.file,
		this.scale = 1.0
	});

	@override
	ImageStreamCompleter loadBuffer(ThumbnailImageProvider key, DecoderBufferCallback decode) {
		return MultiFrameImageStreamCompleter(
			codec: () async {
				assert(key == this);
				final conversion = MediaConversion.extractThumbnail(file.uri);
				conversion.start();
				final result = await conversion.result;
				final bytes = await result.file.readAsBytes();
				return await decode(await ImmutableBuffer.fromUint8List(bytes));
			}(),
			scale: key.scale
		);
	}

	@override
	Future<ThumbnailImageProvider> obtainKey(ImageConfiguration configuration) => SynchronousFuture<ThumbnailImageProvider>(this);

	@override
	bool operator == (dynamic other) => (other is ThumbnailImageProvider) && (other.file.path == file.path) && (other.scale == scale);

	@override
	int get hashCode => Object.hash(file.path, scale);

	@override
	String toString() => 'ThumbnailImageProvider(file: $file, scale; $scale)';
}
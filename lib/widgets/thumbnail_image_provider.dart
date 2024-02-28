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
	ImageStreamCompleter loadImage(ThumbnailImageProvider key, ImageDecoderCallback decode) {
		return MultiFrameImageStreamCompleter(
			codec: () async {
				assert(key == this);
				final conversion = MediaConversion.extractThumbnail(file.uri);
				Uint8List bytes;
				if (await conversion.getDestination().exists()) {
					bytes = await conversion.getDestination().readAsBytes();
				}
				else {
					final result = await conversion.start();
					bytes = await result.file.readAsBytes();
				}
				return await decode(await ImmutableBuffer.fromUint8List(bytes));
			}(),
			scale: key.scale
		);
	}

	@override
	Future<ThumbnailImageProvider> obtainKey(ImageConfiguration configuration) => SynchronousFuture<ThumbnailImageProvider>(this);

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		(other is ThumbnailImageProvider) &&
		(other.file.path == file.path) &&
		(other.scale == scale);

	@override
	int get hashCode => Object.hash(file.path, scale);

	@override
	String toString() => 'ThumbnailImageProvider(file: $file, scale; $scale)';
}
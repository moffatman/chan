import 'dart:ui';

import 'package:chan/services/media.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

class ThumbnailImageProvider extends ImageProvider<ThumbnailImageProvider> {
	final Uri uri;
	final Map<String, String>? headers;
	final double scale;

	ThumbnailImageProvider({
		required this.uri,
		this.headers,
		this.scale = 1.0
	});

	@override
	ImageStreamCompleter loadImage(ThumbnailImageProvider key, ImageDecoderCallback decode) {
		return MultiFrameImageStreamCompleter(
			codec: () async {
				assert(key == this);
				final conversion = MediaConversion.extractThumbnail(uri, headers: headers);
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
		(other.uri == uri) &&
		(other.scale == scale);

	@override
	int get hashCode => Object.hash(uri, scale);

	@override
	String toString() => 'ThumbnailImageProvider(uri: $uri, scale; $scale)';
}
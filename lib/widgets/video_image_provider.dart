import 'dart:io';
import 'dart:ui';

import 'package:chan/services/media.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

class VideoImageProvider extends ImageProvider<VideoImageProvider> {
	final File video;
	final double scale;

	VideoImageProvider({
		required this.video,
		this.scale = 1.0
	});

	@override
	ImageStreamCompleter loadBuffer(VideoImageProvider key, DecoderBufferCallback decode) {
		return MultiFrameImageStreamCompleter(
			codec: () async {
				assert(key == this);
				final conversion = MediaConversion.extractThumbnail(video.uri);
				conversion.start();
				final result = await conversion.result;
				final bytes = await result.file.readAsBytes();
				return await decode(await ImmutableBuffer.fromUint8List(bytes));
			}(),
			scale: key.scale
		);
	}

	@override
	Future<VideoImageProvider> obtainKey(ImageConfiguration configuration) => SynchronousFuture<VideoImageProvider>(this);

	@override
	bool operator == (dynamic other) => (other is VideoImageProvider) && (other.video.path == video.path) && (other.scale == scale);

	@override
	int get hashCode => Object.hash(video.path, scale);

	@override
	String toString() => 'VideoImageProvider(video: $video, scale; $scale)';
}
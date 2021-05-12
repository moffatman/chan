
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as image;

class RotatedImageKey {
	Object parentKey;
	int quarterTurns;

	RotatedImageKey({
		required this.parentKey,
		required this.quarterTurns
	});

	@override
	bool operator == (dynamic d) => d is RotatedImageKey && (d.parentKey == parentKey) && (d.quarterTurns == quarterTurns);

	@override
	int get hashCode => hashValues(parentKey, quarterTurns);
}

class RotatingImageProvider extends ImageProvider<RotatedImageKey> {
	final ImageProvider parent;
	final int quarterTurns;
	RotatingImageProvider({
		required this.parent,
		required this.quarterTurns
	});

	@override
	ImageStreamCompleter load(RotatedImageKey key, DecoderCallback decode) {
		return parent.load(key.parentKey, (data, {bool allowUpscaling = false, int? cacheHeight, int? cacheWidth}) async {
			final originalImage = image.decodeAnimation(data)!;
			final rotatedImage = image.Animation();
			rotatedImage.frameType = originalImage.frameType;
			rotatedImage.width = (quarterTurns % 2 == 1) ? originalImage.height : originalImage.width;
			rotatedImage.height = (quarterTurns % 2 == 1) ? originalImage.width : originalImage.height;
			rotatedImage.loopCount = originalImage.loopCount;
			rotatedImage.backgroundColor = originalImage.backgroundColor;
			for (final i in originalImage.frames) {
				final rotatedFrame = image.copyRotate(i, quarterTurns * 90, interpolation: image.Interpolation.cubic);
				rotatedFrame.duration = i.duration;
				rotatedImage.addFrame(rotatedFrame);
			}
			return await decode(Uint8List.fromList(rotatedImage.length > 1 ? image.encodeGifAnimation(rotatedImage)! : image.encodePng(rotatedImage.first)), allowUpscaling: allowUpscaling, cacheHeight: cacheHeight, cacheWidth: cacheWidth);
		});
	}

	@override
	Future<RotatedImageKey> obtainKey(ImageConfiguration configuration) async {
		return RotatedImageKey(
			parentKey: await parent.obtainKey(configuration),
			quarterTurns: quarterTurns
		);
	}
}
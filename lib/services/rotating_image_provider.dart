
import 'dart:async';
import 'dart:isolate';
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
	bool operator == (dynamic other) => other is RotatedImageKey && (other.parentKey == parentKey) && (other.quarterTurns == quarterTurns);

	@override
	int get hashCode => hashValues(parentKey, quarterTurns);
}

class _RotateIsolateParam {
	final Uint8List data;
	final int quarterTurns;
	final SendPort sendPort;
	_RotateIsolateParam(this.data, this.quarterTurns, this.sendPort);
}

void _rotateImageIsolate(_RotateIsolateParam param) {
	final originalImage = image.decodeAnimation(param.data)!;
	final rotatedImage = image.Animation();
	rotatedImage.frameType = originalImage.frameType;
	rotatedImage.width = (param.quarterTurns % 2 == 1) ? originalImage.height : originalImage.width;
	rotatedImage.height = (param.quarterTurns % 2 == 1) ? originalImage.width : originalImage.height;
	rotatedImage.loopCount = originalImage.loopCount;
	rotatedImage.backgroundColor = originalImage.backgroundColor;
	for (final i in originalImage.frames) {
		final rotatedFrame = image.copyRotate(i, param.quarterTurns * 90, interpolation: image.Interpolation.cubic);
		rotatedFrame.duration = i.duration;
		rotatedImage.addFrame(rotatedFrame);
	}
	if (rotatedImage.length > 1) {
		param.sendPort.send(Uint8List.fromList(image.encodeGifAnimation(rotatedImage)!));
	}
	else {
		param.sendPort.send(Uint8List.fromList(image.encodePng(rotatedImage.first)));
	}
}

class RotatingImageProvider extends ImageProvider<RotatedImageKey> {
	final ImageProvider parent;
	final int quarterTurns;
	final VoidCallback? onLoaded;
	RotatingImageProvider({
		required this.parent,
		required this.quarterTurns,
		this.onLoaded
	});

	@override
	ImageStreamCompleter load(RotatedImageKey key, DecoderCallback decode) {
		return parent.load(key.parentKey, (data, {bool allowUpscaling = false, int? cacheHeight, int? cacheWidth}) async {
			final receivePort = ReceivePort();
			await Isolate.spawn(_rotateImageIsolate, _RotateIsolateParam(data, quarterTurns, receivePort.sendPort));
			final outData = await receivePort.first as Uint8List;
			final result = await decode(outData, allowUpscaling: allowUpscaling, cacheHeight: cacheHeight, cacheWidth: cacheWidth);
			onLoaded?.call();
			return result;
		});
	}

	@override
	Future<RotatedImageKey> obtainKey(ImageConfiguration configuration) async {
		return RotatedImageKey(
			parentKey: await parent.obtainKey(configuration),
			quarterTurns: quarterTurns
		);
	}

	@override
	bool operator == (dynamic other) => (other is RotatingImageProvider) && (other.parent == parent) && (other.quarterTurns == quarterTurns);

	@override
	int get hashCode => hashValues(parent, quarterTurns);
}
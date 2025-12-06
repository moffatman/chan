import 'dart:async';

import 'package:flutter/rendering.dart';

/// To expose protected method
class _OneFrameImageStreamCompleter extends OneFrameImageStreamCompleter {
	_OneFrameImageStreamCompleter(super.image);
	void _reportImageChunkEvent(ImageChunkEvent event)	=> reportImageChunkEvent(event);
}

class WrappedOneFrameImageProviderKey<T> {
	final T key;
	const WrappedOneFrameImageProviderKey(this.key);

	@override
	int get hashCode => key.hashCode;
	@override
	bool operator ==(Object other) =>
		identical(this, other) ||
		other is WrappedOneFrameImageProviderKey<T> &&
		other.key == key;

	@override
	String toString() => 'WrappedOneFrameImageProviderKey<$T>($key)';
}

class OneFrameImageProvider<T extends Object> extends ImageProvider<WrappedOneFrameImageProviderKey<T>> {
	final ImageProvider<T> imageProvider;

	const OneFrameImageProvider(this.imageProvider);

	@override
	Future<WrappedOneFrameImageProviderKey<T>> obtainKey(ImageConfiguration configuration) {
		return imageProvider.obtainKey(configuration).then((k) => WrappedOneFrameImageProviderKey(k));
	}

	@override
	ImageStreamCompleter loadImage(WrappedOneFrameImageProviderKey<T> key, ImageDecoderCallback decode) {
		final nested = imageProvider.loadImage(key.key, decode);
		final completer = Completer<ImageInfo>();
		final out = _OneFrameImageStreamCompleter(completer.future);
		ImageStreamListener? listener;
		listener = ImageStreamListener(
			(image, synchronousCall) {
				completer.complete(image);
				// Give outer listener a chance
				Future.microtask(() => nested.removeListener(listener!));
			},
			onChunk: out._reportImageChunkEvent,
			onError: (e, st) {
				if (!completer.isCompleted) {
					completer.completeError(e, st);
					nested.removeListener(listener!);
				}
			}
		);
		nested.addListener(listener);
		return out;
	}
}

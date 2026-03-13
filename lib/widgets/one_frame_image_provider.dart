import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// To expose protected method
class _OneFrameImageStreamCompleter extends OneFrameImageStreamCompleter {
	_OneFrameImageStreamCompleter(super.image);
	void _reportImageChunkEvent(ImageChunkEvent event)	=> reportImageChunkEvent(event);
}

class _SynchronousOneFrameImageStreamCompleter extends ImageStreamCompleter {
	_SynchronousOneFrameImageStreamCompleter(ImageInfo image) {
		setImage(image);
	}
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
		Completer<WrappedOneFrameImageProviderKey<T>>? completer;
		// If the imageProvider.obtainKey future is synchronous, then we will be able to fill in result with
		// a value before completer is initialized below.
		SynchronousFuture<WrappedOneFrameImageProviderKey<T>>? result;
		imageProvider.obtainKey(configuration).then((T key) {
			if (completer == null) {
				// This future has completed synchronously (completer was never assigned),
				// so we can directly create the synchronous result to return.
				result = SynchronousFuture<WrappedOneFrameImageProviderKey<T>>(
					WrappedOneFrameImageProviderKey(key),
				);
			} else {
				// This future did not synchronously complete.
				completer.complete(WrappedOneFrameImageProviderKey(key));
			}
		});
		if (result != null) {
			return result!;
		}
		// If the code reaches here, it means the imageProvider.obtainKey was not
		// completed sync, so we initialize the completer for completion later.
		completer = Completer<WrappedOneFrameImageProviderKey<T>>();
		return completer.future;
	}

	@override
	ImageStreamCompleter loadImage(WrappedOneFrameImageProviderKey<T> key, ImageDecoderCallback decode) {
		final nested = imageProvider.loadImage(key.key, decode);
		Completer<ImageInfo>? completer;
		void Function(ImageChunkEvent event)? reportImageChunkEventCb;
		void reportImageChunkEvent(ImageChunkEvent event) {
			reportImageChunkEventCb?.call(event);
		}
		ImageInfo? result;
		ImageStreamListener? listener;
		listener = ImageStreamListener(
			(image, synchronousCall) {
				if (completer == null) {
					result = image;
				}
				else {
					completer.complete(image);
				}
				// Give outer listener a chance
				Future.microtask(() => nested.removeListener(listener!));
			},
			onChunk: reportImageChunkEvent,
			onError: (e, st) {
				if (!completer!.isCompleted) {
					completer.completeError(e, st);
					nested.removeListener(listener!);
				}
			}
		);
		nested.addListener(listener);
		if (result != null) {
			return _SynchronousOneFrameImageStreamCompleter(result!);
		}
		completer = Completer();
		final out = _OneFrameImageStreamCompleter(completer.future);
		reportImageChunkEventCb = out._reportImageChunkEvent;
		return out;
	}
}

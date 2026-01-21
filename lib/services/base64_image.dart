import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// Fixed cache frame missed
class Base64ImageProvider extends ImageProvider<Base64ImageProvider> {
	final String data;

	Base64ImageProvider(this.data);

	@override
	ImageStreamCompleter loadImage(Base64ImageProvider key, ImageDecoderCallback decode) {
		return MultiFrameImageStreamCompleter(
			codec: _loadAsync(decode),
			scale: 1.0
		);
	}

	Future<ui.Codec> _loadAsync(ImageDecoderCallback decode) async {
		return await decode(await ui.ImmutableBuffer.fromUint8List(base64.decode(data)));
	}

	@override
	Future<Base64ImageProvider> obtainKey(ImageConfiguration configuration) {
	return SynchronousFuture<Base64ImageProvider>(this);
	}

	@override
	bool operator ==(Object other) =>
		identical(this, other) ||
		other is Base64ImageProvider &&
		other.data == data;

	@override
	int get hashCode => data.hashCode;

	@override
	String toString() => '${objectRuntimeType(this, 'Base64ImageProvider')}(data.length=${data.length})';
}

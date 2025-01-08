import 'dart:async';
import 'dart:typed_data';

import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:dio/dio.dart';
import 'package:extended_image_library/extended_image_library_io.dart';
import 'package:flutter/widgets.dart';

class CNetworkImageProvider extends ExtendedNetworkImageProvider {
	final Dio? client;
  CNetworkImageProvider(super.url, {
		required this.client,
		super.cache,
		super.headers
	});

	@override
	Future<Uint8List?> loadNetwork(
		ExtendedNetworkImageProvider key,
    StreamController<ImageChunkEvent>? chunkEvents,
	) async {
		final client = (this.client ?? Settings.instance.client);
		final resolved = Uri.base.resolve(key.url);
		final response = await client.getUri(resolved, options: Options(
			responseType: ResponseType.bytes,
			headers: headers,
			extra: {
				// We can't really get the image bytes after clearing cloudflare, don't try it
				kPriority: RequestPriority.cosmetic
			}
		), onReceiveProgress: chunkEvents == null ? null : (count, total) {
			chunkEvents.add(ImageChunkEvent(
				cumulativeBytesLoaded: count,
				expectedTotalBytes: total
			));
		});
		final bytes = response.data as List<int>;
		if (bytes.isEmpty) {
			throw StateError('NetworkImage is empty file: $resolved');
		}
		return Uint8List.fromList(bytes);
	}

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
	 	other is CNetworkImageProvider &&
		other.client == client &&
		other.url == url &&
		other.cache == cache;
	
	@override
	int get hashCode => Object.hash(client, url, cache);
}
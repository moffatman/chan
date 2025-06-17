import 'dart:async';
import 'dart:typed_data';

import 'package:chan/services/cloudflare.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:dio/dio.dart';
import 'package:extended_image_library/extended_image_library_io.dart';
import 'package:flutter/widgets.dart';

class CNetworkImageProvider extends ExtendedNetworkImageProvider {
	final Dio? client;
	final RequestPriority priority;

  CNetworkImageProvider(super.url, {
		required this.client,
		super.cache,
		super.headers,
		this.priority = RequestPriority.cosmetic
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
				kPriority: priority,
				kRetryIfCloudflare: true
			}
		), onReceiveProgress: chunkEvents == null ? null : (count, total) {
			chunkEvents.add(ImageChunkEvent(
				cumulativeBytesLoaded: count,
				expectedTotalBytes: total > 0 ? total : null
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
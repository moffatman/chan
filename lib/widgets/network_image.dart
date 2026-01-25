import 'package:chan/services/network_image_provider.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/widgets.dart';

class CNetworkImage extends StatelessWidget {
	final String url;
	final Dio? client;
	final Map<String, String>? headers;
	final String extraCookie;
	final bool cache;
	final BoxFit? fit;
	final bool enableLoadState;
	final Widget? Function(ExtendedImageState)? loadStateChanged;
	final FilterQuality filterQuality;
	final double? width;
	final double? height;
	final int? cacheWidth;
	final int? cacheHeight;
	final RequestPriority priority;

	const CNetworkImage({
		required this.url,
		required this.client,
		this.headers,
		this.extraCookie = '',
		this.cache = false,
		this.fit,
		this.enableLoadState = false,
		this.loadStateChanged,
		this.filterQuality = FilterQuality.low,
		this.width,
		this.height,
		this.cacheWidth,
		this.cacheHeight,
		this.priority = RequestPriority.cosmetic,
		super.key
	});

	@override
	Widget build(BuildContext context) {
		return ExtendedImage(
			image: ExtendedResizeImage.resizeIfNeeded(
				provider: CNetworkImageProvider(
					url,
					client: client,
					headers: headers,
					extraCookie: extraCookie,
					cache: cache,
					priority: priority
				),
				cacheWidth: cacheWidth,
				cacheHeight: cacheHeight
			),
			fit: fit,
			filterQuality: filterQuality,
			enableLoadState: enableLoadState,
			loadStateChanged: loadStateChanged,
			width: width,
			height: height,
		);
	}
}

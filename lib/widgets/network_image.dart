import 'package:chan/services/network_image_provider.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/widgets.dart';

class CNetworkImage extends StatelessWidget {
	final String url;
	final Dio? client;
	final Map<String, String>? headers;
	final bool cache;
	final BoxFit? fit;
	final bool enableLoadState;
	final Widget? Function(ExtendedImageState)? loadStateChanged;
	final FilterQuality filterQuality;
	final double? width;
	final double? height;
	final int? cacheWidth;
	final int? cacheHeight;

	const CNetworkImage({
		required this.url,
		required this.client,
		this.headers,
		this.cache = false,
		this.fit,
		this.enableLoadState = false,
		this.loadStateChanged,
		this.filterQuality = FilterQuality.low,
		this.width,
		this.height,
		this.cacheWidth,
		this.cacheHeight,
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
					cache: cache
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

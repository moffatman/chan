import 'package:chan/services/imageboard.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class ImageboardIcon extends StatelessWidget {
	final String? imageboardKey;

	const ImageboardIcon({
		this.imageboardKey,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		final imageboard = context.watch<Imageboard?>() ?? ImageboardRegistry.instance.getImageboard(imageboardKey ?? '');
		if (imageboard == null) {
			return const Icon(CupertinoIcons.exclamationmark_triangle_fill);
		}
		return ExtendedImage.network(
			imageboard.site.iconUrl.toString(),
			headers: imageboard.site.getHeaders(imageboard.site.iconUrl),
			cache: true,
			enableLoadState: false,
			filterQuality: FilterQuality.high,
			width: 16,
			height: 16,
			cacheWidth: 32,
			cacheHeight: 32,
		);
	}
}
import 'package:chan/services/imageboard.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class ImageboardIcon extends StatelessWidget {

	const ImageboardIcon({
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		final imageboard = context.read<Imageboard?>();
		if (imageboard == null) {
			return const Icon(CupertinoIcons.exclamationmark_triangle_fill);
		}
		return ExtendedImage.network(
			imageboard.site.iconUrl.toString(),
			headers: imageboard.site.getHeaders(imageboard.site.iconUrl),
			cache: true,
			enableLoadState: false,
			width: 16,
			height: 16,
			cacheWidth: 32,
			cacheHeight: 32,
		);
	}
}
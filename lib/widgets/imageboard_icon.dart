import 'package:chan/services/imageboard.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/network_image.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class ImageboardIcon extends StatelessWidget {
	final ImageboardSite? site;
	final String? imageboardKey;
	final String? boardName;
	final double size;

	const ImageboardIcon({
		this.site,
		this.imageboardKey,
		this.boardName,
		this.size = 16,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		Imageboard? imageboard;
		if (this.site == null) {
			imageboard = context.watch<Imageboard?>();
			if (imageboardKey != null) {
				imageboard = ImageboardRegistry.instance.getImageboard(imageboardKey!);
			}
		}
		final site = this.site ?? imageboard?.site;
		if (site == null) {
			return Icon(CupertinoIcons.exclamationmark_triangle_fill, size: size);
		}
		Uri? url = site.iconUrl;
		bool clipOval = false;
		if (boardName != null) {
			final boardUrl = imageboard?.persistence.getBoard(boardName!).icon;
			if (boardUrl != null) {
				url = boardUrl;
				clipOval = true;
			}
		}
		final cacheSize = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
		final child = SizedBox.square(
			dimension: size,
			child: url != null ? CNetworkImage(
				url: url.toString(),
				client: site.client,
				cache: true,
				enableLoadState: true,
				loadStateChanged: (state) {
					if (state.extendedImageLoadState == LoadState.failed) {
						return Builder(
							builder: (context) => Center(
								child: Icon(CupertinoIcons.exclamationmark_triangle_fill, size: size)
							)
						);
					}
					else if (state.extendedImageLoadState == LoadState.loading) {
						return const SizedBox();
					}
					return null;
				},
				filterQuality: FilterQuality.high,
				fit: BoxFit.contain,
				width: size,
				height: size,
				cacheWidth: cacheSize,
				cacheHeight: cacheSize,
			) : Icon(CupertinoIcons.globe, size: size)
		);
		if (clipOval) {
			return ClipOval(
				child: child
			);
		}
		return child;
	}
}

class ImageboardSiteLoginSystemIcon extends StatelessWidget {
	final ImageboardSiteLoginSystem? loginSystem;
	final double size;

	const ImageboardSiteLoginSystemIcon({
		required this.loginSystem,
		this.size = 16,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		final url = loginSystem?.iconUrl;
		final cacheSize = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
		return SizedBox.square(
			dimension: size,
			child: url != null ? CNetworkImage(
				url: url.toString(),
				client: loginSystem?.parent.client,
				cache: true,
				enableLoadState: true,
				loadStateChanged: (state) {
					if (state.extendedImageLoadState == LoadState.failed) {
						return Builder(
							builder: (context) => Center(
								child: Icon(CupertinoIcons.exclamationmark_triangle_fill, size: size)
							)
						);
					}
					else if (state.extendedImageLoadState == LoadState.loading) {
						return const SizedBox();
					}
					return null;
				},
				filterQuality: FilterQuality.high,
				fit: BoxFit.contain,
				width: size,
				height: size,
				cacheWidth: cacheSize,
				cacheHeight: cacheSize,
			) : Icon(CupertinoIcons.person, size: size)
		);
	}
}

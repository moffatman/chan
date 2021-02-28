import 'package:chan/models/attachment.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/services/util.dart';
import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:provider/provider.dart';

class AttachmentThumbnail extends StatelessWidget {
	final Attachment attachment;
	final double width;
	final double height;
	final BoxFit fit;
	final bool hero;
	final Object? heroTag;

	AttachmentThumbnail({
		required this.attachment,
		this.width = 75,
		this.height = 75,
		this.fit = BoxFit.contain,
		this.hero = true,
		this.heroTag
	});

	@override
	Widget build(BuildContext context) {
		final url = context.watch<ImageboardSite>().getAttachmentThumbnailUrl(attachment).toString();
		Widget child = ExtendedImage.network(
			url,
			width: width,
			height: height,
			fit: fit,
			cache: true,
			loadStateChanged: (loadstate) {
				if (loadstate.extendedImageLoadState == LoadState.loading) {
					return SizedBox(
						width: width,
						height: height,
						child: Center(
							child: CircularProgressIndicator(
								value: (loadstate.loadingProgress != null) ? loadstate.loadingProgress!.cumulativeBytesLoaded / loadstate.loadingProgress!.expectedTotalBytes! : null
							)
						)
					);
				}
				else if (loadstate.extendedImageLoadState == LoadState.failed) {
					return SizedBox(
						width: width,
						height: height,
						child: Center(
							child: Icon(Icons.error)
						)
					);
				}
			}
		);
		return hero ? Hero(
			tag: heroTag ?? attachment,
			child: child,
			flightShuttleBuilder: (context, animation, direction, fromContext, toContext) {
				return (direction == HeroFlightDirection.push ? fromContext.widget as Hero : toContext.widget as Hero).child;
			},
		) : child;
	}
}
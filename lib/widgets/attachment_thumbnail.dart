import 'package:chan/models/attachment.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:provider/provider.dart';

class AttachmentSemanticLocation {
	String _tag;
	AttachmentSemanticLocation({
		required List<int> semanticParents,
		required Attachment attachment
	}) : _tag = semanticParents.join('/') + '/' + attachment.id.toString();

	@override
	bool operator == (Object other) {
		if (identical(this, other)) {
			return true;
		}
		return (other is AttachmentSemanticLocation) && _tag == other._tag;
	}

	@override
	int get hashCode {
		return _tag.hashCode;
	}
}

class AttachmentThumbnail extends StatelessWidget {
	final Attachment attachment;
	final double width;
	final double height;
	final BoxFit fit;
	final Object? hero;

	AttachmentThumbnail({
		required this.attachment,
		this.width = 75,
		this.height = 75,
		this.fit = BoxFit.contain,
		this.hero
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
		return (hero != null) ? Hero(
			tag: hero!,
			child: child,
			flightShuttleBuilder: (context, animation, direction, fromContext, toContext) {
				return (direction == HeroFlightDirection.push ? fromContext.widget as Hero : toContext.widget as Hero).child;
			},
		) : child;
	}
}
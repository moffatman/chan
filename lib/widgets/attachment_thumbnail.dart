import 'package:chan/models/attachment.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/services/rotating_image_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:provider/provider.dart';

class AttachmentSemanticLocation {
	String _tag;
	AttachmentSemanticLocation({
		required Iterable<int> semanticParents,
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

	@override
	String toString() => 'AttachmentSemanticLocation($_tag)';
}

class AttachmentThumbnail extends StatelessWidget {
	final ThreadIdentifier? thread;
	final Attachment attachment;
	final double width;
	final double height;
	final BoxFit fit;
	final Object? hero;
	final int quarterTurns;
	final ValueChanged<Object?>? onLoadError;
	final bool gaplessPlayback;

	AttachmentThumbnail({
		required this.attachment,
		this.thread,
		this.width = 75,
		this.height = 75,
		this.fit = BoxFit.contain,
		this.hero,
		this.quarterTurns = 0,
		this.onLoadError,
		this.gaplessPlayback = false
	});

	@override
	Widget build(BuildContext context) {
		ImageProvider image = ExtendedNetworkImageProvider(
			attachment.spoiler ? context.watch<ImageboardSite>().getSpoilerImageUrl(attachment, thread: thread).toString() : attachment.thumbnailUrl.toString(),
			cache: true
		);
		if (quarterTurns != 0) {
			image = RotatingImageProvider(parent: image, quarterTurns: quarterTurns);
		}
		Widget child = ExtendedImage(
			image: image,
			width: width,
			height: height,
			fit: fit,
			gaplessPlayback: gaplessPlayback,
			loadStateChanged: (loadstate) {
				if (loadstate.extendedImageLoadState == LoadState.loading) {
					return SizedBox(
						width: width,
						height: height,
						child: Center(
							child: CupertinoActivityIndicator()
						)
					);
				}
				else if (loadstate.extendedImageLoadState == LoadState.failed) {
					onLoadError?.call(loadstate.lastException);
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
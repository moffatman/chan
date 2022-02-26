import 'dart:ui';

import 'package:chan/models/attachment.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/services/rotating_image_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:extended_image/extended_image.dart';
import 'package:provider/provider.dart';

class AttachmentSemanticLocation {
	final String _tag;
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
	final Function(Object?, StackTrace?)? onLoadError;
	final bool gaplessPlayback;

	const AttachmentThumbnail({
		required this.attachment,
		this.thread,
		this.width = 75,
		this.height = 75,
		this.fit = BoxFit.contain,
		this.hero,
		this.quarterTurns = 0,
		this.onLoadError,
		this.gaplessPlayback = false,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		final site = context.watch<ImageboardSite>();
		ImageProvider image = ExtendedNetworkImageProvider(
			attachment.spoiler ? site.getSpoilerImageUrl(attachment, thread: thread).toString() : attachment.thumbnailUrl.toString(),
			cache: true,
			headers: site.getHeaders(attachment.thumbnailUrl)
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
						child: const Center(
							child: CupertinoActivityIndicator()
						)
					);
				}
				else if (loadstate.extendedImageLoadState == LoadState.failed) {
					onLoadError?.call(loadstate.lastException, loadstate.lastStack);
					return SizedBox(
						width: width,
						height: height,
						child: const Center(
							child: Icon(CupertinoIcons.exclamationmark_triangle_fill)
						)
					);
				}
				return null;
			}
		);
		if (context.watch<EffectiveSettings>().blurThumbnails) {
			child = ClipRect(
				child: ImageFiltered(
					imageFilter: ImageFilter.blur(
						sigmaX: 7.0,
						sigmaY: 7.0
					),
					child: child
				)
			);
		}
		return (hero != null) ? Hero(
			tag: hero!,
			child: child,
			flightShuttleBuilder: (context, animation, direction, fromContext, toContext) {
				return (direction == HeroFlightDirection.push ? fromContext.widget as Hero : toContext.widget as Hero).child;
			},
		) : child;
	}
}
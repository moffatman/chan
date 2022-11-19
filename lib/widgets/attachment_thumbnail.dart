import 'dart:ui';

import 'package:chan/models/attachment.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:extended_image/extended_image.dart';
import 'package:provider/provider.dart';

class AttachmentSemanticLocation {
	final String _tag;
	AttachmentSemanticLocation({
		required Iterable<int> semanticParents,
		required Attachment attachment
	}) : _tag = '${semanticParents.join('/')}/${attachment.id}';

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
	final double? width;
	final double? height;
	final BoxFit fit;
	final Object? hero;
	final bool rotate90DegreesClockwise;
	final Function(Object?, StackTrace?)? onLoadError;
	final Alignment alignment;
	final bool gaplessPlayback;
	final bool revealSpoilers;
	final ImageboardSite? site;
	final bool shrinkHeight;
	final bool shrinkBoth;

	const AttachmentThumbnail({
		required this.attachment,
		this.thread,
		this.width,
		this.height,
		this.fit = BoxFit.contain,
		this.alignment = Alignment.center,
		this.hero,
		this.rotate90DegreesClockwise = false,
		this.onLoadError,
		this.gaplessPlayback = false,
		this.revealSpoilers = false,
		this.shrinkHeight = false,
		this.shrinkBoth = false,
		this.site,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<EffectiveSettings>();
		final spoiler = attachment.spoiler && !revealSpoilers;
		double effectiveWidth = width ?? settings.thumbnailSize;
		double effectiveHeight = height ?? settings.thumbnailSize;
		if (!spoiler) {
			if (shrinkBoth) {
				final size = attachment.estimateFittedSize(size: Size(effectiveWidth, effectiveHeight));
				effectiveWidth = size.width;
				effectiveHeight = size.height;
			}
			else if (shrinkHeight) {
				effectiveHeight = attachment.estimateFittedSize(size: Size(effectiveWidth, effectiveHeight)).height;
			}
		}
		final s = site ?? context.watch<ImageboardSite?>();
		if (s == null) {
			return SizedBox(
				width: effectiveWidth,
				height: effectiveHeight,
				child: const Center(
					child: Icon(CupertinoIcons.exclamationmark_triangle_fill)
				)
			);
		}
		String url = spoiler ? s.getSpoilerImageUrl(attachment, thread: thread).toString() : attachment.thumbnailUrl.toString();
		if (url.endsWith('.jp')) {
			// Sometimes 4plebs has strange thumbnails which are blocked from hotlinking, just fallback to the full image
			if (attachment.ext != '.webm' && ((attachment.sizeInBytes ?? 0) < 300000) || settings.connectivity == ConnectivityResult.wifi) {
				// Only use the full-res image if less than 300 KB or we are on Wi-Fi
				url = attachment.url.toString();
			}
		}
		ImageProvider image = ExtendedNetworkImageProvider(
			url,
			cache: true,
			headers: s.getHeaders(attachment.thumbnailUrl)
		);
		Widget child = ExtendedImage(
			image: image,
			width: effectiveWidth,
			height: effectiveHeight,
			fit: fit,
			alignment: alignment,
			gaplessPlayback: gaplessPlayback,
			rotate90DegreesClockwise: rotate90DegreesClockwise,
			//filterQuality: FilterQuality.high,
			loadStateChanged: (loadstate) {
				if (loadstate.extendedImageLoadState == LoadState.loading) {
					return SizedBox(
						width: effectiveWidth,
						height: effectiveHeight,
						child: const Center(
							child: CupertinoActivityIndicator()
						)
					);
				}
				else if (loadstate.extendedImageLoadState == LoadState.failed) {
					onLoadError?.call(loadstate.lastException, loadstate.lastStack);
					return SizedBox(
						width: effectiveWidth,
						height: effectiveHeight,
						child: const Center(
							child: Icon(CupertinoIcons.exclamationmark_triangle_fill)
						)
					);
				}
				return null;
			}
		);
		if (settings.blurThumbnails) {
			child = ClipRect(
				child: ImageFiltered(
					imageFilter: ImageFilter.blur(
						sigmaX: 7.0,
						sigmaY: 7.0,
						tileMode: TileMode.decal
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
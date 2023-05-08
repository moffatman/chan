import 'dart:math';
import 'dart:ui';

import 'package:chan/models/attachment.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/apple.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/attachment_viewer.dart';
import 'package:flutter/cupertino.dart';
import 'package:extended_image/extended_image.dart';
import 'package:provider/provider.dart';

class TaggedAttachment {
	final Attachment attachment;
	final Iterable<int> semanticParentIds;
	final String _tag;
	TaggedAttachment({
		required this.attachment,
		required this.semanticParentIds
	}) : _tag = '${semanticParentIds.join('/')}/${attachment.id}';

	@override
	bool operator == (Object other) {
		if (identical(this, other)) {
			return true;
		}
		return (other is TaggedAttachment) && _tag == other._tag;
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
	final bool shrinkWidth;

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
		this.shrinkWidth = false,
		this.site,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<EffectiveSettings>();
		final spoiler = attachment.spoiler && !revealSpoilers;
		double effectiveWidth = width ?? settings.thumbnailSize;
		double effectiveHeight = height ?? settings.thumbnailSize;
		if (rotate90DegreesClockwise) {
			final tmp = effectiveWidth;
			effectiveWidth = effectiveHeight;
			effectiveHeight = tmp;
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
		String url = attachment.thumbnailUrl;
		if (context.select<EffectiveSettings, bool>((s) => s.fullQualityThumbnails) && attachment.type == AttachmentType.image && !attachment.isRateLimited) {
			url = attachment.url;
		}
		if (spoiler && !settings.alwaysShowSpoilers) {
			url = s.getSpoilerImageUrl(attachment, thread: thread).toString();
		}
		ImageProvider image = ExtendedNetworkImageProvider(
			url,
			cache: true,
			headers: {
				...s.getHeaders(Uri.parse(url)) ?? {},
				if (attachment.useRandomUseragent) 'user-agent': makeRandomUserAgent()
			}
		);
		Widget child; 
		if (settings.loadThumbnails) {
			child = ExtendedImage(
				image: image,
				constraints: BoxConstraints(
					maxWidth: effectiveWidth,
					maxHeight: effectiveHeight
				),
				width: shrinkWidth ? null : effectiveWidth,
				height: shrinkHeight ? null : effectiveHeight,
				color: const Color.fromRGBO(238, 242, 255, 1),
				colorBlendMode: BlendMode.dstOver,
				fit: fit,
				alignment: alignment,
				key: gaplessPlayback ? null : ValueKey(url),
				gaplessPlayback: true,
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
					else if (loadstate.extendedImageLoadState == LoadState.failed ||
						(((loadstate.extendedImageInfo?.image.height ?? 0) < 5) && ((loadstate.extendedImageInfo?.image.width ?? 0) < 5))) {
						if (loadstate.extendedImageLoadState == LoadState.failed) {
							onLoadError?.call(loadstate.lastException, loadstate.lastStack);
						}
						return Container(
							width: effectiveWidth,
							height: effectiveHeight,
							color: settings.theme.barColor,
							child: Center(
								child: Icon(attachment.type == AttachmentType.url ? CupertinoIcons.compass : CupertinoIcons.exclamationmark_triangle_fill, size: max(24, 0.5 * min(effectiveWidth, effectiveHeight)))
							)
						);
					}
					else if (loadstate.extendedImageLoadState == LoadState.completed) {
						attachment.width ??= loadstate.extendedImageInfo?.image.width;
						attachment.height ??= loadstate.extendedImageInfo?.image.height;
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
		}
		else {
			child = Container(
				width: effectiveWidth,
				height: effectiveHeight,
				color: settings.theme.barColor,
				child: Center(
					child: Icon(
						(attachment.type == AttachmentType.url || attachment.type == AttachmentType.pdf) ?
							CupertinoIcons.compass :
							(attachment.isVideoOrGif || attachment.type == AttachmentType.mp3) ?
								CupertinoIcons.play_arrow_solid : CupertinoIcons.photo,
						size: max(24, 0.5 * min(effectiveWidth, effectiveHeight))
					)
				)
			);
		}
		return (hero != null) ? Hero(
			tag: hero!,
			child: child,
			flightShuttleBuilder: (context, animation, direction, fromContext, toContext) {
				return (direction == HeroFlightDirection.push ? fromContext.widget as Hero : toContext.widget as Hero).child;
			},
			createRectTween: (startRect, endRect) {
				if (startRect != null && endRect != null) {
					if (attachment.type == AttachmentType.image) {
						// Need to deflate the original startRect because it has inbuilt layoutInsets
						// This AttachmentThumbnail will always fill its size
						final rootPadding = MediaQueryData.fromView(View.of(context)).padding - sumAdditionalSafeAreaInsets();
						startRect = rootPadding.deflateRect(startRect);
					}
					if (fit == BoxFit.cover && attachment.width != null && attachment.height != null) {
						// This is AttachmentViewer -> AttachmentThumbnail (cover)
						// Need to shrink the startRect, so it only contains the image
						final fittedStartSize = applyBoxFit(BoxFit.contain, Size(attachment.width!.toDouble(), attachment.height!.toDouble()), startRect.size).destination;
						startRect = Alignment.center.inscribe(fittedStartSize, startRect);
					}
				}
				return CurvedRectTween(curve: Curves.ease, begin: startRect, end: endRect);
			}
		) : child;
	}
}
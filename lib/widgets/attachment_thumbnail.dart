import 'dart:math';
import 'dart:ui';

import 'package:chan/models/attachment.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/apple.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/attachment_viewer.dart';
import 'package:flutter/cupertino.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TaggedAttachment {
	final Attachment attachment;
	final Iterable<int> semanticParentIds;
	final String _tag;
	TaggedAttachment({
		required this.attachment,
		required this.semanticParentIds
	}) : _tag = '${semanticParentIds.join('/')}/${attachment.id}/${attachment.inlineWithinPostId}';

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
	final bool? overrideFullQuality;
	/// Whether it is actually a thumbnail (preview) like in catalog/thread
	final bool mayObscure;
	final ({Color backgroundColor, Color borderColor, double? size})? showIconInCorner;
	final double heroScale;

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
		this.site,
		this.overrideFullQuality,
		this.showIconInCorner,
		required this.mayObscure,
		this.heroScale = 1.0,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<Settings>();
		final spoiler = attachment.spoiler && !revealSpoilers;
		double effectiveWidth = width ?? settings.thumbnailSize;
		double effectiveHeight = height ?? settings.thumbnailSize;
		if (shrinkHeight && fit == BoxFit.contain && attachment.width != null && attachment.height != null) {
			if (attachment.aspectRatio > 1) {
				effectiveHeight = effectiveWidth / attachment.aspectRatio;
			}
		}
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
		bool resize = false;
		String url = attachment.thumbnailUrl;
		if ((overrideFullQuality ?? (settings.fullQualityThumbnails && !attachment.isRateLimited)) && attachment.type == AttachmentType.image) {
			resize = true;
			url = attachment.url;
		}
		if (spoiler && !settings.alwaysShowSpoilers) {
			url = s.getSpoilerImageUrl(attachment, thread: thread)?.toString() ?? '';
		}
		if (url.isEmpty) {
			return SizedBox(
				width: effectiveWidth,
				height: effectiveHeight,
				child: Center(
					child: Icon(attachment.icon ?? Adaptive.icons.photo, size: max(24, 0.5 * min(effectiveWidth, effectiveHeight)))
				)
			);
		}
		ImageProvider image = ExtendedNetworkImageProvider(
			url,
			cache: true,
			headers: {
				...s.getHeaders(Uri.parse(url)),
				if (attachment.useRandomUseragent) 'user-agent': makeRandomUserAgent()
			}
		);
		final pixelation = settings.thumbnailPixelation;
		final FilterQuality filterQuality;
		if (pixelation > 0 && mayObscure) {
			filterQuality = FilterQuality.none;
			// In BoxFit.cover we see the shortest side
			final targetLongestSide = fit != BoxFit.cover;
			// maintain minimum pixels on shortest side
			final targetHeight = (targetLongestSide && (attachment.aspectRatio < 1)) || 
													 (!targetLongestSide && (attachment.aspectRatio > 1));
			image = ExtendedResizeImage(
				image,
				maxBytes: null,
				width: targetHeight ? null : pixelation,
				height: targetHeight ? pixelation : null,
			);
		}
		else if (resize && effectiveWidth.isFinite && effectiveHeight.isFinite) {
			filterQuality = FilterQuality.low;
			image = ExtendedResizeImage(
				image,
				maxBytes: 800 << 10,
				width: overrideFullQuality == true ? null : (effectiveWidth * MediaQuery.devicePixelRatioOf(context)).ceil()
			);
		}
		else {
			filterQuality = FilterQuality.low;
		}
		final barColor = ChanceTheme.barColorOf(context);
		Widget child;
		if (settings.loadThumbnails) {
			final primaryColor = ChanceTheme.primaryColorOf(context);
			child = ExtendedImage(
				image: image,
				constraints: BoxConstraints(
					maxWidth: effectiveWidth,
					maxHeight: effectiveHeight
				),
				width: effectiveWidth,
				height: shrinkHeight ? null : effectiveHeight,
				color: const Color.fromRGBO(238, 242, 255, 1),
				colorBlendMode: BlendMode.dstOver,
				fit: fit,
				alignment: alignment,
				key: gaplessPlayback ? null : ValueKey(url),
				gaplessPlayback: true,
				rotate90DegreesClockwise: rotate90DegreesClockwise,
				afterPaintImage: showIconInCorner == null || attachment.icon == null ? null : (canvas, rect, image, paint) {
					final icon = attachment.icon;
					if (icon == null) {
						return;
					}
					final fontSize = showIconInCorner?.size ?? 16;
					TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
					textPainter.text = TextSpan(
						text: String.fromCharCode(icon.codePoint),
						style: TextStyle(
							fontSize: fontSize,
							fontFamily: icon.fontFamily,
							color: primaryColor,
							package: icon.fontPackage
						)
					);
					textPainter.layout();
					final badgeSize = EdgeInsets.all(fontSize / 8).inflateSize(Size.square(textPainter.size.longestSide));
					final badgeRect = (rect.bottomRight - (Offset.zero & badgeSize).bottomRight) & badgeSize;
					final rrect = RRect.fromRectAndCorners(
						badgeRect,
						topLeft: Radius.circular(fontSize * 0.375)
					);
					canvas.drawRRect(rrect, Paint()
						..color = showIconInCorner!.backgroundColor
						..style = PaintingStyle.fill);
					canvas.drawRRect(rrect, Paint()
						..strokeWidth = 1
						..color = showIconInCorner!.borderColor
						..style = PaintingStyle.stroke);
					textPainter.paint(canvas, Alignment.center.inscribe(textPainter.size, badgeRect).topLeft + const Offset(1, 1));
				},
				filterQuality: filterQuality,
				loadStateChanged: (loadstate) {
					if (loadstate.extendedImageLoadState == LoadState.loading) {
						return Container(
							width: effectiveWidth,
							height: effectiveHeight,
							color: barColor,
							child: const Center(
								child: CircularProgressIndicator.adaptive()
							)
						);
					}
					else if (
						// Image loading failed
						loadstate.extendedImageLoadState == LoadState.failed ||
						(
							// The real image dimensions were 1x1 (thumbnailer-failed placeholder)
							pixelation != 1 &&
							(loadstate.extendedImageInfo?.image.height ?? 0) == 1) &&
							((loadstate.extendedImageInfo?.image.width ?? 0) == 1)
						) {
						if (loadstate.extendedImageLoadState == LoadState.failed) {
							onLoadError?.call(loadstate.lastException, loadstate.lastStack);
						}
						return Container(
							width: effectiveWidth,
							height: effectiveHeight,
							color: barColor,
							child: Center(
								child: Icon((loadstate.extendedImageLoadState == LoadState.failed && url.isNotEmpty ? CupertinoIcons.exclamationmark_triangle_fill : (attachment.icon ?? Adaptive.icons.photo)), size: max(24, 0.5 * min(effectiveWidth, effectiveHeight)))
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
			if (settings.blurThumbnails && mayObscure) {
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
				color: barColor,
				child: Center(
					child: Icon(
						attachment.icon ?? Adaptive.icons.photo,
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
					endRect = Rect.fromLTWH(endRect.left, endRect.top, endRect.width * heroScale, endRect.height * heroScale);
				}
				return CurvedRectTween(curve: Curves.ease, begin: startRect, end: endRect);
			}
		) : child;
	}
}
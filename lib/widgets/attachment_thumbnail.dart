import 'dart:math';
import 'dart:ui';

import 'package:chan/models/attachment.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/apple.dart';
import 'package:chan/services/attachment_cache.dart';
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

class AttachmentThumbnailCornerIcon {
	final Color backgroundColor;
	final Color borderColor;
	final double? size;
	final TextSpan? appendText;
	final Alignment alignment;

	const AttachmentThumbnailCornerIcon({
		required this.backgroundColor,
		required this.borderColor,
		this.size,
		this.appendText,
		this.alignment = Alignment.bottomRight
	});
}

typedef _AfterPaintKey = (Attachment, AttachmentThumbnailCornerIcon);
typedef _AfterPaint = void Function(Canvas canvas, Rect rect);
typedef _KeyedAfterPaint = ({_AfterPaintKey key, _AfterPaint afterPaint});

_KeyedAfterPaint? _makeKeyedAfterPaint({
	required Attachment attachment,
	required AttachmentThumbnailCornerIcon? cornerIcon,
	required IconData? alreadyShowingBigIcon,
	required Color primaryColor
}) {
	if (cornerIcon == null || ((attachment.icon == null || attachment.icon == alreadyShowingBigIcon) && cornerIcon.appendText == null)) {
		return null;
	}
	return (
		key: (attachment, cornerIcon),
		afterPaint: (canvas, rect) {
			final icon = attachment.icon;
			final appendText = cornerIcon.appendText;
			if ((icon == null || icon == alreadyShowingBigIcon) && appendText == null) {
				// Nothing to draw
				return;
			}
			final fontSize = cornerIcon.size ?? 16;
			TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
			textPainter.text = TextSpan(
				children: [
					if (icon != null && icon != alreadyShowingBigIcon) TextSpan(
						text: String.fromCharCode(icon.codePoint),
						style: TextStyle(
							fontSize: fontSize,
							fontFamily: icon.fontFamily,
							color: primaryColor,
							package: icon.fontPackage
						)
					),
					if (icon != null && appendText != null) const TextSpan(text: ' '),
					if (appendText != null) appendText
				]
			);
			textPainter.layout();
			final badgeSize = EdgeInsets.all(fontSize / 4).inflateSize(textPainter.size);
			final badgeRect = cornerIcon.alignment.inscribe(badgeSize, rect);
			final rrect = RRect.fromRectAndCorners(
				badgeRect,
				topLeft: cornerIcon.alignment == Alignment.bottomRight ? Radius.circular(fontSize * 0.375) : Radius.zero,
				topRight: cornerIcon.alignment == Alignment.bottomLeft ? Radius.circular(fontSize * 0.375) : Radius.zero,
				bottomLeft: cornerIcon.alignment == Alignment.topRight ? Radius.circular(fontSize * 0.375) : Radius.zero,
				bottomRight: cornerIcon.alignment == Alignment.topLeft ? Radius.circular(fontSize * 0.375) : Radius.zero
			);
			canvas.drawRRect(rrect, Paint()
				..color = cornerIcon.backgroundColor
				..style = PaintingStyle.fill);
			canvas.drawRRect(rrect, Paint()
				..strokeWidth = 1
				..color = cornerIcon.borderColor
				..style = PaintingStyle.stroke);
			textPainter.paint(canvas, Alignment.center.inscribe(textPainter.size, badgeRect).topLeft + const Offset(1, 1));
		}
	);
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
	final AttachmentThumbnailCornerIcon? cornerIcon;
	final bool expand;

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
		this.cornerIcon,
		this.expand = false,
		required this.mayObscure,
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
		final primaryColor = ChanceTheme.primaryColorOf(context);
		final cornerIcon = this.cornerIcon;
		_KeyedAfterPaint? makeAfterPaint({IconData? alreadyShowingBigIcon}) =>
			_makeKeyedAfterPaint(attachment: attachment, cornerIcon: cornerIcon, alreadyShowingBigIcon: alreadyShowingBigIcon, primaryColor: primaryColor);
		Widget child;
		if (settings.loadThumbnails) {
			final afterPaint = makeAfterPaint();
			child = ExtendedImage(
				image: image,
				constraints: expand ? null : BoxConstraints(
					maxWidth: effectiveWidth,
					maxHeight: effectiveHeight
				),
				width: effectiveWidth,
				height: shrinkHeight || expand ? null : effectiveHeight,
				color: const Color.fromRGBO(238, 242, 255, 1),
				colorBlendMode: BlendMode.dstOver,
				fit: fit,
				alignment: alignment,
				key: gaplessPlayback ? null : ValueKey(url),
				gaplessPlayback: true,
				rotate90DegreesClockwise: rotate90DegreesClockwise,
				afterPaintImage: afterPaint == null ? null : (
					key: afterPaint.key,
					fn: (canvas, rect, image, paint) {
						afterPaint.afterPaint(canvas, rect);
					}
				),
				filterQuality: filterQuality,
				loadStateChanged: (loadstate) {
					if (loadstate.extendedImageLoadState == LoadState.loading) {
						return _AttachmentThumbnailPlaceholder(
							effectiveWidth: effectiveWidth,
							effectiveHeight: effectiveHeight,
							attachment: attachment,
							fit: fit,
							afterPaint: makeAfterPaint(),
							child: const CircularProgressIndicator.adaptive()
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
						final icon = loadstate.extendedImageLoadState == LoadState.failed && url.isNotEmpty ? CupertinoIcons.exclamationmark_triangle_fill : (attachment.icon ?? Adaptive.icons.photo);
						return _AttachmentThumbnailPlaceholder(
							child: null,
							icon: icon,
							effectiveWidth: effectiveWidth,
							effectiveHeight: effectiveHeight,
							attachment: attachment,
							afterPaint: makeAfterPaint(alreadyShowingBigIcon: icon),
							fit: fit
						);
					}
					else if (loadstate.extendedImageLoadState == LoadState.completed) {
						if (url == attachment.url) {
							// Thie a is a full-quality thumbnail
							AttachmentCache.onCached(attachment);
						}
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
			final icon = attachment.icon ?? Adaptive.icons.photo;
			child = _AttachmentThumbnailPlaceholder(
				child: null,
				icon: icon,
				effectiveWidth: effectiveWidth,
				effectiveHeight: effectiveHeight,
				attachment: attachment,
				afterPaint: makeAfterPaint(alreadyShowingBigIcon: icon),
				fit: fit
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

class _AttachmentThumbnailPlaceholder extends StatelessWidget {
	final Widget? child;
	final IconData? icon;
	final Attachment attachment;
	final double effectiveWidth;
	final double effectiveHeight;
	final BoxFit fit;
	final _KeyedAfterPaint? afterPaint;

	const _AttachmentThumbnailPlaceholder({
		required this.child,
		this.icon,
		required this.attachment,
		required this.effectiveWidth,
		required this.effectiveHeight,
		required this.fit,
		required this.afterPaint
	});

	@override
	Widget build(BuildContext context) {
		final theme = context.watch<SavedTheme>();
		return CustomSingleChildLayout(
			delegate: _AttachmentThumbnailPlaceholderLayoutDelegate(
				attachment: attachment,
				effectiveWidth: effectiveWidth,
				effectiveHeight: effectiveHeight,
				fit: fit
			),
			child: CustomPaint(
				foregroundPainter: _AttachmentThumbnailPlaceholderAfterPaintCustomPainter(afterPaint),
				child: DecoratedBox(
					decoration: BoxDecoration(
						color: theme.barColor
					),
					child: Center(
						child: switch (icon) {
							IconData icon => CustomPaint(
								painter: _AttachmentThumbnailPlaceholderIconCustomPainter(
									icon: icon,
									color: theme.primaryColor
								),
								child: const SizedBox.expand()
							),
							null => child
						}
					)
				)
			)
		);
	}
}

class _AttachmentThumbnailPlaceholderLayoutDelegate extends SingleChildLayoutDelegate {
	final BoxFit fit;
	final double effectiveWidth;
	final double effectiveHeight;
	final Attachment attachment;

	const _AttachmentThumbnailPlaceholderLayoutDelegate({
		required this.fit,
		required this.effectiveWidth,
		required this.effectiveHeight,
		required this.attachment
	});

	Size _getChildSize(BoxConstraints constraints) {
		return applyBoxFit(fit, Size(attachment.width?.toDouble() ?? effectiveWidth, attachment.height?.toDouble() ?? effectiveHeight), constraints.biggest).destination;
	}

	@override
	Size getSize(BoxConstraints constraints) {
		return _getChildSize(constraints);
	}

	@override
	BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
		return BoxConstraints.tight(_getChildSize(constraints));
	}

	@override
	Offset getPositionForChild(Size size, Size childSize) {
		return Alignment.center.inscribe(childSize, Offset.zero & size).topLeft;
	}

	@override
	bool shouldRelayout(_AttachmentThumbnailPlaceholderLayoutDelegate oldDelegate) {
		return
			oldDelegate.fit != fit ||
			oldDelegate.effectiveWidth != effectiveWidth ||
			oldDelegate.effectiveHeight != effectiveHeight ||
			oldDelegate.attachment != attachment;
	}
}

class _AttachmentThumbnailPlaceholderIconCustomPainter extends CustomPainter {
	final IconData icon;
	final Color color;

	const _AttachmentThumbnailPlaceholderIconCustomPainter({
		required this.icon,
		required this.color
	});

	@override
	void paint(Canvas canvas, Size size) {
		final fontSize = (0.5 * size.shortestSide).clamp(24.0, 100.0);
		TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
		textPainter.text = TextSpan(
			text: String.fromCharCode(icon.codePoint),
			style: TextStyle(
				fontSize: fontSize,
				fontFamily: icon.fontFamily,
				color: color,
				package: icon.fontPackage
			)
		);
		textPainter.layout();
		textPainter.paint(canvas, Alignment.center.inscribe(textPainter.size, Offset.zero & size).topLeft);
	}

	@override
	bool shouldRepaint(_AttachmentThumbnailPlaceholderIconCustomPainter oldDelegate) {
		return oldDelegate.icon != icon;
	}
}

class _AttachmentThumbnailPlaceholderAfterPaintCustomPainter extends CustomPainter {
	final _KeyedAfterPaint? afterPaint;

	const _AttachmentThumbnailPlaceholderAfterPaintCustomPainter(this.afterPaint);

	@override
	bool shouldRepaint(_AttachmentThumbnailPlaceholderAfterPaintCustomPainter oldDelegate) {
		return oldDelegate.afterPaint?.key != afterPaint?.key;
	}
	
	@override
	void paint(Canvas canvas, Size size) {
		afterPaint?.afterPaint.call(canvas, Offset.zero & size);
	}
}

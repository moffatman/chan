import 'package:chan/models/attachment.dart';
import 'package:chan/services/rotating_image_provider.dart';
import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:extended_image_library/extended_image_library.dart';

class GalleryImageViewer extends StatelessWidget {
	final Uri url;
	final Attachment attachment;
	final Object? tag;
	final ValueChanged<File>? onCacheCompleted;
	final bool isThumbnail;
	final int quarterTurns;

	GalleryImageViewer({
		required this.url,
		required this.attachment,
		this.tag,
		this.onCacheCompleted,
		this.quarterTurns = 0,
		this.isThumbnail = false
	});

	@override
	Widget build(BuildContext context) {
		ImageProvider image = ExtendedNetworkImageProvider(
			url.toString(),
			cache: true
		);
		if (quarterTurns != 0) {
			image = RotatingImageProvider(parent: image, quarterTurns: quarterTurns);
		}
		return ExtendedImage(
			image: image,
			enableSlideOutPage: true,
			gaplessPlayback: true,
			fit: BoxFit.contain,
			mode: ExtendedImageMode.gesture,
			width: double.infinity,
			height: double.infinity,
			onDoubleTap: (state) {
				final old = state.gestureDetails!;
				state.gestureDetails = GestureDetails(
					offset: state.pointerDownPosition!.scale(old.layoutRect!.width / MediaQuery.of(context).size.width, old.layoutRect!.height / MediaQuery.of(context).size.height) * -1,
					totalScale: (old.totalScale ?? 1) > 1 ? 1 : 2,
					actionType: ActionType.zoom
				);
			},
			loadStateChanged: (loadstate) {
				if (loadstate.extendedImageLoadState == LoadState.completed && !isThumbnail) {
					getCachedImageFile(url.toString()).then((file) {
						if (file != null) {
							onCacheCompleted?.call(file);
						}
					});
					return null;
				}
			},
			initGestureConfigHandler: (state) {
				return GestureConfig(
					inPageView: true
				);
			},
			heroBuilderForSlidingPage: (Widget result) {
				return Hero(
					tag: tag ?? attachment,
					child: result,
					flightShuttleBuilder: (ctx, animation, direction, from, to) {
						return (direction == HeroFlightDirection.pop) ? from.widget : to.widget;
					}
				);
			}
		);
	}
}
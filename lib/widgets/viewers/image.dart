import 'package:chan/models/attachment.dart';
import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:extended_image_library/extended_image_library.dart';

class GalleryImageViewer extends StatelessWidget {
	final Uri url;
	final Attachment attachment;
	final Object? tag;
	final ValueChanged<File>? onCacheCompleted;
	final bool isThumbnail;

	GalleryImageViewer({
		required this.url,
		required this.attachment,
		this.tag,
		this.onCacheCompleted,
		this.isThumbnail = false
	});

	@override
	Widget build(BuildContext context) {
		return ExtendedImage.network(
			url.toString(),
			enableSlideOutPage: true,
			gaplessPlayback: true,
			cache: true,
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
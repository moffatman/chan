import 'package:chan/models/attachment.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:extended_image/extended_image.dart';

class ImageViewer extends StatelessWidget {
	final Uri url;
	final Attachment attachment;
	final bool allowZoom;
	final Object? tag;

	ImageViewer({
		required this.url,
		required this.attachment,
		this.allowZoom = true,
		this.tag
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
				print(old.offset);
				state.gestureDetails = GestureDetails(
					offset: old.offset,
					totalScale: old.totalScale > 1 ? 1 : 2,
					actionType: ActionType.zoom
				);
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
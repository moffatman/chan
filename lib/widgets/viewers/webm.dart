import 'package:chan/models/attachment.dart';
import 'package:chan/pages/gallery.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:extended_image/extended_image.dart';

class GalleryWEBMViewer extends StatelessWidget {
	final Attachment attachment;
	final AttachmentVideoAvailableStatus status;
	final Color backgroundColor;
	final Object? tag;

	GalleryWEBMViewer({
		required this.attachment,
		required this.status,
		this.backgroundColor = Colors.black,
		this.tag
	});

	Widget build(BuildContext context) {
		return ExtendedImageSlidePageHandler(
			heroBuilderForSlidingPage: (Widget result) {
				return Hero(
					tag: tag ?? attachment,
					child: result
				);
			},
			child: Center(
				child: AspectRatio(
					aspectRatio: status.controller.value.aspectRatio,
					child: VideoPlayer(status.controller)
				)
			)
		);
	}
}
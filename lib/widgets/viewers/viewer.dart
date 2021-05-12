import 'dart:io';

import 'package:chan/models/attachment.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/circular_loading_indicator.dart';
import 'package:chan/widgets/util.dart';
import 'package:chan/widgets/viewers/image.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class AttachmentViewer extends StatelessWidget {
	final Attachment attachment;
	final AttachmentStatus status;
	final Color backgroundColor;
	final Object? tag;
	final ValueChanged<File>? onCacheCompleted;
	final bool autoRotate;

	AttachmentViewer({
		required this.attachment,
		required this.status,
		this.backgroundColor = Colors.black,
		this.tag,
		this.onCacheCompleted,
		this.autoRotate = false,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		int quarterTurns = 0;
		final displayIsLandscape = MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;
		if (autoRotate && (((attachment.isLandscape ?? false) && !displayIsLandscape) || (!(attachment.isLandscape ?? true) && displayIsLandscape))) {
			quarterTurns = 1;
		}
		if (attachment.type == AttachmentType.Image && (status is AttachmentImageUrlAvailableStatus || status is AttachmentLoadingStatus)) {
			return GalleryImageViewer(
				attachment: attachment,
				quarterTurns: quarterTurns,
				url: (status is AttachmentImageUrlAvailableStatus) ? (status as AttachmentImageUrlAvailableStatus).url : attachment.thumbnailUrl,
				onCacheCompleted: onCacheCompleted,
				isThumbnail: !(status is AttachmentImageUrlAvailableStatus),
				tag: tag
			);
		}
		else {
			return ExtendedImageSlidePageHandler(
				heroBuilderForSlidingPage: (Widget result) {
					return Hero(
						tag: tag ?? attachment,
						child: result
					);
				},
				child: Stack(
					children: [
						AttachmentThumbnail(
							attachment: attachment,
							width: double.infinity,
							height: double.infinity,
							quarterTurns: quarterTurns
						),
						if (status is AttachmentUnavailableStatus) Center(
							child: ErrorMessageCard((status as AttachmentUnavailableStatus).cause)
						)
						else if (status is AttachmentLoadingStatus) Center(
							child: CircularLoadingIndicator(value: (status as AttachmentLoadingStatus).progress)
						)
						else if (status is AttachmentVideoAvailableStatus) Center(
							child: RotatedBox(
								quarterTurns: quarterTurns,
								child: AspectRatio(
									aspectRatio: (status as AttachmentVideoAvailableStatus).controller.value.aspectRatio,
									child: VideoPlayer((status as AttachmentVideoAvailableStatus).controller)
								)
							)
						)
					]
				)
			);
		}
	}
}
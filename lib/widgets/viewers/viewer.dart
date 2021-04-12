import 'dart:io';

import 'package:chan/models/attachment.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/circular_loading_indicator.dart';
import 'package:chan/widgets/util.dart';
import 'package:chan/widgets/viewers/image.dart';
import 'package:chan/widgets/viewers/webm.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AttachmentViewer extends StatelessWidget {
	final Attachment attachment;
	final AttachmentStatus status;
	final Color backgroundColor;
	final Object? tag;
	final ValueChanged<File>? onCacheCompleted;

	AttachmentViewer({
		required this.attachment,
		required this.status,
		this.backgroundColor = Colors.black,
		this.tag,
		this.onCacheCompleted,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		if (status is AttachmentVideoAvailableStatus) {
			return GalleryWEBMViewer(
				attachment: attachment,
				status: status as AttachmentVideoAvailableStatus,
				tag: tag
			);
		}
		else if (status is AttachmentImageUrlAvailableStatus) {
			return GalleryImageViewer(
				attachment: attachment,
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
							height: double.infinity
						),
						if (status is AttachmentUnavailableStatus) Center(
							child: ErrorMessageCard((status as AttachmentUnavailableStatus).cause)
						)
						else if (status is AttachmentLoadingStatus) Center(
							child: CircularLoadingIndicator(value: (status as AttachmentLoadingStatus).progress)
						)
					]
				)
			);
		}
	}
}
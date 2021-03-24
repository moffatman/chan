import 'dart:io';

import 'package:chan/models/attachment.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/viewers/image.dart';
import 'package:chan/widgets/viewers/webm.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AttachmentViewer extends StatelessWidget {
	final Attachment attachment;
	final AttachmentStatus status;
	final Color backgroundColor;
	final bool autoload;
	final Object? tag;
	final ValueChanged<File>? onCacheCompleted;

	AttachmentViewer({
		required this.attachment,
		required this.status,
		this.backgroundColor = Colors.black,
		this.autoload = false,
		this.tag,
		this.onCacheCompleted,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return Stack(
			children: [
				if (status is AttachmentVideoAvailableStatus) GalleryWEBMViewer(
					attachment: attachment,
					status: status as AttachmentVideoAvailableStatus
				)
				else GalleryImageViewer(
					attachment: attachment,
					url: (status is AttachmentImageUrlAvailableStatus) ? (status as AttachmentImageUrlAvailableStatus).url : context.watch<ImageboardSite>().getAttachmentThumbnailUrl(attachment),
					tag: tag,
					onCacheCompleted: onCacheCompleted,
					isThumbnail: !(status is AttachmentImageUrlAvailableStatus)
				),
				if (status is AttachmentUnavailableStatus) Center(
					child: Container(
						padding: EdgeInsets.all(16),
						decoration: BoxDecoration(
							color: CupertinoTheme.of(context).scaffoldBackgroundColor,
							borderRadius: BorderRadius.all(Radius.circular(8))
						),
						child: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								Icon(Icons.error),
								Text((status as AttachmentUnavailableStatus).cause, style: TextStyle(color: CupertinoTheme.of(context).primaryColor))
							]
						)
					)
				)
				else if (status is AttachmentLoadingStatus)
					Center(
						child: CircularProgressIndicator(value: (status as AttachmentLoadingStatus).progress)
					)
			]
		);
	}
}
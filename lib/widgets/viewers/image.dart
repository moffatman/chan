import 'package:cached_network_image/cached_network_image.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class ImageViewer extends StatelessWidget {
	final Uri url;
	final Attachment attachment;
	final ValueChanged<bool>? onDeepInteraction;
	final Color backgroundColor;
	final bool allowZoom;

	ImageViewer({
		required this.url,
		required this.attachment,
		this.onDeepInteraction,
		this.backgroundColor = Colors.black,
		this.allowZoom = true
	});

	@override
	Widget build(BuildContext context) {
		return PhotoView(
			gaplessPlayback: true,
			disableGestures: !allowZoom,
			backgroundDecoration: BoxDecoration(color: backgroundColor),
			imageProvider: NetworkImage(url.toString()),
			minScale: PhotoViewComputedScale.contained,
			heroAttributes: PhotoViewHeroAttributes(
				tag: attachment
			),
			scaleStateChangedCallback: (state) {
				onDeepInteraction?.call(state != PhotoViewScaleState.initial);
			},
			loadingBuilder: (context, imageChunkEvent) {
				return Stack(
					children: [
						AttachmentThumbnail(
							attachment: attachment,
							fit: BoxFit.contain,
							width: double.infinity,
							height: double.infinity,
							hero: false
						),
						Center(
							child: CircularProgressIndicator(
								value: imageChunkEvent.expectedTotalBytes == null ? null : imageChunkEvent.cumulativeBytesLoaded / imageChunkEvent.expectedTotalBytes!
							)
						)
					]
				);
			}
		);
	}
}
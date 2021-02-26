import 'package:chan/models/attachment.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class ImageViewer extends StatelessWidget {
	final Uri url;
	final Attachment attachment;
	final ValueChanged<bool>? onDeepInteraction;
	final Color backgroundColor;

	ImageViewer({
		required this.url,
		required this.attachment,
		this.onDeepInteraction,
		this.backgroundColor = Colors.black
	});

	@override
	Widget build(BuildContext context) {
		return PhotoView(
			backgroundDecoration: BoxDecoration(color: backgroundColor),
			imageProvider: NetworkImage(url.toString()),
			minScale: PhotoViewComputedScale.contained,
			scaleStateChangedCallback: (state) {
				print(state);
				if (onDeepInteraction != null) {
					onDeepInteraction?.call(state != PhotoViewScaleState.initial);
				}
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
							child: CircularProgressIndicator()
						)
					]
				);
			}
		);
	}
}
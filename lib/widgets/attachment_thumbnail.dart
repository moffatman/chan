import 'package:chan/models/attachment.dart';
import 'package:chan/services/util.dart';
import 'package:chan/widgets/chan_site.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AttachmentThumbnail extends StatelessWidget {
	final Attachment attachment;
	final double width;
	final double height;
	final BoxFit fit;
	AttachmentThumbnail({
		@required this.attachment,
		this.width = 75,
		this.height = 75,
		this.fit = BoxFit.cover
	});

	@override
	Widget build(BuildContext context) {
		final url = ChanSite.of(context).provider.getAttachmentThumbnailUrl(attachment).toString();
		if (isDesktop()) {
			return Image.network(
				url,
				width: width,
				height: height,
				fit: fit,
				loadingBuilder: (context, child, loadingProgress) {
					if (loadingProgress == null) {
						return child;
					}
					return SizedBox(
						width: width,
						height: height,
						child: Center(
							child: CircularProgressIndicator(
								value: (loadingProgress.expectedTotalBytes != null) ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes : null
							)
						)
					);
				}
			);
		}
		else {
			return CachedNetworkImage(
				width: width,
				height: height,
				fit: fit,
				placeholder: (BuildContext context, String url) {
					return SizedBox(
						width: width,
						height: height,
						child: Center(
							child: CircularProgressIndicator()
						)
					);
				},
				imageUrl: url
			);
		}
	}
}
import 'package:chan/models/attachment.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AttachmentThumbnail extends StatelessWidget {
  final bool isDesktop;
  final Attachment attachment;
  final double width;
  final double height;
  AttachmentThumbnail({
    @required this.isDesktop,
    @required this.attachment,
    this.width = 75,
    this.height = 75
  });

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return Image.network(
        attachment.thumbnailUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
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
        fit: BoxFit.cover,
        placeholder: (BuildContext context, String url) {
          return SizedBox(
            width: width,
            height: height,
            child: Center(
              child: CircularProgressIndicator()
            )
          );
        },
        imageUrl: attachment.thumbnailUrl
      );
    }
  }
}
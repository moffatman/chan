import 'package:chan/models/attachment.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/services/util.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

class AttachmentThumbnail extends StatelessWidget {
	final Attachment attachment;
	final double width;
	final double height;
	final BoxFit fit;
	final bool hero;
	AttachmentThumbnail({
		required this.attachment,
		this.width = 75,
		this.height = 75,
		this.fit = BoxFit.contain,
		this.hero = true
	});

	Widget _buildDesktop(String url) {
		return Image.network(
			url,
			width: width,
			height: height,
			fit: fit,
			errorBuilder: (context, exception, stackTrace) {
				return SizedBox(
					width: width,
					height: height,
					child: Center(
						child: Icon(Icons.error)
					)
				);
			},
			loadingBuilder: (context, child, loadingProgress) {
				if (loadingProgress == null) {
					return child;
				}
				return SizedBox(
					width: width,
					height: height,
					child: Center(
						child: CircularProgressIndicator(
							value: (loadingProgress.expectedTotalBytes != null) ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null
						)
					)
				);
			}
		);
	}

	Widget _buildMobile(String url) {
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

	@override
	Widget build(BuildContext context) {
		final url = context.watch<ImageboardSite>().getAttachmentThumbnailUrl(attachment).toString();
		Widget child = isDesktop() ? _buildDesktop(url) : _buildMobile(url);
		return hero ? Hero(
			tag: attachment,
			child: child,
			/*flightShuttleBuilder: (context, animation, direction, fromContext, toContext) {
				print(direction);
				return (direction == HeroFlightDirection.push ? fromContext.widget as Hero : toContext.widget as Hero).child;
			},*/
		) : child;
	}
}
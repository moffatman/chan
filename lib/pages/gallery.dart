import 'package:chan/models/attachment.dart';
import 'package:chan/widgets/attachment_gallery.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';

class GalleryPage extends StatefulWidget {
	final List<Attachment> attachments;
	final Attachment? initialAttachment;
	final bool initiallyShowChrome;
	final ValueChanged<Attachment>? onChange;

	GalleryPage({
		required this.attachments,
		required this.initialAttachment,
		this.initiallyShowChrome = false,
		this.onChange
	});

	@override
	createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
	late Attachment? lastAttachment;
	late bool showChrome;

	@override
	void initState() {
		super.initState();
		lastAttachment = widget.initialAttachment;
		showChrome = widget.initiallyShowChrome;
	}

	@override
	void didUpdateWidget(GalleryPage old) {
		super.didUpdateWidget(old);
		if (widget.initialAttachment != old.initialAttachment) {
			lastAttachment = widget.initialAttachment;
		}
	}

	@override
	Widget build(BuildContext context) {
		return ExtendedImageSlidePage(
			resetPageDuration: const Duration(milliseconds: 100),
			slidePageBackgroundHandler: (offset, size) {
				return Colors.black.withOpacity((0.38 * (1 - (offset.dx / size.width).abs()) * (1 - (offset.dy / size.height).abs())).clamp(0, 1));
			},
			child: CupertinoTheme(
				data: CupertinoThemeData(brightness: Brightness.dark, primaryColor: Colors.white),
				child: CupertinoPageScaffold(
					backgroundColor: Colors.transparent,
					navigationBar: showChrome ? CupertinoNavigationBar(
						brightness: Brightness.light,
						middle: Text('Gallery'),
						backgroundColor: Colors.black38
					) : null,
					child: AttachmentGallery(
						key: galleryKey,
						attachments: widget.attachments,
						initialAttachment: lastAttachment,
						showThumbnails: showChrome,
						onTap: (attachment) {
							setState(() {
								showChrome = !showChrome;
							});
						},
						onChange: (attachment) {
							setState(() {
								lastAttachment = attachment;
							});
							widget.onChange?.call(attachment);
						}
					)
				)
			)
		);
	}
}
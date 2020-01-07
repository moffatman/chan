import 'package:chan/models/attachment.dart';
import 'package:chan/widgets/attachment_gallery.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class GalleryPage extends StatefulWidget {
	final List<Attachment> attachments;
	final Attachment initialAttachment;

	GalleryPage({
		@required this.attachments,
		@required this.initialAttachment
	});

	@override
	createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
	Attachment lastAttachment;
	bool showChrome = false;

	@override
	void initState() {
		print('gallerypage initstate');
		super.initState();
		lastAttachment = widget.initialAttachment;
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
		print('build gallerypage');
		return Dismissible(
			direction: DismissDirection.down,
			onDismissed: (direction) {
				Navigator.of(context).pop();
			},
			key: ObjectKey('xd'),
			child: CupertinoPageScaffold(
				backgroundColor: Colors.black38,
				navigationBar: showChrome ? CupertinoNavigationBar(
					middle: const Text('Gallery'),
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
					}
				)
			)
		);
	}
}
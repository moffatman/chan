import 'package:chan/models/attachment.dart';
import 'package:chan/widgets/attachment_gallery.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
		return Dismissible(
			background: Container(
				color: Colors.black38
			),
			direction: DismissDirection.down,
			onDismissed: (direction) {
				Navigator.of(context).pop();
			},
			resizeDuration: Duration(milliseconds: 1),
			dismissThresholds: {
				DismissDirection.down: 0.1
			},
			key: ObjectKey('GalleryPage'),
			child: CupertinoPageScaffold(
				backgroundColor: Colors.black38,
				navigationBar: showChrome ? CupertinoNavigationBar(
					middle: const Text('Gallery', style: TextStyle(color: Colors.white)),
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
		);
	}
}
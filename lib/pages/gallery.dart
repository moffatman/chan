import 'dart:io';

import 'package:chan/models/attachment.dart';
import 'package:chan/widgets/attachment_gallery.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:share/share.dart';
import 'package:path_provider/path_provider.dart';

class GalleryPage extends StatefulWidget {
	final List<Attachment> attachments;
	final Attachment? initialAttachment;
	final bool initiallyShowChrome;
	final ValueChanged<Attachment>? onChange;
	final List<int> semanticParentIds;

	GalleryPage({
		required this.attachments,
		required this.initialAttachment,
		required this.semanticParentIds,
		this.initiallyShowChrome = false,
		this.onChange,
	});

	@override
	createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
	late Attachment currentAttachment;
	final Map<Attachment, File> _cachedAttachments = Map();
	late bool showChrome;
	late Key _galleryKey;

	@override
	void initState() {
		super.initState();
		currentAttachment = widget.initialAttachment ?? widget.attachments[0];
		showChrome = widget.initiallyShowChrome;
		_galleryKey = GlobalObjectKey(widget.semanticParentIds.join('/'));
	}

	@override
	void didUpdateWidget(GalleryPage old) {
		super.didUpdateWidget(old);
		if (widget.initialAttachment != old.initialAttachment) {
			currentAttachment = widget.initialAttachment ?? widget.attachments[0];
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
						middle: Text(currentAttachment.filename),
						backgroundColor: Colors.black38,
						trailing: CupertinoButton(
							padding: EdgeInsets.zero,
							child: Icon(Icons.ios_share),
							onPressed: (_cachedAttachments[currentAttachment] != null) ? () async {
								final systemTempDirectory = await getTemporaryDirectory();
								final shareDirectory = await (new Directory(systemTempDirectory.path + '/sharecache')).create(recursive: true);
								final newFilename = currentAttachment.id.toString() + currentAttachment.ext.replaceFirst('webm', 'mp4');
								final renamedFile = await _cachedAttachments[currentAttachment]!.copy(shareDirectory.path.toString() + '/' + newFilename);
								Share.shareFiles([renamedFile.path], subject: currentAttachment.filename);
							} : null
						)
					) : null,
					child: AttachmentGallery(
						key: _galleryKey,
						attachments: widget.attachments,
						semanticParentIds: widget.semanticParentIds,
						currentAttachment: currentAttachment,
						showThumbnails: showChrome,
						onTap: (attachment) {
							setState(() {
								showChrome = !showChrome;
							});
						},
						onChange: (attachment) {
							setState(() {
								currentAttachment = attachment;
							});
							widget.onChange?.call(attachment);
						},
						onCached: (attachment, file) {
							setState(() {
								_cachedAttachments[attachment] = file;
							});
						}
					)
				)
			)
		);
	}
}
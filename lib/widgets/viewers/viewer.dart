import 'dart:io';

import 'package:chan/models/attachment.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/viewers/image.dart';
import 'package:chan/widgets/viewers/webm.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum AttachmentViewerStatus {
	LowRes,
	Checking,
	CheckError,
	RealViewer
}

class AttachmentViewer extends StatefulWidget {
	final Attachment attachment;
	final Color backgroundColor;
	final bool autoload;
	final Object? tag;
	final ValueChanged<File>? onCached;

	AttachmentViewer({
		required this.attachment,
		this.backgroundColor = Colors.black,
		this.autoload = false,
		this.tag,
		this.onCached,
		Key? key
	}) : super(key: key);

	@override
	createState() => _AttachmentViewerState();
}

class _AttachmentViewerState extends State<AttachmentViewer> with AutomaticKeepAliveClientMixin {
	late AttachmentViewerStatus status;
	Uri? goodUrl;
	bool _showCheckingLoader = false;

	@override
	void initState() {
		print('attachmentviewer.initstate');
		super.initState();
		status = AttachmentViewerStatus.LowRes;
		updateKeepAlive();
	}

	@override
	void didChangeDependencies() {
		print('attachmentviewer.didchangedependencies');
		super.didChangeDependencies();
		if (status != AttachmentViewerStatus.RealViewer) {
			_updateAutoload();
		}
	}

	@override
	void didUpdateWidget(AttachmentViewer oldWidget) {
		print('attachmentviewer.didupdatewidget');
		super.didUpdateWidget(oldWidget);
		if (oldWidget.attachment != widget.attachment) {
			_updateAutoload();
		}
	}

	void _updateAutoload() {
		status = AttachmentViewerStatus.LowRes;
		if (context.read<Settings>().autoloadAttachments || widget.autoload) {
			_load();
		}
	}

	void _load() async {
		final site = context.read<ImageboardSite>();
		final url = site.getAttachmentUrl(widget.attachment);
		setState(() {
			status = AttachmentViewerStatus.Checking;
			_showCheckingLoader = false;
		});
		Future.delayed(const Duration(milliseconds: 500), () {
			if (mounted) {
				setState(() {
					_showCheckingLoader = true;
				});
			}
		});
		final result = await site.client.head(url);
		if (result.statusCode == 200 && mounted) {
			setState(() {
				goodUrl = url;
				status = AttachmentViewerStatus.RealViewer;
			});
		}
		else if (mounted) {
			setState(() {
				status = AttachmentViewerStatus.CheckError;
			});
		}
	}

	void _loadArchive() async {
		final site = context.watch<ImageboardSite>();
		final urls = site.getArchiveAttachmentUrls(widget.attachment);
		setState(() {
			status = AttachmentViewerStatus.Checking;
			_showCheckingLoader = false;
		});
		Future.delayed(const Duration(milliseconds: 500), () {
			setState(() {
				_showCheckingLoader = true;
			});
		});
		for (final url in urls) {
			final result = await site.client.head(url);
			if (result.statusCode == 200) {
				setState(() {
					goodUrl = url;
					status = AttachmentViewerStatus.RealViewer;
				});
				return;
			}
		}
		setState(() {
			status = AttachmentViewerStatus.CheckError;
		});
	}

	@override
	Widget build(BuildContext context) {
		super.build(context);
		return GestureDetector(
			child: Stack(
				children: [
					if (widget.attachment.type == AttachmentType.WEBM && status == AttachmentViewerStatus.RealViewer) Material(
						color: widget.backgroundColor,
						child: WEBMViewer(
							attachment: widget.attachment,
							url: goodUrl!,
							backgroundColor: widget.backgroundColor,
							tag: widget.tag,
							onCached: (file) => widget.onCached?.call(file)
						)
					)
					else ImageViewer(
						attachment: widget.attachment,
						url: (status == AttachmentViewerStatus.RealViewer) ? goodUrl! : context.watch<ImageboardSite>().getAttachmentThumbnailUrl(widget.attachment),
						allowZoom: status == AttachmentViewerStatus.RealViewer,
						tag: widget.tag,
						onCached: (file) {
							if (status == AttachmentViewerStatus.RealViewer) {
								widget.onCached?.call(file);
							}
						}
					),
					if (status == AttachmentViewerStatus.CheckError)
						Center(
							child: Column(
								mainAxisAlignment: MainAxisAlignment.center,
								children: [
									Icon(Icons.warning),
									Text('Error getting file'),
									ElevatedButton.icon(
										icon: Icon(Icons.history),
										label: Text('Try archive'),
										onPressed: _loadArchive
									)
								]
							)
						)
					else if (status == AttachmentViewerStatus.Checking && _showCheckingLoader)
						Center(
							child: CircularProgressIndicator()
						)
				]
			),
			onTap: (status == AttachmentViewerStatus.RealViewer) ? null : () {
				if (status == AttachmentViewerStatus.LowRes) {
					_load();
				}
			}
		);
	}

	@override
	bool get wantKeepAlive {
		return true;
	}
}
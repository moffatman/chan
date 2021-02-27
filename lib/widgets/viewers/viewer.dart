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
	final ValueChanged<bool>? onDeepInteraction;

	AttachmentViewer({
		required this.attachment,
		this.backgroundColor = Colors.black,
		this.onDeepInteraction,
		Key? key
	}) : super(key: key);

	@override
	createState() => _AttachmentViewerState();
}

class _AttachmentViewerState extends State<AttachmentViewer> with AutomaticKeepAliveClientMixin {
	late AttachmentViewerStatus status;
	Uri? goodUrl;

	@override
	void initState() {
		super.initState();
		status = AttachmentViewerStatus.LowRes;
		updateKeepAlive();
	}

	@override
	void didChangeDependencies() {
		super.didChangeDependencies();
		if (Settings.of(context).autoloadAttachments && status == AttachmentViewerStatus.LowRes) {
			_load();
		}
	}

	@override
	void didUpdateWidget(AttachmentViewer oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.attachment != widget.attachment) {
			status = AttachmentViewerStatus.LowRes;
			if (Settings.of(context).autoloadAttachments) {
				_load();
			}
		}
	}

	void _load() async {
		final site = context.watch<ImageboardSite>();
		final url = site.getAttachmentUrl(widget.attachment);
		setState(() {
			status = AttachmentViewerStatus.Checking;
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
					if (widget.attachment.type == AttachmentType.WEBM) Material(
						child: WEBMViewer(
							attachment: widget.attachment,
							url: goodUrl!,
							backgroundColor: widget.backgroundColor,
							onDeepInteraction: widget.onDeepInteraction
						)
					)
					else ImageViewer(
						attachment: widget.attachment,
						url: (status == AttachmentViewerStatus.RealViewer) ? goodUrl! : context.watch<ImageboardSite>().getAttachmentThumbnailUrl(widget.attachment),
						allowZoom: false,
						backgroundColor: widget.backgroundColor,
						onDeepInteraction: (status == AttachmentViewerStatus.RealViewer) ? widget.onDeepInteraction : null,
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
					else if (status == AttachmentViewerStatus.Checking)
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
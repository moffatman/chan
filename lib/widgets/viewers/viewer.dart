import 'package:chan/models/attachment.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/chan_site.dart';
import 'package:chan/widgets/viewers/image.dart';
import 'package:chan/widgets/viewers/webm.dart';
import 'package:flutter/material.dart';

enum AttachmentViewerStatus {
	LowRes,
	Checking,
	CheckError,
	RealViewer
}

class AttachmentViewer extends StatefulWidget {
	final Attachment attachment;
	final Color backgroundColor;
	final ValueChanged<bool> onDeepInteraction;

	AttachmentViewer({
		@required this.attachment,
		this.backgroundColor = Colors.black,
		this.onDeepInteraction
	});

	@override
	createState() => _AttachmentViewerState();
}

class _AttachmentViewerState extends State<AttachmentViewer> with AutomaticKeepAliveClientMixin {
	AttachmentViewerStatus status;
	Uri goodUrl;

	@override
	void initState() {
		super.initState();
		print('attachmentviewer: initstate');
		status = AttachmentViewerStatus.LowRes;
	}

	@override
	void didChangeDependencies() {
		super.didChangeDependencies();
		print('attachmentviewer: didchangedependencies');
		if (Settings.of(context).autoloadAttachments) {
			print('autoloading');
			_load();
		}
	}

	@override
	void didUpdateWidget(AttachmentViewer oldWidget) {
		super.didUpdateWidget(oldWidget);
		print('didupdatewidget');
		if (oldWidget.attachment != widget.attachment) {
			print('attachmentviewer widget updated attachment');
			status = AttachmentViewerStatus.LowRes;
			if (Settings.of(context).autoloadAttachments) {
				_load();
			}
		}
	}

	void _load() async {
		print('load');
		final site = ChanSite.of(context).provider;
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
		final site = ChanSite.of(context).provider;
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
		print('buildstatus: $status');
		if (status == AttachmentViewerStatus.RealViewer) {
			if (widget.attachment.type == AttachmentType.WEBM) {
				return WEBMViewer(
					attachment: widget.attachment,
					url: goodUrl,
					backgroundColor: widget.backgroundColor,
					onDeepInteraction: widget.onDeepInteraction
				);
			}
			else {
				return ImageViewer(
					attachment: widget.attachment,
					url: goodUrl,
					backgroundColor: widget.backgroundColor,
					onDeepInteraction: widget.onDeepInteraction
				);
			}
		}
		else {
			return GestureDetector(
				child: Stack(
					children: [
						AttachmentThumbnail(
							attachment: widget.attachment,
							width: double.infinity,
							height: double.infinity,
							fit: BoxFit.contain
						),
						if (status == AttachmentViewerStatus.CheckError)
							Center(
								child: Column(
									children: [
										Icon(Icons.warning),
										Text('Error getting file'),
										RaisedButton.icon(
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
				onTap: () {
					print(status);
					if (status == AttachmentViewerStatus.LowRes) {
						_load();
					}
				}
			);
		}
	}

	@override
	bool get wantKeepAlive {
		return true;
	}
}
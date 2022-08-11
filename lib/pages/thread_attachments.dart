import 'package:chan/models/attachment.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/attachment_viewer.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class ThreadAttachmentsPage extends StatefulWidget {
	final Thread thread;
	final Attachment? initialAttachment;
	final ValueChanged<Attachment>? onChange;
	const ThreadAttachmentsPage({
		required this.thread,
		this.initialAttachment,
		this.onChange,
		Key? key
	}) : super(key: key);

	@override
	createState() => _ThreadAttachmentsPage();
}

class _ThreadAttachmentsPage extends State<ThreadAttachmentsPage> {
	final Map<Attachment, AttachmentViewerController> _controllers = {};
	final _controller = RefreshableListController<Attachment>();
	AttachmentViewerController? _lastPrimary;

	@override
	void initState() {
		super.initState();
		if (widget.initialAttachment != null) {
			Future.delayed(const Duration(milliseconds: 250), () {
				_controller.animateTo((a) => a.id == widget.initialAttachment?.id);
			});
		}
		Future.delayed(const Duration(seconds: 1), () {
			_controller.slowScrollUpdates.listen((_) {
				final lastItem = _controller.middleVisibleItem;
				if (lastItem != null) {
					widget.onChange?.call(lastItem);
					final primary = _controllers[lastItem];
					if (primary != _lastPrimary) {
						_lastPrimary?.isPrimary = false;
						_controllers[lastItem]?.isPrimary = true;
						_lastPrimary = primary;
					}
				}
			});
		});
	}

	AttachmentViewerController _getController(Attachment attachment) {
		return _controllers.putIfAbsent(attachment, () {
			final controller = AttachmentViewerController(
				context: context,
				attachment: attachment,
				site: context.read<ImageboardSite>(),
				isPrimary: false
			);
			if (context.watch<EffectiveSettings>().autoloadAttachments) {
				Future.microtask(() => controller.loadFullAttachment());
			}
			return controller;
		});
	}

	@override
	Widget build(BuildContext context) {
		final attachments = widget.thread.posts.expand((p) => p.attachments).toList();
		return RefreshableList<Attachment>(
			filterableAdapter: null,
			id: '${widget.thread.identifier} attachments',
			controller: _controller,
			listUpdater: () => throw UnimplementedError(),
			disableUpdates: true,
			initialList: attachments,
			itemBuilder: (context, attachment) => AspectRatio(
				aspectRatio: (attachment.width ?? 1) / (attachment.height ?? 1),
				child: GestureDetector(
					behavior: HitTestBehavior.opaque,
					onTap: () async {
						_getController(attachment).isPrimary = false;
						await showGallery(
							context: context,
							attachments: attachments,
							semanticParentIds: [-101],
							initialAttachment: attachment
						);
						_getController(attachment).isPrimary = true;
					},
					child: AnimatedBuilder(
						animation: _getController(attachment),
						builder: (context, child) => IgnorePointer(
							child: AttachmentViewer(
								controller: _getController(attachment),
								semanticParentIds: const [-101],
							)
						)
					)
				)
			)
		);
	}

	@override
	void dispose() {
		super.dispose();
		_controller.dispose();
		for (final controller in _controllers.values) {
			controller.dispose();
		}
	}
}
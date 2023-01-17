import 'dart:async';

import 'package:chan/pages/gallery.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/attachment_viewer.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class AttachmentsPage extends StatefulWidget {
	final List<TaggedAttachment> attachments;
	final TaggedAttachment? initialAttachment;
	final ValueChanged<TaggedAttachment>? onChange;
	final PersistentThreadState? threadState;
	const AttachmentsPage({
		required this.attachments,
		this.initialAttachment,
		this.onChange,
		this.threadState,
		Key? key
	}) : super(key: key);

	@override
	createState() => _AttachmentsPageState();
}

class _AttachmentsPageState extends State<AttachmentsPage> {
	final Map<TaggedAttachment, AttachmentViewerController> _controllers = {};
	late final RefreshableListController<TaggedAttachment> _controller;
	AttachmentViewerController? _lastPrimary;

	@override
	void initState() {
		super.initState();
		_controller = RefreshableListController();
		if (widget.initialAttachment != null) {
			Future.delayed(const Duration(milliseconds: 250), () {
				_controller.animateTo((a) => a.attachment.id == widget.initialAttachment?.attachment.id);
			});
		}
		Future.delayed(const Duration(seconds: 1), () {
			_controller.slowScrolls.addListener(_onSlowScroll);
		});
	}

	void _onSlowScroll() {
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
	}

	AttachmentViewerController _getController(TaggedAttachment attachment) {
		return _controllers.putIfAbsent(attachment, () {
			final controller = AttachmentViewerController(
				context: context,
				attachment: attachment.attachment,
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
		return Container(
			color: CupertinoTheme.of(context).scaffoldBackgroundColor,
			child: RefreshableList<TaggedAttachment>(
				filterableAdapter: null,
				id: '${widget.attachments.hashCode} attachments',
				controller: _controller,
				listUpdater: () => throw UnimplementedError(),
				disableUpdates: true,
				initialList: widget.attachments,
				itemBuilder: (context, attachment) => AspectRatio(
					aspectRatio: (attachment.attachment.width ?? 1) / (attachment.attachment.height ?? 1),
					child: GestureDetector(
						behavior: HitTestBehavior.opaque,
						onTap: () async {
							_getController(attachment).isPrimary = false;
							await showGalleryPretagged(
								context: context,
								attachments: widget.attachments,
								initialAttachment: attachment,
								isAttachmentAlreadyDownloaded: widget.threadState?.isAttachmentDownloaded,
								onAttachmentDownload: widget.threadState?.didDownloadAttachment
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
			)
		);
	}

	@override
	void dispose() {
		super.dispose();
		_controller.slowScrolls.removeListener(_onSlowScroll);
		_controller.dispose();
		for (final controller in _controllers.values) {
			controller.dispose();
		}
	}
}
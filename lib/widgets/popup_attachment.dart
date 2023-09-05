import 'package:chan/models/attachment.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/attachment_viewer.dart';
import 'package:chan/widgets/hover_popup.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class PopupAttachment extends StatelessWidget {
	final Attachment attachment;
	final Widget child;

	const PopupAttachment({
		required this.attachment,
		required this.child,
		Key? key
	}) : super(key: key);

	AttachmentViewerController _makeController(BuildContext context) {
		final controller = AttachmentViewerController(
			context: context,
			attachment: attachment,
			site: context.read<ImageboardSite>()
		);
		controller.isPrimary = true;
		controller.loadFullAttachment();
		return controller;
	}

	@override
	Widget build(BuildContext context) {
		return HoverPopup<AttachmentViewerController>(
			style: HoverPopupStyle.floating,
			key: ValueKey(attachment),
			popupBuilder: (controller, isWithinScalerBlurrer) => AnimatedBuilder(
				animation: controller!,
				builder: (context, child) => AttachmentViewer(
					controller: controller,
					semanticParentIds: const [-1, -1],
					fill: isWithinScalerBlurrer,
					heroOtherEndIsBoxFitCover: false
				)
			),
			setup: () => _makeController(context),
			softSetup: (controller) {
				if (controller?.attachment != attachment) {
					controller?.dispose();
					return _makeController(context);
				}
				else {
					controller?.isPrimary = true;
					controller?.videoPlayerController?.player.play();
					return controller;
				}
			},
			softCleanup: (controller) {
				Future.microtask(() {
					controller?.isPrimary = false;
					controller?.videoPlayerController?.player.pause();
				});
			},
			cleanup: (controller) {
				controller?.dispose();
			},
			child: child
		);
	}
}
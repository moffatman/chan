import 'package:chan/models/post.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/translation.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/reply_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

SelectableRegionContextMenuBuilder makePostContextMenuBuilder({
	required PostSpanZoneData zone,
	required ReplyBoxZone replyBoxZone,
	required BuildContext context,
	required ({Post post, List<int> parentIds, BuildContext context, double startOffset})? Function(double globalY1, double globalY2) findPost,
	required SelectedContent? Function() getSelection
}) {
	return (contextMenuContext, selectableRegionState) {
		final listItem = findPost(selectableRegionState.contextMenuAnchors.primaryAnchor.dy, switch (selectableRegionState.contextMenuAnchors.secondaryAnchor?.dy) {
			// Subtract 1 pixel as for some reason it goes a little below
			double y => y - 1,
			// Fallback to primary anchor
			null => selectableRegionState.contextMenuAnchors.primaryAnchor.dy
		});
		Post? post = listItem?.post;
		if (listItem != null) {
			final primaryAnchorInListItem = selectableRegionState.contextMenuAnchors.primaryAnchor - Offset(0, listItem.startOffset);
			final secondaryAnchorInListItem = switch (selectableRegionState.contextMenuAnchors.secondaryAnchor) {
				Offset anchor => anchor - Offset(0, listItem.startOffset + 1),
				null => primaryAnchorInListItem
			};
			PostSpanZoneData childZone = zone;
			for (final id in listItem.parentIds) {
				childZone = childZone.childZoneFor(id, style: zone.style);
			}
			for (final pair in childZone.expandedPostContexts) {
				final box = pair.value.findRenderObject() as RenderBox?;
				if (box == null) {
					continue;
				}
				final transform = box.getTransformTo(listItem.context.findRenderObject())..invert();
				final primaryAnchorLocal = MatrixUtils.transformPoint(transform, primaryAnchorInListItem);
				final secondaryAnchorLocal = MatrixUtils.transformPoint(transform, secondaryAnchorInListItem);
				final size = box.size;
				// Only compare dy. dx selection points can be bugged. And ExpandingPost is always full row.
				final containsPrimary = 0 <= primaryAnchorLocal.dy && primaryAnchorLocal.dy <= size.height;
				final containsSecondary = 0 <= secondaryAnchorLocal.dy && secondaryAnchorLocal.dy <= size.height;
				if (containsPrimary && containsSecondary) {
					// Selection contained within ExpandingPost
					post = zone.findPost(pair.key.postId);
					break;
				}
				else if (containsPrimary || containsSecondary) {
					// Selection partially contained within ExpandingPost
					post = null;
					break;
				}
				// No intersection
			}
		}
		return AdaptiveTextSelectionToolbar.buttonItems(
			anchors: selectableRegionState.contextMenuAnchors,
			buttonItems: [
				if (zone.imageboard.site.supportsPosting && zone.primaryThreadState?.thread?.isArchived == false) ...[
					if (post != null) ContextMenuButtonItem(
						onPressed: () {
							replyBoxZone.onQuoteText(getSelection()?.plainText ?? '', backlink: post?.identifier);
							selectableRegionState.hideToolbar();
						},
						label: 'Quotelink'
					),
					ContextMenuButtonItem(
						onPressed: () {
							replyBoxZone.onQuoteText(getSelection()?.plainText ?? '', backlink: null);
							selectableRegionState.hideToolbar();
						},
						label: 'Quote'
					)
				],
				...selectableRegionState.contextMenuButtonItems,
				ContextMenuButtonItem(
					onPressed: () {
						final text = getSelection()?.plainText ?? '';
						final future = translateHtml(text, toLanguage: Settings.instance.translationTargetLanguage);
						selectableRegionState.hideToolbar();
						showAdaptiveDialog(
							context: context,
							barrierDismissible: true,
							builder: (context) => AdaptiveAlertDialog(
								title: const Text('Translation'),
								content: FutureBuilder(
									future: future,
									builder: (context, snapshot) {
										final data = snapshot.data;
										if (data != null) {
											return Text(data, style: const TextStyle(fontSize: 16));
										}
										final error = snapshot.error;
										if (error != null) {
											return Text('Error: ${error.toStringDio()}');
										}
										return const CircularProgressIndicator.adaptive();
									}
								),
								actions: [
									AdaptiveDialogAction(
										onPressed: () => Navigator.pop(context),
										child: const Text('Close')
									)
								],
							)
						);
					},
					label: 'Translate'
				)
			]
		);
	};
}

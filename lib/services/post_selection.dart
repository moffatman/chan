import 'dart:io';

import 'package:chan/models/post.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/share.dart';
import 'package:chan/services/translation.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/reply_box.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

List<ContextMenuButtonItem> _makeCommonItems({
	required SelectedContent? Function() getSelection,
	required BuildContext contextMenuContext,
	required SelectableRegionState selectableRegionState,
}) => [
	if (Platform.isIOS) ...[
		// Temporary until https://github.com/flutter/flutter/issues/141775
		ContextMenuButtonItem(
			onPressed: () {
				shareOne(
					context: contextMenuContext,
					text: getSelection()?.plainText ?? '',
					type: "text",
					sharePositionOrigin: contextMenuContext.globalPaintBounds
				);
			},
			label: 'Share'
		),
		ContextMenuButtonItem(
			onPressed: () => openBrowser(contextMenuContext, Uri.https('google.com', '/search', {
				'q': getSelection()?.plainText ?? ''
			})),
			label: 'Google'
		)
	],
	ContextMenuButtonItem(
		onPressed: () {
			final text = getSelection()?.plainText ?? '';
			final future = translateHtml(text, toLanguage: Settings.instance.translationTargetLanguage);
			selectableRegionState.hideToolbar();
			showAdaptiveDialog(
				context: contextMenuContext,
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
							return const Center(
								child: CircularProgressIndicator.adaptive()
							);
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
];

SelectableRegionContextMenuBuilder makePostContextMenuBuilder({
	required PostSpanZoneData zone,
	required ReplyBoxZone replyBoxZone,
	required BuildContext context,
	required Post post,
	required SelectedContent? Function() getSelection
}) {
	return (contextMenuContext, selectableRegionState) {
		return AdaptiveTextSelectionToolbar.buttonItems(
			anchors: selectableRegionState.contextMenuAnchors,
			buttonItems: [
				if (zone.imageboard.site.supportsPosting) ...[
					ContextMenuButtonItem(
						onPressed: () {
							replyBoxZone.onQuoteText(getSelection()?.plainText ?? '', backlink: post.identifier);
							selectableRegionState.hideToolbar();
							Navigator.of(contextMenuContext, rootNavigator: true).pop();
						},
						label: 'Quotelink'
					),
					ContextMenuButtonItem(
						onPressed: () {
							replyBoxZone.onQuoteText(getSelection()?.plainText ?? '', backlink: null);
							selectableRegionState.hideToolbar();
							Navigator.of(contextMenuContext, rootNavigator: true).pop();
						},
						label: 'Quote'
					)
				],
				...selectableRegionState.contextMenuButtonItems,
				..._makeCommonItems(
					getSelection: getSelection,
					contextMenuContext: contextMenuContext,
					selectableRegionState: selectableRegionState
				)
			]
		);
	};
}

SelectableRegionContextMenuBuilder makeGeneralContextMenuBuilder(SelectedContent? Function() getSelection) {
	return (contextMenuContext, selectableRegionState) {
		return AdaptiveTextSelectionToolbar.buttonItems(
			anchors: selectableRegionState.contextMenuAnchors,
			buttonItems: [
				...selectableRegionState.contextMenuButtonItems,
				..._makeCommonItems(
					getSelection: getSelection,
					contextMenuContext: contextMenuContext,
					selectableRegionState: selectableRegionState
				)
			]
		);
	};
}

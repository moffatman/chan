import 'dart:io';

import 'package:chan/models/post.dart';
import 'package:chan/services/android.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/report_bug.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/share.dart';
import 'package:chan/services/translation.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/filter_editor.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/reply_box.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

List<ContextMenuButtonItem> makeCommonContextMenuItems({
	required SelectedContent? Function() getSelection,
	required BuildContext contextMenuContext,
	required SelectableRegionState? selectableRegionState,
}) => [
	ContextMenuButtonItem(
		onPressed: () async {
			final text = getSelection()?.plainText ?? '';
			if (text.isEmpty) {
				return;
			}
			final newFilter = await editFilter(contextMenuContext, CustomFilter(
				pattern: RegExp(RegExp.escape(text), caseSensitive: false)
			));
			if (newFilter?.value case final newFilter?) {
				final old = Settings.instance.filterConfiguration;
				Settings.instance.filterConfiguration = '$old\n${newFilter.toStringConfiguration()}';
				if (contextMenuContext.mounted) {
					showUndoToast(
						context: contextMenuContext,
						message: 'Added filter: ${newFilter.toStringConfiguration()}',
						onUndo: () {
							Settings.instance.filterConfiguration = old;
						}
					);
				}
			}
		},
		label: 'Filter'
	),
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
			final future = translateHtml(text, toLanguage: Settings.instance.translationTargetLanguage, interactive: true);
			selectableRegionState?.hideToolbar();
			showAdaptiveDialog(
				context: contextMenuContext,
				barrierDismissible: true,
				builder: (context) => FutureBuilder(
					future: future,
					builder: (context, snapshot) {
						final Widget content;
						if (snapshot.data case String translation) {
							content = Text(translation, style: const TextStyle(fontSize: 16));
						}
						else if (snapshot.error case Object error) {
							content = Text('Error: ${error.toStringDio()}');
						}
						else {
							content = const Center(
								child: CircularProgressIndicator.adaptive()
							);
						}
						return AdaptiveAlertDialog(
							title: const Text('Translation'),
							content: content,
							actions: [
								if (snapshot.error case final e?) ...[
									if (canOpenGoogleTranslate) AdaptiveDialogAction(
										onPressed: () => openGoogleTranslate(text),
										child: const Text('Open Google Translate')
									),
									if (snapshot.stackTrace case final st?)
										for (final remedy in generateBugRemedies(e, st, context).entries)
											AdaptiveDialogAction(
												onPressed: remedy.value,
												child: Text(remedy.key)
											)
								],
								AdaptiveDialogAction(
									onPressed: () => Navigator.pop(context),
									child: const Text('Close')
								)
							]
						);
					}
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
							final navigator = Navigator.of(contextMenuContext, rootNavigator: true);
							final currentRoute = navigator.currentRoute;
							replyBoxZone.onQuoteText(getSelection()?.plainText ?? '', backlink: post.identifier);
							selectableRegionState.hideToolbar();
							// Pop only if we haven't already popped (it might be handled in onQuoteText)
							navigator.popUntil((r) => r != currentRoute);
						},
						label: 'Quotelink'
					),
					ContextMenuButtonItem(
						onPressed: () {
							final navigator = Navigator.of(contextMenuContext, rootNavigator: true);
							final currentRoute = navigator.currentRoute;
							replyBoxZone.onQuoteText(getSelection()?.plainText ?? '', backlink: null);
							selectableRegionState.hideToolbar();
							// Pop only if we haven't already popped (it might be handled in onQuoteText)
							navigator.popUntil((r) => r != currentRoute);
						},
						label: 'Quote'
					)
				],
				...selectableRegionState.contextMenuButtonItems,
				...makeCommonContextMenuItems(
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
				...makeCommonContextMenuItems(
					getSelection: getSelection,
					contextMenuContext: contextMenuContext,
					selectableRegionState: selectableRegionState
				)
			]
		);
	};
}

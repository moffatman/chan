import 'package:chan/models/post.dart';
import 'package:chan/pages/overscroll_modal.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/util.dart';
import 'package:chan/widgets/weak_navigator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class SelectablePostPage extends StatelessWidget {
	final PostSpanZoneData zone;
	final Post post;
	final void Function(String, {required bool includeBacklink}) onQuoteText;

	const SelectablePostPage({
		required this.zone,
		required this.post,
		required this.onQuoteText,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return ChangeNotifierProvider.value(
			value: zone,
			child: Builder(
				builder: (context) => OverscrollModalPage(
					child: Container(
						padding: const EdgeInsets.all(16),
						width: double.infinity,
						color: ChanceTheme.backgroundColorOf(context),
						child: Column(
							mainAxisSize: MainAxisSize.min,
							crossAxisAlignment: CrossAxisAlignment.stretch,
							children: [
								SelectableText.rich(
									TextSpan(
										children: [
											TextSpan(children: buildPostInfoRow(
												post: post,
												isYourPost: zone.imageboard.persistence.getThreadStateIfExists(post.threadIdentifier)?.youIds.contains(post.id) ?? false,
												showSiteIcon: false,
												showBoardName: false,
												settings: context.watch<EffectiveSettings>(),
												theme: context.watch<SavedTheme>(),
												site: context.watch<ImageboardSite>(),
												context: context,
												zone: zone,
												interactive: false
											)),
											const TextSpan(text: '\n'),
											post.span.build(context, zone, context.watch<EffectiveSettings>(), context.watch<SavedTheme>(), PostSpanRenderOptions(
												showRawSource: true,
												recognizer: TapGestureRecognizer(),
												overrideRecognizer: true,
												shrinkWrap: true
											))
										]
									),
									scrollPhysics: const NeverScrollableScrollPhysics(),
									contextMenuBuilder: (context, editableTextState) => AdaptiveTextSelectionToolbar.buttonItems(
										anchors: editableTextState.contextMenuAnchors,
										buttonItems: [
											...editableTextState.contextMenuButtonItems,
											if (zone.imageboard.site.supportsPosting && zone.findThread(post.threadId)?.isArchived == false) ...[
												ContextMenuButtonItem(
													onPressed: () {
														onQuoteText(editableTextState.textEditingValue.selection.textInside(editableTextState.textEditingValue.text), includeBacklink: true);
													},
													label: 'Link in reply'
												),
												ContextMenuButtonItem(
													onPressed: () {
														onQuoteText(editableTextState.textEditingValue.selection.textInside(editableTextState.textEditingValue.text), includeBacklink: false);
													},
													label: 'Quote in reply'
												)
											],
											ContextMenuButtonItem(
												onPressed: () {
													Share.share(
														editableTextState.textEditingValue.selection.textInside(editableTextState.textEditingValue.text),
														sharePositionOrigin: null
													);
												},
												label: 'Share'
											),
											ContextMenuButtonItem(
												onPressed: () => openBrowser(context, Uri.https('google.com', '/search', {
													'q': editableTextState.textEditingValue.selection.textInside(editableTextState.textEditingValue.text)
												})),
												label: 'Google'
											)
										]
									),
								),
								const SizedBox(height: 16),
								Wrap(
									runAlignment: WrapAlignment.end,
									alignment: WrapAlignment.end,
									spacing: 16,
									runSpacing: 16,
									children: [
										AdaptiveFilledButton(
											onPressed: !zone.imageboard.site.supportsPosting || (zone.findThread(post.threadId)?.isArchived ?? false) ? null : () {
												onQuoteText(post.span.buildText(), includeBacklink: true);
												WeakNavigator.pop(context);
											},
											child: const Row(
												mainAxisSize: MainAxisSize.min,
												children: [
													Icon(CupertinoIcons.chevron_right_2),
													SizedBox(width: 8),
													Text('Link all')
												]
											)
										),
										AdaptiveFilledButton(
											onPressed: !zone.imageboard.site.supportsPosting || (zone.findThread(post.threadId)?.isArchived ?? false) ? null : () {
												onQuoteText(post.span.buildText(), includeBacklink: false);
												WeakNavigator.pop(context);
											},
											child: const Row(
												mainAxisSize: MainAxisSize.min,
												children: [
													Icon(CupertinoIcons.text_quote),
													SizedBox(width: 8),
													Text('Quote all')
												]
											)
										)
									]
								)
							]
						)
					)
				)
			)
		);
	}
}
import 'package:chan/models/post.dart';
import 'package:chan/pages/overscroll_modal.dart';
import 'package:chan/services/post_selection.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/weak_navigator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

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
											buildPostInfoRow(
												post: post,
												isYourPost: zone.imageboard.persistence.getThreadStateIfExists(post.threadIdentifier)?.youIds.contains(post.id) ?? false,
												showSiteIcon: false,
												showBoardName: false,
												settings: context.watch<Settings>(),
												theme: context.watch<SavedTheme>(),
												site: context.watch<ImageboardSite>(),
												context: context,
												zone: zone,
												interactive: false
											),
											const TextSpan(text: '\n'),
											post.span.build(context, post, zone, context.watch<Settings>(), context.watch<SavedTheme>(), PostSpanRenderOptions(
												showRawSource: true,
												recognizer: TapGestureRecognizer(debugOwner: this),
												overrideRecognizer: true,
												shrinkWrap: true
											))
										]
									),
									scrollPhysics: const NeverScrollableScrollPhysics(),
									contextMenuBuilder: (context, editableTextState) => AdaptiveTextSelectionToolbar.buttonItems(
										anchors: editableTextState.contextMenuAnchors,
										buttonItems: [
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
											...editableTextState.contextMenuButtonItems,
											...makeCommonContextMenuItems(
												getSelection: () => SelectedContent(
													plainText: editableTextState.textEditingValue.selection.textInside(editableTextState.textEditingValue.text)
												),
												contextMenuContext: context,
												selectableRegionState: null
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
											padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
											onPressed: !zone.imageboard.site.supportsPosting || (zone.findThread(post.threadId)?.isArchived ?? false) ? null : () {
												onQuoteText(post.buildText(), includeBacklink: true);
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
											padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
											onPressed: !zone.imageboard.site.supportsPosting || (zone.findThread(post.threadId)?.isArchived ?? false) ? null : () {
												onQuoteText(post.buildText(), includeBacklink: false);
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
								),
								const SizedBox(height: 16),
								Text(
									'Link all: Add quotelink, and copy text to reply field into a quote block\nQuote all: Copy text to reply field into a quote block',
									textAlign: TextAlign.right,
									style: TextStyle(
										color: ChanceTheme.primaryColorOf(context).withValues(alpha: 0.7)
									)
								),
								const SizedBox(height: 16),
								if (!ChanceTheme.materialOf(context) && !context.watch<MouseSettings>().supportMouse) Text(
									'NEW FEATURE: You can select and quote text from posts directly in the long-press context menu. Try it out! It\'s the menu you used to open this popup.',
									textAlign: TextAlign.left,
									style: TextStyle(
										color: ChanceTheme.secondaryColorOf(context)
									)
								)
							]
						)
					)
				)
			)
		);
	}
}
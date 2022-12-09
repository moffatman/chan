import 'package:chan/models/post.dart';
import 'package:chan/pages/overscroll_modal.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/weak_navigator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class SelectablePostPage extends StatelessWidget {
	final PostSpanZoneData zone;
	final Post post;
	final ValueChanged<String> onQuoteText;

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
						color: CupertinoTheme.of(context).scaffoldBackgroundColor,
						child: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								SelectableText.rich(
									TextSpan(
										children: [
											TextSpan(children: buildPostInfoRow(
												post: post,
												isYourPost: zone.threadState?.youIds.contains(post.id) ?? false,
												showSiteIcon: false,
												showBoardName: false,
												settings: context.read<EffectiveSettings>(),
												site: context.read<ImageboardSite>(),
												context: context,
												zone: zone,
												interactive: false
											)),
											const TextSpan(text: '\n'),
											post.span.build(context, zone, context.watch<EffectiveSettings>(), PostSpanRenderOptions(
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
											ContextMenuButtonItem(
												onPressed: () {
													onQuoteText(editableTextState.textEditingValue.selection.textInside(editableTextState.textEditingValue.text));
												},
												label: 'Quote in reply'
											),
											ContextMenuButtonItem(
												onPressed: () {
													Share.share(
														editableTextState.textEditingValue.selection.textInside(editableTextState.textEditingValue.text),
														sharePositionOrigin: null
													);
												},
											)
										]
									),
								),
								const SizedBox(height: 16),
								Align(
									alignment: Alignment.centerRight,
									child: CupertinoButton.filled(
										onPressed: () {
											onQuoteText(post.span.buildText());
											WeakNavigator.pop(context);
										},
										child: Row(
											mainAxisSize: MainAxisSize.min,
											children: const [
												Icon(CupertinoIcons.text_quote),
												SizedBox(width: 8),
												Text('Quote all')
											]
										)
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
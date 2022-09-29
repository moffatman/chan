import 'package:chan/models/post.dart';
import 'package:chan/pages/overscroll_modal.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/weak_navigator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

const double _kArrowScreenPadding = 26.0;

class _CustomTextSelectionControlsToolbar extends StatefulWidget {
	const _CustomTextSelectionControlsToolbar({
		Key? key,
		required this.clipboardStatus,
		required this.endpoints,
		required this.globalEditableRegion,
		required this.handleCopy,
		required this.handleCut,
		required this.handlePaste,
		required this.handleSelectAll,
		required this.selectionMidpoint,
		required this.textLineHeight,
		required this.handleQuoteText,
		required this.handleShare,
	}) : super(key: key);

	final ValueListenable<ClipboardStatus>? clipboardStatus;
	final List<TextSelectionPoint> endpoints;
	final Rect globalEditableRegion;
	final VoidCallback? handleCopy;
	final VoidCallback? handleCut;
	final VoidCallback? handlePaste;
	final VoidCallback? handleSelectAll;
	final Offset selectionMidpoint;
	final double textLineHeight;
	final VoidCallback? handleQuoteText;
	final VoidCallback? handleShare;

	@override
	_CustomTextSelectionControlsToolbarState createState() => _CustomTextSelectionControlsToolbarState();
}

class _CustomTextSelectionControlsToolbarState extends State<_CustomTextSelectionControlsToolbar> {
	void _onChangedClipboardStatus() {
		setState(() {
			// Inform the widget that the value of clipboardStatus has changed.
		});
	}

	@override
	void initState() {
		super.initState();
		widget.clipboardStatus?.addListener(_onChangedClipboardStatus);
	}

	@override
	void didUpdateWidget(_CustomTextSelectionControlsToolbar oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.clipboardStatus != widget.clipboardStatus) {
			oldWidget.clipboardStatus?.removeListener(_onChangedClipboardStatus);
      widget.clipboardStatus?.addListener(_onChangedClipboardStatus);
		}
	}

	@override
	void dispose() {
		super.dispose();
		widget.clipboardStatus?.removeListener(_onChangedClipboardStatus);
	}

	@override
	Widget build(BuildContext context) {
		// Don't render the menu until the state of the clipboard is known.
		if (widget.handlePaste != null && widget.clipboardStatus?.value == ClipboardStatus.unknown) {
			return const SizedBox(width: 0.0, height: 0.0);
		}

		assert(debugCheckHasMediaQuery(context));
		final MediaQueryData mediaQuery = MediaQuery.of(context);

		// The toolbar should appear below the TextField when there is not enough
		// space above the TextField to show it, assuming there's always enough
		// space at the bottom in this case.
		final double anchorX = (widget.selectionMidpoint.dx + widget.globalEditableRegion.left).clamp(
			_kArrowScreenPadding + mediaQuery.padding.left,
			mediaQuery.size.width - mediaQuery.padding.right - _kArrowScreenPadding,
		);

		// The y-coordinate has to be calculated instead of directly quoting
		// selectionMidpoint.dy, since the caller
		// (TextSelectionOverlay._buildToolbar) does not know whether the toolbar is
		// going to be facing up or down.
		final Offset anchorAbove = Offset(
			anchorX,
			widget.endpoints.first.point.dy - widget.textLineHeight + widget.globalEditableRegion.top,
		);
		final Offset anchorBelow = Offset(
			anchorX,
			widget.endpoints.last.point.dy + widget.globalEditableRegion.top,
		);

		final List<Widget> items = <Widget>[];
		final CupertinoLocalizations localizations = CupertinoLocalizations.of(context);
		final Widget onePhysicalPixelVerticalDivider =
				SizedBox(width: 1.0 / MediaQuery.of(context).devicePixelRatio);

		void addToolbarButton(
			String text,
			VoidCallback onPressed,
		) {
			if (items.isNotEmpty) {
				items.add(onePhysicalPixelVerticalDivider);
			}

			items.add(CupertinoTextSelectionToolbarButton.text(
				onPressed: onPressed,
				text: text,
			));
		}

		if (widget.handleCut != null) {
			addToolbarButton(localizations.cutButtonLabel, widget.handleCut!);
		}
		if (widget.handleCopy != null) {
			addToolbarButton(localizations.copyButtonLabel, widget.handleCopy!);
		}
		if (widget.handlePaste != null
        && widget.clipboardStatus?.value == ClipboardStatus.pasteable) {
			addToolbarButton(localizations.pasteButtonLabel, widget.handlePaste!);
		}
		if (widget.handleSelectAll != null) {
			addToolbarButton(localizations.selectAllButtonLabel, widget.handleSelectAll!);
		}
		if (widget.handleQuoteText != null) {
			addToolbarButton('Quote in reply', widget.handleQuoteText!);
		}
		if (widget.handleShare != null) {
			addToolbarButton('Share', widget.handleShare!);
		}

		// If there is no option available, build an empty widget.
		if (items.isEmpty) {
			return const SizedBox(width: 0.0, height: 0.0);
		}

		return CupertinoTextSelectionToolbar(
			anchorAbove: anchorAbove,
			anchorBelow: anchorBelow,
			children: items,
		);
	}
}

class _CustomEditingControls extends CupertinoTextSelectionControls {
	final ValueChanged<String> onQuoteText;
	final ValueChanged<String> onShare;
	_CustomEditingControls({
		required this.onQuoteText,
		required this.onShare,
	}) : super();

	@override
	Widget buildToolbar(
		BuildContext context,
		Rect globalEditableRegion,
		double textLineHeight,
		Offset selectionMidpoint,
		List<TextSelectionPoint> endpoints,
		TextSelectionDelegate delegate,
		ValueListenable<ClipboardStatus>? clipboardStatus,
		Offset? lastSecondaryTapDownPosition,
	) {
		return _CustomTextSelectionControlsToolbar(
			clipboardStatus: clipboardStatus,
			endpoints: endpoints,
			globalEditableRegion: globalEditableRegion,
			handleCut: canCut(delegate) ? () => handleCut(delegate) : null,
      handleCopy: canCopy(delegate) ? () => handleCopy(delegate) : null,
			handlePaste: canPaste(delegate) ? () => handlePaste(delegate) : null,
			handleSelectAll: canSelectAll(delegate) ? () => handleSelectAll(delegate) : null,
			handleQuoteText: canCopy(delegate) ? () => onQuoteText(delegate.textEditingValue.selection.textInside(delegate.textEditingValue.text)) : null,
			handleShare: canCopy(delegate) ? () => onShare(delegate.textEditingValue.selection.textInside(delegate.textEditingValue.text)) : null,
			selectionMidpoint: selectionMidpoint,
			textLineHeight: textLineHeight,
		);
	}
}

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
									selectionControls: _CustomEditingControls(
										onQuoteText: onQuoteText,
										onShare: (text) => Share.share(
											text,
											sharePositionOrigin: null
										)
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
import 'package:chan/models/post.dart';
import 'package:chan/pages/overscroll_modal.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

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
	}) : super(key: key);

	final ClipboardStatusNotifier? clipboardStatus;
	final List<TextSelectionPoint> endpoints;
	final Rect globalEditableRegion;
	final VoidCallback? handleCopy;
	final VoidCallback? handleCut;
	final VoidCallback? handlePaste;
	final VoidCallback? handleSelectAll;
	final Offset selectionMidpoint;
	final double textLineHeight;
	final VoidCallback? handleQuoteText;

	@override
	_CustomTextSelectionControlsToolbarState createState() => _CustomTextSelectionControlsToolbarState();
}

class _CustomTextSelectionControlsToolbarState extends State<_CustomTextSelectionControlsToolbar> {
	ClipboardStatusNotifier? _clipboardStatus;

	void _onChangedClipboardStatus() {
		setState(() {
			// Inform the widget that the value of clipboardStatus has changed.
		});
	}

	@override
	void initState() {
		super.initState();
		if (widget.handlePaste != null) {
			_clipboardStatus = widget.clipboardStatus ?? ClipboardStatusNotifier();
			_clipboardStatus!.addListener(_onChangedClipboardStatus);
			_clipboardStatus!.update();
		}
	}

	@override
	void didUpdateWidget(_CustomTextSelectionControlsToolbar oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.clipboardStatus != widget.clipboardStatus) {
			if (_clipboardStatus != null) {
				_clipboardStatus!.removeListener(_onChangedClipboardStatus);
				_clipboardStatus!.dispose();
			}
			_clipboardStatus = widget.clipboardStatus ?? ClipboardStatusNotifier();
			_clipboardStatus!.addListener(_onChangedClipboardStatus);
			if (widget.handlePaste != null) {
				_clipboardStatus!.update();
			}
		}
	}

	@override
	void dispose() {
		super.dispose();
		// When used in an Overlay, this can be disposed after its creator has
		// already disposed _clipboardStatus.
		if (_clipboardStatus != null && !_clipboardStatus!.disposed) {
			_clipboardStatus!.removeListener(_onChangedClipboardStatus);
			if (widget.clipboardStatus == null) {
				_clipboardStatus!.dispose();
			}
		}
	}

	@override
	Widget build(BuildContext context) {
		// Don't render the menu until the state of the clipboard is known.
		if (widget.handlePaste != null
				&& _clipboardStatus!.value == ClipboardStatus.unknown) {
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
				&& _clipboardStatus!.value == ClipboardStatus.pasteable) {
			addToolbarButton(localizations.pasteButtonLabel, widget.handlePaste!);
		}
		if (widget.handleSelectAll != null) {
			addToolbarButton(localizations.selectAllButtonLabel, widget.handleSelectAll!);
		}
		if (widget.handleQuoteText != null) {
			addToolbarButton('Quote in reply', widget.handleQuoteText!);
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
	_CustomEditingControls({
		required this.onQuoteText
	}) : super();

	@override
	Widget buildToolbar(
		BuildContext context,
		Rect globalEditableRegion,
		double textLineHeight,
		Offset selectionMidpoint,
		List<TextSelectionPoint> endpoints,
		TextSelectionDelegate delegate,
		ClipboardStatusNotifier clipboardStatus,
		Offset? lastSecondaryTapDownPosition,
	) {
		return _CustomTextSelectionControlsToolbar(
			clipboardStatus: clipboardStatus,
			endpoints: endpoints,
			globalEditableRegion: globalEditableRegion,
			handleCut: canCut(delegate) ? () => handleCut(delegate, clipboardStatus) : null,
			handleCopy: canCopy(delegate) ? () => handleCopy(delegate, clipboardStatus) : null,
			handlePaste: canPaste(delegate) ? () => handlePaste(delegate) : null,
			handleSelectAll: canSelectAll(delegate) ? () => handleSelectAll(delegate) : null,
			handleQuoteText: canCopy(delegate) ? () => onQuoteText(delegate.textEditingValue.selection.textInside(delegate.textEditingValue.text)) : null,
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
						child: SelectableText.rich(
							TextSpan(
								children: [
									post.span.build(context, PostSpanRenderOptions(
										showRawSource: true
									))
								]
							),
							scrollPhysics: const NeverScrollableScrollPhysics(),
							selectionControls: _CustomEditingControls(
								onQuoteText: onQuoteText
							),
						)
					)
				)
			)
		);
	}
}
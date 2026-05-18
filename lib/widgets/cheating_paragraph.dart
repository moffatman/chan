import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class RichTextWithBottomRightCornerWidget extends StatelessWidget {
	final InlineSpan textSpan;
	final TextOverflow? overflow;
	final Widget? cornerWidget;
	/// Assume we can break the rules and layout cornerWidget into this amount of negative Y space
	final double assumeTopMargin;
	const RichTextWithBottomRightCornerWidget(this.textSpan, {
		this.overflow,
		this.cornerWidget,
		this.assumeTopMargin = 0,
		super.key
	});

	@override
	Widget build(BuildContext context) {
		return _CheatingParagraph(
			paragraph: Text.rich(textSpan, overflow: overflow),
			decoration: cornerWidget,
			assumeTopMargin: assumeTopMargin
		);
	}
}

enum _CheatingParagraphLayoutId {
	paragraph,
	decoration
}

class _CheatingParagraph extends SlottedMultiChildRenderObjectWidget<_CheatingParagraphLayoutId, RenderBox> {
	final Text paragraph;
	final Widget? decoration;
	final double assumeTopMargin;

	const _CheatingParagraph({
		required this.paragraph,
		required this.decoration,
		required this.assumeTopMargin
	});

	@override
	Widget? childForSlot(_CheatingParagraphLayoutId slot) {
		return switch (slot) {
			_CheatingParagraphLayoutId.paragraph => paragraph,
			_CheatingParagraphLayoutId.decoration => decoration
		};
	}

	@override
	_RenderCheatingParagraph createRenderObject(BuildContext context) {
		return _RenderCheatingParagraph(assumeTopMargin: assumeTopMargin);
	}

	@override
	void updateRenderObject(BuildContext context, _RenderCheatingParagraph renderObject) {
		renderObject.assumeTopMargin = assumeTopMargin;
	}

	@override
	Iterable<_CheatingParagraphLayoutId> get slots => [_CheatingParagraphLayoutId.paragraph, _CheatingParagraphLayoutId.decoration];
}

class _RenderCheatingParagraph extends RenderBox with SlottedContainerRenderObjectMixin<_CheatingParagraphLayoutId, RenderBox> {
	_RenderCheatingParagraph({
		required double assumeTopMargin
	}) : _assumeTopMargin = assumeTopMargin;

	RenderBox? get _paragraph => childForSlot(_CheatingParagraphLayoutId.paragraph);
	RenderBox? get _decoration => childForSlot(_CheatingParagraphLayoutId.decoration);

	double _assumeTopMargin;
	set assumeTopMargin(double newValue) {
		if (_assumeTopMargin == newValue) {
			return;
		}
		_assumeTopMargin = newValue;
		markNeedsLayout();
	}

	@override
	Iterable<RenderBox> get children {
		// Hit test order (top first)
		return [
			if (_decoration != null) _decoration!,
			if (_paragraph != null) _paragraph!
		];
	}

	static RenderParagraph? _extractParagraph(RenderObject? obj) => switch (obj) {
		RenderParagraph paragraph => paragraph,
		RenderObjectWithChildMixin parent => _extractParagraph(parent.child),
		RenderObject? _ => null
	};

	double _calculateDecorationTop({
		required double paragraphHeight,
		required Size decoration,
		required Size biggest,
		required Offset Function(Offset) hitTest
	}) {
		double decorationTop = math.min(math.max(decoration.height, paragraphHeight), biggest.height - decoration.height);
		final minDecorationTop = math.max(0.0, paragraphHeight - decoration.height);
		while (decorationTop > minDecorationTop) {
			final position = hitTest(Offset(double.infinity, decorationTop - 2.0 /* some small delta to go into next line */));
			final availableWidth = biggest.width - position.dx;
			if (availableWidth < decoration.width) {
				return decorationTop;
			}
			decorationTop = position.dy;
		}
		return math.max(-_assumeTopMargin, paragraphHeight - decoration.height);
	}

	@override
	void performLayout() {
		_paragraph!.layout(constraints, parentUsesSize: true);
		if (_decoration == null) {
			size = _paragraph!.size;
			return;
		}
		_decoration!.layout(constraints.loosen(), parentUsesSize: true);
		final double decorationTop;
		// Assuming any renderobject around the paragraph does not change the layout (mouseregion)
		if (_extractParagraph(_paragraph) case final paragraph?) {
			decorationTop = _calculateDecorationTop(
				paragraphHeight: _paragraph!.size.height,
				biggest: constraints.biggest,
				decoration: _decoration!.size,
				hitTest: (o) => paragraph.getOffsetForCaret(paragraph.getPositionForOffset(o), Rect.zero)
			);
		}
		else {
			decorationTop = constraints.constrainHeight(_paragraph!.size.height + _decoration!.size.height) - _decoration!.size.height;
		}
		final width = constraints.maxWidth.isFinite ? constraints.maxWidth : _paragraph!.size.width;
		//(_paragraph!.parentData as BoxParentData).offset = Offset(0, ((decorationTop + _decoration!.size.height) - _paragraph!.size.height) / 2);
		(_paragraph!.parentData as BoxParentData).offset = Offset.zero;
		(_decoration!.parentData as BoxParentData).offset = Offset(width - _decoration!.size.width, decorationTop);
		size = Size(width, decorationTop + _decoration!.size.height);
	}

	@override
	void paint(PaintingContext context, Offset offset) {
		context.paintChild(_paragraph!, offset + (_paragraph!.parentData as BoxParentData).offset);
		if (_decoration != null) {
			context.paintChild(_decoration!, offset + (_decoration!.parentData as BoxParentData).offset);
		}
	}

	@override
	bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
		for (final RenderBox child in children) {
			final BoxParentData parentData = child.parentData! as BoxParentData;
			final bool isHit = result.addWithPaintOffset(
				offset: parentData.offset,
				position: position,
				hitTest: (BoxHitTestResult result, Offset transformed) {
					assert(transformed == position - parentData.offset);
					return child.hitTest(result, position: transformed);
				}
			);
			if (isHit) {
				return true;
			}
		}
		return false;
	}

	// TODO: Steal intrinsics from TextPainter

	@override
	double computeMinIntrinsicWidth(double height) {
		final paragraphWidth = _paragraph!.getMinIntrinsicWidth(height);
		if (_decoration == null) {
			return paragraphWidth;
		}
		final decorationWidth = _decoration!.getMinIntrinsicWidth(height);
		return math.max(paragraphWidth, decorationWidth);
	}

	@override
	double computeMaxIntrinsicWidth(double height) {
		final paragraphWidth = _paragraph!.getMaxIntrinsicWidth(height);
		if (_decoration == null) {
			return paragraphWidth;
		}
		final decorationWidth = _decoration!.getMaxIntrinsicWidth(height);
		return math.max(paragraphWidth, decorationWidth);
	}

	@override
	double computeMinIntrinsicHeight(double width) {
		return _paragraph!.getMinIntrinsicHeight(width);
	}

	@override
	double computeMaxIntrinsicHeight(double width) {
		return _paragraph!.getMaxIntrinsicHeight(width);
	}

	@override
	Size computeDryLayout(BoxConstraints constraints) {
		return _paragraph!.getDryLayout(constraints);
	}
}

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

enum WidgetDecorationLayoutId {
	child,
	decoration
}

/// Force a decoration Widget to the same size as an arbitrary child Widget
class WidgetDecoration extends SlottedMultiChildRenderObjectWidget<WidgetDecorationLayoutId, RenderBox> {
	final Widget child;
	final Widget? decoration;
	final DecorationPosition position;

	const WidgetDecoration({
		required this.child,
		required this.decoration,
		required this.position,
		super.key
	});

	@override
	Widget? childForSlot(WidgetDecorationLayoutId slot) {
		return switch (slot) {
			WidgetDecorationLayoutId.child => child,
			WidgetDecorationLayoutId.decoration => decoration
		};
	}

	@override
	RenderWidgetDecoration createRenderObject(BuildContext context) {
		return RenderWidgetDecoration(
			position: position
		);
	}

	@override
	void updateRenderObject(BuildContext context, RenderWidgetDecoration renderObject) {
		renderObject.position = position;
	}

	@override
	Iterable<WidgetDecorationLayoutId> get slots => [WidgetDecorationLayoutId.child, WidgetDecorationLayoutId.decoration];
}

class RenderWidgetDecoration extends RenderBox with SlottedContainerRenderObjectMixin<WidgetDecorationLayoutId, RenderBox> {
	DecorationPosition _position;
	set position(DecorationPosition v) {
		if (v == _position) {
			return;
		}
		_position = v;
		markNeedsPaint();
	}

	RenderWidgetDecoration({
		required DecorationPosition position
	}) : _position = position;

	RenderBox? get _child => childForSlot(WidgetDecorationLayoutId.child);
	RenderBox? get _decoration => childForSlot(WidgetDecorationLayoutId.decoration);

	@override
	Iterable<RenderBox> get children {
		// Hit test order (top first)
		return [
			if (_position == DecorationPosition.foreground && _decoration != null) _decoration!,
			if (_child != null) _child!,
			if (_position == DecorationPosition.background && _decoration != null) _decoration!
		];
	}

	@override
	void performLayout() {
		_child!.layout(constraints, parentUsesSize: true);
		_decoration?.layout(BoxConstraints.tight(_child!.size));
		size = _child!.size;
	}

	@override
	void paint(PaintingContext context, Offset offset) {
		final decoration = _decoration;
		if (_position == DecorationPosition.background && decoration != null) {
			context.paintChild(decoration, offset);
		}
		context.paintChild(_child!, offset);
		if (_position == DecorationPosition.foreground && decoration != null) {
			context.paintChild(decoration, offset);
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

	@override
	double computeMinIntrinsicWidth(double height) {
		return _child!.computeMinIntrinsicWidth(height);
	}

	@override
	double computeMaxIntrinsicWidth(double height) {
		return _child!.computeMaxIntrinsicWidth(height);
	}

	@override
	double computeMinIntrinsicHeight(double width) {
		return _child!.computeMinIntrinsicHeight(width);
	}

	@override
	double computeMaxIntrinsicHeight(double width) {
		return _child!.computeMaxIntrinsicHeight(width);
	}

	@override
	Size computeDryLayout(BoxConstraints constraints) {
		return _child!.getDryLayout(constraints);
	}
}

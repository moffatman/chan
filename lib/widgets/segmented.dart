import 'dart:async';
import 'dart:math' as math;

import 'package:chan/widgets/cupertino_inkwell.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart';

class SegmentedWidgetSegment {
	final Color color;
	final Widget child;
	final FutureOr Function()? onPressed;
	final bool flexible;

	const SegmentedWidgetSegment({
		required this.color,
		required this.child,
		this.onPressed,
		this.flexible = false
	});

	Widget _build(BorderRadius? borderRadius, EdgeInsets padding) {
		final child = Padding(
			padding: padding,
			child: Align(
				widthFactor: 1,
				heightFactor: 1,
				child: this.child
			)
		);
		return DecoratedBox(
			decoration: BoxDecoration(borderRadius: borderRadius, color: color),
			child: onPressed == null ? child : Builder(
				builder: (context) => CupertinoInkwell(
					padding: EdgeInsets.zero,
					minimumSize: Size.zero,
					onPressed: wrapButtonCallback(context, onPressed),
					child: child
				)
			)
		);
	}
}

class SegmentedWidget extends StatelessWidget {
	final List<SegmentedWidgetSegment> segments;
	final Radius radius;
	final EdgeInsets padding;

	const SegmentedWidget({
		required this.segments,
		required this.radius,
		this.padding = const EdgeInsets.all(8),
		super.key
	});

	@override
	Widget build(BuildContext context) {
		if (segments.isEmpty) return const SizedBox.shrink();
		return _SegmentedLayout(
			flexible: segments.map((segment) => segment.flexible).toList(),
			textDirection: Directionality.of(context),
			children: [
				for (var i = 0; i < segments.length; i++) segments[i]._build(
					BorderRadius.horizontal(
						left: i == 0 ? radius : Radius.zero,
						right: i == segments.length - 1 ? radius : Radius.zero
					),
					padding
				)
			]
		);
	}
}

class _SegmentedLayout extends MultiChildRenderObjectWidget {
	final List<bool> flexible;
	final TextDirection textDirection;

	const _SegmentedLayout({required this.flexible, required this.textDirection, required super.children});

	@override
	_RenderSegmentedLayout createRenderObject(BuildContext context) => _RenderSegmentedLayout(flexible, textDirection);

	@override
	void updateRenderObject(BuildContext context, _RenderSegmentedLayout renderObject) {
		renderObject
			..flexible = flexible
			..textDirection = textDirection;
	}
}

class _SegmentParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderSegmentedLayout extends RenderBox with ContainerRenderObjectMixin<RenderBox, _SegmentParentData>, RenderBoxContainerDefaultsMixin<RenderBox, _SegmentParentData> {
	_RenderSegmentedLayout(this._flexible, this._textDirection);

	List<bool> _flexible;
	set flexible(List<bool> value) {
		if (listEquals(_flexible, value)) return;
		_flexible = value;
		markNeedsLayout();
	}

	TextDirection _textDirection;
	set textDirection(TextDirection value) {
		if (_textDirection == value) return;
		_textDirection = value;
		markNeedsLayout();
	}

	@override
	void setupParentData(RenderBox child) {
		if (child.parentData is! _SegmentParentData) {
			child.parentData = _SegmentParentData();
		}
	}

	Size _measure(BoxConstraints constraints, Size Function(RenderBox, BoxConstraints) layoutChild) {
		final children = getChildrenAsList();
		var width = 0.0;
		var height = 0.0;
		var flexibleCount = 0;
		for (var i = 0; i < children.length; i++) {
			if (_flexible[i]) {
				flexibleCount++;
				continue;
			}
			final childSize = layoutChild(children[i], BoxConstraints(maxHeight: constraints.maxHeight));
			width += childSize.width;
			height = math.max(height, childSize.height);
		}
		// Like Flexible(fit: FlexFit.loose), each flexible segment may use up
		// to an equal share of the space left by the fixed-width segments.
		final flexibleWidth = flexibleCount == 0 ? 0.0 : math.max(0.0, constraints.maxWidth - width) / flexibleCount;
		for (var i = 0; i < children.length; i++) {
			if (!_flexible[i]) continue;
			final childSize = layoutChild(children[i], BoxConstraints(maxWidth: flexibleWidth, maxHeight: constraints.maxHeight));
			width += childSize.width;
			height = math.max(height, childSize.height);
		}
		return constraints.constrain(Size(width, height));
	}

	@override
	Size computeDryLayout(BoxConstraints constraints) => _measure(constraints, (child, constraints) => child.getDryLayout(constraints));

	@override
	void performLayout() {
		size = _measure(constraints, (child, constraints) {
			child.layout(constraints, parentUsesSize: true);
			return child.size;
		});
		var x = 0.0;
		for (final child in getChildrenAsList()) {
			final width = child.size.width;
			// Keep the measured width constraints: tightening to the resulting
			// width can round down and wrap text into the now-fixed height.
			child.layout(child.constraints.tighten(height: size.height), parentUsesSize: true);
			(child.parentData! as _SegmentParentData).offset = Offset(
				_textDirection == TextDirection.ltr ? x : size.width - x - width,
				0
			);
			x += width;
		}
	}

	@override
	void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

	@override
	bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}
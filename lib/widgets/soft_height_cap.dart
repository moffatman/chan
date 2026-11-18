import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Shows the full child when it exceeds [maxHeight] by at most [tolerance].
/// Otherwise, clips it to [maxHeight] without changing the child's layout.
class SoftHeightCap extends SingleChildRenderObjectWidget {
	final double maxHeight;
	final double tolerance;

	const SoftHeightCap({
		required this.maxHeight,
		required this.tolerance,
		required super.child,
		super.key
	}) : assert(maxHeight >= 0 && maxHeight < double.infinity),
		assert(tolerance >= 0 && tolerance < double.infinity);

	@override
	RenderSoftHeightCap createRenderObject(BuildContext context) => RenderSoftHeightCap(maxHeight: maxHeight, tolerance: tolerance);

	@override
	void updateRenderObject(BuildContext context, RenderSoftHeightCap renderObject) {
		renderObject
			..maxHeight = maxHeight
			..tolerance = tolerance;
	}
}

class RenderSoftHeightCap extends RenderProxyBox {
	RenderSoftHeightCap({required double maxHeight, required double tolerance}) : _maxHeight = maxHeight, _tolerance = tolerance;

	double _maxHeight;
	set maxHeight(double value) {
		if (_maxHeight == value) return;
		_maxHeight = value;
		markNeedsLayout();
	}

	double _tolerance;
	set tolerance(double value) {
		if (_tolerance == value) return;
		_tolerance = value;
		markNeedsLayout();
	}

	bool get isTruncated => child != null && child!.size.height > size.height;

	BoxConstraints _childConstraints(BoxConstraints constraints) => constraints.copyWith(minHeight: 0, maxHeight: double.infinity);

	Size _cappedSize(BoxConstraints constraints, Size naturalSize) => constraints.constrain(Size(
		naturalSize.width,
		naturalSize.height <= _maxHeight + _tolerance ? naturalSize.height : _maxHeight
	));

	@override
	Size computeDryLayout(BoxConstraints constraints) => _cappedSize(
		constraints,
		child?.getDryLayout(_childConstraints(constraints)) ?? Size.zero
	);

	@override
	void performLayout() {
		child?.layout(_childConstraints(constraints), parentUsesSize: true);
		size = _cappedSize(constraints, child?.size ?? Size.zero);
	}

	@override
	void paint(PaintingContext context, Offset offset) {
		if (isTruncated) {
			context.pushClipRect(needsCompositing, offset, Offset.zero & size, super.paint);
		}
		else {
			super.paint(context, offset);
		}
	}

	@override
	Rect? describeApproximatePaintClip(RenderObject child) => isTruncated ? Offset.zero & size : null;
}

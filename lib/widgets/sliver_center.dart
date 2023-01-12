import 'dart:math';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class SliverCenter extends SingleChildRenderObjectWidget {
	const SliverCenter({
		super.child,
		super.key
	});

	@override
	RenderSliverCenter createRenderObject(BuildContext context) => RenderSliverCenter();
}


class RenderSliverCenter extends RenderProxySliver {
	RenderSliverCenter({
		RenderSliver? sliver
	}) {
		child = sliver;
	}

	@override
	void performLayout() {
		final SliverConstraints constraints = this.constraints;
		child!.layout(constraints, parentUsesSize: true);
		final extent = max(constraints.viewportMainAxisExtent - constraints.precedingScrollExtent, child!.geometry?.scrollExtent ?? 0);
		final childParentData = child!.parentData! as SliverPhysicalParentData;
		final padding = (extent - (child!.geometry?.scrollExtent ?? 0)) / 2;
		if (constraints.axis == Axis.vertical) {
			childParentData.paintOffset = Offset(0, padding);
		}
		else {
			childParentData.paintOffset = Offset(padding, 0);
		}
		geometry = SliverGeometry(
			scrollExtent: extent,
			layoutExtent: constraints.remainingPaintExtent,
			paintExtent: constraints.remainingPaintExtent,
			maxPaintExtent: extent,
			hasVisualOverflow: extent > constraints.remainingPaintExtent || constraints.scrollOffset > 0.0
		);
	}

	@override
	void paint(PaintingContext context, Offset offset) {
		if (child != null && child!.geometry!.visible) {
			final SliverPhysicalParentData childParentData = child!.parentData! as SliverPhysicalParentData;
			context.paintChild(child!, offset + childParentData.paintOffset);
		}
	}


	@override
	void setupParentData(RenderObject child) {
		if (child.parentData is! SliverPhysicalParentData) {
			child.parentData = SliverPhysicalParentData();
		}
	}

	@override
	bool hitTestChildren(SliverHitTestResult result, { required double mainAxisPosition, required double crossAxisPosition }) {
		if (child != null && child!.geometry!.hitTestExtent > 0.0) {
			final SliverPhysicalParentData childParentData = child!.parentData! as SliverPhysicalParentData;
			result.addWithAxisOffset(
				mainAxisPosition: mainAxisPosition,
				crossAxisPosition: crossAxisPosition,
				mainAxisOffset: childMainAxisPosition(child!),
				crossAxisOffset: childCrossAxisPosition(child!),
				paintOffset: childParentData.paintOffset,
				hitTest: child!.hitTest,
			);
		}
		return false;
	}

	@override
	double childMainAxisPosition(RenderSliver child) {
		assert(child == this.child);
		return calculatePaintOffset(constraints, from: 0.0, to: childScrollOffset(child)!);
	}

	@override
	double? childScrollOffset(RenderObject child) {
		assert(child.parent == this);
		final offset = (child.parentData as SliverPhysicalParentData).paintOffset;
		return constraints.axis == Axis.vertical ? offset.dy : offset.dx;
	}

	@override
	void applyPaintTransform(RenderObject child, Matrix4 transform) {
		assert(child == this.child);
		final SliverPhysicalParentData childParentData = child.parentData! as SliverPhysicalParentData;
		childParentData.applyPaintTransform(transform);
	}
}

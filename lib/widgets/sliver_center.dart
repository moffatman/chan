import 'dart:math';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class SliverCenter extends SingleChildRenderObjectWidget {
	final EdgeInsets minimumPadding;

	const SliverCenter({
		required this.minimumPadding,
		super.child,
		super.key
	});

	@override
	RenderSliverCenter createRenderObject(BuildContext context) => RenderSliverCenter(
		minimumPadding: minimumPadding
	);

	@override
	void updateRenderObject(BuildContext context, RenderSliverCenter renderObject) {
		renderObject.minimumPadding = minimumPadding;
	}
}


class RenderSliverCenter extends RenderSliverEdgeInsetsPadding {
	EdgeInsets minimumPadding;

	RenderSliverCenter({
		required this.minimumPadding,
		RenderSliver? sliver
	}) {
		child = sliver;
	}

	void _resolve() {
		final SliverConstraints constraints = this.constraints;
		child!.layout(constraints, parentUsesSize: true);
		// child!.geometry?.scrollExtent could possibly be Infinity
		final childScrollExtent = min(child!.geometry?.scrollExtent ?? 0, constraints.viewportMainAxisExtent);
		final padding = (max(constraints.viewportMainAxisExtent, childScrollExtent) - childScrollExtent) / 2;
		final EdgeInsets centerPadding;
		if (constraints.axis == Axis.vertical) {
			centerPadding = EdgeInsets.symmetric(vertical: padding);
		}
		else {
			centerPadding = EdgeInsets.symmetric(horizontal: padding);
		}
		_resolvedPadding = EdgeInsets.only(
			top: max(minimumPadding.top, centerPadding.top),
			left: max(minimumPadding.left, centerPadding.left),
			right: max(minimumPadding.right, centerPadding.right),
			bottom: max(minimumPadding.bottom, centerPadding.bottom)
		);
	}

  @override
  void performLayout() {
    _resolve();
    super.performLayout();
  }
	
	EdgeInsets? _resolvedPadding;
	@override
	EdgeInsets? get resolvedPadding => _resolvedPadding;
}

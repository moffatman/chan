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
	EdgeInsets centerPadding = EdgeInsets.zero;

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
		final totalPadding = (max(constraints.viewportMainAxisExtent, childScrollExtent) - childScrollExtent);
		if (constraints.axis == Axis.vertical) {
			centerPadding = EdgeInsets.symmetric(vertical: max(0, (totalPadding - minimumPadding.vertical)) / 2);
		}
		else {
			centerPadding = EdgeInsets.symmetric(horizontal: max(0, (totalPadding - minimumPadding.horizontal)) / 2);
		}
		_resolvedPadding = minimumPadding + centerPadding;
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

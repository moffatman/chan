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


class RenderSliverCenter extends RenderSliverEdgeInsetsPadding {
	RenderSliverCenter({
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
		if (constraints.axis == Axis.vertical) {
			_resolvedPadding = EdgeInsets.symmetric(vertical: padding);
		}
		else {
			_resolvedPadding = EdgeInsets.symmetric(horizontal: padding);
		}
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

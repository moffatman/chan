import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Centers a label in the content area when it fits, otherwise lets it extend
/// rightward from that area's left edge into the outer padding.
class SidebarTabLabel extends SingleChildRenderObjectWidget {
	final EdgeInsets contentPadding;

	const SidebarTabLabel({required this.contentPadding, required super.child, super.key});

	@override
	RenderSidebarTabLabel createRenderObject(BuildContext context) => RenderSidebarTabLabel(contentPadding);

	@override
	void updateRenderObject(BuildContext context, RenderSidebarTabLabel renderObject) {
		renderObject.contentPadding = contentPadding;
	}
}

class RenderSidebarTabLabel extends RenderShiftedBox {
	RenderSidebarTabLabel(this._contentPadding) : super(null);

	EdgeInsets _contentPadding;
	set contentPadding(EdgeInsets value) {
		if (_contentPadding == value) return;
		_contentPadding = value;
		markNeedsLayout();
	}

	BoxConstraints _childConstraints(BoxConstraints constraints) => constraints.loosen().copyWith(
		maxWidth: math.max(0, constraints.maxWidth - _contentPadding.left)
	);

	Size _sizeFor(BoxConstraints constraints, Size childSize) => constraints.constrain(Size(
		constraints.hasBoundedWidth ? constraints.maxWidth : childSize.width + _contentPadding.horizontal,
		childSize.height
	));

	@override
	Size computeDryLayout(BoxConstraints constraints) => _sizeFor(constraints, child!.getDryLayout(_childConstraints(constraints)));

	@override
	void performLayout() {
		child!.layout(_childConstraints(constraints), parentUsesSize: true);
		size = _sizeFor(constraints, child!.size);
		final contentWidth = math.max(0, size.width - _contentPadding.horizontal);
		final left = _contentPadding.left + math.max(0, (contentWidth - child!.size.width) / 2);
		(child!.parentData! as BoxParentData).offset = Offset(left, (size.height - child!.size.height) / 2);
	}
}

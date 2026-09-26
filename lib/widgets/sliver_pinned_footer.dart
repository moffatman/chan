import 'dart:math';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Lays out [sliver] followed by [footer], but keeps the footer visible while
/// the preceding content scrolls beneath it. Short content keeps its natural
/// layout, including when an enclosing SliverCenter centers the whole group.
class SliverPinnedFooter extends MultiChildRenderObjectWidget {
	final double bottomPadding;

	SliverPinnedFooter({
		required Widget sliver,
		required Widget footer,
		required this.bottomPadding,
		super.key
	}) : super(children: [sliver, footer]);

	@override
	RenderSliverPinnedFooter createRenderObject(BuildContext context) => RenderSliverPinnedFooter(
		bottomPadding: bottomPadding
	);

	@override
	void updateRenderObject(BuildContext context, RenderSliverPinnedFooter renderObject) {
		renderObject.bottomPadding = bottomPadding;
	}
}

class RenderSliverPinnedFooter extends RenderSliverMainAxisGroup {
	RenderSliverPinnedFooter({required double bottomPadding}) : _bottomPadding = bottomPadding;

	double _bottomPadding;
	double get bottomPadding => _bottomPadding;
	set bottomPadding(double value) {
		if (value == _bottomPadding) return;
		_bottomPadding = value;
		markNeedsLayout();
	}

	RenderSliver get _content => firstChild!;
	RenderSliver get _footer => lastChild!;

	@override
	void performLayout() {
		assert(firstChild != lastChild);
		assert(constraints.axisDirection == AxisDirection.down);
		final content = _content;
		final footer = _footer;
		content.layout(constraints, parentUsesSize: true);
		final contentExtent = content.geometry!.scrollExtent;

		// Keep the footer laid out even when its natural position is off screen.
		footer.layout(constraints.copyWith(
			scrollOffset: 0,
			precedingScrollExtent: constraints.precedingScrollExtent + contentExtent,
			remainingPaintExtent: constraints.viewportMainAxisExtent,
			remainingCacheExtent: constraints.viewportMainAxisExtent,
			cacheOrigin: 0,
			overlap: 0
		), parentUsesSize: true);
		final footerExtent = footer.geometry!.scrollExtent;
		final totalExtent = contentExtent + footerExtent;
		final naturalTop = contentExtent - constraints.scrollOffset;
		final pinnedTop = constraints.remainingPaintExtent - bottomPadding - footerExtent;
		final footerTop = min(naturalTop, max(0.0, pinnedTop));

		(content.parentData! as SliverPhysicalParentData).paintOffset = Offset.zero;
		(footer.parentData! as SliverPhysicalParentData).paintOffset = Offset(0, footerTop);
		geometry = SliverGeometry(
			scrollExtent: totalExtent,
			paintExtent: max(0.0, min(constraints.remainingPaintExtent,
				max(content.geometry!.paintExtent, footerTop + footer.geometry!.paintExtent))),
			maxPaintExtent: totalExtent,
			cacheExtent: calculateCacheOffset(constraints, from: 0, to: totalExtent),
			hasVisualOverflow: totalExtent > constraints.remainingPaintExtent || constraints.scrollOffset > 0
		);
	}

	@override
	void paint(PaintingContext context, Offset offset) {
		final content = _content;
		final footer = _footer;
		if (content.geometry!.visible) context.paintChild(content, offset);
		if (footer.geometry!.visible) {
			context.paintChild(footer, offset + (footer.parentData! as SliverPhysicalParentData).paintOffset);
		}
	}

	@override
	bool hitTestChildren(SliverHitTestResult result, {
		required double mainAxisPosition,
		required double crossAxisPosition
	}) {
		for (final child in [_footer, _content]) {
			if (result.addWithAxisOffset(
				mainAxisPosition: mainAxisPosition,
				crossAxisPosition: crossAxisPosition,
				paintOffset: (child.parentData! as SliverPhysicalParentData).paintOffset,
				mainAxisOffset: childMainAxisPosition(child),
				crossAxisOffset: childCrossAxisPosition(child),
				hitTest: child.hitTest
			)) {
				return true;
			}
		}
		return false;
	}
}

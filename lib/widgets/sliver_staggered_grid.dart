import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class SliverStaggeredGrid extends SliverMultiBoxAdaptorWidget {
	const SliverStaggeredGrid({
		super.key,
		required super.delegate,
		required this.gridDelegate,
		this.id = 0
	});

	/// The delegate that controls the size and position of the children.
	final SliverStaggeredGridDelegate gridDelegate;

	/// Some way to reset the layout (columns)
	final int id;

	@override
  SliverMultiBoxAdaptorElement createElement() => SliverMultiBoxAdaptorElement(this, replaceMovedChildren: true);

	@override
	RenderSliverStaggeredGrid createRenderObject(BuildContext context) {
		final SliverMultiBoxAdaptorElement element = context as SliverMultiBoxAdaptorElement;
		return RenderSliverStaggeredGrid(childManager: element, gridDelegate: gridDelegate, id: id);
	}

	@override
	void updateRenderObject(BuildContext context, RenderSliverStaggeredGrid renderObject) {
		renderObject.gridDelegate = gridDelegate;
		renderObject.id = id;
	}

	@override
	double estimateMaxScrollOffset(
		SliverConstraints? constraints,
		int firstIndex,
		int lastIndex,
		double leadingScrollOffset,
		double trailingScrollOffset,
	) {
		final totalCount = delegate.estimatedChildCount;
		if (totalCount == null) {
			// Idk
			return double.infinity;
		}
		final averageExtent = trailingScrollOffset / lastIndex;
		return trailingScrollOffset + averageExtent * (totalCount - lastIndex);
	}
}

class RenderSliverStaggeredGrid extends RenderSliverMultiBoxAdaptor {
	RenderSliverStaggeredGrid({
		required super.childManager,
		int id = 0,
		required SliverStaggeredGridDelegate gridDelegate,
	}) : _gridDelegate = gridDelegate, _id = id, super();

	int _lastCrossAxisCount = 0;
	final Map<int, int> _columns = {};

	@override
	void setupParentData(RenderObject child) {
		if (child.parentData is! SliverGridParentData) {
			child.parentData = SliverGridParentData();
		}
	}

	/// The delegate that controls the size and position of the children.
	SliverStaggeredGridDelegate _gridDelegate;
	set gridDelegate(SliverStaggeredGridDelegate value) {
		if (_gridDelegate == value) {
			return;
		}
		if (value.runtimeType != _gridDelegate.runtimeType ||
				value.shouldRelayout(_gridDelegate)) {
			markNeedsLayout();
		}
		_gridDelegate = value;
	}

	/// A way to refresh the column layout
	int _id;
	set id(int value) {
		if (_id == value) {
			return;
		}
		_columns.clear();
		_id = value;
		markNeedsLayout();
	}

	@override
	double childCrossAxisPosition(RenderBox child) {
		final SliverGridParentData childParentData = child.parentData! as SliverGridParentData;
		return childParentData.crossAxisOffset!;
	}

	@override
	bool addInitialChild({ int index = 0, double layoutOffset = 0.0 }) {
		if (super.addInitialChild(index: index, layoutOffset: layoutOffset)) {
			final firstChildParentData = firstChild!.parentData! as SliverGridParentData;
			firstChildParentData.crossAxisOffset ??= 0;
			return true;
		}
		return false;
	}

	@override
	void performLayout() {
		final SliverConstraints constraints = this.constraints;
		childManager.didStartLayout();
		childManager.setDidUnderflow(false);

		final double scrollOffset = constraints.scrollOffset + constraints.cacheOrigin;
		assert(scrollOffset >= 0.0);
		final double remainingExtent = constraints.remainingCacheExtent;
		assert(remainingExtent >= 0.0);
		final double targetEndScrollOffset = scrollOffset + remainingExtent;
		final layout = _gridDelegate.getLayout(constraints);
		if (layout.crossAxisCount != _lastCrossAxisCount) {
			// Reset id -> columns
			_lastCrossAxisCount = layout.crossAxisCount;
			_columns.clear();
		}
		final BoxConstraints childConstraints = switch (constraints.axis) {
			Axis.horizontal => BoxConstraints(
				minHeight: constraints.crossAxisExtent / layout.crossAxisCount,
				maxHeight: constraints.crossAxisExtent / layout.crossAxisCount,
				minWidth: 0,
				maxWidth: double.infinity
			),
			Axis.vertical => BoxConstraints(
				minWidth: constraints.crossAxisExtent / layout.crossAxisCount,
				maxWidth: constraints.crossAxisExtent / layout.crossAxisCount,
				minHeight: 0,
				maxHeight: double.infinity
			)
		};
		int leadingGarbage = 0;
		int trailingGarbage = 0;
		bool reachedEnd = false;

		// Make sure we have at least one child to start from.
		if (firstChild == null) {
			if (!addInitialChild()) {
				// There are no children.
				geometry = SliverGeometry.zero;
				childManager.didFinishLayout();
				return;
			}
		}

		// We have at least one child.

		// These variables track the range of children that we have laid out. Within
		// this range, the children have consecutive indices. Outside this range,
		// it's possible for a child to get removed without notice.
		RenderBox? leadingChildWithLayout, trailingChildWithLayout;

		RenderBox? earliestUsefulChild = firstChild;

		// A firstChild with null layout offset is likely a result of children
		// reordering.
		//
		// We rely on firstChild to have accurate layout offset. In the case of null
		// layout offset, we have to find the first child that has valid layout
		// offset.
		if (childScrollOffset(firstChild!) == null) {
			int leadingChildrenWithoutLayoutOffset = 0;
			while (earliestUsefulChild != null && childScrollOffset(earliestUsefulChild) == null) {
				earliestUsefulChild = childAfter(earliestUsefulChild);
				leadingChildrenWithoutLayoutOffset += 1;
			}
			// We should be able to destroy children with null layout offset safely,
			// because they are likely outside of viewport
			collectGarbage(leadingChildrenWithoutLayoutOffset, 0);
			// If can not find a valid layout offset, start from the initial child.
			if (firstChild == null) {
				if (!addInitialChild()) {
					// There are no children.
					geometry = SliverGeometry.zero;
					childManager.didFinishLayout();
					return;
				}
			}
		}

		// Find the last child that is at or before the scrollOffset.
		earliestUsefulChild = firstChild;

		assert(childScrollOffset(firstChild!)! > -precisionErrorTolerance);

		assert(earliestUsefulChild == firstChild);

		// Make sure we've laid out at least one child.
		earliestUsefulChild!.layout(childConstraints, parentUsesSize: true);
		leadingChildWithLayout = earliestUsefulChild;
		trailingChildWithLayout = earliestUsefulChild;

		bool inLayoutRange = true;
		RenderBox? child = earliestUsefulChild;
		int index = indexOf(child);
		final int earliestUsefulChildIndex = index;
		List<double?> startScrollOffset = List.filled(layout.crossAxisCount, null);
		List<double> endScrollOffset = List.filled(layout.crossAxisCount, 0);

		final initialColumn = _columns[index];
		if (initialColumn != null) {
			startScrollOffset[initialColumn] = childScrollOffset(child)!;
			endScrollOffset[initialColumn] = childScrollOffset(child)! + paintExtentOf(child);
		}
		bool advance() { // returns true if we advanced, false if we have no more children
			// This function is used in two different places below, to avoid code duplication.
			assert(child != null);
			if (child == trailingChildWithLayout) {
				inLayoutRange = false;
			}
			child = childAfter(child!);
			if (child == null) {
				inLayoutRange = false;
			}
			index += 1;
			if (!inLayoutRange) {
				if (child == null || indexOf(child!) != index) {
					// We are missing a child. Insert it (and lay it out) if possible.
					child = insertAndLayoutChild(childConstraints,
						after: trailingChildWithLayout,
						parentUsesSize: true,
					);
					if (child == null) {
						// We have run out of children.
						return false;
					}
				} else {
					// Lay out the child.
					child!.layout(childConstraints, parentUsesSize: true);
				}
				trailingChildWithLayout = child;
			}
			assert(child != null);
			final SliverGridParentData childParentData = child!.parentData! as SliverGridParentData;
			final existingColumn = _columns[index];
			int column;
			if (existingColumn != null) {
				column = existingColumn;
				if (endScrollOffset[column] == 0) {
					endScrollOffset[column] = childParentData.layoutOffset ?? 0;
				}
			}
			else {
				column = 0;
				double shortestColumn = endScrollOffset[0];
				for (int i = 1; i < layout.crossAxisCount; i++) {
					if (endScrollOffset[i] < shortestColumn) {
						shortestColumn = endScrollOffset[i];
						column = i;
					}
				}
				_columns[index] = column;
			}
			childParentData.crossAxisOffset = column * (constraints.crossAxisExtent / layout.crossAxisCount);
			childParentData.layoutOffset = endScrollOffset[column];
			assert(childParentData.index == index);
			startScrollOffset[column] ??= childScrollOffset(child!);
			endScrollOffset[column] = childScrollOffset(child!)! + paintExtentOf(child!);
			return true;
		}

		// Find the first child that ends after the scroll offset.
		while (endScrollOffset.fold(0.0, math.max) < scrollOffset) {
			leadingGarbage += 1;
			if (!advance()) {
				assert(leadingGarbage == childCount);
				assert(child == null);
				// we want to make sure we keep the last child around so we know the end scroll offset
				collectGarbage(leadingGarbage - 1, 0);
				assert(firstChild == lastChild);
				final double extent = childScrollOffset(lastChild!)! + paintExtentOf(lastChild!);
				geometry = SliverGeometry(
					scrollExtent: extent,
					maxPaintExtent: extent,
				);
				return;
			}
		}

		// Now find the first child that ends after our end.
		while (endScrollOffset.fold(double.infinity, math.min) < targetEndScrollOffset) {
			if (!advance()) {
				reachedEnd = true;
				break;
			}
		}

		index = earliestUsefulChildIndex;
		while (startScrollOffset.any((o) => o == null || o > scrollOffset)) {
			assert(earliestUsefulChild != null);
			if (earliestUsefulChild == leadingChildWithLayout) {
				inLayoutRange = false;
			}
			earliestUsefulChild = insertAndLayoutLeadingChild(childConstraints, parentUsesSize: true);
			if (earliestUsefulChild == null) {
				inLayoutRange = false;
			}
			index -= 1;
			leadingGarbage -= 1;
			if (!inLayoutRange) {
				if (earliestUsefulChild == null) {
					// We have run out of children.
					final smallestScrollOffset = startScrollOffset.fold(double.infinity, (sm, m) => math.min(sm, m ?? double.infinity));
					if (smallestScrollOffset > precisionErrorTolerance && smallestScrollOffset.isFinite) {
						// No column reaches offset=0, do a correction
						for (RenderBox? child = firstChild; child != null; child = childAfter(child)) {
							final o = (child.parentData! as SliverGridParentData).layoutOffset;
							if (o != null) {
								(child.parentData! as SliverGridParentData).layoutOffset = o - smallestScrollOffset;
							}
						}
						geometry = SliverGeometry(
							scrollOffsetCorrection: -smallestScrollOffset,
						);
						return;
					}
					else {
						// Just ran out of children normally
						break;
					}
				}
				// Lay out the child.
				earliestUsefulChild.layout(childConstraints, parentUsesSize: true);
				leadingChildWithLayout = earliestUsefulChild;
			}
			assert(earliestUsefulChild != null);
			final SliverGridParentData childParentData = earliestUsefulChild!.parentData! as SliverGridParentData;
			final existingColumn = _columns[index];
			int column;
			if (existingColumn != null) {
				column = existingColumn;
				if (endScrollOffset[column] == 0) {
					endScrollOffset[column] = childParentData.layoutOffset ?? 0;
				}
			}
			else {
				column = 0;
				double biggestColumnGap = startScrollOffset[0] ?? double.infinity;
				for (int i = 1; i < layout.crossAxisCount; i++) {
					final o = startScrollOffset[i] ?? double.infinity;
					if (o > biggestColumnGap) {
						biggestColumnGap = o;
						column = i;
					}
				}
				_columns[index] = column;
			}
			final currentColumnStart = startScrollOffset[column] ?? targetEndScrollOffset;
			childParentData.crossAxisOffset = column * (constraints.crossAxisExtent / layout.crossAxisCount);
			childParentData.layoutOffset = math.max(0, currentColumnStart - paintExtentOf(earliestUsefulChild));
			assert(childParentData.index == index);
			startScrollOffset[column] = childParentData.layoutOffset;
		}

		// Finally count up all the remaining children and label them as garbage.
		if (child != null) {
			child = childAfter(child!);
			while (child != null) {
				trailingGarbage += 1;
				child = childAfter(child!);
			}
		}

		// At this point everything should be good to go, we just have to clean up
		// the garbage and report the geometry.

		collectGarbage(leadingGarbage, trailingGarbage);

		assert(debugAssertChildListIsNonEmptyAndContiguous());
		final double estimatedMaxScrollOffset;
		final maxEndScrollOffset = endScrollOffset.fold(0.0, math.max);
		if (reachedEnd) {
			estimatedMaxScrollOffset = maxEndScrollOffset;
		} else {
			estimatedMaxScrollOffset = childManager.estimateMaxScrollOffset(
				constraints,
				firstIndex: indexOf(firstChild!),
				lastIndex: indexOf(lastChild!),
				leadingScrollOffset: childScrollOffset(firstChild!),
				trailingScrollOffset: maxEndScrollOffset,
			);
			assert(estimatedMaxScrollOffset >= maxEndScrollOffset - childScrollOffset(firstChild!)!);
		}
		final double paintExtent = calculatePaintOffset(
			constraints,
			from: childScrollOffset(firstChild!)!,
			to: maxEndScrollOffset,
		);
		final double cacheExtent = calculateCacheOffset(
			constraints,
			from: childScrollOffset(firstChild!)!,
			to: maxEndScrollOffset,
		);
		final double targetEndScrollOffsetForPaint = constraints.scrollOffset + constraints.remainingPaintExtent;
		geometry = SliverGeometry(
			scrollExtent: estimatedMaxScrollOffset,
			paintExtent: paintExtent,
			cacheExtent: cacheExtent,
			maxPaintExtent: estimatedMaxScrollOffset,
			// Conservative to avoid flickering away the clip during scroll.
			hasVisualOverflow: maxEndScrollOffset > targetEndScrollOffsetForPaint || constraints.scrollOffset > 0.0,
		);

		// We may have started the layout while scrolled to the end, which would not
		// expose a new child.
		if (estimatedMaxScrollOffset == maxEndScrollOffset) {
			childManager.setDidUnderflow(true);
		}
		childManager.didFinishLayout();
	}
}

abstract class SliverStaggeredGridDelegate {
	const SliverStaggeredGridDelegate();

	SliverStaggeredGridLayout getLayout(SliverConstraints constraints);

	bool shouldRelayout(covariant SliverStaggeredGridDelegate oldDelegate);
}

class SliverStaggeredGridDelegateWithMaxCrossAxisExtent extends SliverStaggeredGridDelegate {
	final double maxCrossAxisExtent;

	const SliverStaggeredGridDelegateWithMaxCrossAxisExtent({
		required this.maxCrossAxisExtent
	});

	@override
	SliverStaggeredGridLayout getLayout(SliverConstraints constraints) {
    return SliverStaggeredGridLayout(
      crossAxisCount: math.max(1, (constraints.crossAxisExtent / maxCrossAxisExtent).ceil())
    );
	}

	@override
	bool shouldRelayout(SliverStaggeredGridDelegateWithMaxCrossAxisExtent oldDelegate) {
		return oldDelegate.maxCrossAxisExtent != maxCrossAxisExtent;
	}
}

class SliverStaggeredGridLayout {
	final int crossAxisCount;

	const SliverStaggeredGridLayout({
		required this.crossAxisCount
	});
}
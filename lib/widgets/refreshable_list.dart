import 'dart:async';
import 'dart:math';

import 'package:chan/models/parent_and_child.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/report_bug.dart';
import 'package:chan/services/screen_size_hacks.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/util.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/default_gesture_detector.dart';
import 'package:chan/widgets/sliver_staggered_grid.dart';
import 'package:chan/widgets/timed_rebuilder.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' hide WeakMap;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide WeakMap;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:weak_map/weak_map.dart';

const double _overscrollTriggerThreshold = 100;
const _treeAnimationDuration = Duration(milliseconds: 250);

class ItemNotFoundException implements Exception {
	final String message;
	const ItemNotFoundException(this.message);
	@override
	String toString() => 'Item not found: $message';
}

class FilterAlternative {
	final String name;
	final void Function(String) handler;
	final bool suggestWhenFilterEmpty;

	const FilterAlternative({
		required this.name,
		required this.handler,
		this.suggestWhenFilterEmpty = false
	});
}

const _kDummyHeight = 120.0;

class SliverDontRebuildChildBuilderDelegate<T> extends SliverChildBuilderDelegate {
	final List<T>? list;
	final Object? separatorSentinel;
	final String? id;
	final void Function(int, int)? _didFinishLayout;
	final double? Function(T)? fastHeightEstimate;
	final double? Function(int)? fastErrorEstimate;
	final NullableIndexedWidgetBuilder? separatorBuilder;

	const SliverDontRebuildChildBuilderDelegate(
    super.builder, {
		required this.list,
		this.separatorSentinel,
		this.id,
    super.findChildIndexCallback,
    super.childCount,
    super.addAutomaticKeepAlives,
    super.addRepaintBoundaries,
    super.addSemanticIndexes,
    super.semanticIndexCallback,
    super.semanticIndexOffset,
		void Function(int, int)? didFinishLayout,
		this.fastHeightEstimate,
		this.fastErrorEstimate,
		this.separatorBuilder
  }) : _didFinishLayout = didFinishLayout;

	@override
	void didFinishLayout(int firstIndex, int lastIndex) {
		_didFinishLayout?.call(firstIndex, lastIndex);
	}

	@override
	double? estimateMaxScrollOffset(
    int firstIndex,
    int lastIndex,
    double leadingScrollOffset,
    double trailingScrollOffset,
  ) {
		final items = list;
		if (items == null) {
			return null;
		}
		if ((separatorBuilder != null && lastIndex == (2 * items.length) - 1) ||
				(separatorBuilder == null && lastIndex == items.length - 1)) {
			return trailingScrollOffset;
		}
		final estimater = fastHeightEstimate;
		int knownCount;
		int remainingCount;
		double knownOffset = trailingScrollOffset;
		if (estimater == null) {
			knownCount = separatorBuilder == null ? lastIndex : lastIndex ~/ 2;
			remainingCount = items.length - knownCount;
		}
		else {
			remainingCount = 0;
			if (separatorBuilder != null) {
				for (int i = lastIndex ~/ 2; i < items.length; i++) {
					final estimate = estimater(items[i]);
					if (estimate != 0) {
						remainingCount++;
					}
					knownOffset += fastErrorEstimate?.call(i) ?? 0;
				}
			}
			else {
				for (int i = lastIndex; i < items.length; i++) {
					final estimate = estimater(items[i]);
					if (estimate != 0) {
						remainingCount++;
					}
					knownOffset += fastErrorEstimate?.call(i) ?? 0;
				}
			}
			knownCount = 0;
			if (separatorBuilder != null) {
				for (int i = 0; i <= min(items.length - 1, lastIndex ~/ 2); i++) {
					final estimate = estimater(items[i]);
					if (estimate != null) {
						knownOffset -= estimate;
					}
					else {
						knownCount++;
					}
				}
			}
			else {
				for (int i = 0; i <= lastIndex; i++) {
					final estimate = estimater(items[i]);
					if (estimate != null) {
						knownOffset -= estimate;
					}
					else {
						knownCount++;
					}
				}
			}
		}
		final double averageExtent;
		if (knownCount == 0) {
			// Guess
			averageExtent = 200;
		}
		else if (knownOffset > 100) {
			averageExtent = knownOffset / knownCount;
		}
		else {
			// This is a bad situation, due to use of dummies, we are currently
			// way underestimating the current [pixels]. Idk what to do here, just bail.
			averageExtent = trailingScrollOffset / knownCount;
		}
    return trailingScrollOffset + averageExtent * remainingCount;
	}

	@override
	Widget? build(BuildContext context, int index) {
		if (index < 0 || (childCount != null && index >= childCount!)) {
      return null;
    }
		if (separatorBuilder != null) {
			final childIndex = index ~/ 2;
			if (index.isEven) {
				return super.build(context, childIndex);
			}
			else {
				Widget? child;
				try {
					child = separatorBuilder!(context, childIndex);
				} catch (exception, stackTrace) {
					final error = FlutterErrorDetails(exception: exception, stack: stackTrace);
					FlutterError.reportError(error);
					child = ErrorWidget.builder(error);
				}
				if (child == null) {
					return null;
				}
				final Key? key = child.key;
				if (addRepaintBoundaries) {
					child = RepaintBoundary(child: child);
				}
				if (addSemanticIndexes) {
					final int? semanticIndex = semanticIndexCallback(child, index);
					if (semanticIndex != null) {
						child = IndexedSemantics(index: semanticIndex + semanticIndexOffset, child: child);
					}
				}
				return KeyedSubtree(key: key, child: child);
			}
		}
		else {
			return super.build(context, index);
		}
	}

	@override
	bool shouldRebuild(SliverDontRebuildChildBuilderDelegate oldDelegate) => !listEquals(list, oldDelegate.list) || id != oldDelegate.id || separatorSentinel != oldDelegate.separatorSentinel;
}

class SliverGridRegularTileLayoutWithCacheTrickery extends SliverGridRegularTileLayout {
	const SliverGridRegularTileLayoutWithCacheTrickery({
    required super.crossAxisCount,
    required super.mainAxisStride,
    required super.crossAxisStride,
    required super.childMainAxisExtent,
    required super.childCrossAxisExtent,
    required super.reverseCrossAxis,
  });

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset) {
    return mainAxisStride > precisionErrorTolerance ? (crossAxisCount * (scrollOffset / mainAxisStride)).floor() : 0;
  }

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset) {
    if (mainAxisStride > 0.0) {
      final double mainAxisCount = scrollOffset / mainAxisStride;
      return max(0, (crossAxisCount * mainAxisCount).ceil() - 1);
    }
    return 0;
  }
}

class SliverGridDelegateWithMaxCrossAxisExtentWithCacheTrickery extends SliverGridDelegateWithMaxCrossAxisExtent {
	const SliverGridDelegateWithMaxCrossAxisExtentWithCacheTrickery({
    required super.maxCrossAxisExtent,
    super.mainAxisSpacing = 0.0,
    super.crossAxisSpacing = 0.0,
    super.childAspectRatio = 1.0,
    super.mainAxisExtent,
  });

	@override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    int crossAxisCount = (constraints.crossAxisExtent / (maxCrossAxisExtent + crossAxisSpacing)).ceil();
    // Ensure a minimum count of 1, can be zero and result in an infinite extent
    // below when the window size is 0.
    crossAxisCount = max(1, crossAxisCount);
    final double usableCrossAxisExtent = max(
      0.0,
      constraints.crossAxisExtent - crossAxisSpacing * (crossAxisCount - 1),
    );
    final double childCrossAxisExtent = usableCrossAxisExtent / crossAxisCount;
    final double childMainAxisExtent = mainAxisExtent ?? childCrossAxisExtent / childAspectRatio;
    return SliverGridRegularTileLayoutWithCacheTrickery(
      crossAxisCount: crossAxisCount,
      mainAxisStride: childMainAxisExtent + mainAxisSpacing,
      crossAxisStride: childCrossAxisExtent + crossAxisSpacing,
      childMainAxisExtent: childMainAxisExtent,
      childCrossAxisExtent: childCrossAxisExtent,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }
}

extension _ListBeginsWith<T> on List<T> {
	bool beginsWith(List<T> other) {
		if (other.length > length) {
			// Too short to match
		}
		for (int i = 0; i < other.length; i++) {
			if (this[i] != other[i]) {
				return false;
			}
		}
		return true;
	}
}

class _TreeTooDeepException implements Exception {
	const _TreeTooDeepException();
}

class _TreeNode<T extends Object> {
	final T item;
	final int id;
	final bool hasOmittedReplies;
	final List<_TreeNode<T>> children;
	final List<int> stubChildIds;
	final List<_TreeNode<T>> parents;

	_TreeNode(this.item, this.id, this.hasOmittedReplies) : children = [], stubChildIds = [], parents = [];

	bool find(int needle) {
		if (needle == id) {
			return true;
		}
		for (final parent in parents) {
			if (parent.find(needle)) {
				return true;
			}
		}
		return false;
	}

	_TreeNode get lastDescendant {
		return children.tryLast?.lastDescendant ?? this;
	}

	Iterable<int> get ownershipChain sync* {
		yield id;
		yield* parents.tryLast?.ownershipChain ?? const Iterable.empty();
	}

	@override
	String toString() => '_TreeNode<$T>(item: $item, id: $id, ${children.length > 5 ? '# children: ${children.length}' : 'children: $children'}, ${parents.length > 5 ? '# parents: ${parents.length}' : 'parents: $parents'}';

	@override
	bool operator == (Object o) =>
		identical(this, o) ||
		(o is _TreeNode<T>) &&
		(o.item == item) &&
		(o.id == id) &&
		(o.hasOmittedReplies == hasOmittedReplies) &&
		listEquals(o.children, children) &&
		listEquals(o.stubChildIds, stubChildIds) &&
		listEquals(o.parents, parents);

	@override
	int get hashCode => Object.hash(item, id, hasOmittedReplies, Object.hashAll(children), Object.hashAll(stubChildIds), Object.hashAll(parents));
}

class RefreshableListItem<T extends Object> {
	T item;
	RefreshableListItemOptions options;
	final bool representsUnknownStubChildren;
	final List<ParentAndChildIdentifier> representsKnownStubChildren;
	final List<int> representsUnloadedPages;
	final bool highlighted;
	final bool pinned;
	bool filterCollapsed;
	final String? filterReason;
	final int id;
	final List<int> parentIds;
	final Set<int> treeDescendantIds;
	final int? _depth;
	final _RefreshableTreeItemsCacheKey _key;
	final RefreshableListState _state;

	RefreshableListItem({
		required this.item,
		required this.options,
		required RefreshableListState state,
		this.highlighted = false,
		this.pinned = false,
		this.filterCollapsed = false,
		this.filterReason,
		required this.id,
		this.parentIds = const [],
		Set<int>? treeDescendantIds,
		this.representsUnknownStubChildren = false,
		this.representsKnownStubChildren = const [],
		this.representsUnloadedPages = const [],
		int? depth
	}) : treeDescendantIds = treeDescendantIds ?? {},
	     _depth = depth,
			 _key = state._internHashKey(_RefreshableTreeItemsCacheKey(parentIds, id, representsUnknownStubChildren || representsKnownStubChildren.isNotEmpty)),
			 _state = state;

	@override
	String toString({bool long = false}) => 'RefreshableListItem<$T>(${[
		id.toString(),
		if (representsStubChildren) 'representsStubs: ${representsUnknownStubChildren ? '<unknown>' : representsKnownStubChildren.length > 1 ? representsKnownStubChildren : '<known(${representsKnownStubChildren.length})>'}',
		if (representsUnloadedPages.isNotEmpty) 'representsUnloadedPages: $representsUnloadedPages',
		if (treeDescendantIds.isNotEmpty) 'treeDescendantIds: $treeDescendantIds)',
		if (long) ...[
			'item: $item',
			if (representsUnloadedPages.isNotEmpty) 'representsUnloadedPages: $representsUnloadedPages',
			if (highlighted) 'highlighted',
			if (pinned) 'pinned',
			if (filterCollapsed) 'filterCollapsed',
			if (filterReason != null) 'filterReason: $filterReason',
			if (parentIds.isNotEmpty) 'parentIds: $parentIds',
			if (treeDescendantIds.isNotEmpty) 'treeDescendantIds: $treeDescendantIds',
			if (_depth != null) '_depth: $_depth'
		]
	].join(', ')})';

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		(other is RefreshableListItem<T>) &&
		(other.item == item) &&
		(other.options == options) &&
		(other.id == id) &&
		(other.representsUnknownStubChildren == representsUnknownStubChildren) &&
		listEquals(other.representsKnownStubChildren, representsKnownStubChildren) &&
		listEquals(other.representsUnloadedPages, representsUnloadedPages) &&
		(other.highlighted == highlighted) &&
		(other.pinned == pinned) &&
		(other.filterCollapsed == filterCollapsed) &&
		(other.filterReason == filterReason) &&
		listEquals(other.parentIds, parentIds) &&
		setEquals(other.treeDescendantIds, treeDescendantIds) &&
		(other._depth == _depth) &&
		(other._state == _state);

	@override
	int get hashCode => Object.hash(item, options, representsUnknownStubChildren, representsKnownStubChildren.length, representsUnloadedPages.length, highlighted, pinned, filterCollapsed, filterReason, parentIds.length, treeDescendantIds.length, _depth, _state);

	RefreshableListItem<T> copyWith({
		List<int>? parentIds,
		bool? representsUnknownStubChildren,
		List<ParentAndChildIdentifier>? representsKnownStubChildren,
		int? depth,
	}) => RefreshableListItem(
		item: item,
		options: options,
		id: id,
		highlighted: highlighted,
		pinned: pinned,
		filterCollapsed: filterCollapsed,
		filterReason: filterReason,
		parentIds: parentIds ?? this.parentIds,
		treeDescendantIds: treeDescendantIds,
		representsUnknownStubChildren: representsUnknownStubChildren ?? this.representsUnknownStubChildren,
		representsKnownStubChildren: representsKnownStubChildren ?? this.representsKnownStubChildren,
		representsUnloadedPages: representsUnloadedPages,
		depth: depth,
		state: _state
	);

	int get depth {
		if (_depth != null) {
			return _depth;
		}
		final offset = (
			(
				(_state.widget.treeAdapter?.repliesToOPAreTopLevel ?? false) &&
				parentIds.tryFirst == _state.widget.treeAdapter?.opId
			) ||
			(
				(_state.widget.treeAdapter?.isPaged ?? false) &&
				// Is parent of a page#
				(parentIds.tryFirst?.isNegative ?? false)
			)
		) ? -1 : 0;
		if (representsStubChildren) {
			return max(0, parentIds.length + 1 + offset);
		}
		return max(0, parentIds.length + offset);
	}

	int? get _firstEffectiveParentId {
		if (parentIds.length > 1 &&
		    (_state.widget.treeAdapter?.repliesToOPAreTopLevel ?? false) &&
				(parentIds.tryFirst == _state.widget.treeAdapter?.opId)) {
			return parentIds[1];
		}
		return parentIds.first;
	}

	bool get representsStubChildren => representsUnknownStubChildren || representsKnownStubChildren.isNotEmpty;
}

class RefreshableTreeAdapter<T extends Object> {
	final int Function(T item) getId;
	final Iterable<int> Function(T item) getParentIds;
	final bool Function(T item) getHasOmittedReplies;
	final Future<List<T>> Function(List<T> currentList, List<ParentAndChildIdentifier> stubIds, CancelToken? cancelToken) updateWithStubItems;
	final Widget Function(Widget, List<int>) wrapTreeChild;
	final int opId;
	final double Function(T item, double width) estimateHeight;
	final bool Function(T item) getIsStub;
	final bool Function(T item) getIsPageStub;
	final bool initiallyCollapseSecondLevelReplies;
	final bool collapsedItemsShowBody;
	final bool Function(RefreshableListItem<T> item)? filter;
	final bool repliesToOPAreTopLevel;
	final bool newRepliesAreLinear;
	final bool isPaged;

	const RefreshableTreeAdapter({
		required this.getId,
		required this.getParentIds,
		required this.getHasOmittedReplies,
		required this.updateWithStubItems,
		required this.opId,
		required this.wrapTreeChild,
		required this.estimateHeight,
		required this.getIsStub,
		required this.getIsPageStub,
		required this.initiallyCollapseSecondLevelReplies,
		required this.collapsedItemsShowBody,
		required this.repliesToOPAreTopLevel,
		required this.newRepliesAreLinear,
		required this.isPaged,
		this.filter
	});
}

enum TreeItemCollapseType {
	collapsed,
	childCollapsed,
	mutuallyCollapsed,
	mutuallyChildCollapsed,
	topLevelCollapsed,
	newInsertCollapsed,
	parentOfNewInsert;
}

extension Convenience on TreeItemCollapseType? {
	bool get isDuplicate {
		switch (this) {
			case TreeItemCollapseType.mutuallyCollapsed:
			case TreeItemCollapseType.mutuallyChildCollapsed:
				return true;
			default:
				return false;
		}
	}

	bool get isHidden {
		switch (this) {
			case TreeItemCollapseType.childCollapsed:
			case TreeItemCollapseType.mutuallyChildCollapsed:
			case TreeItemCollapseType.newInsertCollapsed:
				return true;
			default:
				return false;
		}
	}

	bool get isCollapsed {
		switch (this) {
			case TreeItemCollapseType.collapsed:
			case TreeItemCollapseType.childCollapsed:
				return true;
			default:
				return false;
		}
	}
}

class _RefreshableTreeItemsCacheKey {
	final List<int> parentIds;
	final int thisId;
	final bool representsStubChildren;

	_RefreshableTreeItemsCacheKey(this.parentIds, this.thisId, this.representsStubChildren);

	@override
	bool operator ==(Object other) =>
		identical(this, other) ||
		other is _RefreshableTreeItemsCacheKey &&
		other.thisId == thisId &&
		listEquals(other.parentIds, parentIds) &&
		other.representsStubChildren == representsStubChildren;
	
	@override
	int get hashCode => Object.hash(thisId, Object.hashAll(parentIds), representsStubChildren);

	@override
	String toString() => '_RefreshableTreeItemsCacheKey(thisId: $thisId, parentIds: $parentIds, representsStubChildren: $representsStubChildren)';

	bool isDirectParentOf(_RefreshableTreeItemsCacheKey child) {
		if (parentIds.length + 1 != child.parentIds.length) {
			return false;
		}
		for (int i = 0; i < parentIds.length; i++) {
			if (parentIds[i] != child.parentIds[i]) {
				return false;
			}
		}
		return thisId == child.parentIds[parentIds.length];
	}

	bool isPeerOf(_RefreshableTreeItemsCacheKey other) {
		return thisId == other.thisId && listEquals(other.parentIds, parentIds);
	}

	bool isDescendantOf(_RefreshableTreeItemsCacheKey ancestor) {
		if (parentIds.length < (ancestor.parentIds.length + 1)) {
			return false;
		}
		for (int i = 0; i < ancestor.parentIds.length; i++) {
			if (parentIds[i] != ancestor.parentIds[i]) {
				return false;
			}
		}
		return parentIds[ancestor.parentIds.length] == ancestor.thisId;
	}
}

enum _DummyStatus {
	// Null = never built as dummy
	previously,
	now
}

class _RefreshableTreeItems<T extends Object> extends ChangeNotifier {
	final List<List<int>> manuallyCollapsedItems;
	final Map<int, int> defaultPrimarySubtreeParents = {};
	final Map<int, int> primarySubtreeParents;
	final Map<List<int>, CancelToken> loadingOmittedItems = {};
	final Map<_RefreshableTreeItemsCacheKey, TreeItemCollapseType?> _cache = Map.identity();
	final Map<_RefreshableTreeItemsCacheKey, _DummyStatus> _dummyCache = Map.identity();
	/// If the bool is false, we haven't laid out this item yet.
	/// Don't show the indicator on the parent.
	/// That's because its child might end up being shown.
	final Map<List<int>, bool> newlyInsertedItems = {};
	final Map<List<int>, bool> newlyInsertedStubRepliesForItem = {};
	final Set<int> itemsWithUnknownStubReplies = {};
	final RefreshableListState<T> state;

	_RefreshableTreeItems({
		required this.manuallyCollapsedItems,
		required this.primarySubtreeParents,
		required this.state
	});

	TreeItemCollapseType? isItemHidden(RefreshableListItem<T> item) {
		final key = item._key;
		return _cache.putIfAbsent(key, () {
			// Need to check all parent prefixes
			for (int d = 0; d < key.parentIds.length; d++) {
				final primaryParent = primarySubtreeParents[key.parentIds[d]] ?? defaultPrimarySubtreeParents[key.parentIds[d]];
				final theParentId = d == 0 ? -1 : key.parentIds[d - 1];
				if (primaryParent != null && primaryParent != theParentId) {
					return TreeItemCollapseType.mutuallyChildCollapsed;
				}
			}
			if (key.parentIds.isNotEmpty) {
				if (state._automaticallyCollapsedTopLevelItems.contains(item._firstEffectiveParentId)) {
					return TreeItemCollapseType.childCollapsed;
				}
			}
			if (key.representsStubChildren) {
				for (final newlyInserted in newlyInsertedStubRepliesForItem.keys) {
					if (newlyInserted.length != key.parentIds.length + 1) {
						continue;
					}
					// Possible this is the new insert
					if (newlyInserted.last != key.thisId) {
						continue;
					}
					bool keepGoing = true;
					for (int i = 0; i < newlyInserted.length - 1 && keepGoing; i++) {
						keepGoing = newlyInserted[i] == key.parentIds[i];
					}
					if (keepGoing) {
						return TreeItemCollapseType.newInsertCollapsed;
					}
				}
			}
			for (final newlyInserted in newlyInsertedItems.keys) {
				if (newlyInserted.length != key.parentIds.length + 1) {
					continue;
				}
				// Possible this is the new insert
				if (newlyInserted.last != key.thisId) {
					continue;
				}
				bool keepGoing = true;
				for (int i = 0; i < newlyInserted.length - 1 && keepGoing; i++) {
					keepGoing = newlyInserted[i] == key.parentIds[i];
				}
				if (keepGoing) {
					return TreeItemCollapseType.newInsertCollapsed;
				}
			}
			// By iterating reversed it will properly handle collapses within collapses
			for (final collapsed in manuallyCollapsedItems.reversed.followedBy(state._automaticallyCollapsedItems)) {
				if (collapsed.length > key.parentIds.length + 1) {
					continue;
				}
				bool keepGoing = true;
				for (int i = 0; i < collapsed.length - 1 && keepGoing; i++) {
					keepGoing = collapsed[i] == key.parentIds[i];
				}
				if (!keepGoing) {
					continue;
				}
				if (collapsed.length == key.parentIds.length + 1) {
					if (collapsed.last == key.thisId) {
						return TreeItemCollapseType.collapsed;
					}
					continue;
				}
				if (collapsed.last == key.parentIds[collapsed.length - 1] && collapsed.trySingle != (state.widget.treeAdapter?.opId ?? -1)) {
					return TreeItemCollapseType.childCollapsed;
				}
			}
			if (item.depth == 0 && state._automaticallyCollapsedTopLevelItems.contains(key.thisId)) {
				if (key.representsStubChildren) {
					return TreeItemCollapseType.childCollapsed;
				}
				else {
					return TreeItemCollapseType.topLevelCollapsed;
				}
			}
			final personalPrimarySubtreeParent = primarySubtreeParents[key.thisId] ?? defaultPrimarySubtreeParents[key.thisId];
			if (personalPrimarySubtreeParent != null && personalPrimarySubtreeParent != (key.parentIds.tryLast ?? -1)) {
				if (key.representsStubChildren) {
					return TreeItemCollapseType.mutuallyChildCollapsed;
				}
				else {
					return TreeItemCollapseType.mutuallyCollapsed;
				}
			}
			for (final newlyInserted in newlyInsertedItems.keys) {
				if (newlyInserted.length != key.parentIds.length + 2) {
					continue;
				}
				// Possible this is the parent of new insert
				bool keepGoing = true;
				for (int i = 0; i < key.parentIds.length && keepGoing; i++) {
					keepGoing = newlyInserted[i] == key.parentIds[i];
				}
				if (keepGoing && newlyInserted[newlyInserted.length - 2] == key.thisId && newlyInsertedItems[newlyInserted] == true) {
					return TreeItemCollapseType.parentOfNewInsert;
				}
			}
			if (!key.representsStubChildren) {
				for (final newlyInserted in newlyInsertedStubRepliesForItem.keys) {
					if (newlyInserted.length != key.parentIds.length + 1) {
						continue;
					}
					// Possible this is the new insert
					if (newlyInserted.last != key.thisId) {
						continue;
					}
					bool keepGoing = true;
					for (int i = 0; i < newlyInserted.length - 1 && keepGoing; i++) {
						keepGoing = newlyInserted[i] == key.parentIds[i];
					}
					if (keepGoing) {
						return TreeItemCollapseType.parentOfNewInsert;
					}
				}
			}
			return null;
		});
	}

  CancelToken? isItemLoadingOmittedItems(List<int> parentIds, int? thisId) {
		// By iterating reversed it will properly handle collapses within collapses
		for (final entry in loadingOmittedItems.entries) {
			final loading = entry.key;
			if (loading.length != parentIds.length + 1) {
				continue;
			}
			bool keepGoing = true;
			for (int i = 0; i < loading.length - 1 && keepGoing; i++) {
				keepGoing = loading[i] == parentIds[i];
			}
			if (keepGoing && loading.last == thisId) {
				return entry.value;
			}
		}
		return null;
	}

	void itemLoadingOmittedItemsStarted(List<int> parentIds, int thisId, CancelToken cancelToken) {
		loadingOmittedItems[[
			...parentIds,
			thisId
		]] = cancelToken;
		notifyListeners();
	}

	void itemLoadingOmittedItemsEnded(RefreshableListItem<T> item) {
		final x = [
			...item.parentIds,
			item.id
		];
		loadingOmittedItems.removeWhere((w, cancelToken) => listEquals(w, x));
		notifyListeners();
		state._onTreeCollapseOrExpand.call(item, true);
	}

	void hideItem(RefreshableListItem<T> item) {
		manuallyCollapsedItems.add([
			...item.parentIds,
			item.id
		]);
		_cache.removeWhere((key, value) => key.thisId == item.id || key.parentIds.contains(item.id));
		state.widget.onCollapsedItemsChanged?.call(manuallyCollapsedItems, primarySubtreeParents);
		state._onTreeCollapseOrExpand.call(item, false);
		notifyListeners();
	}

	Future<void> unhideItem(RefreshableListItem<T> item, {bool includingParents = false}) async {
		final x = [
			...item.parentIds,
			item.id
		];
		_cache.removeWhere((key, value) => key.thisId == item.id || key.parentIds.contains(item.id));
		if (includingParents) {
			final pid = item.parentIds.tryFirst;
			_cache.removeWhere((key, value) => key.parentIds.contains(pid) || key.thisId == pid);
		}
		final manuallyCollapsedItemsLengthBefore = manuallyCollapsedItems.length;
		manuallyCollapsedItems.removeWhere(includingParents ? x.beginsWith : (w) => listEquals(w, x));
		if (manuallyCollapsedItemsLengthBefore != manuallyCollapsedItems.length) {
			state.widget.onCollapsedItemsChanged?.call(manuallyCollapsedItems, primarySubtreeParents);
		}
		final automaticallyCollapsedItemsLengthBefore = state._automaticallyCollapsedItems.length;
		state._automaticallyCollapsedItems.removeWhere(includingParents ? x.beginsWith : (w) => listEquals(w, x));
		if (automaticallyCollapsedItemsLengthBefore != state._automaticallyCollapsedItems.length) {
			state._onAutomaticallyCollapsedItemExpanded.call(x);
		}
		if (state._automaticallyCollapsedTopLevelItems.remove(item.id)) {
			state._onAutomaticallyCollapsedTopLevelItemExpanded.call(item.id);
		}
		// Reveal any newly inserted items in the subtree below
		newlyInsertedItems.removeWhere((w, _) {
			if (w.length < (x.length + 1)) {
				return false;
			}
			for (int i = 0; i < x.length; i++) {
				if (w[i] != x[i]) {
					return false;
				}
			}
			return true;
		});
		newlyInsertedStubRepliesForItem.removeWhere((w, _) {
			if (w.length < x.length) {
				return false;
			}
			for (int i = 0; i < x.length; i++) {
				if (w[i] != x[i]) {
					return false;
				}
			}
			return true;
		});
		notifyListeners();
		if (includingParents) {
			final root = state.controller._items.tryFirstWhere((i) => i.item.id == item.parentIds.tryFirst)?.item;
			await state._onTreeCollapseOrExpand.call(root ?? item, false);
		}
		else {
			await state._onTreeCollapseOrExpand.call(item, false);
		}
	}

	void swapSubtreeTo(RefreshableListItem<T> item) {
		primarySubtreeParents[item.id] = item.parentIds.tryLast ?? -1;
		_cache.removeWhere((key, value) => key.thisId == item.id || key.parentIds.contains(item.id));
		state.widget.onCollapsedItemsChanged?.call(manuallyCollapsedItems, primarySubtreeParents);
		// Reveal any newly inserted items in the subtree below
		final x = [
			...item.parentIds,
			item.id
		];
		newlyInsertedItems.removeWhere((w, _) {
			if (w.length < (x.length + 1)) {
				return false;
			}
			for (int i = 0; i < x.length; i++) {
				if (w[i] != x[i]) {
					return false;
				}
			}
			return true;
		});
		newlyInsertedStubRepliesForItem.removeWhere((w, _) {
			if (w.length < x.length) {
				return false;
			}
			for (int i = 0; i < x.length; i++) {
				if (w[i] != x[i]) {
					return false;
				}
			}
			return true;
		});
		state._onTreeCollapseOrExpand.call(item, false);
		notifyListeners();
	}

	void revealNewInsert(RefreshableListItem<T> item, {bool quiet = false, bool stubOnly = false}) async {
		final x = [
			...item.parentIds,
			item.id
		];
		if (stubOnly) {
			_cache.removeWhere((key, value) => key.isPeerOf(item._key) || key.isDirectParentOf(item._key));
		}
		else {
			_cache.removeWhere((key, value) {
				return key.isPeerOf(item._key) || key.isDescendantOf(item._key) || key.isDirectParentOf(item._key);
			});
			newlyInsertedItems.removeWhere((w, _) => listEquals(w, x));
		}
		newlyInsertedStubRepliesForItem.removeWhere((w, _) => listEquals(w, x));
		if (!quiet) {
			state._onTreeCollapseOrExpand.call(item, false);
			await SchedulerBinding.instance.endOfFrame;
			notifyListeners();
		}
	}

	void revealNewInsertsBelow(RefreshableListItem<T> item) async {
		final x = [
			...item.parentIds,
			item.id
		];
		_cache.removeWhere((key, value) => key.thisId == item.id || key.parentIds.contains(item.id));
		newlyInsertedItems.removeWhere((w, _) {
			if (w.length < (x.length + 1)) {
				return false;
			}
			for (int i = 0; i < x.length; i++) {
				if (w[i] != x[i]) {
					return false;
				}
			}
			return true;
		});
		newlyInsertedStubRepliesForItem.removeWhere((w, _) => listEquals(w, x));
		state._onTreeCollapseOrExpand.call(item, false);
		await SchedulerBinding.instance.endOfFrame;
		notifyListeners();
	}
}

class _DividerKey {
	final _RefreshableTreeItemsCacheKey key;
	const _DividerKey(this.key);

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is _DividerKey &&
		other.key == key;
	
	@override
	int get hashCode => key.hashCode;
}

class _Divider<T extends Object> extends StatelessWidget {
	final Color color;
	final RefreshableListItem<T> itemBefore;
	final RefreshableListItem<T>? itemAfter;
	final bool dummy;

	const _Divider({
		required this.color,
		required this.dummy,
		required this.itemBefore,
		required this.itemAfter,
		super.key
	});

	@override
	Widget build(BuildContext context) {
		final treeItems = context.read<_RefreshableTreeItems<T>>();
		if (!treeItems.state.useTree) {
			return Divider(
				thickness: 1,
				height: 0,
				color: color
			);
		}
		final int? itemBeforeDepth;
		if (dummy) {
			if (!treeItems.isItemHidden(itemBefore).isHidden) {
				itemBeforeDepth = itemBefore.depth;
			}
			else {
				itemBeforeDepth = null;
			}
		}
		else if (context.select<_RefreshableTreeItems<T>, bool>((c) => !c.isItemHidden(itemBefore).isHidden)) {
			itemBeforeDepth = itemBefore.depth;
		}
		else {
			itemBeforeDepth = null;
		}
		final int? itemAfterDepth;
		if (dummy) {
			if (itemAfter != null && !treeItems.isItemHidden(itemAfter!).isHidden) {
				itemAfterDepth = itemAfter!.depth;
			}
			else {
				itemAfterDepth = null;
			}
		}
		else if (itemAfter != null && context.select<_RefreshableTreeItems<T>, bool>((c) => !c.isItemHidden(itemAfter!).isHidden)) {
			itemAfterDepth = itemAfter!.depth;
		}
		else {
			itemAfterDepth = null;
		}
		const infiniteDepth = 1 << 50;
		final depth = min(itemBeforeDepth ?? infiniteDepth, itemAfterDepth ?? infiniteDepth);
		if (depth == infiniteDepth) {
			return const SizedBox(
				width: double.infinity
			);
		}
		return Padding(
			padding: EdgeInsets.only(left: pow(depth, 0.70) * 20),
			child: Divider(
				thickness: 1,
				height: 0,
				color: color
			)
		);
	}
}

class RefreshableListFilterReason {
	final String reason;
	const RefreshableListFilterReason(this.reason);

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is RefreshableListFilterReason &&
		other.reason == reason;
	@override
	int get hashCode => reason.hashCode;
}

enum RefreshableListUpdateSource {
	top,
	bottom,
	timer,
	animation,
	other;
	bool get manual => switch (this) {
		RefreshableListUpdateSource.top || RefreshableListUpdateSource.bottom => true,
		_ => false
	};
	bool get automatic => switch (this) {
		RefreshableListUpdateSource.timer || RefreshableListUpdateSource.animation => true,
		_ => false
	};
}

class RefreshableListUpdateOptions {
	final RefreshableListUpdateSource source;
	final CancelToken cancelToken;
	const RefreshableListUpdateOptions({
		required this.source,
		required this.cancelToken
	});

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is RefreshableListUpdateOptions &&
		other.source == source &&
		other.cancelToken == cancelToken;
	
	@override
	int get hashCode => Object.hash(source, cancelToken);

	@override
	String toString() => 'RefreshableListUpdateOptions(source: $source)';
}

typedef _Tree<T extends Object> = ({
	List<RefreshableListItem<T>> tree,
	List<List<int>> automaticallyCollapsed,
	Set<int> automaticallyTopLevelCollapsed
});

class RefreshableListItemOptions {
	final bool hideThumbnails;
	final RegExp? queryPattern;

	const RefreshableListItemOptions({
		this.hideThumbnails = false,
		this.queryPattern
	});

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is RefreshableListItemOptions &&
		other.hideThumbnails == hideThumbnails &&
		other.queryPattern == queryPattern;
	
	@override
	int get hashCode => Object.hash(hideThumbnails, queryPattern);

	@override
	String toString() => 'RefreshableListItemOptions(hideThumbnails: $hideThumbnails, queryPattern: $queryPattern)';
}

class RefreshableList<T extends Object> extends StatefulWidget {
	final Widget Function(BuildContext context, T value, RefreshableListItemOptions options) itemBuilder;
	final Widget Function({
		required BuildContext context,
		required T? value,
		required Set<int> collapsedChildIds,
		required bool loading,
		required double? peekContentHeight,
		required List<ParentAndChildIdentifier>? stubChildIds,
		required bool alreadyDim
	})? collapsedItemBuilder;
	final List<T>? initialList;
	final Future<List<T>?> Function(RefreshableListUpdateOptions options) listUpdater;
	final Future<List<T>> Function(T after, CancelToken cancelToken)? listExtender;
	final String id;
	final String rebuildId;
	final RefreshableListController<T>? controller;
	final String? filterHint;
	final Duration? autoUpdateDuration;
	final Map<Type, (String, Future<void> Function())> remedies;
	final bool disableUpdates;
	final bool disableBottomUpdates;
	final Widget? header;
	final Widget? aboveFooter;
	final Widget? footer;
	final SliverGridDelegate? gridDelegate;
	final SliverStaggeredGridDelegate? staggeredGridDelegate;
	final String? initialFilter;
	final ValueChanged<String?>? onFilterChanged;
	final bool allowReordering;
	final ValueChanged<T>? onWantAutosave;
	final void Function(T, AutoWatchType)? onWantAutowatch;
	final (String imageboardKey, Filterable item) Function(T)? filterableAdapter;
	final FilterAlternative? filterAlternative;
	final bool includeImageboardKeyAndBoardInSearchString;
	final bool useTree;
	final RefreshableTreeAdapter<T>? treeAdapter;
	final List<Comparator<T>> sortMethods;
	final bool reverseSort;
	final List<List<int>>? initialCollapsedItems;
	final Map<int, int>? initialPrimarySubtreeParents;
	final void Function(List<List<int>>, Map<int, int>)? onCollapsedItemsChanged;
	final int? initialTreeSplitId;
	final ValueChanged<int>? onTreeSplitIdChanged;
	final Duration minUpdateDuration;
	final Listenable? updateAnimation;
	final bool canTapFooter;
	final double minCacheExtent;
	final bool shrinkWrap;
	final bool autoExtendDuringScroll;
	final bool useFiltersFromContext;
	final bool useAllDummies;
	final Widget? injectBelowScrollbar;

	const RefreshableList({
		required this.itemBuilder,
		required this.listUpdater,
		this.listExtender,
		required this.id,
		this.rebuildId = '',
		this.controller,
		this.filterHint,
		this.autoUpdateDuration,
		this.remedies = const {},
		this.initialList,
		this.disableUpdates = false,
		this.disableBottomUpdates = false,
		this.gridDelegate,
		this.staggeredGridDelegate,
		this.header,
		this.aboveFooter,
		this.footer,
		this.initialFilter,
		this.onFilterChanged,
		this.allowReordering = false,
		this.onWantAutosave,
		this.onWantAutowatch,
		required this.filterableAdapter,
		this.filterAlternative,
		this.includeImageboardKeyAndBoardInSearchString = false,
		this.useTree = false,
		this.treeAdapter,
		this.collapsedItemBuilder,
		this.sortMethods = const [],
		this.reverseSort = false,
		this.initialCollapsedItems,
		this.initialPrimarySubtreeParents,
		this.onCollapsedItemsChanged,
		this.initialTreeSplitId,
		this.onTreeSplitIdChanged,
		this.minUpdateDuration = const Duration(milliseconds: 500),
		this.updateAnimation,
		this.canTapFooter = true,
		this.minCacheExtent = 0,
		this.shrinkWrap = false,
		this.autoExtendDuringScroll = false,
		this.useFiltersFromContext = true,
		this.useAllDummies = false,
		this.injectBelowScrollbar,
		Key? key
	}) : super(key: key);

	@override
	createState() => RefreshableListState<T>();
}

class RefreshableListState<T extends Object> extends State<RefreshableList<T>> with SingleTickerProviderStateMixin {
	List<T>? originalList;
	List<T>? sortedList;
	late final ValueNotifier<(Object, StackTrace)?> error;
	late final ValueNotifier<({String id, Future<void> future, CancelToken cancelToken})?> updatingNow;
	late final TextEditingController _searchController;
	late final FocusNode _searchFocusNode;
	bool get searchHasFocus => _searchFocusNode.hasFocus;
	bool get searching => _searchController.text.isNotEmpty;
	DateTime? lastUpdateTime;
	DateTime? nextUpdateTime;
	Timer? autoUpdateTimer;
	GlobalKey _scrollViewKey = GlobalKey(debugLabel: 'RefreshableListState._scrollViewKey');
	GlobalKey _sliverListKey = GlobalKey(debugLabel: 'RefreshableListState._sliverListKey');
	GlobalKey _footerKey = GlobalKey(debugLabel: 'RefreshableListState._footerKey');
	int _pointerDownCount = 0;
	bool _showFilteredValues = false;
	bool _searchTapped = false;
	bool _overscrollEndingNow = false;
	late final AnimationController _footerShakeAnimation;
	DateTime _lastPointerUpTime = DateTime(2000);
	final List<List<int>> _automaticallyCollapsedItems = [];
	static final Map<String, List<List<int>>> _overrideExpandAutomaticallyCollapsedItemsCache = {};
	List<List<int>> get _overrideExpandAutomaticallyCollapsedItems => _overrideExpandAutomaticallyCollapsedItemsCache.putIfAbsent(widget.id, () => []);
	final Set<int> _automaticallyCollapsedTopLevelItems = {};
	static final Map<String, Set<int>> _overrideExpandAutomaticallyCollapsedTopLevelItemsCache = {};
	Set<int> get _overrideExpandAutomaticallyCollapsedTopLevelItems => _overrideExpandAutomaticallyCollapsedTopLevelItemsCache.putIfAbsent(widget.id, () => {});
	List<RefreshableListItem<T>> filteredValues = [];
	late _RefreshableTreeItems<T> _refreshableTreeItems;
	int forceRebuildId = 0;
	Timer? _trailingUpdateAnimationTimer;
	bool _treeBuildingFailed = false;
	int? _treeSplitId;
	bool _needToTransitionNewlyInsertedItems = false;
	({
		Map<int, int> treeRootIndexLookup,
		Map<int, Map<int, int>> treeChildrenIndexLookup
	})? _lastTreeOrder;
	bool _addedAppResumeCallback = false;
	bool _addedNetworkResumeCallback = false;
	final Set<_RefreshableTreeItemsCacheKey> _internedHashKeys = {};
	final WeakMap<Filterable, String?> _searchStrings = WeakMap();
	({int valuesLength, int newItemsCount})? _addedItemsFromExtension;
	RefreshableListController<T>? _backupController;
	RefreshableListController<T> get controller =>
		(widget.controller ?? (_backupController ??= RefreshableListController()));

	bool get useTree => widget.useTree && !_treeBuildingFailed;
	bool get treeBuildingFailed => _treeBuildingFailed;

	@override
	void initState() {
		super.initState();
		updatingNow = ValueNotifier(null);
		error = ValueNotifier(null);
		_searchController = TextEditingController(text: widget.initialFilter ?? '');
		_searchFocusNode = FocusNode();
		 _footerShakeAnimation = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
		if (widget.initialFilter?.isNotEmpty ?? false) {
			_searchTapped = true;
		}
		controller.attach(this);
		controller.newContentId(widget.id);
		originalList = widget.initialList?.toList();
		if (originalList != null) {
			sortedList = originalList!.toList();
			_sortList();
		}
		if (!widget.disableUpdates) {
			update();
			resetTimer();
		}
		_refreshableTreeItems = _RefreshableTreeItems<T>(
			manuallyCollapsedItems: widget.initialCollapsedItems?.toList() ?? [],
			primarySubtreeParents: Map.from(widget.initialPrimarySubtreeParents ?? {}),
			state: this
		);
		widget.updateAnimation?.addListener(_onUpdateAnimation);
		_treeSplitId = widget.initialTreeSplitId;
	}

	@override
	void didUpdateWidget(RefreshableList<T> oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (widget.controller != oldWidget.controller) {
			oldWidget.controller?.detach();
			controller.attach(this);
			controller.newContentId(widget.id);
		}
		if (oldWidget.updateAnimation != widget.updateAnimation) {
			oldWidget.updateAnimation?.removeListener(_onUpdateAnimation);
			widget.updateAnimation?.addListener(_onUpdateAnimation);
		}
		if (oldWidget.id != widget.id) {
			_searchStrings.clear();
			_internedHashKeys.clear();
			autoUpdateTimer?.cancel();
			autoUpdateTimer = null;
			controller.newContentId(widget.id);
			_scrollViewKey = GlobalKey(debugLabel: 'RefreshableListState._scrollViewKey');
			_sliverListKey = GlobalKey(debugLabel: 'RefreshableListState._sliverListKey');
			_footerKey = GlobalKey(debugLabel: 'RefreshableListState._footerKey');
			closeSearch();
			originalList = widget.initialList;
			sortedList = null;
			error.value = null;
			_treeSplitId = widget.initialTreeSplitId;
			lastUpdateTime = null;
			_automaticallyCollapsedItems.clear();
			_automaticallyCollapsedTopLevelItems.clear();
			_refreshableTreeItems.dispose();
			_refreshableTreeItems = _RefreshableTreeItems<T>(
				manuallyCollapsedItems: widget.initialCollapsedItems?.toList() ?? [],
				primarySubtreeParents: Map.from(widget.initialPrimarySubtreeParents ?? {}),
				state: this
			);
			_lastTreeOrder = null;
			if (!widget.disableUpdates) {
				update();
			}
		}
		else if (oldWidget.disableUpdates != widget.disableUpdates) {
			autoUpdateTimer?.cancel();
			autoUpdateTimer = null;
			if (!widget.disableUpdates) {
				update();
				resetTimer();
			}
		}
		else if (
			(
				// Normal non-listUpdater usecase
				widget.disableUpdates ||
				// Allow setting it from null
				originalList == null ||
				// Allow changing it
				(widget.initialList != null && widget.initialList != originalList)
			) &&
			// There is some change in the list
			!listEquals(oldWidget.initialList, widget.initialList) &&
			// Not in the middle of an update
			(updatingNow.value?.id != widget.id)
		) {
			originalList = widget.initialList;
			sortedList = originalList?.toList();
			if (originalList != null) {
				_sortList();
			}
		}
		if ((!listEquals(widget.sortMethods, oldWidget.sortMethods) ||
		     widget.reverseSort != oldWidget.reverseSort ||
				 sortedList == null) && originalList != null) {
			_lastTreeOrder = null; // Resort
			sortedList = originalList!.toList();
			_sortList();
		}
		if (!widget.disableUpdates && !oldWidget.disableUpdates &&
		    widget.autoUpdateDuration != oldWidget.autoUpdateDuration) {
			if (nextUpdateTime?.isAfter(DateTime.now().add(widget.autoUpdateDuration ?? Duration.zero)) ?? true) {
				// next update is scheduled too late or is scheduled at all if we now have auto-update off
				resetTimer();
			}
		}
		if (!widget.useAllDummies && oldWidget.useAllDummies) {
			for (final item in controller._items) {
				item.cachedOffset = null;
				item.cachedHeight = null;
			}
		}
	}

	@override
	void dispose() {
		super.dispose();
		widget.updateAnimation?.removeListener(_onUpdateAnimation);
		autoUpdateTimer?.cancel();
		_searchController.dispose();
		_searchFocusNode.dispose();
		_footerShakeAnimation.dispose();
		_refreshableTreeItems.dispose();
		updatingNow.dispose();
		_backupController?.dispose();
	}

	void _sortList() {
		for (final method in widget.sortMethods) {
			mergeSort<T>(sortedList!, compare: method);
		}
		if (widget.reverseSort) {
			sortedList = sortedList!.reversed.toList();
		}
	}

	void _onAutomaticallyCollapsedItemExpanded(List<int> item) {
		_overrideExpandAutomaticallyCollapsedItems.add(item);
	}

	void _onAutomaticallyCollapsedTopLevelItemExpanded(int item) {
		_overrideExpandAutomaticallyCollapsedTopLevelItems.add(item);
	}

	Future<void> _onTreeCollapseOrExpand(RefreshableListItem<T> item, bool looseEquality) async {
		Duration total = Duration.zero;
		while (total < _treeAnimationDuration) {
			const incremental = Duration(milliseconds: 50);
			await Future.delayed(incremental);
			if (!mounted) {
				return;
			}
			controller.invalidateAfter(item, looseEquality);
			controller.slowScrolls.didUpdate();
			total += incremental;
		}
	}

	void resetTimer() {
		if (!mounted) {
			return;
		}
		autoUpdateTimer?.cancel();
		if (widget.autoUpdateDuration != null) {
			autoUpdateTimer = Timer(widget.autoUpdateDuration!, _autoUpdate);
			nextUpdateTime = DateTime.now().add(widget.autoUpdateDuration!);
		}
		else {
			nextUpdateTime = null;
		}
	}

	void closeSearch() {
		_searchFocusNode.unfocus();
		_searchController.clear();
		setState(() {
			_lastTreeOrder = null;
			_searchTapped = false;
		});
		WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
			widget.onFilterChanged?.call(null);
		});
	}

	void _focusSearch() {
		_searchFocusNode.requestFocus();
		_searchTapped = true;
		setState(() {});
	}

	void _unfocusSearch() {
		_searchFocusNode.unfocus();
		setState(() {});
	}

	_RefreshableTreeItemsCacheKey _internHashKey(_RefreshableTreeItemsCacheKey key) {
		final existing = _internedHashKeys.lookup(key);
		if (existing != null) {
			return existing;
		}
		_internedHashKeys.add(key);
		return key;
	}

	Future<void> _loadOmittedItems(RefreshableListItem<T> value) async {
		final cancelToken = CancelToken();
		_refreshableTreeItems.itemLoadingOmittedItemsStarted(value.parentIds, value.id, cancelToken);
		try {
			final newList = await widget.treeAdapter!.updateWithStubItems(
				originalList!,
				value.representsUnknownStubChildren
					? [ParentAndChildIdentifier.same(value.id)]
					: value.representsKnownStubChildren,
				cancelToken
			);
			await controller.whenDoneAutoScrolling;
			originalList = newList;
			sortedList = newList.toList();
			_sortList();
			setState(() { });
		}
		catch (e, st) {
			if (mounted && !cancelToken.isCancelled) {
				alertError(context, e, st);
			}
		}
		finally {
			_refreshableTreeItems.itemLoadingOmittedItemsEnded(value);
		}
	}

	Future<void> _loadPage(RefreshableListItem<T> value, int page) async {
		assert(page.isNegative);
		final cancelToken = CancelToken();
		_refreshableTreeItems.itemLoadingOmittedItemsStarted(value.parentIds, value.id, cancelToken);
		try {
			final newList = await widget.treeAdapter!.updateWithStubItems(
				originalList!,
				[ParentAndChildIdentifier.same(page)],
				cancelToken
			);
			await controller.whenDoneAutoScrolling;
			originalList = newList;
			sortedList = newList.toList();
			_sortList();
			setState(() { });
		}
		catch (e, st) {
			if (mounted && !cancelToken.isCancelled) {
				alertError(context, e, st);
			}
		}
		finally {
			_refreshableTreeItems.itemLoadingOmittedItemsEnded(value);
		}
	}

	void _onUpdateAnimation() {
		if (widget.disableUpdates) {
			return;
		}
		if (DateTime.now().difference(lastUpdateTime ?? DateTime(2000)) > const Duration(seconds: 1)) {
			update(source: RefreshableListUpdateSource.animation);
		}
		else {
			_trailingUpdateAnimationTimer?.cancel();
			_trailingUpdateAnimationTimer = Timer(const Duration(seconds: 1), _onUpdateAnimation);
		}
	}

	void _autoExtendTrigger() {
		if (widget.autoExtendDuringScroll && !widget.disableBottomUpdates) {
			update(extend: true, overrideMinUpdateDuration: Duration.zero);
		}
	}

	void _rebuild() {
		if (mounted) {
			setState(() {});
		}
	}

	Future<void> _mergeTrees({required bool rebuild}) async {
		final newTreeSplitId = controller._items.fold<int>(0, (m, i) => max(m, i.item.representsKnownStubChildren.fold<int>(i.item.id, (n, j) => max(n, j.childId))));
		_lastTreeOrder = null; // Reorder OK
		_treeSplitId = newTreeSplitId;
		widget.onTreeSplitIdChanged?.call(newTreeSplitId);
		if (rebuild) {
			try {
				controller._lockSliverListAtEnd();
				setState(() {});
				await SchedulerBinding.instance.endOfFrame;
			}
			finally {
				controller._unlockSliverList();
			}
		}
	}

	Future<void> _autoUpdate() async { 
		if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
			if (!_addedAppResumeCallback) {
				Settings.instance.addAppResumeCallback(_autoUpdate);
			}
			_addedAppResumeCallback = true;
			resetTimer();
			return;
		}
		_addedAppResumeCallback = false;
		if (Settings.instance.isNetworkDown) {
			if (!_addedNetworkResumeCallback) {
				Settings.instance.addNetworkResumeCallback(_autoUpdate);
			}
			_addedNetworkResumeCallback = true;
			resetTimer();
			return;
		}
		_addedNetworkResumeCallback = false;
		await update(source: RefreshableListUpdateSource.timer, extend: true);
	}

	Future<void> update({
		RefreshableListUpdateSource source = RefreshableListUpdateSource.other,
		bool hapticFeedback = false,
		bool extend = false,
		bool mergeTrees = false,
		Duration? overrideMinUpdateDuration
	}) async {
		if (updatingNow.value?.id == widget.id) {
			return updatingNow.value?.future;
		}
		final cancelToken = CancelToken();
		final future = () async {
			final updatingWithId = widget.id;
			List<T>? newList;
			final treeAdapter = widget.treeAdapter;
			try {
				error.value = null;
				Duration minUpdateDuration = widget.minUpdateDuration;
				if (controller.scrollController?.positions.length == 1 && (controller.scrollController!.position.pixels > 0 && (controller.scrollController!.position.pixels <= controller.scrollController!.position.maxScrollExtent))) {
					minUpdateDuration *= 2;
				}
				minUpdateDuration = overrideMinUpdateDuration ?? minUpdateDuration;
				final lastItem = controller._items.tryLast?.item;
				if (mergeTrees) {
					await _mergeTrees(rebuild: true);
				}
				if (extend && treeAdapter != null && lastItem != null && lastItem.representsStubChildren) {
					_refreshableTreeItems.itemLoadingOmittedItemsStarted(lastItem.parentIds, lastItem.id, cancelToken);
					try {
						newList = await treeAdapter.updateWithStubItems(
							originalList!,
							lastItem.representsUnknownStubChildren
								? [ParentAndChildIdentifier.same(lastItem.id)]
								: lastItem.representsKnownStubChildren,
							cancelToken
						);
					}
					catch (e, st) {
						if (mounted && !cancelToken.isCancelled) {
							alertError(context, e, st);
						}
					}
					finally {
						_refreshableTreeItems.itemLoadingOmittedItemsEnded(lastItem);
					}
				}
				else if (extend && lastItem != null && treeAdapter != null && treeAdapter.isPaged && !treeAdapter.getIsPageStub(lastItem.item) && treeAdapter.getParentIds(lastItem.item).isNotEmpty) {
					// If we aren't ending on unloaded pages, first reload the last loaded page
					newList = await treeAdapter.updateWithStubItems(
						originalList!,
						[ParentAndChildIdentifier.same(treeAdapter.getParentIds(lastItem.item).first)],
						cancelToken
					);
				}
				else if (extend && widget.listExtender != null && (originalList?.isNotEmpty ?? false)) {
					final newItems = (await Future.wait([widget.listExtender!(originalList!.last, cancelToken), Future<List<T>?>.delayed(minUpdateDuration)])).first!;
					final filterableAdapter = widget.filterableAdapter;
					if (filterableAdapter != null) {
						// We have the ability to get identifier for each item
						final oldIds = originalList!.map((i) => filterableAdapter(i).$2.id).toSet();
						newList = originalList!.followedBy(newItems.where((newItem) {
							// Item may be already seen in old list
							// This could be because of long time between updates, the item
							// changed in position in the server's list.
							return !oldIds.contains(filterableAdapter(newItem).$2.id);
						})).toList();
					}
					else {
						// Just append the new items
						newList = originalList!.followedBy(newItems).toList();
					}
					if (controller._items.length case int valuesLength) {
						_addedItemsFromExtension = (valuesLength: valuesLength, newItemsCount: newList.length - originalList!.length);
					}
				}
				else {
					final firstUnloadedPageId = controller._items.tryMapOnce((i) => i.item.representsUnloadedPages.tryFirst);
					if (treeAdapter != null && extend && firstUnloadedPageId != null) {
						// Load the first unloaded page
						newList = await treeAdapter.updateWithStubItems(
							originalList!,
							[ParentAndChildIdentifier.same(firstUnloadedPageId)],
							cancelToken
						);
					}
					else {
						// Normal scenario
						newList = (await Future.wait([widget.listUpdater(RefreshableListUpdateOptions(
							source: source,
							cancelToken: cancelToken
						)), Future<List<T>?>.delayed(minUpdateDuration)])).first?.toList();
						if (
							widget.listExtender != null &&
							source.automatic &&
							newList != null &&
							(originalList?.beginsWith(newList) ?? false)
						) {
							// Don't lose extensions from non-interactive update
							newList = originalList;
						}
					}
				}
				if (!mounted) return;
				if (updatingWithId != widget.id) {
					if (updatingNow.value?.id == updatingWithId) {
						updatingNow.value = null;
					}
					return;
				}
				resetTimer();
				lastUpdateTime = DateTime.now();
			}
			catch (e, st) {
				error.value = (e, st);
				if (cancelToken.isCancelled) {
					resetTimer();
				}
				else if (mounted) {
					if (controller.scrollController?.hasOnePosition ?? false) {
						final position = controller.scrollController!.position;
						if (position.extentAfter > 0) {
							showToast(
								context: context,
								message: 'Error loading ${widget.id}: ${e.toStringDio()}',
								icon: CupertinoIcons.exclamationmark_triangle
							);
						}
					}
					if (widget.remedies[e.runtimeType] == null) {
						print('Error refreshing list: ${e.toStringDio()}');
						print(st);
						resetTimer();
						lastUpdateTime = DateTime.now();
					}
					else {
						nextUpdateTime = null;
					}
				}
			}
			await controller.scrollController?.tryPosition?.isScrollingNotifier.waitUntilValue(false);
			if (updatingWithId != widget.id) {
				if (updatingNow.value?.id == updatingWithId) {
					updatingNow.value = null;
				}
				return;
			}
			if (!mounted) return;
			updatingNow.value = null;
			try {
				if (mounted) {
					await ModalRoute.of(context)?.popped.timeout(Duration.zero);
					// Route is popping, just quit
					return;
				}
			}
			on TimeoutException {
				// No popping
			}
			await controller.whenDoneAutoScrolling;
			if (mounted && (newList != null || error.value != null)) {
				if (hapticFeedback) {
					mediumHapticFeedback();
				}
				setState(() {
					originalList = newList ?? originalList;
					sortedList = originalList?.toList();
					if (sortedList != null) {
						_sortList();
					}
				});
			}
			else if (mounted && newList == null && originalList != null && mergeTrees) {
				// Just merge trees
				if (hapticFeedback) {
					mediumHapticFeedback();
				}
				setState(() {});
			}
			else if (originalList == null) {
				// returning null means just use the old list. but here we don't have an old list...
				setState(() {
					error.value = (Exception('listUpdater returned null'), StackTrace.current);
				});
			}
		}();
		Future.microtask(() => updatingNow.value = (id: widget.id, future: future, cancelToken: cancelToken));
		return future;
	}

	Future<void> acceptNewList(List<T> list) async {
		await controller.whenDoneAutoScrolling;
		originalList = list;
		sortedList = list.toList();
		_sortList();
		setState(() {});
	}

	Future<void> _updateWithHapticFeedback() async {
		await update(
			source: RefreshableListUpdateSource.top,
			hapticFeedback: true,
			extend: false,
			mergeTrees: true
		);
	}

	Future<void> _updateOrExtendWithHapticFeedback() async {
		await update(
			source: RefreshableListUpdateSource.bottom,
			hapticFeedback: true,
			extend: true,
			mergeTrees: true
		);
	}

	double? _fastHeightEstimate(RefreshableListItem<T> item) {
		if (_refreshableTreeItems.isItemHidden(item).isHidden) {
			return 0;
		}
		if (item.representsUnloadedPages.isNotEmpty) {
			return 50;
		}
		if (_refreshableTreeItems._dummyCache[item._key] == _DummyStatus.now) {
			// Match to dummy builder
			return _kDummyHeight;
		}
		return null;
	}

	bool _useDummyFor(int itemIndex) {
		if (widget.useAllDummies) {
			return true;
		}
		final range = controller.useDummyItemsInRange;
		return range != null && itemIndex < range.$2 && itemIndex > range.$1;
	}

	Widget _itemBuilder(BuildContext context, RefreshableListItem<T> value, bool dummy) {
		if (widget.staggeredGridDelegate != null) {
			// It can't be done, layout breaks down
			dummy = false;
		}
		if (dummy) {
			_refreshableTreeItems._dummyCache[value._key] = _DummyStatus.now;
		}
		else if (_refreshableTreeItems._dummyCache[value._key] == _DummyStatus.now) {
			_refreshableTreeItems._dummyCache[value._key] = _DummyStatus.previously;
		}
		if (dummy) {
			// Terrible hack
			if (_refreshableTreeItems.isItemHidden(value).isHidden) {
				return const SizedBox(width: double.infinity);
			}
			/// 0 -> 0.1
			final factor = 0.0001 * (identityHashCode(value) % 1000);
			final child = Container(
				margin: const EdgeInsets.all(16),
				width: (widget.gridDelegate == null && widget.staggeredGridDelegate == null) ? double.infinity : null,
				height: (widget.gridDelegate == null && widget.staggeredGridDelegate == null) ? (_kDummyHeight - 32) : null,
				color: Settings.instance.theme.primaryColorWithBrightness(factor)
			);
			if (useTree && value.depth > 0) {
				return Container(
					margin: EdgeInsets.only(
						left: min(estimateWidth(context) / 2, (pow(value.depth, 0.60) * 20) - 5)
					),
					decoration: BoxDecoration(
						border: Border(left: BorderSide(
							width: 5,
							color: ChanceTheme.secondaryColorOf(context).withMinValue(0.5).withSaturation(0.5).shiftHue(value.depth * 25).withOpacity(0.7)
						))
					),
					child: child
				);
			}
			return child;
		}
		Widget child;
		Widget? collapsed;
		CancelToken? loadingOmittedItems;
		final TreeItemCollapseType? isHidden;
		if (widget.treeAdapter != null && useTree) {
			isHidden = context.select<_RefreshableTreeItems<T>, TreeItemCollapseType?>((c) => c.isItemHidden(value));
		}
		else {
			isHidden = null;
		}
		if (widget.treeAdapter != null && (useTree || value.representsStubChildren || value.representsUnloadedPages.isNotEmpty) && !isHidden.isHidden) {
			loadingOmittedItems = context.select<_RefreshableTreeItems<T>, CancelToken?>((c) => c.isItemLoadingOmittedItems(value.parentIds, value.id));
		}
		if (value.representsUnloadedPages.isNotEmpty) {
			final grey = Settings.instance.theme.primaryColorWithBrightness(0.5);
			final single = value.representsUnloadedPages.trySingle;
			if (single != null) {
				child = CupertinoButton(
					padding: const EdgeInsets.all(8),
					onPressed: () => _loadPage(value, value.representsUnloadedPages.first),
					child: Row(
						mainAxisAlignment: MainAxisAlignment.center,
						children: [
							const Icon(CupertinoIcons.doc),
							const SizedBox(width: 8),
							Flexible(
								child: Text(
									'Page ${value.representsUnloadedPages.first.abs()}',
									textAlign: TextAlign.center
								)
							),
							const SizedBox(width: 8),
							const Icon(CupertinoIcons.arrow_up_down)
						]
					)
				);
			}
			else {
				child = CupertinoButton(
					padding: const EdgeInsets.all(8),
					onPressed: () async {
						if (value.representsUnloadedPages.length == 3) {
							_loadPage(value, value.representsUnloadedPages[1]);
						}
						final page = await showAdaptiveDialog<int>(
							context: context,
							barrierDismissible: true,
							builder: (context) => AdaptiveAlertDialog(
								title: const Text('Select Page'),
								content: SizedBox(
									height: 300,
									child: ListView.separated(
										itemCount: value.representsUnloadedPages.length,
										itemBuilder: (context, i) {
											final page = value.representsUnloadedPages[i];
											return CupertinoButton(
												padding: const EdgeInsets.all(4),
												child: Text('Load Page ${-page}'),
												onPressed: () => Navigator.pop(context, page)
											);
										},
										separatorBuilder: (context, i) => const ChanceDivider(),
									)
								),
								actions: [
									AdaptiveDialogAction(
										onPressed: () => Navigator.pop(context),
										child: const Text('Cancel')
									)
								]
							)
						);
						if (page != null) {
							_loadPage(value, page);
						}
					},
					child: Row(
						mainAxisAlignment: MainAxisAlignment.center,
						children: [
							Icon(CupertinoIcons.doc, color: grey),
							const SizedBox(width: 8),
							Flexible(
								child: Text(
									'Pages ${value.representsUnloadedPages[0].abs()}-${value.representsUnloadedPages[value.representsUnloadedPages.length - 1].abs()}',
									textAlign: TextAlign.center,
									style: TextStyle(
										color: grey
									)
								)
							),
							const SizedBox(width: 8),
							Icon(CupertinoIcons.arrow_up_down, color: grey)
						]
					)
				);
			}
			child = Stack(
				children: [
					if (loadingOmittedItems != null) const LinearProgressIndicator(),
					child
				]
			);
		}
		else if (value.representsStubChildren) {
			child = widget.collapsedItemBuilder?.call(
				context: context,
				value: null,
				collapsedChildIds: value.representsKnownStubChildren.map((x) => x.childId).toSet(),
				loading: loadingOmittedItems != null,
				peekContentHeight: null,
				stubChildIds: value.representsKnownStubChildren,
				alreadyDim: false
			) ?? Container(
				height: 30,
				alignment: Alignment.center,
				child: Text('${value.representsKnownStubChildren.length} more replies...')
			);
		}
		else if (isHidden != TreeItemCollapseType.mutuallyChildCollapsed) {
			child = Builder(
				builder: (context) => widget.itemBuilder(context, value.item, value.options)
			);
			collapsed = widget.collapsedItemBuilder?.call(
				context: context,
				value: value.item,
				collapsedChildIds: value.treeDescendantIds,
				loading: loadingOmittedItems != null,
				peekContentHeight: (widget.treeAdapter?.collapsedItemsShowBody ?? false) ? double.infinity : null,
				stubChildIds: null,
				alreadyDim: value.filterCollapsed
			);
			if (value.filterCollapsed && collapsed != null) {
				collapsed = Opacity(
					opacity: 0.5,
					child: collapsed
				);
			}
		}
		else {
			child = const SizedBox(width: double.infinity);
		}
		if (widget.treeAdapter != null && useTree) {
			if (isHidden.isHidden) {
				// Avoid possible heavy build+layout cost for hidden items
				child = const SizedBox(width: double.infinity);
			}
			else if (isHidden == TreeItemCollapseType.mutuallyCollapsed ||
								isHidden == TreeItemCollapseType.topLevelCollapsed ||
								isHidden == TreeItemCollapseType.parentOfNewInsert) {
				final Set<int> collapsedChildIds;
				if (isHidden == TreeItemCollapseType.parentOfNewInsert) {
					collapsedChildIds = _refreshableTreeItems.newlyInsertedItems.entries.where((e) {
						if (e.key.length < (value.parentIds.length + 2)) {
							return false;
						}
						for (int i = 0; i < value.parentIds.length; i++) {
							if (e.key[i] != value.parentIds[i]) {
								return false;
							}
						}
						return e.key[value.parentIds.length] == value.id;
					}).map((x) => x.key.last).toSet();
				}
				else {
					collapsedChildIds = value.treeDescendantIds;
				}
				child = widget.collapsedItemBuilder?.call(
					context: context,
					value: value.item,
					collapsedChildIds: collapsedChildIds,
					loading: loadingOmittedItems != null,
					peekContentHeight: isHidden == TreeItemCollapseType.mutuallyCollapsed ? 90 : double.infinity,
					stubChildIds: null,
					alreadyDim: false
				) ?? Stack(
					alignment: Alignment.bottomRight,
					children: [
						child,
						CupertinoButton(
							padding: EdgeInsets.zero,
							onPressed: isHidden != TreeItemCollapseType.parentOfNewInsert ? null : () {
								_refreshableTreeItems.revealNewInsertsBelow(value);
							},
							child: Row(
								mainAxisSize: MainAxisSize.min,
								children: [
									const Icon(CupertinoIcons.chevron_down, size: 20),
									Text(collapsedChildIds.toString())
								]
							)
						)
					]
				);
			}
			else {
				child = AnimatedCrossFade(
					key: ValueKey(value._key),
					duration: _treeAnimationDuration,
					sizeCurve: Curves.ease,
					firstCurve: Curves.ease,
					//secondCurve: Curves.ease,
					firstChild: child,
					secondChild: (!isHidden.isHidden && !value.representsStubChildren) ? (collapsed ?? const SizedBox(
						height: 30,
						width: double.infinity,
						child: Text('Something hidden')
					)) : const SizedBox(
						height: 0,
						width: double.infinity
					),
					crossFadeState: isHidden == null ? CrossFadeState.showFirst : CrossFadeState.showSecond,
				);
			}
			if (value.parentIds.isNotEmpty && !isHidden.isHidden) {
				child = widget.treeAdapter!.wrapTreeChild(child, value.parentIds);
			}
			if (isHidden != TreeItemCollapseType.mutuallyChildCollapsed) {
				child = AnimatedSize(
					duration: _treeAnimationDuration,
					alignment: Alignment.topCenter,
					curve: Curves.ease,
					child: child
				);
				child = DefaultGestureDetector(
					behavior: HitTestBehavior.translucent,
					onTap: loadingOmittedItems?.cancel ?? () async {
						if (!value.representsStubChildren) {
							if (isHidden == TreeItemCollapseType.mutuallyCollapsed) {
								context.read<_RefreshableTreeItems<T>>().swapSubtreeTo(value);
								Future.delayed(_treeAnimationDuration, () => controller._alignToItemIfPartiallyAboveFold(value));
							}
							else if (isHidden == TreeItemCollapseType.parentOfNewInsert) {
								context.read<_RefreshableTreeItems<T>>().revealNewInsertsBelow(value);
								// At the same time, trigger any loading
								final stubParent = controller.items.tryFirstWhere((otherItem) {
									return otherItem.item == value.item &&
											otherItem.id == value.id &&
											otherItem.parentIds == value.parentIds &&
											otherItem.representsStubChildren;
								});
								if (stubParent != null) {
									_loadOmittedItems(stubParent);
								}
							}
							else if (isHidden != null) {
								context.read<_RefreshableTreeItems<T>>().unhideItem(value);
								if (isHidden == TreeItemCollapseType.topLevelCollapsed) {
									final stubParent = controller.items.tryFirstWhere((otherItem) {
										return otherItem.item == value.item &&
												otherItem.id == value.id &&
												otherItem.parentIds == value.parentIds &&
												otherItem.representsStubChildren;
									});
									if (stubParent != null) {
										_loadOmittedItems(stubParent);
									}
								}
							}
							else if (value.treeDescendantIds.isNotEmpty || !(widget.treeAdapter?.collapsedItemsShowBody ?? false)) {
								context.read<_RefreshableTreeItems<T>>().hideItem(value);
								controller._alignToItemIfPartiallyAboveFold(value);
							}
						}
						else {
							_loadOmittedItems(value);
						}
					},
					child: child
				);
			}
		}
		else if (widget.treeAdapter != null && value.representsStubChildren) {
			child = GestureDetector(
				behavior: HitTestBehavior.translucent,
				onTap: loadingOmittedItems?.cancel ?? () => _loadOmittedItems(value),
				child: child
			);
		}
		if (value.highlighted) {
			child = ClipRect(
				child: ColorFiltered(
					colorFilter: ColorFilter.mode(ChanceTheme.secondaryColorOf(context).withOpacity(0.2), BlendMode.srcOver),
					child: child
				)
			);
		}
		if (value.pinned) {
			child = ClipRect(
				child: ColorFiltered(
					colorFilter: ColorFilter.mode(ChanceTheme.secondaryColorOf(context).withOpacity(0.05), BlendMode.srcOver),
					child: child
				)
			);
		}
		final depth = value.depth;
		if (depth > 0 && useTree) {
			child = Container(
				margin: EdgeInsets.only(left: min(MediaQuery.sizeOf(context).width / 2, (pow(depth, 0.60) * 20) - 5)),
				decoration: BoxDecoration(
					border: Border(left: BorderSide(
						width: 5,
						color: ChanceTheme.secondaryColorOf(context).withMinValue(0.5).withSaturation(0.5).shiftHue(value.depth * 25).withOpacity(0.7)
					))
				),
				child: child
			);
		}
		return child;
	}

	bool _shouldPreCollapseOnSubsequentEncounter(RefreshableListItem<T> item, _TreeNode<RefreshableListItem<T>> node) {
		if (node.children.isNotEmpty) {
			return true;
		}
		final width = estimateWidth(context, listen: false);
		final height = (widget.treeAdapter?.estimateHeight(item.item, width) ?? 0);
		final parentCount = widget.treeAdapter?.getParentIds(item.item).length ?? 0;
		return height > (100 * max(parentCount, 3));
	}

	/// Group into (a) | (a, b) | (a, b+c+d, e)
	Iterable<RefreshableListItem<T>> _groupUnloadedPages(List<RefreshableListItem<T>> pages) {
		final Iterable<List<RefreshableListItem<T>>> groups;
		if (pages.length < 3) {
			groups = pages.map((p) => [p]);
		}
		else {
			groups = [[pages[0]], pages.sublist(1, pages.length - 1), [pages[pages.length - 1]]];
		}
		return groups.map((g) => RefreshableListItem(
			item: g.first.item, // arbitrary
			options: const RefreshableListItemOptions(), // arbitrary
			id: g.first.id, // arbitrary
			state: this,
			representsUnloadedPages: g.map((i) => i.id).toList()
		));
	}

	({
		List<RefreshableListItem<T>> linear,
		int? treeSplitId,
		_Tree<T> tree,
		bool initiallyCollapseSecondLevelReplies,
		bool repliesToOPAreTopLevel,
		bool newRepliesAreLinear
	})? _lastTree;
	_Tree<T> _reassembleAsTree(List<RefreshableListItem<T>> linear) {
		// In case the list is not in sequential order by id
		final orphans = <int, List<_TreeNode<RefreshableListItem<T>>>>{};
		final orphanStubs = <int, List<int>>{};
		final treeMap = <int, _TreeNode<RefreshableListItem<T>>>{};
		// Old tree + some additions at the bottom
		final treeRoots1 = <_TreeNode<RefreshableListItem<T>>>[];
		// New tree
		final treeRoots2 = <_TreeNode<RefreshableListItem<T>>>[];

		final adapter = widget.treeAdapter;
		if (adapter == null) {
			print('Tried to reassemble a tree of $T with a null adapter');
			return (tree: linear, automaticallyCollapsed: [], automaticallyTopLevelCollapsed: {});
		}

		final lastTree = _lastTree;
		if (lastTree != null &&
		    _treeSplitId == lastTree.treeSplitId &&
				linear.length == lastTree.linear.length &&
				adapter.initiallyCollapseSecondLevelReplies == lastTree.initiallyCollapseSecondLevelReplies &&
				adapter.repliesToOPAreTopLevel == lastTree.repliesToOPAreTopLevel &&
				adapter.newRepliesAreLinear == lastTree.newRepliesAreLinear) {
			bool matching = true;
			bool patchedAnyItems = false;
			for (int i = 0; i < linear.length; i++) {
				if (!identical(linear[i]._key, lastTree.linear[i]._key)) {
					matching = false;
					break;
				}
				if (linear[i].filterCollapsed != lastTree.linear[i].filterCollapsed) {
					// Change in filters
					matching = false;
					break;
				}
				if (adapter.getHasOmittedReplies(linear[i].item) != adapter.getHasOmittedReplies(lastTree.linear[i].item)) {
					// New omitted replies exist
					matching = false;
					break;
				}
				if (adapter.getIsStub(linear[i].item) != adapter.getIsStub(lastTree.linear[i].item)) {
					// Loaded exactly this stub
					matching = false;
					break;
				}
				if (linear[i].item != lastTree.linear[i].item) {
					patchedAnyItems = true;
					// Just value changed, not tree structure
					for (final item in lastTree.tree.tree) {
						if (item.id == linear[i].id) {
							item.item = linear[i].item;
						}
					}
					lastTree.linear[i].item = linear[i].item;
				}
				else if (linear[i].options != lastTree.linear[i].options) {
					// Same item but different options
					patchedAnyItems = true;
					for (final item in lastTree.tree.tree) {
						if (item.id == linear[i].id) {
							item.options = linear[i].options;
						}
					}
					lastTree.linear[i].options = linear[i].options;
				}
			}
			if (matching) {
				if (patchedAnyItems) {
					// Because we mutated RefreshableListItem, it may not rebuild on its own
					forceRebuildId++;
				}
				return lastTree.tree;
			}
		}

		final firstTreeBuild = _treeSplitId == null;
		final treeSplitId = _treeSplitId ?? linear.fold<int>(0, (m, i) => max(m, i.representsKnownStubChildren.fold<int>(i.id, (n, j) => max(n, j.childId))));
		if (_treeSplitId == null && linear.length > 1) {
			// Set initial tree-split ID to last post in thread
			_treeSplitId = treeSplitId;
			widget.onTreeSplitIdChanged?.call(treeSplitId);
		}
		final Set<int> itemsWithOmittedReplies = {};

		void visitLinear(RefreshableListItem<T> item) {
			final id = adapter.getId(item.item);
			final node = _TreeNode(item.copyWith(), id, adapter.getHasOmittedReplies(item.item));
			if (node.hasOmittedReplies) {
				itemsWithOmittedReplies.add(id);
			}
			treeMap[id] = node;
			node.children.addAll(orphans[id] ?? []);
			orphans.remove(id);
			node.stubChildIds.addAll(orphanStubs[id] ?? []);
			orphanStubs.remove(id);
			final parentIds = adapter.getParentIds(item.item).toList();
			if (id == adapter.opId) {
				treeRoots1.insert(0, node);
			}
			else if (parentIds.isEmpty) {
				treeRoots1.add(node);
			}
			else if (adapter.newRepliesAreLinear && id > treeSplitId) {
				final peekLastTreeItemSoFar = treeRoots1.tryLast?.lastDescendant;
				final acceptableParentIds = peekLastTreeItemSoFar?.ownershipChain.toSet() ?? {};
				parentIds.removeWhere((parentId) => parentId <= treeSplitId && !acceptableParentIds.contains(parentId));
				if (parentIds.isEmpty) {
					treeRoots2.add(node);
				}
				else {
					node.parents.addAll(parentIds.tryMap((id) => treeMap[id]));
				}
			}
			else {
				// Will only work with sequential ids
				node.parents.addAll(parentIds.tryMap((id) => treeMap[id]));
			}
			if (parentIds.length > 1) {
				// Avoid multiple child subtrees in the same root tree
				// This doesn't handle orphans case, but that should only happen on Reddit,
				// which doesn't have multiple parents anyways.
				final parents = parentIds.tryMap((id) => treeMap[id]).toList();
				// Sort to process from shallowest to deepest
				parents.sort((a, b) => a.id.compareTo(b.id));
				int? findToDelete() {
					for (int i = 0; i < parents.length; i++) {
						for (int j = i + 1; j < parents.length; j++) {
							if (parents[j].find(parents[i].id)) {
								// child already quotes the parent
								return i;
							}
						}
					}
					return null;
				}
				int? toDelete;
				do {
					toDelete = findToDelete();
					if (toDelete != null) {
						final deleted = parents.removeAt(toDelete);
						parentIds.remove(deleted.id);
					}
				} while (toDelete != null);
			}
			if (adapter.getIsStub(item.item)) {
				for (final parentId in parentIds) {
					treeMap[parentId]?.stubChildIds.add(node.id);
					if (treeMap[parentId] == null) {
						orphanStubs.putIfAbsent(parentId, () => []).add(node.id);
					}
				}
			}
			else {
				bool foundAParent = false;
				bool foundOP = false;
				_TreeNode<RefreshableListItem<T>>? parentPage;
				final orphanParents = <int>[];
				for (final parentId in parentIds) {
					if (parentId == id) {
						// Disallow recursive replies
						continue;
					}
					if (adapter.repliesToOPAreTopLevel && parentId == adapter.opId && treeMap.containsKey(parentId)) {
						foundAParent = true;
						foundOP = true;
						continue;
					}
					if (adapter.isPaged && parentId.isNegative) {
						final page = treeMap[parentId];
						if (page != null) {
							parentPage = page;
							continue;
						}
					}
					treeMap[parentId]?.children.add(node);
					if (treeMap[parentId] == null) {
						orphanParents.add(parentId);
					}
					else {
						foundAParent = true;
					}
				}
				if (!foundAParent) {
					if (parentPage != null) {
						// Only put under page if no other parent
						parentPage.children.add(node);
					}
					else {
						for (final parentId in orphanParents) {
							orphans.putIfAbsent(parentId, () => []).add(node);
						}
					}
				}
				if (foundOP) {
					if (adapter.repliesToOPAreTopLevel) {
						treeRoots1.add(node);
					}
					else {
						final op = treeMap[adapter.opId];
						if (op != null) {
							op.children.add(node);
						}
						else {
							orphans.putIfAbsent(adapter.opId, () => []).add(node);
						}
					}
				}
			}
		}

		final Iterable<RefreshableListItem<T>> oldItems;
		final lastTreeOrder = _lastTreeOrder;
		if (lastTreeOrder != null) {
			// We need to sort the old roots first. or else we could have wrong order
			// with newRepliesAreLinear. The optimization to add newest children in tree mode.
			// This maybe is't perfect, there could be reordered final children with
			// same final root in both trees. But it's an edge case.
			oldItems = linear.where((item) => item.id <= treeSplitId).toList(growable: false);
			const infiniteIndex = 1 << 50;
			mergeSort(linear, compare: (a, b) {
				final idxA = lastTreeOrder.treeRootIndexLookup[a.id] ?? infiniteIndex;
				final idxB = lastTreeOrder.treeRootIndexLookup[b.id] ?? infiniteIndex;
				return idxA.compareTo(idxB);
			});
		}
		else {
			oldItems = linear.where((item) => item.id <= treeSplitId);
		}

		oldItems.forEach(visitLinear);
		linear.where((item) => item.id > treeSplitId).forEach(visitLinear);

		final treeRoots = <_TreeNode<RefreshableListItem<T>>>[];
		// Combine adjacent unloaded pages
		final unloadedPages = <RefreshableListItem<T>>[];
		for (final root in treeRoots1.followedBy(treeRoots2)) {
			if (root.children.isEmpty
			    && adapter.getHasOmittedReplies(root.item.item)
					&& adapter.getIsPageStub(root.item.item)) {
				unloadedPages.add(root.item);
			}
			else {
				if (unloadedPages.isNotEmpty) {
					treeRoots.addAll(_groupUnloadedPages(unloadedPages).map((g) => _TreeNode(g, g.id, false)));
					unloadedPages.clear();
				}
				treeRoots.add(root);
			}
		}
		if (unloadedPages.isNotEmpty) {
			treeRoots.addAll(_groupUnloadedPages(unloadedPages).map((g) => _TreeNode(g, g.id, false)));
		}

		final stubRoots = <_TreeNode<RefreshableListItem<T>>>[];

		if (!adapter.isPaged) {
			final lastTreeOrder = _lastTreeOrder;
			if (lastTreeOrder != null) {
				const infiniteIndex = 1 << 50;
				mergeSort(treeRoots, compare: (a, b) {
					final idxA = lastTreeOrder.treeRootIndexLookup[a.id] ?? infiniteIndex;
					final idxB = lastTreeOrder.treeRootIndexLookup[b.id] ?? infiniteIndex;
					return idxA.compareTo(idxB);
				});
				for (final entry in treeMap.entries) {
					mergeSort(entry.value.children, compare: (a, b) {
						final idxA = lastTreeOrder.treeChildrenIndexLookup[entry.key]?[a.id] ?? infiniteIndex;
						final idxB = lastTreeOrder.treeChildrenIndexLookup[entry.key]?[b.id] ?? infiniteIndex;
						return idxA.compareTo(idxB);
					});
				}
			}

			final newOrder = _lastTreeOrder = (
				treeRootIndexLookup: {
					for (int i = 0; i < treeRoots.length; i++)
						treeRoots[i].id: i
				},
				treeChildrenIndexLookup: treeMap.map((k, v) => MapEntry(k, {
					for (int i = 0; i < v.children.length; i++)
						v.children[i].id: i
				}))
			);
			if (lastTreeOrder != null) {
				// The cause of treeOrder is to avoid position change on update due to
				// upvotes difference or something.
				// In case of add/remove, we want to preserve position to make
				// filtering/unfiltering look better, instead of always having the
				// unfiltered item go to the bottom.
				void mergeTreeOrders({required Map<int, int> current, required Map<int, int> old}) {
					if (old.isEmpty) {
						return;
					}
					final oldCurrentLength = current.length;
					current.addAll(old);
					final offset = current.length - oldCurrentLength;
					for (final key in current.keys) {
						if (!old.containsKey(key)) {
							// This is a new item, fix the index due to newly inserted items
							current[key] = current[key]! + offset;
						}
					}
				}
				mergeTreeOrders(current: newOrder.treeRootIndexLookup, old: lastTreeOrder.treeRootIndexLookup);
				for (final order in newOrder.treeChildrenIndexLookup.entries) {
					final old = lastTreeOrder.treeChildrenIndexLookup[order.key];
					if (old != null) {
						mergeTreeOrders(current: order.value, old: old);
					}
				}
			}
		}

		final out = <RefreshableListItem<T>>[];
		final Map<int, RefreshableListItem<T>> encountered = {};
		final precollapseCache = <T, bool>{};
		final automaticallyCollapsed = <List<int>>[];
		final Set<int> automaticallyTopLevelCollapsed = {};
		Set<int> dumpNode(_TreeNode<RefreshableListItem<T>> node, List<int> parentIds, {bool addOmittedChildNode = true}) {
			if (out.length > (kDebugMode ? 15000 : 50000)) {
				// Bail
				throw const _TreeTooDeepException();
			}
			final item = node.item.copyWith(parentIds: parentIds);
			out.add(item);
			final ids = [
				...parentIds,
				node.id
			];
			final willAddOmittedChildNode = addOmittedChildNode && (node.stubChildIds.isNotEmpty || node.hasOmittedReplies);
			if (node.parents.length > 1) {
				if (precollapseCache.putIfAbsent(node.item.item, () => _shouldPreCollapseOnSubsequentEncounter(item, node))) {
					_refreshableTreeItems.defaultPrimarySubtreeParents.putIfAbsent(node.id, () => parentIds.tryLast ?? -1);
				}
			}
			else if (adapter.initiallyCollapseSecondLevelReplies &&
							 item.depth == 0 && // TODO: Test it
							 (node.children.isNotEmpty || willAddOmittedChildNode)) {
				automaticallyTopLevelCollapsed.add(node.id);
			}
			if (item.filterCollapsed) {
				automaticallyCollapsed.add(ids);
			}
			if (!adapter.newRepliesAreLinear &&
			    node.id > treeSplitId &&
					parentIds.isNotEmpty) {
				_refreshableTreeItems.newlyInsertedItems.putIfAbsent(ids, () => false);
				_refreshableTreeItems._cache.removeWhere((k, _) => parentIds.contains(k.thisId));
				if (parentIds.isEmpty) {
					_refreshableTreeItems._cache.remove(_internHashKey(_RefreshableTreeItemsCacheKey([], adapter.opId, false)));
				}
			}
			for (final child in node.children) {
				if (child.id == node.id) {
					print('Skipping recursive child of ${node.id}');
					continue;
				}
				item.treeDescendantIds.add(child.id);
				item.treeDescendantIds.addAll(dumpNode(child, ids.toList()));
			}
			if (willAddOmittedChildNode) {
				if (
					(
						// Node has has unknown further replies, and didn't in the previous tree
						(node.hasOmittedReplies && !_refreshableTreeItems.itemsWithUnknownStubReplies.contains(node.id)) ||
						// Node has known further replies, and didn't have any in the previous tree
						(node.stubChildIds.isNotEmpty && !node.stubChildIds.any((c) => c <= treeSplitId))
					) &&
					// We can trust treeSplitId,itemsWithUnknownStubReplies
					!firstTreeBuild
				) {
					_refreshableTreeItems.newlyInsertedStubRepliesForItem.putIfAbsent(ids, () => false);
					_refreshableTreeItems._cache.removeWhere((k, _) => k.thisId == node.id);
				}
				out.add(item.copyWith(
					representsKnownStubChildren: node.stubChildIds.map((childId) => ParentAndChildIdentifier(
						parentId: node.id,
						childId: childId
					)).toList(),
					representsUnknownStubChildren: node.hasOmittedReplies
				));
				item.treeDescendantIds.addAll(node.stubChildIds);
				if (node.hasOmittedReplies) {
					item.treeDescendantIds.add(-1);
				}
			}
			encountered[node.id] = item;
			return item.treeDescendantIds;
		}
		_TreeNode<RefreshableListItem<T>>? firstRoot;
		if (treeRoots.isNotEmpty) {
			firstRoot = treeRoots.removeAt(0);
			dumpNode(firstRoot, firstRoot.parents.map((t) => t.id).toList(), addOmittedChildNode: false);
		}
		final Set<int> orphanEncountered = {};
		for (final pair in orphans.entries) {
			for (final orphan in pair.value) {
				if (encountered.containsKey(orphan.id) || orphanEncountered.contains(orphan.id)) {
					// It is seen somewhere else in the tree
					continue;
				}
				insertIntoSortedList(
					list: treeRoots,
					sortMethods: widget.sortMethods.isEmpty ? <Comparator<_TreeNode<RefreshableListItem<T>>>>[
						(a, b) => a.id.compareTo(b.id)
					] : widget.sortMethods.map((c) => (_TreeNode<RefreshableListItem<T>> a, _TreeNode<RefreshableListItem<T>> b) => c(a.item.item, b.item.item)).toList(),
					reverseSort: widget.reverseSort,
					item: orphan
				);
				orphanEncountered.add(orphan.id);
			}
		}
		for (final root in treeRoots) {
			if (adapter.getIsStub(root.item.item)) {
				stubRoots.add(root);
				continue;
			}
			dumpNode(root, root.parents.any((r) => r.id == adapter.opId) ? [adapter.opId] : []);
		}
		if (firstRoot != null && (firstRoot.stubChildIds.isNotEmpty || firstRoot.hasOmittedReplies || stubRoots.isNotEmpty)) {
			if (
				(
					// Node has has unknown further replies, and didn't in the previous tree
					firstRoot.hasOmittedReplies && !_refreshableTreeItems.itemsWithUnknownStubReplies.contains(firstRoot.id) ||
					// Node has known further replies, and didn't have any in the previous tree
					!(
						(firstRoot.stubChildIds.isNotEmpty && firstRoot.stubChildIds.any((c) => c <= treeSplitId)) ||
						stubRoots.any((r) => r.id <= treeSplitId)
					)
				) &&
				// We can trust treeSplitId,itemsWithUnknownStubReplies
				!firstTreeBuild
			) {
				_refreshableTreeItems.newlyInsertedStubRepliesForItem.putIfAbsent([firstRoot.id], () => false);
				_refreshableTreeItems._cache.removeWhere((k, _) => k.thisId == firstRoot?.id);
			}
			out.add(firstRoot.item.copyWith(
				parentIds: [],
				representsKnownStubChildren: [
					...firstRoot.stubChildIds.map((childId) => ParentAndChildIdentifier(
						parentId: firstRoot!.id,
						childId: childId
					)),
					...stubRoots.map((r) => ParentAndChildIdentifier(
						parentId: r.parents.tryLast?.id ?? firstRoot!.id,
						childId: r.id
					))
				].toList(),
				representsUnknownStubChildren: firstRoot.hasOmittedReplies,
				depth: 0
			));
		}
		if (out.isNotEmpty) {
			if (adapter.getIsPageStub(out.last.item) && out.last.representsUnknownStubChildren) {
				// Don't show "load more" stub for last page.
				// Reloading the whole list is the right thing to do instead.
				out.removeLast();
			}
		}
		if (!adapter.newRepliesAreLinear && linear.length > 1) {
			// In "old" tree behaviour, we use treeSplitId to track new insertions
			// It needs to be updated after each rebuild
			final treeSplitId = _treeSplitId = linear.fold<int>(0, (m, i) => max(m, i.representsKnownStubChildren.fold<int>(i.id, (n, j) => max(n, j.childId))));
			widget.onTreeSplitIdChanged?.call(treeSplitId);
		}
		_refreshableTreeItems.itemsWithUnknownStubReplies.addAll(itemsWithOmittedReplies);
		_needToTransitionNewlyInsertedItems = true;
		if (!adapter.newRepliesAreLinear) {
			// Reveal all new inserts at the bottom of the list
			// Showing them won't cause any offset jumps since they are below the existing scroll position.
			for (final item in out.reversed) {
				if (item.parentIds.isEmpty && !item.representsStubChildren) {
					// Parentless items are never set to "newly-inserted" state
					continue;
				}
				if (!_refreshableTreeItems.isItemHidden(item).isHidden) {
					// Clear polluted cache
					_refreshableTreeItems._cache.remove(item._key);
					break;
				}
				_refreshableTreeItems.revealNewInsert(item, quiet: true, stubOnly: item.representsStubChildren);
			}
		}
		final tree = (tree: out, automaticallyCollapsed: automaticallyCollapsed, automaticallyTopLevelCollapsed: automaticallyTopLevelCollapsed);
		_lastTree = (
			linear: linear.toList(growable: false),
			treeSplitId: _treeSplitId,
			tree: tree,
			initiallyCollapseSecondLevelReplies: adapter.initiallyCollapseSecondLevelReplies,
			repliesToOPAreTopLevel: adapter.repliesToOPAreTopLevel,
			newRepliesAreLinear: adapter.newRepliesAreLinear
		);
		return tree;
	}

	bool _matchesSearchFilter(String imageboardKey, Filterable item, RegExp query) {
		return (_searchStrings[item] ??= [
			item.id.toString(),
			if (widget.includeImageboardKeyAndBoardInSearchString) ...[
				imageboardKey,
				// Include the slashes
				ImageboardRegistry.instance.getImageboard(imageboardKey)?.site.formatBoardName(item.board) ?? item.board
			],
			...defaultPatternFields.map((field) {
				return item.getFilterFieldText(field) ?? '';
			}),
		].join(' ')).contains(query);
	}

	bool _handleStatusBarTap() {
		if (!mounted || controller.scrollController?.tryPosition == null) {
			// probably dead
			return false;
		}
		// Logic copied from Scaffold / CupertinoPageScaffold
		controller.animateToIndex(0,
			duration: platformIsMaterial ? const Duration(milliseconds: 1000) : const Duration(milliseconds: 500),
			curve: platformIsMaterial ? Curves.easeOutCirc : Curves.linearToEaseOut
		);
		return true;
	}

	@override
	Widget build(BuildContext context) {
		ModalRoute.find(context)?.handleStatusBarTap = _handleStatusBarTap;
		controller.reportPrimaryScrollController(PrimaryScrollController.maybeOf(context));
		controller.topOffset = MediaQuery.paddingOf(context).top;
		controller.bottomOffset = MediaQuery.paddingOf(context).bottom;
		final RegExp? queryPattern;
		if (_searchController.text.isNotEmpty) {
			queryPattern = RegExp(RegExp.escape(_searchController.text), caseSensitive: false);
		}
		else {
			queryPattern = null;
		}
		final sortedList = this.sortedList;
		if (sortedList != null) {
			final filterableAdapter = widget.filterableAdapter;
			final pinnedValues = <RefreshableListItem<T>>[];
			List<RefreshableListItem<T>> values = [];
			filteredValues = <RefreshableListItem<T>>[];
			final filter = Filter.of(context);
			final hideThumbnailsOptions = RefreshableListItemOptions(
				hideThumbnails: true,
				queryPattern: queryPattern
			);
			final normalOptions = RefreshableListItemOptions(
				hideThumbnails: false,
				queryPattern: queryPattern
			);
			for (final item in sortedList) {
				final pair = filterableAdapter?.call(item);
				if (pair != null) {
					if (queryPattern != null && !_matchesSearchFilter(pair.$1, pair.$2, queryPattern)) {
						continue;
					}
					final result = widget.useFiltersFromContext && filterableAdapter != null ? filter.filter(pair.$1, pair.$2) : null;
					if (result != null) {
						final options = result.type.hideThumbnails ? hideThumbnailsOptions : normalOptions;
						bool pinned = false;
						if (result.type.pinToTop && widget.allowReordering) {
							pinned = true;
							pinnedValues.add(RefreshableListItem(
								item: item,
								options: options,
								id: pair.$2.id,
								highlighted: result.type.highlight,
								pinned: true,
								state: this
							));
						}
						if (result.type.autoSave) {
							widget.onWantAutosave?.call(item);
						}
						final autoWatch = result.type.autoWatch;
						if (autoWatch != null) {
							widget.onWantAutowatch?.call(item, autoWatch);
						}
						if (result.type.hide) {
							filteredValues.add(RefreshableListItem(
								item: item,
								options: options,
								id: pair.$2.id,
								filterReason: result.reason,
								state: this
							));
						}
						else if (!pinned) {
							values.add(RefreshableListItem(
								item: item,
								options: options,
								id: pair.$2.id,
								highlighted: result.type.highlight,
								filterCollapsed: result.type.collapse,
								state: this
							));
						}
						continue;
					}
				}
				values.add(RefreshableListItem(
					item: item,
					options: normalOptions,
					id: pair?.$2.id ?? widget.treeAdapter?.getId(item) ?? 0,
					state: this
				));
			}
			_treeBuildingFailed = false;
			values.insertAll(0, pinnedValues);
			if (widget.useTree) {
				try {
					final tree = _reassembleAsTree(values);
					values = tree.tree;
					_automaticallyCollapsedItems.clear();
					for (final collapsed in tree.automaticallyCollapsed) {
						if (!_overrideExpandAutomaticallyCollapsedItems.any((x) => listEquals(x, collapsed))) {
							_automaticallyCollapsedItems.add(collapsed);
						}
					}
					_automaticallyCollapsedTopLevelItems.clear();
					for (final id in tree.automaticallyTopLevelCollapsed) {
						if (!_overrideExpandAutomaticallyCollapsedTopLevelItems.contains(id)) {
							_automaticallyCollapsedTopLevelItems.add(id);
						}
					}
				}
				on _TreeTooDeepException {
					_treeBuildingFailed = true;
				}
				final filter = widget.treeAdapter?.filter;
				if (filter != null) {
					values = values.where(filter).toList();
				}
			}
			else if (widget.treeAdapter != null) {
				final adapter = widget.treeAdapter!;
				RefreshableListItem<T>? stubItem;
				final unloadedPages = <RefreshableListItem<T>>[];
				RefreshableListItem<T>? deferredUnloadedPage;
				final items = values;
				values = [];
				for (final item in items) {
					final isUnloadedPage = adapter.getHasOmittedReplies(item.item) && adapter.getIsPageStub(item.item);
					if (stubItem != null && !adapter.getIsStub(item.item)) {
						values.add(stubItem);
						stubItem = null;
					}
					if (unloadedPages.isNotEmpty && !isUnloadedPage) {
						if (adapter.getParentIds(item.item).contains(unloadedPages.last.id)) {
							// We are in a child of the last page in this unloaded group. Defer the stub item.
							deferredUnloadedPage = unloadedPages.removeLast();
							if (unloadedPages.isNotEmpty) {
								// Still dump any earlier unloaded pages in the right spot
								values.addAll(_groupUnloadedPages(unloadedPages));
								unloadedPages.clear();
							}
							values.add(deferredUnloadedPage); // Entry for top of the page
						}
						else {
							values.addAll(_groupUnloadedPages(unloadedPages));
							unloadedPages.clear();
						}
					}
					if (deferredUnloadedPage != null) {
						if (!adapter.getParentIds(item.item).contains(deferredUnloadedPage.id)) {
							// We now out of the deferred pages' children
							// Show the entry for the bottom of the partially loaded page
							values.add(RefreshableListItem(
								id: deferredUnloadedPage.id,
								options: const RefreshableListItemOptions(),
								item: deferredUnloadedPage.item,
								state: this,
								representsUnloadedPages: [deferredUnloadedPage.id]
							));
							deferredUnloadedPage = null;
						}
					}
					if (adapter.getIsStub(item.item)) {
						stubItem ??= RefreshableListItem(
							item: item.item, // Arbitrary
							options: const RefreshableListItemOptions(), // Arbitrary
							id: item.id, // Arbitrary
							representsKnownStubChildren: [],
							state: this
						);
						stubItem.representsKnownStubChildren.add(ParentAndChildIdentifier(
							parentId: adapter.getParentIds(item.item).tryFirst ?? adapter.opId,
							childId: adapter.getId(item.item)
						));
					}
					else if (isUnloadedPage) {
						unloadedPages.add(item);
					}
					else {
						values.add(item);
						if (adapter.getHasOmittedReplies(item.item)) {
							stubItem ??= RefreshableListItem(
								item: item.item, // Arbitrary
								options: const RefreshableListItemOptions(), // Arbitrary
								id: item.id, // Arbitrary
								representsKnownStubChildren: [],
								state: this
							);
							stubItem.representsKnownStubChildren.add(ParentAndChildIdentifier(
								parentId: adapter.getId(item.item),
								childId: adapter.getId(item.item)
							));
						}
					}
				}
				if (unloadedPages.isNotEmpty) {
					values.addAll(_groupUnloadedPages(unloadedPages));
				}
				// Intentionally not adding deferred final page. It confuses reloading.
				// If you just pull to refresh you will get latest page.
				if (stubItem != null) {
					values.add(stubItem);
				}
			}
			controller.setItems(values);
			final addedItemsFromExtension = _addedItemsFromExtension;
			_addedItemsFromExtension = null;
			if (searching && addedItemsFromExtension != null && addedItemsFromExtension.valuesLength == values.length) {
				// The list was extended, but no new items were visible. Show a toast to make it clear the update worked.
				Future.microtask(() {
					if (context.mounted) {
						showToast(
							context: context,
							message: '${describeCount(addedItemsFromExtension.newItemsCount, 'new item')} loaded',
							icon: CupertinoIcons.refresh
						);
					}
				});
			}
			if (filteredValues.isEmpty) {
				// Don't auto open filtered values after clearing it before
				_showFilteredValues = false;
			}
			final shakeAnimation = CurvedAnimation(
				curve: Curves.easeInOutCubic,
				parent: _footerShakeAnimation
			);
			final theme = context.watch<SavedTheme>();
			final dividerColor = theme.primaryColorWithBrightness(0.2);
			return PopScope(
				canPop: !_searchTapped,
				onPopInvokedWithResult: (didPop, result) {
					if (!didPop) {
						closeSearch();
					}
				},
				child: NotificationListener<ScrollNotification>(
					key: ValueKey(widget.id),
					onNotification: (notification) {
						if (updatingNow.value != null) {
							return false;
						}
						final bool isScrollEnd = (notification is ScrollEndNotification) || (notification is ScrollUpdateNotification && notification.dragDetails == null);
						final bool plausible = DateTime.now().difference(_lastPointerUpTime) < const Duration(milliseconds: 100);
						if (isScrollEnd && plausible) {
							if (!_overscrollEndingNow) {
								double overscroll = controller.scrollController!.position.pixels - controller.scrollController!.position.maxScrollExtent;
								if (overscroll > _overscrollTriggerThreshold && !widget.disableUpdates && !widget.disableBottomUpdates) {
									_overscrollEndingNow = true;
									lightHapticFeedback();
									_updateOrExtendWithHapticFeedback();
								}
							}
						}
						else {
							_overscrollEndingNow = false;
						}
						return false;
						// Auto update here
					},
					child: Listener(
						onPointerDown:(e) {
							_pointerDownCount++;
						},
						onPointerUp: (e) {
							_lastPointerUpTime = DateTime.now();
							_pointerDownCount--;
							if (controller.scrollController != null && controller.scrollController!.activityIsDriven && _pointerDownCount == 0) {
								controller.scrollController!.jumpTo(controller.scrollController!.position.pixels);
							}
							controller.cancelCurrentAnimation();
							final footerBox = _footerKey.currentContext?.findRenderObject() as RenderBox?;
							final footerBottom = footerBox?.localToGlobal(footerBox.paintBounds.bottomRight).dy ?? double.infinity;
							if (e.position.dy >= footerBottom) {
								_footerShakeAnimation.forward(from: 0);
								_updateOrExtendWithHapticFeedback();
							}
						},
						onPointerCancel: (e) {
							_lastPointerUpTime = DateTime.now();
							_pointerDownCount--;
						},
						onPointerPanZoomStart: (e) {
							_pointerDownCount++;
						},
						onPointerPanZoomEnd: (e) {
							_lastPointerUpTime = DateTime.now();
							_pointerDownCount--;
						},
						child: MaybeScrollbar(
							controller: controller.scrollController,
							injectBelow: widget.injectBelowScrollbar,
							child: ChangeNotifierProvider.value(
								value: _refreshableTreeItems,
								child: CustomScrollView(
									key: _scrollViewKey,
									shrinkWrap: widget.shrinkWrap,
									cacheExtent: max(widget.minCacheExtent, 250),
									controller: controller.scrollController,
									physics: const AlwaysScrollableScrollPhysics(),
									slivers: [
										SliverSafeArea(
											sliver: widget.disableUpdates ? const SliverToBoxAdapter(
												child: SizedBox.shrink()
											) : CupertinoSliverRefreshControl(
												onRefresh: _updateWithHapticFeedback,
												refreshTriggerPullDistance: 125
											),
											bottom: false
										),
										if (widget.header != null) ...[
											SliverToBoxAdapter(
												child: widget.header
											)
										],
										if (!widget.shrinkWrap && sortedList.isNotEmpty && widget.filterableAdapter != null) SliverToBoxAdapter(
											child: Padding(
												padding: const EdgeInsets.only(
													top: 16,
													left: 16,
													right: 16,
													bottom: 8
												),
												child: Row(
													mainAxisSize: MainAxisSize.min,
													children: [
														Expanded(
															child: Center(
																child: AdaptiveSearchTextField(
																	onTap: () {
																		setState(() {
																			_searchTapped = true;
																		});
																		widget.onFilterChanged?.call('');
																	},
																	onChanged: (searchText) {
																		setState(() {
																			if (searchText.isEmpty) {
																				_lastTreeOrder = null;
																			}
																		});
																		widget.onFilterChanged?.call(searchText);
																	},
																	onSubmitted: (_) {
																		final isHardwareKeyboard = MediaQueryData.fromView(View.of(context)).viewInsets.bottom <= 100;
																		_updateOrExtendWithHapticFeedback();
																		if (isHardwareKeyboard) {
																			// Stay focused, usually it will clear to close keyboard (show more items)
																			Future.microtask(_focusSearch);
																		}
																	},
																	controller: _searchController,
																	enableIMEPersonalizedLearning: Settings.enableIMEPersonalizedLearningSetting.watch(context),
																	autocorrect: false,
																	focusNode: _searchFocusNode,
																	placeholder: widget.filterHint,
																	smartQuotesType: SmartQuotesType.disabled,
																	smartDashesType: SmartDashesType.disabled
																)
															),
														),
														if (_searchTapped) CupertinoButton(
															padding: const EdgeInsets.only(left: 8),
															minSize: 0,
															onPressed: closeSearch,
															child: const Text('Cancel')
														)
													]
												)
											)
										),
										if (widget.filterAlternative != null &&
												(searching ||
												(_searchTapped && widget.filterAlternative!.suggestWhenFilterEmpty))) SliverToBoxAdapter(
											child: Container(
												decoration: BoxDecoration(
													border: Border(
														top: BorderSide(color: dividerColor),
														bottom: BorderSide(color: dividerColor)
													)
												),
												child: CupertinoButton(
													padding: const EdgeInsets.all(16),
													onPressed: () {
														_searchFocusNode.unfocus();
														widget.filterAlternative!.handler(_searchController.text);
													},
													child: Row(
														children: [
															const Icon(CupertinoIcons.search),
															const SizedBox(width: 8),
															Expanded(
																child: Text(
																	'Search ${widget.filterAlternative?.name}',
																	textAlign: TextAlign.left
																)
															)
														]
													)
												)
											)
										),
										if (values.isNotEmpty)
											if (widget.staggeredGridDelegate != null) SliverStaggeredGrid(
												key: PageStorageKey('staggered grid for ${widget.id}'),
												gridDelegate: widget.staggeredGridDelegate!,
												id: '${_searchController.text}${widget.sortMethods}$forceRebuildId${widget.rebuildId}${controller.useDummyItemsInRange}${widget.useAllDummies}${identityHashCode(values)}',
												delegate: SliverDontRebuildChildBuilderDelegate(
													(context, i) {
														return BuildContextRegistrant(
															key: ValueKey(values[i]._key),
															onBuild: (context) {
																controller._registerItem(i, values[i], context);
															},
															onDispose: (context) {
																controller._unregisterItem(i, context);
															},
															child: Builder(
																builder: (context) => _itemBuilder(context, values[i], _useDummyFor(i))
															)
														);
													},
													list: values,
													id: '${_searchController.text}${widget.sortMethods}$forceRebuildId${widget.rebuildId}${controller.useDummyItemsInRange}${widget.useAllDummies}',
													didFinishLayout: controller.didFinishLayout,
													childCount: values.length,
													addRepaintBoundaries: false,
													addAutomaticKeepAlives: false,
													fastHeightEstimate: _fastHeightEstimate
												)
											)
											else if (widget.gridDelegate != null) SliverGrid(
												key: PageStorageKey('grid for ${widget.id}'),
												gridDelegate: widget.gridDelegate!,
												delegate: SliverDontRebuildChildBuilderDelegate(
													(context, i) {
														return BuildContextRegistrant(
															key: ValueKey(values[i]._key),
															onBuild: (context) {
																controller._registerItem(i, values[i], context);
															},
															onDispose: (context) {
																controller._unregisterItem(i, context);
															},
															child: Builder(
																builder: (context) => _itemBuilder(context, values[i], _useDummyFor(i))
															)
														);
													},
													list: values,
													id: '${_searchController.text}${widget.sortMethods}$forceRebuildId${widget.rebuildId}${controller.useDummyItemsInRange}${widget.useAllDummies}',
													didFinishLayout: controller.didFinishLayout,
													childCount: values.length,
													addRepaintBoundaries: false,
													addAutomaticKeepAlives: false,
													fastHeightEstimate: _fastHeightEstimate
												)
											)
											else SliverList(
												key: _sliverListKey,
												delegate: SliverDontRebuildChildBuilderDelegate(
													(context, childIndex) {
														return BuildContextRegistrant(
															key: ValueKey(values[childIndex]._key),
															onBuild: (context) {
																controller._registerItem(childIndex, values[childIndex], context);
															},
															onDispose: (context) {
																controller._unregisterItem(childIndex, context);
															},
															child: Builder(
																builder: (context) => _itemBuilder(context, values[childIndex], _useDummyFor(childIndex))
															)
														);
													},
													separatorBuilder: (context, childIndex) {
														return _Divider(
															key: ValueKey(_DividerKey(values[childIndex]._key)),
															dummy: _useDummyFor(childIndex),
															itemBefore: values[childIndex],
															itemAfter: (childIndex < values.length - 1) ? values[childIndex + 1] : null,
															color: dividerColor
														);
													},
													separatorSentinel: dividerColor,
													list: values,
													id: '${_searchController.text}${widget.sortMethods}$forceRebuildId${widget.rebuildId}${controller.useDummyItemsInRange}${widget.useAllDummies}',
													childCount: values.length * 2,
													findChildIndexCallback: (key) {
														if (key is ValueKey<_RefreshableTreeItemsCacheKey>) {
															if (key.value.thisId == 0) {
																// Items not really keyed
																return null;
															}
															final idx = values.indexWhere(
																(other) => identical(key.value, other._key)
															) * 2;
															if (idx >= 0) {
																return idx;
															}
														}
														else if (key is ValueKey<_DividerKey>) {
															if (key.value.key.thisId == 0) {
																// Items not really keyed
																return null;
															}
															final idx = values.indexWhere(
																(other) => identical(key.value.key, other._key)
															) * 2;
															if (idx >= 0) {
																return idx + 1;
															}
														}
														return null;
													},
													fastHeightEstimate: _fastHeightEstimate,
													fastErrorEstimate: (i) {
														if (
															// Item was previously dummy. so its contribution to scrollOffset is not correct
															_refreshableTreeItems._dummyCache[values[i]._key] == _DummyStatus.previously &&
															// We are not in a weird inter-insertion-frame situation
															controller._items[i].item == values[i]
														) {
															return (controller._items[i].cachedHeight ?? _kDummyHeight) - _kDummyHeight;
														}
														// No error
														return null;
													},
													didFinishLayout: (startIndex, endIndex) {
														controller.didFinishLayout.call((startIndex / 2).ceil(), (endIndex / 2).floor());
													},
													addAutomaticKeepAlives: false,
													addRepaintBoundaries: false,
												)
											),
										if (values.isEmpty)
											const SliverToBoxAdapter(
													child: SizedBox(
														height: 100,
														child: Center(
															child: Text('Nothing to see here')
														)
													)
												),
										if (!widget.shrinkWrap && filteredValues.isNotEmpty && Settings.showHiddenItemsFooterSetting.watch(context)) ...[
											SliverToBoxAdapter(
												child: GestureDetector(
													onTap: () {
														setState(() {
															_showFilteredValues = !_showFilteredValues;
														});
													},
													child: SizedBox(
														height: 50,
														child: Center(
															child: Text(
																(_showFilteredValues ? 'Showing ' : '') + describeCount(filteredValues.length, 'filtered item'),
																style: TextStyle(
																	color: theme.primaryColorWithBrightness(0.4)
																)
															)
														)
													)
												),
											),
											if (_showFilteredValues)
												if (widget.staggeredGridDelegate != null) SliverStaggeredGrid(
													key: PageStorageKey('filtered staggered grid for ${widget.id}'),
													gridDelegate: widget.staggeredGridDelegate!,
													delegate: SliverDontRebuildChildBuilderDelegate(
														(context, i) => Stack(
															key: ValueKey(filteredValues[i]._key),
															children: [
																Provider.value(
																	value: RefreshableListFilterReason(filteredValues[i].filterReason ?? 'Unknown'),
																	builder: (context, _) => _itemBuilder(context, filteredValues[i], false)
																),
																Align(
																	alignment: Alignment.topRight,
																	child: Padding(
																		padding: const EdgeInsets.only(top: 8, right: 8),
																		child: AdaptiveFilledButton(
																			padding: EdgeInsets.zero,
																			child: const Icon(CupertinoIcons.question),
																			onPressed: () {
																				alert(context, 'Filter reason', filteredValues[i].filterReason ?? 'Unknown');
																			}
																		)
																	)
																)
															]
														),
														list: filteredValues,
														id: widget.id,
														childCount: filteredValues.length,
														addRepaintBoundaries: false,
														addAutomaticKeepAlives: false,
														fastHeightEstimate: _fastHeightEstimate
													)
												)
												else if (widget.gridDelegate != null) SliverGrid(
													key: PageStorageKey('filtered grid for ${widget.id}'),
													gridDelegate: widget.gridDelegate!,
													delegate: SliverDontRebuildChildBuilderDelegate(
														(context, i) => Stack(
															key: ValueKey(filteredValues[i]._key),
															children: [
																Provider.value(
																	value: RefreshableListFilterReason(filteredValues[i].filterReason ?? 'Unknown'),
																	builder: (context, _) => _itemBuilder(context, filteredValues[i], false)
																),
																Align(
																	alignment: Alignment.topRight,
																	child: Padding(
																		padding: const EdgeInsets.only(top: 8, right: 8),
																		child: AdaptiveFilledButton(
																			padding: EdgeInsets.zero,
																			child: const Icon(CupertinoIcons.question),
																			onPressed: () {
																				alert(context, 'Filter reason', filteredValues[i].filterReason ?? 'Unknown');
																			}
																		)
																	)
																)
															]
														),
														list: filteredValues,
														id: '$forceRebuildId${widget.rebuildId}',
														childCount: filteredValues.length,
														addRepaintBoundaries: false,
														addAutomaticKeepAlives: false
													)
												)
												else SliverList(
													key: PageStorageKey('filtered list for ${widget.id}'),
													delegate: SliverDontRebuildChildBuilderDelegate(
														(context, childIndex) {
															return Column(
																key: ValueKey(filteredValues[childIndex]._key),
																mainAxisSize: MainAxisSize.min,
																crossAxisAlignment: CrossAxisAlignment.stretch,
																children: [
																	IgnorePointer(
																		child: Container(
																			padding: const EdgeInsets.all(4),
																			color: theme.primaryColorWithBrightness(0.5),
																			child: Text('Filter reason:\n${filteredValues[childIndex].filterReason}', style: TextStyle(
																				color: theme.backgroundColor
																			))
																		)
																	),
																	Container(
																		color: theme.primaryColorWithBrightness(0.5),
																		padding: const EdgeInsets.all(8),
																		child: Provider.value(
																			value: RefreshableListFilterReason(filteredValues[childIndex].filterReason ?? 'Unknown'),
																			builder: (context, _) => _itemBuilder(context, filteredValues[childIndex], false)
																		)
																	)
																]
															);
														},
														separatorBuilder: (context, childIndex) => Divider(
															thickness: 1,
															height: 0,
															color: dividerColor
														),
														separatorSentinel: dividerColor,
														list: filteredValues,
														id: '$forceRebuildId${widget.rebuildId}',
														childCount: filteredValues.length * 2,
														addRepaintBoundaries: false,
														addAutomaticKeepAlives: false
													)
												)
										],
										SliverList(
											delegate: SliverChildListDelegate([
												if (widget.aboveFooter != null) widget.aboveFooter!,
												if (widget.footer != null && widget.disableUpdates) SafeArea(
													top: false,
													child: widget.footer!
												)
												else if (widget.footer != null && !widget.disableUpdates) RepaintBoundary(
													child: GestureDetector(
														behavior: HitTestBehavior.opaque,
														onTap: (!widget.canTapFooter || (updatingNow.value != null)) ? null : () {
															lightHapticFeedback();
															Future.delayed(const Duration(milliseconds: 17), () {
																controller.scrollController?.animateTo(
																	controller.scrollController!.position.maxScrollExtent,
																	duration: const Duration(milliseconds: 250),
																	curve: Curves.ease
																);
															});
															_footerShakeAnimation.forward(from: 0);
															_updateOrExtendWithHapticFeedback();
														},
														child: AnimatedBuilder(
															animation: shakeAnimation,
															builder: (context, child) => Transform.scale(
																scale: 1.0 - 0.2*sin(pi * shakeAnimation.value),
																child: child
															),
															child: widget.footer
														)
													)
												)
												else if (widget.disableUpdates || widget.disableBottomUpdates) const SafeArea(
													top: false,
													child: SizedBox.shrink()
												),
												if (!widget.disableUpdates && !widget.disableBottomUpdates) SafeArea(
													top: false,
													child: RepaintBoundary(
														child: ValueListenableBuilder(
															valueListenable: error,
															builder: (context, error, _) {
																final errorType = error?.$1.runtimeType;
																return ValueListenableBuilder(
																	valueListenable: updatingNow,
																	builder: (context, updatingNow, _) => RefreshableListFooter(
																		key: _footerKey,
																		updater: _updateOrExtendWithHapticFeedback,
																		updatingNow: updatingNow != null,
																		lastUpdateTime: lastUpdateTime,
																		nextUpdateTime: nextUpdateTime,
																		error: error,
																		remedy: widget.remedies[errorType],
																		overscrollFactor: controller.overscrollFactor,
																		isScrollable: controller.isScrollable,
																		pointerDownNow: () {
																			return _pointerDownCount > 0;
																		}
																	)
																);
															}
														)
													)
												)
											])
										)
									]
								)
							)
						)
					)
				)
			);
		}
		return ValueListenableBuilder(
			valueListenable: error,
			builder: (context, error, _) {
				if (error != null) {
					final remedy = widget.remedies[error.$1.runtimeType];
					return Center(
						child: ErrorMessageCard(
							'Error loading ${widget.id}:\n${error.$1.toStringDio()}',
							remedies: {
								'Retry': _updateWithHapticFeedback,
								if (isReportableBug(error.$1)) 'Report bug': () => reportBug(error.$1, error.$2),
								if (remedy != null) remedy.$1: () async {
									await remedy.$2.call();
									await _updateWithHapticFeedback();
								},
								...(ExtendedException.extract(error.$1)?.remedies ?? {})
									.map((k, v) => MapEntry(k, () async {
										await v(context);
										await _updateWithHapticFeedback();
									})),
								if (widget.initialList?.isNotEmpty ?? false) 'View cached': () {
									originalList = widget.initialList;
									this.sortedList = originalList?.toList();
									if (sortedList != null) {
										_sortList();
									}
									setState(() {});
								}
							}
						)
					);
				}
				else {
					return Center(
						child: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								const CircularProgressIndicator.adaptive(),
								ValueListenableBuilder(
									valueListenable: updatingNow,
									builder: (context, pair, _) {
										if (pair == null) {
											return const SizedBox.shrink();
										}
										return HiddenCancelButton(
											cancelToken: pair.cancelToken,
											icon: const Text('Cancel'),
											alignment: Alignment.topCenter
										);
									}
								)
							]
						)
					);
				}
			}
		);
	}
}

class RefreshableListFooter extends StatelessWidget {
	final (Object, StackTrace)? error;
	final Future<void> Function() updater;
	final bool updatingNow;
	final DateTime? lastUpdateTime;
	final DateTime? nextUpdateTime;
	final (String, Future<void> Function())? remedy;
	final ValueListenable<double>? overscrollFactor;
	final ValueListenable<bool>? isScrollable;
	final bool Function() pointerDownNow;
	const RefreshableListFooter({
		required this.updater,
		required this.updatingNow,
		this.lastUpdateTime,
		this.nextUpdateTime,
		this.error,
		this.remedy,
		this.overscrollFactor,
		this.isScrollable,
		required this.pointerDownNow,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		final theme = context.watch<SavedTheme>();
		final primaryColorWithBrightness10 = theme.primaryColorWithBrightness(0.1);
		final primaryColorWithBrightness50 = theme.primaryColorWithBrightness(0.5);
		return GestureDetector(
			behavior: HitTestBehavior.opaque,
			onTap: updatingNow ? null : updater,
			child: Padding(
				padding: const EdgeInsets.all(1),
				child: Center(
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							if (error != null) Container(
								padding: const EdgeInsets.all(16),
								color: Colors.orange.withOpacity(0.5),
								child: Row(
									mainAxisAlignment: MainAxisAlignment.center,
									children: [
										Flexible(
											child: Text(error!.$1.toStringDio())
										),
										const SizedBox(width: 8),
										AdaptiveIconButton(
											onPressed: () => alertError(context, error!.$1, error!.$2, barrierDismissible: true),
											icon: const Icon(CupertinoIcons.exclamationmark_triangle)
										)
									].maybeReversed(!Settings.showListPositionIndicatorsOnLeftSetting.watch(context))
								),
							),
							if (!updatingNow && remedy != null) ...[
								AdaptiveFilledButton(
									child: Text(remedy!.$1),
									onPressed: () async {
										await remedy?.$2();
										await updater();
									}
								),
								const SizedBox(height: 16)
							],
							if (overscrollFactor != null) SizedBox(
								height: updatingNow ? 64 : 0,
								child: OverflowBox(
									maxHeight: 100,
									alignment: Alignment.topCenter,
									child: ValueListenableBuilder(
										valueListenable: isScrollable ?? const ConstantValueListenable(false),
										builder: (context, bool isScrollableValue, child) => ValueListenableBuilder(
											valueListenable: overscrollFactor!,
											builder: (context, double value, child) => TweenAnimationBuilder(
												tween: Tween<double>(begin: 0, end: value),
												duration: const Duration(milliseconds: 50),
												curve: Curves.ease,
												builder: (context, double smoothedValue, child) => Stack(
													alignment: Alignment.topCenter,
													clipBehavior: Clip.none,
													children: [
														Positioned(
															top: 0,
															child: Container(
																padding: const EdgeInsets.only(top: 32),
																constraints: const BoxConstraints(
																	maxWidth: 100
																),
																child: ClipRRect(
																	borderRadius: const BorderRadius.all(Radius.circular(8)),
																	child: Stack(
																		children: [
																			if (nextUpdateTime != null && lastUpdateTime != null) TimedRebuilder<double>(
																				enabled: !isScrollableValue || smoothedValue > 0,
																				interval: const Duration(seconds: 1),
																				function: () {
																					final now = DateTime.now();
																					return updatingNow ? 0 : now.difference(lastUpdateTime!).inSeconds / nextUpdateTime!.difference(lastUpdateTime!).inSeconds;
																				},
																				builder: (context, value) {
																					return LinearProgressIndicator(
																						value: value,
																						color: theme.primaryColor.withOpacity(0.5),
																						backgroundColor: primaryColorWithBrightness10,
																						minHeight: 8
																					);
																				}
																			) else LinearProgressIndicator(
																				value: 0,
																				color: theme.primaryColor.withOpacity(0.5),
																				backgroundColor: primaryColorWithBrightness10,
																				minHeight: 8
																			),
																			LinearProgressIndicator(
																				value: (updatingNow) ? null : (pointerDownNow() ? smoothedValue : 0),
																				backgroundColor: Colors.transparent,
																				color: theme.primaryColor,
																				minHeight: 8
																			)
																		]
																	)
																)
															)
														),
														if ((nextUpdateTime?.isAfter(DateTime.now()) ?? false) &&
																(lastUpdateTime?.isBefore(DateTime.now().subtract(const Duration(seconds: 1))) ?? false) &&
																!updatingNow) Positioned(
															top: 50,
															child: TimedRebuilder(
																enabled: nextUpdateTime != null && lastUpdateTime != null && (!isScrollableValue || smoothedValue > 0),
																interval: const Duration(seconds: 1),
																function: () {
																	return formatRelativeTime(nextUpdateTime ?? DateTime(3000));
																},
																builder: (context, relativeTime) {
																	return GreedySizeCachingBox(
																		child: Text('Next update $relativeTime', style: TextStyle(
																			color: primaryColorWithBrightness50
																		))
																	);
																}
															)
														)
													]
												)
											)
										)
									)
								)
							)
						]
					)
				)
			)
		);
	}
}

class _BuiltRefreshableListItem<T extends Object> {
	BuildContext? context;
	T item;
	double? cachedOffset;
	double? cachedHeight;
	bool get hasGoodState {
		try {
			return (context?.findRenderObject()?.attached ?? false) && ((context?.findRenderObject() as RenderBox).hasSize);
		}
		on FlutterError {
			return false;
		}
	}
	_BuiltRefreshableListItem(this.item);

	@override
	bool operator == (Object o) =>
		identical(this, o) ||
		(o is _BuiltRefreshableListItem<T>) &&
		o.item == item;

	@override
	int get hashCode => item.hashCode;

	@override
	String toString() => '_RefreshableListItem(item: $item, cachedOffset: $cachedOffset, cachedHeight: $cachedHeight)';
}
class RefreshableListController<T extends Object> extends ChangeNotifier {
	List<_BuiltRefreshableListItem<RefreshableListItem<T>>> _items = [];
	Iterable<RefreshableListItem<T>> get items => _items.map((i) => i.item);
	int get itemsLength => _items.length;
	RefreshableListItem<T> getItem(int i) => _items[i].item;
	ScrollController? scrollController;
	late final ValueNotifier<double> overscrollFactor = ValueNotifier<double>(0);
	late final ValueNotifier<bool> isScrollable = ValueNotifier<bool>(true);
	final slowScrolls = BufferedListenable(const Duration(milliseconds: 100));
	double topOffset = 0;
	double bottomOffset = 0;
	String? contentId;
	RefreshableListState<T>? state;
	final Map<(int, bool), List<Completer<void>>> _itemCacheCallbacks = {};
	int? currentTargetIndex;
	(int, int)? useDummyItemsInRange;
	bool? _useTree;
	final Map<int, RefreshableListItem<T>> _newInsertIndices = {};
	bool _autoExtendEnabled = true;
	bool _isDisposed = false;
	(int, int)? _lastLaidOutRange;
	RefreshableListController() {
		slowScrolls.addListener(_onSlowScroll);
		SchedulerBinding.instance.endOfFrame.then((_) => _onScrollControllerNotification());
	}
	void invalidateAfter(RefreshableListItem<T> item, bool looseEquality) {
		final index = looseEquality ?
			_items.indexWhere((i) => i.item.item == item.item) :
			_items.indexWhere((i) => i.item == item);
		if (index == -1) {
			print('Could not find $item in list to invalidate after');
		}
		for (final item in _items.skip(index + 1)) {
			item.cachedOffset = null;
			item.cachedHeight = null;
		}
	}
	Future<void> _tryCachingItem(int index) async {
		await SchedulerBinding.instance.endOfFrame;
		if (index >= _items.length) {
			return;
		}
		final item = _items[index];
		if (item.hasGoodState) {
			// ignore: use_build_context_synchronously
			final RenderObject object = item.context!.findRenderObject()!;
			item.cachedHeight = object.semanticBounds.height;
			final newOffset = _getOffset(object);
			if (item.cachedOffset != null && item.cachedOffset != newOffset) {
				for (final item in _items.skip(index + 1)) {
					item.cachedOffset = null;
				}
			}
			if (index == 0) {
				// Reset the dummy cache. Scroll offset is now guaranteed to be correct.
				state?._refreshableTreeItems._dummyCache.clear();
			}
			item.cachedOffset = newOffset;
			final keys = _itemCacheCallbacks.keys.toList();
			for (final position in keys) {
				if (position.$2 && index >= position.$1) {
					// scrolling down
					_itemCacheCallbacks[position]?.forEach((c) => c.complete());
					_itemCacheCallbacks.remove(position);
				}
				else if (!position.$2 && index <= position.$1) {
					// scrolling up
					_itemCacheCallbacks[position]?.forEach((c) => c.complete());
					_itemCacheCallbacks.remove(position);
				}
			}
		}
	}
	Future<void> _onSlowScroll() async {
		final extentAfter = scrollController?.tryPosition?.extentAfter;
		if (extentAfter != null) {
			if (extentAfter < 1000 && _autoExtendEnabled) {
				// The list just may be shrinking e.g. via filtering
				// In that case, don't do an update, and still set the flag to false,
				// so that first scroll in the shorter list doesn't extend either.
				if (scrollController?.tryPosition?.isScrollingNotifier.value ?? false) {
					state?._autoExtendTrigger();
				}
				_autoExtendEnabled = false;
			}
			else if (extentAfter > 2000) {
				_autoExtendEnabled = true;
			}
		}
		for (final item in _items) {
			if (item.context?.mounted == false) {
				item.context = null;
			}
		}
	}
	void _onScrollControllerNotification() {
		if (_isDisposed) {
			return;
		}
		slowScrolls.didUpdate();
		if (scrollControllerPositionLooksGood) {
			final overscrollAmount = scrollController!.position.pixels - scrollController!.position.maxScrollExtent;
			overscrollFactor.value = (overscrollAmount / _overscrollTriggerThreshold).clamp(0, 1);
			isScrollable.value = scrollController!.position.maxScrollExtent > 0;
		}
	}
	void attach(RefreshableListState<T> list) {
		state = list;
		_useTree = list.useTree;
	}
	void detach() {
		state = null;
	}
	void focusSearch() async {
		await animateToIndex(0);
		state?._focusSearch();
	}
	void unfocusSearch() {
		state?._unfocusSearch();
	}
	void closeSearch() => state?.closeSearch();
	void reportPrimaryScrollController(ScrollController? controller) {
		if (scrollController != controller) {
			scrollController?.removeListener(_onScrollControllerNotification);
			scrollController = controller;
			scrollController?.addListener(_onScrollControllerNotification);
		}
	}
	@override
	void dispose() {
		super.dispose();
		_isDisposed = true;
		scrollController?.removeListener(_onScrollControllerNotification);
		slowScrolls.removeListener(_onSlowScroll);
		slowScrolls.dispose();
		overscrollFactor.dispose();
		isScrollable.dispose();
	}
	void newContentId(String contentId) {
		if (this.contentId != null && this.contentId != contentId) {
			for (final cbs in _itemCacheCallbacks.values) {
				for (final cb in cbs) {
					cb.completeError(Exception('page changed'));
				}
			}
			_items = [];
			_itemCacheCallbacks.clear();
		}
		this.contentId = contentId;
	}
	void setItems(List<RefreshableListItem<T>> items) {
		final oldFirstOffset = _items.tryFirst?.cachedOffset;
		if (items.length > 2 &&
		   _items.length > 2 &&
			 items[0] == _items[0].item &&
			 items[1] == _items[1].item &&
			 items.length >= _items.length &&
			 state?.useTree == _useTree &&
			 state?.useTree != true) {
			if (items.length < _items.length) {
				_items = _items.sublist(0, items.length);
			}
			for (int i = 0; i < items.length; i++) {
				if (i < _items.length) {
					_items[i].item = items[i];
				}
				else {
					_items.add(_BuiltRefreshableListItem(items[i]));
				}
			}
		}
		else if (items.length == 1 && _items.length == 1 && items[0] == _items[0].item) {
			_items[0].item = items[0];
		}
		else if (!listEquals(items, this.items.toList())) {
			final oldCachedHeights = (state?.useTree == _useTree) ? <RefreshableListItem<T>, double>{
				for (final item in _items)
					if (item.cachedHeight != null)
						item.item: item.cachedHeight!
			} : <RefreshableListItem<T>, double>{};
			_items = items.map((item) => _BuiltRefreshableListItem(item)..cachedHeight = oldCachedHeights[item]).toList();
		}
		_items.tryFirst?.cachedOffset = oldFirstOffset;
		_useTree = state?.useTree;
		for (int i = 0; i < _items.length; i++) {
			if (isItemHidden(_items[i].item) == TreeItemCollapseType.newInsertCollapsed) {
				_newInsertIndices[i] = _items[i].item;
			}
		}
		WidgetsBinding.instance.addPostFrameCallback((_) {
			if (_isDisposed) {
				return;
			}
			slowScrolls.didUpdate(now: true);
			notifyListeners();
		});
	}
	void _registerItem(int index, RefreshableListItem<T> item, BuildContext context) {
		if (index < _items.length) {
			_items[index].item = item;
			_items[index].context = context;
		}
	}
	void _unregisterItem(int index, BuildContext context) {
		if (index < _items.length && _items[index].context == context) {
			_items[index].context = null;
		}
	}
	double _getOffset(RenderObject object) {
		return RenderAbstractViewport.of(object).getOffsetToReveal(object, 0.0).offset;
	}
	double? _estimateOffset(int targetIndex) {
		if (targetIndex == 0) {
			return 0;
		}
		final heightedItems = _items.tryMap((i) => i.cachedHeight);
		if (heightedItems.length < 2) {
			// If we only have one heighted item. It must be a super long OP which probably
			// isn't representative anyway.
			return null;
		}
		final averageItemHeight = heightedItems.fold<double>(0, (a, b) => a + b) / heightedItems.length;
		int nearestDistance = _items.length + 1;
		int nearestIndex = 0;
		for (int i = 0; i < _items.length; i++) {
			if (_items[i].cachedOffset != null) {
				final distance = (targetIndex - i).abs();
				if (distance < nearestDistance) {
					nearestIndex = i;
					nearestDistance = distance;
				}
			}
		}
		double estimate = _items[nearestIndex].cachedOffset!;
		if (targetIndex > nearestIndex) {
			for (int j = nearestIndex; j < targetIndex; j++) {
				estimate += _items[j].cachedHeight ?? averageItemHeight;
			}
		}
		else if (targetIndex < nearestIndex) {
			for (int j = targetIndex; j < nearestIndex; j++) {
				estimate -= _items[j].cachedHeight ?? averageItemHeight;
			}
		}
		return estimate;
	}
	Future<void> animateTo(bool Function(T val) f, {
		double alignment = 0.0,
		bool Function(T val)? orElseLast,
		Duration duration = const Duration(milliseconds: 200),
		Curve curve = Curves.easeInOut,
		bool revealIfHidden = true
	}) async {
		int targetIndex = _items.indexWhere((i) => f(i.item.item));
		if (targetIndex == -1) {
			if (orElseLast != null) {
				targetIndex = _items.lastIndexWhere((i) => orElseLast(i.item.item));
			}
			if (targetIndex == -1) {
				throw const ItemNotFoundException('No matching item to scroll to');
			}
		}
		await animateToIndex(targetIndex, alignment: alignment, duration: duration, curve: curve, revealIfHidden: revealIfHidden);
	}
	Future<void> animateToIfOffscreen(bool Function(T val) f, {
		double alignment = 0.0,
		bool Function(T val)? orElseLast,
		Duration duration = const Duration(milliseconds: 200),
		bool revealIfHidden = true
	}) async {
		int targetIndex = _items.indexWhere((i) => f(i.item.item));
		if (targetIndex == -1) {
			if (orElseLast != null) {
				targetIndex = _items.lastIndexWhere((i) => orElseLast(i.item.item));
			}
			if (targetIndex == -1) {
				throw const ItemNotFoundException('No matching item to scroll to');
			}
		}
		if (_isOnscreen(_items[targetIndex])) {
			return;
		}
		await animateToIndex(targetIndex, alignment: alignment, duration: duration);
	}
	Future<void> animateToIndex(int targetIndex, {
		double alignment = 0.0,
		Duration duration = const Duration(milliseconds: 200),
		Curve curve = Curves.easeInOut,
		bool revealIfHidden = true
	}) async {
		if (targetIndex < 0 || targetIndex >= itemsLength) {
			print('Someone tried to animateTo an invalid index (0 <= $targetIndex < $itemsLength)');
			print(StackTrace.current);
			return;
		}
		final startPixels = scrollController?.tryPosition?.pixels ?? 0;
		final (int, int) proposedRange;
		final rangeBonus = (state?.useTree == true || state?.widget.gridDelegate != null || state?.widget.staggeredGridDelegate != null) ? 5 : 0;
		if (targetIndex > firstVisibleIndex) {
			// Scrolling forwards
			proposedRange = (lastVisibleIndex + 1, targetIndex - 12 - rangeBonus);
		}
		else {
			// Scrolling backwards
			proposedRange = (targetIndex + 7 + rangeBonus, firstVisibleIndex - 3);
		}
		// If the range is already mostly collapsed, don't use dummies
		int cost = 0;
		for (int i = proposedRange.$1; i < proposedRange.$2; i++) {
			if (!isItemHidden(_items[i].item).isHidden) {
				cost++;
			}
		}
		if (cost > 20) {
			useDummyItemsInRange = proposedRange;
			for (final item in _items) {
				item.cachedOffset = null;
				item.cachedHeight = null;
			}
			state?._rebuild();
			try {
				await SchedulerBinding.instance.endOfFrame;
				await _animateToIndex(targetIndex, alignment: alignment, duration: duration, curve: curve, startPixels: startPixels, revealIfHidden: revealIfHidden);
			}
			catch (e, st) {
				print(e);
				print(st);
			}
			for (int i = 0; i < _items.length; i++) {
				_items[i].cachedOffset = null;
				if (i < proposedRange.$2 && i > proposedRange.$1) {
					_items[i].cachedHeight = null;
				}
			}
			useDummyItemsInRange = null;
			state?._rebuild();
			await SchedulerBinding.instance.endOfFrame;
		}
		else {
			// Just to be safe
			useDummyItemsInRange = null;
			await _animateToIndex(targetIndex, alignment: alignment, duration: duration, curve: curve, startPixels: startPixels, revealIfHidden: revealIfHidden);
		}
	}
	void _lockSliverListAtIndex(int index) {
		assert(index >= 0);
		// This is not supported on flutter master
	}
	void _lockSliverListAtEnd() {
		// This is not supported on flutter master
	}
	void _unlockSliverList() {
		// This is not supported on flutter master
	}
	Future<void> _animateToIndex(int targetIndex, {
		required double alignment,
		required Duration duration,
		Curve curve = Curves.easeInOut,
		required double startPixels,
		required bool revealIfHidden
	}) async {
		try {
			print('$contentId animating to $targetIndex (${_items[targetIndex].item.item}) (alignment: $alignment)');
			final start = DateTime.now();
			currentTargetIndex = targetIndex;
			if (revealIfHidden && isItemHidden(_items[targetIndex].item).isHidden) {
				if (targetIndex < firstVisibleIndex) {
					_lockSliverListAtIndex(_items.indexWhere((i) => !isItemHidden(i.item).isHidden, targetIndex));
				}
				await state?._refreshableTreeItems.unhideItem(_items[targetIndex].item, includingParents: true);
			}
			final initialContentId = contentId;
			if (_estimateOffset(targetIndex) == null) {
				// Or it will hang
				final minDuration = const Duration(seconds: 5) * _items.length;
				if (minDuration < duration) {
					duration = minDuration;
				}
			}
			Future<bool> attemptResolve() async {
				if (scrollController!.position.outOfRange) {
					scrollController!.position.jumpTo(scrollController!.position.maxScrollExtent);
				}
				final completer = Completer<void>();
				final originalEstimate = _estimateOffset(targetIndex);
				double estimate = switch (originalEstimate) {
					double e => e - topOffset,
					null => switch (scrollController!.position.maxScrollExtent) {
						double.infinity => 200 * _items.length, // make it sane
						double ok => ok
					} * (targetIndex / max(1, _items.length - 1))
				};
				if (_items.last.cachedOffset != null) {
					// prevent overscroll
					estimate = min(estimate, scrollController!.position.maxScrollExtent);
				}
				estimate = max(0, estimate);
				if (startPixels == estimate) {
					return true;
				}
				_itemCacheCallbacks.putIfAbsent((targetIndex, estimate > scrollController!.position.pixels), () => []).add(completer);
				final cc = curve.recurve(
					start: startPixels,
					current: scrollController!.position.pixels,
					end: estimate
				);
				if ((estimate - scrollController!.position.pixels < 50)) {
					await _tryCachingItem(targetIndex);
				}
				final delay = Duration(milliseconds: max(50, (duration * ((estimate - scrollController!.position.pixels) / (startPixels - estimate)).abs()).inMilliseconds));
				scrollController!.animateTo(
					estimate,
					duration: delay,
					curve: cc
				);
				await Future.any([completer.future, Future.wait([Future.delayed(const Duration(milliseconds: 50)), Future.delayed(duration ~/ 4)])]);
				return (_items[targetIndex].cachedOffset != null);
			}
			if (_items[targetIndex].cachedOffset == null || _items[targetIndex].cachedHeight == null) {
				while (contentId == initialContentId && !(await attemptResolve()) && DateTime.now().difference(start).inSeconds < 7 && targetIndex == currentTargetIndex) {
					// Keep trying
				}
				if (initialContentId != contentId) {
					print('List was hijacked ($initialContentId -> $contentId)');
					return;
				}
				if (currentTargetIndex != targetIndex) {
					print('animateTo was hijacked ($targetIndex -> $currentTargetIndex)');
					return;
				}
			}
			if (_items[targetIndex].cachedOffset == null || _items[targetIndex].cachedHeight == null) {
				throw TimeoutException('Scrolling timed out');
			}
			if (_isDisposed) {
				return;
			}
			double atAlignment0 = _items[targetIndex].cachedOffset! - topOffset;
			final alignmentSlidingWindow = scrollController!.position.viewportDimension - _items[targetIndex].cachedHeight! - topOffset - bottomOffset;
			if (targetIndex == _items.length - 1) {
				// add offset to reveal the full footer
				atAlignment0 += 110;
			}
			else if (targetIndex == 0 && state?.widget.filterableAdapter != null && alignment >= 0) {
				// subtract offset to reveal the search bar
				atAlignment0 = 0;
			}
			else {
				atAlignment0 += 1;
			}
			final finalDestinationUnclamped = atAlignment0 - (alignmentSlidingWindow * alignment);
			if (finalDestinationUnclamped > scrollController!.position.maxScrollExtent &&
					(_items.last.cachedHeight == null || _items.last.cachedOffset == null)) {
				// Need to actually figure out the height
				final penultimateDuration = duration * ((scrollController!.position.maxScrollExtent - scrollController!.position.pixels) / (startPixels - scrollController!.position.maxScrollExtent)).abs();
				await scrollController!.animateTo(
					scrollController!.position.maxScrollExtent,
					duration: penultimateDuration > const Duration(milliseconds: 50) ? penultimateDuration : const Duration(milliseconds: 50),
					curve: curve.recurve(
						start: startPixels,
						current: scrollController!.position.pixels,
						end: scrollController!.position.maxScrollExtent
					)
				);
			}

			// The scrollController's maxScrollExtent is not trustworthy
			double maxScrollExtent;
			if (_items.last.cachedHeight != null && _items.last.cachedOffset != null) {
				final footerHeight = state?.widget.footer != null ? 40 : 0; // Lazy estimate
				maxScrollExtent = _items.last.cachedHeight! + _items.last.cachedOffset! + footerHeight - scrollController!.position.viewportDimension + bottomOffset;
			}
			else {
				maxScrollExtent = scrollController!.position.maxScrollExtent - (state?.updatingNow.value != null ? 64 : 0);
			}
			// Give up and fallback
			if (maxScrollExtent <= 0) {
				maxScrollExtent = scrollController!.position.maxScrollExtent;
			}
			final finalDestination = finalDestinationUnclamped.clamp(0.0, maxScrollExtent);
			if (scrollController!.position.pixels != finalDestination) {
				final finalDuration = duration * ((finalDestination - scrollController!.position.pixels) / (startPixels - finalDestination)).abs();
				await scrollController!.animateTo(
					finalDestination,
					duration: finalDuration > const Duration(milliseconds: 50) ? finalDuration : const Duration(milliseconds: 50),
					curve: curve.recurve(
						start: startPixels,
						current: scrollController!.position.pixels,
						end: finalDestination
					)
				);
			}
			await SchedulerBinding.instance.endOfFrame;
			await scrollController?.tryPosition?.isScrollingNotifier.waitUntilValue(false);
		}
		finally {
			currentTargetIndex = null;
			_unlockSliverList();
		}
	}
	void cancelCurrentAnimation() {
		currentTargetIndex = null;
	}
	double getItemAlignment(int index) {
		if (!scrollControllerPositionLooksGood) {
			// A guess at alignment
			return 0;
		}
		final viewportStart = scrollController!.position.pixels + topOffset;
		final itemStart = _items[index].cachedOffset ?? viewportStart;
		return (itemStart - viewportStart) / (scrollController!.position.viewportDimension - ((_items[index].cachedHeight ?? 0) + topOffset + bottomOffset));
	}
	double getItemEndAlignment(int index) {
		if (!scrollControllerPositionLooksGood) {
			// A guess at alignment
			return 1;
		}
		final viewportStart = scrollController!.position.pixels + topOffset;
		final viewportEnd = scrollController!.position.pixels + scrollController!.position.viewportDimension - bottomOffset;
		final itemEnd = switch ((_items[index].cachedOffset, _items[index].cachedHeight)) {
			(double offset, double height) => offset + height,
			_ => viewportEnd
		};
		return (itemEnd - viewportStart) / (scrollController!.position.viewportDimension - (topOffset + bottomOffset));
	}
	({T item, double? alignment})? findItem(bool Function(T val) f) {
		final index = _items.indexWhere((x) => f(x.item.item));
		if (index == -1) {
			return null;
		}
		final item = _items[index];
		final double? alignment;
		if (item.cachedHeight != null && item.cachedOffset != null) {
			alignment = getItemAlignment(index);
		}
		else {
			alignment = null;
		}
		return (item: item.item.item, alignment: alignment);
	}
	int get firstVisibleIndex {
		if (scrollControllerPositionLooksGood) {
			if (_items.isNotEmpty &&
					_items.first.cachedOffset != null &&
					_items.first.cachedOffset! > scrollController!.position.pixels &&
					_items.first.cachedHeight != null) {
				// Search field will mean that the _items.lastIndexWhere search will return -1
				return 0;
			}
			final threshold = scrollController!.position.pixels + topOffset;
			test(_BuiltRefreshableListItem<RefreshableListItem<T>> i) =>
				(i.cachedHeight != null) &&
				(i.cachedOffset != null) &&
				(i.cachedOffset! <= threshold);
			final range = _lastLaidOutRange;
			if (range != null && range.$2 < _items.length) {
				for (int i = range.$2; i >= range.$1; i--) {
					if (test(_items[i])) {
						return i;
					}
				}
				return -1;
			}
			return _items.lastIndexWhere(test);
		}
		return -1;
	}
	({T item, double alignment})? get firstVisibleItem {
		final index = firstVisibleIndex;
		if (index < 0) {
			return null;
		}
		return (item: _items[index].item.item, alignment: getItemAlignment(index));
	}
	T? get middleVisibleItem {
		if (scrollControllerPositionLooksGood) {
			final threshold = scrollController!.position.pixels + (scrollController!.position.viewportDimension / 2);
			test(_BuiltRefreshableListItem<RefreshableListItem<T>> i) =>
				(i.cachedHeight != null) &&
				(i.cachedOffset != null) &&
				((i.cachedOffset! + i.cachedHeight!) > threshold);
			final range = _lastLaidOutRange;
			if (range != null && range.$2 < _items.length) {
				for (int i = range.$1; i <= range.$2; i++) {
					if (test(_items[i])) {
						return _items[i].item.item;
					}
				}
				return null;
			}
			int index = _items.indexWhere(test);
			if (index != -1) {
				return _items[index].item.item;
			}
		}
		return null;
	}
	int get lastVisibleIndex {
		if (scrollControllerPositionLooksGood) {
			if (_items.isNotEmpty &&
					_items.first.cachedHeight != null &&
					_items.first.cachedHeight! > (scrollController!.position.pixels + scrollController!.position.viewportDimension)) {
				return 0;
			}
			final threshold = scrollController!.position.pixels + scrollController!.position.viewportDimension - bottomOffset;
			test(_BuiltRefreshableListItem<RefreshableListItem<T>> i) =>
				(i.cachedHeight != null) &&
				(i.cachedOffset != null) &&
				i.cachedOffset! < threshold;
			final range = _lastLaidOutRange;
			if (range != null && range.$2 < _items.length) {
				for (int i = range.$2; i >= range.$1; i--) {
					if (test(_items[i])) {
						return i;
					}
				}
				return -1;
			}
			return _items.lastIndexWhere(test);
		}
		return -1;
	}
	T? get lastVisibleItem {
		final index = lastVisibleIndex;
		return index < 0 ? null : _items[index].item.item;
	}
	Iterable<RefreshableListItem<T>> get visibleItems sync* {
		if (!scrollControllerPositionLooksGood) {
			return;
		}
		final dummyRange = useDummyItemsInRange;
		final top = scrollController!.position.pixels;
		final bottom = top + scrollController!.position.viewportDimension;
		final range = _lastLaidOutRange ?? (0, items.length - 1);
		for (int i = range.$1; i <= range.$2; i++) {
			if (dummyRange != null && i < dummyRange.$2 && i > dummyRange.$1) {
				// Dummy, not really visible
				continue;
			}
			final item = _items[i];
			if (isItemHidden(item.item).isHidden) {
				// Not visible
				continue;
			}
			final height = item.cachedHeight;
			final offset = item.cachedOffset;
			if (height != null && offset != null) {
				if (offset + height < top) {
					// Above viewport
					continue;
				}
				if (offset > bottom) {
					// Below viewport
					return;
				}
				yield item.item;
			}
		}
	}
	({RefreshableListItem<T> item, BuildContext context, double startOffset})? findItemAtOffset(double offset) {
		for (final item in _items) {
			final cachedOffset = item.cachedOffset;
			final cachedHeight = item.cachedHeight;
			final context = item.context;
			if (cachedOffset == null || cachedHeight == null || context == null) {
				continue;
			}
			if (cachedOffset > offset) {
				// No hope finding it
				break;
			}
			if (offset >= cachedOffset && offset <= (cachedOffset + cachedHeight)) {
				return (item: item.item, context: context, startOffset: cachedOffset);
			}
		}
		return null;
	}
	bool _isOnscreen(_BuiltRefreshableListItem<RefreshableListItem<T>> i) {
		return (i.cachedHeight != null) &&
					 (i.cachedOffset != null) && 
					 (i.cachedOffset! + i.cachedHeight! > (scrollController!.position.pixels + topOffset)) &&
					 (i.cachedOffset! < (scrollController!.position.pixels + scrollController!.position.viewportDimension - bottomOffset));
	}
	bool isOnscreen(T item) {
		if (scrollControllerPositionLooksGood) {
			return _items.any((i) {
				return (i.item.item == item) &&
							 _isOnscreen(i);
			});
		}
		return false;
	}
	Future<void> blockAndUpdate() async {
		_lastLaidOutRange = null;
		state?.originalList = null;
		state?.sortedList = null;
		state?._lastTreeOrder = null;
		state?._rebuild(); // Force [block]
		setItems([]);
		await state?.update();
		slowScrolls.didUpdate(now: true);
	}
	Future<void> update() async {
		await state?.update();
	}
	Future<void> _alignToItemIfPartiallyAboveFold(RefreshableListItem<T> item) async {
		final found = _items.tryFirstWhere((i) => i.item == item);
		if (found != null && found.cachedOffset != null && (found.cachedOffset! < (scrollController?.offset ?? 0))) {
			scrollController?.animateTo(
				found.cachedOffset! - MediaQuery.paddingOf(state!.context).top,
				duration: const Duration(milliseconds: 200),
				curve: Curves.ease
			);
		}
	}

	Future<void> waitForItemBuild(int item) async {
		if (_items.length > item && _items[item].hasGoodState) {
			return;
		}
		final c = Completer();
		_itemCacheCallbacks.putIfAbsent(const (0, true), () => []).add(c);
		await c.future;
	}

	TreeItemCollapseType? isItemHidden(RefreshableListItem<T> item) {
		return state?._refreshableTreeItems.isItemHidden(item);
	}

	void didFinishLayout(int startIndex, int endIndex) {
		if (endIndex >= _items.length) {
			_lastLaidOutRange = null;
			// Out of sync
			return;
		}
		_lastLaidOutRange = (startIndex, endIndex);
		if (state?.searching == false) {
			for (int i = startIndex; i <= endIndex; i++) {
				_tryCachingItem(i);
			}
			_newInsertIndices.removeWhere((i, item) {
				if (i < startIndex || i >= endIndex) {
					// i >= endIndex is used to always reveal the last item
					state?._refreshableTreeItems.revealNewInsert(item);
					return true;
				}
				return false;
			});
		}
		else {
			for (final item in _newInsertIndices.values) {
				state?._refreshableTreeItems.revealNewInsert(item);
			}
			_newInsertIndices.clear();
		}
		if (state?._needToTransitionNewlyInsertedItems ?? false) {
			bool removedAnyCaches = false;
			for (final key in state?._refreshableTreeItems.newlyInsertedItems.keys ?? const Iterable<List<int>>.empty()) {
				// Laid-out
				if (state?._refreshableTreeItems.newlyInsertedItems[key] == false) {
					state?._refreshableTreeItems.newlyInsertedItems[key] = true;
					state?._refreshableTreeItems._cache.removeWhere((k, value) => k.thisId == key[key.length - 2]);
					removedAnyCaches = true;
				}
			}
			for (final key in state?._refreshableTreeItems.newlyInsertedStubRepliesForItem.keys ?? const Iterable<List<int>>.empty()) {
				// Laid-out
				if (state?._refreshableTreeItems.newlyInsertedStubRepliesForItem[key] == false) {
					state?._refreshableTreeItems.newlyInsertedStubRepliesForItem[key] = true;
					state?._refreshableTreeItems._cache.removeWhere((k, value) => k.thisId == key[key.length - 1]);
					removedAnyCaches = true;
				}
			}
			if (removedAnyCaches) {
				SchedulerBinding.instance.addPostFrameCallback((_) {
					state?._refreshableTreeItems.notifyListeners();
				});
			}
			state?._needToTransitionNewlyInsertedItems = false;
		}
	}

	bool get scrollControllerPositionLooksGood => scrollController?.tryPosition?.haveDimensions ?? false;

	void mergeTrees() {
		state?._mergeTrees(rebuild: true);
	}

	ValueListenable<({String id, Future<void> future, CancelToken cancelToken})?> get updatingNow => state?.updatingNow ?? const StoppedValueListenable(null);
	
	Future<void> get whenDoneAutoScrolling {
		final position = scrollController?.tryPosition;
		if (position == null) {
			return Future.value(null);
		}
		final completer = Completer<void>();
		void listener() {
			// ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
			if (position.activity is! DrivenScrollActivity) {
				completer.complete();
				position.isScrollingNotifier.removeListener(listener);
			}
		}
		position.isScrollingNotifier.addListener(listener);
		listener();
		return completer.future;
	}
}

extension _Recurve on Curve {
	Curve recurve({
		required double start,
		required double current,
		required double end
	}) {
		// Recurved curve
		final baseIn = ((current - start) / (end - start));
		if (baseIn <= 0.02 || baseIn >= 0.98 || baseIn.isNaN || baseIn.isInfinite) {
			// Give up
			return Curves.easeOut;
		}
		final slopeIn = (end - current) / (end - start);
		final baseOut = transform(baseIn);
		if (baseOut == 0) {
			// Give up
			return Curves.easeOut;
		}
		final slopeOut = 1 / (1 - baseOut);
		return _RecurvedCurve(
			curve: this,
			baseIn: baseIn,
			slopeIn: slopeIn,
			baseOut: baseOut,
			slopeOut: slopeOut
		);
	}
}

class _RecurvedCurve extends Curve {
	const _RecurvedCurve({
		required this.curve,
		required this.baseIn,
		required this.slopeIn,
		required this.baseOut,
		required this.slopeOut
	});

	final Curve curve;
	final double baseIn;
	final double slopeIn;
	final double baseOut;
	final double slopeOut;

	@override
	double transformInternal(double t) => (slopeOut * (curve.transform((baseIn + (slopeIn * t)).clamp(0, 1)) - baseOut));

	@override
	String toString() => '_RecurveCurved($curve, $baseIn -> ${baseIn + slopeIn}, -$baseOut * $slopeOut)';
}

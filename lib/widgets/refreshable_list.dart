import 'dart:async';
import 'dart:math';

import 'package:chan/services/filtering.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/util.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/timed_rebuilder.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tuple/tuple.dart';

const double _overscrollTriggerThreshold = 100;

class FilterAlternative {
	final String name;
	final void Function(String) handler;

	const FilterAlternative({
		required this.name,
		required this.handler
	});
}

class SliverDontRebuildChildBuilderDelegate extends SliverChildBuilderDelegate {
	final List? list;
	final String? id;
	const SliverDontRebuildChildBuilderDelegate(
    super.builder, {
		required this.list,
		this.id,
    super.findChildIndexCallback,
    super.childCount,
    super.addAutomaticKeepAlives,
    super.addRepaintBoundaries,
    super.addSemanticIndexes,
    super.semanticIndexCallback,
    super.semanticIndexOffset
  });

	@override
	bool shouldRebuild(SliverDontRebuildChildBuilderDelegate oldDelegate) => !listEquals(list, oldDelegate.list) || id != oldDelegate.id;
}

class _TreeNode<T extends Object> {
	final T item;
	final int id;
	final int omittedChildCount;
	final List<_TreeNode<T>> children;
	final List<_TreeNode<T>> parents;

	_TreeNode(this.item, this.id, this.omittedChildCount) : children = [], parents = [];

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

	@override
	bool operator == (Object o) => (o is _TreeNode<T>) && (o.item == item);

	@override
	int get hashCode => item.hashCode;
}

class RefreshableListItem<T extends Object> {
	final T item;
	final int omittedChildCount;
	final bool highlighted;
	final bool collapsed;
	final String? filterReason;
	final List<int> parentIds;
	int treeChildrenCount;

	RefreshableListItem({
		required this.item,
		this.highlighted = false,
		this.collapsed = false,
		this.filterReason,
		this.parentIds = const [],
		this.treeChildrenCount = 0,
		this.omittedChildCount = 0
	});

	@override
	bool operator == (Object other) => (other is RefreshableListItem<T>) && (other.item == item) && (other.highlighted == highlighted) && (other.collapsed == collapsed) && (other.filterReason == filterReason) && listEquals(other.parentIds, parentIds) && (other.treeChildrenCount == treeChildrenCount);
	@override
	int get hashCode => Object.hash(item, highlighted, collapsed, filterReason, parentIds, treeChildrenCount);

	RefreshableListItem<T> copyWith({
		List<int>? parentIds,
		int? omittedChildCount
	}) => RefreshableListItem(
		item: item,
		highlighted: highlighted,
		collapsed: collapsed,
		filterReason: filterReason,
		parentIds: parentIds ?? this.parentIds,
		treeChildrenCount: treeChildrenCount,
		omittedChildCount: omittedChildCount ?? this.omittedChildCount,
	);

	int get depth {
		if (omittedChildCount > 0) {
			return parentIds.length + 1;
		}
		return parentIds.length;
	}
}

class RefreshableTreeAdapter<T extends Object> {
	final int Function(T item) getId;
	final Iterable<int> Function(T item) getParentIds;
	final int Function(T item) getOmittedChildCount;
	final Future<List<T>> Function(List<T>, T) updateWithOmittedChildren;
	final Widget Function(Widget, List<int>) wrapTreeChild;
	final int opId;

	const RefreshableTreeAdapter({
		required this.getId,
		required this.getParentIds,
		required this.getOmittedChildCount,
		required this.updateWithOmittedChildren,
		required this.opId,
		required this.wrapTreeChild
	});
}

enum _TreeItemCollapseType {
	collapsed,
	childCollapsed
}

class _CollapsedRefreshableTreeItems extends ChangeNotifier {
	final List<List<int>> collapsedItems = [];

	_TreeItemCollapseType? isItemHidden(List<int> parentIds, int? thisId) {
		// By iterating reversed it will properly handle collapses within collapses
		for (final collapsed in collapsedItems.reversed) {
			if (collapsed.length > parentIds.length + 1) {
				continue;
			}
			bool keepGoing = true;
			for (int i = 0; i < collapsed.length - 1 && keepGoing; i++) {
				keepGoing = collapsed[i] == parentIds[i];
			}
			if (!keepGoing) {
				continue;
			}
			if (collapsed.length == parentIds.length + 1) {
				if (collapsed.last == thisId) {
					return _TreeItemCollapseType.collapsed;
				}
				continue;
			}
			if (collapsed.last == parentIds[collapsed.length - 1]) {
				return _TreeItemCollapseType.childCollapsed;
			}
		}
		return null;
	}

	void hideItem(List<int> parentIds, int thisId) {
		collapsedItems.add([
			...parentIds,
			thisId
		]);
		notifyListeners();
	}

	void unhideItem(List<int> parentIds, int thisId) {
		final x = [
			...parentIds,
			thisId
		];
		collapsedItems.removeWhere((w) => listEquals(w, x));
		notifyListeners();
	}
}

class RefreshableList<T extends Object> extends StatefulWidget {
	final Widget Function(BuildContext context, T value) itemBuilder;
	final Widget Function(BuildContext context, T? value, int collapsedChildrenCount)? collapsedItemBuilder;
	final List<T>? initialList;
	final Future<List<T>?> Function() listUpdater;
	final Future<List<T>> Function(T after)? listExtender;
	final String id;
	final RefreshableListController<T>? controller;
	final String? filterHint;
	final Widget Function(BuildContext context, T value, VoidCallback resetPage, String filter)? filteredItemBuilder;
	final Duration? autoUpdateDuration;
	final Map<Type, Widget Function(BuildContext, VoidCallback)> remedies;
	final bool disableUpdates;
	final Widget? footer;
	final Size? gridSize;
	final String? initialFilter;
	final ValueChanged<String?>? onFilterChanged;
	final bool allowReordering;
	final ValueChanged<T>? onWantAutosave;
	final Filterable Function(T)? filterableAdapter;
	final FilterAlternative? filterAlternative;
	final bool useTree;
	final RefreshableTreeAdapter<T>? treeAdapter;
	final List<Comparator<T>> sortMethods;

	const RefreshableList({
		required this.itemBuilder,
		required this.listUpdater,
		this.listExtender,
		required this.id,
		this.controller,
		this.filterHint,
		this.filteredItemBuilder,
		this.autoUpdateDuration,
		this.remedies = const {},
		this.initialList,
		this.disableUpdates = false,
		this.gridSize,
		this.footer,
		this.initialFilter,
		this.onFilterChanged,
		this.allowReordering = false,
		this.onWantAutosave,
		required this.filterableAdapter,
		this.filterAlternative,
		this.useTree = false,
		this.treeAdapter,
		this.collapsedItemBuilder,
		this.sortMethods = const [],
		Key? key
	}) : super(key: key);

	@override
	createState() => RefreshableListState<T>();
}

class RefreshableListState<T extends Object> extends State<RefreshableList<T>> with TickerProviderStateMixin {
	List<T>? list;
	String? errorMessage;
	Type? errorType;
	SearchFilter? _searchFilter;
	bool updatingNow = false;
	late final TextEditingController _searchController;
	late final FocusNode _searchFocusNode;
	DateTime? lastUpdateTime;
	DateTime? nextUpdateTime;
	Timer? autoUpdateTimer;
	GlobalKey _scrollViewKey = GlobalKey();
	GlobalKey _sliverListKey = GlobalKey();
	int _pointerDownCount = 0;
	bool _showFilteredValues = false;
	bool _searchTapped = false;
	bool _overscrollEndingNow = false;
	late final AnimationController _footerShakeAnimation;
	List<RefreshableListItem<T>> _listAfterFiltering = [];
	DateTime _lastPointerUpTime = DateTime(2000);
	final Set<int> _collapsedIds = {};

	@override
	void initState() {
		super.initState();
		_searchController = TextEditingController();
		_searchFocusNode = FocusNode();
		 _footerShakeAnimation = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
		if (widget.initialFilter != null) {
			_searchFilter = SearchFilter(widget.initialFilter!);
			_searchTapped = true;
			_searchController.text = widget.initialFilter!;
		}
		widget.controller?.attach(this);
		widget.controller?.newContentId(widget.id);
		list = widget.initialList?.toList();
		if (list != null) {
			_sortList(list!);
		}
		if (!widget.disableUpdates) {
			update();
			resetTimer();
		}
	}

	@override
	void didUpdateWidget(RefreshableList<T> oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.id != widget.id) {
			autoUpdateTimer?.cancel();
			autoUpdateTimer = null;
			widget.controller?.newContentId(widget.id);
			_scrollViewKey = GlobalKey();
			_sliverListKey = GlobalKey();
			_closeSearch();
			list = widget.initialList;
			errorMessage = null;
			errorType = null;
			lastUpdateTime = null;
			_collapsedIds.clear();
			update();
		}
		else if (oldWidget.disableUpdates != widget.disableUpdates) {
			autoUpdateTimer?.cancel();
			autoUpdateTimer = null;
			if (!widget.disableUpdates) {
				update();
				resetTimer();
			}
		}
		else if (widget.disableUpdates && !listEquals(oldWidget.initialList, widget.initialList)) {
			list = widget.initialList;
		}
		if (!listEquals(widget.sortMethods, oldWidget.sortMethods) && list != null) {
			_sortList(list!);
		}
	}

	@override
	void dispose() {
		super.dispose();
		autoUpdateTimer?.cancel();
		_searchController.dispose();
		_searchFocusNode.dispose();
		_footerShakeAnimation.dispose();
	}

	void _sortList(List<T> theList) {
		for (final method in widget.sortMethods) {
			mergeSort<T>(theList, compare: method);
		}
	}

	void resetTimer() {
		autoUpdateTimer?.cancel();
		if (widget.autoUpdateDuration != null && !widget.useTree) {
			autoUpdateTimer = Timer(widget.autoUpdateDuration!, update);
			nextUpdateTime = DateTime.now().add(widget.autoUpdateDuration!);
		}
		else {
			nextUpdateTime = DateTime.now().add(const Duration(days: 1000));
		}
	}

	void _closeSearch() {
		_searchFocusNode.unfocus();
		_searchController.clear();
		setState(() {
			_searchTapped = false;
			_searchFilter = null;
		});
		widget.onFilterChanged?.call(null);
	}

	void _focusSearch() {
		_searchFocusNode.requestFocus();
		_searchTapped = true;
		setState(() {});
	}

	Future<void> update({bool hapticFeedback = false, bool extend = false}) async {
		if (updatingNow) {
			return;
		}
		final updatingWithId = widget.id;
		List<T>? newList;
		try {
			setState(() {
				errorMessage = null;
				errorType = null;
				updatingNow = true;
			});
			Duration minUpdateDuration = const Duration(milliseconds: 500);
			if (widget.controller?.scrollController?.positions.length == 1 && (widget.controller!.scrollController!.position.pixels > 0 && (widget.controller!.scrollController!.position.pixels <= widget.controller!.scrollController!.position.maxScrollExtent))) {
				minUpdateDuration = const Duration(seconds: 1);
			}
			if (extend && widget.listExtender != null && (list?.isNotEmpty ?? false)) {
				final newItems = await widget.listExtender!(list!.last);
				newList = list!.followedBy(newItems).toList();
			}
			else {
				newList = (await Future.wait([widget.listUpdater(), Future<List<T>?>.delayed(minUpdateDuration)])).first?.toList();
			}
			if (newList != null) {
				_sortList(newList);
			}
			if (updatingWithId != widget.id) {
				updatingNow = false;
				return;
			}
			resetTimer();
			lastUpdateTime = DateTime.now();
		}
		catch (e, st) {
			errorMessage = e.toStringDio();
			errorType = e.runtimeType;
			if (mounted) {
				showToast(
					context: context,
					message: 'Error loading ${widget.id}: $errorMessage',
					icon: CupertinoIcons.exclamationmark_triangle
				);
				if (widget.remedies[errorType] == null) {
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
		if (widget.controller?.scrollController?.positions.length == 1 && widget.controller?.scrollController?.position.isScrollingNotifier.value == true) {
			final completer = Completer<void>();
			void listener() {
				if (widget.controller?.scrollController?.position.isScrollingNotifier.value == false) {
					completer.complete();
				}
			}
			widget.controller!.scrollController!.position.isScrollingNotifier.addListener(listener);
			await Future.any([completer.future, Future.delayed(const Duration(seconds: 3))]);
			if (!mounted) return;
			widget.controller?.scrollController?.position.isScrollingNotifier.removeListener(listener);
			if (updatingWithId != widget.id) {
				updatingNow = false;
				return;
			}
		}
		updatingNow = false;
		if (mounted && (newList != null || list == null || errorMessage != null)) {
			if (hapticFeedback) {
				mediumHapticFeedback();
			}
			setState(() {
				list = newList ?? list;
			});
		}
	}

	Future<void> _updateWithHapticFeedback() async {
		await update(hapticFeedback: true, extend: false);
	}

	Future<void> _updateOrExtendWithHapticFeedback() async {
		await update(hapticFeedback: true, extend: true);
	}

	Widget _itemBuilder(BuildContext context, RefreshableListItem<T> value) {
		Widget child;
		Widget? collapsed;
		int? id = widget.treeAdapter?.getId(value.item);
		if (_searchFilter != null && widget.filteredItemBuilder != null) {
			child = widget.filteredItemBuilder!(context, value.item, _closeSearch, _searchFilter!.text);
		}
		else {
			if (value.omittedChildCount > 0) {
				child = widget.collapsedItemBuilder?.call(context, null, value.treeChildrenCount) ?? Container(
					height: 30,
					alignment: Alignment.center,
					child: Text('${value.omittedChildCount} more replies...')
				);
			}
			else {
				child = widget.itemBuilder(context, value.item);
				collapsed = widget.collapsedItemBuilder?.call(context, value.item, value.treeChildrenCount);
			}
			if (widget.treeAdapter != null && widget.useTree) {
				final isHidden = context.select<_CollapsedRefreshableTreeItems, _TreeItemCollapseType?>((c) => c.isItemHidden(value.parentIds, id));
				if (value.parentIds.isNotEmpty) {
					child = widget.treeAdapter!.wrapTreeChild(child, value.parentIds);
				}
				child = AnimatedCrossFade(
					duration: const Duration(milliseconds: 350),
					sizeCurve: Curves.ease,
					firstCurve: Curves.ease,
					//secondCurve: Curves.ease,
					firstChild: child,
					secondChild: (isHidden != _TreeItemCollapseType.childCollapsed && value.omittedChildCount == 0) ? (collapsed ?? const SizedBox(
						height: 30,
						width: double.infinity,
						child: Text('Something hidden')
					)) : const SizedBox(
						height: 0,
						width: double.infinity
					),
					crossFadeState: isHidden == null ? CrossFadeState.showFirst : CrossFadeState.showSecond,
				);
				child = GestureDetector(
					behavior: HitTestBehavior.translucent,
					onTap: () async {
						if (value.omittedChildCount == 0) {
							if (isHidden != null) {
								context.read<_CollapsedRefreshableTreeItems>().unhideItem(value.parentIds, id!);
							}
							else {
								context.read<_CollapsedRefreshableTreeItems>().hideItem(value.parentIds, id!);
							}
						}
						else {
							final newList = await widget.treeAdapter!.updateWithOmittedChildren(list!, value.item);
							_sortList(newList);
							setState(() {
								list = newList;
							});
						}
					},
					child: child
				);
			}
		}
		if (value.highlighted) {
			child = ClipRect(
				child: ColorFiltered(
					colorFilter: ColorFilter.mode(CupertinoTheme.of(context).textTheme.actionTextStyle.color?.withOpacity(0.2) ?? Colors.white.withOpacity(0.2), BlendMode.srcOver),
					child: child
				)
			);
		}
		if (value.depth > 0) {
			child = Container(
				margin: EdgeInsets.only(left: (value.depth * 20) - 5),
				decoration: BoxDecoration(
					border: Border(left: BorderSide(
						width: 5,
						color: context.select<EffectiveSettings, Color>((s) => s.theme.primaryColor).withSaturation(0.5).shiftHue(value.depth * 25).withOpacity(0.7)
					))
				),
				child: child
			);
		}
		return child;
	}

	List<RefreshableListItem<T>> _reassembleAsTree(List<RefreshableListItem<T>> linear) {
		// In case the list is not in sequential order by id
		final orphans = <int, List<_TreeNode<RefreshableListItem<T>>>>{};
		final treeMap = <int, _TreeNode<RefreshableListItem<T>>>{};
		final treeRoots = <_TreeNode<RefreshableListItem<T>>>[];

		final adapter = widget.treeAdapter;
		if (adapter == null) {
			print('Tried to reassemble a tree of $T with a null adapter');
			return linear;
		}

		for (final item in linear) {
			final id = adapter.getId(item.item);
			final node = _TreeNode(item, id, adapter.getOmittedChildCount(item.item));
			treeMap[id] = node;
			node.children.addAll(orphans[id] ?? []);
			final parentIds = adapter.getParentIds(item.item).toList();
			if (id == adapter.opId) {
				treeRoots.insert(0, node);
			}
			else if (parentIds.isEmpty || (parentIds.length == 1 && parentIds.single == adapter.opId)) {
				treeRoots.add(node);
				final op = treeMap[adapter.opId];
				if (op != null) {
					node.parents.add(op);
				}
			}
			else {
				// Will only work with sequential ids
				node.parents.addAll(parentIds.map((id) => treeMap[id]).where((p) => p != null).map((p) => p!));
			}
			if (parentIds.length > 1) {
				// Avoid multiple child subtrees in the same root tree
				// This doesn't handle orphans case, but that should only happen on Reddit,
				// which doesn't have multiple parents anyways.
				final parents = parentIds.map((id) => treeMap[id]).where((p) => p != null).map((p) => p!).toList();
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
			for (final parentId in parentIds) {
				if (parentId == adapter.opId) continue;
				treeMap[parentId]?.children.add(node);
				if (treeMap[parentId] == null) {
					orphans.putIfAbsent(parentId, () => []).add(node);
				}
			}
		}

		final out = <RefreshableListItem<T>>[];
		int dumpNode(_TreeNode<RefreshableListItem<T>> node, List<int> parentIds) {
			final item = node.item.copyWith(parentIds: parentIds);
			out.add(item);
			for (final child in node.children) {
				item.treeChildrenCount += 1 + dumpNode(child, [
					...parentIds,
					node.id
				]);
			}
			if (node.omittedChildCount > 0) {
				out.add(item.copyWith(omittedChildCount: node.omittedChildCount));
				item.treeChildrenCount += item.omittedChildCount;
			}
			return item.treeChildrenCount;
		}
		for (final root in treeRoots) {
			dumpNode(root, []);
		}
		return out;
	}

	@override
	Widget build(BuildContext context) {
		widget.controller?.reportPrimaryScrollController(PrimaryScrollController.of(context));
		widget.controller?.topOffset = MediaQuery.of(context).padding.top;
		widget.controller?.bottomOffset = MediaQuery.of(context).padding.bottom;
		if (list != null) {
			final pinnedValues = <RefreshableListItem<T>>[];
			List<RefreshableListItem<T>> values = [];
			final filteredValues = <RefreshableListItem<T>>[];
			final filters = [
				if (_searchFilter != null) _searchFilter!,
				Filter.of(context)
			];
			for (final item in list!) {
				bool handled = false;
				for (final filter in filters) {
					final result = widget.filterableAdapter != null ? filter.filter(widget.filterableAdapter!(item)) : null;
					if (result != null) {
						bool pinned = false;
						if (result.type.pinToTop && widget.allowReordering) {
							pinned = true;
							pinnedValues.add(RefreshableListItem(
								item: item,
								highlighted: true
							));
						}
						if (result.type.autoSave) {
							widget.onWantAutosave?.call(item);
						}
						if (result.type.hide) {
							filteredValues.add(RefreshableListItem(
								item: item,
								filterReason: result.reason
							));
						}
						else if (!pinned) {
							values.add(RefreshableListItem(
								item: item,
								highlighted: result.type.highlight
							));
						}
						handled = true;
						break;
					}
				}
				if (!handled) {
					values.add(RefreshableListItem(item: item));
				}
			}
			values.insertAll(0, pinnedValues);
			if (!listEquals(values, _listAfterFiltering)) {
				_listAfterFiltering = values.toList();
				widget.controller?.setItems(values);
			}
			else if (widget.controller?._items.isEmpty ?? false) {
				widget.controller?.setItems(values);
			}
			if (widget.useTree) {
				values = _reassembleAsTree(values);
			}
			if (filteredValues.isEmpty) {
				// Don't auto open filtered values after clearing it before
				_showFilteredValues = false;
			}
			final shakeAnimation = CurvedAnimation(
				curve: Curves.easeInOutCubic,
				parent: _footerShakeAnimation
			);
			return NotificationListener<ScrollNotification>(
				key: ValueKey(widget.id),
				onNotification: (notification) {
					if (updatingNow) {
						return false;
					}
					final bool isScrollEnd = (notification is ScrollEndNotification) || (notification is ScrollUpdateNotification && notification.dragDetails == null);
					final bool plausible = DateTime.now().difference(_lastPointerUpTime) < const Duration(milliseconds: 100);
					if (widget.controller != null && isScrollEnd && plausible) {
						if (!_overscrollEndingNow) {
							double overscroll = widget.controller!.scrollController!.position.pixels - widget.controller!.scrollController!.position.maxScrollExtent;
							if (overscroll > _overscrollTriggerThreshold && !widget.disableUpdates) {
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
					child: GestureDetector(
						onTap: () {
							if (widget.controller?.scrollController != null && (widget.controller!.scrollController!.position.userScrollDirection != ScrollDirection.idle) && _pointerDownCount == 0) {
								widget.controller!.scrollController!.jumpTo(widget.controller!.scrollController!.position.pixels);
							}
							widget.controller?.cancelCurrentAnimation();
						},
						child: MaybeCupertinoScrollbar(
							controller: widget.controller?.scrollController,
							child: ChangeNotifierProvider<_CollapsedRefreshableTreeItems>(
								create: (context) => _CollapsedRefreshableTreeItems(),
								child: CustomScrollView(
									key: _scrollViewKey,
									cacheExtent: 1000,
									controller: widget.controller?.scrollController,
									physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
									slivers: [
										SliverSafeArea(
											sliver: widget.disableUpdates ? SliverToBoxAdapter(
												child: Container()
											) : CupertinoSliverRefreshControl(
												onRefresh: _updateWithHapticFeedback,
												refreshTriggerPullDistance: 125
											),
											bottom: false
										),
										if ((list?.isNotEmpty ?? false) && widget.filterableAdapter != null) SliverToBoxAdapter(
											child: Container(
												height: kMinInteractiveDimensionCupertino * context.select<EffectiveSettings, double>((s) => s.textScale),
												padding: const EdgeInsets.all(4),
												child: Row(
													mainAxisSize: MainAxisSize.min,
													children: [
														Expanded(
															child: Center(
																child: CupertinoSearchTextField(
																	prefixIcon: const Padding(
																		padding: EdgeInsets.only(top: 2),
																		child: Icon(CupertinoIcons.search)
																	),
																	onTap: () {
																		setState(() {
																			_searchTapped = true;
																		});
																	},
																	onChanged: (searchText) {
																		setState(() {
																			_searchFilter = SearchFilter(searchText.toLowerCase());
																		});
																		widget.onFilterChanged?.call(searchText);
																	},
																	controller: _searchController,
																	focusNode: _searchFocusNode,
																	placeholder: widget.filterHint,
																	smartQuotesType: SmartQuotesType.disabled,
																	smartDashesType: SmartDashesType.disabled
																)
															),
														),
														if (_searchTapped) CupertinoButton(
															padding: const EdgeInsets.only(left: 8),
															onPressed: _closeSearch,
															child: const Text('Cancel')
														)
													]
												)
											)
										),
										if (filteredValues.isNotEmpty && widget.filterAlternative != null) SliverToBoxAdapter(
											child: Container(
												decoration: BoxDecoration(
													border: Border(
														top: BorderSide(color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2)),
														bottom: BorderSide(color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2))
													)
												),
												child: CupertinoButton(
													padding: const EdgeInsets.all(16),
													onPressed: () {
														_searchFocusNode.unfocus();
														widget.filterAlternative!.handler(_searchFilter!.text);
													},
													child: Row(
														children: [
															const Icon(CupertinoIcons.search),
															const SizedBox(width: 8),
															Text('Search ${widget.filterAlternative?.name}')
														]
													)
												)
											)
										),
										if (values.isNotEmpty)
											if (widget.gridSize != null) SliverGrid(
												key: PageStorageKey('grid for ${widget.id}'),
												gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
													maxCrossAxisExtent: widget.gridSize!.width,
													childAspectRatio: widget.gridSize!.aspectRatio
												),
												delegate: SliverDontRebuildChildBuilderDelegate(
													(context, i) => Builder(
														builder: (context) {
															widget.controller?.registerItem(i, values[i], context);
															return _itemBuilder(context, values[i]);
														}
													),
													list: values,
													id: widget.filteredItemBuilder != null ? _searchFilter?.text : null,
													childCount: values.length,
													addRepaintBoundaries: false,
													addAutomaticKeepAlives: false
												)
											)
											else SliverList(
												key: _sliverListKey,
												delegate: SliverDontRebuildChildBuilderDelegate(
													(context, i) {
														final childIndex = i ~/ 2;
														if (i % 2 == 0) {
															return Builder(
																builder: (context) {
																	widget.controller?.registerItem(childIndex, values[childIndex], context);
																	return _itemBuilder(context, values[childIndex]);
																}
															);
														}
														else {
															int depth = values[childIndex].depth;
															if (childIndex < (values.length - 1)) {
																depth = min(depth, values[childIndex + 1].depth);
															}
															return Padding(
																padding: EdgeInsets.only(left: depth * 20),
																child: Divider(
																	thickness: 1,
																	height: 0,
																	color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2)
																)
															);
														}
													},
													list: values,
													id: widget.filteredItemBuilder != null ? _searchFilter?.text : null,
													childCount: values.length * 2,
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
										if (filteredValues.isNotEmpty) ...[
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
																	color: CupertinoTheme.of(context).primaryColorWithBrightness(0.4)
																)
															)
														)
													)
												),
											),
											if (_showFilteredValues) 
												if (widget.gridSize != null) SliverGrid(
													key: PageStorageKey('filtered grid for ${widget.id}'),
													gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
														maxCrossAxisExtent: widget.gridSize!.width,
														childAspectRatio: widget.gridSize!.aspectRatio
													),
													delegate: SliverDontRebuildChildBuilderDelegate(
														(context, i) => Stack(
															children: [
																Builder(
																	builder: (context) => _itemBuilder(context, filteredValues[i])
																),
																Align(
																	alignment: Alignment.topRight,
																	child: Padding(
																		padding: const EdgeInsets.only(top: 8, right: 8),
																		child: CupertinoButton.filled(
																			padding: EdgeInsets.zero,
																			child: const Icon(CupertinoIcons.question),
																			onPressed: () {
																				showCupertinoDialog(
																					context: context,
																					barrierDismissible: true,
																					builder: (context) => CupertinoAlertDialog(
																						title: const Text('Filter reason'),
																						content: Text(filteredValues[i].filterReason ?? 'Unknown'),
																						actions: [
																							CupertinoDialogAction(
																								child: const Text('OK'),
																								onPressed: () => Navigator.pop(context)
																							)
																						]
																					)
																				);
																			}
																		)
																	)
																)
															]
														),
														list: filteredValues,
														childCount: filteredValues.length,
														addRepaintBoundaries: false,
														addAutomaticKeepAlives: false
													)
												)
												else SliverList(
													key: PageStorageKey('filtered list for ${widget.id}'),
													delegate: SliverDontRebuildChildBuilderDelegate(
														(context, i) {
															if (i % 2 == 0) {
																return Stack(
																	children: [
																		Builder(
																			builder: (context) => _itemBuilder(context, filteredValues[i ~/ 2])
																		),
																		IgnorePointer(
																			child: Align(
																				alignment: Alignment.topRight,
																				child: Container(
																					padding: const EdgeInsets.all(4),
																					color: CupertinoTheme.of(context).primaryColor,
																					child: Text('Filter reason:\n${filteredValues[i ~/ 2].filterReason}', style: TextStyle(
																						color: CupertinoTheme.of(context).scaffoldBackgroundColor
																					))
																				)
																			)
																		)
																	]
																);
															}
															else {
																return Divider(
																	thickness: 1,
																	height: 0,
																	color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2)
																);
															}
														},
														list: filteredValues,
														childCount: filteredValues.length * 2,
														addRepaintBoundaries: false,
														addAutomaticKeepAlives: false
													)
												)
										],
										if (widget.footer != null && widget.disableUpdates) SliverSafeArea(
											top: false,
											sliver: SliverToBoxAdapter(
												child: widget.footer
											)
										)
										else if (widget.footer != null && !widget.disableUpdates) SliverToBoxAdapter(
											child: RepaintBoundary(
												child: GestureDetector(
													behavior: HitTestBehavior.opaque,
													onTap: updatingNow ? null : () {
														lightHapticFeedback();
														Future.delayed(const Duration(milliseconds: 17), () {
															widget.controller?.scrollController?.animateTo(
																widget.controller!.scrollController!.position.maxScrollExtent,
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
										)
										else if (widget.disableUpdates) SliverSafeArea(
											top: false,
											sliver: SliverToBoxAdapter(
												child: Container()
											)
										),
										if (!widget.disableUpdates) SliverSafeArea(
											top: false,
											sliver: SliverToBoxAdapter(
												child: RepaintBoundary(
													child: RefreshableListFooter(
														updater: _updateOrExtendWithHapticFeedback,
														updatingNow: updatingNow,
														lastUpdateTime: lastUpdateTime,
														nextUpdateTime: nextUpdateTime,
														errorMessage: errorMessage,
														remedy: widget.remedies[errorType]?.call(context, _updateOrExtendWithHapticFeedback),
														overscrollFactor: widget.controller?.overscrollFactor,
														pointerDownNow: () {
															return _pointerDownCount > 0;
														}
													)
												)
											)
										)
									]
								)
							)
						)
					)
				)
			);
		}
		else if (errorMessage != null) {
			return Center(
				child: Column(
					mainAxisAlignment: MainAxisAlignment.center,
					children: [
						ErrorMessageCard('Error loading ${widget.id}:\n${errorMessage?.toStringDio()}'),
						CupertinoButton(
							onPressed: _updateWithHapticFeedback,
							child: const Text('Retry')
						),
						if (widget.remedies[errorType] != null) widget.remedies[errorType]!(context, _updateWithHapticFeedback)
					]
				)
			);
		}
		else {
			return const Center(
				child: CupertinoActivityIndicator()
			);
		}
	}
}

class RefreshableListFooter extends StatelessWidget {
	final String? errorMessage;
	final VoidCallback updater;
	final bool updatingNow;
	final DateTime? lastUpdateTime;
	final DateTime? nextUpdateTime;
	final Widget? remedy;
	final ValueListenable<double>? overscrollFactor;
	final bool Function() pointerDownNow;
	const RefreshableListFooter({
		required this.updater,
		required this.updatingNow,
		this.lastUpdateTime,
		this.nextUpdateTime,
		this.errorMessage,
		this.remedy,
		this.overscrollFactor,
		required this.pointerDownNow,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return GestureDetector(
			behavior: HitTestBehavior.opaque,
			onTap: updatingNow ? null : updater,
			child: Container(
				color: errorMessage != null ? Colors.orange.withOpacity(0.5) : null,
				padding: const EdgeInsets.all(1),
				child: Center(
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							if (errorMessage != null) ...[
								const SizedBox(height: 16),
								Text(
									errorMessage!,
									textAlign: TextAlign.center
								),
								const SizedBox(height: 16)
							],
							if (!updatingNow && remedy != null) ...[
								remedy!,
								const SizedBox(height: 16)
							],
							if (overscrollFactor != null) SizedBox(
								height: updatingNow ? 64 : 0,
								child: OverflowBox(
									maxHeight: 100,
									alignment: Alignment.topCenter,
									child: ValueListenableBuilder(
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
																		if (nextUpdateTime != null && lastUpdateTime != null) TimedRebuilder(
																			enabled: true,
																			interval: const Duration(seconds: 1),
																			builder: (context) {
																				final now = DateTime.now();
																				return LinearProgressIndicator(
																					value: updatingNow ? 0 : now.difference(lastUpdateTime!).inSeconds / nextUpdateTime!.difference(lastUpdateTime!).inSeconds,
																					color: CupertinoTheme.of(context).primaryColor.withOpacity(0.5),
																					backgroundColor: CupertinoTheme.of(context).primaryColorWithBrightness(0.2),
																					minHeight: 8
																				);
																			}
																		),
																		LinearProgressIndicator(
																			value: (updatingNow) ? null : (pointerDownNow() ? smoothedValue : 0),
																			backgroundColor: Colors.transparent,
																			color: CupertinoTheme.of(context).primaryColor,
																			minHeight: 8
																		)
																	]
																)
															)
														)
													)
												]
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
	bool operator == (dynamic o) => (o is _BuiltRefreshableListItem<T>) && o.item == item;

	@override
	int get hashCode => item.hashCode;

	@override
	String toString() => '_RefreshableListItem(item: $item, cachedOffset: $cachedOffset, cachedHeight: $cachedHeight)';
}
class RefreshableListController<T extends Object> {
	List<_BuiltRefreshableListItem<RefreshableListItem<T>>> _items = [];
	Iterable<RefreshableListItem<T>> get items => _items.map((i) => i.item);
	ScrollController? scrollController;
	final overscrollFactor = ValueNotifier<double>(0);
	final BehaviorSubject<void> _scrollStream = BehaviorSubject();
	final BehaviorSubject<void> slowScrollUpdates = BehaviorSubject();
	late final StreamSubscription<List<void>> _slowScrollSubscription;
	double? topOffset;
	double? bottomOffset;
	String? contentId;
	RefreshableListState<T>? state;
	final Map<Tuple2<int, bool>, Completer<void>> _itemCacheCallbacks = {};
	int? currentTargetIndex;
	RefreshableListController() {
		_slowScrollSubscription = _scrollStream.bufferTime(const Duration(milliseconds: 100)).where((batch) => batch.isNotEmpty).listen(_onSlowScroll);
		SchedulerBinding.instance.endOfFrame.then((_) => _onScrollControllerNotification());
	}
	Future<void> _tryCachingItem(int index, _BuiltRefreshableListItem<RefreshableListItem<T>> item) async {
		await SchedulerBinding.instance.endOfFrame;
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
			item.cachedOffset = newOffset;
			final keys = _itemCacheCallbacks.keys.toList();
			for (final position in keys) {
				if (position.item2 && index >= position.item1) {
					// scrolling down
					_itemCacheCallbacks[position]?.complete();
					_itemCacheCallbacks.remove(position);
				}
				else if (!position.item2 && index <= position.item1) {
					// scrolling up
					_itemCacheCallbacks[position]?.complete();
					_itemCacheCallbacks.remove(position);
				}
			}
		}
	}
	void _onSlowScroll(void update) {
		int lastCached = -1;
		for (final entry in _items.asMap().entries) {
			if (entry.value.cachedOffset != null) {
				lastCached = entry.key;
			}
		}
		lastCached++; // Cache the final item if uncached
		for (int i = 0; i < lastCached; i++) {
			if (_items[i].cachedOffset == null) {
				_tryCachingItem(i, _items[i]);
			}
		}
		slowScrollUpdates.add(null);
	}
	void _onScrollControllerNotification() {
		_scrollStream.add(null);
		if ((scrollController?.hasOnePosition ?? false)) {
			final overscrollAmount = scrollController!.position.pixels - scrollController!.position.maxScrollExtent;
			overscrollFactor.value = (overscrollAmount / _overscrollTriggerThreshold).clamp(0, 1);
		}
	}
	void attach(RefreshableListState<T> list) {
		state = list;
	}
	void focusSearch() {
		state?._focusSearch();
	}
	void reportPrimaryScrollController(ScrollController? controller) {
		if (scrollController != controller) {
			scrollController?.removeListener(_onScrollControllerNotification);
			scrollController = controller;
			scrollController?.addListener(_onScrollControllerNotification);
		}
	}
	void dispose() {
		_scrollStream.close();
		_slowScrollSubscription.cancel();
		scrollController?.removeListener(_onScrollControllerNotification);
		slowScrollUpdates.close();
		overscrollFactor.dispose();
	}
	void newContentId(String contentId) {
		this.contentId = contentId;
		_items = [];
		for (final cb in _itemCacheCallbacks.values) {
			cb.completeError(Exception('page changed'));
		}
		_itemCacheCallbacks.clear();
	}
	void setItems(List<RefreshableListItem<T>> items) {
		if (items.isNotEmpty && _items.isNotEmpty && items.first == _items.first.item) {
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
		else {
			_items = items.map((item) => _BuiltRefreshableListItem(item)).toList();
		}
	}
	void registerItem(int index, RefreshableListItem<T> item, BuildContext context) {
		if (index < _items.length) {
			_items[index].item = item;
			_items[index].context = context;
			_tryCachingItem(index, _items[index]);
		}
	}
	double _getOffset(RenderObject object) {
		return RenderAbstractViewport.of(object)!.getOffsetToReveal(object, 0.0).offset;
	}
	double? _estimateOffset(int targetIndex) {
		final heightedItems = _items.map((i) => i.cachedHeight).where((i) => i != null);
		if (heightedItems.length < 2) return null;
		final averageItemHeight = heightedItems.reduce((a, b) => a! + b!)! / heightedItems.length;
		int nearestDistance = _items.length + 1;
		double? estimate;
		for (int i = 0; i < _items.length; i++) {
			if (_items[i].cachedOffset != null) {
				final distance = (targetIndex - i).abs();
				if (distance < nearestDistance) {
					estimate = _items[i].cachedOffset! + (averageItemHeight * (targetIndex - i));
					nearestDistance = distance;
				}
			}
		}
		return estimate;
	}
	Future<void> animateTo(bool Function(T val) f, {double alignment = 0.0, bool Function(T val)? orElseLast, Duration duration = const Duration(milliseconds: 200)}) async {
		final start = DateTime.now();
		int targetIndex = _items.indexWhere((i) => f(i.item.item));
		if (targetIndex == -1) {
			if (orElseLast != null) {
				targetIndex = _items.lastIndexWhere((i) => orElseLast(i.item.item));
			}
			if (targetIndex == -1) {
				throw StateError('No matching item to scroll to');
			}
		}
		print('$contentId animating to $targetIndex');
		currentTargetIndex = targetIndex;
		Duration d = duration;
		Curve c = Curves.easeIn;
		final initialContentId = contentId;
		Future<bool> attemptResolve() async {
			final completer = Completer<void>();
			double estimate = (_estimateOffset(targetIndex) ?? scrollController!.position.maxScrollExtent) - topOffset!;
			if (_items.last.cachedOffset != null) {
				// prevent overscroll
				estimate = max(estimate, scrollController!.position.maxScrollExtent);
			}
			_itemCacheCallbacks[Tuple2(targetIndex, estimate > scrollController!.position.pixels)] = completer;
			final delay = Duration(milliseconds: min(300, max(1, (estimate - scrollController!.position.pixels).abs() ~/ 100)));
			scrollController!.animateTo(
				estimate,
				duration: delay,
				curve: c
			);
			await Future.any([completer.future, Future.wait([Future.delayed(const Duration(milliseconds: 32)), Future.delayed(delay ~/ 4)])]);
			return (_items[targetIndex].cachedOffset != null);
		}
		if (_items[targetIndex].cachedOffset == null) {
			while (contentId == initialContentId && !(await attemptResolve()) && DateTime.now().difference(start).inSeconds < 5 && targetIndex == currentTargetIndex) {
				c = Curves.linear;
			}
			if (initialContentId != contentId) {
				print('List was hijacked ($initialContentId -> $contentId)');
				return;
			}
			if (currentTargetIndex != targetIndex) {
				print('animateTo was hijacked ($targetIndex -> $currentTargetIndex)');
				return;
			}
			Duration timeLeft = duration - DateTime.now().difference(start);
			if (timeLeft.inMilliseconds.isNegative) {
				d = duration ~/ 4;
			}
			else {
				d = Duration(milliseconds: min(timeLeft.inMilliseconds, duration.inMilliseconds ~/ 4));
			}
		}
		if (_items[targetIndex].cachedOffset == null) {
			throw Exception('Scrolling timed out');
		}
		double atAlignment0 = _items[targetIndex].cachedOffset! - topOffset!;
		final alignmentSlidingWindow = scrollController!.position.viewportDimension - _items[targetIndex].cachedHeight! - topOffset! - bottomOffset!;
		if (_items[targetIndex] == _items.last) {
			// add offset to reveal the full footer
			atAlignment0 += 110;
		}
		else {
			atAlignment0 += 1;
		}
		double finalDestination = (atAlignment0 - (alignmentSlidingWindow * alignment)).clamp(0, scrollController!.position.maxScrollExtent);
		await scrollController!.animateTo(
			max(0, finalDestination),
			duration: Duration(milliseconds: max(1, d.inMilliseconds)),
			curve: Curves.easeOut
		);
		await SchedulerBinding.instance.endOfFrame;
	}
	void cancelCurrentAnimation() {
		currentTargetIndex = null;
	}
	int get firstVisibleIndex {
		if (scrollController?.hasOnePosition ?? false) {
			return _items.lastIndexWhere((i) => (i.cachedOffset != null) && (i.cachedOffset! <= scrollController!.position.pixels));
		}
		return -1;
	}
	T? get firstVisibleItem {
		final index = firstVisibleIndex;
		return index < 0 ? null : _items[index].item.item;
	}
	T? get middleVisibleItem {
		if (scrollController?.hasOnePosition ?? false) {
			int index = _items.indexWhere((i) => (i.cachedOffset != null) && (i.cachedOffset! > (scrollController!.position.pixels + (scrollController!.position.viewportDimension / 2))));
			if (index != -1) {
				if (index > 0) {
					// It will be one too far, we want the item which covers the middle pixel row
					index--;
				}
				return _items[index].item.item;
			}
		}
		return null;
	}
	int get lastVisibleIndex {
		if (scrollController?.hasOnePosition ?? false) {
			return _items.lastIndexWhere((i) => (i.cachedOffset != null) && (i.cachedOffset! + i.cachedHeight!) < (scrollController!.position.pixels + scrollController!.position.viewportDimension));
		}
		return -1;
	}
	T? get lastVisibleItem {
		if (scrollController?.hasOnePosition ?? false) {
			if (_items.isNotEmpty &&
					_items.first.cachedHeight != null &&
					_items.first.cachedHeight! > (scrollController!.position.pixels + scrollController!.position.viewportDimension)) {
				return _items.first.item.item;
			}
			return _items.tryLastWhere((i) {
				return (i.cachedOffset != null) &&
							 ((i.cachedOffset! + i.cachedHeight!) < (scrollController!.position.pixels + scrollController!.position.viewportDimension));
			})?.item.item;
		}
		return null;
	}
	Future<void> blockAndUpdate() async {
		state?.list = null;
		setItems([]);
		await state?.update();
		slowScrollUpdates.add(null);
	}
	Future<void> update() async {
		await state?.update();
	}
}

extension HasOnePosition on ScrollController {
	// ignore: INVALID_USE_OF_PROTECTED_MEMBER
	bool get hasOnePosition => positions.length == 1;
}
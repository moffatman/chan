import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Builds one of the item-count indicators shown at a physical viewport edge.
///
/// [hiddenItemCount] is the number of items beyond [edge]. For example, an
/// [AxisDirection.left] edge receives the number of items hidden to the left.
typedef PaginatedReorderableListIndicatorBuilder = Widget Function(
    BuildContext context, int hiddenItemCount, AxisDirection edge);

enum _AlignmentPullEdge { leading, trailing }

class _ReorderProxyDropListener extends StatefulWidget {
  final Animation<double> animation;
  final Listenable scrollPosition;
  final Offset Function() scrollTranslation;
  final VoidCallback onDropCompleted;
  final Widget child;

  const _ReorderProxyDropListener(
      {required this.animation,
      required this.scrollPosition,
      required this.scrollTranslation,
      required this.onDropCompleted,
      required this.child});

  @override
  State<_ReorderProxyDropListener> createState() =>
      _ReorderProxyDropListenerState();
}

class _ReorderProxyDropListenerState
    extends State<_ReorderProxyDropListener> {
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    widget.animation.addListener(_handleAnimation);
    widget.scrollPosition.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(_ReorderProxyDropListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeListener(_handleAnimation);
      widget.animation.addListener(_handleAnimation);
      _completed = false;
    }
    if (oldWidget.scrollPosition != widget.scrollPosition) {
      oldWidget.scrollPosition.removeListener(_handleScroll);
      widget.scrollPosition.addListener(_handleScroll);
    }
  }

  void _handleScroll() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleAnimation() {
    // ReorderableList disposes this controller from its dismissed status
    // listener, so observe the final reverse tick before status listeners run.
    if (!_completed &&
        widget.animation.status == AnimationStatus.reverse &&
        widget.animation.value == 0) {
      _completed = true;
      widget.onDropCompleted();
    }
  }

  @override
  void dispose() {
    widget.animation.removeListener(_handleAnimation);
    widget.scrollPosition.removeListener(_handleScroll);
    if (!_completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onDropCompleted();
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Transform.translate(offset: widget.scrollTranslation(), child: widget.child);
}

class _PaginatedPageScrollPhysics extends PageScrollPhysics {
  final double gutterExtent;
  final PaginatedReorderableListDelegate paginationDelegate;

  const _PaginatedPageScrollPhysics(
      {required this.gutterExtent,
      required this.paginationDelegate,
      super.parent});

  @override
  _PaginatedPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _PaginatedPageScrollPhysics(
        gutterExtent: gutterExtent,
        paginationDelegate: paginationDelegate,
        parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    if (position.outOfRange) {
      return parent?.createBallisticSimulation(position, velocity);
    }
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return parent?.createBallisticSimulation(position, velocity);
    }
    final itemsPerPage =
        paginationDelegate.getMainAxisCount(position.viewportDimension);
    final itemExtent =
        position.viewportDimension / (itemsPerPage + 2 * gutterExtent);
    final pageExtent = itemsPerPage * itemExtent;
    if (pageExtent <= 0) {
      return parent?.createBallisticSimulation(position, velocity);
    }
    final tolerance = toleranceFor(position);
    var page = position.pixels / pageExtent;
    if (velocity < -tolerance.velocity) {
      page -= 0.5;
    } else if (velocity > tolerance.velocity) {
      page += 0.5;
    }
    final target = (page.roundToDouble() * pageExtent)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if (target == position.pixels) return null;
    return ScrollSpringSimulation(spring, position.pixels, target, velocity,
        tolerance: tolerance);
  }
}

/// Controls a [PaginatedReorderableList] in logical pages.
class PaginatedReorderableListController extends ScrollController {
  final int initialPage;
  double? _pageExtent;
  int? _itemsPerPage;
  int _leadingEmptySlots = 0;
  int? _pendingPage;

  PaginatedReorderableListController({this.initialPage = 0})
      : assert(initialPage >= 0),
        _pendingPage = initialPage;

  /// The fractional logical page at the current scroll offset.
  double? get page {
    if (!hasClients || _pageExtent == null || !position.hasContentDimensions) {
      return null;
    }
    final pixels = position.pixels
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    final page = pixels / _pageExtent!;
    final roundedPage = page.roundToDouble();
    return (page - roundedPage).abs() < 0.0000000001 ? roundedPage : page;
  }

  /// The logical page containing [index], once page geometry is available.
  int? pageForItem(int index) {
    final itemsPerPage = _itemsPerPage;
    if (itemsPerPage == null) {
      return null;
    }
    return (index + _leadingEmptySlots) ~/ itemsPerPage;
  }

  void _setPageGeometry(
      double pageExtent, int itemsPerPage, int leadingEmptySlots) {
    _pageExtent = pageExtent;
    _itemsPerPage = itemsPerPage;
    _leadingEmptySlots = leadingEmptySlots;
    if (_pendingPage case final pendingPage? when hasClients) {
      _pendingPage = null;
      jumpToPage(pendingPage);
    }
  }

  void jumpToPage(int page) {
    if (!hasClients || _pageExtent == null) {
      _pendingPage = page;
      return;
    }
    jumpTo(_pixelsForPage(page));
  }

  Future<void> animateToPage(int page,
      {required Duration duration, required Curve curve}) {
    if (!hasClients || _pageExtent == null) {
      _pendingPage = page;
      return Future<void>.value();
    }
    return animateTo(_pixelsForPage(page), duration: duration, curve: curve);
  }

  double _pixelsForPage(int page) => page * _pageExtent!;
}

/// A keyed item for [PaginatedReorderableList].
///
/// Put the drag start listener below this widget.
class PaginatedReorderableListItem extends SingleChildRenderObjectWidget {
  final int index;

  const PaginatedReorderableListItem(
      {required this.index, required super.child, required super.key});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPaginatedReorderableListItem(index);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderPaginatedReorderableListItem).update(index);
  }
}

class _RenderPaginatedReorderableListItem extends RenderProxyBox {
  _RenderPaginatedReorderableListItem(this._index);

  int _index;

  void update(int index) {
    _invalidatePreferredExtent();
    _index = index;
    markNeedsLayout();
  }

  void _invalidatePreferredExtent() {
    RenderObject? ancestor = parent;
    while (ancestor != null && ancestor is! _RenderSelectedFirstList) {
      ancestor = ancestor.parent;
    }
    if (ancestor case final _RenderSelectedFirstList list) {
      list.invalidatePreferredExtentForIndex(_index);
    }
  }

  @override
  void markNeedsLayout() {
    _invalidatePreferredExtent();
    super.markNeedsLayout();
  }
}

double? _unusedItemExtentBuilder(
        int index, SliverLayoutDimensions dimensions) =>
    null;

class _PaginatedSliverReorderableList extends SliverReorderableList {
  final PaginatedReorderableListDelegate paginationDelegate;
  final double gutterExtent;
  final bool previousAlignPagesToEnd;
  final bool alignPagesToEnd;
  final Animation<double> pageAlignmentAnimation;
  final int? selectedIndex;
  final double selectedItemExtentFactor;
  final Duration selectedItemAnimationDuration;
  final Curve selectedItemAnimationCurve;

  const _PaginatedSliverReorderableList(
      {required this.paginationDelegate,
      required this.gutterExtent,
      required this.previousAlignPagesToEnd,
      required this.alignPagesToEnd,
      required this.pageAlignmentAnimation,
      required this.selectedIndex,
      required this.selectedItemExtentFactor,
      required this.selectedItemAnimationDuration,
      required this.selectedItemAnimationCurve,
      required super.itemBuilder,
      required super.itemCount,
      required super.onReorder,
      super.onReorderStart,
      super.onReorderEnd,
      super.proxyDecorator,
      super.dragBoundaryProvider,
      super.autoScrollerVelocityScalar,
      super.key});

  @override
  SliverReorderableListState createState() =>
      _PaginatedSliverReorderableListState();
}

class _PaginatedSliverReorderableListState extends SliverReorderableListState {
  late final AnimationController _selectionController;
  late final CurvedAnimation _selectionAnimation;
  int? _previousSelectedIndex;

  @override
  void initState() {
    super.initState();
    final configuration = widget as _PaginatedSliverReorderableList;
    _previousSelectedIndex = configuration.selectedIndex;
    _selectionController = AnimationController(
        vsync: this,
        duration: configuration.selectedItemAnimationDuration,
        value: 1);
    _selectionAnimation = CurvedAnimation(
        parent: _selectionController,
        curve: configuration.selectedItemAnimationCurve);
  }

  @override
  void didUpdateWidget(covariant SliverReorderableList oldWidget) {
    final oldConfiguration = oldWidget as _PaginatedSliverReorderableList;
    super.didUpdateWidget(oldWidget);
    final configuration = widget as _PaginatedSliverReorderableList;
    _selectionController.duration = configuration.selectedItemAnimationDuration;
    _selectionAnimation.curve = configuration.selectedItemAnimationCurve;
    if (oldConfiguration.selectedIndex == null &&
        configuration.selectedIndex != null) {
      _previousSelectedIndex = configuration.selectedIndex;
      _selectionController.value = 1;
    } else if (oldConfiguration.selectedIndex != configuration.selectedIndex) {
      _previousSelectedIndex = oldConfiguration.selectedIndex;
      _selectionController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _selectionAnimation.dispose();
    _selectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sliver = super.build(context);
    if (sliver is! SliverList) {
      throw StateError('Paginated reorderable list expected a SliverList.');
    }
    final configuration = widget as _PaginatedSliverReorderableList;
    return _SliverSelectedFirstList(
        delegate: sliver.delegate,
        itemCount: configuration.itemCount,
        paginationDelegate: configuration.paginationDelegate,
        gutterExtent: configuration.gutterExtent,
        previousAlignPagesToEnd: configuration.previousAlignPagesToEnd,
        alignPagesToEnd: configuration.alignPagesToEnd,
        pageAlignmentAnimation: configuration.pageAlignmentAnimation,
        previousSelectedIndex: _previousSelectedIndex,
        selectedIndex: configuration.selectedIndex,
        selectedItemExtentFactor: configuration.selectedItemExtentFactor,
        selectionAnimation: _selectionAnimation);
  }
}

class _SliverSelectedFirstList extends SliverMultiBoxAdaptorWidget {
  final int itemCount;
  final PaginatedReorderableListDelegate paginationDelegate;
  final double gutterExtent;
  final bool previousAlignPagesToEnd;
  final bool alignPagesToEnd;
  final Animation<double> pageAlignmentAnimation;
  final int? previousSelectedIndex;
  final int? selectedIndex;
  final double selectedItemExtentFactor;
  final Animation<double> selectionAnimation;

  const _SliverSelectedFirstList(
      {required super.delegate,
      required this.itemCount,
      required this.paginationDelegate,
      required this.gutterExtent,
      required this.previousAlignPagesToEnd,
      required this.alignPagesToEnd,
      required this.pageAlignmentAnimation,
      required this.previousSelectedIndex,
      required this.selectedIndex,
      required this.selectedItemExtentFactor,
      required this.selectionAnimation});

  @override
  RenderSliverVariedExtentList createRenderObject(BuildContext context) {
    return _RenderSelectedFirstList(
        childManager: context as SliverMultiBoxAdaptorElement,
        itemCount: itemCount,
        paginationDelegate: paginationDelegate,
        gutterExtent: gutterExtent,
        previousAlignPagesToEnd: previousAlignPagesToEnd,
        alignPagesToEnd: alignPagesToEnd,
        pageAlignmentAnimation: pageAlignmentAnimation,
        previousSelectedIndex: previousSelectedIndex,
        selectedIndex: selectedIndex,
        selectedItemExtentFactor: selectedItemExtentFactor,
        selectionAnimation: selectionAnimation);
  }

  @override
  void updateRenderObject(
      BuildContext context, _RenderSelectedFirstList renderObject) {
    renderObject
      ..invalidatePreferredExtentsForDelegateUpdate()
      ..itemCount = itemCount
      ..paginationDelegate = paginationDelegate
      ..gutterExtent = gutterExtent
      ..previousAlignPagesToEnd = previousAlignPagesToEnd
      ..alignPagesToEnd = alignPagesToEnd
      ..pageAlignmentAnimation = pageAlignmentAnimation
      ..previousSelectedIndex = previousSelectedIndex
      ..selectedIndex = selectedIndex
      ..selectedItemExtentFactor = selectedItemExtentFactor
      ..selectionAnimation = selectionAnimation;
  }
}

class _RenderSelectedFirstList extends RenderSliverVariedExtentList {
  _RenderSelectedFirstList(
      {required super.childManager,
      required int itemCount,
      required PaginatedReorderableListDelegate paginationDelegate,
      required double gutterExtent,
      required bool previousAlignPagesToEnd,
      required bool alignPagesToEnd,
      required Animation<double> pageAlignmentAnimation,
      required int? previousSelectedIndex,
      required int? selectedIndex,
      required double selectedItemExtentFactor,
      required Animation<double> selectionAnimation})
      : _itemCount = itemCount,
        _paginationDelegate = paginationDelegate,
        _gutterExtent = gutterExtent,
        _previousAlignPagesToEnd = previousAlignPagesToEnd,
        _alignPagesToEnd = alignPagesToEnd,
        _pageAlignmentAnimation = pageAlignmentAnimation,
        _previousSelectedIndex = previousSelectedIndex,
        _selectedIndex = selectedIndex,
        _selectedItemExtentFactor = selectedItemExtentFactor,
        _selectionAnimation = selectionAnimation,
        super(itemExtentBuilder: _unusedItemExtentBuilder);

  int _itemCount;
  PaginatedReorderableListDelegate _paginationDelegate;
  double _gutterExtent;
  bool _previousAlignPagesToEnd;
  bool _alignPagesToEnd;
  Animation<double> _pageAlignmentAnimation;
  int _itemsPerPage = 1;
  int? _previousSelectedIndex;
  int? _selectedIndex;
  double _selectedItemExtentFactor;
  Animation<double> _selectionAnimation;
  double? _previousPreferredSelectedExtent;
  double? _preferredSelectedExtent;
  bool _previousPreferredExtentNeedsMeasurement = true;
  bool _preferredExtentNeedsMeasurement = true;
  bool _delegateNeedsSelectedChildUpdate = false;
  double? _lastViewportMainAxisExtent;
  double? _lastCrossAxisExtent;

  int get itemsPerPage => _itemsPerPage;
  double get pageExtent => _pageExtent;
  int get leadingEmptySlots => _leadingEmptySlots;

  int _leadingEmptySlotsFor(bool alignPagesToEnd) {
    if (!alignPagesToEnd || _itemCount <= _itemsPerPage) return 0;
    return (_itemsPerPage - _itemCount % _itemsPerPage) % _itemsPerPage;
  }

  int get _leadingEmptySlots =>
      _leadingEmptySlotsFor(_alignPagesToEnd);

  set gutterExtent(double value) {
    if (_gutterExtent == value) return;
    _gutterExtent = value;
    _invalidatePreferredExtents();
    markNeedsLayout();
  }

  set alignPagesToEnd(bool value) {
    if (_alignPagesToEnd == value) return;
    _alignPagesToEnd = value;
    _invalidatePreferredExtents();
    markNeedsLayout();
  }

  set previousAlignPagesToEnd(bool value) {
    if (_previousAlignPagesToEnd == value) return;
    _previousAlignPagesToEnd = value;
    _invalidatePreferredExtents();
    markNeedsLayout();
  }

  set pageAlignmentAnimation(Animation<double> value) {
    if (identical(_pageAlignmentAnimation, value)) return;
    if (attached) _pageAlignmentAnimation.removeListener(markNeedsLayout);
    _pageAlignmentAnimation = value;
    if (attached) _pageAlignmentAnimation.addListener(markNeedsLayout);
    markNeedsLayout();
  }

  set itemCount(int value) {
    if (_itemCount == value) return;
    _itemCount = value;
    _invalidatePreferredExtents();
    markNeedsLayout();
  }

  set paginationDelegate(PaginatedReorderableListDelegate value) {
    final needsLayout = value.runtimeType != _paginationDelegate.runtimeType ||
        value.shouldRelayout(_paginationDelegate);
    if (!needsLayout) {
      _paginationDelegate = value;
      return;
    }
    _paginationDelegate = value;
    _invalidatePreferredExtents();
    markNeedsLayout();
  }

  set selectedIndex(int? value) {
    if (_selectedIndex == value) return;
    _selectedIndex = value;
    _preferredExtentNeedsMeasurement = true;
    markNeedsLayout();
  }

  set previousSelectedIndex(int? value) {
    if (_previousSelectedIndex == value) return;
    _previousSelectedIndex = value;
    _previousPreferredExtentNeedsMeasurement = true;
    markNeedsLayout();
  }

  set selectedItemExtentFactor(double value) {
    if (_selectedItemExtentFactor == value) return;
    _selectedItemExtentFactor = value;
    _invalidatePreferredExtents();
    markNeedsLayout();
  }

  set selectionAnimation(Animation<double> value) {
    if (identical(_selectionAnimation, value)) return;
    if (attached) _selectionAnimation.removeListener(markNeedsLayout);
    _selectionAnimation = value;
    if (attached) _selectionAnimation.addListener(markNeedsLayout);
    markNeedsLayout();
  }

  void _invalidatePreferredExtents() {
    _previousPreferredExtentNeedsMeasurement = true;
    _preferredExtentNeedsMeasurement = true;
  }

  void invalidatePreferredExtentsForDelegateUpdate() {
    _invalidatePreferredExtents();
    _delegateNeedsSelectedChildUpdate = true;
    markNeedsLayout();
  }

  void invalidatePreferredExtentForIndex(int index) {
    if (index == _previousSelectedIndex) {
      _previousPreferredExtentNeedsMeasurement = true;
    }
    if (index == _selectedIndex) {
      _preferredExtentNeedsMeasurement = true;
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _selectionAnimation.addListener(markNeedsLayout);
    _pageAlignmentAnimation.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _selectionAnimation.removeListener(markNeedsLayout);
    _pageAlignmentAnimation.removeListener(markNeedsLayout);
    super.detach();
  }

  int get _pageCount =>
      _itemCount == 0 ? 0 : (_itemCount / _itemsPerPage).ceil();

  int _pageForIndex(int index, bool alignPagesToEnd) =>
      (index + _leadingEmptySlotsFor(alignPagesToEnd)) ~/ _itemsPerPage;

  double get _interiorEqualExtent =>
      constraints.viewportMainAxisExtent / (_itemsPerPage + 2 * _gutterExtent);

  double get physicalGutterExtent => _gutterExtent * _interiorEqualExtent;

  double get _pageExtent => _itemsPerPage * _interiorEqualExtent;

  double _pageContentExtent(int page, bool alignPagesToEnd) {
    if (_pageCount == 1) return constraints.viewportMainAxisExtent;
    if (alignPagesToEnd) {
      return page == _pageCount - 1
          ? _pageExtent + physicalGutterExtent
          : _pageExtent;
    }
    return page == 0 ? _pageExtent + physicalGutterExtent : _pageExtent;
  }

  double _equalExtentForPage(int page, bool alignPagesToEnd) =>
      _pageContentExtent(page, alignPagesToEnd) / _itemsPerPage;

  double _maximumSelectedExtentForPage(int page, bool alignPagesToEnd) {
    final pageContentExtent = _pageContentExtent(page, alignPagesToEnd);
    if (_itemsPerPage == 1) return pageContentExtent;
    return pageContentExtent *
        _selectedItemExtentFactor /
        (_itemsPerPage - 1 + _selectedItemExtentFactor);
  }

  bool _isValidIndex(int? index) =>
      index != null && index >= 0 && index < _itemCount;

  double _selectedExtent(
      int page, double? preferredExtent, bool alignPagesToEnd) {
    final equalExtent = _equalExtentForPage(page, alignPagesToEnd);
    return (preferredExtent ?? equalExtent)
        .clamp(equalExtent,
            _maximumSelectedExtentForPage(page, alignPagesToEnd));
  }

  double _normalExtentForPage(
      int page,
      int? selectedIndex,
      double? preferredExtent,
      bool alignPagesToEnd) {
    if (_isValidIndex(selectedIndex) &&
        _pageForIndex(selectedIndex!, alignPagesToEnd) == page) {
      final pageContentExtent =
          _pageContentExtent(page, alignPagesToEnd);
      if (_itemsPerPage == 1) return pageContentExtent;
      return (pageContentExtent -
              _selectedExtent(page, preferredExtent, alignPagesToEnd)) /
          (_itemsPerPage - 1);
    }
    return _equalExtentForPage(page, alignPagesToEnd);
  }

  double _extentForSelection(
      int index,
      int? selectedIndex,
      double? preferredExtent,
      bool alignPagesToEnd) {
    final page = _pageForIndex(index, alignPagesToEnd);
    if (_isValidIndex(selectedIndex) && index == selectedIndex) {
      return _selectedExtent(page, preferredExtent, alignPagesToEnd);
    }
    return _normalExtentForPage(
        page, selectedIndex, preferredExtent, alignPagesToEnd);
  }

  double _selectionAnimatedExtentForIndex(
      int index, bool alignPagesToEnd) {
    final begin = _extentForSelection(
        index,
        _previousSelectedIndex,
        _previousPreferredSelectedExtent,
        alignPagesToEnd);
    final end = _extentForSelection(index, _selectedIndex,
        _preferredSelectedExtent, alignPagesToEnd);
    final t = _selectionAnimation.value;
    return begin + (end - begin) * t;
  }

  double _animatedExtentForIndex(int index) {
    final begin = _selectionAnimatedExtentForIndex(
        index, _previousAlignPagesToEnd);
    final end =
        _selectionAnimatedExtentForIndex(index, _alignPagesToEnd);
    final t = _pageAlignmentAnimation.value;
    return begin + (end - begin) * t;
  }

  double _selectionAnimatedNormalExtentForPage(
      int page, bool alignPagesToEnd) {
    final begin = _normalExtentForPage(
        page,
        _previousSelectedIndex,
        _previousPreferredSelectedExtent,
        alignPagesToEnd);
    final end = _normalExtentForPage(page, _selectedIndex,
        _preferredSelectedExtent, alignPagesToEnd);
    final t = _selectionAnimation.value;
    return begin + (end - begin) * t;
  }

  double _maximumSelectedExtentForIndex(int index) {
    final previousPage =
        _pageForIndex(index, _previousAlignPagesToEnd);
    final page = _pageForIndex(index, _alignPagesToEnd);
    return math.max(
        _maximumSelectedExtentForPage(
            previousPage, _previousAlignPagesToEnd),
        _maximumSelectedExtentForPage(page, _alignPagesToEnd));
  }

  double? _extentForIndex(int index, SliverLayoutDimensions dimensions) {
    if (index >= _itemCount) return null;
    return _animatedExtentForIndex(index);
  }

  @override
  ItemExtentBuilder get itemExtentBuilder => _extentForIndex;

  RenderBox? _childAtIndex(int index) {
    RenderBox? child = firstChild;
    while (child != null) {
      final childIndex = indexOf(child);
      if (childIndex == index) return child;
      if (childIndex > index) return null;
      child = childAfter(child);
    }
    return null;
  }

  RenderBox _updateChildFromDelegate(RenderBox child, int index) {
    invokeLayoutCallback<SliverConstraints>((_) {
      childManager.createChild(index, after: childBefore(child));
    });
    return _childAtIndex(index)!;
  }

  double _leadingEmptyExtentFor(bool alignPagesToEnd) {
    if (!alignPagesToEnd) return 0;
    return physicalGutterExtent +
        _leadingEmptySlotsFor(true) *
            _selectionAnimatedNormalExtentForPage(0, true);
  }

  double get _leadingEmptyExtent {
    final begin = _leadingEmptyExtentFor(_previousAlignPagesToEnd);
    final end = _leadingEmptyExtentFor(_alignPagesToEnd);
    final t = _pageAlignmentAnimation.value;
    return begin + (end - begin) * t;
  }

  double _layoutOffsetForIndex(int index) {
    var offset = _leadingEmptyExtent;
    for (var i = 0; i < math.min(index, _itemCount); i++) {
      offset += _animatedExtentForIndex(i);
    }
    return offset;
  }

  @override
  double indexToLayoutOffset(double itemExtent, int index) =>
      _layoutOffsetForIndex(index);

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset, double itemExtent) {
    return super.getMinChildIndexForScrollOffset(
        math.max(0.0, scrollOffset - _leadingEmptyExtent), itemExtent);
  }

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset, double itemExtent) {
    return super.getMaxChildIndexForScrollOffset(
        math.max(0.0, scrollOffset - _leadingEmptyExtent), itemExtent);
  }

  @override
  void performLayout() {
    final resolvedItemsPerPage = _paginationDelegate
        .getMainAxisCount(constraints.viewportMainAxisExtent);
    if (resolvedItemsPerPage <= 0) {
      throw FlutterError(
          'A pagination delegate must return at least one item per page.');
    }
    if (_itemsPerPage != resolvedItemsPerPage ||
        _lastViewportMainAxisExtent != constraints.viewportMainAxisExtent ||
        _lastCrossAxisExtent != constraints.crossAxisExtent) {
      _invalidatePreferredExtents();
      _lastViewportMainAxisExtent = constraints.viewportMainAxisExtent;
      _lastCrossAxisExtent = constraints.crossAxisExtent;
    }
    _itemsPerPage = resolvedItemsPerPage;
    RenderBox? selectedChild;
    if (_isValidIndex(_selectedIndex)) {
      selectedChild = _childAtIndex(_selectedIndex!);
      if (selectedChild == null && firstChild == null) {
        if (addInitialChild(index: _selectedIndex!)) selectedChild = firstChild;
      } else if (selectedChild != null && _delegateNeedsSelectedChildUpdate) {
        selectedChild =
            _updateChildFromDelegate(selectedChild, _selectedIndex!);
      }
      if (selectedChild != null && _preferredExtentNeedsMeasurement) {
        selectedChild.layout(
            constraints.asBoxConstraints(
                minExtent: 0,
                maxExtent:
                    _maximumSelectedExtentForIndex(_selectedIndex!)),
            parentUsesSize: true);
        _preferredSelectedExtent = paintExtentOf(selectedChild);
        _preferredExtentNeedsMeasurement = false;
      }
    } else {
      _preferredSelectedExtent = null;
      _preferredExtentNeedsMeasurement = false;
    }

    RenderBox? previousSelectedChild;
    if (_isValidIndex(_previousSelectedIndex)) {
      previousSelectedChild = _previousSelectedIndex == _selectedIndex
          ? selectedChild
          : _childAtIndex(_previousSelectedIndex!);
      if (previousSelectedChild != null &&
          !identical(previousSelectedChild, selectedChild) &&
          _delegateNeedsSelectedChildUpdate) {
        previousSelectedChild = _updateChildFromDelegate(
            previousSelectedChild, _previousSelectedIndex!);
      }
      if (identical(previousSelectedChild, selectedChild)) {
        _previousPreferredSelectedExtent = _preferredSelectedExtent;
        _previousPreferredExtentNeedsMeasurement =
            _preferredExtentNeedsMeasurement;
      } else if (previousSelectedChild != null &&
          _previousPreferredExtentNeedsMeasurement) {
        previousSelectedChild.layout(
            constraints.asBoxConstraints(
                minExtent: 0,
                maxExtent:
                    _maximumSelectedExtentForIndex(_previousSelectedIndex!)),
            parentUsesSize: true);
        _previousPreferredSelectedExtent = paintExtentOf(previousSelectedChild);
        _previousPreferredExtentNeedsMeasurement = false;
      }
    } else {
      _previousPreferredSelectedExtent = null;
      _previousPreferredExtentNeedsMeasurement = false;
    }
    _delegateNeedsSelectedChildUpdate = false;

    if (selectedChild != null) {
      final parentData =
          selectedChild.parentData! as SliverMultiBoxAdaptorParentData;
      parentData.layoutOffset = _layoutOffsetForIndex(_selectedIndex!);
    }
    if (previousSelectedChild != null &&
        !identical(previousSelectedChild, selectedChild)) {
      final parentData =
          previousSelectedChild.parentData! as SliverMultiBoxAdaptorParentData;
      parentData.layoutOffset = _layoutOffsetForIndex(_previousSelectedIndex!);
    }

    super.performLayout();

    if (geometry?.scrollOffsetCorrection == null) {
      final pageAlignedExtent = switch (_pageCount) {
        0 => 0.0,
        1 => constraints.viewportMainAxisExtent,
        final pageCount => pageCount * _pageExtent + 2 * physicalGutterExtent
      };
      geometry = geometry!.copyWith(
          scrollExtent: pageAlignedExtent,
          maxPaintExtent: pageAlignedExtent,
          hasVisualOverflow:
              pageAlignedExtent > constraints.remainingPaintExtent ||
                  constraints.scrollOffset > 0);
    }
  }
}

/// Decides how many items [PaginatedReorderableList] displays on each page.
///
/// The [mainAxisExtent] passed to [getMainAxisCount] is the viewport extent in
/// [PaginatedReorderableList.scrollDirection]. The returned main-axis count is
/// the number of items visible per page.
abstract class PaginatedReorderableListDelegate {
  const PaginatedReorderableListDelegate();

  /// Returns the number of items to display per page.
  int getMainAxisCount(double mainAxisExtent);

  /// Whether a widget using [oldDelegate] needs to recompute its layout.
  bool shouldRelayout(covariant PaginatedReorderableListDelegate oldDelegate);
}

/// A pagination delegate with a fixed number of items on each page.
class PaginatedReorderableListDelegateWithFixedMainAxisCount
    extends PaginatedReorderableListDelegate {
  final int mainAxisCount;

  const PaginatedReorderableListDelegateWithFixedMainAxisCount(
      {required this.mainAxisCount})
      : assert(mainAxisCount > 0);

  @override
  int getMainAxisCount(double mainAxisExtent) => mainAxisCount;

  @override
  bool shouldRelayout(
      PaginatedReorderableListDelegateWithFixedMainAxisCount oldDelegate) {
    return mainAxisCount != oldDelegate.mainAxisCount;
  }
}

/// A pagination delegate whose items never exceed [maxMainAxisExtent].
///
/// For example, a horizontal list that is 500 logical pixels wide and has a
/// maximum extent of 200 displays three items per page. Each item is expanded
/// to exactly one third of the page so page boundaries always line up with the
/// viewport.
class PaginatedReorderableListDelegateWithMaxMainAxisExtent
    extends PaginatedReorderableListDelegate {
  final double maxMainAxisExtent;

  const PaginatedReorderableListDelegateWithMaxMainAxisExtent(
      {required this.maxMainAxisExtent})
      : assert(maxMainAxisExtent > 0);

  @override
  int getMainAxisCount(double mainAxisExtent) {
    return math.max(1, (mainAxisExtent / maxMainAxisExtent).ceil());
  }

  @override
  bool shouldRelayout(
      PaginatedReorderableListDelegateWithMaxMainAxisExtent oldDelegate) {
    return maxMainAxisExtent != oldDelegate.maxMainAxisExtent;
  }
}

/// A reorderable list that displays and scrolls one page of items at a time.
///
/// Unlike composing a [PageView] from several reorderable lists, this widget
/// uses one [ReorderableList]. Consequently reorder indices are global and a
/// drag can auto-scroll from one page to another.
///
/// Each item must have a unique key and include a
/// [ReorderableDragStartListener] or [ReorderableDelayedDragStartListener], in
/// the same way as an ordinary [ReorderableList]. Listener indices are also the
/// global indices supplied to [itemBuilder].
///
/// When more than one page exists, item counts fade in at the viewport edges
/// while the user scrolls. Each count reports how many items are beyond that
/// edge, and is omitted when the current page is already at that end. Use
/// [pageIndicatorBuilder] to replace the default count badges, or
/// [showPageIndicator] to hide the overlay.
///
/// The widget must have a bounded extent in [scrollDirection].
class PaginatedReorderableList extends StatefulWidget {
  final IndexedWidgetBuilder itemBuilder;
  final int itemCount;
  final ReorderCallback onReorder;
  final PaginatedReorderableListDelegate paginationDelegate;
  final Axis scrollDirection;
  final bool reverse;
  final PaginatedReorderableListController? controller;
  final int initialPage;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<int>? onReorderStart;
  final ValueChanged<int>? onReorderEnd;
  final ReorderItemProxyDecorator? proxyDecorator;

  /// The item that receives a larger share of its page, if any.
  final int? selectedIndex;

  /// The maximum selected-item extent relative to every other slot on its page.
  ///
  /// A [PaginatedReorderableListItem] grows only as much as its intrinsic
  /// extent requires, up to this ratio. Other items and empty slots shrink by
  /// the amount actually used, so the page remains exactly one viewport.
  /// Defaults to twice the extent of the other slots.
  final double selectedItemExtentFactor;

  /// Duration of the extent redistribution when [selectedIndex] changes.
  final Duration selectedItemAnimationDuration;

  /// Curve used to redistribute item extents when [selectedIndex] changes.
  final Curve selectedItemAnimationCurve;
  final ScrollPhysics? physics;
  final bool pageSnapping;
  final DragStartBehavior dragStartBehavior;
  final ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior;
  final String? restorationId;
  final Clip clipBehavior;
  final double? autoScrollerVelocityScalar;
  final ReorderDragBoundaryProvider? dragBoundaryProvider;

  /// Whether to show the fading page indicator when there is more than one page.
  final bool showPageIndicator;

  /// Builds a custom count badge for each edge that has hidden items.
  final PaginatedReorderableListIndicatorBuilder? pageIndicatorBuilder;

  /// Insets both edge badges from the viewport.
  final EdgeInsetsGeometry pageIndicatorPadding;
  final Duration pageIndicatorFadeDuration;

  /// How long the indicator remains fully visible after scrolling ends.
  final Duration pageIndicatorVisibleDuration;

  /// Adjacent-page peek measured in normal item extents per interior edge.
  ///
  /// For example, `0.5` reveals half a normal item on both edges of an
  /// interior page. Page zero starts flush with item zero and retains only the
  /// configured trailing peek. When pages are aligned to the end, this is
  /// mirrored: the first page gains a leading peek and the final page ends
  /// flush. Logical page chunks remain disjoint.
  final double gutterExtent;

  /// Whether pulling beyond the trailing edge can toggle page alignment.
  ///
  /// Pull past [alignmentOverpullExtent], then release to switch between
  /// normal and end-aligned pages. When end-aligned, the leading edge can also
  /// be pulled to restore normal alignment.
  final bool allowTrailingAlignmentOverpull;

  /// Whether pages start end-aligned when this state is first created.
  ///
  /// Changing this value after initialization does not change the current
  /// alignment.
  final bool initialPagesAlignedToEnd;

  /// Called after a completed pull changes the page alignment.
  final ValueChanged<bool>? onPagesAlignedToEndChanged;

  /// Overscroll distance required to change the page alignment.
  final double alignmentOverpullExtent;

  const PaginatedReorderableList(
      {required this.itemBuilder,
      required this.itemCount,
      required this.onReorder,
      required this.paginationDelegate,
      this.scrollDirection = Axis.horizontal,
      this.reverse = false,
      this.controller,
      this.initialPage = 0,
      this.onPageChanged,
      this.onReorderStart,
      this.onReorderEnd,
      this.proxyDecorator,
      this.selectedIndex,
      this.selectedItemExtentFactor = 2,
      this.selectedItemAnimationDuration = const Duration(milliseconds: 350),
      this.selectedItemAnimationCurve = Curves.ease,
      this.physics,
      this.pageSnapping = true,
      this.dragStartBehavior = DragStartBehavior.start,
      this.keyboardDismissBehavior,
      this.restorationId,
      this.clipBehavior = Clip.hardEdge,
      this.autoScrollerVelocityScalar,
      this.dragBoundaryProvider,
      this.showPageIndicator = true,
      this.pageIndicatorBuilder,
      this.pageIndicatorPadding = const EdgeInsets.all(12),
      this.pageIndicatorFadeDuration = const Duration(milliseconds: 200),
      this.pageIndicatorVisibleDuration = const Duration(milliseconds: 500),
      this.gutterExtent = 0,
      this.allowTrailingAlignmentOverpull = false,
      this.initialPagesAlignedToEnd = false,
      this.onPagesAlignedToEndChanged,
      this.alignmentOverpullExtent = 48,
      super.key})
      : assert(itemCount >= 0),
        assert(initialPage >= 0),
        assert(selectedIndex == null || selectedIndex >= 0),
        assert(selectedItemExtentFactor >= 1),
        assert(gutterExtent >= 0 && gutterExtent < double.infinity),
        assert(alignmentOverpullExtent >= 0 &&
            alignmentOverpullExtent < double.infinity);

  @override
  PaginatedReorderableListState createState() =>
      PaginatedReorderableListState();
}

class PaginatedReorderableListState extends State<PaginatedReorderableList>
    with SingleTickerProviderStateMixin {
  final GlobalKey<SliverReorderableListState> _listKey = GlobalKey();
  late PaginatedReorderableListController _controller;
  late int _currentPage;
  int _itemsPerPage = 1;
  int _laidOutLeadingEmptySlots = 0;
  double _pageExtent = 1;
  bool _hasLayout = false;
  int? _lastLaidOutItemCount;
  int _pageCorrectionGeneration = 0;
  Timer? _pageIndicatorHideTimer;
  bool _pageIndicatorVisible = false;
  bool _reordering = false;
  int? _reorderStartIndex;
  int? _dropTargetPage;
  double? _dropStartScrollOffset;
  bool _alignPagesToEnd = false;
  bool _previousAlignPagesToEnd = false;
  late final AnimationController _pageAlignmentController;
  late final CurvedAnimation _pageAlignmentAnimation;
  _AlignmentPullEdge? _alignmentPullEdge;
  double _alignmentPullExtent = 0;
  bool _alignmentPullArmed = false;

  PaginatedReorderableListController get controller => _controller;
  int get page => _currentPage;
  _RenderSelectedFirstList? get _renderList {
    final renderObject = _listKey.currentContext?.findRenderObject();
    return renderObject is _RenderSelectedFirstList ? renderObject : null;
  }

  int get itemsPerPage => _renderList?.itemsPerPage ?? _itemsPerPage;
  bool get pagesAlignedToEnd => _alignPagesToEnd;
  int get leadingEmptySlots {
    if (!_alignPagesToEnd || widget.itemCount <= itemsPerPage) return 0;
    return (itemsPerPage - widget.itemCount % itemsPerPage) % itemsPerPage;
  }
  int get pageCount =>
      widget.itemCount == 0
          ? 0
          : ((widget.itemCount + leadingEmptySlots) / itemsPerPage).ceil();

  int pageForItem(int index) =>
      (index + leadingEmptySlots) ~/ itemsPerPage;

  @override
  void initState() {
    super.initState();
    _validatePageIndicatorConfiguration();
    _controller = widget.controller ??
        PaginatedReorderableListController(initialPage: widget.initialPage);
    _alignPagesToEnd = widget.initialPagesAlignedToEnd;
    _previousAlignPagesToEnd = _alignPagesToEnd;
    _pageAlignmentController = AnimationController(
        vsync: this,
        duration: widget.selectedItemAnimationDuration,
        value: 1);
    _pageAlignmentAnimation = CurvedAnimation(
        parent: _pageAlignmentController,
        curve: widget.selectedItemAnimationCurve);
    _currentPage = widget.controller?.initialPage ?? widget.initialPage;
    _schedulePaginationSync();
  }

  @override
  void didUpdateWidget(PaginatedReorderableList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _validatePageIndicatorConfiguration();
    _pageAlignmentController.duration = widget.selectedItemAnimationDuration;
    _pageAlignmentAnimation.curve = widget.selectedItemAnimationCurve;
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller == null) {
        _controller.dispose();
      }
      _controller = widget.controller ??
          PaginatedReorderableListController(initialPage: _currentPage);
      if (widget.controller != null) {
        _currentPage = widget.controller!.initialPage;
      }
      _lastLaidOutItemCount = null;
    }
    if (!widget.allowTrailingAlignmentOverpull) {
      _alignmentPullEdge = null;
      _alignmentPullExtent = 0;
      _alignmentPullArmed = false;
    }
    _schedulePaginationSync();
  }

  @override
  void dispose() {
    _pageCorrectionGeneration++;
    _pageIndicatorHideTimer?.cancel();
    _pageAlignmentAnimation.dispose();
    _pageAlignmentController.dispose();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void jumpToPage(int page) {
    final target = _clampPage(page);
    if (_controller.hasClients) {
      _controller.jumpToPage(target);
    }
    _notifyPageChanged(target);
  }

  Future<void> animateToPage(int page,
      {required Duration duration, required Curve curve}) async {
    final target = _clampPage(page);
    if (_controller.hasClients) {
      await _controller.animateToPage(target, duration: duration, curve: curve);
    }
    if (!mounted) {
      return;
    }
    _notifyPageChanged(target);
  }

  void cancelReorder() {
    _listKey.currentState?.cancelReorder();
  }

  void _validatePageIndicatorConfiguration() {
    if (widget.pageIndicatorFadeDuration.isNegative ||
        widget.pageIndicatorVisibleDuration.isNegative ||
        widget.selectedItemAnimationDuration.isNegative) {
      throw FlutterError(
          'PaginatedReorderableList durations must not be negative.');
    }
    if (widget.gutterExtent.isNegative || !widget.gutterExtent.isFinite) {
      throw FlutterError(
          'PaginatedReorderableList.gutterExtent must be a finite, '
          'non-negative number.');
    }
    if (widget.alignmentOverpullExtent.isNegative ||
        !widget.alignmentOverpullExtent.isFinite) {
      throw FlutterError(
          'PaginatedReorderableList.alignmentOverpullExtent must be a finite, '
          'non-negative number.');
    }
  }

  int _clampPage(int page) {
    return page.clamp(0, math.max(0, pageCount - 1));
  }

  void _notifyPageChanged(int page) {
    if (_currentPage == page) {
      return;
    }
    setState(() {
      _currentPage = page;
    });
    widget.onPageChanged?.call(page);
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) {
      return false;
    }
    _handleAlignmentOverpull(notification);
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _showPageIndicator();
    } else if (notification is UserScrollNotification &&
        notification.direction != ScrollDirection.idle) {
      _showPageIndicator();
    } else if (notification is ScrollEndNotification) {
      _schedulePageIndicatorFadeOut();
    }
    if (notification.metrics.viewportDimension <= 0) {
      return false;
    }
    final newPage =
        _clampPage((_controller.page ?? _currentPage.toDouble()).round());
    _notifyPageChanged(newPage);
    return false;
  }

  void _handleAlignmentOverpull(ScrollNotification notification) {
    if (!widget.allowTrailingAlignmentOverpull) return;
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _clearAlignmentPull();
      return;
    }
    if (notification is ScrollUpdateNotification &&
        notification.dragDetails == null) {
      _finishAlignmentPull();
      return;
    }
    if (notification is ScrollEndNotification) {
      _finishAlignmentPull();
      return;
    }
    _AlignmentPullEdge? edge;
    double extent = 0;
    if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      final metrics = notification.metrics;
      final leadingExtent =
          math.max(0.0, metrics.minScrollExtent - metrics.pixels);
      final trailingExtent =
          math.max(0.0, metrics.pixels - metrics.maxScrollExtent);
      if (trailingExtent > 0) {
        edge = _AlignmentPullEdge.trailing;
        extent = trailingExtent;
      } else if (leadingExtent > 0) {
        edge = _AlignmentPullEdge.leading;
        extent = leadingExtent;
      }
    } else if (notification is OverscrollNotification &&
        notification.dragDetails != null) {
      if (notification.overscroll < 0) {
        edge = _AlignmentPullEdge.leading;
      } else {
        edge = _AlignmentPullEdge.trailing;
      }
      extent = (_alignmentPullEdge == edge ? _alignmentPullExtent : 0) +
          notification.overscroll.abs();
    } else {
      return;
    }

    final canChangeAlignment = pageCount > 1;
    final edgeCanToggle = canChangeAlignment &&
        (edge == _AlignmentPullEdge.trailing ||
            (_alignPagesToEnd && edge == _AlignmentPullEdge.leading));
    if (!edgeCanToggle) {
      _clearAlignmentPull();
      return;
    }
    _updateAlignmentPull(edge!, extent);
  }

  void _updateAlignmentPull(_AlignmentPullEdge edge, double extent) {
    final armed = _alignmentPullArmed ||
        extent >= widget.alignmentOverpullExtent;
    if (_alignmentPullEdge == edge &&
        _alignmentPullExtent == extent &&
        _alignmentPullArmed == armed) {
      return;
    }
    setState(() {
      _alignmentPullEdge = edge;
      _alignmentPullExtent = extent;
      _alignmentPullArmed = armed;
    });
  }

  void _clearAlignmentPull() {
    if (_alignmentPullEdge == null &&
        _alignmentPullExtent == 0 &&
        !_alignmentPullArmed) {
      return;
    }
    setState(() {
      _alignmentPullEdge = null;
      _alignmentPullExtent = 0;
      _alignmentPullArmed = false;
    });
  }

  void _finishAlignmentPull() {
    if (_alignmentPullEdge == null) return;
    final toggleAlignment = _alignmentPullArmed;
    bool? changedAlignment;
    setState(() {
      _alignmentPullEdge = null;
      _alignmentPullExtent = 0;
      _alignmentPullArmed = false;
      if (toggleAlignment) {
        _previousAlignPagesToEnd = _alignPagesToEnd;
        _alignPagesToEnd = !_alignPagesToEnd;
        changedAlignment = _alignPagesToEnd;
        _pageAlignmentController.forward(from: 0);
      }
    });
    if (changedAlignment case final value?) {
      widget.onPagesAlignedToEndChanged?.call(value);
    }
  }

  void _showPageIndicator() {
    if (!widget.showPageIndicator || pageCount <= 1) {
      return;
    }
    _pageIndicatorHideTimer?.cancel();
    if (!_pageIndicatorVisible) {
      setState(() {
        _pageIndicatorVisible = true;
      });
    }
  }

  void _schedulePageIndicatorFadeOut() {
    if (!_pageIndicatorVisible) {
      return;
    }
    _pageIndicatorHideTimer?.cancel();
    _pageIndicatorHideTimer = Timer(widget.pageIndicatorVisibleDuration, () {
      if (mounted) {
        setState(() {
          _pageIndicatorVisible = false;
        });
      }
    });
  }

  void _schedulePaginationSync() {
    final generation = ++_pageCorrectionGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _pageCorrectionGeneration) return;
      _syncPaginationFromRender();
    });
  }

  void _syncPaginationFromRender() {
    final renderList = _renderList;
    if (renderList == null) return;
    final newItemsPerPage = renderList.itemsPerPage;
    final newPageExtent = renderList.pageExtent;
    final newLeadingEmptySlots = renderList.leadingEmptySlots;
    assert(newItemsPerPage > 0);
    assert(newPageExtent > 0);
    final itemCountChanged = _lastLaidOutItemCount != widget.itemCount;
    _lastLaidOutItemCount = widget.itemCount;
    final pageGeometryChanged = newItemsPerPage != _itemsPerPage ||
        (newPageExtent - _pageExtent).abs() > 0.000001;
    final pageAlignmentChanged =
        newLeadingEmptySlots != _laidOutLeadingEmptySlots;
    final firstVisibleItem = math.max(
        0, _currentPage * _itemsPerPage - _laidOutLeadingEmptySlots);
    _controller._setPageGeometry(
        newPageExtent, newItemsPerPage, newLeadingEmptySlots);
    var targetPage = _clampPage(_currentPage);
    if (!_hasLayout) {
      _hasLayout = true;
      _itemsPerPage = newItemsPerPage;
      _pageExtent = newPageExtent;
      _laidOutLeadingEmptySlots = newLeadingEmptySlots;
      targetPage = _clampPage(_currentPage);
    } else if (pageGeometryChanged) {
      _itemsPerPage = newItemsPerPage;
      _pageExtent = newPageExtent;
      _laidOutLeadingEmptySlots = newLeadingEmptySlots;
      targetPage =
          _clampPage((firstVisibleItem + newLeadingEmptySlots) ~/ _itemsPerPage);
    } else if (pageAlignmentChanged) {
      _laidOutLeadingEmptySlots = newLeadingEmptySlots;
    } else if (!itemCountChanged) {
      return;
    }

    if (_controller.hasClients) {
      final actualPage = _controller.page ?? 0;
      if ((actualPage - targetPage).abs() > 0.0001) {
        _controller.jumpToPage(targetPage);
      }
    }
    if (_currentPage == targetPage) {
      setState(() {});
    } else {
      _notifyPageChanged(targetPage);
    }
  }

  bool _handleScrollMetricsNotification(
      ScrollMetricsNotification notification) {
    if (notification.depth == 0) _schedulePaginationSync();
    return false;
  }

  void _handleReorderEnd(int index) {
    final startIndex = _reorderStartIndex ?? index;
    final destinationIndex = index > startIndex ? index - 1 : index;
    if (widget.itemCount == 0) {
      _dropTargetPage = 0;
    } else {
      final lastIndex = widget.itemCount - 1;
      final insertionPage =
          _clampPage(pageForItem(index.clamp(0, lastIndex)));
      final destinationPage = _clampPage(
          pageForItem(destinationIndex.clamp(0, lastIndex)));
      if (insertionPage == destinationPage) {
        _dropTargetPage = destinationPage;
      } else {
        final viewportPage = _controller.page ?? _currentPage.toDouble();
        _dropTargetPage =
            (viewportPage - insertionPage).abs() <=
                    (viewportPage - destinationPage).abs()
                ? insertionPage
                : destinationPage;
      }
    }
    _dropStartScrollOffset =
        _controller.hasClients ? _controller.offset : null;
    if (_reordering) {
      setState(() {
        _reordering = false;
      });
    }
    widget.onReorderEnd?.call(index);
    _snapToDropPage();
  }

  void _handleProxyDropCompleted() {
    if (!mounted) {
      return;
    }
    final restoreSnapping = _reordering;
    setState(() {
      _reordering = false;
      _reorderStartIndex = null;
      _dropTargetPage = null;
      _dropStartScrollOffset = null;
    });
    if (restoreSnapping) {
      _snapToDropPage();
    }
  }

  void _snapToDropPage() {
    if (!widget.pageSnapping) {
      return;
    }
    final targetPage =
        _clampPage(_dropTargetPage ?? _controller.page?.round() ?? _currentPage);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) {
        return;
      }
      _controller.animateToPage(targetPage,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  void _handleReorderStart(int index) {
    if (!_reordering) {
      setState(() {
        _reordering = true;
        _reorderStartIndex = index;
        _dropTargetPage = null;
        _dropStartScrollOffset = null;
      });
    }
    widget.onReorderStart?.call(index);
  }

  Offset _proxyScrollTranslation(Animation<double> animation) {
    final startOffset = _dropStartScrollOffset;
    if (startOffset == null || !_controller.hasClients) {
      return Offset.zero;
    }
    final dropProgress = 1 - Curves.easeOut.transform(animation.value);
    final scrollDelta = (_controller.offset - startOffset) * dropProgress;
    final direction = getAxisDirectionFromAxisReverseAndDirectionality(
        context, widget.scrollDirection, widget.reverse);
    final translation = axisDirectionIsReversed(direction)
        ? scrollDelta
        : -scrollDelta;
    return widget.scrollDirection == Axis.horizontal
        ? Offset(translation, 0)
        : Offset(0, translation);
  }

  Widget _buildReorderProxy(
      Widget child, int index, Animation<double> animation) {
    final proxy = widget.proxyDecorator?.call(child, index, animation) ?? child;
    return _ReorderProxyDropListener(
        animation: animation,
        scrollPosition: _controller,
        scrollTranslation: () => _proxyScrollTranslation(animation),
        onDropCompleted: _handleProxyDropCompleted,
        child: proxy);
  }

  Widget _buildDefaultPageIndicator(
      BuildContext context, int hiddenItemCount, AxisDirection edge) {
    final edgeName = switch (edge) {
      AxisDirection.up => 'above',
      AxisDirection.right => 'to the right',
      AxisDirection.down => 'below',
      AxisDirection.left => 'to the left'
    };
    final arrow = switch (edge) {
      AxisDirection.up => '↑',
      AxisDirection.right => '→',
      AxisDirection.down => '↓',
      AxisDirection.left => '←'
    };
    final direction = switch (edge) {
      AxisDirection.up || AxisDirection.down => Axis.vertical,
      AxisDirection.right || AxisDirection.left => Axis.horizontal
    };
    final arrowFirst = edge == AxisDirection.up || edge == AxisDirection.left;
    const textStyle = TextStyle(
        color: Color(0xFFFFFFFF), fontSize: 13, fontWeight: FontWeight.w600);
    final spacing = direction == Axis.horizontal
        ? const SizedBox(width: 4)
        : const SizedBox(height: 2);
    return Semantics(
        liveRegion: true,
        excludeSemantics: true,
        label: '$hiddenItemCount items $edgeName',
        child: _buildIndicatorPill(
            key: ValueKey('PaginatedReorderableList.${edge.name}Indicator'),
            child: Flex(
                direction: direction,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (arrowFirst) Text(arrow, style: textStyle),
                  if (arrowFirst) spacing,
                  Text('$hiddenItemCount',
                      textAlign: TextAlign.center, style: textStyle),
                  if (!arrowFirst) spacing,
                  if (!arrowFirst) Text(arrow, style: textStyle)
                ])));
  }

  Widget _buildIndicatorPill({required Key key, required Widget child}) {
    return Container(
        key: key,
        constraints: const BoxConstraints(minWidth: 28),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
            color: const Color(0x99000000),
            borderRadius: BorderRadius.circular(999)),
        child: child);
  }

  Alignment _alignmentForEdge(AxisDirection edge) {
    return switch (edge) {
      AxisDirection.up => Alignment.topCenter,
      AxisDirection.right => Alignment.centerRight,
      AxisDirection.down => Alignment.bottomCenter,
      AxisDirection.left => Alignment.centerLeft
    };
  }

  Widget _buildEdgeIndicator(
      BuildContext context, int count, AxisDirection edge) {
    final indicator = widget.pageIndicatorBuilder?.call(context, count, edge) ??
        _buildDefaultPageIndicator(context, count, edge);
    return Align(alignment: _alignmentForEdge(edge), child: indicator);
  }

  Widget _buildAlignmentPullSymbol(AxisDirection destination) {
    final direction = switch (destination) {
      AxisDirection.left || AxisDirection.right => Axis.horizontal,
      AxisDirection.up || AxisDirection.down => Axis.vertical
    };
    final arrow = switch (destination) {
      AxisDirection.left => '←',
      AxisDirection.right => '→',
      AxisDirection.up => '↑',
      AxisDirection.down => '↓'
    };
    final destinationFirst =
        destination == AxisDirection.left || destination == AxisDirection.up;
    final bar = Container(
        width: direction == Axis.horizontal ? 1.5 : 11,
        height: direction == Axis.horizontal ? 11 : 1.5,
        decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(1)));
    final spacing = direction == Axis.horizontal
        ? const SizedBox(width: 4)
        : const SizedBox(height: 2);
    const arrowStyle = TextStyle(
        color: Color(0xFFFFFFFF),
        fontSize: 13,
        fontWeight: FontWeight.w600);
    return Flex(
        direction: direction,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (destinationFirst) bar,
          if (destinationFirst) spacing,
          Text(arrow, style: arrowStyle),
          if (!destinationFirst) spacing,
          if (!destinationFirst) bar
        ]);
  }

  Widget _buildAlignmentPullIndicator(BuildContext context) {
    final forwardDirection = getAxisDirectionFromAxisReverseAndDirectionality(
        context, widget.scrollDirection, widget.reverse);
    final pulledEdge = _alignmentPullEdge == _AlignmentPullEdge.trailing
        ? forwardDirection
        : flipAxisDirection(forwardDirection);
    final destination = _alignPagesToEnd
        ? flipAxisDirection(forwardDirection)
        : forwardDirection;
    final progress = widget.alignmentOverpullExtent == 0
        ? 1.0
        : (_alignmentPullExtent / widget.alignmentOverpullExtent)
            .clamp(0.0, 1.0);
    final targetName = _alignPagesToEnd ? 'start' : 'end';
    final instruction = _alignmentPullArmed
        ? 'Release to align pages to the $targetName'
        : 'Pull to align pages to the $targetName';
    final translation = switch (pulledEdge) {
      AxisDirection.left => Offset(progress - 1, 0),
      AxisDirection.right => Offset(1 - progress, 0),
      AxisDirection.up => Offset(0, progress - 1),
      AxisDirection.down => Offset(0, 1 - progress)
    };
    final indicator = IgnorePointer(
        child: ClipRect(
            child: FractionalTranslation(
                translation: translation,
                child: Semantics(
                    liveRegion: _alignmentPullArmed,
                    label: instruction,
                    child: _buildIndicatorPill(
                        key: const ValueKey(
                            'PaginatedReorderableList.alignmentPullIndicator'),
                        child: _buildAlignmentPullSymbol(destination))))));
    return switch (pulledEdge) {
      AxisDirection.left => Positioned(
          left: 0, top: 0, bottom: 0, child: Center(child: indicator)),
      AxisDirection.right => Positioned(
          right: 0, top: 0, bottom: 0, child: Center(child: indicator)),
      AxisDirection.up => Positioned(
          left: 0, right: 0, top: 0, child: Center(child: indicator)),
      AxisDirection.down => Positioned(
          left: 0, right: 0, bottom: 0, child: Center(child: indicator))
    };
  }

  Widget _buildPageIndicators(BuildContext context) {
    final currentPage = _clampPage(_currentPage);
    final effectiveItemsPerPage = itemsPerPage;
    final hiddenBefore = math.max(
        0, currentPage * effectiveItemsPerPage - leadingEmptySlots);
    final hiddenAfter = math
        .max(
            0,
            widget.itemCount -
                math.min(
                    widget.itemCount,
                    (currentPage + 1) * effectiveItemsPerPage -
                        leadingEmptySlots))
        .toInt();
    final forwardDirection = getAxisDirectionFromAxisReverseAndDirectionality(
        context, widget.scrollDirection, widget.reverse);
    final beforeEdge = flipAxisDirection(forwardDirection);
    final afterEdge = forwardDirection;
    return Positioned.fill(
        child: IgnorePointer(
            child: AnimatedOpacity(
                key: const ValueKey('PaginatedReorderableList.pageIndicator'),
                opacity: _pageIndicatorVisible ? 1 : 0,
                duration: widget.pageIndicatorFadeDuration,
                child: Padding(
                    padding: widget.pageIndicatorPadding,
                    child: Stack(children: [
                      if (hiddenBefore > 0)
                        _buildEdgeIndicator(context, hiddenBefore, beforeEdge),
                      if (hiddenAfter > 0)
                        _buildEdgeIndicator(context, hiddenAfter, afterEdge)
                    ])))));
  }

  @override
  Widget build(BuildContext context) {
    final inheritedPhysics = widget.physics ??
        ScrollConfiguration.of(context).getScrollPhysics(context);
    final effectivePhysics = widget.pageSnapping && !_reordering
        ? _PaginatedPageScrollPhysics(
                gutterExtent: widget.gutterExtent,
                paginationDelegate: widget.paginationDelegate)
            .applyTo(inheritedPhysics)
        : inheritedPhysics;

    return Stack(children: [
      Positioned.fill(
          child: NotificationListener<ScrollMetricsNotification>(
              onNotification: _handleScrollMetricsNotification,
              child: NotificationListener<ScrollNotification>(
                  onNotification: _handleScrollNotification,
                  child: CustomScrollView(
                      scrollDirection: widget.scrollDirection,
                      reverse: widget.reverse,
                      controller: _controller,
                      physics: effectivePhysics,
                      dragStartBehavior: widget.dragStartBehavior,
                      keyboardDismissBehavior: widget.keyboardDismissBehavior,
                          restorationId: widget.restorationId,
                          clipBehavior: widget.clipBehavior,
                          slivers: [
                        _PaginatedSliverReorderableList(
                            key: _listKey,
                            paginationDelegate: widget.paginationDelegate,
                            gutterExtent: widget.gutterExtent,
                            previousAlignPagesToEnd:
                                _previousAlignPagesToEnd,
                            alignPagesToEnd: _alignPagesToEnd,
                            pageAlignmentAnimation: _pageAlignmentAnimation,
                            selectedIndex: widget.selectedIndex,
                            selectedItemExtentFactor:
                                widget.selectedItemExtentFactor,
                            selectedItemAnimationDuration:
                                widget.selectedItemAnimationDuration,
                            selectedItemAnimationCurve:
                                widget.selectedItemAnimationCurve,
                            itemBuilder: widget.itemBuilder,
                            itemCount: widget.itemCount,
                            onReorder: widget.onReorder,
                            onReorderStart: _handleReorderStart,
                            onReorderEnd: _handleReorderEnd,
                            proxyDecorator: _buildReorderProxy,
                            autoScrollerVelocityScalar:
                                widget.autoScrollerVelocityScalar,
                            dragBoundaryProvider: widget.dragBoundaryProvider)
                      ])))),
      if (widget.showPageIndicator && pageCount > 1)
        _buildPageIndicators(context),
      if (widget.allowTrailingAlignmentOverpull &&
          _alignmentPullEdge != null)
        _buildAlignmentPullIndicator(context)
    ]);
  }
}

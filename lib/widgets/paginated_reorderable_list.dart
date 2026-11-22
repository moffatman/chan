import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show precisionErrorTolerance;
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

/// The logical pages and their offsets for a resolved list viewport.
class _PaginationGeometry {
  const _PaginationGeometry({
    required this.viewportExtent,
    required this.itemsPerPage,
    required this.itemCount,
    required this.leadingGutter,
    required this.trailingGutter,
    required this.alignToEnd,
  });

  final double viewportExtent;
  final int itemsPerPage;
  final int itemCount;
  final double leadingGutter;
  final double trailingGutter;
  final bool alignToEnd;

  double get slotExtent =>
      viewportExtent / (itemsPerPage + leadingGutter + trailingGutter);
  double get leadingGutterExtent => leadingGutter * slotExtent;
  double get trailingGutterExtent => trailingGutter * slotExtent;
  double get pageExtent => itemsPerPage * slotExtent;
  int get pageCount => countPages(itemCount, itemsPerPage);
  int get leadingSlots => leadingSlotsFor(alignToEnd);

  static int countPages(int itemCount, int itemsPerPage) =>
      (itemCount + itemsPerPage - 1) ~/ itemsPerPage;

  static int countLeadingSlots(
          int itemCount, int itemsPerPage, bool alignToEnd) =>
      !alignToEnd || itemCount <= itemsPerPage
          ? 0
          : (itemsPerPage - itemCount % itemsPerPage) % itemsPerPage;

  int leadingSlotsFor(bool alignToEnd) =>
      countLeadingSlots(itemCount, itemsPerPage, alignToEnd);

  int pageForItem(int index, {bool? alignToEnd}) =>
      (index + leadingSlotsFor(alignToEnd ?? this.alignToEnd)) ~/ itemsPerPage;

  double pageAt(double offset) => offset / pageExtent;
  double offsetForPage(int page) => page * pageExtent;

  double get scrollExtent => switch (pageCount) {
        0 => 0,
        1 => viewportExtent,
        final count =>
          count * pageExtent + leadingGutterExtent + trailingGutterExtent,
      };

  double contentExtent(int page, bool alignToEnd) {
    if (pageCount == 1) return viewportExtent;
    if (alignToEnd) {
      return page == pageCount - 1
          ? pageExtent + trailingGutterExtent
          : pageExtent;
    }
    return page == 0 ? pageExtent + leadingGutterExtent : pageExtent;
  }

  int firstItemOnPage(int page) =>
      math.max(0, page * itemsPerPage - leadingSlots);

  int pastLastItemOnPage(int page) =>
      math.min(itemCount, (page + 1) * itemsPerPage - leadingSlots);

  int clampPage(int page) => page.clamp(0, math.max(0, pageCount - 1));

  int pageAfterResize(_PaginationGeometry previous, int oldPage) {
    if (pageCount == 0 || previous.pageCount == 0) return 0;
    oldPage = previous.clampPage(oldPage);
    // Keep the last page pinned even if another page has more items in common.
    if (oldPage == previous.pageCount - 1) return pageCount - 1;
    final oldStart = previous.firstItemOnPage(oldPage);
    final oldEnd = previous.pastLastItemOnPage(oldPage);
    final oldCenter = (oldStart + oldEnd) / 2;
    var bestPage = 0;
    var greatestOverlap = -1;
    var closestCenterDistance = double.infinity;
    for (var page = 0; page < pageCount; page++) {
      final start = firstItemOnPage(page);
      final end = pastLastItemOnPage(page);
      final overlap = math
          .max(0, math.min(oldEnd, end) - math.max(oldStart, start))
          .toInt();
      final centerDistance = ((start + end) / 2 - oldCenter).abs();
      if (overlap > greatestOverlap ||
          (overlap == greatestOverlap &&
              centerDistance < closestCenterDistance)) {
        bestPage = page;
        greatestOverlap = overlap;
        closestCenterDistance = centerDistance;
      }
    }
    return bestPage;
  }
}

class _PaginatedPageScrollPhysics extends PageScrollPhysics {
  final _PaginationGeometry? Function() geometry;
  final bool Function() isViewportAnimating;

  const _PaginatedPageScrollPhysics(
      {required this.geometry,
      required this.isViewportAnimating,
      super.parent});

  @override
  _PaginatedPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _PaginatedPageScrollPhysics(
        geometry: geometry,
        isViewportAnimating: isViewportAnimating,
        parent: buildParent(ancestor));
  }

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    if (isViewportAnimating()) return newPosition.pixels;
    return super.adjustPositionForNewDimensions(
        oldPosition: oldPosition,
        newPosition: newPosition,
        isScrolling: isScrolling,
        velocity: velocity);
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    // Geometry correction is not scrolling momentum. In particular, iOS bounce
    // physics must not carry it into a fling after the resize completes.
    if (isViewportAnimating()) return null;
    if (position.outOfRange) {
      return parent?.createBallisticSimulation(position, velocity);
    }
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return parent?.createBallisticSimulation(position, velocity);
    }
    final pages = geometry();
    if (pages == null) {
      return parent?.createBallisticSimulation(position, velocity);
    }
    final tolerance = toleranceFor(position);
    var page = pages.pageAt(position.pixels);
    if (velocity < -tolerance.velocity) {
      page -= 0.5;
    } else if (velocity > tolerance.velocity) {
      page += 0.5;
    }
    final target = pages.offsetForPage(page.round())
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if (target == position.pixels) return null;
    return ScrollSpringSimulation(spring, position.pixels, target, velocity,
        tolerance: tolerance);
  }
}

/// Controls a [PaginatedReorderableList] in logical pages.
class PaginatedReorderableListController extends ScrollController {
  final int initialPage;
  int? _pendingPage;

  PaginatedReorderableListController({this.initialPage = 0})
      : assert(initialPage >= 0),
        _pendingPage = initialPage;

  _RenderSelectedFirstList? get _renderList => hasClients
      ? position.context.storageContext
          .findAncestorStateOfType<PaginatedReorderableListState>()?._renderList
      : null;

  /// The fractional logical page at the current scroll offset.
  double? get page {
    final pages = _renderList?.pagination;
    if (pages == null || !position.hasContentDimensions) {
      return null;
    }
    final pixels = position.pixels
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    final page = pages.pageAt(pixels);
    final roundedPage = page.roundToDouble();
    return (page - roundedPage).abs() < 0.0000000001 ? roundedPage : page;
  }

  /// The logical page containing [index], once page geometry is available.
  int? pageForItem(int index) => _renderList?.pagination?.pageForItem(index);

  void _applyPendingPage(
      {int? pendingPageOverride, bool revealInLayout = false}) {
    if (pendingPageOverride != null) {
      _pendingPage = pendingPageOverride;
    }
    if (_pendingPage case final pendingPage?
        when _renderList?.pagination != null) {
      _pendingPage = null;
      if (!revealInLayout) jumpToPage(pendingPage);
    }
  }

  void jumpToPage(int page) {
    final pages = _renderList?.pagination;
    if (pages == null) {
      _pendingPage = page;
      return;
    }
    final target = pages.offsetForPage(page);
    if ((position.pixels - target).abs() <= precisionErrorTolerance) {
      return;
    }
    jumpTo(target);
  }

  Future<void> animateToPage(int page,
      {required Duration duration, required Curve curve}) {
    final pages = _renderList?.pagination;
    if (pages == null) {
      _pendingPage = page;
      return Future<void>.value();
    }
    final target = pages.offsetForPage(page);
    if ((position.pixels - target).abs() <= precisionErrorTolerance) {
      return Future<void>.value();
    }
    return animateTo(target, duration: duration, curve: curve);
  }

  /// Reveals an item without aligning to a full page, useful when an obstruction
  /// hides part of a page and page snapping is disabled.
  Future<void> ensureItemVisible(int index,
      {required Duration duration, required Curve curve}) async {
    if (!hasClients || !position.hasContentDimensions) return;
    final list = position.context.storageContext
        .findAncestorStateOfType<PaginatedReorderableListState>();
    final renderList = list?._renderList;
    if (list == null || renderList == null || index < 0 || index >= list.widget.itemCount) return;
    final pixels = position.pixels;
    final visibleExtent =
        position.viewportDimension - list.widget.padding.along(position.axis);
    final target = renderList._offsetToReveal(index, pixels, visibleExtent)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((target - pixels).abs() <= precisionErrorTolerance) return;
    if (duration == Duration.zero) {
      jumpTo(target);
    } else {
      await animateTo(target, duration: duration, curve: curve);
    }
  }

}

/// A keyed item for [PaginatedReorderableList].
///
/// Put the drag start listener below this widget.
class PaginatedReorderableListItem extends SingleChildRenderObjectWidget {
  final int index;

  const PaginatedReorderableListItem(
      {required this.index, required super.child, required super.key});

  /// The selected item's index relative to this item on the same page.
  /// Positive values mean the selected item is after this one; negative values
  /// mean it is before. Returns null for the selected item or another page.
  static int? selectedItemDeltaOf(BuildContext context) =>
      _PaginatedItemSelectionScope.maybeOf(context)?.selectedItemDelta;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPaginatedReorderableListItem(index);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderPaginatedReorderableListItem).update(index);
  }
}

class _PaginatedItemSelectionScope extends InheritedWidget {
  final int? selectedItemDelta;

  const _PaginatedItemSelectionScope({
    required this.selectedItemDelta,
    required super.child,
    super.key,
  });

  static _PaginatedItemSelectionScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PaginatedItemSelectionScope>();

  @override
  bool updateShouldNotify(_PaginatedItemSelectionScope oldWidget) =>
      selectedItemDelta != oldWidget.selectedItemDelta;
}

/// Horizontal item padding that gives content more room only when its slot
/// becomes too narrow. [shrinkWeights] controls which side may contract:
/// `dx` is the left side and `dy` is the right side.
class PaginatedReorderableListItemPadding extends SingleChildRenderObjectWidget {
  final double preferredContentExtent;
  final Offset shrinkWeights;

  const PaginatedReorderableListItemPadding({
    required this.preferredContentExtent,
    required this.shrinkWeights,
    required super.child,
    super.key,
  }) : assert(preferredContentExtent >= 0);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPaginatedItemPadding(preferredContentExtent, shrinkWeights);

  @override
  void updateRenderObject(
      BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderPaginatedItemPadding)
      ..preferredContentExtent = preferredContentExtent
      ..shrinkWeights = shrinkWeights;
  }
}

class _RenderPaginatedItemPadding extends RenderShiftedBox {
  _RenderPaginatedItemPadding(
      this._preferredContentExtent, this._shrinkWeights)
      : super(null);

  static const double _normalSidePadding = 16;
  static const double _minimumSidePadding = 4;
  static const double _verticalPadding = 8;

  double _preferredContentExtent;
  set preferredContentExtent(double value) {
    if (_preferredContentExtent == value) return;
    _preferredContentExtent = value;
    markNeedsLayout();
  }

  Offset _shrinkWeights;
  set shrinkWeights(Offset value) {
    if (_shrinkWeights == value) return;
    final oldPadding = hasSize ? _paddingForWidth(constraints.maxWidth) : null;
    _shrinkWeights = value;
    if (oldPadding == null ||
        oldPadding != _paddingForWidth(constraints.maxWidth)) {
      markNeedsLayout();
    }
  }

  double? get _unselectedItemExtent {
    RenderObject? ancestor = parent;
    while (ancestor != null && ancestor is! _RenderPaginatedReorderableListItem) {
      ancestor = ancestor.parent;
    }
    return (ancestor as _RenderPaginatedReorderableListItem?)
        ?._unselectedExtent;
  }

  EdgeInsets _paddingForWidth(double availableWidth) {
    final leftCapacity =
        (_normalSidePadding - _minimumSidePadding) * _shrinkWeights.dx;
    final rightCapacity =
        (_normalSidePadding - _minimumSidePadding) * _shrinkWeights.dy;
    final totalCapacity = leftCapacity + rightCapacity;
    final unselectedExtent = _unselectedItemExtent;
    if (!availableWidth.isFinite || totalCapacity == 0 ||
        unselectedExtent == null) {
      return const EdgeInsets.symmetric(
          horizontal: _normalSidePadding, vertical: _verticalPadding);
    }
    final deficit = math.max(0.0,
        _preferredContentExtent + 2 * _normalSidePadding - availableWidth);
    // Do not expose more text than the unselected slot did. Only return space
    // actually taken from this item by the selected item's expansion.
    final selectionPressure = math.max(0.0, unselectedExtent - availableWidth);
    final shrink = math.min(math.min(deficit, selectionPressure), totalCapacity);
    return EdgeInsets.only(
        left: _normalSidePadding - shrink * leftCapacity / totalCapacity,
        right: _normalSidePadding - shrink * rightCapacity / totalCapacity,
        top: _verticalPadding,
        bottom: _verticalPadding);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final padding = _paddingForWidth(constraints.maxWidth);
    final childSize = child?.getDryLayout(constraints.deflate(padding)) ??
        Size.zero;
    return constraints.constrain(Size(
        childSize.width + padding.horizontal,
        childSize.height + padding.vertical));
  }

  @override
  void performLayout() {
    final padding = _paddingForWidth(constraints.maxWidth);
    final childBox = child;
    if (childBox == null) {
      size = constraints.constrain(Size(padding.horizontal, padding.vertical));
      return;
    }
    childBox.layout(constraints.deflate(padding), parentUsesSize: true);
    size = constraints.constrain(Size(
        childBox.size.width + padding.horizontal,
        childBox.size.height + padding.vertical));
    final extraWidth = math.max(
        0.0, size.width - padding.horizontal - childBox.size.width);
    final extraHeight = math.max(
        0.0, size.height - padding.vertical - childBox.size.height);
    (childBox.parentData! as BoxParentData).offset = Offset(
        padding.left + extraWidth / 2, padding.top + extraHeight / 2);
  }
}

class _RenderPaginatedReorderableListItem extends RenderProxyBox {
  _RenderPaginatedReorderableListItem(this._index);

  int _index;

  _RenderSelectedFirstList? get _list {
    RenderObject? ancestor = parent;
    while (ancestor != null && ancestor is! _RenderSelectedFirstList) {
      ancestor = ancestor.parent;
    }
    return ancestor as _RenderSelectedFirstList?;
  }

  double? get _unselectedExtent => _list?.unselectedExtentForIndex(_index);

  void update(int index) {
    _invalidatePreferredExtent();
    _index = index;
    markNeedsLayout();
  }

  void _invalidatePreferredExtent() {
    _list?.invalidatePreferredExtentForIndex(_index);
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

typedef _ViewportSnapshot = ({
  double scrollExtent,
  double Function(int) offsetAt,
  double Function(int) extentAt,
});

class _PaginatedSliverReorderableList extends SliverReorderableList {
  final VoidCallback onViewportAnimationChanged;
  final PaginatedReorderableListDelegate paginationDelegate;
  final double gutterExtent;
  final double leadingGutterExtent;
  final double viewportPadding;
  final bool keepSelectedVisible;
  final bool previousAlignPagesToEnd;
  final bool alignPagesToEnd;
  final Animation<double> pageAlignmentAnimation;
  final int? selectedIndex;
  final double selectedItemExtentFactor;
  final Duration selectedItemAnimationDuration;
  final Curve selectedItemAnimationCurve;

  const _PaginatedSliverReorderableList(
      {required this.onViewportAnimationChanged,
      required this.paginationDelegate,
      required this.gutterExtent,
      required this.leadingGutterExtent,
      required this.viewportPadding,
      required this.keepSelectedVisible,
      required this.previousAlignPagesToEnd,
      required this.alignPagesToEnd,
      required this.pageAlignmentAnimation,
      required this.selectedIndex,
      required this.selectedItemExtentFactor,
      required this.selectedItemAnimationDuration,
      required this.selectedItemAnimationCurve,
      required super.itemBuilder,
      required super.itemCount,
      required super.onReorderItem,
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
  late final AnimationController _contentSizeController;
  late final CurvedAnimation _contentSizeAnimation;
  late final AnimationController _viewportController;
  late final CurvedAnimation _viewportAnimation;
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
    _contentSizeController = AnimationController(
        vsync: this,
        duration: configuration.selectedItemAnimationDuration,
        value: 1);
    _contentSizeAnimation = CurvedAnimation(
        parent: _contentSizeController,
        curve: configuration.selectedItemAnimationCurve);
    _viewportController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250), value: 1);
    _viewportAnimation = CurvedAnimation(
        parent: _viewportController, curve: Curves.easeInOutCubic);
    _viewportController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        (widget as _PaginatedSliverReorderableList).onViewportAnimationChanged();
      }
    });
  }

  @override
  void didUpdateWidget(covariant SliverReorderableList oldWidget) {
    final oldConfiguration = oldWidget as _PaginatedSliverReorderableList;
    super.didUpdateWidget(oldWidget);
    final configuration = widget as _PaginatedSliverReorderableList;
    _selectionController.duration = configuration.selectedItemAnimationDuration;
    _selectionAnimation.curve = configuration.selectedItemAnimationCurve;
    _contentSizeController.duration = configuration.selectedItemAnimationDuration;
    _contentSizeAnimation.curve = configuration.selectedItemAnimationCurve;
    if (oldConfiguration.selectedIndex == null &&
        configuration.selectedIndex != null) {
      _contentSizeController.value = 1;
      _previousSelectedIndex = configuration.selectedIndex;
      _selectionController.value = 1;
    } else if (oldConfiguration.selectedIndex != configuration.selectedIndex) {
      _contentSizeController.value = 1;
      _previousSelectedIndex = oldConfiguration.selectedIndex;
      if (configuration.selectedItemExtentFactor == 1) {
        _selectionController.value = 1;
      } else {
        _selectionController.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _viewportAnimation.dispose();
    _viewportController.dispose();
    _contentSizeAnimation.dispose();
    _contentSizeController.dispose();
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
        leadingGutterExtent: configuration.leadingGutterExtent,
        viewportPadding: configuration.viewportPadding,
        keepSelectedVisible: configuration.keepSelectedVisible,
        previousAlignPagesToEnd: configuration.previousAlignPagesToEnd,
        alignPagesToEnd: configuration.alignPagesToEnd,
        pageAlignmentAnimation: configuration.pageAlignmentAnimation,
        previousSelectedIndex: _previousSelectedIndex,
        selectedIndex: configuration.selectedIndex,
        selectedItemExtentFactor: configuration.selectedItemExtentFactor,
        selectionAnimation: _selectionAnimation,
        contentSizeAnimation: _contentSizeAnimation,
        viewportAnimation: _viewportAnimation,
        animateViewportChanges: !MediaQuery.disableAnimationsOf(context),
        onViewportChanged: () {
          if (!mounted) return;
          _viewportController.forward(from: 0);
          configuration.onViewportAnimationChanged();
        },
        onContentSizeChanged: () {
          if (mounted) _contentSizeController.forward(from: 0);
        });
  }
}

class _SliverSelectedFirstList extends SliverMultiBoxAdaptorWidget {
  final int itemCount;
  final PaginatedReorderableListDelegate paginationDelegate;
  final double gutterExtent;
  final double leadingGutterExtent;
  final double viewportPadding;
  final bool keepSelectedVisible;
  final bool previousAlignPagesToEnd;
  final bool alignPagesToEnd;
  final Animation<double> pageAlignmentAnimation;
  final int? previousSelectedIndex;
  final int? selectedIndex;
  final double selectedItemExtentFactor;
  final Animation<double> selectionAnimation;
  final Animation<double> contentSizeAnimation;
  final VoidCallback onContentSizeChanged;
  final Animation<double> viewportAnimation;
  final bool animateViewportChanges;
  final VoidCallback onViewportChanged;

  const _SliverSelectedFirstList(
      {required super.delegate,
      required this.itemCount,
      required this.paginationDelegate,
      required this.gutterExtent,
      required this.leadingGutterExtent,
      required this.viewportPadding,
      required this.keepSelectedVisible,
      required this.previousAlignPagesToEnd,
      required this.alignPagesToEnd,
      required this.pageAlignmentAnimation,
      required this.previousSelectedIndex,
      required this.selectedIndex,
      required this.selectedItemExtentFactor,
      required this.selectionAnimation,
      required this.contentSizeAnimation,
      required this.onContentSizeChanged,
      required this.viewportAnimation,
      required this.animateViewportChanges,
      required this.onViewportChanged});

  @override
  RenderSliverVariedExtentList createRenderObject(BuildContext context) {
    return _RenderSelectedFirstList(
        childManager: context as SliverMultiBoxAdaptorElement,
        itemCount: itemCount,
        paginationDelegate: paginationDelegate,
        gutterExtent: gutterExtent,
        leadingGutterExtent: leadingGutterExtent,
        viewportPadding: viewportPadding,
        keepSelectedVisible: keepSelectedVisible,
        previousAlignPagesToEnd: previousAlignPagesToEnd,
        alignPagesToEnd: alignPagesToEnd,
        pageAlignmentAnimation: pageAlignmentAnimation,
        previousSelectedIndex: previousSelectedIndex,
        selectedIndex: selectedIndex,
        selectedItemExtentFactor: selectedItemExtentFactor,
        selectionAnimation: selectionAnimation,
        contentSizeAnimation: contentSizeAnimation,
        onContentSizeChanged: onContentSizeChanged,
        viewportAnimation: viewportAnimation,
        animateViewportChanges: animateViewportChanges,
        onViewportChanged: onViewportChanged);
  }

  @override
  void updateRenderObject(
      BuildContext context, _RenderSelectedFirstList renderObject) {
    renderObject
      ..itemCount = itemCount
      ..paginationDelegate = paginationDelegate
      ..gutterExtent = gutterExtent
      ..leadingGutterExtent = leadingGutterExtent
      ..viewportPadding = viewportPadding
      ..keepSelectedVisible = keepSelectedVisible
      ..previousAlignPagesToEnd = previousAlignPagesToEnd
      ..alignPagesToEnd = alignPagesToEnd
      ..pageAlignmentAnimation = pageAlignmentAnimation
      ..previousSelectedIndex = previousSelectedIndex
      ..selectedIndex = selectedIndex
      ..selectedItemExtentFactor = selectedItemExtentFactor
      ..selectionAnimation = selectionAnimation
      ..contentSizeAnimation = contentSizeAnimation
      ..onContentSizeChanged = onContentSizeChanged
      ..animateViewportChanges = animateViewportChanges
      ..onViewportChanged = onViewportChanged;
  }
}

class _RenderSelectedFirstList extends RenderSliverVariedExtentList {
  _RenderSelectedFirstList(
      {required super.childManager,
      required int itemCount,
      required PaginatedReorderableListDelegate paginationDelegate,
      required double gutterExtent,
      required double leadingGutterExtent,
      required double viewportPadding,
      required bool keepSelectedVisible,
      required bool previousAlignPagesToEnd,
      required bool alignPagesToEnd,
      required Animation<double> pageAlignmentAnimation,
      required int? previousSelectedIndex,
      required int? selectedIndex,
      required double selectedItemExtentFactor,
      required Animation<double> selectionAnimation,
      required Animation<double> contentSizeAnimation,
      required VoidCallback onContentSizeChanged,
      required Animation<double> viewportAnimation,
      required this.animateViewportChanges,
      required this.onViewportChanged})
      : _itemCount = itemCount,
        _paginationDelegate = paginationDelegate,
        _gutterExtent = gutterExtent,
        _leadingGutterExtent = leadingGutterExtent,
        _viewportPadding = viewportPadding,
        _keepSelectedVisible = keepSelectedVisible,
        _previousAlignPagesToEnd = previousAlignPagesToEnd,
        _alignPagesToEnd = alignPagesToEnd,
        _pageAlignmentAnimation = pageAlignmentAnimation,
        _previousSelectedIndex = previousSelectedIndex,
        _selectedIndex = selectedIndex,
        _selectedItemExtentFactor = selectedItemExtentFactor,
        _selectionAnimation = selectionAnimation,
        _contentSizeAnimation = contentSizeAnimation,
        _onContentSizeChanged = onContentSizeChanged,
        _viewportAnimation = viewportAnimation,
        super(itemExtentBuilder: _unusedItemExtentBuilder);

  int _itemCount;
  PaginatedReorderableListDelegate _paginationDelegate;
  double _gutterExtent;
  double _leadingGutterExtent;
  double _viewportPadding;
  bool _keepSelectedVisible;

  set keepSelectedVisible(bool value) {
    if (_keepSelectedVisible == value) return;
    _keepSelectedVisible = value;
    markNeedsLayout();
  }

  set viewportPadding(double value) {
    if (_viewportPadding == value) return;
    _viewportPadding = value;
    markNeedsLayout();
  }

  // Keep the inputs to the applied layout together for the next layout pass.
  ({
    _PaginationGeometry pages,
    double crossAxisExtent,
    double visibleExtent,
    int? revealIndex,
  })? _layout;
  _PaginationGeometry? get pagination => _layout?.pages;
  _PaginationGeometry get _pages => _layout!.pages;
  double get _viewportExtent => _pages.viewportExtent;
  final Animation<double> _viewportAnimation;
  bool animateViewportChanges;
  VoidCallback onViewportChanged;
  ({int page, double offset, _ViewportSnapshot? snapshot})? _viewportTransition;
  bool _viewportAnimationPending = false;
  int _viewportAnimationGeneration = 0;
  double get _viewportAnimationProgress =>
      _viewportAnimationPending ? 0 : _viewportAnimation.value;
  bool get isViewportAnimating => _viewportTransition != null;
  bool _previousAlignPagesToEnd;
  bool _alignPagesToEnd;
  Animation<double> _pageAlignmentAnimation;
  int get _itemsPerPage => _pages.itemsPerPage;
  int? _previousSelectedIndex;
  int? _selectedIndex;
  double _selectedItemExtentFactor;
  Animation<double> _selectionAnimation;
  Animation<double> _contentSizeAnimation;
  VoidCallback _onContentSizeChanged;
  double? _previousPreferredSelectedExtent;
  double? _preferredSelectedExtent;
  double? _contentSizeAnimationStart;
  bool _animateNextPreferredMeasurement = false;
  bool _contentSizeAnimationPending = false;
  int _contentSizeChangeGeneration = 0;
  bool _previousPreferredExtentNeedsMeasurement = true;
  bool _preferredExtentNeedsMeasurement = true;
  bool _didCorrectInitialSelectedPage = false;

  double _offsetToReveal(int index, double pixels, double visibleExtent) {
    // Status elements and controls may cover the entire remaining viewport.
    // Preserve the position until there is space to reveal a tab again.
    if (visibleExtent <= 0) return pixels;
    final start = _layoutOffsetForIndex(index);
    final extent = _animatedExtentForIndex(index);
    final trailingOffset = start + extent - visibleExtent;
    if (extent > visibleExtent) return trailingOffset;
    if (start < pixels) return start;
    if (trailingOffset > pixels) return trailingOffset;
    return pixels;
  }

  int _leadingEmptySlotsFor(bool alignPagesToEnd) =>
      _pages.leadingSlotsFor(alignPagesToEnd);

  set gutterExtent(double value) {
    if (_gutterExtent == value) return;
    _gutterExtent = value;
    _invalidatePreferredExtents();
    markNeedsLayout();
  }

  set leadingGutterExtent(double value) {
    if (_leadingGutterExtent == value) return;
    _leadingGutterExtent = value;
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
    _preferredSelectedExtent = null;
    _animateNextPreferredMeasurement = false;
    _contentSizeAnimationStart = null;
    _contentSizeAnimationPending = false;
    _contentSizeChangeGeneration++;
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

  set contentSizeAnimation(Animation<double> value) {
    if (identical(_contentSizeAnimation, value)) return;
    if (attached) _contentSizeAnimation.removeListener(markNeedsLayout);
    _contentSizeAnimation = value;
    if (attached) _contentSizeAnimation.addListener(markNeedsLayout);
    markNeedsLayout();
  }

  set onContentSizeChanged(VoidCallback value) {
    _onContentSizeChanged = value;
  }

  void _invalidatePreferredExtents() {
    _animateNextPreferredMeasurement = false;
    _contentSizeAnimationStart = null;
    _contentSizeAnimationPending = false;
    _contentSizeChangeGeneration++;
    _previousPreferredExtentNeedsMeasurement = true;
    _preferredExtentNeedsMeasurement = true;
  }

  void invalidatePreferredExtentForIndex(int index) {
    if (_selectedItemExtentFactor == 1) return;
    var invalidated = false;
    if (index == _previousSelectedIndex) {
      _previousPreferredExtentNeedsMeasurement = true;
      invalidated = true;
    }
    if (index == _selectedIndex) {
      _preferredExtentNeedsMeasurement = true;
      _animateNextPreferredMeasurement = true;
      invalidated = true;
    }
    if (invalidated) {
      markNeedsLayout();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _selectionAnimation.addListener(markNeedsLayout);
    _contentSizeAnimation.addListener(markNeedsLayout);
    _pageAlignmentAnimation.addListener(markNeedsLayout);
    _viewportAnimation.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _viewportAnimationGeneration++;
    _viewportAnimation.removeListener(markNeedsLayout);
    _selectionAnimation.removeListener(markNeedsLayout);
    _contentSizeAnimation.removeListener(markNeedsLayout);
    _pageAlignmentAnimation.removeListener(markNeedsLayout);
    super.detach();
  }

  int get _pageCount => _pages.pageCount;

  int _pageForIndex(int index, bool alignPagesToEnd) =>
      _pages.pageForItem(index, alignToEnd: alignPagesToEnd);

  double get _interiorEqualExtent => _pages.slotExtent;

  double get physicalGutterExtent => _pages.trailingGutterExtent;
  double get physicalLeadingGutterExtent => _pages.leadingGutterExtent;

  double get _pageExtent => _pages.pageExtent;

  bool get _usesSidebarSlots => constraints.axis == Axis.vertical &&
      _leadingGutterExtent == 0 && _gutterExtent == 0 &&
      _selectedItemExtentFactor == 1;

  double get _pageAlignedExtent {
    final target = _pages.scrollExtent;
    final start = _viewportTransition?.snapshot?.scrollExtent;
    return start == null
        ? target
        : start + (target - start) * _viewportAnimationProgress;
  }

  double _pageContentExtent(int page, bool alignPagesToEnd) =>
      _pages.contentExtent(page, alignPagesToEnd);

  double _equalExtentForPage(int page, bool alignPagesToEnd) =>
      _pageContentExtent(page, alignPagesToEnd) / _itemsPerPage;

  double? unselectedExtentForIndex(int index) {
    if (pagination == null || !_isValidIndex(index)) return null;
    final previousPage = _pageForIndex(index, _previousAlignPagesToEnd);
    final page = _pageForIndex(index, _alignPagesToEnd);
    final begin = _equalExtentForPage(previousPage, _previousAlignPagesToEnd);
    final end = _equalExtentForPage(page, _alignPagesToEnd);
    return begin + (end - begin) * _pageAlignmentAnimation.value;
  }

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

  double? get _animatedPreferredSelectedExtent {
    final target = _preferredSelectedExtent;
    final start = _contentSizeAnimationStart;
    if (target == null || start == null) return target;
    final t = _contentSizeAnimationPending ? 0.0 : _contentSizeAnimation.value;
    return start + (target - start) * t;
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
        _animatedPreferredSelectedExtent, alignPagesToEnd);
    final t = _selectionAnimation.value;
    return begin + (end - begin) * t;
  }

  double _animatedExtentForIndex(int index) {
    if (_usesSidebarSlots) return _sidebarSlotExtent;
    final begin =
        _selectionAnimatedExtentForIndex(index, _previousAlignPagesToEnd);
    final end = _selectionAnimatedExtentForIndex(index, _alignPagesToEnd);
    final target = begin + (end - begin) * _pageAlignmentAnimation.value;
    final start = _viewportTransition?.snapshot?.extentAt(index);
    return start == null
        ? target
        : start + (target - start) * _viewportAnimationProgress;
  }

  double get _sidebarSlotExtent {
    final target = _pages.slotExtent;
    final start = _viewportTransition?.snapshot?.extentAt(0);
    return start == null
        ? target
        : start + (target - start) * _viewportAnimationProgress;
  }

  double _selectionAnimatedNormalExtentForPage(
      int page, bool alignPagesToEnd) {
    final begin = _normalExtentForPage(
        page,
        _previousSelectedIndex,
        _previousPreferredSelectedExtent,
        alignPagesToEnd);
    final end = _normalExtentForPage(page, _selectedIndex,
        _animatedPreferredSelectedExtent, alignPagesToEnd);
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

  double _laidOutMainAxisExtent(RenderBox child) => switch (constraints.axis) {
        Axis.horizontal => child.size.width,
        Axis.vertical => child.size.height
      };

  double _leadingEmptyExtentFor(bool alignPagesToEnd) {
    if (!alignPagesToEnd || _pageCount <= 1) return 0;
    return physicalLeadingGutterExtent +
        _leadingEmptySlotsFor(true) *
            (_usesSidebarSlots
                ? _pages.slotExtent
                : _selectionAnimatedNormalExtentForPage(0, true));
  }

  double get _leadingEmptyExtent {
    final begin = _leadingEmptyExtentFor(_previousAlignPagesToEnd);
    final end = _leadingEmptyExtentFor(_alignPagesToEnd);
    final t = _pageAlignmentAnimation.value;
    final target = begin + (end - begin) * t;
    final start = _viewportTransition?.snapshot?.offsetAt(0);
    return start == null
        ? target
        : start + (target - start) * _viewportAnimationProgress;
  }

  double _layoutOffsetForSelection(int index, int? selectedIndex,
      double? preferredExtent, bool alignPagesToEnd) {
    final leadingEmptySlots = _leadingEmptySlotsFor(alignPagesToEnd);
    final slotCount = leadingEmptySlots + math.min(index, _itemCount);
    final fullPageCount = slotCount ~/ _itemsPerPage;
    final partialPageSlotCount = slotCount % _itemsPerPage;
    var offset =
        alignPagesToEnd && _pageCount > 1 ? physicalLeadingGutterExtent : 0.0;
    offset += fullPageCount * _pageExtent;
    if (fullPageCount > 0) {
      if (_pageCount == 1) {
        offset += _viewportExtent - _pageExtent;
      } else if (!alignPagesToEnd) {
        offset += physicalLeadingGutterExtent;
      } else if (fullPageCount == _pageCount) {
        offset += physicalGutterExtent;
      }
    }
    if (partialPageSlotCount > 0) {
      final page = fullPageCount;
      final normalExtent = _normalExtentForPage(
          page, selectedIndex, preferredExtent, alignPagesToEnd);
      offset += partialPageSlotCount * normalExtent;
      if (_isValidIndex(selectedIndex)) {
        final selectedSlot = selectedIndex! + leadingEmptySlots;
        if (selectedSlot ~/ _itemsPerPage == page &&
            selectedSlot % _itemsPerPage < partialPageSlotCount) {
          offset += _selectedExtent(
                  page, preferredExtent, alignPagesToEnd) -
              normalExtent;
        }
      }
    }
    return offset;
  }

  double _selectionAnimatedLayoutOffsetForIndex(
      int index, bool alignPagesToEnd) {
    final begin = _layoutOffsetForSelection(index, _previousSelectedIndex,
        _previousPreferredSelectedExtent, alignPagesToEnd);
    final end = _layoutOffsetForSelection(index, _selectedIndex,
        _animatedPreferredSelectedExtent, alignPagesToEnd);
    final t = _selectionAnimation.value;
    return begin + (end - begin) * t;
  }

  double _layoutOffsetForIndex(int index) {
    if (_usesSidebarSlots) {
      return _leadingEmptyExtent + math.min(index, _itemCount) * _sidebarSlotExtent;
    }
    final begin = _selectionAnimatedLayoutOffsetForIndex(
        index, _previousAlignPagesToEnd);
    final end = _selectionAnimatedLayoutOffsetForIndex(
        index, _alignPagesToEnd);
    final t = _pageAlignmentAnimation.value;
    final target = begin + (end - begin) * t;
    final start = _viewportTransition?.snapshot?.offsetAt(index);
    return start == null
        ? target
        : start + (target - start) * _viewportAnimationProgress;
  }

  @override
  double indexToLayoutOffset(double itemExtent, int index) =>
      _layoutOffsetForIndex(index);

  @override
  double? childScrollOffset(RenderObject child) =>
      _layoutOffsetForIndex(indexOf(child as RenderBox));

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset, double itemExtent) {
    if (_usesSidebarSlots) return _sidebarIndexAtOffset(scrollOffset);
    return super.getMinChildIndexForScrollOffset(
        math.max(0.0, scrollOffset - _leadingEmptyExtent), itemExtent);
  }

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset, double itemExtent) {
    if (_usesSidebarSlots) return _sidebarIndexAtOffset(scrollOffset);
    return super.getMaxChildIndexForScrollOffset(
        math.max(0.0, scrollOffset - _leadingEmptyExtent), itemExtent);
  }

  int _sidebarIndexAtOffset(double scrollOffset) {
    final offset = scrollOffset - _leadingEmptyExtent;
    if (offset <= 0 || _itemCount == 0) return 0;
    // Match Flutter's varied-extent boundary rule: an offset exactly at an
    // item's end still includes that item in the layout range.
    return ((offset / _sidebarSlotExtent).ceil() - 1).clamp(0, _itemCount - 1);
  }

  void _measureSelectedItems() {
    RenderBox? selectedChild;
    if (_isValidIndex(_selectedIndex)) {
      selectedChild = _childAtIndex(_selectedIndex!);
      if (selectedChild == null && firstChild == null) {
        if (addInitialChild(index: _selectedIndex!)) selectedChild = firstChild;
      }
      if (selectedChild != null && _preferredExtentNeedsMeasurement) {
        final oldTarget = _preferredSelectedExtent;
        final oldAnimatedExtent = _animatedPreferredSelectedExtent;
        selectedChild.layout(
            constraints.asBoxConstraints(
                minExtent: 0,
                maxExtent:
                    _maximumSelectedExtentForIndex(_selectedIndex!)),
            parentUsesSize: true);
        _preferredSelectedExtent = _laidOutMainAxisExtent(selectedChild);
        _preferredExtentNeedsMeasurement = false;
        if (_animateNextPreferredMeasurement && oldTarget != null &&
            oldAnimatedExtent != null &&
            (_preferredSelectedExtent! - oldTarget).abs() >
                precisionErrorTolerance) {
          _contentSizeAnimationStart = oldAnimatedExtent;
          _contentSizeAnimationPending = true;
          final generation = ++_contentSizeChangeGeneration;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!attached || generation != _contentSizeChangeGeneration) return;
            _contentSizeAnimationPending = false;
            _onContentSizeChanged();
          });
        } else if (!_animateNextPreferredMeasurement) {
          _contentSizeAnimationStart = null;
          _contentSizeAnimationPending = false;
          _contentSizeChangeGeneration++;
        }
        _animateNextPreferredMeasurement = false;
      }
    } else {
      _preferredSelectedExtent = null;
      _contentSizeAnimationStart = null;
      _contentSizeAnimationPending = false;
      _contentSizeChangeGeneration++;
      _preferredExtentNeedsMeasurement = false;
    }

    RenderBox? previousSelectedChild;
    if (_isValidIndex(_previousSelectedIndex)) {
      previousSelectedChild = _previousSelectedIndex == _selectedIndex
          ? selectedChild
          : _childAtIndex(_previousSelectedIndex!);
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
        _previousPreferredSelectedExtent =
            _laidOutMainAxisExtent(previousSelectedChild);
        _previousPreferredExtentNeedsMeasurement = false;
      }
    } else {
      _previousPreferredSelectedExtent = null;
      _previousPreferredExtentNeedsMeasurement = false;
    }
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
  }

  _ViewportSnapshot _captureViewport() {
    final scrollExtent = _pageAlignedExtent;
    if (_usesSidebarSlots) {
      // Equal slots stay equal during interpolation. Two values describe the
      // whole list, including when a resize interrupts another resize.
      final leading = _layoutOffsetForIndex(0);
      final slot = _animatedExtentForIndex(0);
      return (
        scrollExtent: scrollExtent,
        offsetAt: (index) => leading + index * slot,
        extentAt: (_) => slot,
      );
    }
    final offsets = List<double>.generate(_itemCount + 1, _layoutOffsetForIndex);
    final extents = List<double>.generate(_itemCount, _animatedExtentForIndex);
    return (
      scrollExtent: scrollExtent,
      offsetAt: (index) => offsets[index],
      extentAt: (index) => extents[index],
    );
  }

  void _startViewportAnimation(int page, double scrollOffset,
      {_ViewportSnapshot? snapshot}) {
    _viewportTransition = (page: page, offset: scrollOffset, snapshot: snapshot);
    _viewportAnimationPending = true;
    final generation = ++_viewportAnimationGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!attached || generation != _viewportAnimationGeneration) return;
      _viewportAnimationPending = false;
      onViewportChanged();
    });
  }

  @override
  void performLayout() {
    final previousLayout = _layout;
    final previous = previousLayout?.pages;
    final parentSliver = parent;
    final padding = parentSliver is RenderSliverPadding ? parentSliver : null;
    final appliedPadding = padding?.resolvedPadding ?? EdgeInsets.zero;
    final visibleExtent = constraints.viewportMainAxisExtent -
        appliedPadding.along(constraints.axis);
    final viewportExtent =
        math.max(1.0, constraints.viewportMainAxisExtent - _viewportPadding);
    final resolvedItemsPerPage = _paginationDelegate.getMainAxisCount(viewportExtent);
    if (resolvedItemsPerPage <= 0) {
      throw FlutterError(
          'A pagination delegate must return at least one item per page.');
    }
    final next = _PaginationGeometry(
      viewportExtent: viewportExtent,
      itemsPerPage: resolvedItemsPerPage,
      itemCount: _itemCount,
      leadingGutter: _leadingGutterExtent,
      trailingGutter: _gutterExtent,
      alignToEnd: _alignPagesToEnd,
    );
    final revealIndex = _keepSelectedVisible && _isValidIndex(_selectedIndex)
        ? _selectedIndex
        : null;
    final viewportChanged = previous?.viewportExtent != viewportExtent;
    final restoreSelectedPage = !_keepSelectedVisible &&
        previousLayout?.revealIndex != null &&
        _isValidIndex(_selectedIndex);
    if (isViewportAnimating &&
        (_keepSelectedVisible ||
            !animateViewportChanges ||
            constraints.axis != Axis.vertical ||
            previous?.itemCount != _itemCount)) {
      _viewportTransition = null;
      _viewportAnimationPending = false;
      _viewportAnimationGeneration++;
    }
    final scrollOffset =
        padding?.constraints.scrollOffset ?? constraints.scrollOffset;
    final closeAtEnd = previous != null && !_keepSelectedVisible && _usesSidebarSlots &&
        _alignPagesToEnd &&
        previous.itemCount == _itemCount + 1 &&
        _itemCount >= resolvedItemsPerPage && resolvedItemsPerPage > 1 &&
        _selectedIndex == _itemCount - 1 &&
        _previousSelectedIndex == _itemCount &&
        !viewportChanged &&
        previous.itemsPerPage == resolvedItemsPerPage &&
        scrollOffset >= previous.offsetForPage(previous.pageCount - 1) - 1;
    if (!_keepSelectedVisible && animateViewportChanges &&
        constraints.axis == Axis.vertical &&
        previous != null &&
        (viewportChanged || restoreSelectedPage) &&
        previous.itemCount == _itemCount &&
        _itemCount > 0) {
      // Capture the currently displayed geometry, including an interrupted
      // transition, while the sliver still uses the previous page geometry.
      final oldPage =
          _viewportTransition?.page ?? previous.pageAt(scrollOffset).round();
      final targetPage = restoreSelectedPage
          ? next.pageForItem(_selectedIndex!)
          : next.pageAfterResize(previous, oldPage);
      _startViewportAnimation(targetPage, scrollOffset,
          snapshot: _captureViewport());
    }
    _layout = (
      pages: next,
      crossAxisExtent: constraints.crossAxisExtent,
      visibleExtent: visibleExtent,
      revealIndex: revealIndex,
    );
    if (previous?.itemsPerPage != resolvedItemsPerPage ||
        viewportChanged ||
        previousLayout?.crossAxisExtent != constraints.crossAxisExtent) {
      _invalidatePreferredExtents();
    }
    if (closeAtEnd && animateViewportChanges) {
      // The remaining tabs keep their screen positions on the first frame.
      // Only the slot vacated by the closed tab needs to slide away.
      _startViewportAnimation(_pageCount - 1,
          (_pageCount - 1) * _pageExtent + _interiorEqualExtent);
    }
    if (_viewportTransition case final transition?) {
      final page = next.clampPage(transition.page);
      final t = _viewportAnimationProgress;
      final targetOffset = transition.offset +
          (next.offsetForPage(page) - transition.offset) * t;
      if (t == 1) {
        _viewportTransition = null;
      }
      final correction = targetOffset - scrollOffset;
      if (correction.abs() > precisionErrorTolerance) {
        geometry = SliverGeometry(scrollOffsetCorrection: correction);
        return;
      }
    } else if (!_keepSelectedVisible && previous != null) {
      final oldPage = previous.pageAt(scrollOffset).round();
      int? page;
      if (closeAtEnd) {
        page = _pageCount - 1;
      } else if (restoreSelectedPage) {
        page = next.pageForItem(_selectedIndex!);
      } else if (previous.itemsPerPage != next.itemsPerPage ||
          (previous.pageExtent - next.pageExtent).abs() > 0.000001) {
        page = next.pageAfterResize(previous, oldPage);
      } else if (previous.itemCount != next.itemCount ||
          previous.leadingSlots != next.leadingSlots) {
        page = next.clampPage(oldPage);
      }
      if (page != null) {
        final correction = next.offsetForPage(page) - scrollOffset;
        if (correction.abs() > precisionErrorTolerance) {
          geometry = SliverGeometry(scrollOffsetCorrection: correction);
          return;
        }
      }
    }
    if (!_didCorrectInitialSelectedPage && _itemCount > 0 && _pageExtent > 0) {
      _didCorrectInitialSelectedPage = true;
      if (!_keepSelectedVisible && _isValidIndex(_selectedIndex)) {
        final selectedPage =
            _pageForIndex(_selectedIndex!, _alignPagesToEnd);
        final selectedPageOffset = selectedPage * _pageExtent;
        // SliverPadding subtracts its leading clearance from the child's
        // scroll offset. Page targets use the scrollable's original offset.
        final correction = selectedPageOffset - scrollOffset;
        if (correction.abs() > precisionErrorTolerance) {
          geometry = SliverGeometry(scrollOffsetCorrection: correction);
          return;
        }
      }
    }
    if (_selectedItemExtentFactor != 1) _measureSelectedItems();

    if (revealIndex != null && visibleExtent > 0 &&
        (viewportChanged ||
            previous?.itemCount != _itemCount ||
            previousLayout?.visibleExtent != visibleExtent ||
            previousLayout?.revealIndex != revealIndex)) {
      final maxOffset = math.max(0.0, _pageAlignedExtent - visibleExtent);
      final target = _offsetToReveal(revealIndex, scrollOffset, visibleExtent)
          .clamp(0.0, maxOffset);
      final correction = target - scrollOffset;
      if (correction.abs() > precisionErrorTolerance) {
        geometry = SliverGeometry(scrollOffsetCorrection: correction);
        return;
      }
    }

    super.performLayout();

    if (geometry?.scrollOffsetCorrection == null) {
      final pageAlignedExtent = _pageAlignedExtent;
      final hasRoom = !_keepSelectedVisible || visibleExtent > 0;
      // Keep the list laid out and its offset intact when the status area and
      // controls meet, but hide the tabs until there is room between them.
      final paintExtent = hasRoom
          ? calculatePaintOffset(constraints, from: 0, to: pageAlignedExtent)
          : 0.0;
      final cacheExtent =
          calculateCacheOffset(constraints, from: 0, to: pageAlignedExtent);
      geometry = geometry!.copyWith(
          scrollExtent: pageAlignedExtent,
          paintExtent: paintExtent,
          layoutExtent: paintExtent,
          hitTestExtent: paintExtent,
          cacheExtent: cacheExtent,
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
  final ReorderCallback onReorderItem;
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

  /// Scrollable content clearance. Pages fit the viewport minus this padding,
  /// allowing adjacent-page items to scroll through the padded region.
  final EdgeInsets padding;

  /// Destination clearance while [padding] animates. Supplying the destination
  /// lets page geometry and clearance animate together, rather than regrouping
  /// tabs halfway through the padding animation.
  final EdgeInsets? targetPadding;

  /// Viewport space temporarily hidden, for example by the keyboard.
  /// Item sizing includes this extent; the visible scrollable stays smaller.
  final double obscuredExtent;
  final double? autoScrollerVelocityScalar;
  final ReorderDragBoundaryProvider? dragBoundaryProvider;

  /// Whether to show the fading page indicator when there is more than one page.
  final bool showPageIndicator;

  /// Builds a custom count badge for each edge that has hidden items.
  final PaginatedReorderableListIndicatorBuilder? pageIndicatorBuilder;

  /// Insets the edge count badges and alignment-pull indicator from the viewport.
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

  /// Overrides only the leading peek; defaults to [gutterExtent].
  /// Set to zero when scrollable leading padding already hints at more items.
  final double? leadingGutterExtent;

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
      required this.onReorderItem,
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
      this.padding = EdgeInsets.zero,
      this.targetPadding,
      this.obscuredExtent = 0,
      this.autoScrollerVelocityScalar,
      this.dragBoundaryProvider,
      this.showPageIndicator = true,
      this.pageIndicatorBuilder,
      this.pageIndicatorPadding = const EdgeInsets.all(12),
      this.pageIndicatorFadeDuration = const Duration(milliseconds: 200),
      this.pageIndicatorVisibleDuration = const Duration(milliseconds: 500),
      this.gutterExtent = 0,
      this.leadingGutterExtent,
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
        assert(leadingGutterExtent == null ||
            (leadingGutterExtent >= 0 &&
                leadingGutterExtent < double.infinity)),
        assert(alignmentOverpullExtent >= 0 &&
            alignmentOverpullExtent < double.infinity);

  @override
  PaginatedReorderableListState createState() =>
      PaginatedReorderableListState();
}

class _PaginationIndicators extends StatelessWidget {
  const _PaginationIndicators({
    required this.scrollDirection,
    required this.reverse,
    required this.padding,
    required this.showPageIndicator,
    required this.visible,
    required this.fadeDuration,
    required this.hiddenBefore,
    required this.hiddenAfter,
    required this.indicatorBuilder,
    required this.alignToEnd,
    required this.pullEdge,
    required this.overpullThreshold,
    required this.pullExtent,
    required this.pullArmed,
  });

  final Axis scrollDirection;
  final bool reverse;
  final EdgeInsetsGeometry padding;
  final bool showPageIndicator;
  final bool visible;
  final Duration fadeDuration;
  final int hiddenBefore;
  final int hiddenAfter;
  final PaginatedReorderableListIndicatorBuilder? indicatorBuilder;
  final bool alignToEnd;
  final _AlignmentPullEdge? pullEdge;
  final double overpullThreshold;
  final double pullExtent;
  final bool pullArmed;

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
    final indicator = indicatorBuilder?.call(context, count, edge) ??
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
        color: Color(0xFFFFFFFF), fontSize: 13, fontWeight: FontWeight.w600);
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
        context, scrollDirection, reverse);
    final pulledEdge = pullEdge == _AlignmentPullEdge.trailing
        ? forwardDirection
        : flipAxisDirection(forwardDirection);
    final destination =
        alignToEnd ? flipAxisDirection(forwardDirection) : forwardDirection;
    final progress = overpullThreshold == 0
        ? 1.0
        : (pullExtent / overpullThreshold).clamp(0.0, 1.0);
    final targetName = alignToEnd ? 'start' : 'end';
    final instruction = pullArmed
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
                    liveRegion: pullArmed,
                    label: instruction,
                    child: _buildIndicatorPill(
                        key: const ValueKey(
                            'PaginatedReorderableList.alignmentPullIndicator'),
                        child: _buildAlignmentPullSymbol(destination))))));
    return Positioned.fill(
        child: Padding(
            padding: padding,
            child: Align(
                alignment: _alignmentForEdge(pulledEdge), child: indicator)));
  }

  Widget _buildPageIndicators(BuildContext context) {
    final forwardDirection = getAxisDirectionFromAxisReverseAndDirectionality(
        context, scrollDirection, reverse);
    final beforeEdge = flipAxisDirection(forwardDirection);
    final afterEdge = forwardDirection;
    return Positioned.fill(
        child: IgnorePointer(
            child: AnimatedOpacity(
                key: const ValueKey('PaginatedReorderableList.pageIndicator'),
                opacity: visible ? 1 : 0,
                duration: fadeDuration,
                child: Padding(
                    padding: padding,
                    child: Stack(children: [
                      if (hiddenBefore > 0)
                        _buildEdgeIndicator(context, hiddenBefore, beforeEdge),
                      if (hiddenAfter > 0)
                        _buildEdgeIndicator(context, hiddenAfter, afterEdge)
                    ])))));
  }

  @override
  Widget build(BuildContext context) => Positioned.fill(
          child: Stack(children: [
        if (showPageIndicator) _buildPageIndicators(context),
        if (pullEdge != null) _buildAlignmentPullIndicator(context),
      ]));
}

class PaginatedReorderableListState extends State<PaginatedReorderableList>
    with SingleTickerProviderStateMixin {
  final GlobalKey<SliverReorderableListState> _listKey = GlobalKey();
  late PaginatedReorderableListController _controller;
  late int _currentPage;
  _PaginationGeometry? _reportedPagination;
  bool _paginationSyncScheduled = false;
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
  int? _alignmentPullStartPage;
  double _alignmentPullExtent = 0;
  bool _alignmentPullArmed = false;

  PaginatedReorderableListController get controller => _controller;
  int get page => _currentPage;
  _RenderSelectedFirstList? get _renderList {
    final renderObject = _listKey.currentContext?.findRenderObject();
    return renderObject is _RenderSelectedFirstList ? renderObject : null;
  }

  int get itemsPerPage =>
      (_renderList?.pagination ?? _reportedPagination)?.itemsPerPage ?? 1;
  bool get pagesAlignedToEnd => _alignPagesToEnd;
  int get leadingEmptySlots {
    return _PaginationGeometry.countLeadingSlots(
        widget.itemCount, itemsPerPage, _alignPagesToEnd);
  }

  int get pageCount => _PaginationGeometry.countPages(widget.itemCount, itemsPerPage);

  int pageForItem(int index) => (index + leadingEmptySlots) ~/ itemsPerPage;

  int? _selectedItemDeltaFor(int index) {
    final selectedIndex = widget.selectedIndex;
    if (selectedIndex == null || selectedIndex < 0 ||
        selectedIndex >= widget.itemCount || index == selectedIndex) {
      return null;
    }
    // The selected page is initially laid out by the sliver. Until that first
    // layout resolves its count, compacting other items avoids a first-frame
    // padding change on the page that contains the selected item.
    if (_reportedPagination == null ||
        pageForItem(index) == pageForItem(selectedIndex)) {
      return selectedIndex - index;
    }
    return null;
  }

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
      _reportedPagination = null;
    }
    if (!widget.allowTrailingAlignmentOverpull) {
      _alignmentPullEdge = null;
      _alignmentPullStartPage = null;
      _alignmentPullExtent = 0;
      _alignmentPullArmed = false;
    }
    if (oldWidget.obscuredExtent == 0 &&
        widget.obscuredExtent > 0 &&
        widget.selectedIndex != null) {
      // A scroll started before the keyboard appeared still has an old page
      // target. Stop it after layout, which has already revealed the selection.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || widget.obscuredExtent == 0 || !_controller.hasClients) {
          return;
        }
        final position = _controller.position;
        if (position is ScrollPositionWithSingleContext &&
            position.isScrollingNotifier.value) {
          position.goIdle();
        }
      });
    }
    _schedulePaginationSync();
  }

  @override
  void dispose() {
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
    if (_renderList?.isViewportAnimating ?? false) {
      // Pixels between two page geometries do not describe a user page change.
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
    if (_controller.page case final page?
        when _clampPage(page.round()) != _currentPage) {
      _schedulePaginationSync();
    }
    return false;
  }

  void _handleAlignmentOverpull(ScrollNotification notification) {
    if (!widget.allowTrailingAlignmentOverpull) return;
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _clearAlignmentPull();
      _alignmentPullStartPage =
          _clampPage((_controller.page ?? _currentPage.toDouble()).round());
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
    final startedAtToggleEdge = switch (edge) {
      _AlignmentPullEdge.leading => _alignmentPullStartPage == 0,
      _AlignmentPullEdge.trailing =>
        _alignmentPullStartPage == pageCount - 1,
      null => false
    };
    final edgeCanToggle = canChangeAlignment &&
        startedAtToggleEdge &&
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
    _alignmentPullStartPage = null;
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
    if (_paginationSyncScheduled) return;
    _paginationSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _paginationSyncScheduled = false;
      if (mounted) _syncPaginationFromRender();
    });
  }

  void _syncPaginationFromRender() {
    final renderList = _renderList;
    final next = renderList?.pagination;
    if (renderList == null || next == null) return;
    final previous = _reportedPagination;
    _reportedPagination = next;
    final itemCountChanged = previous?.itemCount != next.itemCount;
    final slotsChanged = previous?.itemsPerPage != next.itemsPerPage;
    final pageAlignmentChanged = previous?.leadingSlots != next.leadingSlots;
    final needsBuild = itemCountChanged || slotsChanged || pageAlignmentChanged;
    final initialSelectedPage = previous == null &&
            widget.selectedIndex != null &&
            widget.selectedIndex! >= 0 &&
            widget.selectedIndex! < widget.itemCount
        ? next.pageForItem(widget.selectedIndex!)
        : null;
    _controller._applyPendingPage(
        pendingPageOverride: initialSelectedPage,
        revealInLayout:
            widget.obscuredExtent > 0 && widget.selectedIndex != null);
    final targetPage = next.clampPage(renderList._viewportTransition?.page ??
        (_controller.page ?? _currentPage.toDouble()).round());
    if (_currentPage == targetPage) {
      if (needsBuild) setState(() {});
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

  @override
  Widget build(BuildContext context) {
    final paginationPadding = widget.targetPadding ?? widget.padding;
    final viewportPadding = (widget.scrollDirection == Axis.vertical
            ? paginationPadding.vertical
            : paginationPadding.horizontal) -
        widget.obscuredExtent;
    final inheritedPhysics = widget.physics ??
        ScrollConfiguration.of(context).getScrollPhysics(context);
    final effectivePhysics = widget.pageSnapping && !_reordering
        ? _PaginatedPageScrollPhysics(
                geometry: () => _renderList?.pagination,
                isViewportAnimating: () => _renderList?.isViewportAnimating ?? false)
            .applyTo(inheritedPhysics)
        : inheritedPhysics;
    final firstSlot = _clampPage(_currentPage) * itemsPerPage - leadingEmptySlots;

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
                        SliverPadding(
                            padding: widget.padding,
                            sliver: _PaginatedSliverReorderableList(
                                key: _listKey,
                            onViewportAnimationChanged: _schedulePaginationSync,
                                paginationDelegate: widget.paginationDelegate,
                                gutterExtent: widget.gutterExtent,
                                leadingGutterExtent:
                                    widget.leadingGutterExtent ??
                                        widget.gutterExtent,
                                viewportPadding: viewportPadding,
                                keepSelectedVisible: widget.obscuredExtent > 0,
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
                                itemBuilder: (context, index) {
                                  final item =
                                      widget.itemBuilder(context, index);
                                  return _PaginatedItemSelectionScope(
                                      key: ValueKey(item.key),
                                      selectedItemDelta:
                                          _selectedItemDeltaFor(index),
                                      child: item);
                                },
                                itemCount: widget.itemCount,
                                onReorderItem: widget.onReorderItem,
                                onReorderStart: _handleReorderStart,
                                onReorderEnd: _handleReorderEnd,
                                proxyDecorator: _buildReorderProxy,
                                autoScrollerVelocityScalar:
                                    widget.autoScrollerVelocityScalar,
                                dragBoundaryProvider:
                                    widget.dragBoundaryProvider))
                      ])))),
      _PaginationIndicators(
        scrollDirection: widget.scrollDirection,
        reverse: widget.reverse,
        padding: widget.pageIndicatorPadding,
        showPageIndicator: widget.showPageIndicator && pageCount > 1,
        visible: _pageIndicatorVisible,
        fadeDuration: widget.pageIndicatorFadeDuration,
        hiddenBefore: math.max(0, firstSlot),
        hiddenAfter: math.max(0, widget.itemCount - firstSlot - itemsPerPage),
        indicatorBuilder: widget.pageIndicatorBuilder,
        alignToEnd: _alignPagesToEnd,
        pullEdge: widget.allowTrailingAlignmentOverpull ? _alignmentPullEdge : null,
        overpullThreshold: widget.alignmentOverpullExtent,
        pullExtent: _alignmentPullExtent,
        pullArmed: _alignmentPullArmed,
      ),
    ]);
  }
}

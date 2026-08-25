import 'package:chan/widgets/paginated_reorderable_list.dart';
import 'package:chan/widgets/weak_gesture_recognizer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _FasterSnappingPageScrollPhysics extends ScrollPhysics {
  const _FasterSnappingPageScrollPhysics({super.parent});

  @override
  _FasterSnappingPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _FasterSnappingPageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring =>
      SpringDescription.withDampingRatio(mass: 0.3, stiffness: 150, ratio: 1.1);
}

class _LayoutRecorder extends SingleChildRenderObjectWidget {
  final ValueChanged<BoxConstraints> onLayout;

  const _LayoutRecorder({required this.onLayout, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLayoutRecorder(onLayout);

  @override
  void updateRenderObject(
      BuildContext context, _RenderLayoutRecorder renderObject) {
    renderObject.onLayout = onLayout;
  }
}

class _RenderLayoutRecorder extends RenderProxyBox {
  _RenderLayoutRecorder(this.onLayout);

  ValueChanged<BoxConstraints> onLayout;

  @override
  void performLayout() {
    onLayout(constraints);
    super.performLayout();
  }
}

Widget buildTestList(
    {required int itemCount,
    required PaginatedReorderableListDelegate delegate,
    GlobalKey<PaginatedReorderableListState>? listKey,
    PaginatedReorderableListController? controller,
    ValueChanged<int>? onPageChanged,
    ReorderCallback? onReorder,
    ScrollPhysics? physics,
    int? selectedIndex,
    double selectedItemExtentFactor = 2,
    double gutterExtent = 0,
    Map<int, Key> itemKeys = const {},
    bool tabGestures = false,
    Map<int, double> preferredMainAxisExtents = const {},
    void Function(int index, BoxConstraints constraints)? onItemLayout,
    bool delayedDragStart = false,
    Axis scrollDirection = Axis.horizontal,
    double width = 400,
    double height = 200}) {
  return WidgetsApp(
      color: const Color(0xFF000000),
      pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context)),
      home: Center(
          child: SizedBox(
              width: width,
              height: height,
              child: PaginatedReorderableList(
                  key: listKey,
                  controller: controller,
                  itemCount: itemCount,
                  paginationDelegate: delegate,
                  scrollDirection: scrollDirection,
                  selectedIndex: selectedIndex,
                  selectedItemExtentFactor: selectedItemExtentFactor,
                  gutterExtent: gutterExtent,
                  physics: physics,
                  onPageChanged: onPageChanged,
                  onReorder: onReorder ?? (_, __) {},
                  itemBuilder: (context, index) {
                    final preferredExtent = preferredMainAxisExtents[index];
                    Widget buildContent() => SizedBox(
                          width: scrollDirection == Axis.horizontal
                              ? preferredExtent
                              : null,
                          height: scrollDirection == Axis.vertical
                              ? preferredExtent
                              : null,
                          child: ColoredBox(
                              color: const Color(0xFF000000),
                              child: Text('Item $index',
                                  textDirection: TextDirection.ltr)),
                        );
                    var content = buildContent();
                    if (onItemLayout != null) {
                      content = _LayoutRecorder(
                          onLayout: (constraints) =>
                              onItemLayout(index, constraints),
                          child: content);
                    }
                    if (tabGestures) {
                      content = RawGestureDetector(
                          gestures: {
                            if (scrollDirection == Axis.horizontal)
                              WeakVerticalDragGestureRecognizer:
                                  GestureRecognizerFactoryWithHandlers<
                                      WeakVerticalDragGestureRecognizer>(
                                () => WeakVerticalDragGestureRecognizer(
                                    weakness: 2, sign: -1),
                                (recognizer) => recognizer.onEnd = (_) {},
                              )
                            else
                              WeakHorizontalDragGestureRecognizer:
                                  GestureRecognizerFactoryWithHandlers<
                                      WeakHorizontalDragGestureRecognizer>(
                                () => WeakHorizontalDragGestureRecognizer(
                                    weakness: 2, sign: 1),
                                (recognizer) => recognizer.onEnd = (_) {},
                              )
                          },
                          child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {},
                              child: content));
                    }
                    final child = delayedDragStart
                        ? ReorderableDelayedDragStartListener(
                            index: index, child: content)
                        : ReorderableDragStartListener(
                            index: index, child: content);
                    return PaginatedReorderableListItem(
                        key: itemKeys[index] ?? ValueKey(index),
                        index: index,
                        child: child);
                  }))));
}

void main() {
  group('pagination delegates', () {
    test('fixed main-axis count is constant', () {
      const delegate = PaginatedReorderableListDelegateWithFixedMainAxisCount(
          mainAxisCount: 4);
      expect(delegate.getMainAxisCount(100), 4);
      expect(delegate.getMainAxisCount(1000), 4);
    });

    test('maximum main-axis extent rounds up', () {
      const delegate = PaginatedReorderableListDelegateWithMaxMainAxisExtent(
          maxMainAxisExtent: 200);
      expect(delegate.getMainAxisCount(0), 1);
      expect(delegate.getMainAxisCount(200), 1);
      expect(delegate.getMainAxisCount(201), 2);
      expect(delegate.getMainAxisCount(500), 3);
    });
  });

  testWidgets('lays out exactly one fixed-size page at a time', (tester) async {
    final key = GlobalKey<PaginatedReorderableListState>();
    await tester.pumpWidget(buildTestList(
        listKey: key,
        itemCount: 5,
        delegate: const PaginatedReorderableListDelegateWithFixedMainAxisCount(
            mainAxisCount: 2)));
    await tester.pump();

    expect(key.currentState!.itemsPerPage, 2);
    expect(key.currentState!.pageCount, 3);
    expect(tester.getSize(find.byKey(const ValueKey(0))).width, 200);
    expect(tester.getSize(find.byKey(const ValueKey(1))).width, 200);
  });

  testWidgets('partial last page remains aligned to a page boundary',
      (tester) async {
    final key = GlobalKey<PaginatedReorderableListState>();
    await tester.pumpWidget(buildTestList(
        listKey: key,
        itemCount: 5,
        delegate: const PaginatedReorderableListDelegateWithFixedMainAxisCount(
            mainAxisCount: 2)));
    await tester.pump();

    key.currentState!.jumpToPage(2);
    await tester.pump();

    expect(key.currentState!.controller.page, 2);
    final listLeft =
        tester.getTopLeft(find.byType(PaginatedReorderableList)).dx;
    expect(tester.getTopLeft(find.byKey(const ValueKey(4))).dx, listLeft);
  });

  testWidgets('page gutter reveals adjacent items without changing chunks',
      (tester) async {
    final key = GlobalKey<PaginatedReorderableListState>();
    await tester.pumpWidget(buildTestList(
        listKey: key,
        itemCount: 15,
        width: 400,
        gutterExtent: 0.5,
        delegate: const PaginatedReorderableListDelegateWithMaxMainAxisExtent(
            maxMainAxisExtent: 80)));
    await tester.pump();

    final listLeft =
        tester.getTopLeft(find.byType(PaginatedReorderableList)).dx;
    expect(key.currentState!.itemsPerPage, 5);
    expect(key.currentState!.pageCount, 3);
    expect(tester.getSize(find.byKey(const ValueKey(0))).width,
        closeTo(220 / 3, 0.001));
    expect(tester.getTopLeft(find.byKey(const ValueKey(0))).dx, listLeft);
    expect(tester.getTopLeft(find.byKey(const ValueKey(5))).dx,
        closeTo(listLeft + 1100 / 3, 0.001));

    key.currentState!.jumpToPage(1);
    await tester.pump();

    expect(key.currentState!.controller.offset, closeTo(1000 / 3, 0.001));
    expect(key.currentState!.controller.page, 1);
    expect(tester.getTopLeft(find.byKey(const ValueKey(4))).dx,
        closeTo(listLeft - 40, 0.001));
    expect(tester.getTopLeft(find.byKey(const ValueKey(5))).dx,
        closeTo(listLeft + 100 / 3, 0.001));
    expect(tester.getTopLeft(find.byKey(const ValueKey(10))).dx,
        closeTo(listLeft + 1100 / 3, 0.001));
    expect(key.currentState!.controller.position.maxScrollExtent,
        closeTo(2000 / 3, 0.001));

    key.currentState!.jumpToPage(2);
    await tester.pump();

    expect(key.currentState!.controller.page, 2);
    expect(key.currentState!.controller.offset, closeTo(2000 / 3, 0.001));
    expect(tester.getTopLeft(find.byKey(const ValueKey(9))).dx,
        closeTo(listLeft - 100 / 3, 0.001));
    expect(tester.getTopLeft(find.byKey(const ValueKey(10))).dx,
        closeTo(listLeft + 100 / 3, 0.001));
    expect(tester.getTopLeft(find.byKey(const ValueKey(14))).dx,
        closeTo(listLeft + 300, 0.001));
  });

  testWidgets('gutter does not reserve empty space for a single page',
      (tester) async {
    final key = GlobalKey<PaginatedReorderableListState>();
    await tester.pumpWidget(buildTestList(
        listKey: key,
        itemCount: 5,
        width: 400,
        gutterExtent: 0.5,
        delegate: const PaginatedReorderableListDelegateWithFixedMainAxisCount(
            mainAxisCount: 5)));
    await tester.pump();

    final listLeft =
        tester.getTopLeft(find.byType(PaginatedReorderableList)).dx;
    expect(tester.getTopLeft(find.byKey(const ValueKey(0))).dx, listLeft);
    expect(tester.getSize(find.byKey(const ValueKey(0))).width, 80);
    expect(tester.getSize(find.byKey(const ValueKey(4))).width, 80);
    expect(key.currentState!.controller.position.maxScrollExtent, 0);
  });

  testWidgets('inward release while leading-overscrolled stays on first page',
      (tester) async {
    final key = GlobalKey<PaginatedReorderableListState>();
    await tester.pumpWidget(buildTestList(
        listKey: key,
        itemCount: 6,
        gutterExtent: 0.5,
        physics: const _FasterSnappingPageScrollPhysics(
            parent: BouncingScrollPhysics()),
        delegate: const PaginatedReorderableListDelegateWithFixedMainAxisCount(
            mainAxisCount: 2)));
    await tester.pump();

    final gesture = await tester
        .startGesture(tester.getCenter(find.byType(PaginatedReorderableList)));
    await gesture.moveBy(const Offset(300, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(-30, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(key.currentState!.page, 0);
    expect(key.currentState!.controller.page, 0);
    expect(key.currentState!.controller.offset, 0);
  });

  testWidgets('overscrolling past the first page does not return to page two',
      (tester) async {
    final key = GlobalKey<PaginatedReorderableListState>();
    await tester.pumpWidget(buildTestList(
        listKey: key,
        itemCount: 6,
        gutterExtent: 0.5,
        physics: const _FasterSnappingPageScrollPhysics(),
        delegate: const PaginatedReorderableListDelegateWithFixedMainAxisCount(
            mainAxisCount: 2)));
    await tester.pump();
    key.currentState!.jumpToPage(1);
    await tester.pump();

    await tester.drag(
        find.byType(PaginatedReorderableList), const Offset(800, 0));
    await tester.pumpAndSettle();

    expect(key.currentState!.page, 0);
    expect(key.currentState!.controller.page, 0);
    expect(key.currentState!.controller.offset, 0);
  });

  testWidgets('gutter pagination settles on the reduced page stride',
      (tester) async {
    final key = GlobalKey<PaginatedReorderableListState>();
    await tester.pumpWidget(buildTestList(
        listKey: key,
        itemCount: 12,
        width: 400,
        gutterExtent: 0.5,
        physics: const _FasterSnappingPageScrollPhysics(),
        delegate: const PaginatedReorderableListDelegateWithFixedMainAxisCount(
            mainAxisCount: 4)));
    await tester.pump();

    await tester.drag(
        find.byType(PaginatedReorderableList), const Offset(-240, 0));
    await tester.pumpAndSettle();

    expect(key.currentState!.page, 1);
    expect(key.currentState!.controller.page, 1);
    expect(key.currentState!.controller.offset, 320);
  });

  testWidgets('selected item grows to its preferred extent within the page',
      (tester) async {
    final key = GlobalKey<PaginatedReorderableListState>();
    await tester.pumpWidget(buildTestList(
        listKey: key,
        itemCount: 6,
        width: 300,
        selectedIndex: 1,
        preferredMainAxisExtents: const {1: 120},
        delegate: const PaginatedReorderableListDelegateWithFixedMainAxisCount(
            mainAxisCount: 3)));

    expect(tester.getSize(find.byKey(const ValueKey(0))).width, 90);
    expect(tester.getSize(find.byKey(const ValueKey(1))).width, 120);
    expect(tester.getSize(find.byKey(const ValueKey(2))).width, 90);
    expect(key.currentState!.controller.position.maxScrollExtent, 300);
  });

  testWidgets('selected item redistributes only the gutter-adjusted page',
      (tester) async {
    final key = GlobalKey<PaginatedReorderableListState>();
    await tester.pumpWidget(buildTestList(
        listKey: key,
        itemCount: 8,
        width: 400,
        gutterExtent: 0.5,
        selectedIndex: 1,
        preferredMainAxisExtents: const {1: 120},
        delegate: const PaginatedReorderableListDelegateWithFixedMainAxisCount(
            mainAxisCount: 4)));
    await tester.pump();

    expect(tester.getSize(find.byKey(const ValueKey(0))).width, 80);
    expect(tester.getSize(find.byKey(const ValueKey(1))).width, 120);
    expect(tester.getSize(find.byKey(const ValueKey(2))).width, 80);
    final listLeft =
        tester.getTopLeft(find.byType(PaginatedReorderableList)).dx;
    expect(tester.getTopLeft(find.byKey(const ValueKey(4))).dx, listLeft + 360);
    expect(key.currentState!.controller.position.maxScrollExtent, 320);
  });

  testWidgets('selected item preferred extent is capped by the factor',
      (tester) async {
    await tester.pumpWidget(buildTestList(
        itemCount: 3,
        width: 300,
        selectedIndex: 1,
        preferredMainAxisExtents: const {1: 200},
        delegate: const PaginatedReorderableListDelegateWithFixedMainAxisCount(
            mainAxisCount: 3)));
    await tester.pump();

    expect(tester.getSize(find.byKey(const ValueKey(0))).width, 75);
    expect(tester.getSize(find.byKey(const ValueKey(1))).width, 150);
    expect(tester.getSize(find.byKey(const ValueKey(2))).width, 75);
  });

  testWidgets('selected item is not forced wider than its content needs',
      (tester) async {
    await tester.pumpWidget(buildTestList(
        itemCount: 3,
        width: 300,
        selectedIndex: 1,
        preferredMainAxisExtents: const {1: 60},
        delegate: const PaginatedReorderableListDelegateWithFixedMainAxisCount(
            mainAxisCount: 3)));
    await tester.pump();

    expect(tester.getSize(find.byKey(const ValueKey(0))).width, 100);
    expect(tester.getSize(find.byKey(const ValueKey(1))).width, 100);
    expect(tester.getSize(find.byKey(const ValueKey(2))).width, 100);
  });

  testWidgets('selected item on a partial last page preserves page alignment',
      (tester) async {
    final key = GlobalKey<PaginatedReorderableListState>();
    await tester.pumpWidget(buildTestList(
        listKey: key,
        itemCount: 5,
        width: 300,
        selectedIndex: 4,
        preferredMainAxisExtents: const {4: 120},
        delegate: const PaginatedReorderableListDelegateWithFixedMainAxisCount(
            mainAxisCount: 3)));
    await tester.pump();

    expect(key.currentState!.controller.position.maxScrollExtent, 300);
    key.currentState!.jumpToPage(1);
    await tester.pump();

    final listLeft =
        tester.getTopLeft(find.byType(PaginatedReorderableList)).dx;
    expect(tester.getTopLeft(find.byKey(const ValueKey(3))).dx, listLeft);
    expect(tester.getSize(find.byKey(const ValueKey(3))).width, 90);
    expect(tester.getSize(find.byKey(const ValueKey(4))).width, 120);
  });

  testWidgets('changing selection redistributes space without moving pages',
      (tester) async {
    final key = GlobalKey<PaginatedReorderableListState>();
    late StateSetter setState;
    int selectedIndex = 0;
    await tester.pumpWidget(StatefulBuilder(builder: (context, setter) {
      setState = setter;
      return buildTestList(
          listKey: key,
          itemCount: 6,
          width: 300,
          selectedIndex: selectedIndex,
          preferredMainAxisExtents: const {0: 130, 4: 120},
          delegate:
              const PaginatedReorderableListDelegateWithFixedMainAxisCount(
                  mainAxisCount: 3));
    }));
    await tester.pump();
    key.currentState!.jumpToPage(1);
    await tester.pump();

    setState(() => selectedIndex = 4);
    await tester.pump();

    expect(key.currentState!.controller.page, 1);
    expect(key.currentState!.controller.position.maxScrollExtent, 300);
    expect(tester.getSize(find.byKey(const ValueKey(3))).width, 100);
    expect(tester.getSize(find.byKey(const ValueKey(4))).width, 100);
    expect(tester.getSize(find.byKey(const ValueKey(5))).width, 100);

    await tester.pump(const Duration(milliseconds: 175));
    final middleSelectedWidth =
        tester.getSize(find.byKey(const ValueKey(4))).width;
    expect(middleSelectedWidth, greaterThan(100));
    expect(middleSelectedWidth, lessThan(120));
    expect(
        tester.getSize(find.byKey(const ValueKey(3))).width * 2 +
            middleSelectedWidth,
        closeTo(300, 0.001));

    await tester.pump(const Duration(milliseconds: 175));
    expect(tester.getSize(find.byKey(const ValueKey(3))).width, 90);
    expect(tester.getSize(find.byKey(const ValueKey(4))).width, 120);
    expect(tester.getSize(find.byKey(const ValueKey(5))).width, 90);
  });

  testWidgets('initial selection commits without animating',
      (tester) async {
    late StateSetter setState;
    int? selectedIndex;
    await tester.pumpWidget(StatefulBuilder(builder: (context, setter) {
      setState = setter;
      return buildTestList(
          itemCount: 3,
          width: 300,
          selectedIndex: selectedIndex,
          preferredMainAxisExtents: const {1: 120},
          delegate:
              const PaginatedReorderableListDelegateWithFixedMainAxisCount(
                  mainAxisCount: 3));
    }));
    await tester.pump();

    expect(tester.getSize(find.byKey(const ValueKey(1))).width, 100);

    setState(() => selectedIndex = 1);
    await tester.pump();

    expect(tester.getSize(find.byKey(const ValueKey(1))).width, 120);
  });

  testWidgets('selection animation measures each preferred extent only once',
      (tester) async {
    late StateSetter setState;
    var selectedIndex = 0;
    final layouts = <int, List<BoxConstraints>>{};
    await tester.pumpWidget(StatefulBuilder(builder: (context, setter) {
      setState = setter;
      return buildTestList(
          itemCount: 3,
          width: 300,
          selectedIndex: selectedIndex,
          preferredMainAxisExtents: const {0: 130, 1: 120},
          onItemLayout: (index, constraints) =>
              layouts.putIfAbsent(index, () => []).add(constraints),
          delegate:
              const PaginatedReorderableListDelegateWithFixedMainAxisCount(
                  mainAxisCount: 3));
    }));
    await tester.pump();
    layouts.clear();

    setState(() => selectedIndex = 1);
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 35));
    }

    final looseLayouts = layouts.values
        .expand((constraints) => constraints)
        .where((constraints) => !constraints.hasTightWidth)
        .length;
    expect(looseLayouts, 2,
        reason: 'The old and new preferred widths should each be captured '
            'once, not measured again on every animation tick.');
  });

  testWidgets('selected preferred extent is remeasured when content changes',
      (tester) async {
    late StateSetter setState;
    var preferredExtent = 120.0;
    await tester.pumpWidget(StatefulBuilder(builder: (context, setter) {
      setState = setter;
      return buildTestList(
          itemCount: 3,
          width: 300,
          selectedIndex: 1,
          preferredMainAxisExtents: {1: preferredExtent},
          delegate:
              const PaginatedReorderableListDelegateWithFixedMainAxisCount(
                  mainAxisCount: 3));
    }));
    await tester.pump();
    expect(tester.getSize(find.byKey(const ValueKey(1))).width, 120);

    setState(() => preferredExtent = 140);
    await tester.pump();

    expect(tester.getSize(find.byKey(const ValueKey(0))).width, 80);
    expect(tester.getSize(find.byKey(const ValueKey(1))).width, 140);
    expect(tester.getSize(find.byKey(const ValueKey(2))).width, 80);
  });

  testWidgets('deleting the only item on the last page selects the prior page',
      (tester) async {
    final key = GlobalKey<PaginatedReorderableListState>();
    late StateSetter setState;
    int itemCount = 5;
    final changedPages = <int>[];

    await tester.pumpWidget(StatefulBuilder(builder: (context, setter) {
      setState = setter;
      return buildTestList(
          listKey: key,
          itemCount: itemCount,
          width: 400,
          gutterExtent: 0.5,
          onPageChanged: changedPages.add,
          delegate:
              const PaginatedReorderableListDelegateWithFixedMainAxisCount(
                  mainAxisCount: 2));
    }));
    await tester.pump();
    key.currentState!.jumpToPage(2);
    await tester.pump();
    expect(key.currentState!.page, 2);

    setState(() => itemCount = 4);
    await tester.pump();
    await tester.pump();

    expect(key.currentState!.pageCount, 2);
    expect(key.currentState!.page, 1);
    expect(key.currentState!.controller.page, 1);
    expect(changedPages, containsAllInOrder([2, 1]));
  });

  testWidgets('deleting every item safely returns to page zero',
      (tester) async {
    final key = GlobalKey<PaginatedReorderableListState>();
    late StateSetter setState;
    int itemCount = 5;

    await tester.pumpWidget(StatefulBuilder(builder: (context, setter) {
      setState = setter;
      return buildTestList(
          listKey: key,
          itemCount: itemCount,
          delegate:
              const PaginatedReorderableListDelegateWithFixedMainAxisCount(
                  mainAxisCount: 2));
    }));
    await tester.pump();
    key.currentState!.jumpToPage(2);
    await tester.pump();

    setState(() => itemCount = 0);
    await tester.pump();
    await tester.pump();

    expect(key.currentState!.pageCount, 0);
    expect(key.currentState!.page, 0);
    expect(key.currentState!.controller.page, 0);
  });

  testWidgets('max extent delegate adapts item count to the viewport',
      (tester) async {
    final key = GlobalKey<PaginatedReorderableListState>();
    await tester.pumpWidget(buildTestList(
        listKey: key,
        itemCount: 6,
        width: 500,
        delegate: const PaginatedReorderableListDelegateWithMaxMainAxisExtent(
            maxMainAxisExtent: 200)));
    await tester.pump();

    expect(key.currentState!.itemsPerPage, 3);
    expect(key.currentState!.pageCount, 2);
    expect(tester.getSize(find.byKey(const ValueKey(0))).width,
        closeTo(500 / 3, 0.001));
  });

  testWidgets('vertical pagination uses the available height', (tester) async {
    final key = GlobalKey<PaginatedReorderableListState>();
    await tester.pumpWidget(buildTestList(
        listKey: key,
        itemCount: 6,
        height: 450,
        scrollDirection: Axis.vertical,
        delegate: const PaginatedReorderableListDelegateWithMaxMainAxisExtent(
            maxMainAxisExtent: 200)));
    await tester.pump();

    expect(key.currentState!.itemsPerPage, 3);
    expect(tester.getSize(find.byKey(const ValueKey(0))).height, 150);
  });

  testWidgets('vertical gutter reveals the next logical page', (tester) async {
    final key = GlobalKey<PaginatedReorderableListState>();
    await tester.pumpWidget(buildTestList(
        listKey: key,
        itemCount: 6,
        height: 450,
        gutterExtent: 0.5,
        scrollDirection: Axis.vertical,
        delegate: const PaginatedReorderableListDelegateWithMaxMainAxisExtent(
            maxMainAxisExtent: 200)));
    await tester.pump();

    final listTop = tester.getTopLeft(find.byType(PaginatedReorderableList)).dy;
    expect(key.currentState!.itemsPerPage, 3);
    expect(tester.getSize(find.byKey(const ValueKey(0))).height, 131.25);
    expect(tester.getTopLeft(find.byKey(const ValueKey(0))).dy, listTop);
    expect(
        tester.getTopLeft(find.byKey(const ValueKey(3))).dy, listTop + 393.75);
    key.currentState!.jumpToPage(1);
    await tester.pump();
    expect(key.currentState!.controller.offset, 337.5);
  });

  testWidgets('reorder callback uses global list indices', (tester) async {
    final reorders = <(int, int)>[];
    await tester.pumpWidget(buildTestList(
        itemCount: 4,
        onReorder: (oldIndex, newIndex) => reorders.add((oldIndex, newIndex)),
        delegate: const PaginatedReorderableListDelegateWithFixedMainAxisCount(
            mainAxisCount: 2)));
    await tester.pump();

    final drag = await tester
        .startGesture(tester.getCenter(find.byKey(const ValueKey(0))));
    await tester.pump(kPressTimeout);
    await drag.moveBy(const Offset(10, 0));
    await tester.pump();
    await drag.moveBy(const Offset(220, 0));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();

    expect(reorders, isNotEmpty);
    expect(reorders.single.$1, 0);
  });

  testWidgets('page snapping is suspended while an item is being reordered',
      (tester) async {
    final controller = PaginatedReorderableListController();
    await tester.pumpWidget(buildTestList(
        itemCount: 4,
        controller: controller,
        delayedDragStart: true,
        physics: const BouncingScrollPhysics(),
        delegate: const PaginatedReorderableListDelegateWithFixedMainAxisCount(
            mainAxisCount: 2)));
    await tester.pump();

    expect(controller.position.physics, isA<PageScrollPhysics>());

    final drag = await tester
        .startGesture(tester.getCenter(find.byKey(const ValueKey(0))));
    await tester.pump(kLongPressTimeout);
    await drag.moveBy(const Offset(10, 0));
    await tester.pump();

    expect(controller.position.physics, isNot(isA<PageScrollPhysics>()));

    await drag.up();
    await tester.pump();

    expect(controller.position.physics, isA<PageScrollPhysics>());
    await tester.pumpAndSettle();
  });

  testWidgets('dragging beyond the viewport auto-scrolls to the next page',
      (tester) async {
    final controller = PaginatedReorderableListController();
    final listKey = GlobalKey<PaginatedReorderableListState>();
    (int, int)? reorder;
    final itemKeys = <int, Key>{
      for (var i = 0; i < 12; i++) i: GlobalKey(debugLabel: 'item $i')
    };
    await tester.pumpWidget(buildTestList(
        listKey: listKey,
        itemCount: 12,
        controller: controller,
        onReorder: (oldIndex, newIndex) => reorder = (oldIndex, newIndex),
        delayedDragStart: true,
        height: 80,
        gutterExtent: 0.5,
        selectedIndex: 0,
        selectedItemExtentFactor: 2,
        itemKeys: itemKeys,
        tabGestures: true,
        physics: const _FasterSnappingPageScrollPhysics(),
        delegate: const PaginatedReorderableListDelegateWithMaxMainAxisExtent(
            maxMainAxisExtent: 120)));
    await tester.pump();

    final itemFinder = find.byKey(itemKeys[0]!);
    final itemCenter = tester.getCenter(itemFinder);
    final drag = await tester.startGesture(itemCenter);
    await tester.pump(kLongPressTimeout);
    await drag.moveBy(const Offset(10, 0));
    await tester.pump();
    final listRight = tester
        .getTopRight(find.byType(PaginatedReorderableList))
        .dx;
    await drag.moveTo(Offset(listRight + 50, itemCenter.dy));
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(controller.page, greaterThanOrEqualTo(1));

    final viewportPageAtDrop = controller.page!;
    await drag.up();
    await tester.pumpAndSettle();

    expect(reorder, isNotNull);
    final itemsPerPage = listKey.currentState!.itemsPerPage;
    final destinationIndex = reorder!.$2 > reorder!.$1
        ? reorder!.$2 - 1
        : reorder!.$2;
    final insertionPage = reorder!.$2 ~/ itemsPerPage;
    final destinationPage = destinationIndex ~/ itemsPerPage;
    final expectedPage =
        (viewportPageAtDrop - insertionPage).abs() <=
                (viewportPageAtDrop - destinationPage).abs()
            ? insertionPage
            : destinationPage;
    expect(controller.page, expectedPage);
  });

  testWidgets('vertical drag beyond the viewport auto-scrolls', (tester) async {
    final controller = PaginatedReorderableListController();
    await tester.pumpWidget(buildTestList(
        itemCount: 12,
        controller: controller,
        delayedDragStart: true,
        gutterExtent: 0.5,
        selectedIndex: 0,
        selectedItemExtentFactor: 1,
        physics: const _FasterSnappingPageScrollPhysics(),
        scrollDirection: Axis.vertical,
        width: 200,
        height: 400,
        delegate: const PaginatedReorderableListDelegateWithMaxMainAxisExtent(
            maxMainAxisExtent: 120)));
    await tester.pump();

    final itemFinder = find.byKey(const ValueKey(0));
    final itemCenter = tester.getCenter(itemFinder);
    final drag = await tester.startGesture(itemCenter);
    await tester.pump(kLongPressTimeout);
    await drag.moveBy(const Offset(0, 10));
    await tester.pump();
    final listBottom = tester
        .getBottomLeft(find.byType(PaginatedReorderableList))
        .dy;
    await drag.moveTo(Offset(itemCenter.dx, listBottom + 50));
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(controller.page, greaterThanOrEqualTo(1));

    await drag.up();
    await tester.pumpAndSettle();
  });

  testWidgets('adaptive layout keeps the first visible item in view',
      (tester) async {
    final key = GlobalKey<PaginatedReorderableListState>();
    late StateSetter setState;
    double width = 400;

    await tester.pumpWidget(StatefulBuilder(builder: (context, setter) {
      setState = setter;
      return buildTestList(
          listKey: key,
          itemCount: 8,
          width: width,
          delegate: const PaginatedReorderableListDelegateWithMaxMainAxisExtent(
              maxMainAxisExtent: 200));
    }));
    await tester.pump();
    key.currentState!.jumpToPage(2);
    await tester.pump();

    setState(() => width = 600);
    await tester.pump();
    await tester.pump();

    expect(key.currentState!.itemsPerPage, 3);
    expect(key.currentState!.page, 1);
    expect(key.currentState!.controller.page, 1);
  });

  testWidgets('edge counts fade in while swiping and omit exhausted ends',
      (tester) async {
    final key = GlobalKey<PaginatedReorderableListState>();
    await tester.pumpWidget(buildTestList(
        listKey: key,
        itemCount: 6,
        delayedDragStart: true,
        delegate: const PaginatedReorderableListDelegateWithFixedMainAxisCount(
            mainAxisCount: 2)));
    await tester.pump();

    const indicatorKey = ValueKey('PaginatedReorderableList.pageIndicator');
    expect(find.byKey(indicatorKey), findsOneWidget);
    expect(tester.widget<AnimatedOpacity>(find.byKey(indicatorKey)).opacity, 0);
    expect(find.byKey(const ValueKey('PaginatedReorderableList.leftIndicator')),
        findsNothing);
    final rightIndicator =
        find.byKey(const ValueKey('PaginatedReorderableList.rightIndicator'));
    expect(rightIndicator, findsOneWidget);
    expect(find.descendant(of: rightIndicator, matching: find.text('4')),
        findsOneWidget);
    expect(find.descendant(of: rightIndicator, matching: find.text('→')),
        findsOneWidget);
    final background = tester.widget<Container>(rightIndicator);
    final backgroundDecoration = background.decoration! as BoxDecoration;
    expect(backgroundDecoration.color, const Color(0x99000000));
    expect(backgroundDecoration.borderRadius, isNotNull);

    final swipe = await tester
        .startGesture(tester.getCenter(find.byType(PaginatedReorderableList)));
    await swipe.moveBy(const Offset(-10, 0));
    await tester.pump();
    await swipe.moveBy(const Offset(-220, 0));
    await tester.pump();

    expect(tester.widget<AnimatedOpacity>(find.byKey(indicatorKey)).opacity, 1);
    expect(key.currentState!.page, 1);
    final leftIndicator =
        find.byKey(const ValueKey('PaginatedReorderableList.leftIndicator'));
    expect(leftIndicator, findsOneWidget);
    expect(find.descendant(of: leftIndicator, matching: find.text('2')),
        findsOneWidget);
    expect(find.descendant(of: leftIndicator, matching: find.text('←')),
        findsOneWidget);
    expect(find.descendant(of: rightIndicator, matching: find.text('2')),
        findsOneWidget);

    await swipe.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.widget<AnimatedOpacity>(find.byKey(indicatorKey)).opacity, 0);

    key.currentState!.jumpToPage(2);
    await tester.pump();
    expect(leftIndicator, findsOneWidget);
    expect(find.descendant(of: leftIndicator, matching: find.text('4')),
        findsOneWidget);
    expect(rightIndicator, findsNothing);
  });

  testWidgets('page indicator is omitted when there is only one page',
      (tester) async {
    await tester.pumpWidget(buildTestList(
        itemCount: 2,
        delegate: const PaginatedReorderableListDelegateWithFixedMainAxisCount(
            mainAxisCount: 2)));
    await tester.pump();

    expect(find.byKey(const ValueKey('PaginatedReorderableList.pageIndicator')),
        findsNothing);
  });
}

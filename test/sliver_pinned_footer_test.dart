import 'package:chan/widgets/sliver_center.dart';
import 'package:chan/widgets/sliver_pinned_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
	testWidgets('short content keeps the footer directly below it', (tester) async {
		tester.view.physicalSize = const Size(400, 600);
		tester.view.devicePixelRatio = 1;
		addTearDown(tester.view.resetPhysicalSize);
		addTearDown(tester.view.resetDevicePixelRatio);

		await tester.pumpWidget(MaterialApp(home: Scaffold(body: CustomScrollView(slivers: [
			SliverCenter(
				minimumPadding: const EdgeInsets.only(top: 40, bottom: 20),
				child: SliverPinnedFooter(
					bottomPadding: 20,
					sliver: const SliverToBoxAdapter(child: SizedBox(key: Key('content'), height: 120)),
					footer: const SliverToBoxAdapter(child: SizedBox(key: Key('footer'), height: 60))
				)
			)
		]))));

		expect(tester.getTopLeft(find.byKey(const Key('footer'))).dy,
			tester.getBottomLeft(find.byKey(const Key('content'))).dy);
	});

	testWidgets('long content scrolls under a visible, tappable footer', (tester) async {
		tester.view.physicalSize = const Size(400, 600);
		tester.view.devicePixelRatio = 1;
		addTearDown(tester.view.resetPhysicalSize);
		addTearDown(tester.view.resetDevicePixelRatio);
		var taps = 0;
		var contentTaps = 0;

		await tester.pumpWidget(MaterialApp(home: Scaffold(body: CustomScrollView(slivers: [
			SliverCenter(
				minimumPadding: const EdgeInsets.only(top: 40, bottom: 20),
				child: SliverPinnedFooter(
					bottomPadding: 20,
					sliver: SliverToBoxAdapter(child: GestureDetector(
						onTap: () => contentTaps++,
						child: const SizedBox(key: Key('content'), height: 900)
					)),
					footer: SliverToBoxAdapter(child: SizedBox(
						key: const Key('footer'),
						height: 120,
						child: TextButton(onPressed: () => taps++, child: const Text('Submit'))
					))
				)
			)
		]))));

		expect(tester.getTopLeft(find.byKey(const Key('footer'))).dy, 460);
		await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
		await tester.pumpAndSettle();
		expect(tester.getTopLeft(find.byKey(const Key('footer'))).dy, 460);
		await tester.tap(find.text('Submit'));
		expect(taps, 1);
		expect(contentTaps, 0);
		await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
		await tester.pumpAndSettle();
		expect(tester.getBottomLeft(find.byKey(const Key('content'))).dy, 460);
		expect(tester.getTopLeft(find.byKey(const Key('footer'))).dy, 460);
	});
}

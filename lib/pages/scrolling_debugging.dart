import 'dart:math';

import 'package:chan/services/filtering.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';

class ScrollingDebuggingPage extends StatefulWidget {
	const ScrollingDebuggingPage({
		Key? key
	}) : super(key: key);
	@override
	createState() => _ScrollingDebuggingPage();
}

class FakeItem implements Filterable {
	@override
	final int id;
	const FakeItem(this.id);
	@override
	String? getFilterFieldText(String fieldName) => null;

  @override
  String get board => '';

  @override
  bool get hasFile => false;

  @override
  bool get isThread => false;

	@override
	List<int> get repliedToIds => [];

	@override
	Iterable<String> get md5s => [];
}

class _ScrollingDebuggingPage extends State<ScrollingDebuggingPage> {
	final controller = RefreshableListController<FakeItem>();
	int count = 30;
	bool showBox = false;
	List<FakeItem>? list;
	@override
	Widget build(BuildContext context) {
		return CupertinoPageScaffold(
			navigationBar: CupertinoNavigationBar(
				transitionBetweenRoutes: false,
				middle: const Text('Scrolling debugging'),
				trailing: Row(
					mainAxisSize: MainAxisSize.min,
					children: [
						CupertinoButton(
							child: const Icon(CupertinoIcons.cube_box),
							onPressed: () {
								setState(() {
									showBox = true;
								});
							}
						),
						CupertinoButton(
							child: const Icon(CupertinoIcons.arrow_down_to_line),
							onPressed: () {
								controller.animateTo((x) => x.id == 300, orElseLast: (x) => true);
							}
						)
					]
				)
			),
			child: Column(
				children: [
					Expanded(
						child: RefreshableList<FakeItem>(
							filterableAdapter: null,
							id: 'debuggingList',
							controller: controller,
							itemBuilder: (context, item) => ExpensiveWidget(id: item.id),
							initialList: list,
							listUpdater: () async {
								Future.delayed(const Duration(milliseconds: 400)).then((_) {
									setState(() {
										showBox = false;
									});
									Future.delayed(const Duration(milliseconds: 150)).then((_) {
										setState(() {});
									});
								});
								//await Future.delayed(const Duration(milliseconds: 150));
								list = List.generate(count++, (i) => FakeItem(i));
								return list;
							},
							footer: const SizedBox(
								height: 150,
								child: Center(
									child: Text('Footer here')
								)
							)
						)
					),
					Expander(
						height: 400,
						expanded: showBox,
						duration: const Duration(milliseconds: 200),
						child: Container(
							color: const Color.fromARGB(255, 173, 44, 216),
							alignment: Alignment.center,
							child: CupertinoButton(
								onPressed: controller.update,
								child: const Text('Update')
							)
						)
					)
				]
			)
		);
	}
}

class ExpensiveWidget extends StatelessWidget {
	final int id;
	const ExpensiveWidget({
		required this.id,
		Key? key
	}) : super(key: key);
	@override
	Widget build(BuildContext context) {
		int i = 0;
		while (i < 9999999) {
			break;
			//i++;
		}
		print('building $id');
		return SizedBox(
			height: 800 / pow(id + 1, 0.1),
			child: Center(
				child: Text(id.toString())
			)
		);
	}
}
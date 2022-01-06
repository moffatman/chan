import 'dart:math';

import 'package:chan/services/filtering.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ScrollingDebuggingPage extends StatefulWidget {
	const ScrollingDebuggingPage({
		Key? key
	}) : super(key: key);
	@override
	createState() => _ScrollingDebuggingPage();
}

class _FakeItem implements Filterable {
	@override
	final int id;
	const _FakeItem(this.id);
	@override
	String? getFilterFieldText(String fieldName) => null;

  @override
  String get board => '';

  @override
  bool get hasFile => false;

  @override
  bool get isThread => false;
}

class _ScrollingDebuggingPage extends State<ScrollingDebuggingPage> {
	final controller = RefreshableListController<_FakeItem>();
	@override
	Widget build(BuildContext context) {
		return CupertinoPageScaffold(
			navigationBar: CupertinoNavigationBar(
				middle: const Text('Scrolling debugging'),
				trailing: CupertinoButton(
					child: const Icon(Icons.vertical_align_bottom),
					onPressed: () {
						controller.animateTo((x) => x.id == 3000);
					}
				)
			),
			child: RefreshableList<_FakeItem>(
				id: 'debuggingList',
				controller: controller,
				itemBuilder: (context, item) => ExpensiveWidget(id: item.id),
				listUpdater: () async {
					return List.generate(100000, (i) => _FakeItem(i));
				}
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
			//break;
			i++;
		}
		print('building $id');
		return SizedBox(
			height: 800 / sqrt(id + 1),
			child: Center(
				child: Text(id.toString())
			)
		);
	}
}
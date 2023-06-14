import 'package:chan/util.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';

class TreeDebuggingPage extends StatefulWidget {
	const TreeDebuggingPage({
		super.key
	});

	@override
	createState() => _TreeDebuggingPageState();
}

class _DebuggingItem {
	final int id;
	final List<int> parentIds;
	const _DebuggingItem({
		required this.id,
		required this.parentIds
	});

	@override
	String toString() => '_DebuggingItem(id: $id, parentIds: $parentIds)';
}

class _TreeDebuggingPageState extends State<TreeDebuggingPage> {
	late final RefreshableListController<_DebuggingItem> controller;
	final List<_DebuggingItem> items = [];

	@override
	void initState() {
		super.initState();
		controller = RefreshableListController();
		items.add(const _DebuggingItem(id: 0, parentIds: []));
	}

	@override
	Widget build(BuildContext context) {
		return RefreshableList<_DebuggingItem>(
			controller: controller,
			itemBuilder: (context, item) => SizedBox(
				height: 50,
				width: double.infinity,
				child: Stack(
					alignment: Alignment.center,
					children: [
						Text('Item ${item.id}'),
						Positioned.fill(
							child: Align(
								alignment: Alignment.bottomLeft,
								child: CupertinoButton(
									onPressed: () {
										items.add(_DebuggingItem(
											id: items.last.id + 1,
											parentIds: [item.id]
										));
										setState(() {});
									},
									child: const Icon(CupertinoIcons.add)
								)
							)
						)
					]
				)
			),
			disableUpdates: true,
			listUpdater: () async => throw UnimplementedError(),
			id: 'treeDebugging',
			initialList: items.toList(),
			filterableAdapter: null,
			useTree: true,
			treeAdapter: RefreshableTreeAdapter(
				getId: (i) => i.id,
				getParentIds: (i) => i.parentIds,
				getHasOmittedReplies: (i) => false,
				updateWithStubItems: (_, __) async => throw UnimplementedError(),
				opId: 0,
				wrapTreeChild: (c, l) => c,
				estimateHeight: (i, w) => 50,
				getIsStub: (i) => false,
				initiallyCollapseSecondLevelReplies: false,
				collapsedItemsShowBody: false
			),
			footer: CupertinoButton(
				child: const Icon(CupertinoIcons.pencil),
				onPressed: () async {
					final list = <String>[];
					await editStringList(
						context: context,
						list: list,
						name: 'id',
						title: 'ID chain'
					);
					final ids = list.tryMap((v) => int.tryParse(v)).toList();
					if (ids.isNotEmpty) {
						items.add(_DebuggingItem(
							id: ids.last,
							parentIds: ids.sublist(0, list.length - 1)
						));
						setState(() {});
					}
				}
			)
		);
	}

	@override
	void dispose() {
		super.dispose();
		controller.dispose();
	}
}
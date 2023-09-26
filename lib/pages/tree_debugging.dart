import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
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
	final bool isStub;
	final bool hasUnknownStubChildren;

	const _DebuggingItem({
		required this.id,
		required this.parentIds,
		required this.isStub,
		required this.hasUnknownStubChildren
	});

	@override
	String toString() => '_DebuggingItem(id: $id, parentIds: $parentIds, isStub: $isStub, hasUnknownStubChildren: $hasUnknownStubChildren)';
}

class _TreeDebuggingPageState extends State<TreeDebuggingPage> {
	late final RefreshableListController<_DebuggingItem> controller;
	final List<_DebuggingItem> items = [];
	int _id = 0;

	@override
	void initState() {
		super.initState();
		controller = RefreshableListController();
		items.add(const _DebuggingItem(id: 0, parentIds: [], isStub: false, hasUnknownStubChildren: false));
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
						Text('Item ${item.id}${item.isStub ? ' [STUB]}' : ''}'),
						Positioned.fill(
							child: Align(
								alignment: Alignment.bottomLeft,
								child: Row(
									mainAxisSize: MainAxisSize.min,
									children: [
										CupertinoButton(
											onPressed: () {
												int idx = items.indexOf(item);
												if (idx == -1) {
													idx = items.length;
												}
												items.insert(idx, _DebuggingItem(
													id: _id++,
													parentIds: [item.id],
													isStub: false,
													hasUnknownStubChildren: false
												));
												setState(() {});
											},
											child: const Icon(CupertinoIcons.add)
										),
										CupertinoButton(
											onPressed: () {
												int idx = items.indexOf(item);
												if (idx == -1) {
													idx = items.length;
												}
												items.insert(idx, _DebuggingItem(
													id: _id++,
													parentIds: [item.id],
													isStub: true,
													hasUnknownStubChildren: false
												));
												setState(() {});
											},
											child: const Icon(CupertinoIcons.add_circled)
										),
										CupertinoButton(
											onPressed: () {
												final i = items.indexOf(item);
												items[i] = _DebuggingItem(
													id: item.id,
													parentIds: item.parentIds,
													isStub: false,
													hasUnknownStubChildren: !item.hasUnknownStubChildren
												);
												setState(() {});
											},
											child: const Icon(CupertinoIcons.asterisk_circle)
										)
									]
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
				getHasOmittedReplies: (i) => i.hasUnknownStubChildren,
				updateWithStubItems: (input, stubIds) async {
					final output = input.map((item) {
						if (stubIds.any((i) => i.childId == item.id)) {
							return _DebuggingItem(id: item.id, parentIds: item.parentIds, isStub: false, hasUnknownStubChildren: false);
						}
						return item;
					}).toList();
					if (stubIds.length == 1 && stubIds.single.childId == stubIds.single.parentId) {
						// Expanding unknownStubChildren
						output.add(_DebuggingItem(
							id: _id++,
							parentIds: [stubIds.single.childId],
							isStub: false,
							hasUnknownStubChildren: false
						));
					}
					items.clear();
					items.addAll(output);
					return output;
				},
				opId: 0,
				wrapTreeChild: (c, l) => c,
				estimateHeight: (i, w) => 50,
				getIsStub: (i) => i.isStub,
				initiallyCollapseSecondLevelReplies: false,
				collapsedItemsShowBody: false,
				repliesToOPAreTopLevel: true,
				newRepliesAreLinear: true
			),
			footer: Padding(
				padding: const EdgeInsets.all(16),
				child: Row(
					mainAxisAlignment: MainAxisAlignment.spaceEvenly,
					children: [
						AdaptiveIconButton(
							icon: const Icon(CupertinoIcons.pencil),
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
										parentIds: ids.sublist(0, ids.length - 1),
										isStub: list.last == 's',
										hasUnknownStubChildren: false
									));
									setState(() {});
								}
							}
						),
						AdaptiveIconButton(
							icon: const Icon(CupertinoIcons.tree),
							onPressed: controller.mergeTrees
						),
						AdaptiveIconButton(
							icon: const Icon(CupertinoIcons.shuffle),
							onPressed: () {
								items.shuffle();
								setState(() {});
							}
						)
					]
				)
			)
		);
	}

	@override
	void dispose() {
		super.dispose();
		controller.dispose();
	}
}
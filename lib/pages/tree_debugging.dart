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
	final bool isPageStub;
	final bool hasUnknownStubChildren;

	const _DebuggingItem({
		required this.id,
		required this.parentIds,
		required this.isStub,
		required this.isPageStub,
		required this.hasUnknownStubChildren
	});

	@override
	String toString() => '_DebuggingItem(id: $id, parentIds: $parentIds, isStub: $isStub, isPageStub: $isPageStub, hasUnknownStubChildren: $hasUnknownStubChildren)';
}

class _TreeDebuggingPageState extends State<TreeDebuggingPage> {
	late final RefreshableListController<_DebuggingItem> controller;
	final List<_DebuggingItem> items = [];
	int _id = 0;
	bool _useTree = true;

	@override
	void initState() {
		super.initState();
		controller = RefreshableListController();
		items.add(_DebuggingItem(id: _id++, parentIds: [], isStub: false, isPageStub: false, hasUnknownStubChildren: false));
	}

	@override
	Widget build(BuildContext context) {
		return RefreshableList<_DebuggingItem>(
			controller: controller,
			itemBuilder: (context, item) => SizedBox(
				width: double.infinity,
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						const SizedBox(height: 16),
						Text([
							'Item ${item.id}',
							if (item.isStub) '[STUB]',
							if (item.isPageStub) '[PAGE]',
							if (item.hasUnknownStubChildren) '[H_U_S_C]'
						].join(' ')),
						const SizedBox(height: 16),
						Wrap(
							spacing: 16,
							runSpacing: 16,
							children: [
								AdaptiveThinButton(
									onPressed: () {
										int idx = items.indexOf(item);
										if (idx == -1) {
											idx = items.length;
										}
										items.insert(idx, _DebuggingItem(
											id: _id++,
											parentIds: [item.id],
											isStub: false,
											isPageStub: false,
											hasUnknownStubChildren: false
										));
										setState(() {});
									},
									child: const Text('Add child')
								),
								AdaptiveThinButton(
									onPressed: () {
										int idx = items.indexOf(item);
										if (idx == -1) {
											idx = items.length;
										}
										items.insert(idx, _DebuggingItem(
											id: _id++,
											parentIds: [item.id],
											isStub: true,
											isPageStub: false,
											hasUnknownStubChildren: false
										));
										setState(() {});
									},
									child: const Text('Add stub child')
								),
								AdaptiveThinButton(
									onPressed: () {
										final i = items.indexOf(item);
										items[i] = _DebuggingItem(
											id: item.id,
											parentIds: item.parentIds,
											isStub: false,
											isPageStub: item.isPageStub,
											hasUnknownStubChildren: !item.hasUnknownStubChildren
										);
										setState(() {});
									},
									child: const Text('Toggle h_u_s_c')
								)
							]
						),
						const SizedBox(height: 16)
					]
				)
			),
			disableUpdates: true,
			listUpdater: () async => throw UnimplementedError(),
			id: 'treeDebugging',
			initialList: items.toList(),
			filterableAdapter: null,
			useTree: _useTree,
			treeAdapter: RefreshableTreeAdapter(
				getId: (i) => i.id,
				getParentIds: (i) => i.parentIds,
				getHasOmittedReplies: (i) => i.hasUnknownStubChildren,
				updateWithStubItems: (input, stubIds) async {
					final output = input.map((item) {
						if (stubIds.any((i) => i.childId == item.id)) {
							return _DebuggingItem(
								id: item.id,
								parentIds: item.parentIds,
								isStub: false,
								isPageStub: false,
								hasUnknownStubChildren: false
							);
						}
						return item;
					}).toList();
					if (stubIds.length == 1 && stubIds.single.childId == stubIds.single.parentId) {
						// Expanding unknownStubChildren
						output.add(_DebuggingItem(
							id: _id++,
							parentIds: [stubIds.single.childId],
							isStub: false,
							isPageStub: false,
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
				getIsPageStub: (i) => i.isPageStub,
				isPaged: false,
				initiallyCollapseSecondLevelReplies: false,
				collapsedItemsShowBody: false,
				repliesToOPAreTopLevel: true,
				newRepliesAreLinear: true
			),
			footer: Padding(
				padding: const EdgeInsets.all(16),
				child: Wrap(
					spacing: 16,
					runSpacing: 16,
					children: [
						AdaptiveThinButton(
							child: const Text('Insert...'),
							onPressed: () async {
								try {
									final list = <String>[];
									await editStringList(
										context: context,
										list: list,
										name: 'item',
										title: 'Items'
									);
									final newItems = list.map((str) {
										final list = str.split('/');
										final ids = list.tryMap((v) => int.tryParse(v)).toList();
										return _DebuggingItem(
											id: ids.last,
											parentIds: ids.sublist(0, ids.length - 1),
											isStub: list.last.contains('s'),
											isPageStub: list.last.contains('p'),
											hasUnknownStubChildren: list.last.contains('u')
										);
									}).toList();
									if (newItems.isNotEmpty) {
										items.addAll(newItems);
										setState(() {});
									}
								}
								catch (e, st) {
									Future.error(e, st);
									if (context.mounted) {
										alertError(context, e.toStringDio());
									}
								}
							}
						),
						AdaptiveThinButton(
							onPressed: controller.mergeTrees,
							child: const Text('Merge trees')
						),
						AdaptiveThinButton(
							child: const Text('Shuffle()'),
							onPressed: () {
								items.shuffle();
								setState(() {});
							}
						),
						AdaptiveThinButton(
							onPressed: () {
								setState(() {
									_useTree = !_useTree;
								});
							},
							child: _useTree ? const Text('->Linear') : const Text('->Tree')
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
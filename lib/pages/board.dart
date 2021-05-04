import 'dart:math';

import 'package:chan/models/board.dart';
import 'package:chan/pages/board_switcher.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:chan/widgets/thread_row.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';

import 'package:chan/models/thread.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chan/widgets/cupertino_page_route.dart';

class BoardPage extends StatefulWidget {
	final ImageboardBoard initialBoard;
	final bool allowChangingBoard;
	final ValueChanged<ThreadIdentifier>? onThreadSelected;
	final ThreadIdentifier? selectedThread;
	BoardPage({
		required this.initialBoard,
		this.allowChangingBoard = true,
		this.onThreadSelected,
		this.selectedThread
	});

	createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
	late ImageboardBoard board;

	@override
	void initState() {
		super.initState();
		board = widget.initialBoard;
	}

	@override
	void didUpdateWidget(BoardPage oldWidget) {
		super.didUpdateWidget(oldWidget);
		setState(() {});
	}

	@override
	Widget build(BuildContext context) {
		final site = context.watch<ImageboardSite>();
		final settings = context.watch<EffectiveSettings>();
		return CupertinoPageScaffold(
			navigationBar: CupertinoNavigationBar(
				transitionBetweenRoutes: false,
				middle: GestureDetector(
					onTap: widget.allowChangingBoard ? () async {
						final newBoard = await Navigator.of(context).push<ImageboardBoard>(TransparentRoute(builder: (ctx) => BoardSwitcherPage()));
						if (newBoard != null) {
							setState(() {
								board = newBoard;
							});
						}
					} : null,
					child: Row(
						mainAxisSize: MainAxisSize.min,
						children: [
							Text('/${board.name}/'),
							if (widget.allowChangingBoard) Icon(Icons.arrow_drop_down)
						]
					)
				),
				trailing: CupertinoButton(
					padding: EdgeInsets.zero,
					child: Transform(
						alignment: Alignment.center,
						transform: settings.reverseCatalogSorting ? Matrix4.rotationX(pi) : Matrix4.identity(),
						child: Icon(Icons.sort)
					),
					onPressed: () {
						showCupertinoModalPopup<DateTime>(
							context: context,
							builder: (context) => CupertinoActionSheet(
								title: const Text('Sort by...'),
								actions: {
									ThreadSortingMethod.Unsorted: 'Bump Order',
									ThreadSortingMethod.ReplyCount: 'Reply Count',
									ThreadSortingMethod.OPTime: 'Creation Date'
								}.entries.map((entry) => CupertinoActionSheetAction(
									child: Text(entry.value, style: TextStyle(
										fontWeight: entry.key == settings.catalogSortingMethod ? FontWeight.bold : null
									)),
									onPressed: () {
										if (settings.catalogSortingMethod == entry.key) {
											settings.reverseCatalogSorting = !settings.reverseCatalogSorting;
										}
										else {
											settings.reverseCatalogSorting = false;
											settings.catalogSortingMethod = entry.key;
										}
										Navigator.of(context, rootNavigator: true).pop();
									}
								)).toList(),
								cancelButton: CupertinoActionSheetAction(
									child: const Text('Cancel'),
									onPressed: () => Navigator.of(context, rootNavigator: true).pop()
								)
							)
						);
					}
				)
			),
			child: RefreshableList<Thread>(
				listUpdater: () => site.getCatalog(board.name).then((list) {
					if (settings.hideStickiedThreads) {
						list = list.where((thread) => !thread.isSticky).toList();
					}
					if (settings.catalogSortingMethod == ThreadSortingMethod.ReplyCount) {
						list.sort((a, b) => b.replyCount.compareTo(a.replyCount));
					}
					else if (settings.catalogSortingMethod == ThreadSortingMethod.OPTime) {
						list.sort((a, b) => b.id.compareTo(a.id));
					}
					return settings.reverseCatalogSorting ? list.reversed.toList() : list;
				}),
				id: '/${board.name}/ ${settings.catalogSortingMethod} ${settings.reverseCatalogSorting}',
				itemBuilder: (context, thread) {
					return GestureDetector(
						behavior: HitTestBehavior.opaque,
						child: ThreadRow(
							thread: thread,
							isSelected: thread.identifier == widget.selectedThread
						),
						onTap: () {
							if (widget.onThreadSelected != null) {
								widget.onThreadSelected!(thread.identifier);
							}
							else {
								Navigator.of(context).push(FullWidthCupertinoPageRoute(builder: (ctx) => ThreadPage(thread: thread.identifier)));
							}
						}
					);
				},
				filterHint: 'Search in board'
			)
		);
	}
}
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
import 'package:cupertino_back_gesture/src/cupertino_page_route.dart' as cpr;

enum BoardSortMethod {
	BumpOrder,
	ReplyCount,
	CreationDate
}

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
	BoardSortMethod sorting = BoardSortMethod.BumpOrder;
	bool descending = true;

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
						transform: descending ? Matrix4.identity() : Matrix4.rotationX(pi),
						child: Icon(Icons.sort)
					),
					onPressed: () {
						showCupertinoModalPopup<DateTime>(
							context: context,
							builder: (context) => CupertinoActionSheet(
								title: const Text('Sort by...'),
								actions: {
									BoardSortMethod.BumpOrder: 'Bump Order',
									BoardSortMethod.ReplyCount: 'Reply Count',
									BoardSortMethod.CreationDate: 'Creation Date'
								}.entries.map((entry) => CupertinoActionSheetAction(
									child: Text(entry.value),
									onPressed: () {
										if (sorting == entry.key) {
											setState(() {
												descending = !descending;
											});
										}
										else {
											setState(() {
												sorting = entry.key;
											});
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
					if (context.read<EffectiveSettings>().hideStickiedThreads) {
						list = list.where((thread) => !thread.isSticky).toList();
					}
					if (sorting == BoardSortMethod.ReplyCount) {
						list.sort((a, b) => b.replyCount.compareTo(a.replyCount));
					}
					else if (sorting == BoardSortMethod.CreationDate) {
						list.sort((a, b) => b.id.compareTo(a.id));
					}
					return descending ? list : list.reversed.toList();
				}),
				id: '/${board.name}/ $sorting $descending',
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
								Navigator.of(context).push(cpr.CupertinoPageRoute(builder: (ctx) => ThreadPage(thread: thread.identifier)));
							}
						}
					);
				},
				filterHint: 'Search in board'
			)
		);
	}
}
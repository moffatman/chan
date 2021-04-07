import 'dart:math';

import 'package:chan/models/board.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:chan/widgets/thread_row.dart';
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
	final ValueChanged<Thread>? onThreadSelected;
	final Thread? selectedThread;
	final ImageboardBoard board;
	final VoidCallback? onHeaderTapped;
	BoardPage({
		this.onThreadSelected,
		this.selectedThread,
		required this.board,
		this.onHeaderTapped
	});

	createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
	BoardSortMethod sorting = BoardSortMethod.BumpOrder;
	bool descending = true;

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
					onTap: widget.onHeaderTapped,
					child: Row(
						mainAxisSize: MainAxisSize.min,
						children: [
							Text('/${widget.board.name}/'),
							if (widget.onHeaderTapped != null) Icon(Icons.arrow_drop_down)
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
				listUpdater: () => site.getCatalog(widget.board.name).then((list) {
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
				id: '/${widget.board.name}/ $sorting $descending',
				itemBuilder: (context, thread) {
					return GestureDetector(
						behavior: HitTestBehavior.opaque,
						child: ThreadRow(
							thread: thread,
							isSelected: thread == widget.selectedThread
						),
						onTap: () {
							if (widget.onThreadSelected != null) {
								widget.onThreadSelected!(thread);
							}
							else {
								Navigator.of(context).push(cpr.CupertinoPageRoute(builder: (ctx) => ThreadPage(board: widget.board, id: thread.id)));
							}
						}
					);
				},
				filterHint: 'Search in board'
			)
		);
	}
}
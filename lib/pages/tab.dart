import 'package:chan/models/thread.dart';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'package:chan/pages/thread.dart';

import 'package:chan/pages/board.dart';

class ImageboardTab extends StatefulWidget {
	final bool isInTabletLayout;
	final String initialBoard;
	const ImageboardTab({
		@required this.isInTabletLayout,
		@required this.initialBoard
	});
	@override
	_ImageboardTabState createState() => _ImageboardTabState();
}

class _ImageboardTabState extends State<ImageboardTab> {
	String board;
	Thread selectedThread;
	@override
	initState() {
		super.initState();
		setState(() {
			board = widget.initialBoard;
		});
	}

	@override
	Widget build(BuildContext context) {
		if (widget.isInTabletLayout) {
			return Row(
				children: [
					Flexible(
						flex: 1,
						child: BoardPage(
							board: board,
							selectedThread: selectedThread,
							onThreadSelected: (thread) {
								setState(() {
									selectedThread = thread;
								});
							},
						)
					),
					VerticalDivider(
						width: 0
					),
					Flexible(
						flex: 3,
						child: selectedThread != null ? ThreadPage(thread: selectedThread) : Center(child: Text('Select a thread'))
					)
				]
			);
		}
		else {
			return BoardPage(
				board: board,
				selectedThread: null,
				onThreadSelected: (thread) {
					Navigator.of(context).push(CupertinoPageRoute(builder: (ctx) => ThreadPage(thread: thread)));
				},
			);
		}
	}
}
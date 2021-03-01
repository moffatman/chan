import 'package:chan/models/thread.dart';
import 'package:chan/widgets/gallery_manager.dart';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cupertino_back_gesture/src/cupertino_page_route.dart' as cpr;

import 'board.dart';
import 'board_switcher.dart';
import 'thread.dart';

class ImageboardTab extends StatefulWidget {
	final bool isInTabletLayout;
	final String initialBoard;
	const ImageboardTab({
		required this.isInTabletLayout,
		required this.initialBoard
	});
	@override
	_ImageboardTabState createState() => _ImageboardTabState();
}

class _ImageboardTabState extends State<ImageboardTab> {
	late String board;
	Thread? selectedThread;
	GlobalKey<NavigatorState> _rightPaneNavigatorKey = GlobalKey<NavigatorState>();
	@override
	initState() {
		super.initState();
		board = widget.initialBoard;
	}

	@override
	Widget build(BuildContext context) {
		if (widget.isInTabletLayout) {
			return Row(
				children: [
					Flexible(
						flex: 1,
						child: Navigator(
							initialRoute: '/',
							onGenerateRoute: (RouteSettings settings) {
								return TransparentRoute(
									builder: (context) {
										return BoardPage(
											board: board,
											selectedThread: selectedThread,
											onThreadSelected: (thread) {
												setState(() {
													selectedThread = thread;
												});
												_rightPaneNavigatorKey.currentState!.popUntil((route) => route.isFirst);
											},
											onHeaderTapped: () async {
												final newBoard = await Navigator.of(context).push<String>(TransparentRoute(builder: (ctx) => BoardSwitcherPage()));
												if (newBoard != null) {
													setState(() {
														board = newBoard;
													});
												}
											}
										);
									}
								);
							}
						)
					),
					VerticalDivider(
						width: 0
					),
					Flexible(
						flex: 3,
						child: Navigator(
							key: _rightPaneNavigatorKey,
							initialRoute: '/',
							onGenerateRoute: (RouteSettings settings) {
								return cpr.CupertinoPageRoute(
									builder: (context) {
										return selectedThread != null ? ThreadPage(board: selectedThread!.board, id: selectedThread!.id) : Center(child: Text('Select a thread'));
									},
									settings: settings
								);
							}
						)
					)
				]
			);
		}
		else {
			return BoardPage(
				board: board,
				onThreadSelected: (thread) {
					Navigator.of(context).push(cpr.CupertinoPageRoute(builder: (ctx) => ThreadPage(board: thread.board, id: thread.id)));
				},
				onHeaderTapped: () async {
					final newBoard = await Navigator.of(context).push<String>(TransparentRoute(builder: (ctx) => BoardSwitcherPage()));
					if (newBoard != null) {
						setState(() {
							board = newBoard;
						});
					}
				},
			);
		}
	}
}
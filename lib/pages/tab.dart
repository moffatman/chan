import 'package:chan/models/thread.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/util.dart';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cupertino_back_gesture/src/cupertino_page_route.dart' as cpr;
import 'package:provider/provider.dart';

import 'board.dart';
import 'board_switcher.dart';
import 'thread.dart';

class ImageboardTab extends StatefulWidget {
	final bool isInTabletLayout;
	final String initialBoardName;
	const ImageboardTab({
		required this.isInTabletLayout,
		required this.initialBoardName
	});
	@override
	_ImageboardTabState createState() => _ImageboardTabState();
}

GlobalKey<NavigatorState> rightPaneNavigatorKey = GlobalKey<NavigatorState>();

class _ImageboardTabState extends State<ImageboardTab> {
	ImageboardBoard? board;
	Thread? selectedThread;
	@override
	initState() {
		super.initState();
		context.read<ImageboardSite>().getBoards().then((list) {
			final matches =list.where((b) => b.name == widget.initialBoardName);
			if (matches.isNotEmpty) {
				setState(() {
					this.board = matches.first;
				});
			}
		});
	}

	@override
	Widget build(BuildContext context) {
		if (board == null) {
			return Center(
				child: CircularProgressIndicator()
			);
		}
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
											board: board!,
											selectedThread: selectedThread,
											onThreadSelected: (thread) {
												setState(() {
													selectedThread = thread;
												});
												rightPaneNavigatorKey.currentState!.popUntil((route) => route.isFirst);
											},
											onHeaderTapped: () async {
												final newBoard = await Navigator.of(context).push<ImageboardBoard>(TransparentRoute(builder: (ctx) => BoardSwitcherPage()));
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
						width: 0,
						color: CupertinoTheme.of(context).primaryColor.withOpacity(0.1)
					),
					Flexible(
						flex: 3,
						child: Navigator(
							key: rightPaneNavigatorKey,
							initialRoute: '/',
							onGenerateRoute: (RouteSettings settings) {
								return cpr.CupertinoPageRoute(
									builder: (context) {
										return selectedThread != null ? ThreadPage(board: board!, id: selectedThread!.id) : Container(
											decoration: BoxDecoration(
												color: CupertinoTheme.of(context).scaffoldBackgroundColor,
											),
											child: Center(
												child: Text('Select a thread')
											)
										);
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
				board: board!,
				onThreadSelected: (thread) {
					Navigator.of(context).push(cpr.CupertinoPageRoute(builder: (ctx) => ThreadPage(board: board!, id: thread.id)));
				},
				onHeaderTapped: () async {
					final newBoard = await Navigator.of(context).push<ImageboardBoard>(TransparentRoute(builder: (ctx) => BoardSwitcherPage()));
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
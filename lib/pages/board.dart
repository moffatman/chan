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


class BoardPage extends StatelessWidget {
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

	@override
	Widget build(BuildContext context) {
		final site = context.watch<ImageboardSite>();
		return CupertinoPageScaffold(
			navigationBar: CupertinoNavigationBar(
				middle: GestureDetector(
					onTap: onHeaderTapped,
					child: Row(
						mainAxisSize: MainAxisSize.min,
						children: [
							Text('/${board.name}/'),
							if (onHeaderTapped != null) Icon(Icons.arrow_drop_down)
						]
					)
				)
			),
			child: RefreshableList<Thread>(
				listUpdater: () => site.getCatalog(board.name).then((list) {
					if (context.read<EffectiveSettings>().hideStickiedThreads) {
						return list.where((thread) => !thread.isSticky).toList();
					}
					else {
						return list;
					}
				}),
				id: '/${board.name}/',
				lazy: true,
				itemBuilder: (context, thread) {
					return GestureDetector(
						behavior: HitTestBehavior.opaque,
						child: ThreadRow(
							thread: thread,
							isSelected: thread == selectedThread
						),
						onTap: () {
							if (onThreadSelected != null) {
								onThreadSelected!(thread);
							}
							else {
								Navigator.of(context).push(cpr.CupertinoPageRoute(builder: (ctx) => ThreadPage(board: board, id: thread.id)));
							}
						}
					);
				},
				filterHint: 'Search in board'
			)
		);
	}
}
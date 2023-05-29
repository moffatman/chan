import 'package:chan/models/thread.dart';
import 'package:chan/pages/board.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/persistence.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class ImageboardTab extends StatelessWidget {
	final PersistentBrowserTab tab;
	final void Function(String, String, String)? onWantArchiveSearch;
	final int id;
	const ImageboardTab({
		required this.tab,
		this.onWantArchiveSearch,
		this.id = -1,
		required Key key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return MasterDetailPage<ThreadIdentifier>(
			id: 'tab_$key',
			initialValue: tab.thread,
			onValueChanged: (thread) {
				tab.thread = thread;
				if (thread != null) {
					// ensure state created before didUpdate
					context.read<Persistence>().getThreadState(thread);
				}
				Future.delayed(const Duration(seconds: 1), Persistence.didUpdateTabs);
				tab.didUpdate();
			},
			masterBuilder: (context, selectedThread, threadSetter) {
				return BoardPage(
					key: tab.boardKey,
					tab: tab,
					initialBoard: tab.board,
					isThreadSelected: selectedThread,
					onThreadSelected: threadSetter,
					onBoardChanged: (board) {
						tab.board = board.item;
						final didChangeSite = tab.imageboardKey != board.imageboard.key;
						tab.imageboardKey = board.imageboard.key;
						tab.initialSearch = null;
						if (didChangeSite) {
							threadSetter(null);
						}
						else {
							Future.delayed(const Duration(seconds: 1), Persistence.didUpdateTabs);
							tab.didUpdate();
						}
					},
					onWantArchiveSearch: onWantArchiveSearch,
					semanticId: id
				);
			},
			detailBuilder: (selectedThread, setter, poppedOut) {
				return BuiltDetailPane(
					widget: selectedThread != null ? ThreadPage(
						thread: selectedThread,
						onWantChangeThread: setter,
						boardSemanticId: id
					) : Builder(
						builder: (context) => Container(
							decoration: BoxDecoration(
								color: CupertinoTheme.of(context).scaffoldBackgroundColor,
							),
							child: const Center(
								child: Text('Select a thread')
							)
						)
					),
					pageRouteBuilder: fullWidthCupertinoPageRouteBuilder
				);
			}
		);
	}
}
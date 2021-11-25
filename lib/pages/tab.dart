import 'package:chan/models/board.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/board.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/persistence.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class ImageboardTab extends StatelessWidget {
	final String initialBoardName;
	final ValueChanged<ImageboardBoard>? onBoardChanged;
	ImageboardTab({
		required this.initialBoardName,
		this.onBoardChanged
	});

	@override
	Widget build(BuildContext context) {
		ImageboardBoard board = context.watch<Persistence>().boardBox.values.first;
		try {
			board = context.watch<Persistence>().getBoard(initialBoardName);
		}
		catch (e) {
			
		}
		return MasterDetailPage<ThreadIdentifier>(
			id: 'tab',
			masterBuilder: (context, selectedThread, threadSetter) {
				return BoardPage(
					initialBoard: board,
					selectedThread: selectedThread,
					onThreadSelected: threadSetter,
					onBoardChanged: onBoardChanged,
				);
			},
			detailBuilder: (selectedThread, poppedOut) {
				return BuiltDetailPane(
					widget: selectedThread != null ? ThreadPage(thread: selectedThread) : Builder(
						builder: (context) => Container(
							decoration: BoxDecoration(
								color: CupertinoTheme.of(context).scaffoldBackgroundColor,
							),
							child: Center(
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
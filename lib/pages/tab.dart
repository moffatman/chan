import 'package:chan/models/thread.dart';
import 'package:chan/pages/board.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/persistence.dart';
import 'package:flutter/cupertino.dart';

class ImageboardTab extends StatelessWidget {
	final String initialBoardName;
	ImageboardTab({
		required this.initialBoardName
	});

	@override
	Widget build(BuildContext context) {
		return MasterDetailPage<ThreadIdentifier>(
			masterBuilder: (context, selectedThread, threadSetter) {
				return BoardPage(
					initialBoard: Persistence.getBoard(initialBoardName),
					selectedThread: selectedThread,
					onThreadSelected: threadSetter
				);
			},
			detailBuilder: (context, selectedThread) {
				return selectedThread != null ? ThreadPage(thread: selectedThread) : Container(
					decoration: BoxDecoration(
						color: CupertinoTheme.of(context).scaffoldBackgroundColor,
					),
					child: Center(
						child: Text('Select a thread')
					)
				);
			}
		);
	}
}
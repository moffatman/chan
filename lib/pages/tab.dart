import 'package:chan/models/board.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/board.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/thread.dart';
import 'package:flutter/cupertino.dart';

class ImageboardTab extends StatelessWidget {
	final ImageboardBoard? initialBoard;
	final ValueChanged<ImageboardBoard>? onBoardChanged;
	final ThreadIdentifier? initialThread;
	final ValueChanged<ThreadIdentifier?>? onThreadChanged;
	final String initialThreadDraftText;
	final ValueChanged<String>? onThreadDraftTextChanged;
	final String initialThreadDraftSubject;
	final ValueChanged<String>? onThreadDraftSubjectChanged;
	final int id;
	const ImageboardTab({
		required this.initialBoard,
		this.onBoardChanged,
		this.initialThread,
		this.onThreadChanged,
		this.initialThreadDraftText = '',
		this.onThreadDraftTextChanged,
		this.initialThreadDraftSubject = '',
		this.onThreadDraftSubjectChanged,
		this.id = -1,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return MasterDetailPage<ThreadIdentifier>(
			id: 'tab_$id',
			initialValue: initialThread,
			onValueChanged: onThreadChanged,
			masterBuilder: (context, selectedThread, threadSetter) {
				return BoardPage(
					initialBoard: initialBoard,
					selectedThread: selectedThread,
					onThreadSelected: threadSetter,
					onBoardChanged: onBoardChanged,
					initialDraftText: initialThreadDraftText,
					onDraftTextChanged: onThreadDraftTextChanged,
					initialDraftSubject: initialThreadDraftSubject,
					onDraftSubjectChanged: onThreadDraftSubjectChanged,
					semanticId: id
				);
			},
			detailBuilder: (selectedThread, poppedOut) {
				return BuiltDetailPane(
					widget: selectedThread != null ? ThreadPage(
						thread: selectedThread,
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
import 'package:chan/models/board.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/board.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/imageboard.dart';
import 'package:flutter/cupertino.dart';

class ImageboardTab extends StatelessWidget {
	final ImageboardBoard? initialBoard;
	final ValueChanged<ImageboardScoped<ImageboardBoard>>? onBoardChanged;
	final ThreadIdentifier? initialThread;
	final ValueChanged<ThreadIdentifier?>? onThreadChanged;
	final String Function()? getInitialThreadDraftText;
	final ValueChanged<String>? onThreadDraftTextChanged;
	final String Function()? getInitialThreadDraftSubject;
	final ValueChanged<String>? onThreadDraftSubjectChanged;
	final void Function(String, ThreadIdentifier)? onWantOpenThreadInNewTab;
	final String Function()? getInitialThreadDraftOptions;
	final ValueChanged<String>? onThreadDraftOptionsChanged;
	final String? Function()? getInitialThreadDraftFilePath;
	final ValueChanged<String?>? onThreadDraftFilePathChanged;
	final int id;
	final Key? boardKey;
	const ImageboardTab({
		required this.initialBoard,
		this.onBoardChanged,
		this.initialThread,
		this.onThreadChanged,
		this.getInitialThreadDraftText,
		this.onThreadDraftTextChanged,
		this.getInitialThreadDraftSubject,
		this.onThreadDraftSubjectChanged,
		this.onWantOpenThreadInNewTab,
		this.getInitialThreadDraftOptions,
		this.onThreadDraftOptionsChanged,
		this.getInitialThreadDraftFilePath,
		this.onThreadDraftFilePathChanged,
		this.id = -1,
		this.boardKey,
		required Key key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return MasterDetailPage<ThreadIdentifier>(
			id: 'tab_$key',
			initialValue: initialThread,
			onValueChanged: onThreadChanged,
			masterBuilder: (context, selectedThread, threadSetter) {
				return BoardPage(
					key: boardKey,
					initialBoard: initialBoard,
					selectedThread: selectedThread,
					onThreadSelected: threadSetter,
					onBoardChanged: onBoardChanged,
					getInitialDraftText: getInitialThreadDraftText,
					onDraftTextChanged: onThreadDraftTextChanged,
					getInitialDraftSubject: getInitialThreadDraftSubject,
					onDraftSubjectChanged: onThreadDraftSubjectChanged,
					onWantOpenThreadInNewTab: onWantOpenThreadInNewTab,
					getInitialThreadDraftOptions: getInitialThreadDraftOptions,
					onThreadDraftOptionsChanged: onThreadDraftOptionsChanged,
					getInitialThreadDraftFilePath: getInitialThreadDraftFilePath,
					onThreadDraftFilePathChanged: onThreadDraftFilePathChanged,
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
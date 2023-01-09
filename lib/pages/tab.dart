import 'package:chan/models/thread.dart';
import 'package:chan/pages/board.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class ImageboardTab extends StatelessWidget {
	final PersistentBrowserTab tab;
	final void Function(String, ThreadIdentifier, bool)? onWantOpenThreadInNewTab;
	final void Function(String, String, String)? onWantArchiveSearch;
	final int id;
	const ImageboardTab({
		required this.tab,
		this.onWantOpenThreadInNewTab,
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
					getInitialDraftText: () => tab.draftThread,
					onDraftTextChanged: (newText) {
						tab.draftThread = newText;
						runWhenIdle(const Duration(seconds: 3), Persistence.didUpdateTabs);
					},
					getInitialDraftSubject: () => tab.draftSubject,
					onDraftSubjectChanged: (newSubject) {
						tab.draftSubject = newSubject;
						runWhenIdle(const Duration(seconds: 3), Persistence.didUpdateTabs);
					},
					onWantOpenThreadInNewTab: onWantOpenThreadInNewTab,
					getInitialThreadDraftOptions: () => tab.draftOptions,
					onThreadDraftOptionsChanged: (newOptions) {
						tab.draftOptions = newOptions;
						runWhenIdle(const Duration(seconds: 3), Persistence.didUpdateTabs);
					},
					getInitialThreadDraftFilePath: () => tab.draftFilePath,
					onThreadDraftFilePathChanged: (newFilePath) {
						tab.draftFilePath = newFilePath;
						runWhenIdle(const Duration(seconds: 3), Persistence.didUpdateTabs);
					},
					initialSearch: tab.initialSearch,
					onSearchChanged: (newSearch) {
						tab.initialSearch = newSearch;
						runWhenIdle(const Duration(seconds: 3), Persistence.didUpdateTabs);
					},
					onWantArchiveSearch: onWantArchiveSearch,
					initialCatalogVariant: tab.catalogVariant,
					onCatalogVariantChanged: (newVariant) {
						tab.catalogVariant = newVariant;
						runWhenIdle(const Duration(seconds: 3), Persistence.didUpdateTabs);
					},
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
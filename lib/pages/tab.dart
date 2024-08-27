import 'package:chan/main.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/board.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/screen_size_hacks.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class ImageboardTab extends StatelessWidget {
	final PersistentBrowserTab tab;
	const ImageboardTab({
		required this.tab,
		required Key key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		final id = identityHashCode(tab);
		return AnimatedBuilder(
			animation: tab,
			builder: (context, child) {
				return MultiProvider(
					providers: [
						ChangeNotifierProvider.value(value: tab),
						Provider.value(
							value: OpenInNewTabZone(
								hashCode: identityHashCode(tab),
								onWantOpenThreadInNewTab: (imageboardKey, thread, {bool incognito = false, bool activate = true}) {
									context.read<ChanTabs>().addNewTab(
										withImageboardKey: imageboardKey,
										atPosition: Persistence.tabs.indexOf(tab) + 1,
										withBoard: thread.board,
										withThreadId: thread.id,
										activate: activate,
										incognito: incognito
									);
								}
							)
						)
					],
					child: tab.imageboardKey == null ? child : ImageboardScope(
						imageboardKey: tab.imageboardKey!,
						overridePersistence: tab.incognitoPersistence,
						loaderOffset: Settings.androidDrawerSetting.watch(context) ? Offset.zero : (isScreenWide(context) ? const Offset(-42.5, 0) : const Offset(0, 25)),
						child: child!
					)
				);
			},
			child: MasterDetailPage<ThreadIdentifier>(
				id: 'tab_$key',
				multiMasterDetailPageKey: tab.masterDetailKey,
				initialValue: tab.thread,
				onValueChanged: (thread) {
					tab.thread = thread;
					if (thread != null) {
						tab.threadForPullTab = null;
						// ensure state created before didUpdate
						tab.imageboard?.persistence.getThreadState(thread);
					}
					Future.delayed(const Duration(seconds: 1), Persistence.saveTabs);
					tab.didUpdate();
				},
				masterBuilder: (context, selectedThread, threadSetter) {
					final boardName = tab.board;
					return BoardPage(
						key: tab.boardKey,
						tab: tab,
						initialBoard: boardName == null ? null : tab.imageboard?.persistence.getBoard(boardName),
						isThreadSelected: selectedThread,
						onThreadSelected: threadSetter,
						onBoardChanged: (board) {
							tab.board = board.item.name;
							final didChangeSite = tab.imageboardKey != board.imageboard.key;
							tab.imageboardKey = board.imageboard.key;
							tab.initialSearch = null;
							if (didChangeSite) {
								threadSetter(null);
							}
							else {
								Future.delayed(const Duration(seconds: 1), Persistence.saveTabs);
								tab.didUpdate();
							}
						},
						onWantArchiveSearch: context.watch<ChanTabs>().searchArchives,
						semanticId: id
					);
				},
				detailBuilder: (selectedThread, setter, poppedOut) {
					return BuiltDetailPane(
						widget: selectedThread != null ? ThreadPage(
							thread: selectedThread,
							onWantChangeThread: setter,
							boardSemanticId: id
						) : const AdaptiveScaffold(
							body: Center(
								child: Text('Select a thread')
							)
						),
						pageRouteBuilder: fullWidthCupertinoPageRouteBuilder
					);
				}
			)
		);
	}
}
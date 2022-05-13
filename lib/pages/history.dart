import 'package:chan/models/thread.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/widgets/context_menu.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:chan/widgets/thread_row.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

class HistoryPage extends StatefulWidget {
	final bool isActive;
	final ValueChanged<ThreadIdentifier>? onWantOpenThreadInNewTab;

	const HistoryPage({
		required this.isActive,
		this.onWantOpenThreadInNewTab,
		Key? key
	}) : super(key: key);

	@override
	createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
	final _listController = RefreshableListController<PersistentThreadState>();

	@override
	Widget build(BuildContext context) {
		return MasterDetailPage<ThreadIdentifier>(
			id: 'history',
			masterBuilder: (context, selectedThread, threadSetter) {
				Widget innerMasterBuilder(BuildContext context, Box<PersistentThreadState> box, Widget? child) {
					final states = box.toMap().values.where((s) => s.thread != null).toList();
					states.sort((a, b) => b.lastOpenedTime.compareTo(a.lastOpenedTime));
					return RefreshableList<PersistentThreadState>(
						controller: _listController,
						listUpdater: () => throw UnimplementedError(),
						id: 'history',
						disableUpdates: true,
						initialList: states,
						itemBuilder: (context, state) => ContextMenu(
							maxHeight: 125,
							actions: [
								if (widget.onWantOpenThreadInNewTab != null) ContextMenuAction(
									child: const Text('Open in new tab'),
									trailingIcon: CupertinoIcons.rectangle_stack_badge_plus,
									onPressed: () {
										widget.onWantOpenThreadInNewTab?.call(state.identifier);
									}
								),
								ContextMenuAction(
									child: const Text('Remove'),
									onPressed: state.delete,
									trailingIcon: CupertinoIcons.xmark,
									isDestructiveAction: true
								)
							],
							child: GestureDetector(
								behavior: HitTestBehavior.opaque,
								child: ThreadRow(
									thread: state.thread!,
									isSelected: state.thread!.identifier == selectedThread,
									semanticParentIds: const [-3],
									showBoardName: true,
									onThumbnailTap: (initialAttachment) {
										final attachments = _listController.items.where((_) => _.thread?.attachment != null).map((_) => _.thread!.attachment!).toList();
										showGallery(
											context: context,
											attachments: attachments,
											replyCounts: {
												for (final item in _listController.items.where((_) => _.thread?.attachment != null)) item.thread!.attachment!: item.thread!.replyCount
											},
											initialAttachment: attachments.firstWhere((a) => a.id == initialAttachment.id),
											onChange: (attachment) {
												_listController.animateTo((p) => p.thread?.attachment?.id == attachment.id);
											},
											semanticParentIds: [-3]
										);
									}
								),
								onTap: () => threadSetter(state.thread!.identifier)
							)
						),
						filterHint: 'Search history'
					);
				}
				final persistence = context.watch<Persistence>();
				return CupertinoPageScaffold(
					resizeToAvoidBottomInset: false,
					navigationBar: CupertinoNavigationBar(
						transitionBetweenRoutes: false,
						middle: const Text('History'),
						trailing: CupertinoButton(
							padding: EdgeInsets.zero,
							child: Icon(persistence.browserState.enableHistory ? CupertinoIcons.stop : CupertinoIcons.play),
							onPressed: () {
								persistence.browserState.enableHistory = !persistence.browserState.enableHistory;
								context.read<Persistence>().didChangeBrowserHistoryStatus();
								threadSetter(selectedThread);
								showToast(
									context: context,
									message: persistence.browserState.enableHistory ? 'History resumed' : 'History stopped',
									icon: persistence.browserState.enableHistory ? CupertinoIcons.play : CupertinoIcons.stop
								);
							}
						)
					),
					child: widget.isActive ? ValueListenableBuilder(
						valueListenable: persistence.threadStateBox.listenable(),
						builder: innerMasterBuilder
					) : innerMasterBuilder(context, persistence.threadStateBox, null)
				);
			},
			detailBuilder: (selectedThread, poppedOut) {
				return BuiltDetailPane(
					widget: selectedThread != null ? ThreadPage(
						thread: selectedThread,
						boardSemanticId: -3
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
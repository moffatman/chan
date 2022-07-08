import 'package:chan/models/thread.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/widgets/context_menu.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:chan/widgets/thread_row.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HistoryPage extends StatefulWidget {
	final bool isActive;
	final void Function(String, ThreadIdentifier)? onWantOpenThreadInNewTab;

	const HistoryPage({
		required this.isActive,
		this.onWantOpenThreadInNewTab,
		Key? key
	}) : super(key: key);

	@override
	createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
	final _listController = RefreshableListController<ImageboardScoped<PersistentThreadState>>();

	@override
	Widget build(BuildContext context) {
		return MasterDetailPage<ImageboardScoped<ThreadIdentifier>>(
			id: 'history',
			masterBuilder: (context, selectedThread, threadSetter) {
				Widget innerMasterBuilder(BuildContext context, Widget? child) {
					final states = ImageboardRegistry.instance.imageboards.expand((i) => i.persistence.threadStateBox.toMap().values.map((s) => ImageboardScoped(
						imageboard: i,
						item: s
					))).where((i) => i.item.thread != null).toList();
					states.sort((a, b) => b.item.lastOpenedTime.compareTo(a.item.lastOpenedTime));
					return RefreshableList<ImageboardScoped<PersistentThreadState>>(
						filterableAdapter: (t) => t.item,
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
										widget.onWantOpenThreadInNewTab?.call(state.imageboard.key, state.item.identifier);
									}
								),
								ContextMenuAction(
									child: const Text('Remove'),
									onPressed: state.item.delete,
									trailingIcon: CupertinoIcons.xmark,
									isDestructiveAction: true
								)
							],
							child: GestureDetector(
								behavior: HitTestBehavior.opaque,
								child: ImageboardScope(
									imageboardKey: state.imageboard.key,
									child: ThreadRow(
										thread: state.item.thread!,
										isSelected: state.item.thread!.identifier == selectedThread?.item,
										semanticParentIds: const [-3],
										showSiteIcon: ImageboardRegistry.instance.count > 1,
										showBoardName: true,
										onThumbnailTap: (initialAttachment) {
											final attachments = _listController.items.where((_) => _.item.thread?.attachment != null).map((_) => _.item.thread!.attachment!).toList();
											showGallery(
												context: context,
												attachments: attachments,
												replyCounts: {
													for (final item in _listController.items.where((_) => _.item.thread?.attachment != null)) item.item.thread!.attachment!: item.item.thread!.replyCount
												},
												initialAttachment: attachments.firstWhere((a) => a.id == initialAttachment.id),
												onChange: (attachment) {
													_listController.animateTo((p) => p.item.thread?.attachment?.id == attachment.id);
												},
												semanticParentIds: [-3]
											);
										}
									)
								),
								onTap: () => threadSetter(ImageboardScoped(
									imageboard: state.imageboard,
									item: state.item.thread!.identifier
								))
							)
						),
						filterHint: 'Search history'
					);
				}
				final threadStateBoxesAnimation = Listenable.merge(ImageboardRegistry.instance.imageboards.map((i) => i.persistence.threadStateBox.listenable()).toList());
				return CupertinoPageScaffold(
					resizeToAvoidBottomInset: false,
					navigationBar: CupertinoNavigationBar(
						transitionBetweenRoutes: false,
						middle: const Text('History'),
						trailing: CupertinoButton(
							padding: EdgeInsets.zero,
							child: Icon(Persistence.enableHistory ? CupertinoIcons.stop : CupertinoIcons.play),
							onPressed: () {
								Persistence.enableHistory = !Persistence.enableHistory;
								Persistence.didChangeBrowserHistoryStatus();
								threadSetter(selectedThread);
								showToast(
									context: context,
									message: Persistence.enableHistory ? 'History resumed' : 'History stopped',
									icon: Persistence.enableHistory ? CupertinoIcons.play : CupertinoIcons.stop
								);
							}
						)
					),
					child: widget.isActive ? AnimatedBuilder(
						animation: threadStateBoxesAnimation,
						builder: innerMasterBuilder
					) : innerMasterBuilder(context, null)
				);
			},
			detailBuilder: (selectedThread, poppedOut) {
				return BuiltDetailPane(
					widget: selectedThread != null ? ImageboardScope(
						imageboardKey: selectedThread.imageboard.key,
						child: ThreadPage(
							thread: selectedThread.item,
							boardSemanticId: -3
						)
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
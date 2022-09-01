import 'dart:async';
import 'dart:math';

import 'package:chan/models/board.dart';
import 'package:chan/pages/board_switcher.dart';
import 'package:chan/pages/imageboard_switcher.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/notifications.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/context_menu.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:chan/widgets/reply_box.dart';
import 'package:chan/widgets/pull_tab.dart';
import 'package:chan/widgets/thread_row.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';

import 'package:chan/models/thread.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:chan/widgets/cupertino_page_route.dart';

import 'package:chan/pages/gallery.dart';

const _oldThreadThreshold = Duration(days: 7);

enum _ThreadSortingMethodScope {
	global,
	board,
	temporary
}

class BoardPage extends StatefulWidget {
	final int semanticId;
	final ImageboardBoard? initialBoard;
	final bool allowChangingBoard;
	final ValueChanged<ImageboardScoped<ImageboardBoard>>? onBoardChanged;
	final ValueChanged<ThreadIdentifier>? onThreadSelected;
	final ThreadIdentifier? selectedThread;
	final String? initialSearch;
	final String Function()? getInitialDraftText;
	final ValueChanged<String>? onDraftTextChanged;
	final String Function()? getInitialDraftSubject;
	final ValueChanged<String>? onDraftSubjectChanged;
	final void Function(String, ThreadIdentifier)? onWantOpenThreadInNewTab;
	final String Function()? getInitialThreadDraftOptions;
	final ValueChanged<String>? onThreadDraftOptionsChanged;
	final String? Function()? getInitialThreadDraftFilePath;
	final ValueChanged<String?>? onThreadDraftFilePathChanged;
	final void Function(String, String, String)? onWantArchiveSearch;
	const BoardPage({
		required this.initialBoard,
		this.allowChangingBoard = true,
		this.onBoardChanged,
		this.onThreadSelected,
		this.selectedThread,
		this.initialSearch,
		this.getInitialDraftText,
		this.onDraftTextChanged,
		this.getInitialDraftSubject,
		this.onDraftSubjectChanged,
		this.onWantOpenThreadInNewTab,
		this.getInitialThreadDraftOptions,
		this.onThreadDraftOptionsChanged,
		this.getInitialThreadDraftFilePath,
		this.onThreadDraftFilePathChanged,
		this.onWantArchiveSearch,
		required this.semanticId,
		Key? key
	}) : super(key: key);

	@override
	createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
	late ImageboardBoard? board;
	final _listController = RefreshableListController<Thread>();
	final _replyBoxKey = GlobalKey<ReplyBoxState>();
	Completer<void>? _loadCompleter;
	ThreadSortingMethod? _temporarySortingMethod;
	bool _temporaryReverseSorting = false;
	ThreadIdentifier? _lastSelectedThread;
	final _boardsPullTabKey = GlobalKey();
	final _threadPullTabKey = GlobalKey();

	@override
	void initState() {
		super.initState();
		board = widget.initialBoard;
		if (board == null) {
			Future.delayed(const Duration(milliseconds: 100), _selectBoard);
		}
		if (widget.selectedThread != null) {
			_lastSelectedThread = widget.selectedThread;
			_loadCompleter = Completer<void>()
				..future.then((_) async {
					try {
						await _listController.animateTo((t) => t.identifier == widget.selectedThread);
					}
					on StateError {
						// Ignore, the thread must not be in catalog
					}
					_loadCompleter = null;
				});
		}
		else if (context.findAncestorStateOfType<NavigatorState>()?.canPop() == false) {
			_lastSelectedThread = context.read<PersistentBrowserTab?>()?.thread;
		}
	}

	@override
	void didUpdateWidget(BoardPage oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (widget.selectedThread != null) {
			_lastSelectedThread = widget.selectedThread;
		}
	}

	void _selectBoard() async {
		final keys = <String, GlobalKey>{};
		final newBoard = await Navigator.of(context).push<ImageboardScoped<ImageboardBoard>>(TransparentRoute(
			builder: (ctx) => ImageboardSwitcherPage(
				initialImageboardKey: context.read<Imageboard?>()?.key,
				builder: (ctx, focusNode) => BoardSwitcherPage(
					key: keys.putIfAbsent(ctx.read<Imageboard?>()?.key ?? 'null', () => GlobalKey()),
					searchFocusNode: focusNode
				)
			),
			showAnimations: context.read<EffectiveSettings>().showAnimations
		));
		if (newBoard != null) {
			_swapBoard(newBoard);
		}
	}
	
	void _swapBoard(ImageboardScoped<ImageboardBoard> newBoard) {
		widget.onBoardChanged?.call(newBoard);
		setState(() {
			board = newBoard.item;
			_listController.scrollController?.jumpTo(0);
			_temporarySortingMethod = null;
			_temporaryReverseSorting = false;
		});
	}

	void _onThreadSelected(ThreadIdentifier identifier) {
		_lastSelectedThread = identifier;
		setState(() {});
		if (widget.onThreadSelected != null) {
			widget.onThreadSelected!(identifier);
		}
		else {
			Navigator.of(context).push(FullWidthCupertinoPageRoute(
				builder: (ctx) => ImageboardScope(
					imageboardKey: null,
					imageboard: context.read<Imageboard>(),
					child: ThreadPage(
						thread: identifier,
						boardSemanticId: widget.semanticId,
					)
				),
				showAnimations: context.read<EffectiveSettings>().showAnimations
			));
		}
	}

	@override
	Widget build(BuildContext context) {
		final imageboard = context.watch<Imageboard?>();
		final site = context.watch<ImageboardSite?>();
		final settings = context.watch<EffectiveSettings>();
		final persistence = context.watch<Persistence?>();
		ThreadSortingMethod sortingMethod = settings.catalogSortingMethod;
		bool reverseSorting = settings.reverseCatalogSorting;
		if (persistence?.browserState.boardSortingMethods[board?.name] != null) {
			sortingMethod = persistence!.browserState.boardSortingMethods[board?.name]!;
			reverseSorting = persistence.browserState.boardReverseSortings[board?.name] ?? false;
		}
		if (_temporarySortingMethod != null) {
			sortingMethod = _temporarySortingMethod!;
			reverseSorting = _temporaryReverseSorting;
		}
		Widget itemBuilder(BuildContext context, Thread thread, {String? highlightString}) {
			final isSaved = context.select<Persistence, bool>((p) => p.getThreadStateIfExists(thread.identifier)?.savedTime != null);
			final isThreadHidden = context.select<Persistence, bool>((p) => p.browserState.isThreadHidden(thread.board, thread.id));
			final isImageHidden = context.select<Persistence, bool>((p) => p.browserState.areMD5sHidden(thread.md5s));
			return ContextMenu(
				actions: [
					if (widget.onWantOpenThreadInNewTab != null) ContextMenuAction(
						child: const Text('Open in new tab'),
						trailingIcon: CupertinoIcons.rectangle_stack_badge_plus,
						onPressed: () {
							widget.onWantOpenThreadInNewTab?.call(imageboard!.key, thread.identifier);
						}
					),
					if (isSaved) ContextMenuAction(
						child: const Text('Un-save thread'),
						trailingIcon: CupertinoIcons.bookmark_fill,
						onPressed: () {
							final threadState = context.read<Persistence>().getThreadState(thread.identifier);
							threadState.savedTime = null;
							threadState.save();
							setState(() {});
						}
					)
					else ContextMenuAction(
						child: const Text('Save thread'),
						trailingIcon: CupertinoIcons.bookmark,
						onPressed: () {
							final threadState = context.read<Persistence>().getThreadState(thread.identifier);
							threadState.thread = thread;
							threadState.savedTime = DateTime.now();
							threadState.save();
							setState(() {});
						}
					),
					if (isThreadHidden) ContextMenuAction(
						child: const Text('Unhide thread'),
						trailingIcon: CupertinoIcons.eye_slash_fill,
						onPressed: () {
							context.read<Persistence>().browserState.unHideThread(thread.board, thread.id);
							context.read<Persistence>().didUpdateBrowserState();
							setState(() {});
						}
					)
					else ContextMenuAction(
						child: const Text('Hide thread'),
						trailingIcon: CupertinoIcons.eye_slash,
						onPressed: () {
							context.read<Persistence>().browserState.hideThread(thread.board, thread.id);
							context.read<Persistence>().didUpdateBrowserState();
							setState(() {});
						}
					),
					if (isImageHidden) ContextMenuAction(
						child: const Text('Unhide by image'),
						trailingIcon: CupertinoIcons.eye_slash_fill,
						onPressed: () {
							context.read<Persistence>().browserState.unHideByMD5s(thread.md5s);
							context.read<Persistence>().didUpdateBrowserState();
							setState(() {});
						}
					)
					else if (thread.attachments.isNotEmpty) ContextMenuAction(
						child: const Text('Hide by image'),
						trailingIcon: CupertinoIcons.eye_slash,
						onPressed: () {
							thread.md5s.forEach(context.read<Persistence>().browserState.hideByMD5);
							context.read<Persistence>().didUpdateBrowserState();
							setState(() {});
						}
					)
				],
				maxHeight: settings.maxCatalogRowHeight,
				child:  GestureDetector(
					child: ThreadRow(
						contentFocus: settings.useCatalogGrid,
						thread: thread,
						isSelected: thread.identifier == widget.selectedThread,
						semanticParentIds: [widget.semanticId],
						onThumbnailTap: (initialAttachment) {
							final attachments = _listController.items.expand((_) => _.attachments).toList();
							// It might not be in the list if the thread has been filtered
							final initialAttachmentInList = attachments.tryFirstWhere((a) => a.id == initialAttachment.id);
							showGallery(
								context: context,
								attachments: initialAttachmentInList == null ? [initialAttachment] : attachments,
								replyCounts: {
									for (final thread in _listController.items)
										for (final attachment in thread.attachments)
											attachment: thread.replyCount
								},
								initialAttachment: initialAttachmentInList ?? initialAttachment,
								onChange: (attachment) {
									_listController.animateTo((p) => p.attachments.any((a) => a.id == attachment.id), alignment: 0.5);
								},
								semanticParentIds: [widget.semanticId]
							);
						},
						baseOptions: PostSpanRenderOptions(
							highlightString: highlightString
						)
					),
					onTap: () => _onThreadSelected(thread.identifier)
				)
			);
		}
		return CupertinoPageScaffold(
			resizeToAvoidBottomInset: false,
			navigationBar: CupertinoNavigationBar(
				transitionBetweenRoutes: false,
				leading: settings.supportMouse.value && !Navigator.of(context).canPop() ? CupertinoButton(
					padding: EdgeInsets.zero,
					child: const Icon(CupertinoIcons.refresh),
					onPressed: () {
						_listController.blockAndUpdate();
					}
				) : null,
				middle: GestureDetector(
					onTap: widget.allowChangingBoard ? _selectBoard : null,
					child: Row(
						mainAxisSize: MainAxisSize.min,
						children: [
							if (imageboard != null) ...[
								if (ImageboardRegistry.instance.count > 1) ...[
									const ImageboardIcon(),
									const Text(' ')
								],
								if (board != null) Text('/${board!.name}/')
								else const Text('Select Board')
							]
							else const Text('Select Imageboard'),
							if (widget.allowChangingBoard) const Icon(Icons.arrow_drop_down)
						]
					)
				),
				trailing: Row(
					mainAxisSize: MainAxisSize.min,
					children: [
						CupertinoButton(
							padding: EdgeInsets.zero,
							child: Transform(
								alignment: Alignment.center,
								transform: reverseSorting ? Matrix4.rotationX(pi) : Matrix4.identity(),
								child: const Icon(CupertinoIcons.sort_down)
							),
							onPressed: () {
								showCupertinoModalPopup<DateTime>(
									context: context,
									builder: (context) => CupertinoActionSheet(
										title: const Text('Sort by...'),
										actions: {
											ThreadSortingMethod.unsorted: 'Bump Order',
											ThreadSortingMethod.replyCount: 'Reply Count',
											ThreadSortingMethod.threadPostTime: 'Creation Date',
											ThreadSortingMethod.postsPerMinute: 'Reply Rate',
											ThreadSortingMethod.lastReplyTime: 'Last Reply',
											ThreadSortingMethod.imageCount: 'Image Count',
											if (_temporarySortingMethod != null) null: 'Clear temporary method'
											else if (persistence?.browserState.boardSortingMethods[board?.name] != null) null: 'Clear board method'
										}.entries.map((entry) => CupertinoActionSheetAction(
											child: Text(entry.value, style: TextStyle(
												fontWeight: (entry.key == sortingMethod || entry.key == null) ? FontWeight.bold : null
											)),
											onPressed: () {
												Navigator.of(context, rootNavigator: true).pop();
												final method = entry.key;
												if (method == null) {
													if (_temporarySortingMethod != null) {
														_temporarySortingMethod = null;
													}
													else {
														persistence?.browserState.boardSortingMethods.remove(board?.name);
														persistence?.browserState.boardReverseSortings.remove(board?.name);
													}
													setState(() {});
													return;
												}
												showCupertinoModalPopup<DateTime>(
													context: context,
													builder: (context) => CupertinoActionSheet(
														title: const Text('Sorting method scope'),
														actions: {
															_ThreadSortingMethodScope.global: 'For All Boards',
															_ThreadSortingMethodScope.board: 'For Current Board',
															_ThreadSortingMethodScope.temporary: 'Temporarily',
														}.entries.map((entry) => CupertinoActionSheetAction(
															child: Text(entry.value),
															onPressed: () {
																switch (entry.key) {
																	case _ThreadSortingMethodScope.global:
																		if (settings.catalogSortingMethod == method) {
																			settings.reverseCatalogSorting = !settings.reverseCatalogSorting;
																		}
																		else {
																			settings.reverseCatalogSorting = false;
																			settings.catalogSortingMethod = method;
																		}
																		break;
																	case _ThreadSortingMethodScope.board:
																		if (persistence?.browserState.boardSortingMethods[board!.name] == method) {
																			persistence?.browserState.boardReverseSortings[board!.name] = !(persistence.browserState.boardReverseSortings[board!.name] ?? false);
																		}
																		else {
																			persistence?.browserState.boardReverseSortings[board!.name] = false;
																			persistence?.browserState.boardSortingMethods[board!.name] = method;
																		}
																		persistence?.didUpdateBrowserState();
																		break;
																	case _ThreadSortingMethodScope.temporary:
																		if (_temporarySortingMethod == method) {
																			_temporaryReverseSorting = !_temporaryReverseSorting;
																		}
																		else {
																			_temporaryReverseSorting = false;
																			_temporarySortingMethod = method;
																		}
																		setState(() {});
																		break;
																}
																Navigator.of(context, rootNavigator: true).pop();
															}
														)).toList(),
														cancelButton: CupertinoActionSheetAction(
															child: const Text('Cancel'),
															onPressed: () => Navigator.of(context, rootNavigator: true).pop()
														)
													)
												);
											}
										)).toList(),
										cancelButton: CupertinoActionSheetAction(
											child: const Text('Cancel'),
											onPressed: () => Navigator.of(context, rootNavigator: true).pop()
										)
									)
								);
							}
						),
						CupertinoButton(
							padding: EdgeInsets.zero,
							child: (_replyBoxKey.currentState?.show ?? false) ? const Icon(CupertinoIcons.pencil_slash) : const Icon(CupertinoIcons.pencil),
							onPressed: () {
								if (context.read<MasterDetailHint?>()?.twoPane == true && _replyBoxKey.currentState?.show != true) {
									showCupertinoModalPopup(
										context: context,
										builder: (ctx) => ImageboardScope(
											imageboardKey: null,
											imageboard: imageboard!,
											child: Padding(
												padding: MediaQuery.of(ctx).viewInsets,
												child: Container(
													color: CupertinoTheme.of(context).scaffoldBackgroundColor,
													child: ReplyBox(
														fullyExpanded: true,
														board: board!.name,
														initialText: widget.getInitialDraftText?.call() ?? '',
														onTextChanged: (text) {
															widget.onDraftTextChanged?.call(text);
														},
														initialSubject: widget.getInitialDraftSubject?.call() ?? '',
														onSubjectChanged: (subject) {
															widget.onDraftSubjectChanged?.call(subject);
														},
														initialOptions: widget.getInitialThreadDraftOptions?.call() ?? '',
														onOptionsChanged: (options) {
															widget.onThreadDraftOptionsChanged?.call(options);
														},
														initialFilePath: widget.getInitialThreadDraftFilePath?.call() ?? '',
														onFilePathChanged: (filePath) {
															widget.onThreadDraftFilePathChanged?.call(filePath);
														},
														onReplyPosted: (receipt) async {
															await promptForPushNotificationsIfNeeded(ctx);
															if (!mounted) return;
															imageboard.notifications.subscribeToThread(
																thread: ThreadIdentifier(board!.name, receipt.id),
																lastSeenId: receipt.id,
																localYousOnly: false,
																pushYousOnly: false,
																push: true,
																youIds: [receipt.id]
															);
															_listController.update();
															_onThreadSelected(ThreadIdentifier(board!.name, receipt.id));
															Navigator.of(ctx).pop();
														}
													)
												)
											)
										)
									);
								}
								else {
									_replyBoxKey.currentState?.toggleReplyBox();
									setState(() {});
								}
							}
						)
					]
				)
			),
			child: board == null ? const Center(
				child: Text('No Board Selected')
			) : PullTab(
				key: _boardsPullTabKey,
				tab: PullTabTab(
					child: const Text('Open boards'),
					onActivation: _selectBoard,
				),
				child: PullTab(
					key: _threadPullTabKey,
					tab: (widget.selectedThread != null || _lastSelectedThread == null) ? null : PullTabTab(
						child: Text('Re-open /${_lastSelectedThread!.board}/${_lastSelectedThread!.id}'),
						onActivation: () => _onThreadSelected(_lastSelectedThread!)
					),
					position: PullTabPosition.left,
					child: FilterZone(
						filter: context.select<Persistence, Filter>((p) => p.browserState.getCatalogFilter(board!.name)),
						child: WillPopScope(
							onWillPop: () async {
								if (_replyBoxKey.currentState?.show ?? false) {
									_replyBoxKey.currentState?.hideReplyBox();
									setState(() {});
									return false;
								}
								return true;
							},
							child: Column(
								children: [
									Flexible(
										child: CallbackShortcuts(
											bindings: {
												LogicalKeySet(LogicalKeyboardKey.keyG): () {
													if (board != null && context.read<EffectiveSettings>().showImages(context, board!.name)) {
														final nextThreadWithImage = _listController.items.skip(_listController.firstVisibleIndex).firstWhere((t) => t.attachments.isNotEmpty, orElse: () {
															return _listController.items.firstWhere((t) => t.attachments.isNotEmpty);
														});
														final attachments = _listController.items.expand((_) => _.attachments).toList();
														showGallery(
															context: context,
															attachments: attachments,
															replyCounts: {
																for (final thread in _listController.items)
																	for (final attachment in thread.attachments)
																		attachment: thread.replyCount
															},
															initialAttachment: attachments.firstWhere((a) => nextThreadWithImage.attachments.any((a2) => a2.id == a.id)),
															onChange: (attachment) {
																_listController.animateTo((p) => p.attachments.any((a) => a.id == attachment.id), alignment: 0.5);
															},
															semanticParentIds: [widget.semanticId]
														);
													}
												}
											},
											child: site == null ? const Center(
												child: ErrorMessageCard('No imageboard selected')
											) : Stack(
												fit: StackFit.expand,
												children: [
													RefreshableList<Thread>(
														initialFilter: widget.initialSearch,
														filterableAdapter: (t) => t,
														allowReordering: true,
														onWantAutosave: (thread) async {
															final persistence = context.read<Persistence>();
															if (persistence.browserState.autosavedIds[thread.board]?.contains(thread.id) ?? false) {
																// Already saw this thread
																return;
															}
															final threadState = persistence.getThreadState(thread.identifier);
															threadState.savedTime = DateTime.now();
															threadState.thread = thread;
															persistence.browserState.autosavedIds.putIfAbsent(thread.board, () => []).add(thread.id);
															await threadState.save();
															await persistence.didUpdateBrowserState();
														},
														gridSize: settings.useCatalogGrid ? Size(settings.catalogGridWidth, settings.catalogGridHeight) : null,
														controller: _listController,
														listUpdater: () => site.getCatalog(board!.name).then((list) async {
															for (final thread in list) {
																await thread.preinit(catalog: true);
															}
															final now = DateTime.now();
															if (settings.hideOldStickiedThreads && list.length > 100) {
																list = list.where((thread) {
																	return !thread.isSticky || now.difference(thread.time).compareTo(_oldThreadThreshold).isNegative;
																}).toList();
															}
															switch (sortingMethod) {
																case ThreadSortingMethod.replyCount:
																	list.sort((a, b) => b.replyCount.compareTo(a.replyCount));
																	break;
																case ThreadSortingMethod.threadPostTime:
																	list.sort((a, b) => b.id.compareTo(a.id));
																	break;
																case ThreadSortingMethod.postsPerMinute:
																	list.sort((a, b) => -1 * ((b.replyCount + 1) / b.time.difference(now).inSeconds).compareTo((a.replyCount + 1) / a.time.difference(now).inSeconds));
																	break;
																case ThreadSortingMethod.lastReplyTime:
																	list.sort((a, b) => b.posts.last.id.compareTo(a.posts.last.id));
																	break;
																case ThreadSortingMethod.imageCount:
																	list.sort((a, b) => b.imageCount.compareTo(a.imageCount));
																	break;
																// Some methods only used for saved posts
																case ThreadSortingMethod.savedTime:
																case ThreadSortingMethod.lastPostTime:
																case ThreadSortingMethod.lastReplyByYouTime:
																case ThreadSortingMethod.unsorted:
																	break;
															}
															Future.delayed(const Duration(milliseconds: 100), () {
																if (_loadCompleter?.isCompleted == false) {
																	_loadCompleter?.complete();
																}
															});
															return reverseSorting ? list.reversed.toList() : list;
														}),
														id: '/${board!.name}/ $sortingMethod $reverseSorting',
														itemBuilder: (context, thread) => itemBuilder(context, thread),
														filteredItemBuilder: (context, thread, resetPage, filterText) => itemBuilder(context, thread, highlightString: filterText),
														filterHint: 'Search in board',
														filterAlternative: widget.onWantArchiveSearch == null ? null : FilterAlternative(
															name: '/${board?.name}/ archives',
															handler: (s) {
																widget.onWantArchiveSearch!(imageboard!.key, board!.name, s);
															}
														)
													),
													RepaintBoundary(
														child: StreamBuilder(
															stream: _listController.slowScrollUpdates,
															builder: (context, _) {
																final page = _listController.firstVisibleItem?.currentPage;
																scrollToTop() => _listController.scrollController?.animateTo(0.0, duration: const Duration(milliseconds: 200), curve: Curves.ease);
																return (page == null || page == 0 || _listController.firstVisibleIndex == 0 || ((_listController.scrollController?.position.pixels ?? 1) < 0)) ? Container() : SafeArea(
																	child: Align(
																		alignment: Alignment.bottomRight,
																		child: Row(
																			mainAxisSize: MainAxisSize.min,
																			children: [
																				GestureDetector(
																					onTap: scrollToTop,
																					child: Container(
																						decoration: BoxDecoration(
																							color: CupertinoTheme.of(context).primaryColorWithBrightness(0.8),
																							borderRadius: const BorderRadius.all(Radius.circular(8))
																						),
																						padding: const EdgeInsets.all(8),
																						margin: const EdgeInsets.only(bottom: 16, right: 16),
																						child: Row(
																							mainAxisSize: MainAxisSize.min,
																							children: [
																								Icon(CupertinoIcons.doc, color: CupertinoTheme.of(context).scaffoldBackgroundColor),
																								SizedBox(
																									width: 25,
																									child: Text(
																										page.toString(),
																										textAlign: TextAlign.center,
																										style: TextStyle(
																											color: CupertinoTheme.of(context).scaffoldBackgroundColor
																										)
																									)
																								)
																							]
																						)
																					)
																				)
																			]
																		)
																	)
																);
															}
														)
													)
												]
											)
										)
									),
									RepaintBoundary(
										child: ReplyBox(
											key: _replyBoxKey,
											board: board!.name,
											initialText: widget.getInitialDraftText?.call() ?? '',
											onTextChanged: (text) {
												widget.onDraftTextChanged?.call(text);
											},
											initialSubject: widget.getInitialDraftSubject?.call() ?? '',
											onSubjectChanged: (subject) {
												widget.onDraftSubjectChanged?.call(subject);
											},
											initialOptions: widget.getInitialThreadDraftOptions?.call() ?? '',
											onOptionsChanged: (options) {
												widget.onThreadDraftOptionsChanged?.call(options);
											},
											initialFilePath: widget.getInitialThreadDraftFilePath?.call() ?? '',
											onFilePathChanged: (filePath) {
												widget.onThreadDraftFilePathChanged?.call(filePath);
											},
											onReplyPosted: (receipt) async {
												await promptForPushNotificationsIfNeeded(context);
												if (!mounted) return;
												imageboard?.notifications.subscribeToThread(
													thread: ThreadIdentifier(board!.name, receipt.id),
													lastSeenId: receipt.id,
													localYousOnly: false,
													pushYousOnly: false,
													push: true,
													youIds: [receipt.id]
												);
												_listController.update();
												_onThreadSelected(ThreadIdentifier(board!.name, receipt.id));
											},
											onVisibilityChanged: () => setState(() {}),
										)
									)
								]
							)
						)
					)
				)
			)
		);
	}
}
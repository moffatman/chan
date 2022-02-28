import 'dart:async';
import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:chan/widgets/reply_box.dart';
import 'package:chan/widgets/util.dart';
import 'package:chan/widgets/weak_navigator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:chan/models/post.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class OpenGalleryIntent extends Intent {
	const OpenGalleryIntent();
}

class ThreadPage extends StatefulWidget {
	final ThreadIdentifier thread;
	final int? initialPostId;
	final bool initiallyUseArchive;
	final int boardSemanticId;

	const ThreadPage({
		required this.thread,
		this.initialPostId,
		this.initiallyUseArchive = false,
		required this.boardSemanticId,
		Key? key
	}) : super(key: key);

	@override
	createState() => _ThreadPageState();
}

class _ThreadPageState extends State<ThreadPage> {
	late PersistentThreadState persistentState;
	final _shareButtonKey = GlobalKey();
	final _weakNavigatorKey = GlobalKey<WeakNavigatorState>();
	final _replyBoxKey = GlobalKey<ReplyBoxState>();
	final _listKey = GlobalKey<RefreshableListState>();

	final _listController = RefreshableListController<Post>();
	late PostSpanRootZoneData zone;
	bool blocked = false;
	bool _unnaturallyScrolling = false;
	late Listenable _threadStateListenable;
	Thread? lastThread;
	int lastHiddenPostIdsLength = 0;
	int lastPostsMarkedAsYouLength = 0;
	DateTime? lastSavedTime;
	Timer? _saveThreadStateDuringEditingTimer;
	int lastSavedPostsLength = 0;
	bool _saveQueued = false;
	int lastHiddenMD5sLength = 0;
	int? lastPageNumber;

	void _onThreadStateListenableUpdate() {
		final persistence = context.read<Persistence>();
		final savedPostsLength = persistentState.thread?.posts.where((p) => persistence.getSavedPost(p) != null).length ?? 0;
		final hiddenMD5sLength = persistence.browserState.hiddenImageMD5s.length;
		if (persistentState.thread != lastThread ||
				persistentState.hiddenPostIds.length != lastHiddenPostIdsLength || 
				persistentState.postsMarkedAsYou.length != lastPostsMarkedAsYouLength || 
				persistentState.savedTime != lastSavedTime ||
				savedPostsLength != lastSavedPostsLength ||
				hiddenMD5sLength != lastHiddenMD5sLength) {
			setState(() {});
		}
		lastThread = persistentState.thread;
		lastHiddenPostIdsLength = persistentState.hiddenPostIds.length;
		lastPostsMarkedAsYouLength = persistentState.postsMarkedAsYou.length;
		lastSavedTime = persistentState.savedTime;
		lastSavedPostsLength = savedPostsLength;
		lastHiddenMD5sLength = hiddenMD5sLength;
	}

	Thread get _nullThread => Thread(
		board: widget.thread.board,
		id: widget.thread.id,
		isDeleted: false,
		isArchived: false,
		title: '',
		isSticky: false,
		replyCount: -1,
		imageCount: -1,
		time: DateTime.fromMicrosecondsSinceEpoch(0),
		posts: [],
	);

	Future<void> _blockAndScrollToPostIfNeeded([Duration delayBeforeScroll = Duration.zero]) async {
		final int? scrollToId = widget.initialPostId ?? persistentState.lastSeenPostId;
		if (persistentState.thread != null && scrollToId != null) {
			setState(() {
				blocked = true;
				_unnaturallyScrolling = true;
			});
			await Future.delayed(delayBeforeScroll);
			final alignment = (scrollToId == widget.initialPostId) ? 0.0 : 1.0;
			try {
				await WidgetsBinding.instance.endOfFrame;
				await _listController.animateTo((post) => post.id == scrollToId, orElseLast: (post) => post.id <= scrollToId, alignment: alignment, duration: const Duration(milliseconds: 1));
				await WidgetsBinding.instance.endOfFrame;
			}
			catch (e, st) {
				print('${widget.thread} Error scrolling');
				print(e);
				print(st);
			}
			if (mounted) {
				setState(() {
					blocked = false;
				});
			}
			await Future.delayed(const Duration(milliseconds: 200));
			_unnaturallyScrolling = false;
		}
	}

	@override
	void initState() {
		super.initState();
		persistentState = context.read<Persistence>().getThreadState(widget.thread, updateOpenedTime: true);
		persistentState.useArchive |= widget.initiallyUseArchive;
		persistentState.save();
		zone = PostSpanRootZoneData(
			thread: persistentState.thread ?? _nullThread,
			site: context.read<ImageboardSite>(),
			threadState: persistentState,
			semanticRootIds: [widget.boardSemanticId, 0],
			onNeedScrollToPost: (post) {
				_weakNavigatorKey.currentState!.popAllExceptFirst();
				Future.delayed(const Duration(milliseconds: 150), () => _listController.animateTo((val) => val.id == post.id));
			}
		);
		Future.delayed(const Duration(milliseconds: 50), () {
			_threadStateListenable = context.read<Persistence>().listenForPersistentThreadStateChanges(widget.thread);
			_threadStateListenable.addListener(_onThreadStateListenableUpdate);
		});
		_listController.slowScrollUpdates.listen((_) {
			final lastItem = _listController.lastVisibleItem;
			if (persistentState.thread != null && !_unnaturallyScrolling && lastItem != null) {
				final newLastSeen = lastItem.id;
				if (newLastSeen > (persistentState.lastSeenPostId ?? 0)) {
					persistentState.lastSeenPostId = newLastSeen;
					persistentState.lastSeenPostIdNotifier.value = newLastSeen;
					_saveQueued = true;
				}
			}
		});
		_blockAndScrollToPostIfNeeded();
	}

	@override
	void didUpdateWidget(ThreadPage old) {
		super.didUpdateWidget(old);
		if (widget.thread != old.thread) {
			_threadStateListenable.removeListener(_onThreadStateListenableUpdate);
			_threadStateListenable = context.watch<Persistence>().listenForPersistentThreadStateChanges(widget.thread);
			_threadStateListenable.addListener(_onThreadStateListenableUpdate);
			_weakNavigatorKey.currentState!.popAllExceptFirst();
			persistentState.save(); // Save old state in case it had pending scroll update to save
			persistentState = context.watch<Persistence>().getThreadState(widget.thread, updateOpenedTime: true);
			persistentState.useArchive |= widget.initiallyUseArchive;
			final oldZone = zone;
			Future.delayed(const Duration(milliseconds: 100), () => oldZone.dispose());
			zone = PostSpanRootZoneData(
				thread: persistentState.thread ?? _nullThread,
				site: context.read<ImageboardSite>(),
				threadState: persistentState,
				onNeedScrollToPost: oldZone.onNeedScrollToPost,
				semanticRootIds: [widget.boardSemanticId, 0]
			);
			persistentState.save();
			_blockAndScrollToPostIfNeeded(const Duration(milliseconds: 100));
			setState(() {});
		}
		else if (widget.initialPostId != old.initialPostId && widget.initialPostId != null) {
			_listController.animateTo((post) => post.id == widget.initialPostId!, orElseLast: (post) => post.id <= widget.initialPostId!, alignment: 0.0, duration: const Duration(milliseconds: 500));
		}
	}

	void _showGallery({bool initiallyShowChrome = false, Attachment? initialAttachment}) {
		final attachments = persistentState.thread!.posts.where((_) => _.attachment != null).map((_) => _.attachment!).toList();
		showGallery(
			context: context,
			attachments: attachments,
			initiallyShowChrome: initiallyShowChrome,
			initialAttachment: (initialAttachment == null) ? null : attachments.firstWhere((a) => a.id == initialAttachment.id),
			onChange: (attachment) {
				_listController.animateTo((p) => p.attachment?.id == attachment.id);
			},
			semanticParentIds: [widget.boardSemanticId, 0]
		);
	}

	Widget _limitCounter(int value, int? maximum) {
		if (maximum != null && (value >= maximum * 0.8)) {
			return Text('$value / $maximum', style: TextStyle(
				color: value >= maximum ? Colors.red : null
			));
		}
		else {
			return Text('$value ');
		}
	}

	Future<void> _switchToArchive() async {
		persistentState.useArchive = true;
		await persistentState.save();
		setState(() {});
		await _listController.blockAndUpdate();
	}

	Future<void> _switchToLive() async {
		persistentState.useArchive = false;
		await persistentState.save();
		setState(() {});
		await _listController.blockAndUpdate();
	}

	@override
	Widget build(BuildContext context) {
		String title = '/${widget.thread.board}/';
		if (persistentState.thread?.title != null) {
			title += ' - ' + context.read<EffectiveSettings>().filterProfanity(persistentState.thread!.title!);
		}
		else {
			title += widget.thread.id.toString();
		}
		if (persistentState.thread?.isArchived ?? false) {
			title += ' (Archived)';
		}
		return FilterZone(
			filter: persistentState.threadFilter,
			child: Provider.value(
				value: _replyBoxKey,
				child: CupertinoPageScaffold(
					resizeToAvoidBottomInset: false,
					navigationBar: CupertinoNavigationBar(
						transitionBetweenRoutes: false,
						middle: AutoSizeText(title),
						trailing: Row(
							mainAxisSize: MainAxisSize.min,
							children: [
								CupertinoButton(
									padding: EdgeInsets.zero,
									child: Icon(persistentState.savedTime == null ? CupertinoIcons.bookmark : CupertinoIcons.bookmark_fill),
									onPressed: () {
										if (persistentState.savedTime != null) {
											persistentState.savedTime = null;
										}
										else {
											persistentState.savedTime = DateTime.now();
										}
										persistentState.save();
										setState(() {});
									}
								),
								CupertinoButton(
									key: _shareButtonKey,
									padding: EdgeInsets.zero,
									child: const Icon(CupertinoIcons.share),
									onPressed: () {
										final offset = (_shareButtonKey.currentContext?.findRenderObject() as RenderBox?)?.localToGlobal(Offset.zero);
										final size = _shareButtonKey.currentContext?.findRenderObject()?.semanticBounds.size;
										shareOne(
											text: context.read<ImageboardSite>().getWebUrl(widget.thread.board, widget.thread.id),
											type: "text",
											sharePositionOrigin: (offset != null && size != null) ? offset & size : null
										);
									}
								),
								CupertinoButton(
									padding: EdgeInsets.zero,
									child: (_replyBoxKey.currentState?.show ?? false) ? const Icon(CupertinoIcons.arrowshape_turn_up_left_fill) : const Icon(CupertinoIcons.reply),
									onPressed: (persistentState.thread?.isArchived == true && !(_replyBoxKey.currentState?.show ?? false)) ? null : () {
										_replyBoxKey.currentState?.toggleReplyBox();
									}
								)
							]
						)
					),
					child: Column(
						children: [
							Flexible(
								flex: 1,
								child: Shortcuts(
									shortcuts: {
										LogicalKeySet(LogicalKeyboardKey.keyG): const OpenGalleryIntent()
									},
									child: Actions(
										actions: {
											OpenGalleryIntent: CallbackAction<OpenGalleryIntent>(
												onInvoke: (i) {
													if (context.read<EffectiveSettings>().showImages(context, widget.thread.board)) {
														final nextPostWithImage = persistentState.thread?.posts.skip(_listController.firstVisibleIndex).firstWhere((p) => p.attachment != null, orElse: () {
															return persistentState.thread!.posts.take(_listController.firstVisibleIndex).firstWhere((p) => p.attachment != null);
														});
														if (nextPostWithImage != null) {
															_showGallery(initialAttachment: nextPostWithImage.attachment);
														}
													}
													return null;
												}
											)
										},
										child: Focus(
											autofocus: true,
											child: WeakNavigator(
												key: _weakNavigatorKey,
												child: Stack(
													fit: StackFit.expand,
													children: [
														ChangeNotifierProvider<PostSpanZoneData>.value(
															value: zone,
															child: NotificationListener<ScrollNotification>(
																onNotification: (notification) {
																	if (notification is ScrollEndNotification) {
																		Future.delayed(const Duration(milliseconds: 300), () {
																			if (!(_listController.scrollController?.position.isScrollingNotifier.value ?? false) && _saveQueued) {
																				persistentState.save();
																				_saveQueued = false;
																			}
																		});
																	}
																	return false;
																},
																child: RefreshableList<Post>(
																	key: _listKey,
																	id: '/${widget.thread.board}/${widget.thread.id}',
																	disableUpdates: persistentState.thread?.isArchived ?? false,
																	autoUpdateDuration: const Duration(seconds: 60),
																	initialList: persistentState.thread?.posts,
																	footer: Container(
																		padding: const EdgeInsets.all(16),
																		child: (persistentState.thread == null) ? null : Opacity(
																			opacity: persistentState.thread?.isArchived == true ? 0.5 : 1,
																			child: Row(
																				children: [
																					const Spacer(),
																					const Icon(CupertinoIcons.reply),
																					const SizedBox(width: 8),
																					_limitCounter(persistentState.thread!.replyCount, context.watch<Persistence>().getBoard(widget.thread.board).threadCommentLimit),
																					const Spacer(),
																					const Icon(CupertinoIcons.photo),
																					const SizedBox(width: 8),
																					_limitCounter(persistentState.thread!.imageCount, context.watch<Persistence>().getBoard(widget.thread.board).threadImageLimit),
																					const Spacer(),
																					if (persistentState.thread!.uniqueIPCount != null) ...[
																						const Icon(CupertinoIcons.person),
																						const SizedBox(width: 8),
																						Text('${persistentState.thread!.uniqueIPCount}'),
																						const Spacer(),
																					],
																					if (persistentState.thread!.currentPage != null) ...[
																						const Icon(CupertinoIcons.doc),
																						const SizedBox(width: 8),
																						_limitCounter(persistentState.thread!.currentPage!, context.watch<Persistence>().getBoard(widget.thread.board).pageCount),
																						const Spacer()
																					],
																					if (persistentState.thread!.isArchived) ...[
																						GestureDetector(
																							behavior: HitTestBehavior.opaque,
																							child: Row(
																								children: const [
																									Icon(CupertinoIcons.archivebox),
																									SizedBox(width: 8),
																									Text('Archived')
																								]
																							),
																							onTap: _switchToLive
																						),
																						const Spacer()
																					]
																				]
																			)
																		)
																	),
																	remedies: {
																		ThreadNotFoundException: (context, updater) => CupertinoButton.filled(
																			child: const Text('Try archive'),
																			onPressed: () {
																				persistentState.useArchive = true;
																				persistentState.save();
																				updater();
																			}
																		)
																	},
																	listUpdater: () async {
																		final _persistentState = persistentState;
																		lastPageNumber = persistentState.thread?.currentPage;
																		// The thread might switch in this interval
																		final _thread = _persistentState.useArchive ?
																			await context.read<ImageboardSite>().getThreadFromArchive(widget.thread) :
																			await context.read<ImageboardSite>().getThread(widget.thread);
																		final bool firstLoad = _persistentState.thread == null;
																		bool shouldScroll = false;
																		if (_thread != _persistentState.thread) {
																			_persistentState.thread = _thread;
																			if (persistentState == _persistentState) {
																				zone.thread = _thread;
																				if (firstLoad) shouldScroll = true;
																			}
																			await _persistentState.save();
																			setState(() {});
																			Future.delayed(const Duration(milliseconds: 100), () {
																				if (persistentState == _persistentState && !_unnaturallyScrolling) {
																					final lastItem = _listController.lastVisibleItem;
																					if (lastItem != null) {
																						_persistentState.lastSeenPostId = max(_persistentState.lastSeenPostId ?? 0, lastItem.id);
																						_persistentState.save();
																						setState(() {});
																					}
																					else {
																						print('Failed to find last visible post after an update in $_persistentState');
																					}
																				}
																			});
																		}
																		else if (_thread.currentPage != lastPageNumber) {
																			setState(() {
																				lastPageNumber = _thread.currentPage;
																			});
																		}
																		if (shouldScroll) _blockAndScrollToPostIfNeeded(const Duration(milliseconds: 500));
																		// Don't show data if the thread switched
																		if (persistentState == _persistentState) {
																			return _thread.posts;
																		}
																		return null;
																	},
																	controller: _listController,
																	itemBuilder: (context, post) {
																		return PostRow(
																			post: post,
																			onThumbnailTap: (attachment) {
																				_showGallery(initialAttachment: attachment);
																			},
																			onRequestArchive: _switchToArchive
																		);
																	},
																	filteredItemBuilder: (context, post, resetPage) {
																		return PostRow(
																			post: post,
																			onThumbnailTap: (attachment) {
																				_showGallery(initialAttachment: attachment);
																			},
																			onRequestArchive: _switchToArchive,
																			onTap: () {
																				resetPage();
																				Future.delayed(const Duration(milliseconds: 250), () => _listController.animateTo((val) => val.id == post.id));
																			}
																		);
																	},
																	filterHint: 'Search in thread'
																)
															)
														),
														SafeArea(
															child: Align(
																alignment: Alignment.bottomRight,
																child: ThreadPositionIndicator(
																	persistentState: persistentState,
																	listController: _listController
																)
															)
														),
														if (blocked) Builder(
															builder: (context) => Container(
																color: CupertinoTheme.of(context).scaffoldBackgroundColor,
																child: const Center(
																	child: CupertinoActivityIndicator()
																)
															)
														)
													]
												)
											)
										)
									)
								)
							),
							ReplyBox(
								key: _replyBoxKey,
								board: widget.thread.board,
								threadId: widget.thread.id,
								isArchived: persistentState.thread?.isArchived ?? false,
								initialText: persistentState.draftReply,
								onTextChanged: (text) {
									persistentState.draftReply = text;
									_saveThreadStateDuringEditingTimer?.cancel();
									_saveThreadStateDuringEditingTimer = Timer(const Duration(seconds: 3), () => persistentState.save());
								},
								onReplyPosted: (receipt) {
									persistentState.savedTime = DateTime.now();
									persistentState.save();
									_listController.update();
								},
								onVisibilityChanged: () {
									setState(() {});
								}
							)
						]
					)
				)
			)
		);
	}

	@override
	void dispose() {
		super.dispose();
		_threadStateListenable.removeListener(_onThreadStateListenableUpdate);
		_listController.dispose();
	}
}

class ThreadPositionIndicator extends StatefulWidget {
	final PersistentThreadState persistentState;
	final RefreshableListController listController;
	
	const ThreadPositionIndicator({
		required this.persistentState,
		required this.listController,
		Key? key
	}) : super(key: key);

	@override
	createState() => _ThreadPositionIndicatorState();
}

class _ThreadPositionIndicatorState extends State<ThreadPositionIndicator> {
	final FilterCache _filterCache = FilterCache(const DummyFilter());
	List<Post>? _filteredPosts;
	int _lastLastItemId = -1;
	int _redCount = 0;
	int _whiteCount = 0;
	int _greyCount = 0;

	@override
	void didUpdateWidget(ThreadPositionIndicator oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (widget.persistentState != oldWidget.persistentState) {
			_filteredPosts = null;
			_lastLastItemId = -1;
		}
	}

	@override
	Widget build(BuildContext context) {
		return StreamBuilder(
			stream: widget.listController.slowScrollUpdates,
			builder: (context, a) {
				if (widget.persistentState.thread != null) {
					final newFilter = Filter.of(context);
					if (_filterCache.wrappedFilter != newFilter || _filteredPosts == null) {
						_filterCache.setFilter(newFilter);
						_filteredPosts = widget.persistentState.thread!.posts.where((p) => _filterCache.filter(p)?.type != FilterResultType.hide).toList();
					}
					final lastItemId = widget.listController.lastVisibleItem?.id;
					if (widget.persistentState.lastSeenPostId != null && lastItemId != null && lastItemId != _lastLastItemId) {
						final youIds = widget.persistentState.youIds;
						_redCount = _filteredPosts!.where((p) => p.id > widget.persistentState.lastSeenPostId! && p.span.referencedPostIds(p.board).any((id) => youIds.contains(id))).length;
						_whiteCount = _filteredPosts!.where((p) => p.id > widget.persistentState.lastSeenPostId!).length;
						_greyCount = _filteredPosts!.where((p) => p.id > lastItemId).length - _whiteCount;
						_lastLastItemId = lastItemId;
					}
				}
				const radius = Radius.circular(8);
				const radiusAlone = BorderRadius.all(radius);
				scrollToBottom() => widget.listController.animateTo((post) => post.id == widget.persistentState.thread!.posts.last.id, alignment: 1.0);
				if (_redCount > 0 || _whiteCount > 0 || _greyCount > 0) {
					return GestureDetector(
						child: Builder(
							builder: (context) => Row(
								mainAxisSize: MainAxisSize.min,
								children: [
									if (_redCount > 0) Container(
										decoration: BoxDecoration(
											borderRadius: (_whiteCount > 0 || _greyCount > 0) ? const BorderRadius.only(topLeft: radius, bottomLeft: radius) : radiusAlone,
											color: CupertinoTheme.of(context).textTheme.actionTextStyle.color
										),
										padding: const EdgeInsets.all(8),
										margin: EdgeInsets.only(bottom: 16, right: (_whiteCount == 0 && _greyCount == 0) ? 16 : 0),
										child: Text(
											_redCount.toString(),
											textAlign: TextAlign.center
										)
									),
									if (_greyCount > 0) Container(
										decoration: BoxDecoration(
											borderRadius: (_redCount > 0) ? (_whiteCount > 0 ? null : const BorderRadius.only(topRight: radius, bottomRight: radius)) : (_whiteCount > 0 ? const BorderRadius.only(topLeft: radius, bottomLeft: radius) : radiusAlone),
											color: CupertinoTheme.of(context).primaryColorWithBrightness(0.6)
										),
										padding: const EdgeInsets.all(8),
										margin: EdgeInsets.only(bottom: 16, right: _whiteCount > 0 ? 0 : 16),
										child: Container(
											constraints: BoxConstraints(
												minWidth: 24 * MediaQuery.of(context).textScaleFactor
											),
											child: Text(
												_greyCount.toString(),
												style: TextStyle(
													color: CupertinoTheme.of(context).scaffoldBackgroundColor
												),
												textAlign: TextAlign.center
											)
										)
									),
									if (_whiteCount > 0) Container(
										decoration: BoxDecoration(
											borderRadius: (_greyCount > 0 || _redCount > 0) ? const BorderRadius.only(topRight: radius, bottomRight: radius) : radiusAlone,
											color: CupertinoTheme.of(context).primaryColor
										),
										padding: const EdgeInsets.all(8),
										margin: const EdgeInsets.only(bottom: 16, right: 16),
										child: Container(
											constraints: BoxConstraints(
												minWidth: 24 * MediaQuery.of(context).textScaleFactor
											),
											child: Text(
												_whiteCount.toString(),
												style: TextStyle(
													color: CupertinoTheme.of(context).scaffoldBackgroundColor
												),
												textAlign: TextAlign.center
											)
										)
									)
								]
							)
						),
						onTap: () => widget.listController.animateTo((post) => post.id == widget.persistentState.lastSeenPostId, alignment: 1.0),
						onLongPress: scrollToBottom
					);
				}
				else {
					return const SizedBox.shrink();
				}
			}
		);
	}
}
import 'dart:async';
import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/posts.dart';
import 'package:chan/pages/thread_attachments.dart';
import 'package:chan/pages/thread_watch_controls.dart';
import 'package:chan/services/apple.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/notifications.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/share.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/widgets/cupertino_page_route.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/imageboard_scope.dart';
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
import 'package:tuple/tuple.dart';

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
	int lastReceiptsLength = 0;
	int lastTreeHiddenIdsLength = 0;
	int lastHiddenPosterIdsLength = 0;
	bool _foreground = false;

	void _onThreadStateListenableUpdate() {
		final persistence = context.read<Persistence>();
		final savedPostsLength = persistentState.thread?.posts.where((p) => persistence.getSavedPost(p) != null).length ?? 0;
		final hiddenMD5sLength = persistence.browserState.hiddenImageMD5s.length;
		if (persistentState.thread != lastThread ||
				persistentState.hiddenPostIds.length != lastHiddenPostIdsLength || 
				persistentState.postsMarkedAsYou.length != lastPostsMarkedAsYouLength || 
				persistentState.savedTime != lastSavedTime ||
				savedPostsLength != lastSavedPostsLength ||
				hiddenMD5sLength != lastHiddenMD5sLength ||
				persistentState.receipts.length != lastReceiptsLength ||
				persistentState.treeHiddenPostIds.length != lastTreeHiddenIdsLength ||
				persistentState.hiddenPosterIds.length != lastHiddenPosterIdsLength) {
			setState(() {});
		}
		if (persistentState.thread != lastThread) {
			final tmpPersistentState = persistentState;
			Future.delayed(const Duration(milliseconds: 100), () {
				if (persistentState == tmpPersistentState && !_unnaturallyScrolling) {
					final lastItem = _listController.lastVisibleItem;
					if (lastItem != null) {
						tmpPersistentState.lastSeenPostId = max(tmpPersistentState.lastSeenPostId ?? 0, lastItem.id);
						tmpPersistentState.save();
						setState(() {});
					}
					else {
						print('Failed to find last visible post after an update in $tmpPersistentState');
					}
				}
			});
		}
		lastThread = persistentState.thread;
		lastHiddenPostIdsLength = persistentState.hiddenPostIds.length;
		lastPostsMarkedAsYouLength = persistentState.postsMarkedAsYou.length;
		lastSavedTime = persistentState.savedTime;
		lastSavedPostsLength = savedPostsLength;
		lastHiddenMD5sLength = hiddenMD5sLength;
		lastReceiptsLength = persistentState.receipts.length;
		lastTreeHiddenIdsLength = persistentState.treeHiddenPostIds.length;
		lastHiddenPosterIdsLength = persistentState.hiddenPosterIds.length;
		if (persistentState.thread != null) {
			zone.thread = persistentState.thread!;
		}
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
		posts_: [],
	);

	Future<void> _blockAndScrollToPostIfNeeded([Duration delayBeforeScroll = Duration.zero]) async {
		final int? scrollToId = widget.initialPostId ?? context.read<PersistentBrowserTab?>()?.initialPostId[widget.thread] ?? persistentState.lastSeenPostId;
		context.read<PersistentBrowserTab?>()?.initialPostId.remove(widget.thread);
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

	void _maybeUpdateWatch() {
		final notifications = context.read<Notifications>();
		final threadWatch = notifications.getThreadWatch(widget.thread);
		if (threadWatch != null && persistentState.thread != null) {
			_checkForeground();
			notifications.updateLastKnownId(threadWatch, persistentState.thread!.posts.last.id, foreground: _foreground);
		}
	}

	void _checkForeground() {
		final masterDetailHint = context.read<MasterDetailHint?>();
		_foreground = masterDetailHint == null // Dev board in settings
				 	|| masterDetailHint.primaryInterceptorKey.currentState?.primaryScrollControllerTracker.value != null;
	}

	@override
	void initState() {
		super.initState();
		persistentState = context.read<Persistence>().getThreadState(widget.thread, updateOpenedTime: true);
		persistentState.useArchive |= widget.initiallyUseArchive;
		persistentState.save();
		_maybeUpdateWatch();
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
		context.read<PersistentBrowserTab?>()?.threadController = _listController;
		_blockAndScrollToPostIfNeeded();
	}

	@override
	void didUpdateWidget(ThreadPage old) {
		super.didUpdateWidget(old);
		if (widget.thread != old.thread) {
			_threadStateListenable.removeListener(_onThreadStateListenableUpdate);
			_threadStateListenable = context.read<Persistence>().listenForPersistentThreadStateChanges(widget.thread);
			_threadStateListenable.addListener(_onThreadStateListenableUpdate);
			_weakNavigatorKey.currentState!.popAllExceptFirst();
			persistentState.save(); // Save old state in case it had pending scroll update to save
			persistentState = context.read<Persistence>().getThreadState(widget.thread, updateOpenedTime: true);
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
			_maybeUpdateWatch();
			persistentState.save();
			_blockAndScrollToPostIfNeeded(const Duration(milliseconds: 100));
			setState(() {});
		}
		else if (widget.initialPostId != old.initialPostId && widget.initialPostId != null) {
			_listController.animateTo((post) => post.id == widget.initialPostId!, orElseLast: (post) => post.id <= widget.initialPostId!, alignment: 0.0, duration: const Duration(milliseconds: 500));
		}
	}

	@override
	void didChangeDependencies() {
		super.didChangeDependencies();
		_checkForeground();
		setHandoffUrl(_foreground ? context.read<ImageboardSite>().getWebUrl(widget.thread.board, widget.thread.id) : null);
	}

	void _showGallery({bool initiallyShowChrome = false, Attachment? initialAttachment}) {
		final attachments = persistentState.thread!.posts.where((_) => _.attachment != null).map((_) => _.attachment!).toList();
		showGallery(
			context: context,
			attachments: attachments,
			replyCounts: {
				for (final post in persistentState.thread!.posts.where((_) => _.attachment != null)) post.attachment!: post.replyIds.length
			},
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

	Future<void> _showWatchMenu() async {
		await _weakNavigatorKey.currentState?.push(ThreadWatchControlsPage(
			thread: widget.thread
		));
	}

	@override
	Widget build(BuildContext context) {
		String title = '/${widget.thread.board}/';
		if (persistentState.thread?.title != null) {
			title += ' - ${context.read<EffectiveSettings>().filterProfanity(persistentState.thread!.title!)}';
		}
		else {
			title += widget.thread.id.toString();
		}
		if (persistentState.thread?.isArchived ?? false) {
			title += ' (Archived)';
		}
		final notifications = context.watch<Notifications>();
		final watch = context.select<Persistence, ThreadWatch?>((_) => notifications.getThreadWatch(widget.thread));
		return WillPopScope(
			onWillPop: () async {
				if (_replyBoxKey.currentState?.show ?? false) {
					_replyBoxKey.currentState?.hideReplyBox();
					return false;
				}
				return true;
			},
			child: FilterZone(
				filter: persistentState.threadFilter,
				child: Provider.value(
					value: _replyBoxKey,
					child: CupertinoPageScaffold(
						resizeToAvoidBottomInset: false,
						navigationBar: CupertinoNavigationBar(
							transitionBetweenRoutes: false,
							middle: Padding(
								padding: const EdgeInsets.only(top: 8, bottom: 8),
								child: Row(
									mainAxisAlignment: MainAxisAlignment.center,
									mainAxisSize: MainAxisSize.min,
									children: [
										if (ImageboardRegistry.instance.count > 1) const Padding(
											padding: EdgeInsets.only(right: 6),
											child: ImageboardIcon()
										),
										Flexible(
											child: AutoSizeText(
												title,
												minFontSize: 6,
												maxLines: 4,
												overflow: TextOverflow.ellipsis,
											)
										)
									]
								)
							),
							trailing: Row(
								mainAxisSize: MainAxisSize.min,
								children: [
									CupertinoButton(
										padding: EdgeInsets.zero,
										onPressed: _showWatchMenu,
										child: Icon(watch == null ? CupertinoIcons.bell : CupertinoIcons.bell_fill)
									),
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
												context: context,
												text: context.read<ImageboardSite>().getWebUrl(widget.thread.board, widget.thread.id),
												type: "text",
												sharePositionOrigin: (offset != null && size != null) ? offset & size : null
											);
										}
									),
									CupertinoButton(
										padding: EdgeInsets.zero,
										onPressed: (persistentState.thread?.isArchived == true && !(_replyBoxKey.currentState?.show ?? false)) ? null : () {
											_replyBoxKey.currentState?.toggleReplyBox();
										},
										child: (_replyBoxKey.currentState?.show ?? false) ? const Icon(CupertinoIcons.arrowshape_turn_up_left_fill) : const Icon(CupertinoIcons.reply)
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
																		filterableAdapter: (t) => t,
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
																						_limitCounter(persistentState.thread!.replyCount, context.read<Persistence>().getBoard(widget.thread.board).threadCommentLimit),
																						const Spacer(),
																						const Icon(CupertinoIcons.photo),
																						const SizedBox(width: 8),
																						_limitCounter(persistentState.thread!.imageCount, context.read<Persistence>().getBoard(widget.thread.board).threadImageLimit),
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
																							_limitCounter(persistentState.thread!.currentPage!, context.read<Persistence>().getBoard(widget.thread.board).pageCount),
																							const Spacer()
																						],
																						if (persistentState.thread!.isArchived) ...[
																							GestureDetector(
																								behavior: HitTestBehavior.opaque,
																								onTap: _switchToLive,
																								child: Row(
																									children: const [
																										Icon(CupertinoIcons.archivebox),
																										SizedBox(width: 8),
																										Text('Archived')
																									]
																								)
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
																			final tmpPersistentState = persistentState;
																			lastPageNumber = persistentState.thread?.currentPage;
																			// The thread might switch in this interval
																			final newThread = tmpPersistentState.useArchive ?
																				await context.read<ImageboardSite>().getThreadFromArchive(widget.thread) :
																				await context.read<ImageboardSite>().getThread(widget.thread);
																			final bool firstLoad = tmpPersistentState.thread == null;
																			bool shouldScroll = false;
																			if (watch != null && newThread.identifier == widget.thread && mounted) {
																				_checkForeground();
																				notifications.updateLastKnownId(watch, newThread.posts.last.id, foreground: _foreground);
																			}
																			if (newThread != tmpPersistentState.thread) {
																				tmpPersistentState.thread = newThread;
																				if (persistentState == tmpPersistentState) {
																					zone.thread = newThread;
																					if (firstLoad) shouldScroll = true;
																				}
																				await tmpPersistentState.save();
																				setState(() {});
																				Future.delayed(const Duration(milliseconds: 100), () {
																					if (persistentState == tmpPersistentState && !_unnaturallyScrolling) {
																						final lastItem = _listController.lastVisibleItem;
																						if (lastItem != null) {
																							tmpPersistentState.lastSeenPostId = max(tmpPersistentState.lastSeenPostId ?? 0, lastItem.id);
																							tmpPersistentState.save();
																							setState(() {});
																						}
																						else {
																							print('Failed to find last visible post after an update in $tmpPersistentState');
																						}
																					}
																				});
																			}
																			else if (newThread.currentPage != lastPageNumber) {
																				setState(() {
																					lastPageNumber = newThread.currentPage;
																				});
																			}
																			if (shouldScroll) _blockAndScrollToPostIfNeeded(const Duration(milliseconds: 500));
																			// Don't show data if the thread switched
																			Future.delayed(const Duration(milliseconds: 30), () {
																				// Trigger update of counts in case new post is drawn fully onscreen
																				_listController.slowScrollUpdates.add(null);
																			});
																			if (persistentState == tmpPersistentState) {
																				return newThread.posts;
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
																				onThumbnailLoadError: (a, b) {
																					print(a);
																					print(b);
																				},
																				onRequestArchive: _switchToArchive
																			);
																		},
																		filteredItemBuilder: (context, post, resetPage, filterText) {
																			return PostRow(
																				post: post,
																				onThumbnailTap: (attachment) {
																					_showGallery(initialAttachment: attachment);
																				},
																				onRequestArchive: _switchToArchive,
																				onTap: () {
																					resetPage();
																					Future.delayed(const Duration(milliseconds: 250), () => _listController.animateTo((val) => val.id == post.id));
																				},
																				baseOptions: PostSpanRenderOptions(
																					highlightString: filterText
																				),
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
																		thread: persistentState.thread,
																		listController: _listController,
																		zone: zone,
																		filter: Filter.of(context)
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
								RepaintBoundary(
									child: ReplyBox(
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
										onReplyPosted: (receipt) async {
											await promptForPushNotificationsIfNeeded(context);
											if (!mounted) return;
											context.read<Notifications>().subscribeToThread(
												thread: widget.thread,
												lastSeenId: receipt.id,
												localYousOnly: context.read<Notifications>().getThreadWatch(widget.thread)?.localYousOnly ?? true,
												pushYousOnly: context.read<Notifications>().getThreadWatch(widget.thread)?.pushYousOnly ?? true,
												push: true,
												youIds: persistentState.youIds
											);
											if (persistentState.lastSeenPostId == persistentState.thread?.posts.last.id) {
												// If already at the bottom, pre-mark the created post as seen
												persistentState.lastSeenPostId = receipt.id;
												persistentState.lastSeenPostIdNotifier.value = receipt.id;
												_saveQueued = true;
											}
											_listController.update();
										},
										onVisibilityChanged: () {
											setState(() {});
										}
									)
								)
							]
						)
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
		if (_saveQueued) {
			persistentState.save();
		}
		if (_foreground) {
			setHandoffUrl(null);
		}
	}
}

class ThreadPositionIndicator extends StatefulWidget {
	final PersistentThreadState persistentState;
	final Thread? thread;
	final RefreshableListController<Post> listController;
	final Filter filter;
	final PostSpanZoneData zone;
	
	const ThreadPositionIndicator({
		required this.persistentState,
		required this.thread,
		required this.listController,
		required this.filter,
		required this.zone,
		Key? key
	}) : super(key: key);

	@override
	createState() => _ThreadPositionIndicatorState();
}

class _ThreadPositionIndicatorState extends State<ThreadPositionIndicator> with TickerProviderStateMixin {
	List<Post>? _filteredPosts;
	List<Post> _yous = [];
	int? _lastLastVisibleItemId;
	int _redCount = 0;
	int _whiteCount = 0;
	int _greyCount = 0;
	late StreamSubscription<void> _slowScrollSubscription;
	Timer? _waitForRebuildTimer;
	late final _buttonsAnimationController = AnimationController(
		vsync: this,
		duration: const Duration(milliseconds: 300)
	);
	late final _buttonsAnimation = CurvedAnimation(
		parent: _buttonsAnimationController,
		curve: Curves.ease
	);

	bool _updateCounts() {
		final lastVisibleItemId = widget.listController.lastVisibleItem?.id;
		if (lastVisibleItemId == null || _filteredPosts == null) return false;
		final youIds = widget.persistentState.youIds;
		final lastSeenPostId = widget.persistentState.lastSeenPostId ?? widget.persistentState.id;
		_yous = _filteredPosts!.where((p) => p.span.referencedPostIds(p.board).any((id) => youIds.contains(id))).toList();
		_redCount = _yous.where((p) => p.id > lastSeenPostId).length;
		_whiteCount = _filteredPosts!.where((p) => p.id > lastSeenPostId).length;
		_greyCount = _filteredPosts!.where((p) => p.id > lastVisibleItemId).length - _whiteCount;
		_lastLastVisibleItemId = lastVisibleItemId;
		setState(() {});
		return true;
	}

	void _onSlowScroll(_) {
		final lastVisibleItemId = widget.listController.lastVisibleItem?.id;
		if (lastVisibleItemId != null && lastVisibleItemId != _lastLastVisibleItemId && _filteredPosts != null) {
			_updateCounts();
		}
	}

	void _onLastSeenPostIdNotifier() {
		_updateCounts();
	}

	@override
	void initState() {
		super.initState();
		_slowScrollSubscription = widget.listController.slowScrollUpdates.listen(_onSlowScroll);
		widget.persistentState.lastSeenPostIdNotifier.addListener(_onLastSeenPostIdNotifier);
		if (widget.thread != null) {
			_filteredPosts = widget.thread!.posts.where((p) => widget.filter.filter(p)?.type != FilterResultType.hide).toList();
		}
	}

	@override
	void didUpdateWidget(ThreadPositionIndicator oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (widget.persistentState != oldWidget.persistentState) {
			_filteredPosts = null;
			_lastLastVisibleItemId = null;
			oldWidget.persistentState.lastSeenPostIdNotifier.removeListener(_onLastSeenPostIdNotifier);
			widget.persistentState.lastSeenPostIdNotifier.addListener(_onLastSeenPostIdNotifier);
		}
		if (widget.thread != oldWidget.thread || widget.filter != oldWidget.filter) {
			_waitForRebuildTimer?.cancel();
			if (widget.thread == null) {
				_filteredPosts = null;
			}
			else {
				_filteredPosts = widget.thread!.posts.where((p) => widget.filter.filter(p)?.type != FilterResultType.hide).toList();
			}
			if (widget.thread?.identifier != oldWidget.thread?.identifier) {
				setState(() {
					_redCount = 0;
					_whiteCount = 0;
					_greyCount = 0;
				});
			}
			if (!_updateCounts()) {
				_waitForRebuildTimer = Timer.periodic(const Duration(milliseconds: 150), (t) {
					if (_updateCounts()) {
						t.cancel();
					}
				});
			}
		}
		if (widget.listController != oldWidget.listController) {
			_slowScrollSubscription.cancel();
			_slowScrollSubscription = widget.listController.slowScrollUpdates.listen(_onSlowScroll);
		}
	}

	@override
	Widget build(BuildContext context) {
		const radius = Radius.circular(8);
		const radiusAlone = BorderRadius.all(radius);
		scrollToBottom() => widget.listController.animateTo((post) => post.id == widget.persistentState.thread!.posts.last.id, alignment: 1.0);
		final youIds = widget.persistentState.youIds;
		return Stack(
			alignment: Alignment.bottomRight,
			children: [
				AnimatedBuilder(
					animation: _buttonsAnimationController,
					builder: (context, child) => Transform(
						transform: Matrix4.translationValues(0, 100 - _buttonsAnimation.value * 100, 0),
						child: FadeTransition(
							opacity: _buttonsAnimation,
							child: IgnorePointer(
								ignoring: _buttonsAnimation.value < 0.5,
								child: child
							)
						)
					),
					child: Padding(
						padding: const EdgeInsets.only(top: 10, bottom: 50),
						child: FittedBox(
							fit: BoxFit.contain,
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.end,
								mainAxisSize: MainAxisSize.min,
								children: [
									for (final button in [
										Tuple3('Scroll to top', const Icon(CupertinoIcons.arrow_up_to_line, size: 19), () => widget.listController.scrollController?.animateTo(
											0,
											duration: const Duration(milliseconds: 200),
											curve: Curves.ease
										)),
										Tuple3(describeCount(youIds.length, 'submission'), const Icon(CupertinoIcons.person, size: 19), youIds.isEmpty ? null : () {
												WeakNavigator.push(context, PostsPage(
													zone: widget.zone,
													postsIdsToShow: youIds,
													onTap: (post) {
														widget.listController.animateTo((p) => p.id == post.id);
														WeakNavigator.pop(context);
													}
												)
											);
										}),
										Tuple3(describeCount(_yous.length, '(You)'), const Icon(CupertinoIcons.reply_all, size: 19), _yous.isEmpty ? null : () {
												WeakNavigator.push(context, PostsPage(
													zone: widget.zone,
													postsIdsToShow: _yous.map((y) => y.id).toList(),
													onTap: (post) {
														widget.listController.animateTo((p) => p.id == post.id);
														WeakNavigator.pop(context);
													}
												)
											);
										}),
										Tuple3(
											describeCount((widget.thread?.imageCount ?? 0) + 1, 'image'),
											const RotatedBox(
												quarterTurns: 1,
												child: Icon(CupertinoIcons.rectangle_split_3x1, size: 19)
											),
											() {
												final nextPostWithImage = widget.persistentState.thread?.posts.skip(max(0, widget.listController.firstVisibleIndex - 1)).firstWhere((p) => p.attachment != null, orElse: () {
													return widget.persistentState.thread!.posts.take(widget.listController.firstVisibleIndex).lastWhere((p) => p.attachment != null);
												});
												final imageboard = context.read<Imageboard>();
												Navigator.of(context).push(FullWidthCupertinoPageRoute(
													builder: (context) => ImageboardScope(
														imageboardKey: null,
														imageboard: imageboard,
														child: ThreadAttachmentsPage(
															thread: widget.persistentState.thread!,
															initialAttachment: nextPostWithImage?.attachment,
															//onChange: (attachment) => widget.listController.animateTo((p) => p.attachment?.id == attachment.id)
														)
													),
													showAnimations: context.read<EffectiveSettings>().showAnimations)
												);
											}
										),
										Tuple3('Search', const Icon(CupertinoIcons.search, size: 19), widget.listController.focusSearch),
										Tuple3('Scroll to last-seen', const Icon(CupertinoIcons.arrow_down_to_line, size: 19), _greyCount <= 0 ? null : () => widget.listController.animateTo((post) => post.id == widget.persistentState.lastSeenPostId, alignment: 1.0)),
										Tuple3('Scroll to bottom', const Icon(CupertinoIcons.arrow_down_to_line, size: 19), scrollToBottom)
									]) Padding(
										padding: const EdgeInsets.only(bottom: 16, right: 16),
										child: CupertinoButton.filled(
											disabledColor: CupertinoTheme.of(context).primaryColorWithBrightness(0.4),
											padding: const EdgeInsets.all(8),
											minSize: 0,
											onPressed: button.item3 == null ? null : () {
												button.item3?.call();
												_buttonsAnimationController.reverse();
											},
											child: Row(
												mainAxisSize: MainAxisSize.min,
												children: [
													Text(button.item1),
													const SizedBox(width: 8),
													button.item2
												]
											)
										),
									)
								]
							)
						)
					)
				),
				GestureDetector(
					onLongPress: scrollToBottom,
					child: CupertinoButton(
						padding: EdgeInsets.zero,
						child: Builder(
							builder: (context) => Row(
								mainAxisSize: MainAxisSize.min,
								children: [
									if (_redCount > 0) Container(
										decoration: BoxDecoration(
											borderRadius: const BorderRadius.only(topLeft: radius, bottomLeft: radius),
											color: CupertinoTheme.of(context).textTheme.actionTextStyle.color
										),
										padding: const EdgeInsets.all(8),
										margin: EdgeInsets.only(bottom: 16, right: (_whiteCount == 0 && _greyCount == 0) ? 16 : 0),
										child: Text(
											_redCount.toString(),
											textAlign: TextAlign.center
										)
									),
									if (_whiteCount == 0 || _greyCount > 0) Container(
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
											borderRadius: (_redCount <= 0 && _greyCount <= 0) ? radiusAlone : const BorderRadius.only(topRight: radius, bottomRight: radius),
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
						onPressed: () {
							if (_buttonsAnimation.value > 0.5) {
								_buttonsAnimationController.reverse();
							}
							else {
								_buttonsAnimationController.forward();
							}
						}
					)
				)
			]
		);
	}

	@override
	void dispose() {
		super.dispose();
		_slowScrollSubscription.cancel();
		widget.persistentState.lastSeenPostIdNotifier.removeListener(_onLastSeenPostIdNotifier);
	}
}
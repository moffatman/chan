import 'dart:async';
import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:chan/main.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/models/parent_and_child.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/posts.dart';
import 'package:chan/pages/attachments.dart';
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
import 'package:chan/util.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
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

class OpenGalleryIntent extends Intent {
	const OpenGalleryIntent();
}

class _PersistentThreadStateSnapshot {
	final Thread? thread;
	final int hiddenPostIdsLength;
	final int postsMarkedAsYouLength;
	final DateTime? savedTime;
	final int receiptsLength;
	final int treeHiddenIdsLength;
	final int hiddenPosterIdsLength;
	final bool? useTree;

	_PersistentThreadStateSnapshot.empty() :
		thread = null,
		hiddenPostIdsLength = 0,
		postsMarkedAsYouLength = 0,
		savedTime = null,
		receiptsLength = 0,
		treeHiddenIdsLength = 0,
		hiddenPosterIdsLength = 0,
		useTree = null;

	_PersistentThreadStateSnapshot.of(PersistentThreadState s) :
		thread = s.thread,
		hiddenPostIdsLength = s.hiddenPostIds.length,
		postsMarkedAsYouLength = s.postsMarkedAsYou.length,
		savedTime = s.savedTime,
		receiptsLength = s.receipts.length,
		treeHiddenIdsLength = s.treeHiddenPostIds.length,
		hiddenPosterIdsLength = s.hiddenPosterIds.length,
		useTree = s.useTree;
	
	@override
	bool operator == (Object o) =>
		(o is _PersistentThreadStateSnapshot) &&
		(o.thread == thread) &&
		(o.hiddenPostIdsLength == hiddenPostIdsLength) &&
		(o.postsMarkedAsYouLength == postsMarkedAsYouLength) &&
		(o.savedTime == savedTime) &&
		(o.receiptsLength == receiptsLength) &&
		(o.treeHiddenIdsLength == treeHiddenIdsLength) &&
		(o.hiddenPosterIdsLength == hiddenPosterIdsLength) &&
		(o.useTree == useTree);
	
	@override
	int get hashCode => Object.hash(thread, hiddenPostIdsLength, postsMarkedAsYouLength, savedTime, receiptsLength, treeHiddenIdsLength, hiddenPostIdsLength, useTree);
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

	late final RefreshableListController<Post> _listController;
	late PostSpanRootZoneData zone;
	bool blocked = false;
	bool _unnaturallyScrolling = false;
	late Listenable _threadStateListenable;
	Timer? _saveThreadStateDuringEditingTimer;
	bool _saveQueued = false;
	int? lastPageNumber;
	int lastSavedPostsLength = 0;
	int lastHiddenMD5sLength = 0;
	_PersistentThreadStateSnapshot lastPersistentThreadStateSnapshot = _PersistentThreadStateSnapshot.empty();
	bool _foreground = false;
	PersistentBrowserTab? _parentTab;
	final List<Function> _postUpdateCallbacks = [];
	int lastSeenIdBeforeLastUpdate = pow(2, 50).toInt();
	bool _searching = false;
	bool _passedFirstLoad = false;
	bool _showingWatchMenu = false;

	void _onThreadStateListenableUpdate() {
		final persistence = context.read<Persistence>();
		final savedPostsLength = persistentState.thread?.posts.where((p) => persistence.getSavedPost(p) != null).length ?? 0;
		final hiddenMD5sLength = persistence.browserState.hiddenImageMD5s.length;
		final currentSnapshot = _PersistentThreadStateSnapshot.of(persistentState);
		if (currentSnapshot != lastPersistentThreadStateSnapshot ||
				savedPostsLength != lastSavedPostsLength ||
				hiddenMD5sLength != lastHiddenMD5sLength) {
			_listController.state?.forceRebuildId++;
			setState(() {});
		}
		if (persistentState.thread != lastPersistentThreadStateSnapshot.thread) {
			final tmpPersistentState = persistentState;
			_postUpdateCallbacks.add(() {
				if (mounted && persistentState == tmpPersistentState && !_unnaturallyScrolling) {
					int? newLastId;
					if (useTree) {
						final lastListIndex = _listController.lastVisibleIndex;
						if (lastListIndex != -1) {
							newLastId = _listController.items.take(lastListIndex).map((l) => l.item.id).reduce(max);
						}
					}
					else {
						newLastId = _listController.lastVisibleItem?.id;
					}
					if (newLastId != null) {
						tmpPersistentState.lastSeenPostId = max(tmpPersistentState.lastSeenPostId ?? 0, newLastId);
						tmpPersistentState.save();
						setState(() {});
					}
					else {
						print('Failed to find last visible post after an update in $tmpPersistentState');
					}
				}
			});
		}
		lastSavedPostsLength = savedPostsLength;
		lastHiddenMD5sLength = hiddenMD5sLength;
		lastPersistentThreadStateSnapshot = currentSnapshot;
		if (persistentState.thread != null) {
			zone.thread = persistentState.thread!;
		}
	}

	bool get useTree => persistentState.useTree ?? context.read<Persistence>().browserState.useTree ?? context.read<ImageboardSite>().useTree;

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
		attachments: []
	);

	Future<void> _blockAndScrollToPostIfNeeded([Duration delayBeforeScroll = Duration.zero]) async {
		if (persistentState.thread == null) {
			// too early to try to scroll
			return;
		}
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
				await _listController.animateTo(
					(useTree && scrollToId == persistentState.lastSeenPostId) ? (_) => false : (post) => post.id == scrollToId,
					orElseLast: (post) => post.id <= scrollToId,
					alignment: alignment,
					duration: const Duration(milliseconds: 1)
				);
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

	void _onSlowScroll() {
		final lastItem = _listController.lastVisibleItem;
		if (persistentState.thread != null && !_unnaturallyScrolling && lastItem != null) {
			final newLastSeen = lastItem.id;
			if (newLastSeen > (persistentState.lastSeenPostId ?? 0)) {
				persistentState.lastSeenPostId = newLastSeen;
				persistentState.lastSeenPostIdNotifier.value = newLastSeen;
				_saveQueued = true;
			}
		}
	}

	@override
	void initState() {
		super.initState();
		_listController = RefreshableListController();
		persistentState = context.read<Persistence>().getThreadState(widget.thread, updateOpenedTime: true);
		persistentState.useArchive |= widget.initiallyUseArchive;
		persistentState.save();
		_maybeUpdateWatch();
		persistentState.thread?.preinit();
		zone = PostSpanRootZoneData(
			thread: persistentState.thread ?? _nullThread,
			site: context.read<ImageboardSite>(),
			threadState: persistentState,
			semanticRootIds: [widget.boardSemanticId, 0],
			onNeedScrollToPost: (post) {
				_weakNavigatorKey.currentState!.popAllExceptFirst();
				Future.delayed(const Duration(milliseconds: 150), () => _listController.animateTo((val) => val.id == post.id));
			},
			onNeedUpdateWithStubItems: (ids) async {
				await _updateWithStubItems(ids);
				_listController.state?.acceptNewList(zone.thread.posts);
			}
		);
		Future.delayed(const Duration(milliseconds: 50), () {
			_threadStateListenable = context.read<Persistence>().listenForPersistentThreadStateChanges(widget.thread);
			_threadStateListenable.addListener(_onThreadStateListenableUpdate);
		});
		_listController.slowScrolls.addListener(_onSlowScroll);
		context.read<PersistentBrowserTab?>()?.threadController = _listController;
		final int? explicitScrollToId = widget.initialPostId ?? context.read<PersistentBrowserTab?>()?.initialPostId[widget.thread];
		if (explicitScrollToId != null || !(useTree && (context.read<ImageboardSite>().isReddit || context.read<ImageboardSite>().isHackerNews))) {
			_blockAndScrollToPostIfNeeded();
		}
	}

	@override
	void didUpdateWidget(ThreadPage old) {
		super.didUpdateWidget(old);
		if (widget.thread != old.thread) {
			_saveQueued = false;
			_passedFirstLoad = false;
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
				onNeedUpdateWithStubItems: oldZone.onNeedUpdateWithStubItems,
				semanticRootIds: [widget.boardSemanticId, 0]
			);
			_maybeUpdateWatch();
			persistentState.save();
			if (!useTree) {
				_blockAndScrollToPostIfNeeded(const Duration(milliseconds: 100));
			}
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
		_parentTab = context.watch<PersistentBrowserTab?>();
		setHandoffUrl(_foreground ? context.read<ImageboardSite>().getWebUrl(widget.thread.board, widget.thread.id) : null);
	}

	void _showGallery({bool initiallyShowChrome = false, TaggedAttachment? initialAttachment}) {
		final commonParentIds = [widget.boardSemanticId, 0];
		List<TaggedAttachment> attachments = _listController.items.expand((item) => item.item.attachments.map((a) => TaggedAttachment(
			attachment: a,
			semanticParentIds: commonParentIds.followedBy(item.parentIds)
		))).toList();
		if (!attachments.contains(initialAttachment)) {
			final hiddenAttachments = _listController.state?.filteredValues.expand((item) => item.item.attachments.map((a) => TaggedAttachment(
				attachment: a,
				semanticParentIds: commonParentIds.followedBy(item.parentIds)
			))).toList() ?? [];
			if (hiddenAttachments.contains(initialAttachment)) {
				attachments = hiddenAttachments;
			}
		}
		else {
			// Dedupe
			final found = <Attachment, TaggedAttachment>{};
			for (final a in attachments) {
				found.putIfAbsent(a.attachment, () => a);
			}
			if (initialAttachment != null) {
				found[initialAttachment.attachment] = initialAttachment;
			}
			attachments.removeWhere((a) => found[a.attachment] != a);
		}
		showGalleryPretagged(
			context: context,
			attachments: attachments,
			replyCounts: {
				for (final post in persistentState.thread!.posts)
					for (final attachment in post.attachments)
						attachment: post.replyIds.length
			},
			isAttachmentAlreadyDownloaded: persistentState.isAttachmentDownloaded,
			onAttachmentDownload: persistentState.didDownloadAttachment,
			initiallyShowChrome: initiallyShowChrome,
			initialAttachment: initialAttachment,
			onChange: (attachment) {
				_listController.animateTo((p) => p.attachments.any((a) {
					return a.id == attachment.attachment.id;
				}));
			}
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
		if (_showingWatchMenu) {
			return;
		}
		_showingWatchMenu = true;
		await _weakNavigatorKey.currentState?.push(ThreadWatchControlsPage(
			thread: widget.thread
		));
		_showingWatchMenu = false;
	}

	Future<Thread> _getUpdatedThread() async {
		final tmpPersistentState = persistentState;
		final site = context.read<ImageboardSite>();
		final notifications = context.read<Notifications>();
		lastPageNumber = persistentState.thread?.currentPage;
		// The thread might switch in this interval
		final newThread = tmpPersistentState.useArchive ?
			await site.getThreadFromArchive(widget.thread) :
			await site.getThread(widget.thread, variant: tmpPersistentState.variant);
		final bool firstLoad = tmpPersistentState.thread == null;
		bool shouldScroll = false;
		final watch = notifications.getThreadWatch(widget.thread);
		if (watch != null && newThread.identifier == widget.thread && mounted) {
			_checkForeground();
			notifications.updateLastKnownId(watch, newThread.posts.last.id, foreground: _foreground);
		}
		newThread.mergePosts(tmpPersistentState.thread, tmpPersistentState.thread?.posts ?? [], site.placeOrphanPost);
		if (newThread != tmpPersistentState.thread) {
			await newThread.preinit();
			tmpPersistentState.thread = newThread;
			if (persistentState == tmpPersistentState) {
				zone.thread = newThread;
				if (_replyBoxKey.currentState?.hasSpamFilteredPostToCheck ?? false) {
					newThread.posts.forEach(_replyBoxKey.currentState!.checkForSpamFilteredPost);
				}
				if (firstLoad) shouldScroll = true;
				if (persistentState.autoTranslate) {
					// Translate new posts
					for (final post in newThread.posts) {
						if (zone.translatedPost(post.id) == null) {
							zone.translatePost(post.id);
						}
					}
				}
			}
			await tmpPersistentState.save();
			_postUpdateCallbacks.add(() async {
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
			lastPageNumber = newThread.currentPage;
		}
		lastSeenIdBeforeLastUpdate = tmpPersistentState.lastSeenPostId ?? lastSeenIdBeforeLastUpdate;
		if (useTree && _passedFirstLoad) {
			tmpPersistentState.lastSeenPostId = newThread.posts.map((p) => p.id).reduce(max);
			tmpPersistentState.lastSeenPostIdNotifier.value = tmpPersistentState.lastSeenPostId;
		}
		// Don't show data if the thread switched
		_postUpdateCallbacks.add(() async {
			if (!mounted) return;
			// Trigger update of counts in case new post is drawn fully onscreen
			_listController.slowScrolls.didUpdate();
		});
		if (shouldScroll && !useTree) {
			_blockAndScrollToPostIfNeeded(const Duration(milliseconds: 500))
				.then((_) async {
					await _listController.waitForItemBuild(0);
					_runPostUpdateCallbacks();
				});
		}
		else {
			_listController.waitForItemBuild(0).then((_) => _runPostUpdateCallbacks());
		}
		_passedFirstLoad = true;
		setState(() {});
		return newThread;
	}

	void _runPostUpdateCallbacks() async {
		await WidgetsBinding.instance.endOfFrame;
		final tmp = _postUpdateCallbacks.toList();
		_postUpdateCallbacks.clear();
		for (final cb in tmp) {
			cb();
		}
	}

	Future<List<Post>> _updateWithStubItems(List<ParentAndChildIdentifier> ids) async {
			final thread = persistentState.thread;
			if (thread == null) {
				throw Exception('Thread not loaded');
			}
			final site = context.read<ImageboardSite>();
			final newChildren = await site.getStubPosts(thread.identifier, ids);
			thread.mergePosts(null, newChildren, site.placeOrphanPost);
			if (ids.length == 1 && ids.single.childId == ids.single.parentId) {
				// Clear hasOmittedReplies in case it has only omitted shadowbanned replies
				thread.posts_.tryFirstWhere((p) => p.id == ids.single.childId)?.hasOmittedReplies = false;
			}
			persistentState.save();
			return thread.posts;
		}

	@override
	Widget build(BuildContext context) {
		final site = context.watch<ImageboardSite>();
		String title = site.formatBoardName(site.persistence.getBoard(widget.thread.board));
		final threadTitle = persistentState.thread?.title ?? site.getThreadFromCatalogCache(widget.thread)?.title;
		if (threadTitle != null) {
			title += ' - ${context.read<EffectiveSettings>().filterProfanity(threadTitle)}';
		}
		else {
			title = title.replaceFirst(RegExp(r'\/$'), '');
			title += '/${widget.thread.id}';
		}
		if (persistentState.thread?.isArchived ?? false) {
			title = '(Archived) $title';
		}
		if (!site.supportsMultipleBoards) {
			if (threadTitle != null) {
				title = context.read<EffectiveSettings>().filterProfanity(threadTitle);
			}
			else {
				title = widget.thread.id.toString();
			}
		}
		final notifications = context.watch<Notifications>();
		final watch = context.select<Persistence, ThreadWatch?>((_) => notifications.getThreadWatch(widget.thread));
		final reverseIndicatorPosition = context.select<EffectiveSettings, bool>((s) => s.showListPositionIndicatorsOnLeft);
		zone.postSortingMethods = [
			if ((site.isReddit || site.isHackerNews) && !useTree) (a, b) => a.id.compareTo(b.id)
		];
		zone.tree = useTree;
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
							middle: GestureDetector(
								onTap: () {
									showCupertinoDialog(
										context: context,
										barrierDismissible: true,
										builder: (context) => CupertinoAlertDialog(
											title: const Text('Thread title'),
											content: Text(title),
											actions: [
												CupertinoDialogAction(
													child: const Text('OK'),
													onPressed: () => Navigator.pop(context)
												)
											]
										)
									);
								},
								child: Padding(
									padding: const EdgeInsets.only(top: 8, bottom: 8),
									child: Row(
										mainAxisAlignment: MainAxisAlignment.center,
										mainAxisSize: MainAxisSize.min,
										children: [
											if (persistentState.incognito) const Padding(
												padding: EdgeInsets.only(right: 6),
												child: Icon(CupertinoIcons.eyeglasses)
											),
											if (ImageboardRegistry.instance.count > 1) Padding(
												padding: const EdgeInsets.only(right: 6),
												child: ImageboardIcon(
													boardName: widget.thread.board
												)
											),
											Flexible(
												child: AutoSizeText(
													title,
													minFontSize: 14,
													maxLines: 1,
													overflow: TextOverflow.ellipsis,
												)
											)
										]
									)
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
										onPressed: persistentState.incognito ? null : () {
											lightHapticFeedback();
											if (persistentState.savedTime != null) {
												persistentState.savedTime = null;
											}
											else {
												persistentState.savedTime = DateTime.now();
											}
											persistentState.save();
											setState(() {});
										},
										child: Icon(persistentState.savedTime == null ? CupertinoIcons.bookmark : CupertinoIcons.bookmark_fill)
									),
									if (site.threadVariants.isNotEmpty) CupertinoButton(
										padding: EdgeInsets.zero,
										child: FittedBox(
											fit: BoxFit.contain,
											child: SizedBox(
												width: 40,
												height: 40,
												child: Stack(
													children: [
														Align(
															alignment: Alignment.bottomRight,
															child: Icon(persistentState.variant?.icon ?? persistentState.thread?.suggestedVariant?.icon ?? site.threadVariants.first.icon)
														),
														const Align(
															alignment: Alignment.topLeft,
															child: Icon(CupertinoIcons.sort_down)
														)
													]
												)
											)
										),
										onPressed: () async {
											final choice = await showCupertinoModalPopup<ThreadVariant>(
												useRootNavigator: false,
												context: context,
												builder: (context) => CupertinoActionSheet(
													title: const Text('Thread Sorting'),
													actions: site.threadVariants.map((variant) => CupertinoActionSheetAction(
														child: Row(
															children: [
																SizedBox(
																	width: 40,
																	child: Center(
																		child: Icon(variant.icon),
																	)
																),
																Expanded(
																	child: Text(
																		variant.name,
																		textAlign: TextAlign.left,
																		style: TextStyle(
																			fontWeight: variant == (persistentState.variant ?? persistentState.thread?.suggestedVariant ?? site.threadVariants.first) ? FontWeight.bold : null
																		)
																	)
																)
															]
														),
														onPressed: () {
															Navigator.of(context).pop(variant);
														}
													)).toList(),
													cancelButton: CupertinoActionSheetAction(
														child: const Text('Cancel'),
														onPressed: () => Navigator.of(context).pop()
													)
												)
											);
											if (choice != null && mounted) {
												persistentState.variant = choice;
												persistentState.save();
												setState(() {});
												await Future.delayed(const Duration(milliseconds: 30));
												await _listController.blockAndUpdate();
												setState(() {});
											}
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
												text: site.getWebUrl(widget.thread.board, widget.thread.id),
												type: "text",
												sharePositionOrigin: (offset != null && size != null) ? offset & size : null
											);
										}
									),
									if (site.supportsPosting) CupertinoButton(
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
															RefreshableListItem<Post>? nextPostWithImage = _listController.items.skip(_listController.firstVisibleIndex).tryFirstWhere((p) => p.item.attachments.isNotEmpty);
															nextPostWithImage ??= _listController.items.take(_listController.firstVisibleIndex).tryFirstWhere((p) => p.item.attachments.isNotEmpty);
															if (nextPostWithImage != null) {
																_showGallery(initialAttachment: TaggedAttachment(
																	attachment: nextPostWithImage.item.attachments.first,
																	semanticParentIds: [widget.boardSemanticId, 0].followedBy(nextPostWithImage.parentIds)
																));
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
																				if (!((_listController.scrollController?.hasClients ?? false) && (_listController.scrollController?.position.isScrollingNotifier.value ?? false)) && _saveQueued) {
																					persistentState.save();
																					_saveQueued = false;
																				}
																			});
																		}
																		return false;
																	},
																	child: RefreshableList<Post>(
																		filterableAdapter: (t) => t,
																		onFilterChanged: (filter) {
																			_searching = filter != null;
																			setState(() {});
																		},
																		key: _listKey,
																		sortMethods: zone.postSortingMethods,
																		id: '/${widget.thread.board}/${widget.thread.id}${persistentState.variant?.dataId ?? ''}',
																		disableUpdates: persistentState.thread?.isArchived ?? false,
																		autoUpdateDuration: const Duration(seconds: 60),
																		initialList: persistentState.thread?.posts,
																		useTree: useTree,
																		initialCollapsedItems: persistentState.collapsedItems,
																		onCollapsedItemsChanged: (newCollapsedItems) {
																			persistentState.collapsedItems = newCollapsedItems.toList();
																			_saveQueued = true;
																		},
																		treeAdapter: RefreshableTreeAdapter(
																			getId: (p) => p.id,
																			getParentIds: (p) => p.repliedToIds,
																			getIsStub: (p) => p.isStub,
																			getHasOmittedReplies: (p) => p.hasOmittedReplies,
																			updateWithStubItems: (_, ids) => _updateWithStubItems(ids),
																			opId: widget.thread.id,
																			wrapTreeChild: (child, parentIds) {
																				PostSpanZoneData childZone = zone;
																				for (final id in parentIds) {
																					childZone = childZone.childZoneFor(id);
																				}
																				return ChangeNotifierProvider.value(
																					value: childZone,
																					child: child
																				);
																			},
																			estimateHeight: (post, width) {
																				final fontSize = DefaultTextStyle.of(context).style.fontSize ?? 17;
																				return post.span.estimateLines(
																					(width / (0.55 * fontSize * (DefaultTextStyle.of(context).style.height ?? 1.2))).lazyCeil().toDouble()
																				).ceil() * fontSize;
																			}
																		),
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
																								child: const Row(
																									children: [
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
																		listExtender: (persistentState.thread?.isSticky == true && !site.isReddit && !site.isHackerNews) ? (Post after) async {
																			return (await _getUpdatedThread()).posts.where((p) => p.id > after.id).toList();
																		} : null,
																		listUpdater: () async {
																			return (await _getUpdatedThread()).posts;
																		},
																		controller: _listController,
																		itemBuilder: (context, post) {
																			return PostRow(
																				post: post,
																				onThumbnailTap: (attachment) {
																					_showGallery(initialAttachment: TaggedAttachment(
																						attachment: attachment,
																						semanticParentIds: context.read<PostSpanZoneData>().stackIds
																					));
																				},
																				onRequestArchive: _switchToArchive,
																				highlight: useTree && post.id > lastSeenIdBeforeLastUpdate,
																			);
																		},
																		filteredItemBuilder: (context, post, resetPage, filterText) {
																			return PostRow(
																				post: post,
																				onThumbnailTap: (attachment) {
																					_showGallery(initialAttachment: TaggedAttachment(
																						attachment: attachment,
																						semanticParentIds: context.read<PostSpanZoneData>().stackIds
																					));
																				},
																				onRequestArchive: _switchToArchive,
																				onTap: () {
																					resetPage();
																					Future.delayed(const Duration(milliseconds: 250), () => _listController.animateTo((val) => val.id == post.id));
																				},
																				baseOptions: PostSpanRenderOptions(
																					highlightString: filterText
																				),
																				highlight: useTree && post.id > lastSeenIdBeforeLastUpdate,
																			);
																		},
																		collapsedItemBuilder: ({
																			required BuildContext context,
																			required Post? value,
																			required int collapsedChildrenCount,
																			required bool loading,
																			required List<ParentAndChildIdentifier>? stubChildIds
																		}) {
																			final settings = context.watch<EffectiveSettings>();
																			final unseenCount = value?.replyIds.where((id) => id > lastSeenIdBeforeLastUpdate).length ?? 0;
																			return IgnorePointer(
																				child: Container(
																					width: double.infinity,
																					padding: const EdgeInsets.all(8),
																					color: useTree && (value?.id ?? (stubChildIds ?? []).map((x) => x.childId).fold<int>(0, max)) > lastSeenIdBeforeLastUpdate ? CupertinoTheme.of(context).primaryColorWithBrightness(0.1) : null,
																					child: Row(
																						children: [
																							if (value != null) Expanded(
																								child: Text.rich(
																									TextSpan(
																										children: buildPostInfoRow(
																											post: value,
																											isYourPost: persistentState.youIds.contains(value.id),
																											settings: settings,
																											site: site,
																											context: context,
																											zone: zone
																										)
																									)
																								)
																							)
																							else const Spacer(),
																							if (loading) ...[
																								const CupertinoActivityIndicator(),
																								const Text(' ')
																							],
																							if (collapsedChildrenCount > 0) Text(
																								'$collapsedChildrenCount '
																							),
																							if (unseenCount > 0) Text(
																								'($unseenCount new) '
																							),
																							const Icon(CupertinoIcons.chevron_down, size: 20)
																						]
																					)
																				)
																			);
																		},
																		filterHint: 'Search in thread'
																	)
																)
															),
															SafeArea(
																child: Align(
																	alignment: reverseIndicatorPosition ? Alignment.bottomLeft : Alignment.bottomRight,
																	child: ThreadPositionIndicator(
																		reversed: reverseIndicatorPosition,
																		persistentState: persistentState,
																		thread: persistentState.thread,
																		threadIdentifier: widget.thread,
																		listController: _listController,
																		zone: zone,
																		filter: Filter.of(context),
																		useTree: useTree,
																		lastSeenIdBeforeLastUpdate: lastSeenIdBeforeLastUpdate,
																		searching: _searching,
																		passedFirstLoad: _passedFirstLoad,
																		blocked: blocked,
																		boardSemanticId: widget.boardSemanticId
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
											if (site.supportsPushNotifications) {
												await promptForPushNotificationsIfNeeded(context);
											}
											if (!mounted) return;
											notifications.subscribeToThread(
												thread: widget.thread,
												lastSeenId: receipt.id,
												localYousOnly: notifications.getThreadWatch(widget.thread)?.localYousOnly ?? true,
												pushYousOnly: notifications.getThreadWatch(widget.thread)?.pushYousOnly ?? true,
												push: true,
												youIds: persistentState.freshYouIds()
											);
											if (persistentState.lastSeenPostId == persistentState.thread?.posts.last.id) {
												// If already at the bottom, pre-mark the created post as seen
												persistentState.lastSeenPostId = receipt.id;
												persistentState.lastSeenPostIdNotifier.value = receipt.id;
												_saveQueued = true;
											}
											_listController.update();
											Future.delayed(const Duration(seconds: 8), _listController.update);
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
		if (_parentTab?.threadController == _listController) {
			_parentTab?.threadController = null;
		}
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
	final ThreadIdentifier threadIdentifier;
	final RefreshableListController<Post> listController;
	final Filter filter;
	final PostSpanZoneData zone;
	final bool reversed;
	final bool useTree;
	final int lastSeenIdBeforeLastUpdate;
	final bool searching;
	final bool passedFirstLoad;
	final bool blocked;
	final int boardSemanticId;
	
	const ThreadPositionIndicator({
		required this.persistentState,
		required this.thread,
		required this.threadIdentifier,
		required this.listController,
		required this.filter,
		required this.zone,
		this.reversed = false,
		required this.useTree,
		required this.lastSeenIdBeforeLastUpdate,
		required this.searching,
		required this.passedFirstLoad,
		required this.blocked,
		required this.boardSemanticId,
		Key? key
	}) : super(key: key);

	@override
	createState() => _ThreadPositionIndicatorState();
}

class _ThreadPositionIndicatorState extends State<ThreadPositionIndicator> with TickerProviderStateMixin {
	List<Post>? _filteredPosts;
	List<RefreshableListItem<Post>>? _filteredItems;
	List<int> _youIds = [];
	int? _lastLastVisibleItemId;
	int _redCountAbove = 0;
	int _redCountBelow = 0;
	int _whiteCountAbove = 0;
	int _whiteCountBelow = 0;
	int _greyCount = 0;
	Timer? _waitForRebuildTimer;
	late final AnimationController _buttonsAnimationController;
	late final Animation<double> _buttonsAnimation;
	int treeModeFurthestSeenIndexTop = 0;
	int treeModeFurthestSeenIndexBottom = 0;
	int _lastListControllerItemsLength = 0;
	int _lastFirstVisibleIndex = -1;
	int _lastLastVisibleIndex = -1;
	final _animatedPaddingKey = GlobalKey();

	Future<bool> _updateCounts() async {
		await WidgetsBinding.instance.endOfFrame;
		if (!mounted) return false;
		final lastVisibleIndex = widget.listController.lastVisibleIndex;
		if (lastVisibleIndex == -1 || (!widget.useTree && _filteredPosts == null) || (widget.useTree && _filteredItems == null)) {
			if (!widget.passedFirstLoad && widget.useTree) {
				if (widget.thread == null) {
					_greyCount = context.read<ImageboardSite>().getThreadFromCatalogCache(widget.threadIdentifier)?.replyCount ?? 0;
					setState(() {});
				}
				return false;
			}
			if (widget.useTree) {
				assert(widget.thread != null);
				final catalogReplyCount = context.read<ImageboardSite>().getThreadFromCatalogCache(widget.threadIdentifier)?.replyCount;
				if (catalogReplyCount != null) {
					_greyCount = widget.thread?.replyCount ?? 0;
					_whiteCountBelow = max(0, catalogReplyCount - _greyCount);
				}
			}
			else {
				_whiteCountBelow = widget.thread?.replyCount ??
					context.read<ImageboardSite>().getThreadFromCatalogCache(widget.threadIdentifier)?.replyCount
					?? 0;
				_greyCount = 0;
			}
			_redCountBelow = 0;
			setState(() {});
			return false;
		}
		final lastVisibleItemId = widget.listController.getItem(lastVisibleIndex).item.id;
		_youIds = widget.persistentState.replyIdsToYou(widget.filter) ?? [];
		if (widget.useTree) {
			final items = widget.listController.items.toList();
			_greyCount = 0;
			_whiteCountAbove = 0;
			_whiteCountBelow = 0;
			_redCountAbove = 0;
			_redCountBelow = 0;
			if (!widget.passedFirstLoad) {
				_whiteCountBelow += max(0, (context.read<ImageboardSite>().getThreadFromCatalogCache(widget.threadIdentifier)?.replyCount ?? 0) - (widget.thread?.replyCount ?? 0));
			}
			// TODO: Determine if this needs to be / can be memoized
			for (int i = 0; i < items.length - 1; i++) {
				if (items[i].preCollapsed) {
					continue;
				}
				if (i > treeModeFurthestSeenIndexBottom) {
					if (items[i].representsKnownStubChildren.isNotEmpty) {
						for (final stubChild in items[i].representsKnownStubChildren) {
							if (stubChild.childId > widget.lastSeenIdBeforeLastUpdate) {
								_whiteCountBelow++;
							}
							else {
								_greyCount++;
							}
						}
					}
					else if (items[i].item.id > widget.lastSeenIdBeforeLastUpdate) {
						_whiteCountBelow++;
						if (_youIds.contains(items[i].item.id)) {
							_redCountBelow++;
						}
					}
					else {
						_greyCount++;
					}
				}
				else if (i < treeModeFurthestSeenIndexTop) {
					if (items[i].representsKnownStubChildren.isNotEmpty) {
						for (final stubChild in items[i].representsKnownStubChildren) {
							if (stubChild.childId > widget.lastSeenIdBeforeLastUpdate) {
								_whiteCountAbove++;
							}
						}
					}
					else if (items[i].item.id > widget.lastSeenIdBeforeLastUpdate) {
						_whiteCountAbove++;
						if (_youIds.contains(items[i].item.id)) {
							_redCountAbove++;
						}
					}
				}
				else if (i > lastVisibleIndex) {
					_greyCount += max(1, items[i].representsKnownStubChildren.length);
				}
			}
			if (!items.last.preCollapsed) {
				if (items.last.representsKnownStubChildren.isNotEmpty) {
					for (final stubChild in items.last.representsKnownStubChildren) {
						if (stubChild.childId > widget.lastSeenIdBeforeLastUpdate) {
							_whiteCountBelow++;
						}
						else {
							_greyCount++;
						}
					}
				}
				else if ((items.length - 1) > treeModeFurthestSeenIndexBottom) {
					if (items.last.item.id > widget.lastSeenIdBeforeLastUpdate) {
						_whiteCountBelow++;
						if (_youIds.contains(items.last.item.id)) {
							_redCountBelow++;
						}
					}
				}
				else if (lastVisibleIndex < (items.length - 1)) {
					_greyCount++;
				}
			}
		}
		else {
			final lastSeenPostId = widget.persistentState.lastSeenPostId ?? widget.persistentState.id;
			_redCountBelow = _youIds.binarySearchCountAfter((p) => p > lastSeenPostId);
			_whiteCountBelow = _filteredPosts!.binarySearchCountAfter((p) => p.id > lastSeenPostId);
			_greyCount = max(0, widget.listController.itemsLength - (widget.listController.lastVisibleIndex + 1) - _whiteCountBelow);
		}
		_lastLastVisibleItemId = lastVisibleItemId;
		setState(() {});
		return true;
	}

	Future<bool> _onSlowScroll() async {
		if (widget.useTree) {
			_filteredItems ??= widget.listController.items.toList();
			final firstVisibleIndex = widget.listController.firstVisibleIndex;
			if (firstVisibleIndex != -1) {
				treeModeFurthestSeenIndexTop = min(firstVisibleIndex, treeModeFurthestSeenIndexTop);
			}
			final lastVisibleIndex = widget.listController.lastVisibleIndex;
			if (lastVisibleIndex != -1) {
				treeModeFurthestSeenIndexBottom = max(lastVisibleIndex, treeModeFurthestSeenIndexBottom);
			}
			final skip = _lastFirstVisibleIndex == firstVisibleIndex && _lastLastVisibleIndex == lastVisibleIndex;
			_lastFirstVisibleIndex = firstVisibleIndex;
			_lastLastVisibleIndex = lastVisibleIndex;
			return skip || await _updateCounts();
		}
		else {
			final lastVisibleItemId = widget.listController.lastVisibleItem?.id;
			_filteredPosts ??= widget.persistentState.filteredPosts(widget.filter);
			if (lastVisibleItemId != null && lastVisibleItemId != _lastLastVisibleItemId && _filteredPosts != null) {
				return await _updateCounts();
			}
			else {
				return true;
			}
		}
	}

	@override
	void initState() {
		super.initState();
		_buttonsAnimationController = AnimationController(
			vsync: this,
			duration: const Duration(milliseconds: 300)
		);
		_buttonsAnimation = CurvedAnimation(
			parent: _buttonsAnimationController,
			curve: Curves.ease
		);
		widget.listController.slowScrolls.addListener(_onSlowScroll);
		widget.listController.state?.updatingNow.addListener(_onUpdatingNowChange);
		widget.persistentState.lastSeenPostIdNotifier.addListener(_updateCounts);
		if (widget.thread != null) {
			_filteredPosts = widget.persistentState.filteredPosts(widget.filter);
		}
		_updateCounts();
	}

	@override
	void didUpdateWidget(ThreadPositionIndicator oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (widget.persistentState != oldWidget.persistentState) {
			_filteredPosts = null;
			_lastLastVisibleItemId = null;
			oldWidget.persistentState.lastSeenPostIdNotifier.removeListener(_updateCounts);
			widget.persistentState.lastSeenPostIdNotifier.addListener(_updateCounts);
		}
		if (widget.thread != oldWidget.thread || widget.filter != oldWidget.filter) {
			_waitForRebuildTimer?.cancel();
			if (widget.thread == null) {
				_filteredPosts = null;
				_filteredItems = null;
			}
			else {
				_filteredPosts = widget.persistentState.filteredPosts(widget.filter);
				_filteredItems = null; // Likely not built yet
				treeModeFurthestSeenIndexTop = 9999999;
				treeModeFurthestSeenIndexBottom = 0;
			}
			if (widget.threadIdentifier != oldWidget.threadIdentifier) {
				setState(() {
					_redCountBelow = 0;
					_whiteCountBelow = 0;
					_greyCount = 0;
				});
			}
			_onSlowScroll().then((result) {
				if (result) return;
				_waitForRebuildTimer = Timer.periodic(const Duration(milliseconds: 75), (t) async {
					if (!mounted || (await _onSlowScroll())) {
						t.cancel();
					}
				});
			});
		}
		else if (widget.listController.itemsLength != _lastListControllerItemsLength || widget.useTree != oldWidget.useTree) {
			if (widget.useTree) {
				_filteredItems = widget.listController.items.toList();
			}
			else {
				_filteredPosts = widget.persistentState.filteredPosts(widget.filter);
			}
			_onSlowScroll();
		}
		_lastListControllerItemsLength = widget.listController.items.length;
		if (widget.listController != oldWidget.listController) {
			oldWidget.listController.slowScrolls.removeListener(_onSlowScroll);
			widget.listController.slowScrolls.addListener(_onSlowScroll);
		}
		if (widget.listController.state?.updatingNow != oldWidget.listController.state?.updatingNow) {
			oldWidget.listController.state?.updatingNow.removeListener(_onUpdatingNowChange);
			widget.listController.state?.updatingNow.addListener(_onUpdatingNowChange);
		}
		if (widget.searching && !oldWidget.searching) {
			_hideMenu();
		}
	}

	@override
	void didChangeDependencies() {
		super.didChangeDependencies();
		final masterDetailHint = context.read<MasterDetailHint?>();
		final foreground = masterDetailHint == null // Dev board in settings
				 	|| masterDetailHint.primaryInterceptorKey.currentState?.primaryScrollControllerTracker.value != null;
		if (foreground) {
			_scheduleAdditionalSafeAreaInsetsShow();
		}
		else {
			_scheduleAdditionalSafeAreaInsetsHide();
		}
	}

	void _scheduleAdditionalSafeAreaInsetsShow() async {
		await Future.delayed(const Duration(milliseconds: 100));
		final box = _animatedPaddingKey.currentContext?.findRenderObject() as RenderBox?;
		if (box != null) {
			final bounds = Rect.fromPoints(
				box.localToGlobal(box.paintBounds.topLeft),
				// The padding for the primary button is already accounted for in 'main'
				box.localToGlobal(box.paintBounds.bottomRight - const Offset(0, 50))
			);
			setAdditionalSafeAreaInsets('menu${widget.boardSemanticId}', EdgeInsets.only(bottom: bounds.height));
		}
	}

	void _scheduleAdditionalSafeAreaInsetsHide() async {
		await Future.delayed(const Duration(milliseconds: 100));
		setAdditionalSafeAreaInsets('menu${widget.boardSemanticId}', EdgeInsets.zero);
	}

	void _showMenu() {
		_buttonsAnimationController.forward();
		_scheduleAdditionalSafeAreaInsetsShow();
	}

	void _hideMenu() {
		_buttonsAnimationController.reverse();
		_scheduleAdditionalSafeAreaInsetsHide();
	}

	Future<void> _onUpdatingNowChange() async {
		await WidgetsBinding.instance.endOfFrame;
		setState(() {});
	}

	@override
	Widget build(BuildContext context) {
		const radius = Radius.circular(8);
		const radiusAlone = BorderRadius.all(radius);
		final radiusStart = widget.reversed ? const BorderRadius.only(topRight: radius, bottomRight: radius) : const BorderRadius.only(topLeft: radius, bottomLeft: radius);
		final radiusEnd = widget.reversed ? const BorderRadius.only(topLeft: radius, bottomLeft: radius) : const BorderRadius.only(topRight: radius, bottomRight: radius);
		scrollToBottom() => widget.listController.animateTo((post) => false, orElseLast: (x) => true, alignment: 1.0);
		final youIds = widget.persistentState.youIds;
		return Stack(
			alignment: widget.reversed ? Alignment.bottomLeft : Alignment.bottomRight,
			children: [
				AnimatedBuilder(
					animation: _buttonsAnimationController,
					builder: (context, child) => Transform(
						transform: Matrix4.translationValues(0, 100 - _buttonsAnimation.value * 100, 0),
						child: FadeTransition(
							opacity: _buttonsAnimation,
							child: IgnorePointer(
								ignoring: _buttonsAnimation.value < 0.5,
								child: Visibility(
									visible: _buttonsAnimation.value > 0.1,
									child: child!
								)
							)
						)
					),
					child: AnimatedPadding(
						key: _animatedPaddingKey,
						duration: const Duration(milliseconds: 200),
						curve: Curves.ease,
						padding: EdgeInsets.only(bottom: _whiteCountAbove > 0 ? 100 : 50),
						child: SingleChildScrollView(
							reverse: true,
							primary: false,
							physics: const BouncingScrollPhysics(),
							child: Column(
								crossAxisAlignment: widget.reversed ? CrossAxisAlignment.start : CrossAxisAlignment.end,
								mainAxisSize: MainAxisSize.min,
								children: [
									for (final button in [
										('Scroll to top', const Icon(CupertinoIcons.arrow_up_to_line, size: 19), () => widget.listController.scrollController?.animateTo(
											0,
											duration: const Duration(milliseconds: 200),
											curve: Curves.ease
										)),
										(describeCount(youIds.length, 'submission'), const Icon(CupertinoIcons.person, size: 19), youIds.isEmpty ? null : () {
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
										(describeCount(_youIds.length, '(You)'), const Icon(CupertinoIcons.reply_all, size: 19), _youIds.isEmpty ? null : () {
												WeakNavigator.push(context, PostsPage(
													zone: widget.zone,
													postsIdsToShow: _youIds,
													onTap: (post) {
														widget.listController.animateTo((p) => p.id == post.id);
														WeakNavigator.pop(context);
													}
												)
											);
										}),
										(
											describeCount((widget.thread?.imageCount ?? 0) + 1, 'image'),
											const RotatedBox(
												quarterTurns: 1,
												child: Icon(CupertinoIcons.rectangle_split_3x1, size: 19)
											),
											() {
												const commonParentIds = [-101];
												final nextPostWithImage = widget.listController.items.skip(max(0, widget.listController.firstVisibleIndex - 1)).firstWhere((p) => p.item.attachments.isNotEmpty, orElse: () {
													return widget.listController.items.take(widget.listController.firstVisibleIndex).lastWhere((p) => p.item.attachments.isNotEmpty);
												});
												final imageboard = context.read<Imageboard>();
												Navigator.of(context).push(FullWidthCupertinoPageRoute(
													builder: (context) => ImageboardScope(
														imageboardKey: null,
														imageboard: imageboard,
														child: AttachmentsPage(
															attachments: widget.listController.items.expand((item) => item.item.attachments.map((a) => TaggedAttachment(
																attachment: a,
																semanticParentIds: commonParentIds.followedBy(item.parentIds)
															))).toList(),
															initialAttachment: TaggedAttachment(
																attachment: nextPostWithImage.item.attachments.first,
																semanticParentIds: commonParentIds.followedBy(nextPostWithImage.parentIds)
															),
															threadState: widget.persistentState
															//onChange: (attachment) => widget.listController.animateTo((p) => p.attachment?.id == attachment.id)
														)
													),
													showAnimations: context.read<EffectiveSettings>().showAnimations)
												);
											}
										),
										('Search', const Icon(CupertinoIcons.search, size: 19), widget.listController.focusSearch),
										if (widget.persistentState.useArchive) ('Live', const ImageboardIcon(), () {
											widget.persistentState.useArchive = false;
											widget.persistentState.save();
											setState(() {});
											widget.listController.blockAndUpdate();
										})
										else ('Archive', const Icon(CupertinoIcons.archivebox, size: 19), () async {
											widget.persistentState.useArchive = true;
											widget.persistentState.save();
											setState(() {});
											widget.listController.blockAndUpdate();
										}),
										if (widget.persistentState.autoTranslate) ('Original', const Icon(Icons.translate, size: 19), () {
											widget.persistentState.autoTranslate = false;
											widget.persistentState.translatedPosts.clear();
											widget.zone.clearTranslatedPosts();
											widget.persistentState.save();
											setState(() {});
										})
										else ('Translate', const Icon(Icons.translate, size: 19), () async {
											widget.persistentState.autoTranslate = true;
											for (final post in widget.persistentState.thread?.posts ?? []) {
												if (widget.zone.translatedPost(post.id) == null) {
													try {
														await widget.zone.translatePost(post.id);
													}
													catch (e) {
														// ignore, it will be shown on the post widget anyway
													}
												}
											}
											widget.persistentState.save();
											setState(() {});
										}),
										if (widget.useTree) ('Linear', const Icon(CupertinoIcons.list_bullet), () => setState(() {
											widget.persistentState.useTree = false;
											widget.persistentState.save();
										}))
										else ('Tree', const Icon(CupertinoIcons.list_bullet_indent), () => setState(() {
											widget.persistentState.useTree = true;
											widget.persistentState.save();
										})),
										('Scroll to new posts', const Icon(CupertinoIcons.arrow_down_to_line, size: 19), _whiteCountBelow <= 0 ? null : () {
											if (widget.useTree) {
												int targetIndex = widget.listController.items.toList().asMap().entries.tryFirstWhere((entry) {
													return entry.key > treeModeFurthestSeenIndexBottom &&
														(entry.value.item.id > widget.lastSeenIdBeforeLastUpdate || entry.value.representsKnownStubChildren.any((id) => id.childId > widget.lastSeenIdBeforeLastUpdate)) &&
														!entry.value.preCollapsed;
												})?.key ?? -1;
												if (targetIndex != -1) {
													while (widget.listController.isItemHidden(widget.listController.getItem(targetIndex)) == TreeItemCollapseType.childCollapsed) {
														// Align to parent if the target has been collapsed
														targetIndex++;
													}
													widget.listController.animateToIndex(targetIndex);
												}
											}
											else {
												widget.listController.animateTo((post) => post.id == widget.persistentState.lastSeenPostId, alignment: 1.0);
											}
										}),
										('Scroll to bottom', const Icon(CupertinoIcons.arrow_down_to_line, size: 19), scrollToBottom),
										if (developerMode) ('Override last-seen', const Icon(CupertinoIcons.arrow_up_down), () {
											final id = widget.listController.lastVisibleItem?.id;
											if (id != null) {
												widget.persistentState.lastSeenPostId = id;
												widget.persistentState.lastSeenPostIdNotifier.value = id;
												widget.persistentState.save();
											}
										})
									]) Padding(
										padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
										child: CupertinoButton.filled(
											disabledColor: CupertinoTheme.of(context).primaryColorWithBrightness(0.4),
											padding: const EdgeInsets.all(8),
											minSize: 0,
											onPressed: button.$3 == null ? null : () {
												lightHapticFeedback();
												button.$3?.call();
												_hideMenu();
											},
											child: Row(
												mainAxisSize: MainAxisSize.min,
												children: [
													Text(button.$1),
													const SizedBox(width: 8),
													button.$2
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
					onLongPress: () {
						scrollToBottom();
						mediumHapticFeedback();
					},
					child: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: widget.reversed ? CrossAxisAlignment.start : CrossAxisAlignment.end,
						children: [
							if (widget.searching)
								CupertinoButton(
									padding: EdgeInsets.zero,
									onPressed: widget.listController.state?.closeSearch,
									child: Container(
										decoration: BoxDecoration(
											borderRadius: radiusAlone,
											color: CupertinoTheme.of(context).primaryColor
										),
										margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
										padding: const EdgeInsets.all(8),
										child: Row(
											mainAxisSize: MainAxisSize.min,
											children: [
												Icon(CupertinoIcons.search, color: CupertinoTheme.of(context).scaffoldBackgroundColor, size: 19),
												const SizedBox(width: 8),
												Icon(CupertinoIcons.xmark, color: CupertinoTheme.of(context).scaffoldBackgroundColor, size: 19)
											]
										)
									)
								)
							else ...[
								if (widget.useTree && _whiteCountAbove > 0) CupertinoButton(
									padding: EdgeInsets.zero,
									child: Builder(
										builder: (context) {
											List<Widget> children = [
												if (_redCountAbove > 0) Container(
													decoration: BoxDecoration(
														borderRadius: radiusStart,
														color: CupertinoTheme.of(context).textTheme.actionTextStyle.color
													),
													padding: const EdgeInsets.all(8),
													child: Text(
														_redCountAbove.toString(),
														textAlign: TextAlign.center
													)
												),
												if (_whiteCountAbove > 0) Container(
													decoration: BoxDecoration(
														borderRadius: _redCountAbove <= 0 ? radiusAlone : radiusEnd,
														color: CupertinoTheme.of(context).primaryColor
													),
													padding: const EdgeInsets.all(8),
													child: Row(
														mainAxisSize: MainAxisSize.min,
														children: [
															Container(
																constraints: BoxConstraints(
																	minWidth: 24 * MediaQuery.textScaleFactorOf(context) * max(1, 0.5 * _whiteCountAbove.toString().length)
																),
																child: Text(
																	_whiteCountAbove.toString(),
																	style: TextStyle(
																		color: CupertinoTheme.of(context).scaffoldBackgroundColor
																	),
																	textAlign: TextAlign.center
																)
															),
															Icon(CupertinoIcons.arrow_up, color: CupertinoTheme.of(context).scaffoldBackgroundColor, size: 19)
														]
													)
												)
											];
											if (widget.reversed) {
												children = children.reversed.toList();
											}
											return Padding(
												padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
												child: Row(
													mainAxisSize: MainAxisSize.min,
													children: children
												)
											);
										}
									),
									onPressed: () {
										int targetIndex = widget.listController.items.toList().asMap().entries.tryLastWhere((entry) {
											return entry.key < treeModeFurthestSeenIndexTop &&
												(entry.value.item.id > widget.lastSeenIdBeforeLastUpdate || entry.value.representsKnownStubChildren.any((id) => id.childId > widget.lastSeenIdBeforeLastUpdate)) &&
												!entry.value.preCollapsed;
										})?.key ?? -1;
										if (targetIndex != -1) {
											while (widget.listController.isItemHidden(widget.listController.getItem(targetIndex)) == TreeItemCollapseType.childCollapsed) {
												// Align to parent if the target has been collapsed
												targetIndex--;
											}
											widget.listController.animateToIndex(targetIndex);
										}
									}
								),
								CupertinoButton(
									padding: EdgeInsets.zero,
									child: Builder(
										builder: (context) {
											List<Widget> children = [
												if (!widget.blocked && (widget.listController.state?.updatingNow.value ?? false) && widget.listController.state?.originalList != null) ...[
													const CupertinoActivityIndicator(),
													const SizedBox(width: 8),
												],
												if (_redCountBelow > 0) Container(
													decoration: BoxDecoration(
														borderRadius: radiusStart,
														color: CupertinoTheme.of(context).textTheme.actionTextStyle.color
													),
													padding: const EdgeInsets.all(8),
													child: Text(
														_redCountBelow.toString(),
														textAlign: TextAlign.center
													)
												),
												if (_whiteCountBelow == 0 || _greyCount > 0) Container(
													decoration: BoxDecoration(
														borderRadius: (_redCountBelow > 0) ? (_whiteCountBelow > 0 ? null : radiusEnd) : (_whiteCountBelow > 0 ? radiusStart : radiusAlone),
														color: CupertinoTheme.of(context).primaryColorWithBrightness(0.6)
													),
													padding: const EdgeInsets.all(8),
													child: Container(
														constraints: BoxConstraints(
															minWidth: 24 * MediaQuery.textScaleFactorOf(context) * max(1, 0.5 * _greyCount.toString().length)
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
												if (_whiteCountBelow > 0) Container(
													decoration: BoxDecoration(
														borderRadius: (_redCountBelow <= 0 && _greyCount <= 0) ? radiusAlone : radiusEnd,
														color: CupertinoTheme.of(context).primaryColor
													),
													padding: const EdgeInsets.all(8),
													child: Container(
														constraints: BoxConstraints(
															minWidth: 24 * MediaQuery.textScaleFactorOf(context) * max(1, 0.5 * _whiteCountBelow.toString().length)
														),
														child: Text(
															_whiteCountBelow.toString(),
															style: TextStyle(
																color: CupertinoTheme.of(context).scaffoldBackgroundColor
															),
															textAlign: TextAlign.center
														)
													)
												)
											];
											if (widget.reversed) {
												children = children.reversed.toList();
											}
											return Padding(
												padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
												child: Row(
													mainAxisSize: MainAxisSize.min,
													children: children
												)
											);
										}
									),
									onPressed: () {
										lightHapticFeedback();
										if (_buttonsAnimation.value > 0.5) {
											_hideMenu();
										}
										else {
											_showMenu();
										}
									}
								)
							]
						]
					)
				)
			]
		);
	}

	@override
	void dispose() {
		super.dispose();
		widget.listController.slowScrolls.removeListener(_onSlowScroll);
		widget.listController.state?.updatingNow.removeListener(_onUpdatingNowChange);
		widget.persistentState.lastSeenPostIdNotifier.removeListener(_updateCounts);
		_buttonsAnimationController.dispose();
		_waitForRebuildTimer?.cancel();
		WidgetsBinding.instance.addPostFrameCallback((_) {
			_scheduleAdditionalSafeAreaInsetsHide();
		});
	}
}
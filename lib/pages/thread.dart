import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

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
import 'package:chan/services/outbox.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/posts_image.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/share.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/attachment_viewer.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/notifying_icon.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:chan/widgets/reply_box.dart';
import 'package:chan/widgets/shareable_posts.dart';
import 'package:chan/widgets/util.dart';
import 'package:chan/widgets/weak_gesture_recognizer.dart';
import 'package:chan/widgets/weak_navigator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:chan/models/post.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:mutex/mutex.dart';
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
	final int markedReceiptsLength;
	final int treeHiddenIdsLength;
	final int hiddenPosterIdsLength;
	final bool? useTree;
	final PostSortingMethod postSortingMethod;
	final int overrideShowPostIdsLength;

	_PersistentThreadStateSnapshot.empty() :
		thread = null,
		hiddenPostIdsLength = 0,
		postsMarkedAsYouLength = 0,
		savedTime = null,
		receiptsLength = 0,
		markedReceiptsLength = 0,
		treeHiddenIdsLength = 0,
		hiddenPosterIdsLength = 0,
		useTree = null,
		postSortingMethod = PostSortingMethod.none,
		overrideShowPostIdsLength = 0;

	_PersistentThreadStateSnapshot.of(PersistentThreadState s) :
		thread = s.thread,
		hiddenPostIdsLength = s.hiddenPostIds.length,
		postsMarkedAsYouLength = s.postsMarkedAsYou.length,
		savedTime = s.savedTime,
		receiptsLength = s.receipts.length,
		markedReceiptsLength = s.receipts.where((receipt) => receipt.markAsYou).length,
		treeHiddenIdsLength = s.treeHiddenPostIds.length,
		hiddenPosterIdsLength = s.hiddenPosterIds.length,
		useTree = s.useTree,
		postSortingMethod = s.postSortingMethod,
		overrideShowPostIdsLength = s.overrideShowPostIds.length;
	
	@override
	bool operator == (Object o) =>
		identical(this, o) ||
		(o is _PersistentThreadStateSnapshot) &&
		(o.thread == thread) &&
		(o.hiddenPostIdsLength == hiddenPostIdsLength) &&
		(o.postsMarkedAsYouLength == postsMarkedAsYouLength) &&
		(o.savedTime == savedTime) &&
		(o.receiptsLength == receiptsLength) &&
		(o.markedReceiptsLength == markedReceiptsLength) &&
		(o.treeHiddenIdsLength == treeHiddenIdsLength) &&
		(o.hiddenPosterIdsLength == hiddenPosterIdsLength) &&
		(o.useTree == useTree) &&
		(o.postSortingMethod == postSortingMethod) &&
		(o.overrideShowPostIdsLength == overrideShowPostIdsLength);
	
	@override
	int get hashCode => Object.hash(thread, hiddenPostIdsLength, postsMarkedAsYouLength, savedTime, receiptsLength, markedReceiptsLength, treeHiddenIdsLength, hiddenPostIdsLength, useTree, postSortingMethod, overrideShowPostIdsLength);
}

extension _DisableUpdates on PersistentThreadState {
	bool get disableUpdates => (thread?.isDeleted ?? false) || (thread?.isArchived ?? false);
}

enum _AttachmentCachingStatus {
	uncached,
	cached,
	willNotAutoCacheDueToRateLimiting;
	bool get isCached => this == cached;
}

class ThreadPage extends StatefulWidget {
	final ThreadIdentifier thread;
	final int? initialPostId;
	final bool initiallyUseArchive;
	final int boardSemanticId;
	final String? initialSearch;
	final ValueChanged<ThreadIdentifier>? onWantChangeThread;

	const ThreadPage({
		required this.thread,
		this.initialPostId,
		this.initiallyUseArchive = false,
		required this.boardSemanticId,
		this.initialSearch,
		this.onWantChangeThread,
		Key? key
	}) : super(key: key);

	@override
	createState() => ThreadPageState();
}

class ThreadPageState extends State<ThreadPage> {
	late PersistentThreadState persistentState;
	final _shareButtonKey = GlobalKey(debugLabel: '_ThreadPageState._shareButtonKey');
	final _weakNavigatorKey = GlobalKey<WeakNavigatorState>(debugLabel: '_ThreadPageState._weakNavigatorKey');
	final _replyBoxKey = GlobalKey<ReplyBoxState>(debugLabel: '_ThreadPageState._replyBoxKey');
	final _listKey = GlobalKey<RefreshableListState>(debugLabel: '_ThreadPageState._listKey');

	bool _buildRefreshableList = false;
	late final RefreshableListController<Post> _listController;
	late PostSpanRootZoneData zone;
	bool blocked = false;
	late Listenable _threadStateListenable;
	int lastSavedPostsLength = 0;
	int lastHiddenMD5sLength = 0;
	_PersistentThreadStateSnapshot _lastPersistentThreadStateSnapshot = _PersistentThreadStateSnapshot.empty();
	bool _foreground = false;
	RequestPriority get _priority => _foreground ? RequestPriority.interactive : RequestPriority.functional;
	PersistentBrowserTab? _parentTab;
	final List<Function> _postUpdateCallbacks = [];
	final Set<int> newPostIds = {}; // basically a copy of unseenPostIds?
	bool _searching = false;
	bool _passedFirstLoad = false;
	bool _showingWatchMenu = false;
	final Map<Attachment, _AttachmentCachingStatus> _cached = {};
	final List<Attachment> _cachingQueue = [];
	final _indicatorKey = GlobalKey<_ThreadPositionIndicatorState>();
	(ThreadIdentifier, String)? _suggestedNewGeneral;
	ThreadIdentifier? _rejectedNewGeneralSuggestion;
	late final EasyListenable _glowingPostsAnimation;
	int? _glowingPostId;
	final _scrollLock = Mutex();

	void _onThreadStateListenableUpdate() {
		final persistence = context.read<Persistence>();
		final savedPostsLength = persistentState.thread?.posts.where((p) => persistence.getSavedPost(p) != null).length ?? 0;
		final hiddenMD5sLength = Persistence.settings.hiddenImageMD5s.length;
		final currentSnapshot = _PersistentThreadStateSnapshot.of(persistentState);
		if (currentSnapshot != _lastPersistentThreadStateSnapshot ||
				savedPostsLength != lastSavedPostsLength ||
				hiddenMD5sLength != lastHiddenMD5sLength) {
			_listController.state?.forceRebuildId++;
			setState(() {});
		}
		if (persistentState.thread != _lastPersistentThreadStateSnapshot.thread) {
			final tmpPersistentState = persistentState;
			_postUpdateCallbacks.add(() {
				if (mounted && persistentState == tmpPersistentState && !blocked) {
					int? newLastId;
					if (useTree) {
						final lastListIndex = _listController.lastVisibleIndex;
						if (lastListIndex != -1) {
							newLastId = _listController.items.take(lastListIndex).map((l) => l.item.id).fold<int>(0, max);
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
		_lastPersistentThreadStateSnapshot = currentSnapshot;
		if (persistentState.thread != null) {
			zone.addThread(persistentState.thread!);
		}
	}

	bool get useTree => persistentState.useTree ?? context.read<Persistence>().browserState.useTree ?? context.read<ImageboardSite>().useTree;
	String? get archiveName {
		if (persistentState.thread?.identifier == widget.thread) {
			return persistentState.thread?.archiveName;
		}
		return null;
	}

	Future<void> _ensurePostLoaded(int postId) async {
		Post? post = persistentState.thread?.posts_.tryFirstWhere((p) => p.id == postId);
		final usesStubs = persistentState.thread?.posts_.any((p) => p.isStub) ?? false;
		if (usesStubs) {
			if (post?.isStub ?? true) {
				post = (await _updateWithStubItems([ParentAndChildIdentifier(
					parentId: -1, // Should be ignored
					childId: postId
				)])).tryFirstWhere((p) => p.id == postId);
				_listController.state?.acceptNewList(zone.findThread(persistentState.id)!.posts);
			}
			if (post == null) {
				throw Exception('Could not get post');
			}
			if (post.parentId != null) {
				// Load up the chain
				if (post.parentId == -1) {
					if (mounted) {
						showToast(
							context: context,
							icon: CupertinoIcons.exclamationmark_triangle,
							message: 'Comment not found in thread!'
						);
					}
					throw Exception('No parent for post');
				}
				else {
					await _ensurePostLoaded(post.parentId!);
				}
			}
		}
		else if (post == null) {
			// Maybe not loaded yet?
			await _listController.update();
		}
	}

	Future<void> _glowPost(int postId, {Duration duration = const Duration(seconds: 2)}) async {
		if (!mounted) {
			return;
		}
		_glowingPostId = postId;
		_glowingPostsAnimation.didUpdate();
		await Future.delayed(duration);
		if (mounted && _glowingPostId == postId) {
			_glowingPostId = null;
			_glowingPostsAnimation.didUpdate();
		}
	}

	Future<void> scrollToPost(int postId) => _blockAndScrollToPostIfNeeded(
		target: (postId, 0),
		shouldBlock: false
	);

	Future<void> _blockAndScrollToPostIfNeeded({
		Duration delayBeforeScroll = Duration.zero,
		(int, double)? target,
		bool shouldBlock = true
	}) => _scrollLock.protect(() async {
		if (persistentState.thread == null) {
			// too early to try to scroll
			return;
		}
		final (int, double)? scrollTo;
		bool glow = false;
		if (target != null) {
			scrollTo = target;
			glow = true;
		}
		else if (widget.initialPostId != null) {
			scrollTo = (widget.initialPostId!, 0);
			glow = true;
		}
		else if (context.read<PersistentBrowserTab?>()?.initialPostId[widget.thread] != null) {
			scrollTo = (context.read<PersistentBrowserTab>().initialPostId[widget.thread]!, 0);
			glow = true;
			context.read<PersistentBrowserTab?>()?.initialPostId.remove(widget.thread);
		}
		else if (persistentState.firstVisiblePostId != null) {
			scrollTo = (persistentState.firstVisiblePostId!, persistentState.firstVisiblePostAlignment ?? 0);
		}
		else if (persistentState.lastSeenPostId != null) {
			scrollTo = (persistentState.lastSeenPostId!, 1);
		}
		else {
			scrollTo = null;
		}
		if (persistentState.thread != null && scrollTo != null) {
			Post? target = _listController.items.tryFirstWhere((p) => p.id == scrollTo?.$1)?.item;
			if (target != null && _listController.isOnscreen(target)) {
				if (glow) {
					_glowPost(scrollTo.$1);
				}
				return;
			}
			setState(() {
				blocked = shouldBlock;
			});
			try {
				await _ensurePostLoaded(scrollTo.$1);
				setState(() {});
				await WidgetsBinding.instance.endOfFrame;
				target = _listController.items.tryFirstWhere((p) => p.id == scrollTo?.$1)?.item;
				if (target != null && _listController.isOnscreen(target)) {
					setState(() {
						blocked = false;
					});
					return;
				}
				await Future.delayed(delayBeforeScroll);
				await WidgetsBinding.instance.endOfFrame;
				await _listController.animateTo(
					(post) => post.id == scrollTo!.$1,
					orElseLast: (post) => post.id <= scrollTo!.$1,
					alignment: scrollTo.$2,
					duration: const Duration(milliseconds: 1)
				);
				await WidgetsBinding.instance.endOfFrame;
				final remainingPx = (_listController.scrollController?.position.extentAfter ?? 9999) -
					((_listController.state?.updatingNow.value != null) ? 64 : 0);
				if (remainingPx < 32) {
					// Close to the end, just round-to there
					_listController.scrollController!.position.jumpTo(_listController.scrollController!.position.maxScrollExtent);
				}
				if (glow) {
					_glowPost(scrollTo.$1);
				}
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
		}
	});

	void _maybeUpdateWatch() {
		final notifications = context.read<Notifications>();
		final threadWatch = persistentState.threadWatch;
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
		_updateCached(onscreenOnly: true);
		if (persistentState.thread != null && !blocked && lastItem != null && _foreground) {
			final newLastSeen = lastItem.id;
			if (newLastSeen > (persistentState.lastSeenPostId ?? 0)) {
				persistentState.lastSeenPostId = newLastSeen;
				runWhenIdle(const Duration(milliseconds: 500), persistentState.save);
			}
			final firstItem = _listController.firstVisibleItem;
			if (firstItem != null) {
				if (persistentState.firstVisiblePostId != firstItem.item.id) {
					runWhenIdle(const Duration(milliseconds: 500), persistentState.save);
				}
				persistentState.firstVisiblePostId = firstItem.item.id;
				persistentState.firstVisiblePostAlignment = firstItem.alignment;
			}
			final firstIndex = _indicatorKey.currentState?.furthestSeenIndexTop;
			final lastIndex = _indicatorKey.currentState?.furthestSeenIndexBottom;
			if (firstIndex != null && lastIndex != null) {
				final items = _listController.items.toList();
				final firstIndexClamped = firstIndex.clamp(0, items.length - 1);
				final seenIds = items.sublist(firstIndexClamped, lastIndex.clamp(firstIndexClamped, items.length - 1) + 1).where((p) => !_listController.isItemHidden(p).isHidden).map((p) => p.item.id);
				final lengthBefore = persistentState.unseenPostIds.data.length;
				persistentState.unseenPostIds.data.removeAll(seenIds);
				if (lengthBefore != persistentState.unseenPostIds.data.length) {
					persistentState.didUpdate();
					runWhenIdle(const Duration(milliseconds: 250), persistentState.save);
				}
			}
		}
	}

	Future<void> _updateCached({required bool onscreenOnly}) async {
		final attachments = (onscreenOnly ? _listController.visibleItems : _listController.items).expand((p) => p.item.attachments).toSet();
		await Future.wait(attachments.map((attachment) async {
			if (_cached[attachment] == _AttachmentCachingStatus.cached) return;
			_cached[attachment] = switch (await (await optimisticallyFindCachedFile(attachment))?.exists()) {
				true => _AttachmentCachingStatus.cached,
				null || false => _cached[attachment] ?? _AttachmentCachingStatus.uncached
			};
		}));
	}

	Future<void> _cacheAttachments({required bool automatic}) async {
		final settings = Settings.instance;
		await _updateCached(onscreenOnly: false);
		if (!mounted) {
			return;
		}
		_cachingQueue.clear();
		_cachingQueue.addAll(_cached.entries.where((e) => e.value == _AttachmentCachingStatus.uncached).map((e) => e.key));
		int newlyRateLimited = 0;
		while (_cachingQueue.isNotEmpty) {
			if (!mounted) {
				break;
			}
			if (automatic && !settings.autoCacheAttachments) {
				_cachingQueue.clear();
				showToast(
					context: context,
					icon: Icons.cell_tower,
					message: 'Stopping preload'
				);
				_indicatorKey.currentState?.setState(() {});
				break;
			}
			final attachment = _cachingQueue.removeAt(0);
			if (attachment.isRateLimited) {
				// Shouldn't preload as it will probably ban us from the server for too many requests
				newlyRateLimited++;
				_cached[attachment] = _AttachmentCachingStatus.willNotAutoCacheDueToRateLimiting;
				continue;
			}
			final controller = AttachmentViewerController(
				context: context,
				attachment: attachment,
				imageboard: context.read<Imageboard>()
			);
			try {
				await controller.preloadFullAttachment();
			}
			catch (e) {
				if (mounted) {
					showToast(
						context: context,
						message: 'Error getting attachment: ${e.toStringDio()}',
						icon: CupertinoIcons.exclamationmark_triangle
					);
				}
			}
			_cached[attachment] = _AttachmentCachingStatus.cached;
			_indicatorKey.currentState?.setState(() {});
		}
		final count = automatic ? newlyRateLimited : _cached.values.countOf(_AttachmentCachingStatus.willNotAutoCacheDueToRateLimiting);
		if (mounted && count > 0) {
			showToast(
				context: context,
				message: 'Skipped caching ${describeCount(count, 'file')} (${persistentState.thread?.archiveName ?? 'archive'} has rate limits)',
				icon: CupertinoIcons.exclamationmark_circle
			);
		}
	}

	@override
	void initState() {
		super.initState();
		_glowingPostsAnimation = EasyListenable();
		_listController = RefreshableListController();
		persistentState = context.read<Persistence>().getThreadState(widget.thread, updateOpenedTime: true);
		persistentState.ensureThreadLoaded().then((_) => _onThreadStateListenableUpdate());
		persistentState.useArchive |= widget.initiallyUseArchive;
		persistentState.useArchive |= context.read<PersistentBrowserTab?>()?.initiallyUseArchive[widget.thread] ?? false;
		persistentState.save();
		_maybeUpdateWatch();
		persistentState.thread?.preinit();
		final imageboard = context.read<Imageboard>();
		final threadFromCatalogCache = imageboard.site.getThreadFromCatalogCache(widget.thread);
		zone = PostSpanRootZoneData.multi(
			primaryThread: widget.thread,
			style: useTree ? PostSpanZoneStyle.tree : PostSpanZoneStyle.linear,
			threads: [
				if (persistentState.thread != null) persistentState.thread!
				else if (threadFromCatalogCache != null) threadFromCatalogCache
			],
			imageboard: imageboard,
			semanticRootIds: [widget.boardSemanticId, 0],
			onNeedScrollToPost: (post) async {
				_weakNavigatorKey.currentState!.popAllExceptFirst();
				if (post.threadIdentifier == widget.thread) {
					await Future.wait([
						Future.delayed(const Duration(milliseconds: 150)),
						_ensurePostLoaded(post.id)
					]);
					setState(() {});
					await WidgetsBinding.instance.endOfFrame;
					await _listController.animateTo((val) => val.id == post.id);
					await _glowPost(post.id);
				}
				else {
					(context.read<GlobalKey<NavigatorState>?>()?.currentState ?? Navigator.of(context)).push(adaptivePageRoute(
						builder: (ctx) => ImageboardScope(
							imageboardKey: null,
							imageboard: context.read<Imageboard>(),
							overridePersistence: context.read<Persistence>(),
							child: ThreadPage(
								thread: post.threadIdentifier,
								initialPostId: post.id,
								boardSemanticId: -1
							)
						)
					));
				}
			},
			isPostOnscreen: (id) {
				if (_weakNavigatorKey.currentState?.stack.isNotEmpty ?? false) {
					// No posts visible, something is covering them
					return false;
				}
				final post = zone.findPost(id);
				if (post == null) {
					return false;
				}
				return _listController.isOnscreen(post);
			},
			glowOtherPost: (id, glow) {
				if (glow) {
					_glowingPostId = id;
					_glowingPostsAnimation.didUpdate();
				}
				else if (_glowingPostId == id) {
					_glowingPostId = null;
					_glowingPostsAnimation.didUpdate();
				}
			},
			onNeedUpdateWithStubItems: (ids) async {
				await _updateWithStubItems(ids);
				_listController.state?.acceptNewList(zone.findThread(persistentState.id)!.posts);
			}
		);
		Future.delayed(const Duration(milliseconds: 50), () {
			_threadStateListenable = context.read<Persistence>().listenForPersistentThreadStateChanges(widget.thread);
			_threadStateListenable.addListener(_onThreadStateListenableUpdate);
		});
		_listController.slowScrolls.addListener(_onSlowScroll);
		context.read<PersistentBrowserTab?>()?.threadPageState = this;
		if (!(context.read<MasterDetailHint?>()?.twoPane ?? false) &&
		    persistentState.lastSeenPostId != null &&
				(persistentState.thread?.posts_.length ?? 0) > 20) {
			// Likely to lag if building/scrolling done during page transition animation
			Future.delayed(const Duration(milliseconds: 450), () => setState(() {
				_buildRefreshableList = true;
			}));
			_scrollIfWarranted(const Duration(milliseconds: 500));
		}
		else {
			_buildRefreshableList = true;
			_scrollIfWarranted();
		}
		_searching |= widget.initialSearch?.isNotEmpty ?? false;
		if (Settings.instance.autoCacheAttachments) {
			_listController.waitForItemBuild(0).then((_) => _cacheAttachments(automatic: true));
		}
		else {
			_listController.waitForItemBuild(0).then((_) => _updateCached(onscreenOnly: false));
		}
		newPostIds.addAll(persistentState.unseenPostIds.data);
		if (persistentState.disableUpdates) {
			_checkForNewGeneral();
			_loadReferencedThreads(setStateAfterwards: true);
		}
	}

	@override
	void didUpdateWidget(ThreadPage oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (widget.thread != oldWidget.thread) {
			_cached.clear();
			_cachingQueue.clear();
			_passedFirstLoad = false;
			_threadStateListenable.removeListener(_onThreadStateListenableUpdate);
			_threadStateListenable = context.read<Persistence>().listenForPersistentThreadStateChanges(widget.thread);
			_threadStateListenable.addListener(_onThreadStateListenableUpdate);
			_suggestedNewGeneral = null;
			_rejectedNewGeneralSuggestion = null;
			_weakNavigatorKey.currentState!.popAllExceptFirst();
			persistentState.save(); // Save old state in case it had pending scroll update to save
			persistentState = context.read<Persistence>().getThreadState(widget.thread, updateOpenedTime: true);
			persistentState.ensureThreadLoaded().then((_) => _onThreadStateListenableUpdate());
			persistentState.useArchive |= widget.initiallyUseArchive;
			persistentState.useArchive |= context.read<PersistentBrowserTab?>()?.initiallyUseArchive[widget.thread] ?? false;
			final oldZone = zone;
			Future.delayed(const Duration(milliseconds: 100), () => oldZone.dispose());
			final imageboard = context.read<Imageboard>();
			final threadFromCatalogCache = imageboard.site.getThreadFromCatalogCache(widget.thread);
			zone = PostSpanRootZoneData.multi(
				primaryThread: widget.thread,
				threads: [
					if (persistentState.thread != null) persistentState.thread!
					else if (threadFromCatalogCache != null) threadFromCatalogCache
				],
				imageboard: imageboard,
				onNeedScrollToPost: oldZone.onNeedScrollToPost,
				isPostOnscreen: oldZone.isPostOnscreen,
				glowOtherPost: oldZone.glowOtherPost,
				onNeedUpdateWithStubItems: oldZone.onNeedUpdateWithStubItems,
				semanticRootIds: [widget.boardSemanticId, 0],
				style: oldZone.style
			);
			_maybeUpdateWatch();
			persistentState.save();
			_scrollIfWarranted();
			if (Settings.instance.autoCacheAttachments) {
				_listController.waitForItemBuild(0).then((_) => _cacheAttachments(automatic: true));
			}
			newPostIds.clear();
			newPostIds.addAll(persistentState.unseenPostIds.data);
			if (persistentState.disableUpdates) {
				_checkForNewGeneral();
				_loadReferencedThreads(setStateAfterwards: true);
			}
			setState(() {});
		}
		else if (widget.initialPostId != oldWidget.initialPostId && widget.initialPostId != null) {
			_ensurePostLoaded(widget.initialPostId!).then((_) async {
				setState(() {});
				await WidgetsBinding.instance.endOfFrame;
				await _listController.animateTo((post) => post.id == widget.initialPostId!, orElseLast: (post) => post.id <= widget.initialPostId!, alignment: 0.0, duration: const Duration(milliseconds: 500));
				await _glowPost(widget.initialPostId!);
			});
		}
		_searching |= widget.initialSearch?.isNotEmpty ?? false;
	}

	@override
	void didChangeDependencies() {
		super.didChangeDependencies();
		_checkForeground();
		_parentTab = context.watch<PersistentBrowserTab?>();
		setHandoffUrl(_foreground ? context.read<ImageboardSite>().getWebUrl(
			board: widget.thread.board,
			threadId: widget.thread.id,
			archiveName: archiveName
		) : null);
	}

	Future<void> _scrollIfWarranted([Duration delayBeforeScroll = Duration.zero]) async {
		final int? explicitScrollToId = widget.initialPostId ?? context.read<PersistentBrowserTab?>()?.initialPostId[widget.thread];
		if (explicitScrollToId != widget.thread.id && (explicitScrollToId != null || !(useTree && (context.read<ImageboardSite>().isReddit || context.read<ImageboardSite>().isHackerNews) && persistentState.firstVisiblePostId == null))) {
			await _blockAndScrollToPostIfNeeded(delayBeforeScroll: delayBeforeScroll);
		}
	}

	void _showGallery({
		bool initiallyShowChrome = false,
		TaggedAttachment? initialAttachment,
		bool initiallyShowGrid = false
	}) {
		final commonParentIds = [widget.boardSemanticId, 0];
		List<TaggedAttachment> attachments = _listController.items.expand((item) {
			if (item.representsStubChildren) {
				return const <TaggedAttachment>[];
			}
			return item.item.attachments.map((a) => TaggedAttachment(
				attachment: a,
				semanticParentIds: commonParentIds.followedBy(item.parentIds)
			));
		}).toList();
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
				for (final post in persistentState.thread?.posts ?? const Iterable.empty())
					for (final attachment in post.attachments)
						attachment: post.replyIds.length
			},
			isAttachmentAlreadyDownloaded: persistentState.isAttachmentDownloaded,
			onAttachmentDownload: persistentState.didDownloadAttachment,
			initiallyShowChrome: initiallyShowChrome,
			initiallyShowGrid: initiallyShowGrid,
			initialAttachment: initialAttachment,
			onChange: (attachment) {
				if (!_listController.scrollControllerPositionLooksGood) {
					return;
				}
				if (_listController.state?.searching ?? false) {
					return;
				}
				_listController.animateToIfOffscreen((p) => p.attachments.any((a) {
					return a.id == attachment.attachment.id;
				}));
			},
			heroOtherEndIsBoxFitCover: Settings.instance.squareThumbnails
		);
	}

	void _showGalleryFromNextImage({
		bool initiallyShowGrid = false
	}) {
		if (Settings.instance.showImages(context, widget.thread.board)) {
			RefreshableListItem<Post>? nextPostWithImage = _listController.items.skip(_listController.firstVisibleIndex).tryFirstWhere((p) => p.item.attachments.isNotEmpty);
			nextPostWithImage ??= _listController.items.take(_listController.firstVisibleIndex).tryFirstWhere((p) => p.item.attachments.isNotEmpty);
			if (nextPostWithImage != null) {
				_showGallery(
					initialAttachment: TaggedAttachment(
						attachment: nextPostWithImage.item.attachments.first,
						semanticParentIds: [widget.boardSemanticId, 0].followedBy(nextPostWithImage.parentIds)
					),
					initiallyShowGrid: initiallyShowGrid
				);
			}
		}
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

	Future<void> _replacePostFromArchive(Post post) async {
		try {
			final tmpPersistentState = persistentState;
			final site = context.read<ImageboardSite>();
			final asArchived = await site.getPostFromArchive(post.board, post.id, priority: RequestPriority.interactive);
			tmpPersistentState.thread?.mergePosts(null, [asArchived], site.placeOrphanPost);
			await tmpPersistentState.save();
			setState(() {});
		}
		catch (e) {
			if (mounted) {
				showToast(
					context: context,
					message: e.toStringDio(),
					icon: CupertinoIcons.exclamationmark_triangle
				);
			}
		}
	}

	Future<void> _switchToLive() async {
		persistentState.useArchive = false;
		await persistentState.save();
		setState(() {});
		await _listController.blockAndUpdate();
	}

	Future<void> _tapWatchButton({required bool long}) async {
		if (_showingWatchMenu) {
			return;
		}
		final notifications = context.read<Notifications>();
		final watch = persistentState.threadWatch;
		final defaultThreadWatch = Settings.instance.defaultThreadWatch;
		if (defaultThreadWatch == null || long || !(watch?.settingsEquals(defaultThreadWatch) ?? true)) {
			_showingWatchMenu = true;
			await _weakNavigatorKey.currentState?.push(ThreadWatchControlsPage(
				thread: widget.thread
			));
			_showingWatchMenu = false;
			return;
		}
		if (watch == null) {
			notifications.subscribeToThread(
				thread: widget.thread,
				lastSeenId: persistentState.lastSeenPostId ?? widget.thread.id,
				localYousOnly: defaultThreadWatch.localYousOnly,
				pushYousOnly: defaultThreadWatch.pushYousOnly,
				youIds: persistentState.youIds,
				push: defaultThreadWatch.push,
				foregroundMuted: defaultThreadWatch.foregroundMuted
			);
		}
		else {
			notifications.unsubscribeFromThread(widget.thread);
		}
		setState(() {});
	}

	static final _newGeneralPattern = RegExp(r'(?<=^| )\/([^/ ]+)\/(?=$| )');
	Future<void> _checkForNewGeneral() async {
		if (widget.onWantChangeThread == null) {
			// Not possible to switch thread
			return;
		}
		final imageboard = context.read<Imageboard>();
		if (!(persistentState.disableUpdates ||
			    (persistentState.thread?.replyCount ?? 1) >
					 ((imageboard.persistence.maybeGetBoard(widget.thread.board)?.threadCommentLimit ?? 9999999) - 5))) {
		  // No reason to check yet
			return;
		}
		final match = _newGeneralPattern.firstMatch('${persistentState.thread?.title} ${persistentState.thread?.posts_.tryFirst?.name} ${persistentState.thread?.posts_.tryFirst?.text}');
		if (match == null) {
			// no /general/ found
			return;
		}
		final innerPattern = match.group(1)!.toLowerCase();
		if (imageboard.persistence.maybeGetBoard(innerPattern) != null) {
			// This is just someone typing the name of a board
			return;
		}
		final pattern = match.group(0)!.toLowerCase();
		if (_suggestedNewGeneral?.$2 == pattern) {
			// Already have a suggested general
			return;
		}
		await WidgetsBinding.instance.endOfFrame; // Hack - let board win lock first
		final catalog = await imageboard.site.getCatalog(widget.thread.board, priority: _priority, acceptCachedAfter: DateTime.now().subtract(const Duration(seconds: 30)));
		ThreadIdentifier candidate = widget.thread;
		for (final thread in catalog) {
			if (thread.id > candidate.id) {
				final threadPattern = _newGeneralPattern.firstMatch('${thread.title} ${thread.posts_.tryFirst?.name} ${thread.posts_.tryFirst?.text}')?.group(0)?.toLowerCase();
				if (threadPattern == pattern) {
					candidate = thread.identifier;
				}
			}
		}
		if (candidate != widget.thread && candidate != _rejectedNewGeneralSuggestion) {
			setState(() {
				_suggestedNewGeneral = (candidate, pattern);
			});
		}
	}

	Future<bool> _loadReferencedThreads({bool setStateAfterwards = false}) async {
		final imageboard = context.read<Imageboard>();
		final tmpZone = zone;
		final newThread = persistentState.thread;
		if (newThread == null || tmpZone.primaryThread != newThread.identifier) {
			// The thread switched
			return false;
		}
		final crossThreads = <ThreadIdentifier, Set<int>>{};
		for (final id in newThread.posts.expand((p) => p.span.referencedPostIdentifiers)) {
			if (id.threadId == newThread.id || id.postId == id.threadId || id.board != newThread.board) {
				continue;
			}
			crossThreads.putIfAbsent(id.thread, () => {}).add(id.postId);
		}
		// Only fetch threads with multiple cross-referenced posts
		bool loadedAnything = false;
		crossThreads.removeWhere((thread, postIds) => postIds.length < 2);
		for (final pair in crossThreads.entries) {
			final id = pair.key;
			final postIds = pair.value;
			if (tmpZone.findThread(id.id) != null) {
				// This thread is already fetched
				continue;
			}
			loadedAnything = true;
			final threadState = imageboard.persistence.getThreadState(id);
			final cachedThread = await threadState.getThread();
			if (cachedThread != null && postIds.every((neededId) => cachedThread.posts_.any((p) => p.id == neededId))) {
				// Thread is already cached, and it has all the posts we need
				tmpZone.addThread(cachedThread);
				continue;
			}
			try {
				final newThread = await imageboard.site.getThread(id, priority: _priority);
				threadState.thread = newThread;
				tmpZone.addThread(newThread);
			}
			catch (e, st) {
				print(e);
				print(st);
			}
		}
		if (setStateAfterwards && mounted) {
			setState(() {});
		}
		return loadedAnything;
	}

	Future<Thread> _getUpdatedThread() async {
		final tmpPersistentState = persistentState;
		final site = context.read<ImageboardSite>();
		final settings = Settings.instance;
		final notifications = context.read<Notifications>();
		final bool firstLoad = tmpPersistentState.thread == null;
		// The thread might switch in this interval
		_checkForeground();
		final Thread newThread;
		if (tmpPersistentState.useArchive) {
			newThread = await site.getThreadFromArchive(widget.thread, priority: _priority);
		}
		else {
			try {
				newThread = await site.getThread(widget.thread, variant: tmpPersistentState.variant, priority: _priority);
			}
			on ThreadNotFoundException {
				if (site.archives.isEmpty) {
					tmpPersistentState.thread?.isDeleted = true;
				}
				rethrow;
			}
		}
		bool shouldScroll = false;
		final watch = tmpPersistentState.threadWatch;
		if (watch != null && newThread.identifier == widget.thread && mounted) {
			_checkForeground();
			notifications.updateLastKnownId(watch, newThread.posts.last.id, foreground: _foreground);
		}
		newThread.mergePosts(tmpPersistentState.thread, tmpPersistentState.thread?.posts ?? [], site.placeOrphanPost);
		final loadedReferencedThreads = await _loadReferencedThreads();
		_checkForNewGeneral();
		if (newThread != tmpPersistentState.thread) {
			await newThread.preinit();
			tmpPersistentState.thread = newThread;
			if (persistentState == tmpPersistentState) {
				zone.addThread(newThread);
				if (firstLoad) shouldScroll = true;
				if (persistentState.autoTranslate) {
					// Translate new posts
					() async {
						for (final post in newThread.posts) {
							if (zone.translatedPost(post.id) == null) {
								await zone.translatePost(post);
							}
						}
					}();
				}
			}
			await tmpPersistentState.save();
			_postUpdateCallbacks.add(() async {
				if (persistentState == tmpPersistentState && !blocked) {
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
			_postUpdateCallbacks.add(() => _updateCached(onscreenOnly: false));
			if (settings.autoCacheAttachments) {
				_postUpdateCallbacks.add(() => _cacheAttachments(automatic: true));
			}
		}
		else if (firstLoad && tmpPersistentState == persistentState) {
			shouldScroll = true;
		}
		final newPostIdsBefore = newPostIds.toSet();
		// unseenPostIds is filled-up during PersistentThreadState thread setter
		// This will clear out all the posts which were "seen" since last update
		// and get the new posts from the new thread
		newPostIds.clear();
		newPostIds.addAll(tmpPersistentState.unseenPostIds.data);
		if (loadedReferencedThreads || !setEquals(newPostIdsBefore, newPostIds)) {
			_listController.state?.forceRebuildId++; // To force widgets to re-build and re-compute [highlight]
		}
		// Don't show data if the thread switched
		_postUpdateCallbacks.add(() async {
			if (!mounted) return;
			// Trigger update of counts in case new post is drawn fully onscreen
			_listController.slowScrolls.didUpdate();
		});
		if (shouldScroll) {
			_scrollIfWarranted(const Duration(milliseconds: 500))
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
		return tmpPersistentState.thread ?? newThread;
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
		final newChildren = await site.getStubPosts(thread.identifier, ids, priority: RequestPriority.interactive);
		if (widget.thread != thread.identifier) {
			throw Exception('Thread changed');
		}
		thread.mergePosts(null, newChildren, site.placeOrphanPost);
		if (ids.length == 1 && ids.single.childId == ids.single.parentId) {
			// Clear hasOmittedReplies in case it has only omitted shadowbanned replies
			thread.posts_.tryFirstWhere((p) => p.id == ids.single.childId)?.hasOmittedReplies = false;
		}
		zone.addThread(thread);
		persistentState.save();
		return thread.posts;
	}

	Future<void> _popOutReplyBox(ValueChanged<ReplyBoxState>? onInitState) async {
		final imageboard = context.read<Imageboard>();
		final theme = context.read<SavedTheme>();
		await showAdaptiveModalPopup(
			context: context,
			builder: (ctx) => ImageboardScope(
				imageboardKey: null,
				imageboard: imageboard,
				child: ChangeNotifierProvider<PostSpanZoneData>.value(
					value: zone,
					child: Padding(
						padding: MediaQuery.viewInsetsOf(ctx),
						child: Container(
							color: theme.backgroundColor,
							child: ReplyBox(
								board: widget.thread.board,
								threadId: widget.thread.id,
								onInitState: onInitState,
								isArchived: persistentState.thread?.isArchived ?? false,
								initialDraft: persistentState.draft,
								onDraftChanged: (draft) async {
									persistentState.draft = draft;	
									await SchedulerBinding.instance.endOfFrame;
									_replyBoxKey.currentState?.draft = draft;
									runWhenIdle(const Duration(seconds: 3), persistentState.save);
								},
								onReplyPosted: (receipt) async {
									if (imageboard.site.supportsPushNotifications) {
										await promptForPushNotificationsIfNeeded(context);
									}
									if (!mounted) return;
									if (persistentState.lastSeenPostId == persistentState.thread?.posts.last.id) {
										// If already at the bottom, pre-mark the created post as seen
										persistentState.lastSeenPostId = receipt.id;
										runWhenIdle(const Duration(milliseconds: 500), persistentState.save);
									}
									_listController.update();
									Navigator.of(ctx).pop();
								},
								fullyExpanded: true
							)
						)
					)
				)
			)
		);
	}

	@override
	Widget build(BuildContext context) {
		final site = context.watch<ImageboardSite>();
		final theme = context.watch<SavedTheme>();
		String title = site.formatBoardName(widget.thread.board);
		final threadTitle = persistentState.thread?.title ?? site.getThreadFromCatalogCache(widget.thread)?.title;
		if (threadTitle != null) {
			title += ' - ${Settings.instance.filterProfanity(threadTitle)}';
		}
		else {
			final threadText = (persistentState.thread ?? site.getThreadFromCatalogCache(widget.thread))?.posts_.first.span.buildText();
			if (threadText != null) {
				title += ' - $threadText';
			}
			else {
				if (title.endsWith('/')) {
					title += '${widget.thread.id}';
				}
				else {
					title += '/${widget.thread.id}';
				}
			}
		}
		if (persistentState.thread?.isDeleted ?? false) {
			title = '(Deleted) $title';
		}
		else if (persistentState.thread?.isArchived ?? false) {
			title = '(Archived) $title';
		}
		if (!site.supportsMultipleBoards) {
			if (threadTitle != null) {
				title = Settings.instance.filterProfanity(threadTitle);
			}
			else {
				title = widget.thread.id.toString();
			}
		}
		final watch = context.select<Persistence, ThreadWatch?>((_) => persistentState.threadWatch);
		final reverseIndicatorPosition = Settings.showListPositionIndicatorsOnLeftSetting.watch(context);
		zone.postSortingMethods = [
			if (persistentState.postSortingMethod == PostSortingMethod.replyCount) (a, b) => b.replyCount.compareTo(a.replyCount)
			else if ((site.isReddit || site.isHackerNews) && !useTree) (a, b) => a.id.compareTo(b.id)
		];
		zone.style = useTree ? PostSpanZoneStyle.tree : PostSpanZoneStyle.linear;
		final treeModeInitiallyCollapseSecondLevelReplies = context.select<Persistence, bool>((s) => s.browserState.treeModeInitiallyCollapseSecondLevelReplies);
		final treeModeCollapsedPostsShowBody = context.select<Persistence, bool>((s) => s.browserState.treeModeCollapsedPostsShowBody);
		final treeModeRepliesToOPAreTopLevel = context.select<Persistence, bool>((s) => s.browserState.treeModeRepliesToOPAreTopLevel);
		final treeModeNewRepliesAreLinear = context.select<Persistence, bool>((s) => s.browserState.treeModeNewRepliesAreLinear);
		final settings = context.watch<Settings>();
		Duration? autoUpdateDuration = Duration(seconds: _foreground ? settings.currentThreadAutoUpdatePeriodSeconds : settings.backgroundThreadAutoUpdatePeriodSeconds);
		if (autoUpdateDuration.inDays > 1) {
			autoUpdateDuration = null;
		}
		final variant = persistentState.variant ?? persistentState.thread?.suggestedVariant;
		return PopScope(
			canPop: !(_replyBoxKey.currentState?.show ?? false),
			onPopInvoked: (didPop) async {
				if (!didPop) {
					_replyBoxKey.currentState?.hideReplyBox();
					setState(() {});
				}
			},
			child: FilterZone(
				filter: persistentState.threadFilter,
				child: MetaFilterZone(
					child: MultiProvider(
						providers: [
							Provider.value(
								value: ReplyBoxZone(
									onTapPostId: (int threadId, int id) {
										if ((context.read<MasterDetailHint?>()?.location.isVeryConstrained ?? false) && _replyBoxKey.currentState?.show != true) {
											_popOutReplyBox((state) => state.onTapPostId(threadId, id));
										}
										else {
											_replyBoxKey.currentState?.onTapPostId(threadId, id);
										}
										setState(() {});
									},
									onQuoteText: (String text, {required int fromId, required int fromThreadId, required bool includeBacklink}) {
										if ((context.read<MasterDetailHint?>()?.location.isVeryConstrained ?? false) && _replyBoxKey.currentState?.show != true) {
											_popOutReplyBox((state) => state.onQuoteText(text, fromId: fromId, fromThreadId: fromThreadId, includeBacklink: includeBacklink));
										}
										else {
											_replyBoxKey.currentState?.onQuoteText(text, fromId: fromId, fromThreadId: fromThreadId, includeBacklink: includeBacklink);
										}
										setState(() {});
									}
								)
							),
							ChangeNotifierProvider<PostSpanZoneData>.value(value: zone)
						],
						child: AdaptiveScaffold(
							resizeToAvoidBottomInset: false,
							bar: AdaptiveBar(
								title: GestureDetector(
									onTap: () {
										alert(context, 'Thread title', title);
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
														minFontSize: 17,
														maxLines: 1,
														overflow: TextOverflow.ellipsis,
													)
												)
											]
										)
									)
								),
								actions: [
									GestureDetector(
										onLongPress: () => _tapWatchButton(long: true),
										child: AdaptiveIconButton(
											onPressed: () => _tapWatchButton(long: false),
											icon: Icon(watch == null ? CupertinoIcons.bell : CupertinoIcons.bell_fill)
										)
									),
									if (!persistentState.showInHistory) AdaptiveIconButton(
										onPressed: () {
											lightHapticFeedback();
											persistentState.showInHistory = true;
											showToast(
												context: context,
												message: 'Thread restored to history',
												icon: CupertinoIcons.archivebox
											);
											persistentState.save();
											setState(() {});
										},
										icon: const Icon(CupertinoIcons.eye_slash)
									)
									else GestureDetector(
										onLongPress: () {
											lightHapticFeedback();
											persistentState.savedTime = null;
											persistentState.showInHistory = false;
											showToast(
												context: context,
												message: 'Thread hidden from history',
												icon: CupertinoIcons.eye_slash
											);
											persistentState.save();
											setState(() {});
										},
										child: AdaptiveIconButton(
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
											icon: Icon(persistentState.incognito ?
																		CupertinoIcons.eye_slash :
																		persistentState.savedTime == null ?
																			Adaptive.icons.bookmark :
																			Adaptive.icons.bookmarkFilled)
										)
									),
									if (site.threadVariants.isNotEmpty) AdaptiveIconButton(
										padding: EdgeInsets.zero,
										icon: (variant != null && variant != site.threadVariants.tryFirst) ? FittedBox(
											fit: BoxFit.contain,
											child: SizedBox(
												width: 40,
												height: 40,
												child: Stack(
													children: [
														Align(
															alignment: Alignment.bottomRight,
															child: Icon(variant.icon)
														),
														const Align(
															alignment: Alignment.topLeft,
															child: Icon(CupertinoIcons.sort_down)
														)
													]
												)
											)
										) : const Icon(CupertinoIcons.sort_down),
										onPressed: () async {
											final choice = await showAdaptiveModalPopup<ThreadVariant>(
												useRootNavigator: false,
												context: context,
												builder: (context) => AdaptiveActionSheet(
													title: const Text('Thread Sorting'),
													actions: site.threadVariants.map((variant) => AdaptiveActionSheetAction(
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
													cancelButton: AdaptiveActionSheetAction(
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
									Builder(
										builder: (context) => AdaptiveIconButton(
											key: _shareButtonKey,
											icon: Icon(Adaptive.icons.share),
											onPressed: () {
												final offset = (_shareButtonKey.currentContext?.findRenderObject() as RenderBox?)?.localToGlobal(Offset.zero);
												final size = _shareButtonKey.currentContext?.findRenderObject()?.semanticBounds.size;
												final openInNewTabZone = context.read<OpenInNewTabZone?>();
												shareOne(
													context: context,
													text: site.getWebUrl(
														board: widget.thread.board,
														threadId: widget.thread.id,
														archiveName: archiveName
													),
													type: "text",
													sharePositionOrigin: (offset != null && size != null) ? offset & size : null,
													additionalOptions: {
														if (openInNewTabZone != null) 'Open in new tab': () => openInNewTabZone.onWantOpenThreadInNewTab(context.read<Imageboard>().key, widget.thread),
														'Share as image': () async {
															try {
																final file = await modalLoad(context, 'Rendering...', (c) => sharePostsAsImage(context: context, primaryPostId: widget.thread.id, style: const ShareablePostsStyle(
																	expandPrimaryImage: true,
																	width: 400
																)));
																if (context.mounted) {
																	shareOne(
																		context: context,
																		text: file.path,
																		type: 'file',
																		sharePositionOrigin: null
																	);
																}
															}
															catch (e, st) {
																Future.error(e, st); // Report to crashlytics
																if (context.mounted) {
																	alertError(context, e.toStringDio());
																}
															}
														}
													}
												);
											}
										)
									),
									if (site.supportsPosting) NotifyingIcon(
										primaryCount: MappingValueListenable(
											parent: Outbox.instance,
											mapper: (o) =>
												o.queuedPostsFor(persistentState.imageboardKey, widget.thread.board, widget.thread.id).where((e) => e.state.isSubmittable).length
										),
										secondaryCount: MappingValueListenable(
											parent: Outbox.instance,
											mapper: (o) => o.submittableCount - o.queuedPostsFor(persistentState.imageboardKey, widget.thread.board, widget.thread.id).where((e) => e.state.isSubmittable).length
										),
										icon: AdaptiveIconButton(
											onPressed: (persistentState.thread?.isArchived == true && !(_replyBoxKey.currentState?.show ?? false)) ? null : () {
												if ((context.read<MasterDetailHint?>()?.location.isVeryConstrained ?? false) && _replyBoxKey.currentState?.show != true) {
													_popOutReplyBox(null);
												}
												else {
													_replyBoxKey.currentState?.toggleReplyBox();
												}
												setState(() {});
											},
											icon: (_replyBoxKey.currentState?.show ?? false) ? const Icon(CupertinoIcons.arrowshape_turn_up_left_fill) : const Icon(CupertinoIcons.reply)
										)
									)
								]
							),
							body: Column(
								children: [
									Flexible(
										flex: 1,
										child: TransformedMediaQuery(
											transformation: (context, mq) => mq.removePadding(removeBottom: _replyBoxKey.currentState?.show ?? false),
											child: Shortcuts(
												shortcuts: {
													LogicalKeySet(LogicalKeyboardKey.keyG): const OpenGalleryIntent()
												},
												child: Actions(
													actions: {
														OpenGalleryIntent: CallbackAction<OpenGalleryIntent>(
															onInvoke: (i) {
																if (_listController.state?.searchHasFocus ?? false) {
																	return;
																}
																_showGalleryFromNextImage();
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
																	if (_buildRefreshableList) RefreshableList<Post>(
																		filterableAdapter: (t) => t,
																		initialFilter: widget.initialSearch,
																		onFilterChanged: (filter) {
																			_searching = filter != null;
																			setState(() {});
																		},
																		key: _listKey,
																		sortMethods: zone.postSortingMethods,
																		id: '/${widget.thread.board}/${widget.thread.id}${persistentState.variant?.dataId ?? ''}',
																		disableUpdates: persistentState.disableUpdates,
																		autoUpdateDuration: autoUpdateDuration,
																		initialList: persistentState.thread?.posts ?? site.getThreadFromCatalogCache(widget.thread)?.posts_.sublist(0, 1),
																		initialTreeSplitId: persistentState.treeSplitId,
																		onTreeSplitIdChanged: (newId) {
																			persistentState.treeSplitId = newId;
																			runWhenIdle(const Duration(milliseconds: 500), persistentState.save);
																		},
																		useTree: useTree,
																		initialCollapsedItems: persistentState.collapsedItems,
																		initialPrimarySubtreeParents: persistentState.primarySubtreeParents,
																		onCollapsedItemsChanged: (newCollapsedItems, newPrimarySubtreeParents) {
																			persistentState.collapsedItems = newCollapsedItems.toList();
																			persistentState.primarySubtreeParents = newPrimarySubtreeParents;
																			runWhenIdle(const Duration(milliseconds: 500), persistentState.save);
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
																					childZone = childZone.childZoneFor(id, style: PostSpanZoneStyle.tree);
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
																			},
																			initiallyCollapseSecondLevelReplies: treeModeInitiallyCollapseSecondLevelReplies,
																			collapsedItemsShowBody: treeModeCollapsedPostsShowBody,
																			repliesToOPAreTopLevel: treeModeRepliesToOPAreTopLevel,
																			newRepliesAreLinear: treeModeNewRepliesAreLinear
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
																						Icon(Adaptive.icons.photo),
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
																						if (persistentState.thread!.isArchived || persistentState.thread!.isDeleted) ...[
																							GestureDetector(
																								behavior: HitTestBehavior.opaque,
																								onTap: _switchToLive,
																								child: Row(
																									children: [
																										Icon(persistentState.thread!.isDeleted ? CupertinoIcons.trash : CupertinoIcons.archivebox),
																										const SizedBox(width: 8),
																										Text(persistentState.thread!.archiveName ?? (persistentState.thread!.isDeleted ? 'Deleted' : 'Archived'))
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
																			if (site.archives.isNotEmpty) ThreadNotFoundException: (context, updater) => AdaptiveFilledButton(
																				child: const Text('Try archive'),
																				onPressed: () {
																					persistentState.useArchive = true;
																					persistentState.save();
																					updater();
																				}
																			)
																		},
																		listUpdater: () async {
																			return (await _getUpdatedThread()).posts;
																		},
																		controller: _listController,
																		itemBuilder: (context, post) {
																			return AnimatedBuilder(
																				animation: _glowingPostsAnimation,
																				builder: (context, child) {
																					return TweenAnimationBuilder<double>(
																						tween: Tween(begin: 0, end: _glowingPostId == post.id ? 0.2 : 0),
																						duration: const Duration(milliseconds: 350),
																						child: child,
																						builder: (context, factor, child) => factor == 0 ? child! : ColorFiltered(
																							colorFilter: ui.ColorFilter.mode(
																								theme.secondaryColor.withOpacity(factor),
																								BlendMode.srcOver
																							),
																							child: child
																						)
																					);
																				},
																				child: PostRow(
																					post: post,
																					onThumbnailTap: (attachment) {
																						_showGallery(initialAttachment: TaggedAttachment(
																							attachment: attachment,
																							semanticParentIds: context.read<PostSpanZoneData>().stackIds
																						));
																					},
																					onRequestArchive: () => _replacePostFromArchive(post),
																					highlight: newPostIds.contains(post.id),
																				)
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
																				onRequestArchive: () => _replacePostFromArchive(post),
																				onTap: () async {
																					resetPage();
																					await Future.delayed(const Duration(milliseconds: 250));
																					await _listController.animateTo((val) => val.id == post.id);
																					await _glowPost(post.id);
																				},
																				baseOptions: PostSpanRenderOptions(
																					highlightString: filterText
																				),
																				highlight: newPostIds.contains(post.id)
																			);
																		},
																		collapsedItemBuilder: ({
																			required BuildContext context,
																			required Post? value,
																			required Set<int> collapsedChildIds,
																			required bool loading,
																			required double? peekContentHeight,
																			required List<ParentAndChildIdentifier>? stubChildIds
																		}) {
																			final newCount = collapsedChildIds.where((id) => newPostIds.contains(id)).length;
																			final unseenCount = collapsedChildIds.where((id) => persistentState.unseenPostIds.data.contains(id)).length;
																			if (peekContentHeight != null && value != null) {
																				final style = TextStyle(
																					color: theme.secondaryColor,
																					fontWeight: FontWeight.bold
																				);
																				Widget post = Builder(
																					builder: (context) => PostRow(
																						post: value,
																						dim: peekContentHeight.isFinite,
																						highlight: newPostIds.contains(value.id),
																						onThumbnailTap: (attachment) {
																							_showGallery(initialAttachment: TaggedAttachment(
																								attachment: attachment,
																								semanticParentIds: context.read<PostSpanZoneData>().stackIds
																							));
																						},
																						onRequestArchive: () => _replacePostFromArchive(value),
																						overrideReplyCount: Row(
																							mainAxisSize: MainAxisSize.min,
																							children: [
																								RotatedBox(
																									quarterTurns: 1,
																									child: Icon(CupertinoIcons.chevron_right_2, size: 14, color: theme.secondaryColor)
																								),
																								if (collapsedChildIds.isNotEmpty) Text(
																									' ${collapsedChildIds.length}${collapsedChildIds.contains(-1) ? '+' : ''}',
																									style: style
																								),
																								if (unseenCount > 0) Text(
																									' ($unseenCount unseen)',
																									style: style
																								)
																								else if (newCount > 0) Text(
																									' ($newCount new)',
																									style: style
																								)
																							]
																						)
																					)
																				);
																				if (peekContentHeight.isFinite) {
																					post = ClipRect(
																						child: post
																					);
																				}
																				return IgnorePointer(
																					ignoring: peekContentHeight.isFinite,
																					child: ConstrainedBox(
																						constraints: BoxConstraints(
																							maxHeight: peekContentHeight
																						),
																						child: post
																					)
																				);
																			}
																			const style = TextStyle(fontSize: 16);
																			return IgnorePointer(
																				child: Container(
																					width: double.infinity,
																					padding: const EdgeInsets.all(8),
																					// TODO: The below?
																					color: ([value?.id, ...(stubChildIds?.map((x) => x.childId) ?? <int>[])]).any((x) => newPostIds.contains(x)) ? theme.primaryColorWithBrightness(0.1) : null,
																					child: Row(
																						children: [
																							if (value != null) Expanded(
																								child: Text.rich(
																									buildPostInfoRow(
																										post: value,
																										isYourPost: persistentState.youIds.contains(value.id),
																										settings: settings,
																										theme: theme,
																										site: site,
																										context: context,
																										zone: zone
																									)
																								)
																							)
																							else const Spacer(),
																							if (loading) ...[
																								SizedBox(
																									width: 18,
																									height: 18,
																									child: Transform.scale(
																										scale: 0.9,
																										child: const CircularProgressIndicator.adaptive()
																									)
																								),
																								const Text(' ', style: style)
																							],
																							if (collapsedChildIds.isNotEmpty) Text(
																								'${collapsedChildIds.length}${collapsedChildIds.contains(-1) ? '+' : ''} ',
																								style: style
																							),
																							if (unseenCount > 0) Text(
																								'($unseenCount unseen) ',
																								style: style
																							)
																							else if (newCount > 0) Text(
																								'($newCount new) ',
																								style: style
																							),
																							Icon(CupertinoIcons.chevron_down, size: MediaQuery.textScalerOf(context).scale(18))
																						]
																					)
																				)
																			);
																		},
																		filterHint: 'Search in thread'
																	),
																	SafeArea(
																		child: Align(
																			alignment: reverseIndicatorPosition ? Alignment.bottomLeft : Alignment.bottomRight,
																			child: _ThreadPositionIndicator(
																				key: _indicatorKey,
																				reversed: reverseIndicatorPosition,
																				persistentState: persistentState,
																				thread: persistentState.thread,
																				threadIdentifier: widget.thread,
																				listController: _listController,
																				zone: zone,
																				useTree: useTree,
																				newPostIds: newPostIds,
																				searching: _searching,
																				passedFirstLoad: _passedFirstLoad,
																				blocked: blocked,
																				boardSemanticId: widget.boardSemanticId,
																				developerModeButtons: [
																					[('Override last-seen', const Icon(CupertinoIcons.arrow_up_down), () {
																						final id = _listController.lastVisibleItem?.id;
																						if (id != null) {
																							if (useTree) {
																								// Something arbitrary
																								final x = _listController.items.map((i) => i.id).toList()..shuffle();
																								persistentState.unseenPostIds.data.addAll(x.take(x.length ~/ 2));
																							}
																							else {
																								persistentState.unseenPostIds.data.addAll(_listController.items.map((i) => i.id).where((x) => x > id));
																							}
																							persistentState.lastSeenPostId = id;
																							persistentState.save();
																							setState(() {});
																						}
																					})]
																				],
																				cachedAttachments: _cached,
																				attachmentsCachingQueue: _cachingQueue,
																				startCaching: () => _cacheAttachments(automatic: false),
																				openGalleryGrid: () => _showGalleryFromNextImage(initiallyShowGrid: true),
																				suggestedThread: _suggestedNewGeneral == null ? null : (
																					label: _suggestedNewGeneral?.$2 ?? '',
																					onAccept: () {
																						widget.onWantChangeThread?.call(_suggestedNewGeneral!.$1);
																					},
																					onReject: () {
																						setState(() {
																							_rejectedNewGeneralSuggestion = _suggestedNewGeneral?.$1;
																							_suggestedNewGeneral = null;
																						});
																					}
																				)
																			)
																		)
																	),
																	if (blocked) Builder(
																		builder: (context) => Container(
																			color: theme.backgroundColor,
																			child: const Center(
																				child: CircularProgressIndicator.adaptive()
																			)
																		)
																	)
																]
															)
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
											initialDraft: persistentState.draft,
											onDraftChanged: (draft) {
												persistentState.draft = draft;
												runWhenIdle(const Duration(seconds: 3), persistentState.save);
											},
											onReplyPosted: (receipt) async {
												if (site.supportsPushNotifications) {
													await promptForPushNotificationsIfNeeded(context);
												}
												if (persistentState.lastSeenPostId == persistentState.thread?.posts.last.id) {
													// If already at the bottom, pre-mark the created post as seen
													persistentState.lastSeenPostId = receipt.id;
													runWhenIdle(const Duration(milliseconds: 500), persistentState.save);
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
			)
		);
	}

	@override
	void dispose() {
		super.dispose();
		_threadStateListenable.removeListener(_onThreadStateListenableUpdate);
		_listController.dispose();
		if (_parentTab?.threadPageState == this) {
			_parentTab?.threadPageState = null;
		}
		if (_foreground) {
			setHandoffUrl(null);
		}
		zone.dispose();
		_cachingQueue.clear();
		_glowingPostsAnimation.dispose();
	}
}

typedef SuggestedNewThread = ({String label, VoidCallback onAccept, VoidCallback onReject});

class _ThreadPositionIndicator extends StatefulWidget {
	final PersistentThreadState persistentState;
	final Thread? thread;
	final ThreadIdentifier threadIdentifier;
	final RefreshableListController<Post> listController;
	final PostSpanZoneData zone;
	final bool reversed;
	final bool useTree;
	final Set<int> newPostIds;
	final bool searching;
	final bool passedFirstLoad;
	final bool blocked;
	final int boardSemanticId;
	final List<List<(String, Widget, VoidCallback)>> developerModeButtons;
	final Map<Attachment, _AttachmentCachingStatus> cachedAttachments;
	final List<Attachment> attachmentsCachingQueue;
	final VoidCallback startCaching;
	final VoidCallback openGalleryGrid;
	final SuggestedNewThread? suggestedThread;
	
	const _ThreadPositionIndicator({
		required this.persistentState,
		required this.thread,
		required this.threadIdentifier,
		required this.listController,
		required this.zone,
		this.reversed = false,
		required this.useTree,
		required this.newPostIds,
		required this.searching,
		required this.passedFirstLoad,
		required this.blocked,
		required this.boardSemanticId,
		required this.cachedAttachments,
		required this.attachmentsCachingQueue,
		required this.startCaching,
		required this.openGalleryGrid,
		required this.suggestedThread,
		this.developerModeButtons = const [],
		Key? key
	}) : super(key: key);

	@override
	createState() => _ThreadPositionIndicatorState();
}

class _ThreadPositionIndicatorState extends State<_ThreadPositionIndicator> with TickerProviderStateMixin {
	List<Post>? _filteredPosts;
	List<RefreshableListItem<Post>>? _filteredItems;
	List<int> _youIds = [];
	int? _lastLastVisibleItemId;
	int _lastLastSeenPostId = 0;
	int _redCountAbove = 0;
	int _redCountBelow = 0;
	int _whiteCountAbove = 0;
	int _whiteCountBelow = 0;
	int _greyCount = 0;
	Timer? _waitForRebuildTimer;
	late final AnimationController _buttonsAnimationController;
	late final Animation<double> _buttonsAnimation;
	int furthestSeenIndexTop = 9999999;
	int furthestSeenIndexBottom = 0;
	int _lastListControllerItemsLength = 0;
	int _lastFirstVisibleIndex = -1;
	int _lastLastVisibleIndex = -1;
	int _lastItemsLength = 0;
	final _animatedPaddingKey = GlobalKey(debugLabel: '_ThreadPositionIndicatorState._animatedPaddingKey');
	late final ScrollController _menuScrollController;
	ValueNotifier<String?>? _lastUpdatingNow;
	late bool _useCatalogCache;
	Filter? _lastFilter;
	bool _skipNextSwipe = false;

	Future<bool> _updateCounts() async {
		final site = context.read<ImageboardSite>();
		await WidgetsBinding.instance.endOfFrame;
		if (!mounted) return false;
		final lastVisibleIndex = widget.listController.lastVisibleIndex;
		if (lastVisibleIndex == -1 || (!widget.useTree && _filteredPosts == null) || (widget.useTree && _filteredItems == null)) {
			if (!_useCatalogCache) {
				return false;
			}
			if (!widget.passedFirstLoad && widget.useTree) {
				if (widget.thread == null) {
					_whiteCountBelow = 0;
					_greyCount = site.getThreadFromCatalogCache(widget.threadIdentifier)?.replyCount ?? 0;
					setState(() {});
				}
				return false;
			}
			if (widget.useTree) {
				assert(widget.thread != null);
				final catalogReplyCount = site.getThreadFromCatalogCache(widget.threadIdentifier)?.replyCount;
				if (catalogReplyCount != null) {
					_greyCount = widget.thread?.replyCount ?? 0;
					_whiteCountBelow = max(0, catalogReplyCount - _greyCount);
				}
			}
			else {
				_whiteCountBelow = widget.thread?.replyCount ??
					site.getThreadFromCatalogCache(widget.threadIdentifier)?.replyCount
					?? 0;
				_greyCount = 0;
			}
			_redCountBelow = 0;
			setState(() {});
			return false;
		}
		final lastVisibleItemId = widget.listController.getItem(lastVisibleIndex).item.id;
		_youIds = widget.persistentState.replyIdsToYou() ?? [];
		if (widget.useTree) {
			final items = widget.listController.items.toList();
			final greyBelow = <int>{};
			final whiteAbove = <int>{};
			final whiteBelow = <int>{};
			final redAbove = <int>{};
			final redBelow = <int>{};
			if (!widget.passedFirstLoad) {
				_whiteCountBelow = max(0, (site.getThreadFromCatalogCache(widget.threadIdentifier)?.replyCount ?? 0) - (widget.thread?.replyCount ?? 0));
			}
			else {
				_whiteCountBelow = 0;
			}
			// TODO: Determine if this needs to be / can be memoized
			for (int i = 0; i < items.length - 1; i++) {
				if (widget.listController.isItemHidden(items[i]).isDuplicate) {
					continue;
				}
				if (i > furthestSeenIndexBottom) {
					if (items[i].representsKnownStubChildren.isNotEmpty) {
						for (final stubChild in items[i].representsKnownStubChildren) {
							if (widget.newPostIds.contains(stubChild.childId)) {
								whiteBelow.add(stubChild.childId);
							}
							else {
								greyBelow.add(stubChild.childId);
							}
						}
					}
					else if (widget.newPostIds.contains(items[i].item.id)) {
						whiteBelow.add(items[i].item.id);
						if (_youIds.contains(items[i].item.id)) {
							redBelow.add(items[i].item.id);
						}
					}
					else {
						greyBelow.add(items[i].item.id);
					}
				}
				else if (i < furthestSeenIndexTop) {
					if (items[i].representsKnownStubChildren.isNotEmpty) {
						for (final stubChild in items[i].representsKnownStubChildren) {
							if (widget.newPostIds.contains(stubChild.childId)) {
								whiteAbove.add(stubChild.childId);
							}
						}
					}
					else if (widget.newPostIds.contains(items[i].item.id)) {
						whiteAbove.add(items[i].item.id);
						if (_youIds.contains(items[i].item.id)) {
							redAbove.add(items[i].item.id);
						}
					}
				}
				else if (i > lastVisibleIndex) {
					greyBelow.add(items[i].item.id);
					for (final stubChild in items[i].representsKnownStubChildren) {
						greyBelow.add(stubChild.childId);
					}
				}
			}
			if (!items.last.filterCollapsed) {
				if (items.last.representsKnownStubChildren.isNotEmpty) {
					for (final stubChild in items.last.representsKnownStubChildren) {
						if (widget.newPostIds.contains(stubChild.childId)) {
							whiteBelow.add(stubChild.childId);
						}
						else {
							greyBelow.add(stubChild.childId);
						}
					}
				}
				else if ((items.length - 1) > furthestSeenIndexBottom) {
					if (widget.newPostIds.contains(items.last.item.id)) {
						whiteBelow.add(items.last.item.id);
						if (_youIds.contains(items.last.item.id)) {
							redBelow.add(items.last.item.id);
						}
					}
				}
				else if (lastVisibleIndex < (items.length - 1)) {
					greyBelow.add(items.last.item.id);
				}
			}
			_greyCount = greyBelow.length;
			_whiteCountAbove = whiteAbove.length;
			_whiteCountBelow += whiteBelow.length; // Initialized before for-loop
			_redCountAbove = redAbove.length;
			_redCountBelow = redBelow.length;
		}
		else {
			_lastLastSeenPostId = widget.persistentState.lastSeenPostId ?? widget.persistentState.id;
			_redCountBelow = _youIds.binarySearchCountAfter((p) => p > _lastLastSeenPostId);
			_whiteCountBelow = _filteredPosts!.binarySearchCountAfter((p) => p.id > _lastLastSeenPostId);
			_greyCount = max(0, widget.listController.itemsLength - (widget.listController.lastVisibleIndex + 1) - _whiteCountBelow);
		}
		_lastLastVisibleItemId = lastVisibleItemId;
		setState(() {});
		return true;
	}

	Future<bool> _onSlowScroll() async {
		if (widget.blocked) {
			return false;
		}
		final firstVisibleIndex = widget.listController.firstVisibleIndex;
		if (firstVisibleIndex != -1) {
			furthestSeenIndexTop = min(firstVisibleIndex, furthestSeenIndexTop);
		}
		final lastVisibleIndex = widget.listController.lastVisibleIndex;
		if (lastVisibleIndex != -1) {
			furthestSeenIndexBottom = max(lastVisibleIndex, furthestSeenIndexBottom);
		}
		if (widget.useTree) {
			_filteredItems ??= widget.listController.items.toList();
			final skip = widget.blocked && _lastFirstVisibleIndex == firstVisibleIndex && _lastLastVisibleIndex == lastVisibleIndex && _lastItemsLength == widget.listController.itemsLength;
			if (firstVisibleIndex == -1) {
				_lastFirstVisibleIndex = -1;
			}
			if (_lastLastVisibleIndex == -1) {
				_lastLastVisibleIndex = -1;
			}
			if (skip) {
				return true;
			}
			final ok = await _updateCounts();
			if (ok) {
				_lastFirstVisibleIndex = firstVisibleIndex;
				_lastLastVisibleIndex = lastVisibleIndex;
				_lastItemsLength = widget.listController.itemsLength;
			}
			return ok;
		}
		else {
			final lastVisibleItemId = (lastVisibleIndex == -1) ? null : widget.listController.getItem(lastVisibleIndex).id;
			_filteredPosts ??= widget.persistentState.filteredPosts();
			if (lastVisibleItemId != null &&
					_filteredPosts != null &&
					(lastVisibleItemId != _lastLastVisibleItemId ||
					 _lastLastSeenPostId != (widget.persistentState.lastSeenPostId ?? widget.persistentState.id))) {
				return await _updateCounts();
			}
			else {
				return lastVisibleItemId != null && _filteredPosts != null;
			}
		}
	}

	Future<void> _pollForOnSlowScroll() async {
		_waitForRebuildTimer?.cancel();
		if (!await _onSlowScroll()) {
			_waitForRebuildTimer = Timer.periodic(const Duration(milliseconds: 20), (t) async {
				if (!mounted || (await _onSlowScroll())) {
					t.cancel();
				}
			});
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
		_menuScrollController = ScrollController();
		widget.listController.slowScrolls.addListener(_onSlowScroll);
		_lastUpdatingNow = widget.listController.state?.updatingNow;
		_lastUpdatingNow?.addListener(_onUpdatingNowChange);
		if (widget.thread != null) {
			_filteredPosts = widget.persistentState.filteredPosts();
		}
		_useCatalogCache = widget.thread == null;
		_pollForOnSlowScroll();
		_lastFilter = Filter.of(context, listen: false);
	}

	@override
	void didUpdateWidget(_ThreadPositionIndicator oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (widget.persistentState != oldWidget.persistentState) {
			_filteredPosts = null;
			_lastLastVisibleItemId = null;
		}
		if (widget.thread != oldWidget.thread ||
				widget.useTree != oldWidget.useTree) {
			if (widget.thread == null) {
				_filteredPosts = null;
				_filteredItems = null;
				_useCatalogCache = true;
			}
			else {
				_filteredPosts = widget.persistentState.filteredPosts();
				_filteredItems = null; // Likely not built yet
				furthestSeenIndexTop = 9999999;
				furthestSeenIndexBottom = 0;
				_useCatalogCache = false;
			}
			if (widget.threadIdentifier != oldWidget.threadIdentifier) {
				_lastLastSeenPostId = 0;
				setState(() {
					_redCountBelow = 0;
					_whiteCountBelow = 0;
					_greyCount = 0;
				});
			}
			_pollForOnSlowScroll();
		}
		else if (widget.listController.itemsLength != _lastListControllerItemsLength || widget.useTree != oldWidget.useTree) {
			if (widget.useTree) {
				_filteredItems = widget.listController.items.toList();
			}
			else {
				_filteredPosts = widget.persistentState.filteredPosts();
			}
			furthestSeenIndexTop = 9999999;
			furthestSeenIndexBottom = 0;
			_onSlowScroll();
		}
		_lastListControllerItemsLength = widget.listController.items.length;
		if (widget.listController != oldWidget.listController) {
			oldWidget.listController.slowScrolls.removeListener(_onSlowScroll);
			widget.listController.slowScrolls.addListener(_onSlowScroll);
		}
		if (widget.listController.state?.updatingNow != _lastUpdatingNow) {
			_lastUpdatingNow?.removeListener(_onUpdatingNowChange);
			_lastUpdatingNow = widget.listController.state?.updatingNow;
			_lastUpdatingNow?.addListener(_onUpdatingNowChange);
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
		final newFilter = Filter.of(context);
		if (newFilter != _lastFilter) {
			// Reset some state
			if (widget.thread == null) {
				_filteredPosts = null;
				_filteredItems = null;
				_useCatalogCache = true;
			}
			else {
				_filteredPosts = widget.persistentState.filteredPosts();
				_filteredItems = null; // Likely not built yet
				furthestSeenIndexTop = 9999999;
				furthestSeenIndexBottom = 0;
				_useCatalogCache = false;
			}
			_pollForOnSlowScroll();
		}
	}

	void _scheduleAdditionalSafeAreaInsetsShow() async {
		await Future.delayed(const Duration(milliseconds: 100));
		final scrollableHeight = _menuScrollController.tryPosition?.viewportDimension;
		if (scrollableHeight != null) {
			setAdditionalSafeAreaInsets('menu${widget.boardSemanticId}', EdgeInsets.only(bottom: scrollableHeight * Settings.instance.interfaceScale));
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
		if (mounted) {
			setState(() {});
		}
	}

	@override
	Widget build(BuildContext context) {
		final theme = context.watch<SavedTheme>();
		final radius = ChanceTheme.materialOf(context) ? const Radius.circular(4) : const Radius.circular(8);
		final radiusAlone = BorderRadius.all(radius);
		final radiusStart = widget.reversed ? BorderRadius.only(topRight: radius, bottomRight: radius) : BorderRadius.only(topLeft: radius, bottomLeft: radius);
		final radiusEnd = widget.reversed ? BorderRadius.only(topLeft: radius, bottomLeft: radius) : BorderRadius.only(topRight: radius, bottomRight: radius);
		final scrollAnimationDuration = Settings.showAnimationsSetting.watch(context) ? const Duration(milliseconds: 200) : const Duration(milliseconds: 1);
		scrollToTop() => widget.listController.scrollController?.animateTo(0, duration: scrollAnimationDuration, curve: Curves.ease);
		scrollToBottom() => widget.listController.animateTo((post) => false, orElseLast: (x) => true, alignment: 1.0, duration: scrollAnimationDuration);
		final youIds = widget.persistentState.youIds;
		final uncachedCount = widget.cachedAttachments.values.where((v) => !v.isCached).length;
		final uncachedMB = (widget.cachedAttachments.entries.map((e) => e.value.isCached ? 0 : e.key.sizeInBytes ?? 0).fold(0, (a, b) => a + b) / (1024*1024));
		final uncachedMBIsUncertain = widget.cachedAttachments.entries.any((e) => !e.value.isCached && e.key.sizeInBytes == null);
		final cachingButtonLabel = '${uncachedMB.ceil()}${uncachedMBIsUncertain ? '+' : ''} MB';
		final showGalleryGridButton = Settings.showGalleryGridButtonSetting.watch(context);
		final realImageCount = widget.listController.items.fold<int>(0, (t, a) => t + a.item.attachments.length);
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
						padding: EdgeInsets.only(bottom: (widget.suggestedThread != null ? 50 : 0) + (_whiteCountAbove > 0 ? 50 : 0) + 50),
						child: SingleChildScrollView(
							reverse: true,
							primary: false,
							controller: _menuScrollController,
							child: Column(
								crossAxisAlignment: widget.reversed ? CrossAxisAlignment.start : CrossAxisAlignment.end,
								mainAxisSize: MainAxisSize.min,
								children: [
									for (final buttons in [
										[(describeCount(youIds.length, 'submission'), const Icon(CupertinoIcons.person, size: 19), youIds.isEmpty ? null : () {
												WeakNavigator.push(context, PostsPage(
													zone: widget.zone,
													postsIdsToShow: youIds,
													onTap: (post) {
														widget.listController.animateTo((p) => p.id == post.id);
														WeakNavigator.pop(context);
													}
												)
											);
										})],
										[(describeCount(_youIds.length, '(You)'), const Icon(CupertinoIcons.reply_all, size: 19), _youIds.isEmpty ? null : () {
												WeakNavigator.push(context, PostsPage(
													zone: widget.zone,
													postsIdsToShow: _youIds,
													onTap: (post) {
														widget.listController.animateTo((p) => p.id == post.id);
														WeakNavigator.pop(context);
													}
												)
											);
										})],
										[(
											describeCount(realImageCount, 'image'),
											const RotatedBox(
												quarterTurns: 1,
												child: Icon(CupertinoIcons.rectangle_split_3x1, size: 19)
											),
											() async {
												const commonParentIds = [-101];
												final nextPostWithImage = widget.listController.items.skip(max(0, widget.listController.firstVisibleIndex - 1)).firstWhere((p) => p.item.attachments.isNotEmpty, orElse: () {
													return widget.listController.items.take(widget.listController.firstVisibleIndex).lastWhere((p) => p.item.attachments.isNotEmpty);
												});
												final imageboard = context.read<Imageboard>();
												final attachments = widget.listController.items.expand((item) => item.item.attachments.map((a) => TaggedAttachment(
													attachment: a,
													semanticParentIds: commonParentIds.followedBy(item.parentIds)
												))).toList();
												final initialAttachment = TaggedAttachment(
													attachment: nextPostWithImage.item.attachments.first,
													semanticParentIds: commonParentIds.followedBy(nextPostWithImage.parentIds)
												);
												final found = <Attachment, TaggedAttachment>{};
												for (final a in attachments) {
													found.putIfAbsent(a.attachment, () => a);
												}
												found[initialAttachment.attachment] = initialAttachment;
												attachments.removeWhere((a) => found[a.attachment] != a);
												final dest = await Navigator.of(context).push<TaggedAttachment>(adaptivePageRoute(
													builder: (context) => ImageboardScope(
														imageboardKey: null,
														imageboard: imageboard,
														child: AttachmentsPage(
															attachments: attachments,
															initialAttachment: initialAttachment,
															threadState: widget.persistentState
															//onChange: (attachment) => widget.listController.animateTo((p) => p.attachment?.id == attachment.id)
														)
													)
												));
												if (dest != null) {
													final destPost = widget.thread?.posts.tryFirstWhere((p) => p.attachments.contains(dest.attachment));
													if (destPost != null) {
														widget.zone.onNeedScrollToPost?.call(destPost);
													}
												}
											}
										), (
											uncachedCount == 0 ? '' : 'Preload $uncachedCount${uncachedMB == 0 ? '' : ' (${uncachedMBIsUncertain ? '>' : ''}${uncachedMB.ceil()} MB)'}',
											const Icon(CupertinoIcons.cloud_download, size: 19),
											(widget.attachmentsCachingQueue.isEmpty && widget.cachedAttachments.values.any((v) => !v.isCached)) ? widget.startCaching : null
										)],
										[('Search', const Icon(CupertinoIcons.search, size: 19), widget.listController.focusSearch)],
										if (context.read<ImageboardSite>().archives.isEmpty) [('Archive', const Icon(CupertinoIcons.archivebox, size: 19), null)]
										else if (widget.persistentState.useArchive) [('Live', const ImageboardIcon(), () {
											widget.persistentState.useArchive = false;
											widget.persistentState.save();
											setState(() {});
											widget.listController.blockAndUpdate();
										})]
										else [('Archive', const Icon(CupertinoIcons.archivebox, size: 19), () async {
											widget.persistentState.useArchive = true;
											widget.persistentState.save();
											setState(() {});
											widget.listController.blockAndUpdate();
										})],
										if (widget.persistentState.autoTranslate) [('Original', const Icon(Icons.translate, size: 19), () {
											widget.persistentState.autoTranslate = false;
											widget.persistentState.translatedPosts.clear();
											widget.zone.clearTranslatedPosts();
											widget.persistentState.save();
											setState(() {});
										})]
										else [('Translate', const Icon(Icons.translate, size: 19), () async {
											widget.persistentState.autoTranslate = true;
											for (final post in widget.persistentState.thread?.posts ?? <Post>[]) {
												if (widget.zone.translatedPost(post.id) == null) {
													try {
														await widget.zone.translatePost(post);
													}
													catch (e) {
														// ignore, it will be shown on the post widget anyway
													}
												}
											}
											widget.persistentState.save();
											setState(() {});
										})],
										[
											('${widget.persistentState.postSortingMethod == PostSortingMethod.none ? 'Sort' : widget.persistentState.postSortingMethod.displayName}...', const Icon(CupertinoIcons.sort_down, size: 19), () async {
												final choice = await showAdaptiveModalPopup<PostSortingMethod>(
													context: context,
													useRootNavigator: false,
													builder: (context) => AdaptiveActionSheet(
														title: const Text('Sort by...'),
														actions: PostSortingMethod.values.map((v) => AdaptiveActionSheetAction(
															onPressed: () => Navigator.pop(context, v),
															child: Text(v.displayName, style: TextStyle(
																fontWeight: v == widget.persistentState.postSortingMethod ? FontWeight.bold : null
															))
														)).toList(),
														cancelButton: AdaptiveActionSheetAction(
															child: const Text('Cancel'),
															onPressed: () => Navigator.pop(context)
														)
													)
												);
												if (choice == null) {
													return;
												}
												widget.persistentState.postSortingMethod = choice;
												widget.listController.state?.forceRebuildId++;
												widget.persistentState.save();
											}),
											if (widget.useTree) ('Linear', const Icon(CupertinoIcons.list_bullet, size: 19), () => setState(() {
												widget.persistentState.useTree = false;
												widget.persistentState.save();
											}))
											else ('Tree', const Icon(CupertinoIcons.list_bullet_indent, size: 19), () => setState(() {
												widget.persistentState.useTree = true;
												widget.persistentState.save();
											}))
										],
										[('Update', const Icon(CupertinoIcons.refresh, size: 19), widget.listController.update)],
										[('Top', const Icon(CupertinoIcons.arrow_up_to_line, size: 19), scrollToTop)],
										[
											('New posts', const Icon(CupertinoIcons.arrow_down, size: 19), _whiteCountBelow <= 0 ? null : () {
												if (widget.useTree) {
													int targetIndex = widget.listController.items.toList().asMap().entries.tryFirstWhere((entry) {
														return entry.key > furthestSeenIndexBottom &&
															(widget.newPostIds.contains(entry.value.item.id) || entry.value.representsKnownStubChildren.any((id) => widget.newPostIds.contains(id.childId))) &&
															!entry.value.filterCollapsed;
													})?.key ?? -1;
													if (targetIndex != -1) {
														while (widget.listController.isItemHidden(widget.listController.getItem(targetIndex)).isHidden) {
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
											('Bottom', const Icon(CupertinoIcons.arrow_down_to_line, size: 19), scrollToBottom)
										],
										if (developerMode) ...widget.developerModeButtons
									]) Padding(
										padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
										child: Row(
											mainAxisSize: MainAxisSize.min,
											children: buttons.expand((button) => [
												const SizedBox(width: 8),
												AdaptiveFilledButton(
													disabledColor: theme.primaryColorWithBrightness(0.4),
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
															if (button.$1.isNotEmpty) const SizedBox(width: 8),
															button.$2
														]
													)
												)
											]).skip(1).toList()
										)
									)
								]
							)
						)
					)
				),
				Column(
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
										color: theme.primaryColor
									),
									margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
									padding: const EdgeInsets.all(8),
									child: Row(
										mainAxisSize: MainAxisSize.min,
										children: [
											Icon(CupertinoIcons.search, color: theme.backgroundColor, size: 19),
											const SizedBox(width: 8),
											Icon(CupertinoIcons.xmark, color: theme.backgroundColor, size: 19)
										]
									)
								)
							)
						else ...[
							if (!widget.blocked && widget.suggestedThread != null) Padding(
								padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
								child: Builder(
									builder: (context) {
										List<Widget> children = [
											CupertinoButton(
												onPressed: () async {
													widget.suggestedThread?.onReject.call();
												},
												padding: EdgeInsets.zero,
												minSize: 0,
												child: const Icon(CupertinoIcons.xmark, size: 19)
											),
											const SizedBox(width: 4),
											AdaptiveFilledButton(
												onPressed: () async {
													widget.suggestedThread?.onAccept.call();
												},
												padding: const EdgeInsets.all(8),
												minSize: 0,
												child: Row(
													mainAxisSize: MainAxisSize.min,
													crossAxisAlignment: CrossAxisAlignment.center,
													children: [
														Text('New ${widget.suggestedThread?.label} thread'),
														const SizedBox(width: 4),
														const Icon(CupertinoIcons.arrow_right, size: 18),
													]
												)
											)
										];
										if (widget.reversed) {
											children = children.reversed.toList();
										}
										return Row(
											mainAxisSize: MainAxisSize.min,
											children: children
										);
									}
								)
							),
							if (widget.useTree && _whiteCountAbove > 0) CupertinoButton(
								padding: EdgeInsets.zero,
								child: Builder(
									builder: (context) {
										List<Widget> children = [
											if (_redCountAbove > 0) Container(
												decoration: BoxDecoration(
													borderRadius: radiusStart,
													color: theme.secondaryColor
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
													color: theme.primaryColor
												),
												padding: const EdgeInsets.all(8),
												child: Row(
													mainAxisSize: MainAxisSize.min,
													children: [
														Container(
															constraints: BoxConstraints(
																minWidth: MediaQuery.textScalerOf(context).scale(24) * max(1, 0.5 * _whiteCountAbove.toString().length)
															),
															child: Text(
																_whiteCountAbove.toString(),
																style: TextStyle(
																	color: theme.backgroundColor
																),
																textAlign: TextAlign.center
															)
														),
														Icon(CupertinoIcons.arrow_up, color: theme.backgroundColor, size: 19)
													]
												)
											)
										];
										if (widget.reversed) {
											children = children.reversed.toList();
										}
										return Padding(
											padding: const EdgeInsets.only(top: 5, bottom: 8, left: 16, right: 16),
											child: Row(
												mainAxisSize: MainAxisSize.min,
												children: children
											)
										);
									}
								),
								onPressed: () {
									int targetIndex = widget.listController.items.toList().asMap().entries.tryLastWhere((entry) {
										return entry.key < furthestSeenIndexTop &&
											(widget.newPostIds.contains(entry.value.item.id) || entry.value.representsKnownStubChildren.any((id) => widget.newPostIds.contains(id.childId))) &&
											!widget.listController.isItemHidden(entry.value).isDuplicate;
									})?.key ?? -1;
									if (targetIndex != -1) {
										while (widget.listController.isItemHidden(widget.listController.getItem(targetIndex)).isHidden) {
											// Align to parent if the target has been collapsed
											targetIndex--;
										}
										widget.listController.animateToIndex(targetIndex);
									}
								}
							),
							Builder(
								builder: (context) {
									final children = [
										if (!widget.blocked && widget.attachmentsCachingQueue.isNotEmpty) ...[
											AdaptiveFilledButton(
												onPressed: () async {
													final cancel = await confirm(context, 'Cancel preloading?');
													if (mounted && cancel) {
														widget.attachmentsCachingQueue.clear(); // Hacky...
													}
												},
												padding: const EdgeInsets.all(8),
												minSize: 0,
												child: Row(
													mainAxisSize: MainAxisSize.min,
													crossAxisAlignment: CrossAxisAlignment.center,
													children: [
														Icon(Adaptive.icons.photo, size: 19),
														ConstrainedBox(
															constraints: BoxConstraints(
																minWidth: MediaQuery.textScalerOf(context).scale(24) * max(1, 0.5 * cachingButtonLabel.length)
															),
															child: Text(cachingButtonLabel, textAlign: TextAlign.center),
														),
														CupertinoActivityIndicator(
															color: theme.backgroundColor
														),
													]
												)
											),
											const SizedBox(width: 8)
										],
										if (!widget.blocked && (widget.listController.state?.updatingNow.value != null) && widget.listController.state?.originalList != null) ...[
											const SizedBox(
												width: 16,
												height: 16,
												child: CircularProgressIndicator.adaptive()
											),
											const SizedBox(width: 8),
										],
										if (!widget.blocked && widget.persistentState.useArchive) ...[
											Icon(CupertinoIcons.archivebox, color: theme.primaryColor.withOpacity(0.5)),
											const SizedBox(width: 8)
										],
										if (!widget.blocked && (widget.listController.state?.treeBuildingFailed ?? false)) ...[
											CupertinoButton(
												color: Colors.red,
												padding: const EdgeInsets.all(8),
												minSize: 0,
												onPressed: () => alertError(context, 'Tree too complex!\nLarge reply chains mean this thread can not be shown in tree mode.'),
												child: Icon(CupertinoIcons.exclamationmark, color: theme.backgroundColor, size: 19)
											),
											const SizedBox(width: 8)
										],
										if (showGalleryGridButton && realImageCount > 1) ...[
											AdaptiveFilledButton(
												padding: const EdgeInsets.all(8),
												onPressed: widget.openGalleryGrid,
												child: Row(
													mainAxisSize: MainAxisSize.min,
													crossAxisAlignment: CrossAxisAlignment.center,
													children: [
														Icon(CupertinoIcons.square_grid_2x2, size: 19, color: theme.backgroundColor),
														const SizedBox(width: 4),
														Text(describeCount(realImageCount, 'image'), style: TextStyle(
															color: theme.backgroundColor
														))
													]
												)
											),
											const SizedBox(width: 8),
										],
										GestureDetector(
											longPressDuration: const Duration(milliseconds: 300),
											onLongPress: () {
												final position = widget.listController.scrollController?.tryPosition;
												if (position != null && position.extentAfter < 200 && position.extentBefore > 200) {
													scrollToTop();
												}
												else {
													scrollToBottom();
												}
												mediumHapticFeedback();
											},
											onPanStart: (details) {
												_skipNextSwipe = eventTooCloseToEdge(details.globalPosition);
											},
											onPanEnd: (details) {
												if (_skipNextSwipe) {
													return;
												}
												final position = widget.listController.scrollController?.tryPosition;
												if ((-1 * details.velocity.pixelsPerSecond.dy) > details.velocity.pixelsPerSecond.dx.abs()) {
													mediumHapticFeedback();
													if (position != null && position.extentAfter > 0) {
														scrollToBottom();
													}
													else {
														// Not possible, do a "double buzz"
														Future.delayed(const Duration(milliseconds: 100), mediumHapticFeedback);
													}
												}
												else if (details.velocity.pixelsPerSecond.dy > details.velocity.pixelsPerSecond.dx.abs()) {
													mediumHapticFeedback();
													if (position != null && position.extentBefore > 0) {
														scrollToTop();
													}
													else {
														// Not possible, do a "double buzz"
														Future.delayed(const Duration(milliseconds: 100), mediumHapticFeedback);
													}
												}
											},
											child: CupertinoButton(
												padding: EdgeInsets.zero,
												child: Builder(
													builder: (context) {
														final indicatorParts = [
															if (_redCountBelow > 0) Container(
																decoration: BoxDecoration(
																	borderRadius: radiusStart,
																	color: theme.secondaryColor
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
																	color: theme.primaryColorWithBrightness(0.6)
																),
																padding: const EdgeInsets.all(8),
																child: Container(
																	constraints: BoxConstraints(
																		minWidth: MediaQuery.textScalerOf(context).scale(24) * max(1, 0.5 * _greyCount.toString().length)
																	),
																	child: Text(
																		_greyCount.toString(),
																		style: TextStyle(
																			color: theme.backgroundColor
																		),
																		textAlign: TextAlign.center
																	)
																)
															),
															if (_whiteCountBelow > 0) Container(
																decoration: BoxDecoration(
																	borderRadius: (_redCountBelow <= 0 && _greyCount <= 0) ? radiusAlone : radiusEnd,
																	color: theme.primaryColor
																),
																padding: const EdgeInsets.all(8),
																child: Container(
																	constraints: BoxConstraints(
																		minWidth: MediaQuery.textScalerOf(context).scale(24) * max(1, 0.5 * _whiteCountBelow.toString().length)
																	),
																	child: Text(
																		_whiteCountBelow.toString(),
																		style: TextStyle(
																			color: theme.backgroundColor
																		),
																		textAlign: TextAlign.center
																	)
																)
															)
														];
														return Row(
															mainAxisSize: MainAxisSize.min,
															children: widget.reversed ? indicatorParts.reversed.toList() : indicatorParts
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
										)
									];
									return Padding(
										padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
										child: Row(
											mainAxisSize: MainAxisSize.min,
											crossAxisAlignment: CrossAxisAlignment.center,
											children: widget.reversed ? children.reversed.toList() : children
										)
									);
								}
							)
						]
					]
				)
			]
		);
	}

	@override
	void dispose() {
		super.dispose();
		widget.listController.slowScrolls.removeListener(_onSlowScroll);
		widget.listController.state?.updatingNow.removeListener(_onUpdatingNowChange);
		_buttonsAnimationController.dispose();
		_menuScrollController.dispose();
		_waitForRebuildTimer?.cancel();
		WidgetsBinding.instance.addPostFrameCallback((_) {
			_scheduleAdditionalSafeAreaInsetsHide();
		});
	}
}
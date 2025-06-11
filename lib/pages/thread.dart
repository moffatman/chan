import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:auto_size_text/auto_size_text.dart';
import 'package:chan/main.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/models/parent_and_child.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/overscroll_modal.dart';
import 'package:chan/pages/posts.dart';
import 'package:chan/pages/attachments.dart';
import 'package:chan/pages/thread_watch_controls.dart';
import 'package:chan/services/apple.dart';
import 'package:chan/services/attachment_cache.dart';
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
import 'package:chan/widgets/poll.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:chan/widgets/reply_box.dart';
import 'package:chan/widgets/shareable_posts.dart';
import 'package:chan/widgets/timed_rebuilder.dart';
import 'package:chan/widgets/util.dart';
import 'package:chan/widgets/weak_gesture_recognizer.dart';
import 'package:chan/widgets/weak_navigator.dart';
import 'package:dio/dio.dart';
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
	final PostSortingMethod? postSortingMethod;
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
	bool get disableUpdates => (thread?.isDeleted ?? false) || (thread?.isArchived ?? false) || (thread?.isLocked ?? false);
}

enum _AttachmentCachingStatus {
	uncached,
	cached,
	willNotAutoCacheDueToRateLimiting,
	uncacheable;
	bool get isCached => this == cached;
}

class ThreadPage extends StatefulWidget {
	final ThreadIdentifier thread;
	final int? initialPostId;
	final String? initiallyUseArchive;
	final int boardSemanticId;
	final String? initialSearch;
	final ValueChanged<ThreadIdentifier>? onWantChangeThread;

	const ThreadPage({
		required this.thread,
		this.initialPostId,
		this.initiallyUseArchive,
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

	bool _useAllDummies = false;
	late final RefreshableListController<Post> _listController;
	late PostSpanRootZoneData zone;
	bool blocked = false;
	Listenable? _threadStateListenable;
	int lastSavedPostsLength = 0;
	int lastHiddenMD5sLength = 0;
	_PersistentThreadStateSnapshot _lastPersistentThreadStateSnapshot = _PersistentThreadStateSnapshot.empty();
	bool _foreground = false;
	RequestPriority get _priority => _foreground ? RequestPriority.interactive : RequestPriority.functional;
	PersistentBrowserTab? _parentTab;
	final List<Function> _postUpdateCallbacks = [];
	final Map<int, double> _highlightPosts = {};
	bool _searching = false;
	bool _passedFirstLoad = false;
	int? _firstSeenIndex;
	int? _lastSeenIndex;
	bool _showingWatchMenu = false;
	final Map<Attachment, _AttachmentCachingStatus> _cached = {};
	final List<Attachment> _cachingQueue = [];
	final _indicatorKey = GlobalKey<_ThreadPositionIndicatorState>();
	(ThreadIdentifier, String)? _suggestedNewGeneral;
	ThreadIdentifier? _rejectedNewGeneralSuggestion;
	late final EasyListenable _glowingPostsAnimation;
	int? _glowingPostId;
	final _scrollLock = Mutex();
	final _threadStateListenableUpdateMutex = Mutex();
	late final StreamSubscription<Attachment> _cacheSubscription;

	static const _kHighlightZero = 0.0;
	static const _kHighlightPartial = 0.3;
	static const _kHighlightFull = 1.0;

	/// Return whether any were removed
	bool _updateHighlightedPosts({required bool restoring}) {
		final value = restoring ? _kHighlightPartial : _kHighlightFull;
		final lastSeenId = persistentState.lastSeenPostId ?? 0;
		bool anyRemoved = false;
		_highlightPosts.removeWhere((id, v) {
			final remove = !persistentState.unseenPostIds.data.contains(id);
			anyRemoved |= remove;
			return remove;
		});
		for (final newId in persistentState.unseenPostIds.data) {
			_highlightPosts[newId] ??= (newId > lastSeenId) ? _kHighlightFull : value;
		}
		return anyRemoved;
	}

	Future<void> _onThreadStateListenableUpdate() => _threadStateListenableUpdateMutex.protect(() async {
		final persistence = context.read<Persistence>();
		final savedPostsLength = persistentState.thread?.posts_.where((p) => persistence.getSavedPost(p) != null).length ?? 0;
		final hiddenMD5sLength = Persistence.settings.hiddenImageMD5s.length;
		final currentSnapshot = _PersistentThreadStateSnapshot.of(persistentState);
		if (currentSnapshot != _lastPersistentThreadStateSnapshot ||
				savedPostsLength != lastSavedPostsLength ||
				hiddenMD5sLength != lastHiddenMD5sLength) {
			if (currentSnapshot.thread?.identifier == _lastPersistentThreadStateSnapshot.thread?.identifier) {
				// We need to catch newPostIds filled in via thread setter
				// Since newPostIds is always subset of unseenPostIds, this is safe
				_updateHighlightedPosts(restoring: false);
			}
			_listController.state?.forceRebuildId++;
			await persistentState.thread?.preinit();
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
				}
			});
		}
		lastSavedPostsLength = savedPostsLength;
		lastHiddenMD5sLength = hiddenMD5sLength;
		_lastPersistentThreadStateSnapshot = currentSnapshot;
		if (persistentState.thread != null) {
			zone.addThread(persistentState.thread!);
		}
		Future.microtask(_runPostUpdateCallbacks);
	});

	bool get useTree => persistentState.useTree ?? context.read<Persistence>().browserState.useTree ?? context.read<ImageboardSite>().useTree;
	String? get archiveName {
		if (persistentState.thread?.identifier == widget.thread) {
			return persistentState.thread?.archiveName;
		}
		return null;
	}

	/// Returns whether a load was needed
	Future<bool> _ensurePostLoaded(int postId) async {
		bool loadedSomething = false;
		Post? post = persistentState.thread?.posts_.tryFirstWhere((p) => p.id == postId);
		final usesStubs = persistentState.thread?.posts_.any((p) => p.isStub) ?? false;
		if (usesStubs) {
			if (post?.isStub ?? true) {
				post = (await _updateWithStubItems([ParentAndChildIdentifier(
					parentId: -1, // Should be ignored
					childId: postId
				)])).tryFirstWhere((p) => p.id == postId);
				await _listController.state?.acceptNewList(zone.findThread(persistentState.id)!.posts);
				loadedSomething = true;
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
					loadedSomething |= await _ensurePostLoaded(post.parentId!);
				}
			}
		}
		else if (post == null) {
			loadedSomething = true;
			if (context.read<ImageboardSite>().isPaged) {
				// This will find the page and load the post
				await _updateWithStubItems([ParentAndChildIdentifier(
					parentId: widget.thread.id,
					childId: postId
				)]);
				await _listController.state?.acceptNewList(zone.findThread(persistentState.id)!.posts);
			}
			else {
				// Maybe not loaded yet?
				await _listController.update();
			}
		}
		return loadedSomething;
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
		target: (postId, null),
		shouldBlock: false
	);

	Future<void> _blockAndScrollToPostIfNeeded({
		Duration delayBeforeScroll = Duration.zero,
		(int, double?)? target,
		bool shouldBlock = true
	}) => _scrollLock.protect(() async {
		if (persistentState.thread == null) {
			// too early to try to scroll
			return;
		}
		final int postId;
		double? targetAlignment;
		bool glow = false;
		if (target != null) {
			postId = target.$1;
			targetAlignment = target.$2;
			glow = true;
		}
		else if (widget.initialPostId != null) {
			postId = widget.initialPostId!;
			glow = true;
		}
		else if (context.read<PersistentBrowserTab?>()?.initialPostId[widget.thread] != null) {
			postId = context.read<PersistentBrowserTab>().initialPostId[widget.thread]!;
			glow = true;
			context.read<PersistentBrowserTab?>()?.initialPostId.remove(widget.thread);
		}
		else if (persistentState.firstVisiblePostId != null) {
			postId = persistentState.firstVisiblePostId!;
			targetAlignment = persistentState.firstVisiblePostAlignment;
		}
		else if (persistentState.lastSeenPostId != null) {
			postId = persistentState.lastSeenPostId!;
		}
		else {
			// Nothing to scroll to
			return;
		}
		if (persistentState.thread != null) {
			double? alignment = _listController.findItem((p) => p.id == postId)?.alignment;
			bool alignmentMatches() => switch ((alignment, targetAlignment)) {
				// Alignment is close enough
				(double a, double ta) => (ta - a).abs() < 0.05,
				// Just ensure it's onscreen
				(double a, null) => a >= 0 && a <= 1.0,
				// Item not built yet
				(null, _) => false
			};
			if (alignmentMatches()) {
				if (_useAllDummies) {
					setState(() {
						_useAllDummies = false;
					});
				}
				if (glow) {
					_glowPost(postId);
				}
				return;
			}
			setState(() {
				blocked = shouldBlock;
			});
			try {
				if (await _ensurePostLoaded(postId)) {
					// Need to rebuild with new post
					if (!mounted) return;
					setState(() {});
					await WidgetsBinding.instance.endOfFrame;
				}
				if (!mounted) return;
				alignment = _listController.findItem((p) => p.id == postId)?.alignment;
				if (alignmentMatches()) {
					if (_useAllDummies) {
						//await Future.delayed(const Duration(milliseconds: 500));
						// Need to realign after popping in proper items
						setState(() {
							_useAllDummies = false;
						});
						await _listController.animateTo(
							(post) => post.id == postId,
							// Lazy hack. but it works somehow to get to the unloadedPage stub
							orElseLast: postId.isNegative
								? (post) => post.id.isNegative && post.id > postId
								: (post) => post.id <= postId,
							alignment: targetAlignment ?? 0,
							duration: const Duration(milliseconds: 200)
						);
						await WidgetsBinding.instance.endOfFrame;
						if (!mounted) return;
					}
					setState(() {
						blocked = false;
					});
					return;
				}
				await Future.delayed(delayBeforeScroll);
				await WidgetsBinding.instance.endOfFrame;
				if (!mounted) return;
				await _listController.animateTo(
					(post) => post.id == postId,
					// Lazy hack. but it works somehow to get to the unloadedPage stub
					orElseLast: postId.isNegative
						? (post) => post.id.isNegative && post.id > postId
						: (post) => post.id <= postId,
					alignment: targetAlignment ?? 0,
					duration: const Duration(milliseconds: 200)
				);
				await WidgetsBinding.instance.endOfFrame;
				if (!mounted) return;
				if (_useAllDummies) {
					//await Future.delayed(const Duration(milliseconds: 500));
					// Need to realign after popping in proper items
					setState(() {
						_useAllDummies = false;
					});
					await WidgetsBinding.instance.endOfFrame;
					await _listController.animateTo(
						(post) => post.id == postId,
						// Lazy hack. but it works somehow to get to the unloadedPage stub
						orElseLast: postId.isNegative
							? (post) => post.id.isNegative && post.id > postId
							: (post) => post.id <= postId,
						alignment: targetAlignment ?? 0,
						duration: const Duration(milliseconds: 1)
					);
					await WidgetsBinding.instance.endOfFrame;
					if (!mounted) return;
				}
				final offset = ((_listController.state?.updatingNow.value != null) ? 64 : 0);
				final remainingPx = (_listController.scrollController?.position.extentAfter ?? 9999) - offset;
				if (remainingPx > 0 && remainingPx < 32) {
					// Close to the end, just round-to there
					_listController.scrollController!.position.jumpTo(_listController.scrollController!.position.maxScrollExtent - offset);
				}
				if (glow) {
					_glowPost(postId);
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
					_useAllDummies = false;
				});
			}
		}
	});

	void _maybeUpdateWatch() {
		final notifications = context.read<Notifications>();
		final threadWatch = persistentState.threadWatch;
		if (threadWatch != null && persistentState.thread != null) {
			_checkForeground();
			notifications.updateLastKnownId(threadWatch, persistentState.thread!.posts_.last.id, foreground: _foreground);
		}
	}

	void _checkForeground() {
		_foreground = switch (context.read<MasterDetailHint?>()) {
			null =>
				// Dev board in settings
				context.read<ChanTabs?>()?.mainTabIndex == 4,
			MasterDetailHint hint =>
				hint.primaryInterceptorKey.currentState?.primaryScrollControllerTracker.value != null
		};
	}

	void _onSlowScroll() {
		final lastIndex = _listController.lastVisibleIndex;
		_checkForeground();
		if (persistentState.thread != null && !blocked && lastIndex != -1 && _foreground) {
			final lastItem = _listController.getItem(lastIndex);
			_lastSeenIndex = max(lastIndex, _lastSeenIndex ?? lastIndex);
			final newLastSeen = lastItem.id;
			if (newLastSeen > (persistentState.lastSeenPostId ?? 0)) {
				persistentState.lastSeenPostId = newLastSeen;
				runWhenIdle(const Duration(milliseconds: 500), persistentState.save);
			}
			final firstIndex = _listController.firstVisibleIndex;
			if (firstIndex != -1) {
				_firstSeenIndex = min(firstIndex, _firstSeenIndex ?? firstIndex);
				final firstItem = _listController.getItem(firstIndex);
				if (persistentState.firstVisiblePostId != firstItem.item.id) {
					runWhenIdle(const Duration(milliseconds: 500), persistentState.save);
				}
				persistentState.firstVisiblePostId = firstItem.item.id;
				persistentState.firstVisiblePostAlignment = _listController.getItemAlignment(firstIndex);
			}
			final i0 = _firstSeenIndex;
			final i1 = _lastSeenIndex;
			if (i0 != null && i1 != null && i0 <= i1) {
				final items = _listController.items.toList();
				final i0Clamped = i0.clamp(0, items.length - 1);
				final seenIds = items.sublist(i0Clamped, i1.clamp(i0Clamped, items.length - 1) + 1)
														 .where((p) => !_listController.isItemHidden(p).isHidden)
														 .expand((p) => [p.item.id, ...p.representsKnownStubChildren.map((s) => s.childId)]);
				final lengthBefore = persistentState.unseenPostIds.data.length;
				persistentState.unseenPostIds.data.removeAll(seenIds);
				if (lengthBefore != persistentState.unseenPostIds.data.length) {
					persistentState.didUpdate();
					runWhenIdle(const Duration(milliseconds: 250), persistentState.save);
				}
			}
		}
		else if (blocked) {
			_firstSeenIndex = null;
			_lastSeenIndex = null;
		}
	}

	Future<void> _checkAttachmentCache(Attachment attachment) async {
		if (_cached[attachment] == _AttachmentCachingStatus.cached) return;
		if (attachment.type == AttachmentType.pdf || attachment.type == AttachmentType.url) {
			_cached[attachment] = _AttachmentCachingStatus.uncacheable;
			return;
		}
		_cached[attachment] = switch (await (await AttachmentCache.optimisticallyFindFile(attachment))?.exists()) {
			true => _AttachmentCachingStatus.cached,
			null || false => _cached[attachment] ?? _AttachmentCachingStatus.uncached
		};
	}

	Future<void> _updateCached({required bool onscreenOnly}) async {
		final attachments = (onscreenOnly ? _listController.visibleItems : _listController.items).expand((p) => p.item.attachments).toSet();
		await Future.wait(attachments.map(_checkAttachmentCache));
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

	void _onAttachmentCache(Attachment attachment) {
		if (persistentState.thread?.posts_.any((p) => p.attachments.contains(attachment)) ?? false) {
			_checkAttachmentCache(attachment);
		}
	}

	void _onPostSeenFromZone(int id) {
		if (persistentState.unseenPostIds.data.remove(id)) {
			// The post was offscreen, also remove it from newPostIds
			// so the unread counter makes more sense when we scroll down to see it
			_highlightPosts.remove(id);
			runWhenIdle(const Duration(milliseconds: 500), persistentState.save);
			_indicatorKey.currentState?._updateCounts();
		}
	}

	@override
	void initState() {
		super.initState();
		_glowingPostsAnimation = EasyListenable();
		_listController = RefreshableListController();
		persistentState = context.read<Persistence>().getThreadState(widget.thread, updateOpenedTime: true);
		_lastPersistentThreadStateSnapshot = _PersistentThreadStateSnapshot.of(persistentState);
		if (persistentState.thread == null) {
			persistentState.ensureThreadLoaded().then((_) => _onThreadStateListenableUpdate());
		}
		persistentState.useArchive |= widget.initiallyUseArchive != null;
		persistentState.useArchive |= context.read<PersistentBrowserTab?>()?.initiallyUseArchive[widget.thread] != null;
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
				else if (threadFromCatalogCache != null && !imageboard.site.isPaged) threadFromCatalogCache
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
					_listController.state?.closeSearch();
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
			onPostLoadedFromArchive: _onPostLoadedFromArchive,
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
			onPostSeen: _onPostSeenFromZone,
			shouldHighlightPost: _shouldHighlightPost,
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
				await _listController.state?.acceptNewList(zone.findThread(persistentState.id)!.posts);
			}
		);
		Future.delayed(const Duration(milliseconds: 50), () {
			if (mounted) {
				_threadStateListenable?.removeListener(_onThreadStateListenableUpdate);
				(_threadStateListenable = context.read<Persistence>().listenForPersistentThreadStateChanges(widget.thread))
					.addListener(_onThreadStateListenableUpdate);
			}
		});
		_listController.slowScrolls.addListener(_onSlowScroll);
		context.read<PersistentBrowserTab?>()?.threadPageState = this;
		if (!(context.read<MasterDetailLocation?>()?.twoPane ?? false) &&
		    persistentState.lastSeenPostId != null &&
				(persistentState.thread?.posts_.length ?? 0) > 20) {
			_useAllDummies = true;
			_scrollIfWarranted(const Duration(milliseconds: 500));
		}
		else {
			_scrollIfWarranted();
		}
		_searching |= widget.initialSearch?.isNotEmpty ?? false;
		if (Settings.instance.autoCacheAttachments) {
			_listController.waitForItemBuild(0).then((_) => _cacheAttachments(automatic: true));
		}
		else {
			_listController.waitForItemBuild(0).then((_) => _updateCached(onscreenOnly: false));
		}
		_cacheSubscription = AttachmentCache.stream.listen(_onAttachmentCache);
		_updateHighlightedPosts(restoring: true);
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
			_threadStateListenable?.removeListener(_onThreadStateListenableUpdate);
			(_threadStateListenable = context.read<Persistence>().listenForPersistentThreadStateChanges(widget.thread))
				.addListener(_onThreadStateListenableUpdate);
			_suggestedNewGeneral = null;
			_rejectedNewGeneralSuggestion = null;
			_weakNavigatorKey.currentState!.popAllExceptFirst();
			persistentState.save(); // Save old state in case it had pending scroll update to save
			persistentState = context.read<Persistence>().getThreadState(widget.thread, updateOpenedTime: true);
			persistentState.ensureThreadLoaded().then((_) => _onThreadStateListenableUpdate());
			persistentState.useArchive |= widget.initiallyUseArchive != null;
			persistentState.useArchive |= context.read<PersistentBrowserTab?>()?.initiallyUseArchive[widget.thread] != null;
			final oldZone = zone;
			Future.delayed(const Duration(milliseconds: 100), () => oldZone.dispose());
			final imageboard = context.read<Imageboard>();
			final threadFromCatalogCache = imageboard.site.getThreadFromCatalogCache(widget.thread);
			zone = PostSpanRootZoneData.multi(
				primaryThread: widget.thread,
				threads: [
					if (persistentState.thread != null) persistentState.thread!
					else if (threadFromCatalogCache != null && !imageboard.site.isPaged) threadFromCatalogCache
				],
				imageboard: imageboard,
				onNeedScrollToPost: oldZone.onNeedScrollToPost,
				onPostLoadedFromArchive: oldZone.onPostLoadedFromArchive,
				isPostOnscreen: oldZone.isPostOnscreen,
				glowOtherPost: oldZone.glowOtherPost,
				onPostSeen: oldZone.onPostSeen,
				shouldHighlightPost: _shouldHighlightPost,
				onNeedUpdateWithStubItems: oldZone.onNeedUpdateWithStubItems,
				semanticRootIds: [widget.boardSemanticId, 0],
				style: oldZone.style
			);
			_maybeUpdateWatch();
			persistentState.save();
			if ((persistentState.firstVisiblePostAlignment ?? 0) < 0) {
				// Scrolled down somewhat
				blocked = true;
			}
			_scrollIfWarranted();
			if (Settings.instance.autoCacheAttachments) {
				_listController.waitForItemBuild(0).then((_) => _cacheAttachments(automatic: true));
			}
			_highlightPosts.clear();
			_updateHighlightedPosts(restoring: true);
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
		setHandoffUrl(_foreground ? context.read<ImageboardSite>().getWebUrl(
			board: widget.thread.board,
			threadId: widget.thread.id,
			archiveName: archiveName
		) : null);
	}

	Future<void> _scrollIfWarranted([Duration delayBeforeScroll = Duration.zero]) async {
		final int? explicitScrollToId = widget.initialPostId ?? context.read<PersistentBrowserTab?>()?.initialPostId[widget.thread];
		if (explicitScrollToId != widget.thread.id && (explicitScrollToId != null || !(useTree && context.read<ImageboardSite>().useTree && persistentState.firstVisiblePostId == null))) {
			await _blockAndScrollToPostIfNeeded(delayBeforeScroll: delayBeforeScroll);
		}
		else {
			if (explicitScrollToId == widget.thread.id) {
				_glowPost(widget.thread.id);
			}
			if (_useAllDummies) {
				setState(() {
					_useAllDummies = false;
				});
			}
		}
	}

	void _showGallery({
		bool initiallyShowChrome = false,
		TaggedAttachment? initialAttachment,
		bool initiallyShowGrid = false
	}) {
		final imageboard = context.read<Imageboard>();
		final commonParentIds = [widget.boardSemanticId, 0];
		List<TaggedAttachment> attachments = _listController.items.expand((item) {
			if (item.representsStubChildren || _listController.isItemHidden(item).isDuplicate) {
				return const <TaggedAttachment>[];
			}
			return item.item.attachments.map((a) => TaggedAttachment(
				attachment: a,
				semanticParentIds: commonParentIds.followedBy(item.parentIds),
				imageboard: imageboard
			));
		}).toList();
		if (!attachments.contains(initialAttachment)) {
			final hiddenAttachments = _listController.state?.filteredValues.expand((item) => item.item.attachments.map((a) => TaggedAttachment(
				attachment: a,
				semanticParentIds: commonParentIds.followedBy(item.parentIds),
				imageboard: imageboard
			))).toList() ?? [];
			if (hiddenAttachments.contains(initialAttachment)) {
				attachments = hiddenAttachments;
			}
		}
		else {
			// Dedupe
			final found = <Attachment, TaggedAttachment>{};
			int startIndex = -1;
			if (useTree && initialAttachment != null) {
				startIndex = attachments.indexOf(initialAttachment);
				found[initialAttachment.attachment] = initialAttachment;
			}
			if (startIndex == -1) {
				for (final a in attachments) {
					found.putIfAbsent(a.attachment, () => a);
				}
			}
			else {
				final limit = max(startIndex, attachments.length - startIndex);
				for (int i = 1; i <= limit; i++) {
					final high = startIndex + i;
					if (high < attachments.length) {
						found.putIfAbsent(attachments[high].attachment, () => attachments[high]);
					}
					final low = startIndex - i;
					if (low >= 0) {
						found.putIfAbsent(attachments[low].attachment, () => attachments[low]);
					}
				}
			}
			attachments.removeWhere((a) => found[a.attachment] != a);
		}
		showGalleryPretagged(
			context: context,
			attachments: attachments,
			posts: {
				for (final item in _listController.items)
					for (final attachment in item.item.attachments)
						attachment: persistentState.imageboard!.scope(item.item)
			},
			zone: zone,
			replyBoxZone: _replyBoxZone,
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
						semanticParentIds: [widget.boardSemanticId, 0].followedBy(nextPostWithImage.parentIds),
						imageboard: context.read<Imageboard>()
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

	Future<void> _onPostLoadedFromArchive(Post asArchived) async {
		final thread = persistentState.thread;
		if (persistentState.identifier == asArchived.threadIdentifier && thread != null) {
			final newInsert = zone.findPost(asArchived.id) == null;
			thread.mergePosts(null, [asArchived], context.read<ImageboardSite>());
			if (newInsert) {
				_highlightPosts[asArchived.id] = _kHighlightFull;
				persistentState.unseenPostIds.data.add(asArchived.id);
			}
			zone.addThread(thread);
			await persistentState.didMutateThread();
			await _listController.state?.acceptNewList(thread.posts);
			setState(() {});
		}
	}

	Future<void> _switchToLive() async {
		if (persistentState.thread?.isDeleted == true || persistentState.thread?.isArchived == true) {
			persistentState.thread?.isDeleted = false;
			persistentState.thread?.isArchived = false;
			persistentState.didMutateThread();
		}
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
				foregroundMuted: defaultThreadWatch.foregroundMuted,
				notifyOnSecondLastPage: defaultThreadWatch.notifyOnSecondLastPage,
				notifyOnLastPage: defaultThreadWatch.notifyOnLastPage,
				notifyOnDead: defaultThreadWatch.notifyOnDead
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
		if (!mounted) return;
		final catalog = await imageboard.site.getCatalog(widget.thread.board, priority: _priority, acceptCachedAfter: DateTime.now().subtract(const Duration(seconds: 30)));
		if (!mounted) return;
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

	Future<bool> _loadReferencedThreads({bool setStateAfterwards = false, CancelToken? cancelToken}) async {
		final imageboard = context.read<Imageboard>();
		final tmpZone = zone;
		final newThread = persistentState.thread;
		if (newThread == null || tmpZone.primaryThread != newThread.identifier) {
			// The thread switched
			return false;
		}
		final crossThreads = <ThreadIdentifier, Set<int>>{};
		for (final id in newThread.posts.expand((p) => p.referencedPostIdentifiers)) {
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
				final newThread = await imageboard.site.getThread(id, priority: _priority, cancelToken: cancelToken);
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

	Future<Thread> _getUpdatedThread(CancelToken? cancelToken) async {
		final tmpPersistentState = persistentState;
		final site = context.read<ImageboardSite>();
		final settings = Settings.instance;
		final notifications = context.read<Notifications>();
		final oldThread = tmpPersistentState.thread;
		final bool firstLoad = oldThread == null;
		// The thread might switch in this interval
		_checkForeground();
		final Thread newThread;
		if (tmpPersistentState.useArchive) {
			newThread = await site.getThreadFromArchive(
				widget.thread,
				priority: _priority,
				cancelToken: cancelToken,
				archiveName:
					tmpPersistentState.thread?.archiveName ??
					widget.initiallyUseArchive ??
					context.read<PersistentBrowserTab?>()?.initiallyUseArchive[widget.thread]
			);
		}
		else {
			try {
				final lastUpdatedTime = oldThread?.lastUpdatedTime ?? oldThread?.posts_.tryLast?.time;
				if (oldThread != null && lastUpdatedTime != null) {
					final maybeNewThread = await site.getThreadIfModifiedSince(
						widget.thread,
						lastUpdatedTime,
						variant: tmpPersistentState.variant,
						priority: _priority,
						cancelToken: cancelToken
					);
					if (maybeNewThread != null) {
						await site.updatePageNumber(maybeNewThread, true, priority: _priority, cancelToken: cancelToken);
						newThread = maybeNewThread;
					}
					else {
						await site.updatePageNumber(oldThread, false, priority: _priority, cancelToken: cancelToken);
						newThread = oldThread;
					}
				} 
				else {
					newThread = await site.getThread(
						widget.thread,
						variant: tmpPersistentState.variant,
						priority: _priority,
						cancelToken: cancelToken
					);
				}
			}
			on ThreadNotFoundException {
				if (site.archives.isEmpty) {
					tmpPersistentState.thread?.isDeleted = true;
					_listController.state?.forceRebuildId++;
					setState(() {});
				}
				rethrow;
			}
		}
		bool shouldScroll = false;
		final watch = tmpPersistentState.threadWatch;
		if (watch != null && newThread.identifier == widget.thread && mounted) {
			_checkForeground();
			notifications.updateLastKnownId(watch, newThread.posts_.last.id, foreground: _foreground);
		}
		await _listController.whenDoneAutoScrolling;
		newThread.mergePosts(
			tmpPersistentState.thread,
			tmpPersistentState.thread?.posts ?? site.getThreadFromCatalogCache(newThread.identifier)?.posts ?? [],
			site
		);
		final loadedReferencedThreads = await _loadReferencedThreads(cancelToken: cancelToken);
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
		if (firstLoad) {
			// Don't highlight the first-loaded posts, it looks bad to have everything highlighted
			for (final id in persistentState.unseenPostIds.data) {
				_highlightPosts[id] = _kHighlightZero;
			}
		}
		final anyPostsMarkedSeen = _updateHighlightedPosts(restoring: false);
		if (loadedReferencedThreads || anyPostsMarkedSeen) {
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
		_firstSeenIndex = null;
		_lastSeenIndex = null;
		await WidgetsBinding.instance.endOfFrame;
		final tmp = _postUpdateCallbacks.toList();
		_postUpdateCallbacks.clear();
		for (final cb in tmp) {
			cb();
		}
	}

	Future<List<Post>> _updateWithStubItems(List<ParentAndChildIdentifier> ids, {CancelToken? cancelToken}) async {
		final thread = persistentState.thread;
		if (thread == null) {
			throw Exception('Thread not loaded');
		}
		final site = context.read<ImageboardSite>();
		final newChildren = await site.getStubPosts(thread.identifier, ids, priority: RequestPriority.interactive, cancelToken: cancelToken);
		if (widget.thread != thread.identifier) {
			throw Exception('Thread changed');
		}
		final oldIds = {
			for (final post in thread.posts_)
				post.id: post.isStub
		};
		if (_updateHighlightedPosts(restoring: false)) {
			_listController.state?.forceRebuildId++; // To force widgets to re-build and re-compute [highlight]
		}
		for (final p in newChildren) {
			if (!p.isPageStub && oldIds[p.id] != p.isStub && !persistentState.youIds.contains(p.id)) {
				persistentState.unseenPostIds.data.add(p.id);
				_highlightPosts[p.id] = _kHighlightFull;
			}
		}
		final anyNew = thread.mergePosts(null, newChildren, site);
		if (ids.length == 1 && ids.single.childId == ids.single.parentId) {
			// Clear hasOmittedReplies in case it has only omitted shadowbanned replies
			thread.posts_.tryFirstWhere((p) => p.id == ids.single.childId)?.hasOmittedReplies = false;
		}
		zone.addThread(thread);
		if (anyNew) {
			persistentState.didMutateThread();
		}
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
								board: widget.thread.boardKey,
								threadId: widget.thread.id,
								onInitState: onInitState,
								isArchived: persistentState.disableUpdates,
								initialDraft: persistentState.draft,
								onDraftChanged: (draft) async {
									persistentState.draft = draft;	
									await SchedulerBinding.instance.endOfFrame;
									_replyBoxKey.currentState?.draft = draft;
									runWhenIdle(const Duration(seconds: 3), persistentState.save);
								},
								onReplyPosted: (board, receipt) async {
									if (imageboard.site.supportsPushNotifications) {
										await promptForPushNotificationsIfNeeded(context);
									}
									if (!ctx.mounted) return;
									if (persistentState.lastSeenPostId == persistentState.thread?.posts_.last.id) {
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

	void _onTapPostId(int threadId, int id) {
		if ((context.read<MasterDetailLocation?>()?.isVeryConstrained ?? false) && _replyBoxKey.currentState?.show != true) {
			_popOutReplyBox((state) => state.onTapPostId(threadId, id));
		}
		else {
			_replyBoxKey.currentState?.onTapPostId(threadId, id);
		}
		setState(() {});
	}

	void _onQuoteText(String text, {required PostIdentifier? backlink}) {
		if ((context.read<MasterDetailLocation?>()?.isVeryConstrained ?? false) && _replyBoxKey.currentState?.show != true) {
			_popOutReplyBox((state) => state.onQuoteText(text, backlink: backlink));
		}
		else {
			_replyBoxKey.currentState?.onQuoteText(text, backlink: backlink);
		}
		setState(() {});
	}

	late final _replyBoxZone = ReplyBoxZone(
		onTapPostId: _onTapPostId,
		onQuoteText: _onQuoteText
	);

	VoidCallback? _makeOnDoubleTap(int postId) {
		if (!Settings.instance.doubleTapToHidePosts) {
			return null;
		}
		return () {
			final hiding = persistentState.getPostHiding(postId);
			persistentState.setPostHiding(postId, switch (hiding) {
				PostHidingState.hidden || PostHidingState.treeHidden => PostHidingState.shown,
				PostHidingState.shown || PostHidingState.none => PostHidingState.hidden
			});
			persistentState.save();
			setState(() {});
			if (context.mounted) {
				showUndoToast(
					context: context,
					message: 'Post ${switch (hiding) {
						PostHidingState.hidden || PostHidingState.treeHidden => 'unhidden',
						PostHidingState.shown || PostHidingState.none => 'hidden'
					}}',
					onUndo: () {
						persistentState.setPostHiding(postId, hiding);
						persistentState.save();
						setState(() {});
					}
				);
			}
		};
	}

	double _shouldHighlightPost(int id) {
		return _highlightPosts[id] ?? _kHighlightZero;
	}

	@override
	Widget build(BuildContext context) {
		_parentTab = context.watchIdentity<PersistentBrowserTab?>();
		final imageboard = context.watch<Imageboard>();
		final site = imageboard.site;
		final theme = context.watch<SavedTheme>();
		final titleText =
			(persistentState.thread?.title ?? site.getThreadFromCatalogCache(widget.thread)?.title)?.nonEmptyOrNull
			?? (persistentState.thread ?? site.getThreadFromCatalogCache(widget.thread))?.posts_.first.buildText().nonEmptyOrNull;
		String title;
		if (site.supportsMultipleBoards && !site.hasSharedIdSpace) {
			if (titleText != null) {
				title = '${site.formatBoardName(widget.thread.board)} - $titleText';
			}
			else {
				title = '${site.formatBoardNameWithoutTrailingSlash(widget.thread.board)}/${widget.thread.id}';
			}
		}
		else {
			title = titleText ?? 'Thread ${widget.thread.id}';
		}
		if (persistentState.thread?.isDeleted ?? false) {
			title = '(Deleted) $title';
		}
		else if (persistentState.thread?.isArchived ?? false) {
			title = '(Archived) $title';
		}
		else if (persistentState.thread?.isLocked ?? false) {
			title = '(Locked) $title';
		}
		final watch = context.select<Persistence, ThreadWatch?>((_) => persistentState.threadWatch);
		final reverseIndicatorPosition = Settings.showListPositionIndicatorsOnLeftSetting.watch(context);
		final sortingMethod = context.select<Persistence, PostSortingMethod>((_) => persistentState.effectivePostSortingMethod);
		zone.postSortingMethods = [
			if (sortingMethod == PostSortingMethod.replyCount) (a, b) => b.replyCount.compareTo(a.replyCount)
			else if (site.useTree && !useTree) (a, b) => a.id.compareTo(b.id)
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
			onPopInvokedWithResult: (didPop, result) async {
				if (!didPop) {
					_replyBoxKey.currentState?.hideReplyBox();
					setState(() {});
				}
			},
			child: FilterZone(
				filter: persistentState.metaFilter,
				child: FilterZone(
					filter: persistentState.threadFilter,
					child: MultiProvider(
						providers: [
							Provider.value(value: _replyBoxZone),
							ChangeNotifierProvider<PostSpanZoneData>.value(value: zone)
						],
						child: AdaptiveScaffold(
							resizeToAvoidBottomInset: false,
							bar: AdaptiveBar(
								title: GestureDetector(
									onTap: () {
										alert(context, 'Thread title', title, actions: {
											if (_parentTab?.board?.toLowerCase() != widget.thread.board.toLowerCase())
												'Open ${site.formatBoardName(widget.thread.board)}': () => context.read<ChanTabs>().goToPost(
													imageboardKey: imageboard.key,
													board: widget.thread.board,
													threadId: null,
													openNewTabIfNeeded: true
												)
										});
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
									if (!(persistentState.showInHistory ?? false)) AdaptiveIconButton(
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
												persistentState.thread ??= persistentState.imageboard?.site.getThreadFromCatalogCache(persistentState.identifier);
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
																		style: variant == (persistentState.variant ?? persistentState.thread?.suggestedVariant ?? site.threadVariants.first) ? CommonTextStyles.bold : null
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
											onPressed: () async {
												final openInNewTabZone = context.read<OpenInNewTabZone?>();
												await shareOne(
													context: context,
													text: site.getWebUrl(
														board: widget.thread.board,
														threadId: widget.thread.id,
														archiveName: archiveName
													),
													type: "text",
													sharePositionOrigin: _shareButtonKey.currentContext?.globalSemanticBounds,
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
																	alertError(context, e, st);
																}
															}
														}
													}
												);
											}
										)
									),
									if (site.supportsPosting) NotifyingIcon(
										sideBySide: true,
										primaryCount: MappingValueListenable(
											parent: Outbox.instance,
											mapper: (o) =>
												o.queuedPostsFor(persistentState.imageboardKey, widget.thread.board, widget.thread.id).where((e) => e.state.isSubmittable).length
										),
										secondaryCount: MappingValueListenable(
											parent: Outbox.instance,
											mapper: (o) => o.submittableCount - o.queuedPostsFor(persistentState.imageboardKey, widget.thread.board, widget.thread.id).where((e) => e.state.isSubmittable).length
										),
										icon: Opacity(
											opacity: persistentState.disableUpdates ? 0.5 : 1,
											child: AdaptiveIconButton(
												onPressed: () {
													if ((context.read<MasterDetailLocation?>()?.isVeryConstrained ?? false) && _replyBoxKey.currentState?.show != true) {
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
									)
								]
							),
							body: ReplyBoxLayout(
								body: TransformedMediaQuery(
									transformation: (context, mq) => mq.removePadding(removeBottom: _replyBoxKey.currentState?.show ?? false),
									child: Shortcuts(
										shortcuts: {
											ConditionalShortcut(
												parent: LogicalKeySet(LogicalKeyboardKey.keyG),
												condition: () => !(_listController.state?.searchHasFocus ?? false)
											): const OpenGalleryIntent()
										},
										child: Actions(
											actions: {
												OpenGalleryIntent: CallbackAction<OpenGalleryIntent>(
													onInvoke: (i) {
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
															Visibility(
																visible: blocked,
																child: Center(
																	child: Column(
																		mainAxisSize: MainAxisSize.min,
																		children: [
																			const CircularProgressIndicator.adaptive(),
																			AnimatedBuilder(
																				animation: _listController,
																				builder: (context, _) => ValueListenableBuilder(
																					valueListenable: _listController.updatingNow,
																					builder: (context, pair, _) {
																						if (pair == null) {
																							return const SizedBox.shrink();
																						}
																						return HiddenCancelButton(
																							cancelToken: pair.cancelToken,
																							icon: const Text('Cancel'),
																							alignment: Alignment.topCenter
																						);
																					}
																				)
																			)
																		]
																	)
																)
															),
															Visibility.maintain(
																visible: !blocked,
																child: RefreshableList<Post>(
																	filterableAdapter: (t) => (imageboard.key, t),
																	initialFilter: widget.initialSearch,
																	onFilterChanged: (filter) {
																		_searching = filter != null;
																		setState(() {});
																	},
																	key: _listKey,
																	sortMethods: zone.postSortingMethods,
																	id: '/${widget.thread.board}/${widget.thread.id}${persistentState.variant?.dataId ?? ''}',
																	disableUpdates: persistentState.disableUpdates && !(_highlightPosts.isNotEmpty || switch ((persistentState.treeSplitId, persistentState.thread?.posts_)) {
																		(int treeSplitId, List<Post> posts) => treeSplitId < posts.fold(0, (m, p) => max(m, p.id)),
																		_ => false
																	}),
																	autoUpdateDuration: autoUpdateDuration,
																	initialList: persistentState.thread?.posts ?? (site.isPaged ? null : site.getThreadFromCatalogCache(widget.thread)?.posts_.sublist(0, 1)),
																	initialTreeSplitId: persistentState.treeSplitId,
																	onTreeSplitIdChanged: (newId) {
																		persistentState.treeSplitId = newId;
																		runWhenIdle(const Duration(milliseconds: 500), persistentState.save);
																	},
																	useTree: useTree,
																	useAllDummies: _useAllDummies,
																	initialCollapsedItems: persistentState.collapsedItems,
																	initialPrimarySubtreeParents: persistentState.primarySubtreeParents,
																	onCollapsedItemsChanged: (newCollapsedItems, newPrimarySubtreeParents) {
																		Future.microtask(() {
																			if (!mounted) {
																				return;
																			}
																			for (final item in _listController.items) {
																				if (
																					// It was initially not highlighted to avoid whole thread highlighted
																					_highlightPosts[item.id] == _kHighlightZero &&
																					// It was collapsed without being seen
																					_listController.isItemHidden(item) == TreeItemCollapseType.childCollapsed
																				) {
																					_highlightPosts[item.id] = _kHighlightPartial;
																				}
																			}
																		});
																		persistentState.collapsedItems = newCollapsedItems.toList();
																		persistentState.primarySubtreeParents = newPrimarySubtreeParents;
																		runWhenIdle(const Duration(milliseconds: 500), persistentState.save);
																	},
																	treeAdapter: RefreshableTreeAdapter(
																		getId: (p) => p.id,
																		getParentIds: (p) => p.repliedToIds,
																		getIsStub: (p) => p.isStub,
																		getIsPageStub: (p) => p.isPageStub,
																		isPaged: site.isPaged,
																		getHasOmittedReplies: (p) => p.hasOmittedReplies,
																		updateWithStubItems: (_, ids, cancelToken) => _updateWithStubItems(ids, cancelToken: cancelToken),
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
																			return post.span.estimateLines(post,
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
																		if (site.archives.isNotEmpty) ThreadNotFoundException: ('Try archive', () async {
																			persistentState.useArchive = true;
																			await persistentState.save();
																		})
																	},
																	listUpdater: (options) async {
																		if (persistentState.disableUpdates && _listController.state?.originalList != null) {
																			if (options.source.manual) {
																				await Future.delayed(const Duration(milliseconds: 650));
																				// This is just to clear highlighted posts / resort tree on archived threads
																				_highlightPosts.clear();
																				_listController.state?.forceRebuildId++; // To force widgets to re-build and re-compute [highlight]
																				Future.microtask(() => setState(() {}));
																			}
																			return null;
																		}
																		return (await _getUpdatedThread(options.cancelToken)).posts;
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
																					builder: (context, factor, child) => NullableColorFiltered(
																						colorFilter: factor == 0 ? null : ui.ColorFilter.mode(
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
																						semanticParentIds: context.read<PostSpanZoneData>().stackIds,
																						imageboard: imageboard
																					));
																				},
																				highlight: _shouldHighlightPost(post.id),
																				onDoubleTap: _makeOnDoubleTap(post.id)
																			)
																		);
																	},
																	filteredItemBuilder: (context, post, resetPage, filterPattern) {
																		return PostRow(
																			post: post,
																			onThumbnailTap: (attachment) {
																				_showGallery(initialAttachment: TaggedAttachment(
																					attachment: attachment,
																					semanticParentIds: context.read<PostSpanZoneData>().stackIds,
																					imageboard: imageboard
																				));
																			},
																			onTap: () async {
																				resetPage();
																				await Future.delayed(const Duration(milliseconds: 250));
																				await _listController.animateTo((val) => val.id == post.id);
																				await _glowPost(post.id);
																			},
																			baseOptions: PostSpanRenderOptions(
																				highlightPattern: filterPattern
																			),
																			highlight: _shouldHighlightPost(post.id),
																			onDoubleTap: _makeOnDoubleTap(post.id)
																		);
																	},
																	collapsedItemBuilder: ({
																		required BuildContext context,
																		required Post? value,
																		required Set<int> collapsedChildIds,
																		required bool loading,
																		required double? peekContentHeight,
																		required List<ParentAndChildIdentifier>? stubChildIds,
																		required bool alreadyDim
																	}) {
																		if ((value?.id ?? 0).isNegative) {
																			return Row(
																				mainAxisAlignment: MainAxisAlignment.center,
																				children: [
																					const Icon(CupertinoIcons.doc),
																					const SizedBox(width: 8),
																					Flexible(
																						child: Text(
																							'Page ${value?.id.abs()}',
																							textAlign: TextAlign.center
																						)
																					),
																					const SizedBox(width: 8),
																					const Icon(CupertinoIcons.arrow_up_down)
																				]
																			);
																		}
																		final newCount = collapsedChildIds.where((id) => (_highlightPosts[id] ?? _kHighlightZero) > _kHighlightZero).length;
																		final unseenCount = collapsedChildIds.where(persistentState.unseenPostIds.data.contains).length;
																		final isDeletedStub = value != null && value.isDeleted && value.text.isEmpty && value.attachments.isEmpty;
																		if (peekContentHeight != null && value != null) {
																			final style = TextStyle(
																				color: theme.secondaryColor,
																				fontWeight: FontWeight.bold,
																				fontVariations: CommonFontVariations.bold
																			);
																			final post = Builder(
																				builder: (context) => PostRow(
																					post: value,
																					dim: !alreadyDim && (isDeletedStub || peekContentHeight.isFinite),
																					highlight: _shouldHighlightPost(value.id),
																					onThumbnailTap: (attachment) {
																						_showGallery(initialAttachment: TaggedAttachment(
																							attachment: attachment,
																							semanticParentIds: context.read<PostSpanZoneData>().stackIds,
																							imageboard: imageboard
																						));
																					},
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
																				color: switch (([value?.id ?? -1, ...(stubChildIds?.map((x) => x.childId) ?? <int>[])]).fold(0.0, (t, i) => max(t, _shouldHighlightPost(i)))) {
																					0.0 => null,
																					double x => theme.primaryColorWithBrightness(0.1 * x)
																				},
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
																	filterHint: 'Search in thread',
																	injectBelowScrollbar: settings.showYousInScrollbar ? Positioned(
																		right: 0,
																		top: 0,
																		bottom: 0,
																		child: SafeArea(
																			child: _ThreadScrollbar(
																				persistentState: persistentState,
																				listController: _listController
																			)
																		)
																	) : null
																)
															),
															Visibility.maintain(
																visible: !blocked,
																child: SafeArea(
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
																			highlightPosts: _highlightPosts,
																			glowPost: _glowPost,
																			searching: _searching,
																			passedFirstLoad: _passedFirstLoad,
																			blocked: blocked,
																			boardSemanticId: widget.boardSemanticId,
																			forceThreadRebuild: () {
																				_firstSeenIndex = null;
																				_lastSeenIndex = null;
																				setState(() {});
																			},
																			developerModeButtons: [
																				[('Override last-seen', const Icon(CupertinoIcons.arrow_up_down), () {
																					final allIds = (persistentState.thread?.posts_.map((i) => i.id) ?? _listController.items.map((i) => i.id));
																					final id = _listController.lastVisibleItem?.id;
																					if (id != null) {
																						if (useTree) {
																							// Something arbitrary
																							final x = allIds.toList()..shuffle();
																							persistentState.unseenPostIds.data.addAll(x.take(x.length ~/ 2));
																						}
																						else {
																							persistentState.unseenPostIds.data.addAll(allIds.where((x) => x > id));
																						}
																						persistentState.lastSeenPostId = id;
																						persistentState.save();
																						_indicatorKey.currentState?._updateCounts();
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
																			),
																			replyBoxKey: _replyBoxKey
																		)
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
								replyBox: site.supportsPosting ? RepaintBoundary(
									child: ReplyBox(
										key: _replyBoxKey,
										board: widget.thread.boardKey,
										threadId: widget.thread.id,
										isArchived: persistentState.disableUpdates,
										initialDraft: persistentState.draft,
										onDraftChanged: (draft) {
											persistentState.draft = draft;
											runWhenIdle(const Duration(seconds: 3), persistentState.save);
										},
										onReplyPosted: (board, receipt) async {
											if (site.supportsPushNotifications) {
												await promptForPushNotificationsIfNeeded(context);
											}
											if (persistentState.lastSeenPostId == persistentState.thread?.posts_.last.id) {
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
								) : const SizedBox.shrink()
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
		_threadStateListenable?.removeListener(_onThreadStateListenableUpdate);
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
		_cacheSubscription.cancel();
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
	final Map<int, double> highlightPosts;
	final ValueChanged<int> glowPost;
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
	final GlobalKey<ReplyBoxState> replyBoxKey;
	final VoidCallback forceThreadRebuild;
	
	const _ThreadPositionIndicator({
		required this.persistentState,
		required this.thread,
		required this.threadIdentifier,
		required this.listController,
		required this.zone,
		this.reversed = false,
		required this.useTree,
		required this.highlightPosts,
		required this.glowPost,
		required this.searching,
		required this.passedFirstLoad,
		required this.blocked,
		required this.boardSemanticId,
		required this.cachedAttachments,
		required this.attachmentsCachingQueue,
		required this.startCaching,
		required this.openGalleryGrid,
		required this.suggestedThread,
		required this.replyBoxKey,
		required this.forceThreadRebuild,
		this.developerModeButtons = const [],
		Key? key
	}) : super(key: key);

	@override
	createState() => _ThreadPositionIndicatorState();
}

class _ThreadPositionIndicatorState extends State<_ThreadPositionIndicator> with SingleTickerProviderStateMixin {
	List<Post>? _filteredPosts;
	List<RefreshableListItem<Post>>? _filteredItems;
	List<int> _youIds = [];
	int _redCountAbove = 0;
	int _redCountBelow = 0;
	int _whiteCountAbove = 0;
	int _whiteCountBelow = 0;
	int _greyCount = 0;
	Timer? _waitForRebuildTimer;
	late final AnimationController _buttonsAnimationController;
	late final Animation<double> _buttonsAnimation;
	int _lastListControllerItemsLength = 0;
	int _lastFirstVisibleIndex = -1;
	int _lastLastVisibleIndex = -1;
	int _lastItemsLength = 0;
	final _animatedPaddingKey = GlobalKey(debugLabel: '_ThreadPositionIndicatorState._animatedPaddingKey');
	late final ScrollController _menuScrollController;
	ValueNotifier<({String id, Future<void> future, CancelToken cancelToken})?>? _lastUpdatingNow;
	late bool _useCatalogCache;
	Filter? _lastFilter;
	bool _skipNextSwipe = false;

	Future<bool> _updateCounts() async {
		final site = context.read<ImageboardSite>();
		await WidgetsBinding.instance.endOfFrame;
		if (!mounted) return false;
		final firstVisibleIndex = widget.listController.firstVisibleIndex;
		final lastVisibleIndex = widget.listController.lastVisibleIndex;
		if (firstVisibleIndex == -1 || lastVisibleIndex == -1 || (!widget.useTree && _filteredPosts == null) || (widget.useTree && _filteredItems == null)) {
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
		_youIds = widget.persistentState.replyIdsToYou() ?? [];
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
			if (items[i].item.isPageStub) {
				continue;
			}
			if (i > lastVisibleIndex) {
				if (items[i].representsKnownStubChildren.isNotEmpty) {
					for (final stubChild in items[i].representsKnownStubChildren) {
						if (widget.persistentState.unseenPostIds.data.contains(stubChild.childId)) {
							whiteBelow.add(stubChild.childId);
						}
						else {
							greyBelow.add(stubChild.childId);
						}
					}
				}
				else if (widget.persistentState.unseenPostIds.data.contains(items[i].item.id)) {
					whiteBelow.add(items[i].item.id);
					if (_youIds.contains(items[i].item.id)) {
						redBelow.add(items[i].item.id);
					}
				}
				else {
					greyBelow.add(items[i].item.id);
				}
			}
			else if (i < firstVisibleIndex) {
				if (items[i].representsKnownStubChildren.isNotEmpty) {
					for (final stubChild in items[i].representsKnownStubChildren) {
						if (widget.persistentState.unseenPostIds.data.contains(stubChild.childId)) {
							whiteAbove.add(stubChild.childId);
						}
					}
				}
				else if (widget.persistentState.unseenPostIds.data.contains(items[i].item.id)) {
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
					if (widget.persistentState.unseenPostIds.data.contains(stubChild.childId)) {
						whiteBelow.add(stubChild.childId);
					}
					else {
						greyBelow.add(stubChild.childId);
					}
				}
			}
			else if ((items.length - 1) > lastVisibleIndex) {
				if (widget.persistentState.unseenPostIds.data.contains(items.last.item.id)) {
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
		setState(() {});
		return true;
	}

	Future<bool> _onSlowScroll() async {
		if (widget.blocked) {
			return false;
		}
		final firstVisibleIndex = widget.listController.firstVisibleIndex;
		final lastVisibleIndex = widget.listController.lastVisibleIndex;
		_filteredItems ??= widget.listController.items.toList();
		final skip = widget.blocked || (_lastFirstVisibleIndex == firstVisibleIndex && _lastLastVisibleIndex == lastVisibleIndex && _lastItemsLength == widget.listController.itemsLength);
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

	Future<void> _pollForOnSlowScroll() async {
		_waitForRebuildTimer?.cancel();
		_waitForRebuildTimer = null;
		if (!await _onSlowScroll()) {
			_waitForRebuildTimer?.cancel();
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
				_useCatalogCache = false;
			}
			if (widget.threadIdentifier != oldWidget.threadIdentifier) {
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
			_lastFilter = newFilter;
			// Reset some state
			if (widget.thread == null) {
				_filteredPosts = null;
				_filteredItems = null;
				_useCatalogCache = true;
			}
			else {
				_filteredPosts = widget.persistentState.filteredPosts();
				_filteredItems = null; // Likely not built yet
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
		final useMaterial = ChanceTheme.materialOf(context);
		final radius = useMaterial ? const Radius.circular(4) : const Radius.circular(8);
		final radiusAlone = BorderRadius.all(radius);
		final radiusStart = widget.reversed ? BorderRadius.only(topRight: radius, bottomRight: radius) : BorderRadius.only(topLeft: radius, bottomLeft: radius);
		final radiusEnd = widget.reversed ? BorderRadius.only(topLeft: radius, bottomLeft: radius) : BorderRadius.only(topRight: radius, bottomRight: radius);
		final scrollAnimationDuration = Settings.showAnimationsSetting.watch(context) ? const Duration(milliseconds: 200) : const Duration(milliseconds: 1);
		scrollToTop() => widget.listController.animateToIndex(0, duration: scrollAnimationDuration);
		scrollToBottom() {
			final lastVisibleIndex = widget.listController.lastVisibleIndex;
			if (lastVisibleIndex != -1) {
				final markAsRead = widget.listController.items.skip(lastVisibleIndex + 1).map((item) => item.item.id).toSet();
				widget.persistentState.unseenPostIds.data.removeAll(markAsRead);
				widget.persistentState.lastSeenPostId = markAsRead.fold<int>(0, max);
				widget.persistentState.didUpdate();
				runWhenIdle(const Duration(milliseconds: 500), widget.persistentState.save);
				_updateCounts();
			}
			widget.listController.animateToIndex(widget.listController.itemsLength - 1, alignment: 1.0, duration: scrollAnimationDuration);
		}
		final youIds = widget.persistentState.youIds;
		final uncachedCount = widget.cachedAttachments.values.where((v) => !v.isCached).length;
		final uncachedMB = (widget.cachedAttachments.entries.map((e) => e.value.isCached ? 0 : e.key.sizeInBytes ?? 0).fold(0, (a, b) => a + b) / (1024*1024));
		final uncachedMBIsUncertain = widget.cachedAttachments.entries.any((e) => !e.value.isCached && e.key.sizeInBytes == null);
		final cachingButtonLabel = '${uncachedMB.ceil()}${uncachedMBIsUncertain ? '+' : ''} MB';
		final showGalleryGridButton = Settings.showGalleryGridButtonSetting.watch(context);
		final realImageCount = widget.listController.items.fold<int>(0, (t, a) => t + a.item.attachments.where((a) => a.type != AttachmentType.url).length);
		final postSortingMethod = widget.persistentState.effectivePostSortingMethod;
		final poll = widget.thread?.poll;
		final site = context.read<ImageboardSite>();
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
						padding: EdgeInsets.only(bottom: (widget.suggestedThread != null ? 50 : 0) + 50),
						child: SingleChildScrollView(
							// The contents are not really rectangular and have an intentionally transparent background
							hitTestBehavior: HitTestBehavior.deferToChild,
							reverse: true,
							primary: false,
							controller: _menuScrollController,
							child: Stack(
								children: [
									// To absorb scroll in padding around shortest buttons
									Positioned(
										top: 0,
										bottom: 0,
										left: widget.reversed ? 0 : null,
										right: widget.reversed ? null : 0,
										child: const SizedBox(
											width: 100,
											child: AbsorbPointer()
										)
									),
									Column(
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
												if (realImageCount > 0) [(
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
															semanticParentIds: commonParentIds.followedBy(item.parentIds),
															imageboard: imageboard
														))).toList();
														final initialAttachment = TaggedAttachment(
															attachment: nextPostWithImage.item.attachments.first,
															semanticParentIds: commonParentIds.followedBy(nextPostWithImage.parentIds),
															imageboard: imageboard
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
												if (site.archives.isEmpty) [('Archive', const Icon(CupertinoIcons.archivebox, size: 19), null)]
												else [
													if (site.archives.length > 1) ('', const Icon(CupertinoIcons.gear, size: 19), () async {
														final archives = await modalLoad(context, 'Scanning archives...', (controller) async {
															return (await Future.wait(
																site.archives.map(
																	(s) async => (s, await s.getBoards(priority: RequestPriority.interactive))
																)
															)).tryMap((e) {
																if (e.$2.any((b) => b.boardKey == widget.persistentState.boardKey)) {
																	return e.$1;
																}
																return null;
															}).toList();
														});
														if (!context.mounted) {
															return;
														}
														if (archives.isEmpty) {
															showToast(
																context: context,
																message: 'Board not archived',
																icon: CupertinoIcons.exclamationmark_triangle
															);
															return;
														}
														final archive = await showAdaptiveDialog<ImageboardSiteArchive>(
															context: context,
															barrierDismissible: true,
															builder: (context) => AdaptiveAlertDialog(
																title: const Text('Select archive'),
																actions: [
																	for (final a in archives) AdaptiveDialogAction(
																		onPressed: () => Navigator.pop(context, a),
																		child: Text(a.name)
																	),
																	AdaptiveDialogAction(
																		onPressed: () => Navigator.pop(context),
																		child: const Text('Cancel')
																	)
																]
															)
														);
														if (archive != null) {
															// Dreadful hack
															widget.persistentState.thread?.archiveName = archive.name;
															widget.persistentState.useArchive = true;
															widget.persistentState.save();
															setState(() {});
															widget.listController.blockAndUpdate();
														}
													}),
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
													})
												],
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
													('${postSortingMethod == PostSortingMethod.none ? 'Sort' : postSortingMethod.displayName}...', const Icon(CupertinoIcons.sort_down, size: 19), () async {
														final defaultMethod = widget.persistentState.imageboard?.persistence.browserState.postSortingMethodPerBoard[widget.persistentState.boardKey] ?? widget.persistentState.imageboard?.persistence.browserState.postSortingMethod ?? PostSortingMethod.none;
														final choice = await showAdaptiveModalPopup<NullWrapper<PostSortingMethod>>(
															context: context,
															useRootNavigator: false,
															builder: (context) => AdaptiveActionSheet(
																title: const Text('Sort by...'),
																actions: [
																	AdaptiveActionSheetAction(
																		onPressed: () => Navigator.pop(context, const NullWrapper<PostSortingMethod>(null)),
																		isDefaultAction: widget.persistentState.postSortingMethod == null,
																		child: Text('Default (${defaultMethod.displayName})')
																	),
																	...PostSortingMethod.values.map((v) => AdaptiveActionSheetAction(
																		onPressed: () => Navigator.pop(context, NullWrapper(v)),
																		isDefaultAction: v == widget.persistentState.postSortingMethod,
																		child: Text(v.displayName)
																	))
																],
																cancelButton: AdaptiveActionSheetAction(
																	child: const Text('Cancel'),
																	onPressed: () => Navigator.pop(context)
																)
															)
														);
														if (choice == null) {
															return;
														}
														widget.persistentState.postSortingMethod = choice.value;
														widget.listController.state?.forceRebuildId++;
														widget.persistentState.save();
														widget.forceThreadRebuild();
													}),
													if (widget.useTree) ('Linear', const Icon(CupertinoIcons.list_bullet, size: 19), () => setState(() {
														widget.persistentState.useTree = false;
														widget.persistentState.save();
														widget.forceThreadRebuild();
													}))
													else ('Tree', const Icon(CupertinoIcons.list_bullet_indent, size: 19), () => setState(() {
														widget.persistentState.useTree = true;
														widget.persistentState.save();
														widget.forceThreadRebuild();
													}))
												],
												[
													if (!widget.useTree) ('Mark as last-seen', const Icon(CupertinoIcons.asterisk_circle, size: 19), _greyCount == 0 ? null : () async {
														final threadState = widget.persistentState;
														final lastVisibleItem = widget.listController.lastVisibleItem;
														int lastVisibleIndex = widget.listController.lastVisibleIndex;
														if (lastVisibleItem == null || lastVisibleIndex == -1) {
															alertError(context, Exception('Failed to find last visible post'), StackTrace.current);
															return;
														}
														lastVisibleIndex++; // start at first offscreen post visible
														final newlyUnseenPostIds = Iterable.generate(widget.listController.itemsLength - lastVisibleIndex, (i) => i + lastVisibleIndex).map((i) => widget.listController.getItem(i).item.id).toSet();
														final unseenPostIds = threadState.unseenPostIds.data.toSet();
														final highlightPosts = Map.of(widget.highlightPosts);
														final lastSeenPostId = threadState.lastSeenPostId;
														for (final id in newlyUnseenPostIds) {
															widget.highlightPosts[id] = ThreadPageState._kHighlightFull;
														}
														threadState.unseenPostIds.data.addAll(newlyUnseenPostIds);
														threadState.lastSeenPostId = lastVisibleItem.id;
														threadState.didUpdate();
														widget.listController.state?.forceRebuildId++;
														setState(() {});
														_onSlowScroll();
														widget.forceThreadRebuild();
														await threadState.save();
														if (context.mounted) {
															showUndoToast(
																context: context,
																message: 'Marked Post ${lastVisibleItem.id} as last-seen',
																onUndo: () async {
																	widget.highlightPosts.clear();
																	widget.highlightPosts.addAll(highlightPosts);
																	threadState.unseenPostIds.data.clear();
																	threadState.unseenPostIds.data.addAll(unseenPostIds);
																	threadState.lastSeenPostId = lastSeenPostId;
																	threadState.didUpdate();
																	widget.listController.state?.forceRebuildId++;
																	setState(() {});
																	_onSlowScroll();
																	widget.forceThreadRebuild();
																	await threadState.save();
																}
															);
														}
													}),
													('Mark as read', const Icon(CupertinoIcons.xmark_circle, size: 19), _whiteCountAbove <= 0 && _whiteCountBelow <= 0 && widget.persistentState.unseenPostIds.data.isEmpty && widget.highlightPosts.isEmpty ? null : () async {
														final threadState = widget.persistentState;
														final unseenPostIds = threadState.unseenPostIds.data.toSet();
														final highlightPosts = Map.of(widget.highlightPosts);
														final lastSeenPostId = threadState.lastSeenPostId;
														widget.highlightPosts.clear();
														threadState.unseenPostIds.data.clear();
														threadState.lastSeenPostId = threadState.thread?.posts_.fold<int>(0, (m, p) => max(m, p.id));
														threadState.didUpdate();
														widget.listController.state?.forceRebuildId++;
														setState(() {});
														_updateCounts();
														widget.forceThreadRebuild();
														await threadState.save();
														if (context.mounted) {
															showUndoToast(
																context: context,
																message: 'Marked as read',
																onUndo: () async {
																	widget.highlightPosts.addAll(highlightPosts);
																	threadState.unseenPostIds.data.addAll(unseenPostIds);
																	threadState.lastSeenPostId = lastSeenPostId;
																	threadState.didUpdate();
																	widget.listController.state?.forceRebuildId++;
																	setState(() {});
																	_onSlowScroll();
																	widget.forceThreadRebuild();
																	await threadState.save();
																}
															);
														}
													}),
													('Update', const Icon(CupertinoIcons.refresh, size: 19), widget.listController.update)
												],
												[('Top', const Icon(CupertinoIcons.arrow_up_to_line, size: 19), scrollToTop)],
												[
													('New posts', const Icon(CupertinoIcons.arrow_down, size: 19), _whiteCountBelow <= 0 ? null : () {
														final lastVisibleIndex = widget.listController.lastVisibleIndex;
														if (lastVisibleIndex == -1) {
															return;
														}
														int targetIndex = widget.listController.items.toList().asMap().entries.tryFirstWhere((entry) {
															return entry.key > lastVisibleIndex &&
																(widget.persistentState.unseenPostIds.data.contains(entry.value.item.id) || entry.value.representsKnownStubChildren.any((id) => widget.persistentState.unseenPostIds.data.contains(id.childId))) &&
																!entry.value.filterCollapsed;
														})?.key ?? -1;
														if (targetIndex != -1) {
															widget.listController.animateToIndex(targetIndex);
														}
													}),
													('Bottom', const Icon(CupertinoIcons.arrow_down_to_line, size: 19), scrollToBottom)
												],
												if (developerMode) ...widget.developerModeButtons
											]) Padding(
												padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
												child: Wrap(
													alignment: widget.reversed ? WrapAlignment.start : WrapAlignment.end,
													runAlignment: WrapAlignment.end,
													runSpacing: 16,
													spacing: 8,
													children: buttons.map((button) =>
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
													).toList()
												)
											)
										]
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
										if (!widget.blocked && widget.listController.state?.originalList != null) AnimatedBuilder(
											animation: widget.listController,
											builder: (context, _) => ValueListenableBuilder(
												valueListenable: widget.listController.updatingNow,
												builder: (context, pair, _) {
													if (pair == null) {
														return const SizedBox.shrink();
													}
													return Row(
														mainAxisSize: MainAxisSize.min,
														children: [
															HiddenCancelButton(
																cancelToken: pair.cancelToken,
																icon: const Icon(CupertinoIcons.xmark, size: 19),
																alignment: Alignment.centerLeft
															),
															const SizedBox(
																width: 16,
																height: 16,
																child: CircularProgressIndicator.adaptive()
															),
															const SizedBox(width: 8)
														]
													);
												}
											)
										),
										if (!widget.blocked && widget.persistentState.useArchive) ...[
											Icon(CupertinoIcons.archivebox, color: theme.primaryColor.withOpacity(0.5)),
											if (widget.persistentState.thread?.archiveName case String archiveName)
												Text(' $archiveName', style: TextStyle(color: theme.primaryColor.withOpacity(0.5))),
											const SizedBox(width: 8)
										],
										if (!widget.blocked && (widget.persistentState.thread?.isLocked ?? false)) ...[
											Icon(CupertinoIcons.lock, color: theme.primaryColor.withOpacity(0.5)),
											const SizedBox(width: 8)
										],
										if (!widget.blocked && (widget.listController.state?.treeBuildingFailed ?? false)) ...[
											CupertinoButton(
												color: Colors.red,
												padding: const EdgeInsets.all(8),
												minSize: 0,
												onPressed: () => alertError(context, 'Tree too complex!\nLarge reply chains mean this thread can not be shown in tree mode.', null),
												child: Icon(CupertinoIcons.exclamationmark, color: theme.backgroundColor, size: 19)
											),
											const SizedBox(width: 8)
										],
										if (widget.replyBoxKey.currentState case ReplyBoxState replyBoxState) ValueListenableBuilder(
											valueListenable: replyBoxState.postingPost,
											builder: (context, postingPost, _) {
												if (postingPost == null) {
													return const SizedBox.shrink();
												}
												return Padding(
													padding: const EdgeInsets.only(right: 8),
													child: AnimatedBuilder(
														animation: postingPost,
														builder: (context, _) {
															final pair = postingPost.pair;
															return AdaptiveFilledButton(
																padding: const EdgeInsets.all(8),
																color: theme.primaryColorWithBrightness(0.6),
																onPressed: pair != null && pair.highPriority ? () => pair.action(context) : replyBoxState.toggleReplyBox,
																child: AnimatedSize(
																	duration: const Duration(milliseconds: 200),
																	curve: Curves.ease,
																	child: Row(
																		children: [
																			Icon(CupertinoIcons.reply, color: theme.backgroundColor, size: 19),
																			const SizedBox(width: 4),
																			DebouncedBuilder(
																				value: pair?.label ?? postingPost.statusText,
																				period: const Duration(milliseconds: 100),
																				builder: (s) => Text(s, style: TextStyle(color: theme.backgroundColor))
																			),
																			if (pair != null) TimedRebuilder(
																				interval: const Duration(seconds: 1),
																				function: () => formatDuration(pair.deadline.difference(DateTime.now()).clampAboveZero),
																				builder: (context, delta) => Text(
																					' ($delta)',
																					style: CommonTextStyles.tabularFigures
																				)
																			),
																			if (postingPost.isActivelyProcessing) ...[
																				const SizedBox(width: 8),
																				SizedBox(
																					width: 10,
																					height: 10,
																					child: ColorFiltered(
																						colorFilter: !useMaterial ? const ColorFilter.matrix([
																							-1, 0, 0, 0, 255,
																							0, -1, 0, 0, 255,
																							0, 0, -1, 0, 255,
																							0, 0, 0, 1, 0
																						]) :  const ColorFilter.matrix([
																							1, 0, 0, 0, 0,
																							0, 1, 0, 0, 0,
																							0, 0, 1, 0, 0,
																							0, 0, 0, 1, 0
																						]),
																						child: CircularProgressIndicator.adaptive(
																							valueColor: AlwaysStoppedAnimation(theme.backgroundColor),
																						)
																					)
																				),
																				const SizedBox(width: 4)
																			]
																		]
																	)
																)
															);
														}
													)
												);
											}
										),
										if (poll != null) ...[
											AdaptiveFilledButton(
												padding: const EdgeInsets.all(8),
												onPressed: () => WeakNavigator.push(context, OverscrollModalPage(
													child: PollWidget(poll: poll)
												)),
												child: Icon(Icons.bar_chart, size: 19, color: theme.backgroundColor)
											),
											const SizedBox(width: 8),
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
										if (_whiteCountAbove > 0) GestureDetector(
											onLongPress: () {
												scrollToTop();
												mediumHapticFeedback();
											},
											child: CupertinoButton(
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
															padding: const EdgeInsets.only(right: 8),
															child: Row(
																mainAxisSize: MainAxisSize.min,
																children: children
															)
														);
													}
												),
												onPressed: () {
													final firstVisibleIndex = widget.listController.firstVisibleIndex;
													int targetIndex = widget.listController.items.toList().asMap().entries.tryLastWhere((entry) {
														return entry.key < firstVisibleIndex &&
															(widget.persistentState.unseenPostIds.data.contains(entry.value.item.id) || entry.value.representsKnownStubChildren.any((id) => widget.persistentState.unseenPostIds.data.contains(id.childId))) &&
															!widget.listController.isItemHidden(entry.value).isDuplicate;
													})?.key ?? -1;
													if (targetIndex != -1) {
														widget.glowPost(widget.listController.getItem(targetIndex).item.id);
														widget.listController.animateToIndex(targetIndex);
													}
												}
											)
										),
										GestureDetector(
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

class _ThreadScrollbar extends StatefulWidget {
	final PersistentThreadState persistentState;
	final RefreshableListController<Post> listController;

	const _ThreadScrollbar({
		required this.persistentState,
		required this.listController
	});

	@override
	createState() => _ThreadScrollbarState();
}

class _ThreadScrollbarState extends State<_ThreadScrollbar> {
	ValueListenable<bool> isScrollingNotifier = const ConstantValueListenable(false);
	bool show = false;
	int things = 0;
	Timer? hideTimer;

	@override
	void initState() {
		super.initState();
		widget.listController.slowScrolls.addListener(_onSlowScroll);
		widget.persistentState.addListener(_onPersistentStateUpdate);
		things = widget.persistentState.youIds.length + (widget.persistentState.replyIdsToYou()?.length ?? 0);
	}
	
	void _onSlowScroll() {
		final newIsScrollingNotifier = widget.listController.scrollController?.tryPosition?.isScrollingNotifier;
		if (isScrollingNotifier != newIsScrollingNotifier) {
			isScrollingNotifier.removeListener(_onIsScrolling);
			isScrollingNotifier = newIsScrollingNotifier ?? const ConstantValueListenable(false);
			isScrollingNotifier.addListener(_onIsScrolling);
			_onIsScrolling();
		}
	}

	void _onPersistentStateUpdate() {
		final newThings = widget.persistentState.youIds.length + (widget.persistentState.replyIdsToYou()?.length ?? 0);
		if (newThings != things) {
			setState(() {
				things = newThings;
			});
		}
	}

	void _onIsScrolling() {
		if (!mounted) {
			return;
		}
		final isScrolling = isScrollingNotifier.value;
		if (isScrolling && !show) {
			Future.microtask(() => setState(() {
				show = true;
			}));
		}
		else if (!isScrolling && show) {
			hideTimer?.cancel();
			hideTimer = Timer(
				Settings.instance.materialStyle ? const Duration(milliseconds: 600) : const Duration(milliseconds: 1200),
				() => setState(() {
					show = false;
				})
			);
		}
		else if (isScrolling && show && hideTimer != null) {
			hideTimer?.cancel();
			hideTimer = null;
		}
	}

	@override
	void didUpdateWidget(_ThreadScrollbar oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (widget.listController != oldWidget.listController) {
			oldWidget.listController.slowScrolls.removeListener(_onSlowScroll);
			widget.listController.slowScrolls.addListener(_onSlowScroll);
			_onSlowScroll();
		}
		if (widget.persistentState != oldWidget.persistentState) {
			oldWidget.persistentState.removeListener(_onPersistentStateUpdate);
			widget.persistentState.addListener(_onPersistentStateUpdate);
			_onPersistentStateUpdate();
		}
	}

	@override
	Widget build(BuildContext context) {
		if (things == 0) {
			return const SizedBox();
		}
		final theme = context.watch<SavedTheme>();
		final scrollbarThickness = Settings.scrollbarThicknessSetting.watch(context);
		final material = Settings.instance.materialStyle;
		return AnimatedOpacity(
			duration: material ? const Duration(milliseconds: 300) : const Duration(milliseconds: 250),
			opacity: show ? 1 : 0,
			curve: Curves.fastOutSlowIn,
			child: CustomPaint(
				painter: _ThreadScrollbarCustomPainter(
					items: widget.listController.items.toList(),
					youIds: widget.persistentState.youIds.toSet(),
					replyIdsToYou: widget.persistentState.replyIdsToYou()?.toSet() ?? const {},
					theme: theme
				),
				child: SizedBox(width: scrollbarThickness + (material ? 0 : 6 /* crossAxisMargin */))
			)
		);
	}

	@override
	void dispose() {
		super.dispose();
		widget.listController.slowScrolls.removeListener(_onSlowScroll);
		widget.persistentState.removeListener(_onPersistentStateUpdate);
		hideTimer?.cancel();
	}
}

class _ThreadScrollbarCustomPainter extends CustomPainter {
	final List<RefreshableListItem<Post>> items;
	final Set<int> youIds;
	final Set<int> replyIdsToYou;
	final SavedTheme theme;

	_ThreadScrollbarCustomPainter({
		required this.items,
		required this.youIds,
		required this.replyIdsToYou,
		required this.theme
	});

	// Don't shrink the segment shorter than 12 points
	static const _kMinHeight = 12.0;
	
	@override
	void paint(ui.Canvas canvas, ui.Size size) {
		if (items.length < 5) {
			// It would look garish, and also break loop assumptions later
			return;
		}
		final youPaint = ui.Paint()..color = theme.secondaryColor;
		final replyToYouPaint = ui.Paint()..color = theme.secondaryColor.towardsBlack(0.5);
		canvas.saveLayer(null, Paint()..color = Colors.white.withOpacity(0.5)..blendMode = BlendMode.multiply);
		final hd = size.height / (items.length + 1);
		List<Paint?> slots = items.map((item) {
			if (youIds.contains(item.id)) {
				return youPaint;
			}
			else if (replyIdsToYou.contains(item.id)) {
				return replyToYouPaint;
			}
			return null;
		}).toList();
		// Bleed color into empty adjacent "slots"
		final bleedPasses = (_kMinHeight / hd).ceil() - 1;
		for (int pass = 0; pass < bleedPasses; pass++) {
			final newSlots = slots.toList();
			newSlots[0] ??= slots[1];
			for (int i = 1; i < items.length - 1; i++) {
				if (newSlots[i] != null) {
					continue;
				}
				final before = slots[i - 1];
				final after = slots[i + 1];
				if ((before ?? after) == (after ?? before)) {
					newSlots[i] = before ?? after;
				}
			}
			newSlots[slots.length - 1] ??= slots[slots.length - 2];
			slots = newSlots;
		}
		// Now merge adjacent slots into Rects
		Paint? lastPaint;
		double y0 = 0;
		for (int i = 0; i < slots.length; i++) {
			final paint = slots[i];
			if (paint == null) {
				if (lastPaint != null) {
					// End of block
					canvas.drawRect(Rect.fromLTRB(0, y0, size.width, (i + 1) * hd), lastPaint);
					lastPaint = null;
				}
				continue;
			}
			if (lastPaint == null) {
				// Start of block
				y0 = i * hd;
				lastPaint = paint;
			}
			else if (paint == lastPaint) {
				// Continue of block, no-op
			}
			else {
				// End of block, start of new block
				final y = (i + 0.5) * hd;
				canvas.drawRect(Rect.fromLTRB(0, y0, size.width, y), lastPaint);
				lastPaint = paint;
				y0 = y;
				lastPaint = paint;
			}
		}
		if (lastPaint != null) {
			// End of block
			canvas.drawRect(Rect.fromLTRB(0, y0, size.width, size.height), lastPaint);
		}
		canvas.restore();
	}
	
	@override
	bool shouldRepaint(_ThreadScrollbarCustomPainter oldDelegate) {	
		return
			!setEquals(youIds, oldDelegate.youIds) ||
			!setEquals(replyIdsToYou, oldDelegate.replyIdsToYou) ||
			!listEquals(items, oldDelegate.items) ||
			theme != oldDelegate.theme;
	}
}

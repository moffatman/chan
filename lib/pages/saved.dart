import 'dart:io';
import 'dart:math' as math;

import 'package:chan/main.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/pages/history_search.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/apple.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/pick_attachment.dart';
import 'package:chan/services/post_selection.dart';
import 'package:chan/services/reverse_image_search.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/share.dart';
import 'package:chan/services/sorting.dart';
import 'package:chan/services/storage.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/thread_collection_actions.dart' as thread_actions;
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/attachment_viewer.dart';
import 'package:chan/widgets/context_menu.dart';
import 'package:chan/widgets/cupertino_inkwell.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:chan/widgets/media_thumbnail.dart';
import 'package:chan/widgets/sliver_staggered_grid.dart';
import 'package:chan/widgets/thread_row.dart';
import 'package:chan/widgets/timed_rebuilder.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

final _downloadedAttachments = <Attachment>{};

class PostThreadCombo {
	final Imageboard imageboard;
	final Post post;
	final Thread thread;
	PostThreadCombo({
		required this.imageboard,
		required this.post,
		required this.thread
	});

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		(other is PostThreadCombo) &&
		(other.imageboard == imageboard) &&
		(other.post.id == post.id) &&
		(other.thread.identifier == thread.identifier);
	@override
	int get hashCode => Object.hash(imageboard, post, thread.identifier);

	@override
	String toString() => 'PostThreadCombo($imageboard, $thread, $post)';
}

typedef SavedPageMasterDetailPanesState = MultiMasterDetailPage5State<ImageboardScoped<ThreadWatch>, ImageboardScoped<ThreadOrPostIdentifier>, PostThreadCombo, ImageboardScoped<SavedPost>, ImageboardScoped<SavedAttachment>>;

/// As different archives may have slight mismatches
({Post post, Attachment attachment})? _findMatchingAttachment(Thread thread, Attachment a) {
	final best = <({Post post, Attachment attachment})>[];
	int bestScore = -1;
	for (final post in thread.posts) {
		for (final other in post.attachments) {
			int score = 0;
			if (a.id.isNotEmpty && a.id == other.id) {
				score += 5;
			}
			if (a.id.isNotEmpty && other.id.contains(a.id)) {
				// Archive may have timestamp with further precision
				score++;
			}
			if (a.filename.isNotEmpty && a.filename == other.filename) {
				score++;
			}
			if (a.md5.isNotEmpty && a.md5 == other.md5) {
				score++;
			}
			if (a.width != null && a.height != null && a.width == other.width && a.height == other.height) {
				score++;
			}
			if (score > bestScore) {
				bestScore = score;
				best.clear();
			}
			if (score == bestScore) {
				best.add((post: post, attachment: other));
			}
		}
	}
	return best.trySingle;
}

abstract class _SavedThreadsLoader {
	Future<List<ImageboardScoped<ThreadIdentifier>>> initialize(bool reverse);
	Future<(PersistentThreadState, Thread)?> takeSavedThread();
}

sealed class _SavedThreadsLoaderImpl<T> implements _SavedThreadsLoader {
	final List<T> _list = [];
	Future<T?> _initializeImpl(PersistentThreadState state);
	/// Sort the list (in reverse order, because removing at the end is faster)
	void _sortImpl(bool reverse);
	@override
	Future<List<ImageboardScoped<ThreadIdentifier>>> initialize(bool reverse) async {
		final missing = <ImageboardScoped<ThreadIdentifier>>[];
		for (final state in Persistence.sharedThreadStateBox.values) {
			if (state.savedTime == null) {
				continue;
			}
			final imageboard = state.imageboard;
			if (imageboard == null) {
				continue;
			}
			if (!state.isThreadCached) {
				missing.add(imageboard.scope(state.identifier));
				continue;
			}
			final entry = await _initializeImpl(state);
			if (entry != null) {
				_list.add(entry);
			}
		}
		_sortImpl(reverse);
		return missing;
	}
	PersistentThreadState _takeSavedThreadImpl(T entry);
	@override
	Future<(PersistentThreadState, Thread)?> takeSavedThread() async {
		T? entry = _list.tryRemoveLast();
		while (entry != null) {
			final state = _takeSavedThreadImpl(entry);
			final thread = await state.getThread();
			if (thread != null) {
				return (state, thread);
			}
		}
		return null;
	}
}

class _SavedThreadsByTitleLoader extends _SavedThreadsLoaderImpl<(PersistentThreadState, String)> {
	static final _cache = <PersistentThreadState, String>{};
	@override
	Future<(PersistentThreadState, String)?> _initializeImpl(PersistentThreadState state) async {
		final cached = _cache[state];
		if (cached != null) {
			return (state, cached);
		}
		final thread = await state.getThread();
		if (thread == null) {
			return null;
		}
		// Don't store whole Thread for memory reasons
		// Title should never change in a Thread, safe to cache it
		final title = _cache[state] = thread.title ?? thread.posts_.tryFirst?.buildText() ?? '';
		return (state, title);
	}
	@override
	void _sortImpl(bool reverse) {
		if (reverse) {
			// A before Z
			_list.sort((a, b) => a.$2.compareTo(b.$2));
		}
		else {
			// Z before A
			_list.sort((a, b) => b.$2.compareTo(a.$2));
		}
	}
	@override
	PersistentThreadState _takeSavedThreadImpl((PersistentThreadState, String) entry) => entry.$1;
}

class _SavedThreadsByLastPostTimeLoader extends _SavedThreadsLoaderImpl<(PersistentThreadState, DateTime)> {
	static final _cache = <PersistentThreadState, DateTime>{};
	@override
	Future<(PersistentThreadState, DateTime)?> _initializeImpl(PersistentThreadState state) async {
		final cached = _cache[state];
		if (cached != null) {
			return (state, cached);
		}
		final thread = await state.getThread();
		if (thread == null) {
			return null;
		}
		final time = thread.posts_.tryLast?.time;
		if (time == null) {
			return null;
		}
		if (thread.isArchived) {
			// Live threads may change their last-post-time, not safe to cache it
			_cache[state] = time;
		}
		// Don't store whole Thread for memory reasons
		return (state, time);
	}
	@override
	void _sortImpl(bool reverse) {
		if (reverse) {
			// Latest posted first
			_list.sort((a, b) => b.$2.compareTo(a.$2));
		}
		else {
			// Earliest posted first
			_list.sort((a, b) => a.$2.compareTo(b.$2));
		}
	}
	@override
	PersistentThreadState _takeSavedThreadImpl((PersistentThreadState, DateTime) entry) => entry.$1;
}

class _SavedThreadsBySavedTimeLoader extends _SavedThreadsLoaderImpl<PersistentThreadState> {
	static final noDate = DateTime.fromMillisecondsSinceEpoch(0);
	@override
	Future<PersistentThreadState?> _initializeImpl(PersistentThreadState state) async => state;
	@override
	void _sortImpl(bool reverse) {
		if (reverse) {
			// Latest saved first
			_list.sort((a, b) => (b.savedTime ?? noDate).compareTo(a.savedTime ?? noDate));
		}
		else {
			// Earliest saved first
			_list.sort((a, b) => (a.savedTime ?? noDate).compareTo(b.savedTime ?? noDate));
		}
	}
	@override
	PersistentThreadState _takeSavedThreadImpl(PersistentThreadState entry) => entry;
}

class _SavedThreadsByThreadPostTimeLoader implements _SavedThreadsLoader {
	final Map<(Imageboard, String), List<PersistentThreadState>> _lists = {};
	late bool _reverse;
	@override
	Future<List<ImageboardScoped<ThreadIdentifier>>> initialize(bool reverse) async {
		_reverse = reverse;
		final missing = <ImageboardScoped<ThreadIdentifier>>[];
		for (final state in Persistence.sharedThreadStateBox.values) {
			if (state.savedTime == null) {
				continue;
			}
			final imageboard = state.imageboard;
			if (imageboard == null) {
				continue;
			}
			if (!state.isThreadCached) {
				missing.add(imageboard.scope(state.identifier));
				continue;
			}
			final l = _lists.putIfAbsent((imageboard, state.board), () => []);
			l.add(state);
		}
		for (final list in _lists.values) {
			if (reverse) {
				// Latest posted first
				list.sort((a, b) => b.id.compareTo(a.id));
			}
			else {
				// Earliest posted first
				list.sort((a, b) => a.id.compareTo(b.id));
			}
		}
		return missing;
	}
	@override
	Future<(PersistentThreadState, Thread)?> takeSavedThread() async {
		final heads = <(PersistentThreadState, Thread)>[];
		for (final entry in _lists.entries) {
			while (entry.value.isNotEmpty) {
				final state = entry.value.last;
				final thread = await state.getThread();
				if (thread == null) {
					// Something missing. but we don't have to handle it here
					entry.value.removeLast();
					continue;
				}
				heads.add((state, thread));
				break;
			}
		}
		(PersistentThreadState, Thread)? latestHead;
		for (final head in heads) {
			if (latestHead == null || (_reverse ? head.$2.time.isBefore(latestHead.$2.time) : head.$2.time.isAfter(latestHead.$2.time))) {
				latestHead = head;
			}
		}
		final ret = latestHead;
		if (ret == null) {
			// No more entries
			return null;
		}
		final l = _lists[(ret.$1.imageboard, ret.$1.board)];
		if (l != null && l.isNotEmpty) {
			// This should always be non-null and non-empty. But just avoid crash.
			l.removeLast();
		}
		return ret;
	}
}

class SavedPage extends StatefulWidget {
	final GlobalKey<SavedPageMasterDetailPanesState> masterDetailKey;

	const SavedPage({
		required this.masterDetailKey,
		Key? key
	}) : super(key: key);

	@override
	createState() => _SavedPageState();
}

const _savedThreadsChunkSize = 25;
const _yourPostsChunkSize = 25;

class _SavedPageState extends State<SavedPage> {
	late final RefreshableListController<ImageboardScoped<(ThreadWatch, Thread)>> _watchedListController;
	late final RefreshableListController<(PersistentThreadState, Thread)> _threadListController;
	late final RefreshableListController<ImageboardScoped<(SavedPost, Thread)>> _postListController;
	late final RefreshableListController<PostThreadCombo> _yourPostsListController;
	final _watchedThreadsListKey = GlobalKey(debugLabel: '_SavedPageState._watchedThreadsListKey');
	final _savedThreadsListKey = GlobalKey(debugLabel: '_SavedPageState._savedThreadsListKey');
	final _savedPostsListKey = GlobalKey(debugLabel: '_SavedPageState._savedPostsListKey');
	final _yourPostsListKey = GlobalKey(debugLabel: '_SavedPageState._yourPostsListKey');
	final _savedAttachmentsAnimatedBuilderKey = GlobalKey(debugLabel: '_SavedPageState._savedAttachmentsAnimatedBuilderKey');
	late final RefreshableListController<ImageboardScoped<SavedAttachment>> _savedAttachmentsController;
	late final EasyListenable _removeArchivedHack;
	late final ValueNotifier<List<ImageboardScoped<ThreadIdentifier>>> _missingWatchedThreads;
	late final ValueNotifier<List<ImageboardScoped<ThreadIdentifier>>> _missingSavedThreads;
	late final ValueNotifier<List<ImageboardScoped<ThreadIdentifier>>> _missingSavedPostsThreads;
	late final ValueNotifier<List<ImageboardScoped<ThreadIdentifier>>> _missingYourPostsThreads;
	late final ValueNotifier<List<ImageboardScoped<SavedAttachment>>> _missingSavedAttachments;
	_SavedThreadsLoader? _savedThreadsLoader;
	/// for optimization and pagination of loading your posts
	Map<(Imageboard, String), List<PostIdentifier>> _yourPostsLists = {};
	late final ValueNotifier<ImageboardScoped<ThreadOrPostIdentifier>?> _savedThreadsValueInjector;
	late final ValueNotifier<PostThreadCombo?> _yourPostsValueInjector;
	bool _lastTickerMode = true;

	@override
	void initState() {
		super.initState();
		_watchedListController = RefreshableListController();
		_threadListController = RefreshableListController();
		_postListController = RefreshableListController();
		_yourPostsListController = RefreshableListController();
		_savedAttachmentsController = RefreshableListController();
		_removeArchivedHack = EasyListenable();
		_savedThreadsValueInjector = ValueNotifier(null);
		_yourPostsValueInjector = ValueNotifier(null);
		_missingWatchedThreads = ValueNotifier([]);
		_missingSavedThreads = ValueNotifier([]);
		_missingSavedPostsThreads = ValueNotifier([]);
		_missingYourPostsThreads = ValueNotifier([]);
		_missingSavedAttachments = ValueNotifier([]);
	}

	Future<PostThreadCombo?> _takeYourPost() async {
		final heads = <PostThreadCombo>[];
		for (final entry in _yourPostsLists.entries) {
			while (entry.value.isNotEmpty) {
				final last = entry.value.last;
				final state = entry.key.$1.persistence.getThreadStateIfExists(last.thread);
				if (state == null) {
					// Something weird...
					entry.value.removeLast();
					continue;
				}
				final thread = await state.getThread();
				if (thread == null) {
					// Something missing. but we don't have to handle it here
					entry.value.removeLast();
					continue;
				}
				final post = thread.posts_.tryFirstWhere((p) => p.id == last.postId);
				if (post == null) {
					// Weird situation... just skip it
					entry.value.removeLast();
					continue;
				}
				heads.add(PostThreadCombo(
					imageboard: entry.key.$1,
					thread: thread,
					post: post
				));
				break;
			}
		}
		PostThreadCombo? latestHead;
		for (final head in heads) {
			if (latestHead == null || head.post.time.isAfter(latestHead.post.time)) {
				latestHead = head;
			}
		}
		final ret = latestHead;
		if (ret == null) {
			// No more entries
			return null;
		}
		final l = _yourPostsLists[(ret.imageboard, ret.post.board)];
		if (l != null && l.isNotEmpty) {
			// This should always be non-null and non-empty. But just avoid crash.
			l.removeLast();
		}
		return ret;
	}

	Widget _placeholder(String message) {
		return AdaptiveScaffold(
			body: Center(
				child: Text(message)
			)
		);
	}

	void _onSavedThreadsHistorySearch(String query) {
		widget.masterDetailKey.currentState!.masterKey.currentState!.push(adaptivePageRoute(
			builder: (context) => ValueListenableBuilder(
				valueListenable: _savedThreadsValueInjector,
				builder: (context, ImageboardScoped<ThreadOrPostIdentifier>? selectedResult, child) {
					return HistorySearchPage(
						initialQuery: query,
						initialSavedThreadsOnly: true,
						selectedResult: selectedResult,
						onResultSelected: widget.masterDetailKey.currentState!.setValue2
					);
				}
			),
			settings: dontAutoPopSettings
		));
	}

	void _onYourPostsHistorySearch(String query) {
		widget.masterDetailKey.currentState!.masterKey.currentState!.push(adaptivePageRoute(
			builder: (context) => ValueListenableBuilder(
				valueListenable: _yourPostsValueInjector,
				builder: (context, PostThreadCombo? selectedResult, child) {
					final post = selectedResult?.post.identifier.threadOrPostId;
					return HistorySearchPage(
						initialQuery: query,
						initialYourPostsOnly: true,
						selectedResult: post == null ? null : selectedResult?.imageboard.scope(post),
						onResultSelected: (result) async {
							if (result == null) {
								widget.masterDetailKey.currentState!.setValue3(null);
								return;
							}
							final thread = await result.imageboard.persistence.getThreadStateIfExists(result.item.thread)?.getThread();
							if (thread == null) {
								return;
							}
							final postId = result.item.postId ?? result.item.threadId;
							final post = thread.posts.tryFirstWhere((p) => p.id == postId);
							if (post == null) {
								return;
							}
							widget.masterDetailKey.currentState!.setValue3(PostThreadCombo(
								imageboard: result.imageboard,
								thread: thread,
								post: post
							));
						}
					);
				}
			),
			settings: dontAutoPopSettings
		));
	}

	static ContextMenuAction _makeFindSavedAttachmentInThreadAction({
		required Attachment attachment,
		required bool poppedOut,
		required BuildContext context,
		required BuildContext? innerContext,
		required Imageboard? imageboard
	}) => ContextMenuAction(
		child: const Text('Find in thread'),
		trailingIcon: CupertinoIcons.return_icon,
		onPressed: () async {
			try {
				final threadId = attachment.threadId;
				if (threadId == null) {
					throw Exception('Attachment saved without thread ID');
				}
				final threadIdentifier = ThreadIdentifier(attachment.board, threadId);
				if (imageboard == null) {
					throw Exception('Could not find corresponding site');
				}
				final (thread, postId) = await modalLoad(
					context,
					'Finding...',
					(controller) async {
						final threadState = imageboard.persistence.getThreadStateIfExists(threadIdentifier);
						Thread? thread = await threadState?.getThread();
						if (thread == null) {
							try {
								thread = await imageboard.site.getThread(threadIdentifier, priority: RequestPriority.interactive);
							}
							on ThreadNotFoundException {
								thread = await imageboard.site.getThreadFromArchive(threadIdentifier, priority: RequestPriority.interactive, customValidator: (t) async {
									if (_findMatchingAttachment(t, attachment) == null) {
										throw Exception('Could not find attachment in thread');
									}
								});
							}
						}
						final postId = _findMatchingAttachment(thread, attachment)?.post.id;
						return (thread, postId);
					}
				);
				if (!context.mounted) {
					return;
				}
				if (poppedOut && innerContext != null) {
					Navigator.pop(innerContext);
				}
				Navigator.of((poppedOut || innerContext == null) ? context : innerContext).push(adaptivePageRoute(
					builder: (ctx) => ImageboardScope(
						imageboardKey: null,
						imageboard: imageboard,
						child: ThreadPage(
							thread: thread.identifier,
							initialPostId: postId,
							initiallyUseArchive: thread.archiveName,
							boardSemanticId: -1
						)
					)
				));
			}
			catch (e, st) {
				if (context.mounted) {
					alertError(context, e, st);
				}
			}
		}
	);

	@override
	Widget build(BuildContext context) {
		final tickerMode = TickerMode.of(context);
		if (!_lastTickerMode && tickerMode) {
			Future.microtask(_removeArchivedHack.didUpdate);
		}
		_lastTickerMode = tickerMode;
		final persistencesAnimation = Listenable.merge(ImageboardRegistry.instance.imageboards.map((x) => x.persistence).toList());
		final threadStateBoxesAnimation = Persistence.sharedThreadStateListenable;
		final savedPostsNotifiersAnimation = Listenable.merge(ImageboardRegistry.instance.imageboardsIncludingDev.map((i) => i.persistence.savedPostsListenable).toList());
		final savedAttachmentsNotifiersAnimation = Listenable.merge(ImageboardRegistry.instance.imageboardsIncludingDev.map((i) => i.persistence.savedAttachmentsListenable).toList());
		final imageboardIds = <String, int>{};
		return MultiMasterDetailPage5(
			id: 'saved',
			key: widget.masterDetailKey,
			paneCreator1: () =>
				MultiMasterPane<ImageboardScoped<ThreadWatch>>(
					navigationBar: AdaptiveBar(
						title: const Text('Watched Threads'),
						actions: [
							Builder(
								builder: (context) => CupertinoButton(
									padding: EdgeInsets.zero,
									child: const Icon(CupertinoIcons.archivebox),
									onPressed: () => showAdaptiveModalPopup(
										context: context,
										builder: (context) => AdaptiveActionSheet(
											actions: [
												...thread_actions.getWatchedThreadsActions(context)
													.where((a) => a.onPressed != null)
													.map((a) => AdaptiveActionSheetAction(
														onPressed: () {
															a.onPressed?.call();
															Navigator.pop(context);
														},
														child: Text(a.title)
													)),
											],
											cancelButton: AdaptiveActionSheetAction(
												child: const Text('Cancel'),
												onPressed: () => Navigator.pop(context)
											)
										)
									)
								)
							),
							Builder(
								builder: (context) => CupertinoButton(
									padding: EdgeInsets.zero,
									child: Icon(Settings.reverseWatchedThreadsSortingSetting.watch(context) ? CupertinoIcons.sort_up : CupertinoIcons.sort_down),
									onPressed: () => selectWatchedThreadsSortMethod(context, onMutate: _watchedListController.update)
								)
							),
							Builder(
								builder: (context) {
									final onlyShowUnreadWatches = Settings.onlyShowUnreadWatchesSetting.watch(context);
									return CupertinoButton(
										padding: EdgeInsets.zero,
										child: Icon(onlyShowUnreadWatches ? CupertinoIcons.asterisk_circle_fill : CupertinoIcons.asterisk_circle),
										onPressed: () {
											final v = Settings.instance.onlyShowUnreadWatches = !onlyShowUnreadWatches;
											showToast(
												context: context,
												icon: v ? CupertinoIcons.asterisk_circle_fill : CupertinoIcons.asterisk_circle,
												message: v ? 'Showing unread only' : 'Showing all threads'
											);
											_watchedListController.update();
										}
									);
								}
							)
						]
					),
					icon: AnimatedBuilder(
						animation: persistencesAnimation,
						builder: (context, _) => CachingBuilder(
							value: ImageboardRegistry.instance.imageboards.any((i) => i.persistence.browserState.threadWatches.values.isNotEmpty),
							builder: (value) => Builder(
								builder: (context) => Icon(
									value ? CupertinoIcons.bell_fill : CupertinoIcons.bell,
									color: ChanceTheme.primaryColorOf(context)
								)
							)
						)
					),
					masterBuilder: (context, selected, setter) {
						final settings = context.watch<Settings>();
						final theme = context.watch<SavedTheme>();
						return RefreshableList<ImageboardScoped<(ThreadWatch, Thread)>>(
							aboveFooter: Column(
								mainAxisSize: MainAxisSize.min,
								children: [
									const ChanceDivider(),
									ValueListenableBuilder(
										valueListenable: _missingWatchedThreads,
										builder: (context, list, _) => MissingThreadsControls(
											missingThreads: list,
											afterFix: () {
												_watchedListController.state?.forceRebuildId++;
												_watchedListController.update();
											},
											onFixAbandonedForThreads: (threadsToDelete) async {
												for (final thread in threadsToDelete) {
													await thread.imageboard.notifications.unsubscribeFromThread(thread.item);
												}
											}
										)
									)
								],
							),
							filterableAdapter: (t) => (t.imageboard.key, t.item.$2),
							useFiltersFromContext: false,
							includeImageboardKeyAndBoardInSearchString: true,
							controller: _watchedListController,
							listUpdater: (options) async {
								final list = await thread_actions.loadWatches();
								final out = <ImageboardScoped<(ThreadWatch, Thread)>>[];
								final missing = <ImageboardScoped<ThreadIdentifier>>[];
								for (final item in list) {
									final thread = item.imageboard.persistence.getThreadStateIfExists(item.item.threadIdentifier)?.thread;
									if (thread == null) {
										missing.add(item.imageboard.scope(item.item.threadIdentifier));
									}
									else if (!settings.onlyShowUnreadWatches || item.shouldCountAsUnread) {
										out.add(item.imageboard.scope((item.item, thread)));
									}
								}
								_missingWatchedThreads.value = missing;
								_watchedListController.waitForItemBuild(0).then((_) => _removeArchivedHack.didUpdate());
								return out;
							},
							minUpdateDuration: Duration.zero,
							autoExtendDuringScroll: true,
							updateAnimation: persistencesAnimation,
							disableUpdates: !TickerMode.of(context),
							key: _watchedThreadsListKey,
							id: 'watched',
							minCacheExtent: settings.useCatalogGrid ? settings.catalogGridHeight : 0,
							gridDelegate: settings.useCatalogGrid ? SliverGridDelegateWithMaxCrossAxisExtentWithCacheTrickery(
								maxCrossAxisExtent: settings.catalogGridWidth,
								childAspectRatio: settings.catalogGridWidth / settings.catalogGridHeight
							) : null,
							staggeredGridDelegate: (settings.useCatalogGrid && settings.useStaggeredCatalogGrid) ? SliverStaggeredGridDelegateWithMaxCrossAxisExtent(
								maxCrossAxisExtent: settings.catalogGridWidth
							) : null,
							canTapFooter: false,
							header: const LocalWatcherControls(),
							footer: Padding(
								padding: const EdgeInsets.all(16),
								child: Builder(
									builder: (context) => AnimatedBuilder(
										animation: TickerMode.of(context) ? Listenable.merge([
											_removeArchivedHack,
											persistencesAnimation,
											threadStateBoxesAnimation,
										]) : const AlwaysStoppedAnimation(null),
										builder: (context, _) => Wrap(
											spacing: 16,
											runSpacing: 16,
											alignment: WrapAlignment.spaceEvenly,
											runAlignment: WrapAlignment.center,
											children: thread_actions.getWatchedThreadsActions(context, onMutate: _removeArchivedHack.didUpdate).map((a) => CupertinoButton(
												onPressed: a.onPressed,
												child: Row(
													mainAxisSize: MainAxisSize.min,
													children: [
														Icon(a.icon),
														const SizedBox(width: 8),
														Flexible(
															child: Text(a.title, textAlign: TextAlign.center)
														)
													]
												)
											)).toList()
										)
									)
								)
							),
							itemBuilder: (itemContext, watch, options) {
								final isSelected = selected(itemContext, watch.imageboard.scope(watch.item.$1));
								final openInNewTabZone = context.read<OpenInNewTabZone?>();
								return ImageboardScope(
									imageboardKey: watch.imageboard.key,
									child: ContextMenu(
										maxHeight: settings.useCatalogGrid ? settings.catalogGridHeight : 125,
										actions: [
											if (openInNewTabZone != null) ContextMenuAction(
												child: const Text('Open in new tab'),
												trailingIcon: CupertinoIcons.rectangle_stack_badge_plus,
												onPressed: () {
													openInNewTabZone.onWantOpenThreadInNewTab(watch.imageboard.key, watch.item.$1.threadIdentifier);
												}
											),
											ContextMenuAction(
												child: const Text('Unwatch'),
												onPressed: () async {
													await watch.imageboard.notifications.removeWatch(watch.item.$1);
													_watchedListController.update();
													if (context.mounted) {
														showUndoToast(
															context: context,
															message: 'Unwatched',
															onUndo: () async {
																await watch.imageboard.notifications.insertWatch(watch.item.$1);
																_watchedListController.update();
															}
														);
													}
												},
												trailingIcon: CupertinoIcons.xmark,
												isDestructiveAction: true
											),
											ContextMenuAction(
												child: const Text('Mark as read'),
												onPressed: () async {
													final threadState = watch.imageboard.persistence.getThreadState(watch.item.$1.threadIdentifier);
													final unseenPostIds = threadState.unseenPostIds.data.toSet();
													final lastSeenPostId = threadState.lastSeenPostId;
													threadState.unseenPostIds.data.clear();
													threadState.lastSeenPostId = threadState.thread?.posts_.fold<int>(0, (m, p) => math.max(m, p.id));
													threadState.didUpdate();
													await threadState.save();
													if (context.mounted) {
														showUndoToast(
															context: context,
															message: 'Marked as read',
															onUndo: () async {
																threadState.unseenPostIds.data.addAll(unseenPostIds);
																threadState.lastSeenPostId = lastSeenPostId;
																threadState.didUpdate();
																await threadState.save();
															}
														);
													}
												},
												trailingIcon: CupertinoIcons.xmark_circle,
											),
											if (watch.imageboard.persistence.getThreadStateIfExists(watch.item.$1.threadIdentifier)?.savedTime != null) ContextMenuAction(
												child: const Text('Un-save thread'),
												trailingIcon: Adaptive.icons.bookmarkFilled,
												onPressed: () {
													final threadState = watch.imageboard.persistence.getThreadState(watch.item.$1.threadIdentifier);
													final savedTime = threadState.savedTime;
													threadState.savedTime = null;
													threadState.save();
													_threadListController.update();
													showUndoToast(
														context: context,
														message: 'Thread unsaved',
														onUndo: () {
															threadState.savedTime = savedTime ?? DateTime.now();
															threadState.save();
															_threadListController.update();
														}
													);
												}
											)
											else ContextMenuAction(
												child: const Text('Save thread'),
												trailingIcon: Adaptive.icons.bookmark,
												onPressed: () {
													final threadState = watch.imageboard.persistence.getThreadState(watch.item.$1.threadIdentifier);
													threadState.savedTime = DateTime.now();
													threadState.save();
													_threadListController.update();
													showUndoToast(
														context: context,
														message: 'Thread saved',
														onUndo: () {
															threadState.savedTime = null;
															threadState.save();
															_threadListController.update();
														}
													);
												}
											),
										],
										contextMenuBuilderBuilder: makeGeneralContextMenuBuilder,
										child: GestureDetector(
											behavior: HitTestBehavior.opaque,
											child: ValueListenableBuilder(
												valueListenable: watch.imageboard.persistence.listenForPersistentThreadStateChanges(watch.item.$1.threadIdentifier),
												builder: (context, threadState, child) {
													return NullableColorFiltered(
														colorFilter:
															((threadState?.unseenReplyIdsToYouCount() ?? 0) > 0) ?
																ColorFilter.mode(theme.secondaryColor.withOpacity(0.15), BlendMode.srcOver) : null,
														child: ThreadRow(
															thread: threadState?.thread ?? watch.item.$2,
															isSelected: isSelected,
															style: settings.useCatalogGrid ?
																(settings.useStaggeredCatalogGrid ? ThreadRowStyle.staggeredGrid : ThreadRowStyle.grid)
																: ThreadRowStyle.row,
															showBoardName: true,
															showSiteIcon: true,
															showPageNumber: true,
															forceShowInHistory: true,
															hideThumbnails: options.hideThumbnails,
															baseOptions: PostSpanRenderOptions(
																highlightPattern: options.queryPattern
															),
															dimReadThreads: watch.item.$1.zombie,
															invertCountersIfUnread: true,
															onThumbnailLoadError: (error, stackTrace) {
																watch.imageboard.threadWatcher.fixBrokenThread(watch.item.$1.threadIdentifier);
															},
															semanticParentIds: const [-4],
															onThumbnailTap: (initialAttachment) {
																final attachments = {
																	for (final w in _watchedListController.items)
																		for (final attachment in w.item.imageboard.persistence.getThreadStateIfExists(w.item.item.$1.threadIdentifier)?.thread?.attachments ?? <Attachment>[])
																			attachment: w.item.imageboard.persistence.getThreadStateIfExists(w.item.item.$1.threadIdentifier)!
																	};
																showGallery(
																	context: context,
																	attachments: attachments.keys.toList(),
																	threads: {
																		for (final item in attachments.entries) item.key: item.value.imageboard!.scope(item.value.thread!)
																	},
																	onThreadSelected: (t) {
																		final x = _watchedListController.items.firstWhere((w) => w.item.imageboard == t.imageboard && w.item.item.$1.threadIdentifier == t.item.identifier).item;
																		setter(x.imageboard.scope(x.item.$1));
																	},
																	initialAttachment: attachments.keys.firstWhere((a) => a.id == initialAttachment.id),
																	onChange: (attachment) {
																		final threadId = attachments.entries.firstWhere((_) => _.key.id == attachment.id).value.identifier;
																		_watchedListController.animateTo((p) => p.item.$1.threadIdentifier == threadId);
																	},
																	semanticParentIds: [-4],
																	heroOtherEndIsBoxFitCover: settings.useCatalogGrid || settings.squareThumbnails
																);
															}
														)
													);
												}
											),
											onTap: () => setter(watch.imageboard.scope(watch.item.$1))
										)
									)
								);
							},
							filterHint: 'Search watched threads'
						);
					},
					detailBuilder: (selectedThread, setter, poppedOut) {
						return BuiltDetailPane(
							widget: selectedThread != null ? ImageboardScope(
								imageboardKey: selectedThread.imageboard.key,
								child: ThreadPage(
									thread: selectedThread.item.threadIdentifier,
									boardSemanticId: -4
								)
							) : _placeholder('Select a thread'),
							pageRouteBuilder: fullWidthCupertinoPageRouteBuilder
						);
					}
				),
			paneCreator2: () =>
				MultiMasterPane<ImageboardScoped<ThreadOrPostIdentifier>>(
					navigationBar: AdaptiveBar(
						title: const Text('Saved Threads'),
						actions: [
							AnimatedBuilder(
								animation: _threadListController,
								builder: (context, _) => CupertinoButton(
									padding: EdgeInsets.zero,
									onPressed: _threadListController.items.isEmpty ? null : () => thread_actions.unsaveAllSavedThreads(context, onMutate: _threadListController.update),
									child: const Icon(CupertinoIcons.delete)
								)
							),
							Builder(
								builder: (context) => CupertinoButton(
									padding: EdgeInsets.zero,
									child: Icon(Settings.reverseSavedThreadsSortingSetting.watch(context) ? CupertinoIcons.sort_up : CupertinoIcons.sort_down),
									onPressed: () async {
										final before = (Settings.instance.savedThreadsSortingMethod, Settings.instance.reverseSavedThreadsSorting);
										await selectSavedThreadsSortMethod(context);
										if ((Settings.instance.savedThreadsSortingMethod, Settings.instance.reverseSavedThreadsSorting) != before) {
											await _threadListController.update();
										}
									}
								)
							)
						]
					),
					icon: AnimatedBuilder(
						animation: threadStateBoxesAnimation,
						builder: (context, _) => CachingBuilder(
							value: Persistence.sharedThreadStateBox.values.any((s) => s.savedTime != null),
							builder: (value) => Builder(
								builder: (context) => Icon(
									value ? CupertinoIcons.tray_full_fill : CupertinoIcons.tray_full,
									color: ChanceTheme.primaryColorOf(context)
								)
							)
						)
					),
					masterBuilder: (context, selectedThread, threadSetter) {
						final settings = context.watch<Settings>();
						final sortMethod = getSavedThreadsSortMethodTuple();
						return RefreshableList<(PersistentThreadState, Thread)>(
							aboveFooter: ValueListenableBuilder(
								valueListenable: _missingSavedThreads,
								builder: (context, list, _) => MissingThreadsControls(
									missingThreads: list,
									afterFix: () {
										_threadListController.state?.forceRebuildId++;
										_threadListController.update();
									},
									onFixAbandonedForThreads: (threadsToDelete) async {
										for (final thread in threadsToDelete) {
											await thread.imageboard.persistence.getThreadStateIfExists(thread.item)?.delete();
										}
									}
								)
							),
							useFiltersFromContext: false,
							includeImageboardKeyAndBoardInSearchString: true,
							filterableAdapter: (t) => (t.$1.imageboardKey, t.$2),
							controller: _threadListController,
							listUpdater: (options) async {
								if (options.source == RefreshableListUpdateSource.top) {
									// Refresh threads from network
									// Lazy, just steal from list
									for (final item in _threadListController.items) {
										final (state, thread) = item.item;
										if (state.useArchive || thread.isArchived) {
											continue;
										}
										// TODO: Put this in a common place. PersistentThreadState. then use it in thread_watcher Persistence.tabs handling, drawer.dart, etc.
										if (state.imageboard?.site.hasExpiringThreads == false) {
											// Threads don't go to archived on their own.
											// So make a judgement call whether it's reasonable to refresh
											final latestPostTime = thread.posts_.fold<DateTime>(DateTime(2000), (min, post) {
												if (post.time.isAfter(min)) {
													return post.time;
												}
												return min;
											});
											// TODO: Use lastUpdatedTime? But would need to persist it.
											if (DateTime.now().difference(latestPostTime) > const Duration(days: 7)) {
												// A week without updates, don't bother
												continue;
											}
										}
										try {
											await state.imageboard?.threadWatcher.updateThread(state.identifier, cancelToken: options.cancelToken);
										}
										catch (e, st) {
											Future.error(e, st); // crashlytics it
										}
									}
								}
								final loader = _savedThreadsLoader = switch (settings.savedThreadsSortingMethod) {
									ThreadSortingMethod.alphabeticByTitle => _SavedThreadsByTitleLoader(),
									ThreadSortingMethod.savedTime => _SavedThreadsBySavedTimeLoader(),
									ThreadSortingMethod.lastPostTime => _SavedThreadsByLastPostTimeLoader(),
									ThreadSortingMethod.threadPostTime => _SavedThreadsByThreadPostTimeLoader(),
									ThreadSortingMethod other => throw UnsupportedError('Not supported method to sort saved threads: $other')
								};
								final missing = await loader.initialize(settings.reverseSavedThreadsSorting);
								_missingSavedThreads.value = missing;
								final ret = <(PersistentThreadState, Thread)>[];
								for (int i = 0; i < _savedThreadsChunkSize; i++) {
									final p = await loader.takeSavedThread();
									if (p == null) {
										break;
									}
									ret.add(p);
								}
								_missingSavedThreads.value = missing;
								return ret;
							},
							listExtender: (_, cancelToken) async {
								final ret = <(PersistentThreadState, Thread)>[];
								for (int i = 0; i < _savedThreadsChunkSize; i++) {
									final p = await _savedThreadsLoader?.takeSavedThread();
									if (p == null) {
										break;
									}
									ret.add(p);
								}
								return ret;
							},
							minUpdateDuration: Duration.zero,
							id: 'savedThreads',
							sortMethods: [sortMethod],
							key: _savedThreadsListKey,
							autoExtendDuringScroll: true,
							updateAnimation: threadStateBoxesAnimation,
							disableUpdates: !TickerMode.of(context),
							minCacheExtent: settings.useCatalogGrid ? settings.catalogGridHeight : 0,
							gridDelegate: settings.useCatalogGrid ? SliverGridDelegateWithMaxCrossAxisExtentWithCacheTrickery(
								maxCrossAxisExtent: settings.catalogGridWidth,
								childAspectRatio: settings.catalogGridWidth / settings.catalogGridHeight
							) : null,
							staggeredGridDelegate: (settings.useCatalogGrid && settings.useStaggeredCatalogGrid) ? SliverStaggeredGridDelegateWithMaxCrossAxisExtent(
								maxCrossAxisExtent: settings.catalogGridWidth
							) : null,
							itemBuilder: (itemContext, pair, options) {
								final state = pair.$1;
								final isSelected = selectedThread(itemContext, state.imageboard!.scope(ThreadOrPostIdentifier.thread(state.identifier)));
								final openInNewTabZone = context.read<OpenInNewTabZone?>();
								return ImageboardScope(
									imageboardKey: state.imageboardKey,
									child: ContextMenu(
										maxHeight: settings.useCatalogGrid ? settings.catalogGridHeight : 125,
										actions: [
											if (openInNewTabZone != null) ContextMenuAction(
												child: const Text('Open in new tab'),
												trailingIcon: CupertinoIcons.rectangle_stack_badge_plus,
												onPressed: () {
													openInNewTabZone.onWantOpenThreadInNewTab(state.imageboardKey, state.identifier);
												}
											),
											ContextMenuAction(
												child: const Text('Unsave'),
												onPressed: () {
													final oldSavedTime = state.savedTime;
													state.savedTime = null;
													state.save();
													_threadListController.update();
													showUndoToast(
														context: context,
														message: 'Unsaved',
														onUndo: () {
															state.savedTime = oldSavedTime ?? DateTime.now();
															state.save();
															_threadListController.update();
														}
													);
												},
												trailingIcon: CupertinoIcons.xmark,
												isDestructiveAction: true
											)
										],
										contextMenuBuilderBuilder: makeGeneralContextMenuBuilder,
										child: GestureDetector(
											behavior: HitTestBehavior.opaque,
											child: Builder(
												builder: (context) => ThreadRow(
													thread: state.thread ?? pair.$2,
													isSelected: isSelected,
													style: settings.useCatalogGrid ?
														(settings.useStaggeredCatalogGrid ? ThreadRowStyle.staggeredGrid : ThreadRowStyle.grid)
														: ThreadRowStyle.row,
													showBoardName: true,
													showSiteIcon: true,
													forceShowInHistory: true,
													hideThumbnails: options.hideThumbnails,
													baseOptions: PostSpanRenderOptions(
														highlightPattern: options.queryPattern
													),
													onThumbnailLoadError: (error, stackTrace) {
														state.imageboard?.threadWatcher.fixBrokenThread(state.identifier);
													},
													semanticParentIds: const [-12],
													onThumbnailTap: (initialAttachment) {
														final attachments = _threadListController.items.expand((_) => _.item.$2.attachments).toList();
														showGallery(
															context: context,
															attachments: attachments,
															threads: {
																for (final state in _threadListController.items)
																	for (final attachment in state.item.$2.attachments)
																		attachment: state.item.$1.imageboard!.scope(state.item.$2)
															},
															onThreadSelected: (t) => threadSetter(t.imageboard.scope(t.item.identifier.threadOrPostIdentifier)),
															initialAttachment: attachments.firstWhere((a) => a.id == initialAttachment.id),
															onChange: (attachment) {
																_threadListController.animateTo((p) => p.$2.attachments.any((a) => a.id == attachment.id));
															},
															semanticParentIds: [-12],
															heroOtherEndIsBoxFitCover: settings.useCatalogGrid || settings.squareThumbnails
														);
													}
												)
											),
											onTap: () => threadSetter(state.imageboard!.scope(state.identifier.threadOrPostIdentifier))
										)
									)
								);
							},
							filterHint: 'Search saved threads',
							filterAlternative: FilterAlternative(
								name: 'full history',
								suggestWhenFilterEmpty: true,
								handler: _onSavedThreadsHistorySearch
							),
						);
					},
					detailBuilder: (selectedThread, setter, poppedOut) {
						WidgetsBinding.instance.addPostFrameCallback((_){
							_savedThreadsValueInjector.value = selectedThread;
						});
						return BuiltDetailPane(
							widget: selectedThread != null ? ImageboardScope(
								imageboardKey: selectedThread.imageboard.key,
								child: ThreadPage(
									thread: selectedThread.item.thread,
									initialPostId: selectedThread.item.postId,
									boardSemanticId: -12
								)
							) : _placeholder('Select a thread'),
							pageRouteBuilder: fullWidthCupertinoPageRouteBuilder
						);
					}
				),
			paneCreator3: () =>
				MultiMasterPane<PostThreadCombo>(
					navigationBar: const AdaptiveBar(
						title: Text('Your Posts')
					),
					icon: Builder(
						builder: (context) => Icon(
							CupertinoIcons.pencil,
							color: ChanceTheme.primaryColorOf(context)
						)
					),
					masterBuilder: (context, selected, setter) {
						return RefreshableList<PostThreadCombo>(
							aboveFooter: ValueListenableBuilder(
								valueListenable: _missingYourPostsThreads,
								builder: (context, list, _) => MissingThreadsControls(
									missingThreads: list,
									afterFix: () {
										_yourPostsListController.state?.forceRebuildId++;
										_yourPostsListController.update();
									},
									onFixAbandonedForThreads: (threadsToDelete) async {
										for (final thread in threadsToDelete) {
											await thread.imageboard.persistence.getThreadStateIfExists(thread.item)?.delete();
										}
									}
								)
							),
							useFiltersFromContext: false,
							includeImageboardKeyAndBoardInSearchString: true,
							filterableAdapter: (t) => (t.imageboard.key, t.post.isThread ? t.thread : t.post),
							controller: _yourPostsListController,
							listUpdater: (options) async {
								_yourPostsLists = {};
								final missing = <ImageboardScoped<ThreadIdentifier>>[];
								for (final state in Persistence.sharedThreadStateBox.values) {
									final imageboard = state.imageboard;
									if (imageboard == null || state.youIds.isEmpty) {
										continue;
									}
									if (!state.isThreadCached) {
										missing.add(imageboard.scope(state.identifier));
										continue;
									}
									final l = _yourPostsLists.putIfAbsent((imageboard, state.board), () => []);
									for (final id in state.youIds) {
										l.add(PostIdentifier(state.board, state.id, id));
									}
								}
								for (final list in _yourPostsLists.values) {
									// Earliest posted first
									list.sort((a, b) => a.postId.compareTo(b.postId));
								}
								// First chunk should include all with missing threads
								final ret = <PostThreadCombo>[];
								for (int i = 0; i < _yourPostsChunkSize; i++) {
									final p = await _takeYourPost();
									if (p == null) {
										break;
									}
									ret.add(p);
								}
								_missingYourPostsThreads.value = missing;
								return ret;
							},
							listExtender: (_, cancelToken) async {
								final ret = <PostThreadCombo>[];
								for (int i = 0; i < _yourPostsChunkSize; i++) {
									final p = await _takeYourPost();
									if (p == null) {
										break;
									}
									ret.add(p);
								}
								return ret;
							},
							key: _yourPostsListKey,
							id: 'yourPosts',
							filterHint: 'Search your posts...',
							filterAlternative: FilterAlternative(
								name: 'full history',
								suggestWhenFilterEmpty: true,
								handler: _onYourPostsHistorySearch
							),
							autoExtendDuringScroll: true,
							updateAnimation: threadStateBoxesAnimation,
							disableUpdates: !TickerMode.of(context),
							minUpdateDuration: Duration.zero,
							sortMethods: [(a, b) => b.post.time.toLocal().compareTo(a.post.time.toLocal())],
							itemBuilder: (context, item, options) => ImageboardScope(
								imageboardKey: item.imageboard.key,
								child: ChangeNotifierProvider<PostSpanZoneData>(
									create: (context) => PostSpanRootZoneData(
										imageboard: item.imageboard,
										thread: item.thread,
										semanticRootIds: [-8],
										style: PostSpanZoneStyle.linear
									),
									child: Builder(
										builder: (context) => PostRow(
											post: item.post,
											isSelected: selected(context, item),
											onTap: () => setter(item),
											showBoardName: true,
											showSiteIcon: true,
											showYourPostBorder: false,
											hideThumbnails: options.hideThumbnails,
											baseOptions: PostSpanRenderOptions(
												highlightPattern: options.queryPattern
											),
											onThumbnailLoadError: (e, st) async {
												await item.imageboard.threadWatcher.fixBrokenThread(item.thread.identifier);
											},
											onThumbnailTap: (initialAttachment) {
												final attachments = _yourPostsListController.items.expand((_) => _.item.post.attachments).toList();
												showGallery(
													context: context,
													attachments: attachments,
													posts: {
														for (final state in _yourPostsListController.items)
															for (final attachment in state.item.post.attachments)
																attachment: state.item.imageboard.scope(state.item.post)
													},
													initialAttachment: attachments.firstWhere((a) => a.id == initialAttachment.id),
													onChange: (attachment) {
														_yourPostsListController.animateTo((p) => p.imageboard.persistence.getThreadStateIfExists(p.post.threadIdentifier)?.thread?.attachments.any((a) => a.id == attachment.id) ?? false);
													},
													semanticParentIds: [-8],
													heroOtherEndIsBoxFitCover: Settings.instance.squareThumbnails
												);
											}
										)
									)
								)
							)
						);
					},
					detailBuilder: (selected, setter, poppedOut) {
						WidgetsBinding.instance.addPostFrameCallback((_){
							_yourPostsValueInjector.value = selected;
						});
						return BuiltDetailPane(
							widget: selected == null ? _placeholder('Select a post') : ImageboardScope(
								imageboardKey: selected.imageboard.key,
								child: ThreadPage(
									thread: selected.thread.identifier,
									initialPostId: selected.post.id,
									boardSemanticId: -8
								)
							),
							pageRouteBuilder: fullWidthCupertinoPageRouteBuilder
						);
					}
				),
			paneCreator4: () =>
				MultiMasterPane<ImageboardScoped<SavedPost>>(
					navigationBar: AdaptiveBar(
						title: const Text('Saved Posts'),
						actions: [
							AnimatedBuilder(
								animation: _postListController,
								builder: (context, _) => CupertinoButton(
									padding: EdgeInsets.zero,
									onPressed: _postListController.items.isEmpty ? null : () => thread_actions.unsaveAllSavedPosts(context, onMutate: _postListController.update),
									child: const Icon(CupertinoIcons.delete)
								)
							),
							Builder(
								builder: (context) => CupertinoButton(
									padding: EdgeInsets.zero,
									child: Icon(Settings.reverseSavedThreadsSortingSetting.watch(context) ? CupertinoIcons.sort_up : CupertinoIcons.sort_down),
									onPressed: () async {
										final before = (Settings.instance.savedThreadsSortingMethod, Settings.instance.reverseSavedThreadsSorting);
										await selectSavedThreadsSortMethod(context);
										if ((Settings.instance.savedThreadsSortingMethod, Settings.instance.reverseSavedThreadsSorting) != before) {
											await _postListController.update();
										}
									}
								)
							)
						]
					),
					icon: AnimatedBuilder(
						animation: savedPostsNotifiersAnimation,
						builder: (context, _) => CachingBuilder(
							value: ImageboardRegistry.instance.imageboardsIncludingDev.any((i) => i.persistence.savedPosts.isNotEmpty),
							builder: (value) => Builder(
								builder: (context) => Icon(
									value ? CupertinoIcons.reply_thick_solid : CupertinoIcons.reply_all,
									color: ChanceTheme.primaryColorOf(context)
								)
							)
						)
					),
					masterBuilder: (context, selected, setter) {
						Settings.savedThreadsSortingMethodSetting.watch(context);
						Settings.reverseSavedThreadsSortingSetting.watch(context);
						return RefreshableList<ImageboardScoped<(SavedPost, Thread)>>(
							aboveFooter: ValueListenableBuilder(
								valueListenable: _missingSavedPostsThreads,
								builder: (context, list, _) => MissingThreadsControls(
									missingThreads: list,
									afterFix: () {
										_postListController.state?.forceRebuildId++;
										_postListController.update();
									},
									onFixAbandonedForThreads: (threadsToDelete) async {
										for (final thread in threadsToDelete) {
											final postToDelete = thread.imageboard.persistence.savedPosts.values.tryFirstWhere((p) => p.post.threadIdentifier == thread.item);
											if (postToDelete != null) {
												thread.imageboard.persistence.unsavePost(postToDelete.post);
											}
										}
									},
								)
							),
							useFiltersFromContext: false,
							includeImageboardKeyAndBoardInSearchString: true,
							filterableAdapter: (t) => (t.imageboard.key, t.item.$1.post.isThread ? t.item.$2 : t.item.$1.post),
							controller: _postListController,
							listUpdater: (options) async {
								final savedPosts = ImageboardRegistry.instance.imageboardsIncludingDev.expand((i) => i.persistence.savedPosts.values.map(i.scope)).toList();
								final pairs = await Future.wait(savedPosts.map((s) async {
									return (s, await s.imageboard.persistence.getThreadStateIfExists(s.item.post.threadIdentifier)?.getThread());
								}));
								final out = <ImageboardScoped<(SavedPost, Thread)>>[];
								final missing = <ImageboardScoped<ThreadIdentifier>>[];
								for (final (p, t) in pairs) {
									if (t != null) {
										out.add(p.imageboard.scope((p.item, t)));
									}
									else {
										missing.add(p.imageboard.scope(p.item.post.threadIdentifier));
									}
								}
								_missingSavedPostsThreads.value = missing;
								return out;
							},
							id: 'savedPosts',
							key: _savedPostsListKey,
							autoExtendDuringScroll: true,
							updateAnimation: savedPostsNotifiersAnimation,
							disableUpdates: !TickerMode.of(context),
							minUpdateDuration: Duration.zero,
							sortMethods: [getSavedPostsSortMethodTuple()],
							itemBuilder: (context, savedPost, options) {
								final threadState = savedPost.imageboard.persistence.getThreadStateIfExists(savedPost.item.$1.post.threadIdentifier);
								return ImageboardScope(
									imageboardKey: savedPost.imageboard.key,
									child: ChangeNotifierProvider<PostSpanZoneData>(
										create: (context) => PostSpanRootZoneData(
											imageboard: savedPost.imageboard,
											thread: threadState?.thread ?? savedPost.item.$2,
											semanticRootIds: [-2],
											style: PostSpanZoneStyle.linear
										),
										child: Builder(
											builder: (context) => PostRow(
												post: savedPost.item.$1.post,
												isSelected: selected(context, savedPost.imageboard.scope(savedPost.item.$1)),
												onTap: () => setter(savedPost.imageboard.scope(savedPost.item.$1)),
												showBoardName: true,
												showSiteIcon: true,
												hideThumbnails: options.hideThumbnails,
												baseOptions: PostSpanRenderOptions(
													highlightPattern: options.queryPattern
												),
												onThumbnailLoadError: (e, st) async {
													final firstThread = threadState?.thread ?? savedPost.item.$2;
													await savedPost.imageboard.threadWatcher.fixBrokenThread(savedPost.item.$1.post.threadIdentifier);
													if (firstThread != threadState!.thread || threadState.thread?.archiveName != null) {
														savedPost.item.$1.post = threadState.thread!.posts.firstWhere((p) => p.id == savedPost.item.$1.post.id);
														savedPost.imageboard.persistence.didUpdateSavedPost();
													}
												},
												onThumbnailTap: (initialAttachment) {
													final attachments = _postListController.items.expand((_) => _.item.item.$1.post.attachments).toList();
													showGallery(
														context: context,
														attachments: attachments,
														posts: {
															for (final state in _postListController.items)
																for (final attachment in state.item.item.$1.post.attachments)
																	attachment: state.item.imageboard.scope(state.item.item.$1.post)
														},
														initialAttachment: attachments.firstWhere((a) => a.id == initialAttachment.id),
														onChange: (attachment) {
															_postListController.animateTo((p) => p.imageboard.persistence.getThreadStateIfExists(p.item.$1.post.threadIdentifier)?.thread?.attachments.any((a) => a.id == attachment.id) ?? false);
														},
														semanticParentIds: [-2],
														heroOtherEndIsBoxFitCover: Settings.instance.squareThumbnails
													);
												}
											)
										)
									)
								);
							},
							filterHint: 'Search saved posts'
						);
					},
					detailBuilder: (selected, setter, poppedOut) => BuiltDetailPane(
						widget: selected == null ? _placeholder('Select a post') : ImageboardScope(
							imageboardKey: selected.imageboard.key,
							child: ThreadPage(
								thread: selected.item.post.threadIdentifier,
								initialPostId: selected.item.post.id,
								boardSemanticId: -2
							)
						),
						pageRouteBuilder: fullWidthCupertinoPageRouteBuilder
					)
				),
			paneCreator5: () =>
				MultiMasterPane<ImageboardScoped<SavedAttachment>>(
					navigationBar: AdaptiveBar(
						title: const Text('Saved Attachments'),
						actions: [
							Builder(
								builder: (context) => AnimatedBuilder(
									animation: TickerMode.of(context) ? savedAttachmentsNotifiersAnimation : const AlwaysStoppedAnimation(null),
									builder: (context, _) => CupertinoButton(
										padding: EdgeInsets.zero,
										onPressed: ImageboardRegistry.instance.imageboards.any((i) => i.persistence.savedAttachments.isNotEmpty) ?
												() async {
													final toDelete = ImageboardRegistry.instance.imageboards.expand((i) => i.persistence.savedAttachments.values.map(i.scope)).toList();
													final ok = await showAdaptiveDialog<bool>(
														context: context,
														barrierDismissible: true,
														builder: (context) => AdaptiveAlertDialog(
															title: const Text('Are you sure?'),
															content: Text('All ${describeCount(toDelete.length, 'saved attachment')} will be removed.'),
															actions: [
																AdaptiveDialogAction(
																	isDestructiveAction: true,
																	onPressed: () => Navigator.pop(context, true),
																	child: const Text('Delete all')
																),
																AdaptiveDialogAction(
																	onPressed: () => Navigator.pop(context),
																	child: const Text('Cancel')
																)
															]
														)
													);
													if (!context.mounted || ok != true) {
														return;
													}
													final imageboards = toDelete.map((i) => i.imageboard).toSet();
													for (final item in toDelete) {
														item.imageboard.persistence.savedAttachments.remove(item.item.attachment.globalId);
													}
													for (final imageboard in imageboards) {
														imageboard.persistence.savedAttachmentsListenable.didUpdate();
														attachmentSourceNotifier.didUpdate();
													}
													Persistence.settings.save();
													showUndoToast(
														context: context,
														message: 'Deleted ${describeCount(toDelete.length, 'attachment')}',
														onUndo: () {
															// Restore all the objects
															for (final item in toDelete) {
																item.imageboard.persistence.savedAttachments[item.item.attachment.globalId] = item.item;
															}
															for (final imageboard in imageboards) {
																imageboard.persistence.savedAttachmentsListenable.didUpdate();
																attachmentSourceNotifier.didUpdate();
															}
															Persistence.settings.save();
														}
													);
												} : null,
										child: const Icon(CupertinoIcons.delete)
									)
								)
							)
						]
					),
					useRootNavigator: true,
					icon: Builder(
						builder: (context) => Icon(
							Adaptive.icons.photo,
							color: ChanceTheme.primaryColorOf(context)
						)
					),
					masterBuilder: (context, selected, setter) => RefreshableList<ImageboardScoped<SavedAttachment>>(
						id: 'savedAttachments',
						controller: _savedAttachmentsController,
						listUpdater: (options) async {
							final list = <ImageboardScoped<SavedAttachment>>[];
							final missing = <ImageboardScoped<SavedAttachment>>[];
							for (final imageboard in ImageboardRegistry.instance.imageboardsIncludingDev) {
								for (final entry in imageboard.persistence.savedAttachments.entries.toList()) {
									if (!imageboard.persistence.savedAttachments.containsKey(entry.key)) {
										// Some race condition, probably that guy saving/unsaving with his obscene number of attachments
										continue;
									}
									// TODO: cache [exists] on the attachment
									if (await entry.value.file.exists()) {
										list.add(imageboard.scope(entry.value));
									}
									else {
										missing.add(imageboard.scope(entry.value));
									}
								}
							}
							list.sort((a, b) => b.item.savedTime.compareTo(a.item.savedTime));
							_missingSavedAttachments.value = missing;
							return list;
						},
						aboveFooter: ValueListenableBuilder(
							valueListenable: _missingSavedAttachments,
							key: _savedAttachmentsAnimatedBuilderKey,
							builder: (context, missing, _) => MissingAttachmentsControls(
								missingAttachments: missing,
								afterFix: _savedAttachmentsController.update,
								onFixAbandonedForAttachments: (attachments) async {
									for (final a in attachments) {
										a.imageboard.persistence.deleteSavedAttachment(a.item.attachment);
									}
								}
							)
						),
						gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
							crossAxisCount: 4
						),
						autoExtendDuringScroll: true,
						updateAnimation: savedAttachmentsNotifiersAnimation,
						disableUpdates: !TickerMode.of(context),
						useFiltersFromContext: false,
						includeImageboardKeyAndBoardInSearchString: true,
						filterableAdapter: null,
						itemBuilder: (context, item, options) => Builder(
							builder: (context) {
								makeController() => AttachmentViewerController(
									attachment: item.item.attachment,
									context: context,
									imageboard: item.imageboard,
									isDownloaded: _downloadedAttachments.contains(item.item.attachment),
									overrideSource: item.item.file.uri
								);
								return ImageboardScope(
									imageboardKey: item.imageboard.key,
									child: CupertinoInkwell(
										padding: EdgeInsets.zero,
										child: ContextMenu(
											actions: [
												ContextMenuAction(
													trailingIcon: CupertinoIcons.cloud_download,
													onPressed: () async {
														final controller = makeController();
														final download = !controller.isDownloaded || (await confirm(context, 'Redownload?'));
														if (!download) return;
														final filename = await controller.download(force: true);
														if (filename != null && context.mounted) {
															showToast(context: context, message: 'Downloaded $filename', icon: CupertinoIcons.cloud_download);
														}
														controller.dispose();
													},
													child: const Text('Download')
												),
												if (isSaveFileAsSupported) ContextMenuAction(
													trailingIcon: Icons.folder,
													onPressed: () async {
														final controller = makeController();
														final filename = await controller.download(force: true, saveAs: true);
														if (filename != null && context.mounted) {
															showToast(context: context, message: 'Downloaded $filename', icon: Icons.folder);
														}
														controller.dispose();
													},
													child: const Text('Download to...')
												),
												ContextMenuAction(
													trailingIcon: Adaptive.icons.share,
													onPressed: () async {
														final controller = makeController();
														await controller.share(null);
														controller.dispose();
													},
													child: const Text('Share')
												),
												ContextMenuAction(
													child: const Text('Share link'),
													trailingIcon: CupertinoIcons.link,
													onPressed: () async {
														final controller = makeController();
														final text = controller.goodImagePublicSource.toString();
														shareOne(
															context: context,
															text: text,
															type: "text",
															sharePositionOrigin: null
														);
														controller.dispose();
													}
												),
												...buildImageSearchActions(context, item.imageboard, [item.item.attachment]),
												_makeFindSavedAttachmentInThreadAction(
													attachment: item.item.attachment,
													poppedOut: false,
													context: context,
													innerContext: null,
													imageboard: item.imageboard
												)
											],
											child: Container(
												decoration: BoxDecoration(
													color: Colors.transparent,
													borderRadius: const BorderRadius.all(Radius.circular(4)),
													border: Border.all(color: selected(context, item) ? ChanceTheme.primaryColorOf(context) : Colors.transparent, width: 2)
												),
												margin: const EdgeInsets.all(4),
												child: Hero(
													tag: TaggedAttachment(
														attachment: item.item.attachment,
														semanticParentIds: [-5, imageboardIds.putIfAbsent(item.imageboard.key, () => imageboardIds.length)],
														imageboard: item.imageboard
													),
													child: MediaThumbnail(
														uri: item.item.file.uri,
														fit: BoxFit.contain
													),
													flightShuttleBuilder: (context, animation, direction, fromContext, toContext) {
														return (direction == HeroFlightDirection.push ? fromContext.widget as Hero : toContext.widget as Hero).child;
													},
													createRectTween: (startRect, endRect) {
														if (startRect != null && endRect != null) {
															if (item.item.attachment.type == AttachmentType.image) {
																// Need to deflate the original startRect because it has inbuilt layoutInsets
																// This SavedAttachmentThumbnail will always fill its size
																final rootPadding = MediaQueryData.fromView(View.of(context)).padding - sumAdditionalSafeAreaInsets();
																startRect = rootPadding.deflateRect(startRect);
															}
														}
														return CurvedRectTween(curve: Curves.ease, begin: startRect, end: endRect);
													}
												)
											)
										),
										onPressed: () async {
											if (context.read<MasterDetailHint?>()?.currentValue == null) {
												// First use of gallery
												await handleMutingBeforeShowingGallery();
											}
											setter(item);
										}
									)
								);
							}
						)
					),
					detailBuilder: (selectedValue, setter, poppedOut) {
						Widget child;
						if (selectedValue == null) {
							child = _placeholder('Select an attachment');
						}
						else {
							final thisImageboardId = imageboardIds.putIfAbsent(selectedValue.imageboard.key, () => imageboardIds.length);
							final attachment = TaggedAttachment(
								attachment: selectedValue.item.attachment,
								semanticParentIds: poppedOut ? [-5, thisImageboardId] : [-6, thisImageboardId],
								imageboard: selectedValue.imageboard
							);
							child = ImageboardScope(
								imageboardKey: selectedValue.imageboard.key,
								child: Builder(
									builder: (innerContext) => GalleryPage(
										initialAttachment: attachment,
										attachments: _savedAttachmentsController.items.map((l) {
											final thisImageboardId = imageboardIds.putIfAbsent(l.item.imageboard.key, () => imageboardIds.length);
											return TaggedAttachment(
												attachment: l.item.item.attachment,
												semanticParentIds: poppedOut ? [-5, thisImageboardId] : [-6, thisImageboardId],
												imageboard: l.item.imageboard
											);
										}).toList(),
										overrideSources: {
											for (final l in _savedAttachmentsController.items)
												l.item.item.attachment: l.item.item.file.uri
										},
										onChange: (a) {
											final originalL = _savedAttachmentsController.items.tryFirstWhere((l) => l.item.item.attachment == a.attachment)?.item;
											_savedAttachmentsController.animateToIfOffscreen((l) => l.item.attachment == a.attachment, alignment: 0.5);
											widget.masterDetailKey.currentState?.setValue5(originalL, updateDetailPane: false);
										},
										allowScroll: true,
										allowPop: poppedOut,
										updateOverlays: false,
										heroOtherEndIsBoxFitCover: false,
										additionalContextMenuActionsBuilder: (attachment) => [
											_makeFindSavedAttachmentInThreadAction(
												attachment: attachment.attachment,
												poppedOut: poppedOut,
												context: context,
												innerContext: innerContext,
												imageboard: ImageboardRegistry.instance.getImageboard(imageboardIds.entries.tryFirstWhere((e) => e.value == attachment.semanticParentIds.last)?.key)
											)
										],
									)
								)
							);
						}
						return BuiltDetailPane(
							widget: child,
							pageRouteBuilder: transparentPageRouteBuilder
						);
					}
				)
		);
	}

	@override
	void dispose() {
		super.dispose();
		_watchedListController.dispose();
		_threadListController.dispose();
		_postListController.dispose();
		_savedAttachmentsController.dispose();
		_removeArchivedHack.dispose();
		_savedThreadsValueInjector.dispose();
		_yourPostsValueInjector.dispose();
		_missingWatchedThreads.dispose();
		_missingSavedThreads.dispose();
		_missingSavedPostsThreads.dispose();
		_missingYourPostsThreads.dispose();
		_missingSavedAttachments.dispose();
	}
}

class LocalWatcherControls extends StatelessWidget {
	const LocalWatcherControls({
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		final w = ImageboardRegistry.threadWatcherController;
		return Padding(
			padding: const EdgeInsets.all(8),
			child: AnimatedBuilder(
				animation: w,
				builder: (context, _) => Row(
					children: [
						const SizedBox(width: 16),
						Expanded(
							child: Column(
								mainAxisSize: MainAxisSize.min,
								crossAxisAlignment: CrossAxisAlignment.center,
								children: [
									const Text('Local Watcher'),
									const SizedBox(height: 8),
									if (w.nextUpdate != null && w.lastUpdate != null) ClipRRect(
										borderRadius: const BorderRadius.all(Radius.circular(8)),
										child: TimedRebuilder(
											enabled: TickerMode.of(context),
											interval: const Duration(seconds: 1),
											function: () {
												final now = DateTime.now();
												return w.updatingNow ? null : now.difference(w.lastUpdate!).inSeconds / w.nextUpdate!.difference(w.lastUpdate!).inSeconds;
											},
											builder: (context, value) {
												return LinearProgressIndicator(
													value: value,
													color: ChanceTheme.primaryColorOf(context).withOpacity(0.5),
													backgroundColor: ChanceTheme.primaryColorWithBrightness20Of(context),
													minHeight: 8
												);
											}
										)
									)
								]
							)
						),
						const SizedBox(width: 16),
						CupertinoButton(
							onPressed: w.update,
							child: const Icon(CupertinoIcons.refresh)
						),
						AdaptiveSwitch(
							value: w.active,
							onChanged: (val) {
								if (val) {
									w.update();
								}
								else {
									w.cancel();
								}
							}
						)
					]
				)
			)
		);
	}
}

class _MissingControls<T extends Object> extends StatelessWidget {
	final List<ImageboardScoped<T>> missing;
	final String singularNoun;
	final Future<bool> Function(ImageboardScoped<T>) fixer;
	final VoidCallback afterFix;
	final Future<void> Function(List<ImageboardScoped<T>>) onFixAbandoned;

	const _MissingControls({
		required this.missing,
		required this.singularNoun,
		required this.fixer,
		required this.afterFix,
		required this.onFixAbandoned
	});

	@override
	Widget build(BuildContext context) {
		if (missing.isEmpty) {
			return const SizedBox.shrink();
		}
		final errorColor = ChanceTheme.secondaryColorOf(context);
		return CupertinoButton(
			padding: const EdgeInsets.all(16),
			onPressed: () {
				modalLoad(context, 'Fetching ${describeCount(missing.length, 'missing $singularNoun')}', (controller) async {
					final list = missing.toList(); // In case it changes
					list.shuffle();
					if (list.length > 50) {
						// Don't do too many at once
						list.removeRange(50, list.length);
					}
					final failed = <ImageboardScoped<T>>[];
					int i = 0;
					for (final item in list) {
						if (controller.cancelToken.isCancelled) {
							break;
						}
						if (!await fixer(item)) {
							failed.add(item);
						}
						controller.progress.value = ('${i + 1} / ${list.length}', (i + 1) / list.length);
						i++;
					}
					if (failed.length == list.length && context.mounted) {
						// Only failed threads. Ask to just delete them
						final clearFailed = (await showAdaptiveDialog<bool>(
							context: context,
							barrierDismissible: true,
							builder: (context) => AdaptiveAlertDialog(
								title: Text('${describeCount(failed.length, 'missing $singularNoun')} not found'),
								content: Text('''Some ${singularNoun}s could not be re-downloaded.

They were deleted from their original website, and no archives of them could be found.

Would you like to forget about them?

${failed.map((t) => '${t.imageboard.site.name}: ${t.item}').join('\n')}'''),
								actions: [
									AdaptiveDialogAction(
										isDestructiveAction: true,
										onPressed: () {
											Navigator.of(context).pop(true);
										},
										child: const Text('Forget All')
									),
									AdaptiveDialogAction(
										child: const Text('Cancel'),
										onPressed: () {
											Navigator.of(context).pop();
										}
									)
								]
							)
						)) ?? false;
						if (clearFailed) {
							await onFixAbandoned(failed);
						}
					}
					afterFix();
				}, cancellable: true);
			},
			child: Row(
				mainAxisSize: MainAxisSize.min,
				children: [
					Icon(CupertinoIcons.exclamationmark_triangle, color: errorColor),
					const SizedBox(width: 8),
					Flexible(
						child: Text(describeCount(missing.length, 'missing $singularNoun'), style: TextStyle(
							color: errorColor,
							fontWeight: FontWeight.bold,
							fontVariations: CommonFontVariations.bold
						))
					)
				]
			)
		);
	}
}

class MissingThreadsControls extends StatelessWidget {
	final List<ImageboardScoped<ThreadIdentifier>> missingThreads;
	final VoidCallback afterFix;
	final Future<void> Function(List<ImageboardScoped<ThreadIdentifier>>) onFixAbandonedForThreads;

	const MissingThreadsControls({
		required this.missingThreads,
		required this.afterFix,
		required this.onFixAbandonedForThreads,
		super.key
	});

	@override
	Widget build(BuildContext context) => _MissingControls(
		missing: missingThreads,
		singularNoun: 'thread',
		fixer: (thread) async {
			try {
				Thread? newThread;
				try {
					newThread = await thread.imageboard.site.getThread(thread.item, priority: RequestPriority.interactive);
				}
				on ThreadNotFoundException {
					try {
						newThread = await thread.imageboard.site.getThreadFromArchive(thread.item, priority: RequestPriority.interactive);
					}
					catch (e) {
						if (context.mounted) {
							showToast(
								context: context,
								icon: CupertinoIcons.exclamationmark_triangle,
								message: 'Failed to get ${thread.item} from archive: ${e.toStringDio()}'
							);
						}
					}
				}
				catch (e) {
					if (context.mounted) {
						showToast(
							context: context,
							icon: CupertinoIcons.exclamationmark_triangle,
							message: 'Failed to get ${thread.item}: ${e.toStringDio()}'
						);
					}
				}
				if (newThread != null) {
					final state = thread.imageboard.persistence.getThreadState(thread.item);
					state.thread = newThread;
					return true;
				}
			}
			catch (e, st) {
				Future.error(e, st);
			}
			return false;
		},
		afterFix: afterFix,
		onFixAbandoned: onFixAbandonedForThreads,
	);
}

class MissingAttachmentsControls extends StatelessWidget {
	final List<ImageboardScoped<SavedAttachment>> missingAttachments;
	final VoidCallback afterFix;
	final Future<void> Function(List<ImageboardScoped<SavedAttachment>>) onFixAbandonedForAttachments;

	const MissingAttachmentsControls({
		required this.missingAttachments,
		required this.afterFix,
		required this.onFixAbandonedForAttachments,
		super.key
	});

	@override
	Widget build(BuildContext context) => _MissingControls(
		missing: missingAttachments,
		singularNoun: 'attachment',
		fixer: (attachment) async {
			try {
				try {
					// Try naive URL
					await attachment.imageboard.site.client.download(attachment.item.attachment.url, attachment.item.file.path, options: Options(
						headers: {
							...attachment.imageboard.site.getHeaders(Uri.parse(attachment.item.attachment.url)),
							if (attachment.item.attachment.useRandomUseragent) 'user-agent': makeRandomUserAgent()
						}
					));
					return true;
				}
				catch (e, st) {
					Future.error(e, st); // crashlytics
				}
				final threadId = attachment.item.attachment.threadId;
				if (threadId != null) {
					final threadIdentifier = ThreadIdentifier(attachment.item.attachment.board, threadId);
					try {
						// Get the archived thread
						final redirectUrls = <String, String>{};
						final archivedThread = await attachment.imageboard.site.getThreadFromArchive(threadIdentifier, priority: RequestPriority.interactive, customValidator: (thread) async {
							final found = _findMatchingAttachment(thread, attachment.item.attachment)?.attachment;
							if (found == null) {
								throw Exception('Attachment not found in ${thread.archiveName}');
							}
							if (found.url == attachment.item.attachment.url) {
								throw Exception('Attachment not really archived on ${thread.archiveName}');
							}
							final response = await attachment.imageboard.site.client.head(found.url, options: Options(
								headers: {
									...attachment.imageboard.site.getHeaders(Uri.parse(found.url)),
									if (found.useRandomUseragent) 'user-agent': makeRandomUserAgent()
								},
								followRedirects: false,
								validateStatus: (_) => true
							));
							if ((response.statusCode ?? 400) >= 400) {
								throw HTTPStatusException.fromResponse(response);
							}
							if (response.redirects.isNotEmpty) {
								redirectUrls[found.url] = response.redirects.last.location.toString();
							}
							else if (response.headers.value(HttpHeaders.locationHeader) case String location) {
								redirectUrls[found.url] = location;
							}
						});
						final found = _findMatchingAttachment(archivedThread, attachment.item.attachment)?.attachment;
						if (found != null) {
							await attachment.imageboard.site.client.download(redirectUrls[found.url] ?? found.url, attachment.item.file.path, options: Options(
								headers: {
									...attachment.imageboard.site.getHeaders(Uri.parse(found.url)),
									if (found.useRandomUseragent) 'user-agent': makeRandomUserAgent()
								}
							));
							return true;
						}
					}
					catch (e) {
						if (context.mounted) {
							showToast(
								context: context,
								icon: CupertinoIcons.exclamationmark_triangle,
								message: 'Failed to get $threadIdentifier from archive: ${e.toStringDio()}'
							);
						}
					}
				}
			}
			catch (e, st) {
				Future.error(e, st);
			}
			return false;
		},
		afterFix: afterFix,
		onFixAbandoned: onFixAbandonedForAttachments,
	);
}

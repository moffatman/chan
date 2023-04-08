import 'dart:io';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/notifications.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/context_menu.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:chan/widgets/saved_attachment_thumbnail.dart';
import 'package:chan/widgets/thread_row.dart';
import 'package:chan/widgets/timed_rebuilder.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mutex/mutex.dart';
import 'package:provider/provider.dart';
import 'package:unifiedpush/unifiedpush.dart';

class _PostThreadCombo {
	final Imageboard imageboard;
	final Post post;
	final PersistentThreadState threadState;
	_PostThreadCombo({
		required this.imageboard,
		required this.post,
		required this.threadState
	});

	@override
	bool operator == (dynamic o) => (o is _PostThreadCombo) && (o.imageboard == imageboard) && (o.post.id == post.id) && (o.threadState.identifier == threadState.identifier);
	@override
	int get hashCode => Object.hash(imageboard, post, threadState);
}

final _watchMutex = ReadWriteMutex();
Future<List<ImageboardScoped<ThreadWatch>>> _loadWatches() => _watchMutex.protectRead(() async {
	final watches = ImageboardRegistry.instance.imageboards.expand((i) => i.persistence.browserState.threadWatches.map(i.scope)).toList();
	await Future.wait(watches.map((watch) async {
		await watch.imageboard.persistence.getThreadStateIfExists(watch.item.threadIdentifier)?.ensureThreadLoaded();
	}));
	final d = DateTime(2000);
	if (Persistence.settings.watchedThreadsSortingMethod == ThreadSortingMethod.lastReplyByYouTime) {
		mergeSort<ImageboardScoped<ThreadWatch>>(watches, compare: (a, b) {
			final ta = a.imageboard.persistence.getThreadStateIfExists(a.item.threadIdentifier);
			final tb = b.imageboard.persistence.getThreadStateIfExists(b.item.threadIdentifier);
			Post? pa;
			Post? pb;
			if (ta?.youIds.isNotEmpty == true) {
				pa = ta!.thread?.posts_.tryFirstWhere((p) => p.id == ta.youIds.last);
			}
			if (tb?.youIds.isNotEmpty == true) {
				pb = tb!.thread?.posts_.tryFirstWhere((p) => p.id == tb.youIds.last);
			}
			return (pb?.time ?? d).compareTo(pa?.time ?? d);
		});
	}
	else if (Persistence.settings.watchedThreadsSortingMethod == ThreadSortingMethod.lastPostTime) {
		mergeSort<ImageboardScoped<ThreadWatch>>(watches, compare: (a, b) {
			return (b.imageboard.persistence.getThreadStateIfExists(b.item.threadIdentifier)?.thread?.posts.last.time ?? d).compareTo(a.imageboard.persistence.getThreadStateIfExists(a.item.threadIdentifier)?.thread?.posts.last.time ?? d);
		});
	}
	mergeSort<ImageboardScoped<ThreadWatch>>(watches, compare: (a, b) {
		if (a.item.zombie == b.item.zombie) {
			return 0;
		}
		else if (a.item.zombie) {
			return 1;
		}
		else {
			return -1;
		}
	});
	return watches;
});

class SavedPage extends StatefulWidget {
	final bool isActive;
	final void Function(String, ThreadIdentifier)? onWantOpenThreadInNewTab;
	final Key? masterDetailKey;

	const SavedPage({
		required this.isActive,
		this.onWantOpenThreadInNewTab,
		this.masterDetailKey,
		Key? key
	}) : super(key: key);

	@override
	createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
	late final RefreshableListController<ImageboardScoped<ThreadWatch>> _watchedListController;
	late final RefreshableListController<PersistentThreadState> _threadListController;
	late final RefreshableListController<ImageboardScoped<SavedPost>> _postListController;
	late final RefreshableListController<_PostThreadCombo> _yourPostsListController;
	final _watchedThreadsListKey = GlobalKey();
	final _savedThreadsListKey = GlobalKey();
	final _savedPostsListKey = GlobalKey();
	final _yourPostsListKey = GlobalKey();
	final _savedAttachmentsAnimatedBuilderKey = GlobalKey();
	late final ScrollController _savedAttachmentsController;
	late final EasyListenable _removeArchivedHack;

	@override
	void initState() {
		super.initState();
		_watchedListController = RefreshableListController();
		_threadListController = RefreshableListController();
		_postListController = RefreshableListController();
		_yourPostsListController = RefreshableListController();
		_savedAttachmentsController = ScrollController();
		_removeArchivedHack = EasyListenable();
	}

	@override
	void didUpdateWidget(SavedPage oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (widget.isActive && !oldWidget.isActive) {
			_watchedListController.update();
			_threadListController.update();
			_postListController.update();
			_yourPostsListController.update();
			_removeArchivedHack.didUpdate();
		}
	}

	Widget _placeholder(String message) {
		return Container(
			decoration: BoxDecoration(
				color: CupertinoTheme.of(context).scaffoldBackgroundColor,
			),
			child: Center(
				child: Text(message)
			)
		);
	}

	ObstructingPreferredSizeWidget _watchedNavigationBar() {
		final settings = context.watch<EffectiveSettings>();
		return CupertinoNavigationBar(
			transitionBetweenRoutes: false,
			middle: const Text('Watched Threads'),
			trailing: CupertinoButton(
				padding: EdgeInsets.zero,
				child: const Icon(CupertinoIcons.sort_down),
				onPressed: () {
					showCupertinoModalPopup<DateTime>(
						context: context,
						builder: (context) => CupertinoActionSheet(
							title: const Text('Sort by...'),
							actions: {
								ThreadSortingMethod.lastPostTime: 'Last Reply',
								ThreadSortingMethod.lastReplyByYouTime: 'Last Reply by You',
							}.entries.map((entry) => CupertinoActionSheetAction(
								child: Text(entry.value, style: TextStyle(
									fontWeight: entry.key == settings.watchedThreadsSortingMethod ? FontWeight.bold : null
								)),
								onPressed: () {
									settings.watchedThreadsSortingMethod = entry.key;
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
			)
		);
	}

	ObstructingPreferredSizeWidget _savedNavigationBar(String title) {
		final settings = context.watch<EffectiveSettings>();
		return CupertinoNavigationBar(
			transitionBetweenRoutes: false,
			middle: Text(title),
			trailing: CupertinoButton(
				padding: EdgeInsets.zero,
				child: const Icon(CupertinoIcons.sort_down),
				onPressed: () {
					showCupertinoModalPopup<DateTime>(
						context: context,
						builder: (context) => CupertinoActionSheet(
							title: const Text('Sort by...'),
							actions: {
								ThreadSortingMethod.savedTime: 'Saved Date',
								ThreadSortingMethod.lastPostTime: 'Posted Date',
							}.entries.map((entry) => CupertinoActionSheetAction(
								child: Text(entry.value, style: TextStyle(
									fontWeight: entry.key == settings.savedThreadsSortingMethod ? FontWeight.bold : null
								)),
								onPressed: () {
									settings.savedThreadsSortingMethod = entry.key;
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
			)
		);
	}

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<EffectiveSettings>();
		final persistencesAnimation = FilteringListenable(Listenable.merge(ImageboardRegistry.instance.imageboards.map((x) => x.persistence).toList()), () => widget.isActive);
		final threadStateBoxesAnimation = FilteringListenable(Persistence.sharedThreadStateBox.listenable(), () => widget.isActive);
		final savedPostNotifiersAnimation = FilteringListenable(Listenable.merge(ImageboardRegistry.instance.imageboards.map((i) => i.persistence.savedAttachmentsListenable).toList()), () => widget.isActive);
		final savedAttachmentsNotifiersAnimation = FilteringListenable(Listenable.merge(ImageboardRegistry.instance.imageboards.map((i) => i.persistence.savedAttachmentsListenable).toList()), () => widget.isActive);
		return MultiMasterDetailPage(
			id: 'saved',
			key: widget.masterDetailKey,
			paneCreator: () => [
				MultiMasterPane<ImageboardScoped<ThreadWatch>>(
					navigationBar: _watchedNavigationBar(),
					icon: CupertinoIcons.bell_fill,
					masterBuilder: (context, selected, setter) {
						return SafeArea(
							child: Column(
								children: [
									ThreadWatcherControls(
										isActive: widget.isActive
									),
									Divider(
										thickness: 1,
										height: 0,
										color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2)
									),
									Expanded(
										child: RefreshableList<ImageboardScoped<ThreadWatch>>(
											filterableAdapter: null,
											controller: _watchedListController,
											listUpdater: () async {
												final list = await _loadWatches();
												_watchedListController.waitForItemBuild(0).then((_) => _removeArchivedHack.didUpdate());
												return list;
											},
											minUpdateDuration: Duration.zero,
											updateAnimation: persistencesAnimation,
											key: _watchedThreadsListKey,
											id: 'watched',
											canTapFooter: false,
											itemBuilder: (itemContext, watch) {
												final isSelected = selected(itemContext, watch);
												return ImageboardScope(
													imageboardKey: watch.imageboard.key,
													child: ContextMenu(
														maxHeight: 125,
														actions: [
															if (widget.onWantOpenThreadInNewTab != null) ContextMenuAction(
																child: const Text('Open in new tab'),
																trailingIcon: CupertinoIcons.rectangle_stack_badge_plus,
																onPressed: () {
																	widget.onWantOpenThreadInNewTab?.call(watch.imageboard.key, watch.item.threadIdentifier);
																}
															),
															ContextMenuAction(
																child: const Text('Unwatch'),
																onPressed: () async {
																	await watch.imageboard.notifications.removeWatch(watch.item);
																	_watchedListController.update();
																},
																trailingIcon: CupertinoIcons.xmark,
																isDestructiveAction: true
															),
															if (watch.imageboard.persistence.getThreadStateIfExists(watch.item.threadIdentifier)?.savedTime != null) ContextMenuAction(
																child: const Text('Un-save thread'),
																trailingIcon: CupertinoIcons.bookmark_fill,
																onPressed: () {
																	final threadState = watch.imageboard.persistence.getThreadState(watch.item.threadIdentifier);
																	threadState.savedTime = null;
																	threadState.save();
																	_threadListController.update();
																}
															)
															else ContextMenuAction(
																child: const Text('Save thread'),
																trailingIcon: CupertinoIcons.bookmark,
																onPressed: () {
																	final threadState = watch.imageboard.persistence.getThreadState(watch.item.threadIdentifier);
																	threadState.savedTime = DateTime.now();
																	threadState.save();
																}
															),
														],
														child: GestureDetector(
															behavior: HitTestBehavior.opaque,
															child: AnimatedBuilder(
																animation: watch.imageboard.persistence.listenForPersistentThreadStateChanges(watch.item.threadIdentifier),
																builder: (context, child) {
																	final threadState = watch.imageboard.persistence.getThreadStateIfExists(watch.item.threadIdentifier);
																	if (threadState?.thread == null) {
																		// Make sure this isn't a newly-created thread/watch
																		if (threadState == null || DateTime.now().difference(threadState.lastOpenedTime) > const Duration(days: 30)) {
																			// Probably the thread was deleted during a cleanup
																			Future.delayed(const Duration(seconds: 1), () {
																				watch.imageboard.notifications.removeWatch(watch.item);
																			});
																		}
																		return Text('missing for $threadState ${watch.item.threadIdentifier}');
																	}
																	else {
																		return ThreadRow(
																			thread: threadState!.thread!,
																			isSelected: isSelected,
																			showBoardName: true,
																			showSiteIcon: true,
																			dimReadThreads: watch.item.zombie,
																			onThumbnailLoadError: (error, stackTrace) {
																				watch.imageboard.threadWatcher.fixBrokenThread(watch.item.threadIdentifier);
																			},
																			semanticParentIds: const [-4],
																			onThumbnailTap: (initialAttachment) {
																				final attachments = {
																					for (final w in _watchedListController.items)
																						for (final attachment in w.item.imageboard.persistence.getThreadStateIfExists(w.item.item.threadIdentifier)?.thread?.attachments ?? <Attachment>[])
																							attachment: w.item.imageboard.persistence.getThreadStateIfExists(w.item.item.threadIdentifier)!
																					};
																				showGallery(
																					context: context,
																					attachments: attachments.keys.toList(),
																					replyCounts: {
																						for (final item in attachments.entries) item.key: item.value.thread!.replyCount
																					},
																					initialAttachment: attachments.keys.firstWhere((a) => a.id == initialAttachment.id),
																					onChange: (attachment) {
																						final threadId = attachments.entries.firstWhere((_) => _.key.id == attachment.id).value.identifier;
																						_watchedListController.animateTo((p) => p.item.threadIdentifier == threadId);
																					},
																					semanticParentIds: [-4],
																					heroOtherEndIsBoxFitCover: false
																				);
																			}
																		);
																	}
																}
															),
															onTap: () => setter(watch)
														)
													)
												);
											},
											filterHint: 'Search watched threads',
											footer: Padding(
												padding: const EdgeInsets.all(16),
												child: AnimatedBuilder(
													animation: _removeArchivedHack,
													builder: (context, _) => CupertinoButton(
														padding: const EdgeInsets.all(8),
														onPressed: (_watchedListController.items.any((w) => w.item.item.zombie)) ? () async {
															await _watchMutex.protectWrite(() async {
																_watchedListController.update(); // Should wait until mutex releases
																final toRemove = _watchedListController.items.where((w) => w.item.item.zombie).toList();
																for (final watch in toRemove) {
																	await watch.item.imageboard.notifications.removeWatch(watch.item.item);
																}
															});
														} : null,
														child: const Row(
															mainAxisSize: MainAxisSize.min,
															children: [
																Icon(CupertinoIcons.xmark),
																SizedBox(width: 8),
																Flexible(
																	child: Text('Remove archived', textAlign: TextAlign.center)
																)
															]
														)
													)
												)
											)
										)
									)
								]
							)
						);
					},
					detailBuilder: (selectedThread, poppedOut) {
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
				MultiMasterPane<ImageboardScoped<ThreadIdentifier>>(
					navigationBar: _savedNavigationBar('Saved Threads'),
					icon: CupertinoIcons.tray_full,
					masterBuilder: (context, selectedThread, threadSetter) {
						Comparator<PersistentThreadState> sortMethod = (a, b) => 0;
						if (settings.savedThreadsSortingMethod == ThreadSortingMethod.savedTime) {
							sortMethod = (a, b) => b.savedTime!.compareTo(a.savedTime!);
						}
						else if (settings.savedThreadsSortingMethod == ThreadSortingMethod.lastPostTime) {
							final noDate = DateTime.fromMillisecondsSinceEpoch(0);
							sortMethod = (a, b) => (b.thread?.posts.last.time ?? noDate).compareTo(a.thread?.posts.last.time ?? noDate);
						}
						return RefreshableList<PersistentThreadState>(
							filterableAdapter: (t) => t,
							controller: _threadListController,
							listUpdater: () async {
								final states = Persistence.sharedThreadStateBox.values.where((i) => i.savedTime != null && i.imageboard != null).toList();
								await Future.wait(states.map((s) => s.ensureThreadLoaded()));
								return states.where((s) => s.thread != null).toList();
							},
							minUpdateDuration: Duration.zero,
							id: 'saved',
							sortMethods: [sortMethod],
							key: _savedThreadsListKey,
							updateAnimation: threadStateBoxesAnimation,
							itemBuilder: (itemContext, state) {
								final isSelected = selectedThread(itemContext, state.imageboard!.scope(state.identifier));
								return ImageboardScope(
									imageboardKey: state.imageboardKey,
									child: ContextMenu(
										maxHeight: 125,
										actions: [
											if (widget.onWantOpenThreadInNewTab != null) ContextMenuAction(
												child: const Text('Open in new tab'),
												trailingIcon: CupertinoIcons.rectangle_stack_badge_plus,
												onPressed: () {
													widget.onWantOpenThreadInNewTab?.call(state.imageboardKey, state.identifier);
												}
											),
											ContextMenuAction(
												child: const Text('Unsave'),
												onPressed: () {
													state.savedTime = null;
													state.save();
													_threadListController.update();
												},
												trailingIcon: CupertinoIcons.xmark,
												isDestructiveAction: true
											)
										],
										child: GestureDetector(
											behavior: HitTestBehavior.opaque,
											child: Builder(
												builder: (context) => ThreadRow(
													thread: state.thread!,
													isSelected: isSelected,
													showBoardName: true,
													showSiteIcon: true,
													onThumbnailLoadError: (error, stackTrace) {
														state.imageboard!.threadWatcher.fixBrokenThread(state.thread!.identifier);
													},
													semanticParentIds: const [-4],
													onThumbnailTap: (initialAttachment) {
														final attachments = _threadListController.items.expand((_) => _.item.thread!.attachments).toList();
														showGallery(
															context: context,
															attachments: attachments,
															replyCounts: {
																for (final state in _threadListController.items)
																	for (final attachment in state.item.thread!.attachments)
																		attachment: state.item.thread!.replyCount
															},
															initialAttachment: attachments.firstWhere((a) => a.id == initialAttachment.id),
															onChange: (attachment) {
																_threadListController.animateTo((p) => p.thread?.attachments.any((a) => a.id == attachment.id) ?? false);
															},
															semanticParentIds: [-4],
															heroOtherEndIsBoxFitCover: false
														);
													}
												)
											),
											onTap: () => threadSetter(state.imageboard!.scope(state.identifier))
										)
									)
								);
							},
							filterHint: 'Search saved threads'
						);
					},
					detailBuilder: (selectedThread, poppedOut) {
						return BuiltDetailPane(
							widget: selectedThread != null ? ImageboardScope(
								imageboardKey: selectedThread.imageboard.key,
								child: ThreadPage(
									thread: selectedThread.item,
									boardSemanticId: -4
								)
							) : _placeholder('Select a thread'),
							pageRouteBuilder: fullWidthCupertinoPageRouteBuilder
						);
					}
				),
				MultiMasterPane<_PostThreadCombo>(
					navigationBar: const CupertinoNavigationBar(
						transitionBetweenRoutes: false,
						middle: Text('Your Posts')
					),
					icon: CupertinoIcons.pencil,
					masterBuilder: (context, selected, setter) {
						return RefreshableList<_PostThreadCombo>(
							filterableAdapter: (t) => t.post,
							controller: _yourPostsListController,
							listUpdater: () async {
								final states = Persistence.sharedThreadStateBox.values.where((v) {
									return v.imageboard != null;
								}).map((v) => v.imageboard!.scope(v)).where((i) => i.item.youIds.isNotEmpty).toList();
								await Future.wait(states.map((s) => s.item.ensureThreadLoaded()));
								final replies = <_PostThreadCombo>[];
								for (final s in states) {
									if (s.item.thread != null) {
										for (final id in s.item.youIds) {
											final reply = s.item.thread!.posts.tryFirstWhere((p) => p.id == id);
											if (reply != null) {
												replies.add(_PostThreadCombo(
													imageboard: s.imageboard,
													post: reply,
													threadState: s.item
												));
											}
										}
									}
								}
								return replies;
							},
							key: _yourPostsListKey,
							id: 'yourPosts',
							updateAnimation: threadStateBoxesAnimation,
							minUpdateDuration: Duration.zero,
							sortMethods: [(a, b) => b.post.time.compareTo(a.post.time)],
							itemBuilder: (context, item) => ImageboardScope(
								imageboardKey: item.imageboard.key,
								child: ChangeNotifierProvider<PostSpanZoneData>(
									create: (context) => PostSpanRootZoneData(
										site: item.imageboard.site,
										thread: item.threadState.thread!,
										threadState: item.threadState,
										semanticRootIds: [-8]
									),
									child: Builder(
										builder: (context) => PostRow(
											post: item.post,
											isSelected: selected(context, item),
											onTap: () => setter(item),
											showBoardName: true,
											showSiteIcon: true,
											showYourPostBorder: false,
											onThumbnailLoadError: (e, st) async {
												Thread? newThread;
												bool hadToUseArchive = false;
												try {
													newThread = await item.imageboard.site.getThread(item.post.threadIdentifier);
												}
												on ThreadNotFoundException {
													newThread = await item.imageboard.site.getThreadFromArchive(item.post.threadIdentifier);
													hadToUseArchive = true;
												}
												if (newThread != item.threadState.thread || hadToUseArchive) {
													item.threadState.thread = newThread;
													await item.threadState.save();
												}
											},
											onThumbnailTap: (initialAttachment) {
												final attachments = _yourPostsListController.items.expand((_) => _.item.post.attachments).toList();
												showGallery(
													context: context,
													attachments: attachments,
													replyCounts: {
														for (final state in _yourPostsListController.items)
															for (final attachment in state.item.imageboard.persistence.getThreadStateIfExists(state.item.post.threadIdentifier)?.thread?.attachments ?? [])
																attachment: state.item.imageboard.persistence.getThreadStateIfExists(state.item.post.threadIdentifier)?.thread?.replyCount ?? 0
													},
													initialAttachment: attachments.firstWhere((a) => a.id == initialAttachment.id),
													onChange: (attachment) {
														_yourPostsListController.animateTo((p) => p.imageboard.persistence.getThreadStateIfExists(p.post.threadIdentifier)?.thread?.attachments.any((a) => a.id == attachment.id) ?? false);
													},
													semanticParentIds: [-8],
													heroOtherEndIsBoxFitCover: false
												);
											}
										)
									)
								)
							)
						);
					},
					detailBuilder: (selected, poppedOut) => BuiltDetailPane(
						widget: selected == null ? _placeholder('Select a post') : ImageboardScope(
							imageboardKey: selected.imageboard.key,
							child: ThreadPage(
								thread: selected.post.threadIdentifier,
								initialPostId: selected.post.id,
								boardSemanticId: -8
							)
						),
						pageRouteBuilder: fullWidthCupertinoPageRouteBuilder
					)
				),
				MultiMasterPane<ImageboardScoped<SavedPost>>(
					navigationBar: _savedNavigationBar('Saved Posts'),
					icon: CupertinoIcons.reply,
					masterBuilder: (context, selected, setter) {
						Comparator<ImageboardScoped<SavedPost>> sortMethod = (a, b) => 0;
						if (settings.savedThreadsSortingMethod == ThreadSortingMethod.savedTime) {
							sortMethod = (a, b) => b.item.savedTime.compareTo(a.item.savedTime);
						}
						else if (settings.savedThreadsSortingMethod == ThreadSortingMethod.lastPostTime) {
							sortMethod = (a, b) => b.item.post.time.compareTo(a.item.post.time);
						}
						return RefreshableList<ImageboardScoped<SavedPost>>(
							filterableAdapter: (t) => t.item.post,
							controller: _postListController,
							listUpdater: () async {
								final savedPosts = ImageboardRegistry.instance.imageboards.expand((i) => i.persistence.savedPosts.values.map(i.scope)).toList();
								await Future.wait(savedPosts.map((s) async {
									await s.imageboard.persistence.getThreadStateIfExists(s.item.post.threadIdentifier)?.ensureThreadLoaded();
								}));
								return savedPosts;
							},
							id: 'saved',
							key: _savedPostsListKey,
							updateAnimation: savedPostNotifiersAnimation,
							minUpdateDuration: Duration.zero,
							sortMethods: [sortMethod],
							itemBuilder: (context, savedPost) {
								final threadState = savedPost.imageboard.persistence.getThreadStateIfExists(savedPost.item.post.threadIdentifier);
								if (threadState?.thread == null) {
									// Probably the thread was deleted during a cleanup
									Future.delayed(const Duration(seconds: 1), () {
										print('cleaning up ${savedPost.item.post}');
										savedPost.imageboard.persistence.unsavePost(savedPost.item.post);
									});
									return const SizedBox.shrink();
								}
								return ImageboardScope(
									imageboardKey: savedPost.imageboard.key,
									child: ChangeNotifierProvider<PostSpanZoneData>(
										create: (context) => PostSpanRootZoneData(
											site: savedPost.imageboard.site,
											thread: threadState!.thread!,
											semanticRootIds: [-2]
										),
										child: Builder(
											builder: (context) => PostRow(
												post: savedPost.item.post,
												isSelected: selected(context, savedPost),
												onTap: () => setter(savedPost),
												showBoardName: true,
												showSiteIcon: true,
												onThumbnailLoadError: (e, st) async {
													Thread? newThread;
													bool hadToUseArchive = false;
													try {
														newThread = await savedPost.imageboard.site.getThread(savedPost.item.post.threadIdentifier);
													}
													on ThreadNotFoundException {
														newThread = await savedPost.imageboard.site.getThreadFromArchive(savedPost.item.post.threadIdentifier);
														hadToUseArchive = true;
													}
													if (newThread != threadState!.thread || hadToUseArchive) {
														threadState.thread = newThread;
														final state = savedPost.imageboard.persistence.getThreadStateIfExists(savedPost.item.post.threadIdentifier);
														state?.thread = newThread;
														await state?.save();
														savedPost.item.post = newThread.posts.firstWhere((p) => p.id == savedPost.item.post.id);
														savedPost.imageboard.persistence.didUpdateSavedPost();
													}
												},
												onThumbnailTap: (initialAttachment) {
													final attachments = _postListController.items.expand((_) => _.item.item.post.attachments).toList();
													showGallery(
														context: context,
														attachments: attachments,
														replyCounts: {
															for (final state in _postListController.items)
																for (final attachment in state.item.imageboard.persistence.getThreadStateIfExists(state.item.item.post.threadIdentifier)?.thread?.attachments ?? [])
																	attachment: state.item.imageboard.persistence.getThreadStateIfExists(state.item.item.post.threadIdentifier)?.thread?.replyCount ?? 0
														},
														initialAttachment: attachments.firstWhere((a) => a.id == initialAttachment.id),
														onChange: (attachment) {
															_postListController.animateTo((p) => p.imageboard.persistence.getThreadStateIfExists(p.item.post.threadIdentifier)?.thread?.attachments.any((a) => a.id == attachment.id) ?? false);
														},
														semanticParentIds: [-2],
														heroOtherEndIsBoxFitCover: false
													);
												}
											)
										)
									)
								);
							},
							filterHint: 'Search saved threads'
						);
					},
					detailBuilder: (selected, poppedOut) => BuiltDetailPane(
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
				MultiMasterPane<ImageboardScoped<SavedAttachment>>(
					title: const Text('Saved Attachments'),
					icon: CupertinoIcons.photo,
					masterBuilder: (context, selected, setter) => AnimatedBuilder(
						key: _savedAttachmentsAnimatedBuilderKey,
						animation: savedAttachmentsNotifiersAnimation,
						builder: (context, child) {
							final list = ImageboardRegistry.instance.imageboards.expand((i) => i.persistence.savedAttachments.values.map(i.scope)).toList();
							list.sort((a, b) => b.item.savedTime.compareTo(a.item.savedTime));
							return CustomScrollView(
								controller: _savedAttachmentsController,
								slivers: [
									SliverGrid(
										delegate: SliverChildBuilderDelegate(
											(context, i) => Builder(
												builder: (context) => ImageboardScope(
													imageboardKey: list[i].imageboard.key,
													child: GestureDetector(
														child: Container(
															decoration: BoxDecoration(
																color: Colors.transparent,
																borderRadius: const BorderRadius.all(Radius.circular(4)),
																border: Border.all(color: selected(context, list[i]) ? CupertinoTheme.of(context).primaryColor : Colors.transparent, width: 2)
															),
															margin: const EdgeInsets.all(4),
															child: Hero(
																tag: TaggedAttachment(
																	attachment: list[i].item.attachment,
																	semanticParentIds: [-5]
																),
																child: SavedAttachmentThumbnail(
																	file: list[i].item.file,
																	fit: BoxFit.contain
																)
															)
														),
														onTap: () => setter(list[i])
													)
												)
											),
											childCount: list.length
										),
										gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
											crossAxisCount: 4
										)
									),
									SliverToBoxAdapter(
										child: Container(
											padding: const EdgeInsets.all(16),
											child: CupertinoButton(
												padding: const EdgeInsets.all(8),
												onPressed: list.isNotEmpty ? () async {
													final ok = await showCupertinoDialog<bool>(
														context: context,
														barrierDismissible: true,
														builder: (context) => CupertinoAlertDialog(
															title: const Text('Are you sure?'),
															content: const Text('All saved attachments will be removed.'),
															actions: [
																CupertinoDialogAction(
																	onPressed: () => Navigator.pop(context),
																	child: const Text('Cancel')
																),
																CupertinoDialogAction(
																	isDestructiveAction: true,
																	onPressed: () => Navigator.pop(context, true),
																	child: const Text('Delete all')
																)
															]
														)
													);
													if (ok != true || !mounted) {
														return;
													}
													for (final item in list) {
														item.imageboard.persistence.deleteSavedAttachment(item.item.attachment);
													}
												} : null,
												child: const Row(
													mainAxisSize: MainAxisSize.min,
													children: [
														Icon(CupertinoIcons.xmark),
														SizedBox(width: 8),
														Flexible(
															child: Text('Delete all', textAlign: TextAlign.center)
														)
													]
												)
											)
										)
									)
								]
							);
						}
					),
					detailBuilder: (selectedValue, poppedOut) {
						Widget child;
						if (selectedValue == null) {
							child = _placeholder('Select an attachment');
						}
						else {
							final attachment = TaggedAttachment(
								attachment: selectedValue.item.attachment,
								semanticParentIds: poppedOut ? [-5] : [-6]
							);
							child = ImageboardScope(
								imageboardKey: selectedValue.imageboard.key,
								child: GalleryPage(
									initialAttachment: attachment,
									attachments: [attachment],
									overrideSources: {
										selectedValue.item.attachment: selectedValue.item.file.uri
									},
									allowScroll: poppedOut,
									allowPop: poppedOut,
									updateOverlays: false,
									heroOtherEndIsBoxFitCover: false
								)
							);
						}
						return BuiltDetailPane(
							widget: child,
							pageRouteBuilder: transparentPageRouteBuilder
						);
					}
				)
			]
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
	}
}

class ThreadWatcherControls extends StatefulWidget {
	final bool isActive;
	const ThreadWatcherControls({
		Key? key,
		required this.isActive
	}) : super(key: key);

	@override
	createState() => _ThreadWatcherControls();
}

class _ThreadWatcherControls extends State<ThreadWatcherControls> {
	@override
	Widget build(BuildContext context) {
		final settings = context.watch<EffectiveSettings>();
		final w = ImageboardRegistry.threadWatcherController;
		String notificationsError = '';
		if (Notifications.staticError != null) {
			notificationsError = 'Notification setup error:\n${Notifications.staticError!}';
		}
		for (final i in ImageboardRegistry.instance.imageboards) {
			if (i.notifications.error != null) {
				if (notificationsError.isNotEmpty) {
					notificationsError += '\n\n';
				}
				notificationsError += '${i.key} notifications error:\n${i.notifications.error}';
			}
		}
		return AnimatedSize(
			duration: const Duration(milliseconds: 300),
			child: Container(
				padding: const EdgeInsets.all(8),
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						AnimatedBuilder(
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
														enabled: widget.isActive,
														interval: const Duration(seconds: 1),
														builder: (context) {
															final now = DateTime.now();
															return LinearProgressIndicator(
																value: w.updatingNow ? null : now.difference(w.lastUpdate!).inSeconds / w.nextUpdate!.difference(w.lastUpdate!).inSeconds,
																color: CupertinoTheme.of(context).primaryColor.withOpacity(0.5),
																backgroundColor: CupertinoTheme.of(context).primaryColorWithBrightness(0.2),
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
									CupertinoSwitch(
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
						),
						Row(
							children: [
								const SizedBox(width: 16),
								const AutoSizeText('Push Notifications'),
								const Spacer(),
								if (notificationsError.isNotEmpty) CupertinoButton(
									onPressed: () {
										alertError(context, notificationsError);
									},
									child: const Icon(CupertinoIcons.exclamationmark_triangle, color: Colors.red)
								),
								if (Platform.isAndroid && (settings.usePushNotifications ?? false)) CupertinoButton(
									onPressed: () async {
										try {
											final currentDistributor = await UnifiedPush.getDistributor();
											final distributors = await UnifiedPush.getDistributors();
											if (!mounted) return;
											final newDistributor = await showCupertinoDialog<String>(
												context: context,
												barrierDismissible: true,
												builder: (context) => CupertinoAlertDialog(
													title: const Text('UnifiedPush Distributor'),
													content: Column(
														mainAxisSize: MainAxisSize.min,
														children: [
															const SizedBox(height: 16),
															const Flexible(
																child: Text('Select which service will be used to deliver your push notifications.')
															),
															CupertinoButton(
																padding: EdgeInsets.zero,
																onPressed: () => openBrowser(context, Uri.https('unifiedpush.org', '/users/distributors/')),
																child: const Row(
																	mainAxisSize: MainAxisSize.min,
																	children: [
																		Text('More info', style: TextStyle(fontSize: 15)),
																		Icon(CupertinoIcons.chevron_right, size: 15)
																	]
																)
															)
														]
													),
													actions: [
														...distributors.map((distributor) => CupertinoDialogAction(
															isDefaultAction: distributor == currentDistributor,
															onPressed: () => Navigator.pop(context, distributor),
															child: Text(distributor == 'com.moffatman.chan' ? 'Firebase (requires Google services)' : distributor)
														)),
														CupertinoDialogAction(
															onPressed: () => Navigator.pop(context),
															child: const Text('Cancel')
														)
													]
												)
											);
											if (newDistributor != null) {
												await Notifications.tryUnifiedPushDistributor(newDistributor);
											}
										}
										catch (e) {
											alertError(context, e.toStringDio());
											Notifications.registerUnifiedPush();
										}
									},
									child: const Icon(CupertinoIcons.wrench)
								),
								const SizedBox(
									height: 60
								),
								CupertinoSwitch(
									value: settings.usePushNotifications ?? false,
									onChanged: (val) {
										settings.usePushNotifications = val;
									}
								)
							]
						)
					]
				)
			)
		);
	}
}
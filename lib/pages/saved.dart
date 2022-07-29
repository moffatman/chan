import 'package:async/async.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/imageboard.dart';
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
import 'package:provider/provider.dart';

class _PostThreadCombo {
	final Imageboard imageboard;
	final Post post;
	final Thread thread;
	_PostThreadCombo({
		required this.imageboard,
		required this.post,
		required this.thread
	});

	@override
	bool operator == (dynamic o) => (o is _PostThreadCombo) && (o.post.id == post.id) && (o.thread.identifier == thread.identifier);
	@override
	int get hashCode => post.hashCode * 31 + thread.hashCode;
}

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
	final _watchedListController = RefreshableListController<ImageboardScoped<ThreadWatch>>();
	final _threadListController = RefreshableListController<ImageboardScoped<PersistentThreadState>>();
	final _postListController = RefreshableListController<ImageboardScoped<SavedPost>>();

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
		final persistencesAnimation = Listenable.merge(ImageboardRegistry.instance.imageboards.map((x) => x.persistence).toList());
		final threadStateBoxesAnimation = Listenable.merge(ImageboardRegistry.instance.imageboards.map((i) => i.persistence.threadStateBox.listenable()).toList());
		final savedPostNotifiersAnimation = StreamGroup.merge(ImageboardRegistry.instance.imageboards.map((i) => i.persistence.savedPostsNotifier)).asBroadcastStream();
		final savedAttachmentsNotifiersAnimation = StreamGroup.merge(ImageboardRegistry.instance.imageboards.map((i) => i.persistence.savedAttachmentsNotifier)).asBroadcastStream();
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
										child: AnimatedBuilder(
											animation: persistencesAnimation,
											builder: (context, _) {
												final watches = ImageboardRegistry.instance.imageboards.expand((i) => i.persistence.browserState.threadWatches.map((w) => ImageboardScoped(
													imageboard: i,
													item: w
												))).toList();
												final d = DateTime(2000);
												if (settings.watchedThreadsSortingMethod == ThreadSortingMethod.lastReplyByYouTime) {
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
												else if (settings.watchedThreadsSortingMethod == ThreadSortingMethod.lastPostTime) {
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
												return RefreshableList<ImageboardScoped<ThreadWatch>>(
													filterableAdapter: null,
													controller: _watchedListController,
													listUpdater: () => throw UnimplementedError(),
													id: 'watched',
													disableUpdates: true,
													initialList: watches,
													itemBuilder: (context, watch) => ImageboardScope(
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
																	onPressed: () {
																		watch.imageboard.notifications.removeThreadWatch(watch.item);
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
																child: ValueListenableBuilder(
																	valueListenable: watch.imageboard.persistence.listenForPersistentThreadStateChanges(watch.item.threadIdentifier),
																	builder: (context, box, child) {
																		final threadState = watch.imageboard.persistence.getThreadStateIfExists(watch.item.threadIdentifier);
																		if (threadState?.thread == null) {
																			// Make sure this isn't a newly-created thread/watch
																			if (threadState != null && (DateTime.now().difference(threadState.lastOpenedTime) > const Duration(days: 30))) {
																				// Probably the thread was deleted during a cleanup
																				Future.delayed(const Duration(seconds: 1), () {
																					watch.imageboard.notifications.removeThreadWatch(watch.item);
																				});
																			}
																			return const SizedBox.shrink();
																		}
																		else {
																			return Opacity(
																				opacity: watch.item.zombie ? 0.5 : 1.0,
																				child: ThreadRow(
																					thread: threadState!.thread!,
																					isSelected: watch == selected,
																					showBoardName: true,
																					showSiteIcon: true,
																					onThumbnailLoadError: (error, stackTrace) {
																						watch.imageboard.threadWatcher.fixBrokenThread(watch.item.threadIdentifier);
																					},
																					semanticParentIds: const [-4],
																					onThumbnailTap: (initialAttachment) {
																						final attachments = {
																							for (final w in _watchedListController.items)
																								if (w.imageboard.persistence.getThreadStateIfExists(w.item.threadIdentifier)?.thread?.attachment != null)
																									w.imageboard.persistence.getThreadStateIfExists(w.item.threadIdentifier)!: w.imageboard.persistence.getThreadStateIfExists(w.item.threadIdentifier)!.thread!.attachment!
																							};
																						showGallery(
																							context: context,
																							attachments: attachments.values.toList(),
																							replyCounts: {
																								for (final item in attachments.entries) item.value: item.key.thread!.replyCount
																							},
																							initialAttachment: attachments.values.firstWhere((a) => a.id == initialAttachment.id),
																							onChange: (attachment) {
																								final threadId = attachments.entries.firstWhere((_) => _.value.id == attachment.id).key.identifier;
																								_watchedListController.animateTo((p) => p.item.threadIdentifier == threadId);
																							},
																							semanticParentIds: [-4]
																						);
																					}
																				)
																			);
																		}
																	}
																),
																onTap: () => setter(watch)
															)
														)
													),
													filterHint: 'Search watched threads',
													footer: Container(
														padding: const EdgeInsets.all(16),
														child: CupertinoButton(
															padding: const EdgeInsets.all(8),
															onPressed: (watches.any((w) => w.item.zombie)) ? () {
																final toRemove = watches.where((w) => w.item.zombie).toList();
																for (final watch in toRemove) {
																	watch.imageboard.notifications.removeThreadWatch(watch.item);
																}
															} : null,
															child: Row(
																mainAxisSize: MainAxisSize.min,
																children: const [
																	Icon(CupertinoIcons.xmark),
																	SizedBox(width: 8),
																	Flexible(
																		child: Text('Remove archived', textAlign: TextAlign.center)
																	)
																]
															)
														)
													)
												);
											}
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
						Widget innerMasterBuilder(BuildContext context, Widget? child) {
							final states = ImageboardRegistry.instance.imageboards.expand((i) => i.persistence.threadStateBox.toMap().values.where((s) => s.savedTime != null).map((s) => ImageboardScoped(
								imageboard: i,
								item: s
							))).toList();
							if (settings.savedThreadsSortingMethod == ThreadSortingMethod.savedTime) {
								states.sort((a, b) => b.item.savedTime!.compareTo(a.item.savedTime!));
							}
							else if (settings.savedThreadsSortingMethod == ThreadSortingMethod.lastPostTime) {
								final noDate = DateTime.fromMillisecondsSinceEpoch(0);
								states.sort((a, b) => (b.item.thread?.posts.last.time ?? noDate).compareTo(a.item.thread?.posts.last.time ?? noDate));
							}
							return RefreshableList<ImageboardScoped<PersistentThreadState>>(
								filterableAdapter: (t) => t.item,
								controller: _threadListController,
								listUpdater: () => throw UnimplementedError(),
								id: 'saved',
								disableUpdates: true,
								initialList: states,
								itemBuilder: (context, state) => ImageboardScope(
									imageboardKey: state.imageboard.key,
									child: ContextMenu(
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
												child: const Text('Unsave'),
												onPressed: () {
													state.item.savedTime = null;
													state.item.save();
												},
												trailingIcon: CupertinoIcons.xmark,
												isDestructiveAction: true
											)
										],
										child: GestureDetector(
											behavior: HitTestBehavior.opaque,
											child: Builder(
												builder: (context) => ThreadRow(
													thread: state.item.thread!,
													isSelected: state.imageboard == selectedThread?.imageboard && state.item.thread!.identifier == selectedThread?.item,
													showBoardName: true,
													showSiteIcon: true,
													onThumbnailLoadError: (error, stackTrace) {
														state.imageboard.threadWatcher.fixBrokenThread(state.item.thread!.identifier);
													},
													semanticParentIds: const [-4],
													onThumbnailTap: (initialAttachment) {
														final attachments = _threadListController.items.where((_) => _.item.thread?.attachment != null).map((_) => _.item.thread!.attachment!).toList();
														showGallery(
															context: context,
															attachments: attachments,
															replyCounts: {
																for (final item in _threadListController.items.where((_) => _.item.thread?.attachment != null)) item.item.thread!.attachment!: item.item.thread!.replyCount
															},
															initialAttachment: attachments.firstWhere((a) => a.id == initialAttachment.id),
															onChange: (attachment) {
																_threadListController.animateTo((p) => p.item.thread?.attachment?.id == attachment.id);
															},
															semanticParentIds: [-4]
														);
													}
												)
											),
											onTap: () => threadSetter(ImageboardScoped(
												imageboard: state.imageboard,
												item: state.item.identifier
											))
										)
									)
								),
								filterHint: 'Search saved threads'
							);
						}
						return widget.isActive ? AnimatedBuilder(
							animation: threadStateBoxesAnimation,
							builder: innerMasterBuilder
						) : innerMasterBuilder(context, null);
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
						Widget innerMasterBuilder(BuildContext context, Widget? child) {
							final states = ImageboardRegistry.instance.imageboards.expand((i) => i.persistence.threadStateBox.toMap().values.where((s) => s.youIds.isNotEmpty).map((s) => ImageboardScoped(
								imageboard: i,
								item: s
							))).toList();
							final replies = <_PostThreadCombo>[];
							for (final s in states) {
								if (s.item.thread != null) {
									for (final id in s.item.youIds) {
										final reply = s.item.thread!.posts.tryFirstWhere((p) => p.id == id);
										if (reply != null) {
											replies.add(_PostThreadCombo(
												imageboard: s.imageboard,
												post: reply,
												thread: s.item.thread!
											));
										}
									}
								}
							}
							replies.sort((a, b) => b.post.time.compareTo(a.post.time));
							return RefreshableList<_PostThreadCombo>(
								filterableAdapter: (t) => t.post,
								listUpdater: () => throw UnimplementedError(),
								id: 'yourPosts',
								disableUpdates: true,
								initialList: replies,
								itemBuilder: (context, item) => ImageboardScope(
									imageboardKey: item.imageboard.key,
									child: ChangeNotifierProvider<PostSpanZoneData>(
										create: (context) => PostSpanRootZoneData(
											site: item.imageboard.site,
											thread: item.thread,
											semanticRootIds: [-8]
										),
										child: PostRow(
											post: item.post,
											isSelected: item == selected,
											onTap: () => setter(item),
											showBoardName: true,
											showSiteIcon: true
										)
									)
								)
							);
						}
						return widget.isActive ? AnimatedBuilder(
							animation: threadStateBoxesAnimation,
							builder: innerMasterBuilder
						) : innerMasterBuilder(context, null);
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
					masterBuilder: (context, selected, setter) => StreamBuilder(
						stream: savedPostNotifiersAnimation,
						builder: (context, child) {
							final savedPosts = ImageboardRegistry.instance.imageboards.expand((i) => i.persistence.savedPosts.values.map((p) => ImageboardScoped(
								imageboard: i,
								item: p
							))).toList();
							if (settings.savedThreadsSortingMethod == ThreadSortingMethod.savedTime) {
								savedPosts.sort((a, b) => b.item.savedTime.compareTo(a.item.savedTime));
							}
							else if (settings.savedThreadsSortingMethod == ThreadSortingMethod.lastPostTime) {
								savedPosts.sort((a, b) => b.item.post.time.compareTo(a.item.post.time));
							}
							return RefreshableList<ImageboardScoped<SavedPost>>(
								filterableAdapter: (t) => t.item.post,
								controller: _postListController,
								listUpdater: () => throw UnimplementedError(),
								id: 'saved',
								disableUpdates: true,
								initialList: savedPosts,
								itemBuilder: (context, savedPost) => ImageboardScope(
									imageboardKey: savedPost.imageboard.key,
									child: ChangeNotifierProvider<PostSpanZoneData>(
										create: (context) => PostSpanRootZoneData(
											site: savedPost.imageboard.site,
											thread: savedPost.item.thread,
											semanticRootIds: [-2]
										),
										child: Builder(
											builder: (context) => PostRow(
												post: savedPost.item.post,
												isSelected: savedPost == selected,
												onTap: () => setter(savedPost),
												showBoardName: true,
												showSiteIcon: true,
												onThumbnailLoadError: (e, st) async {
													Thread? newThread;
													bool hadToUseArchive = false;
													try {
														newThread = await savedPost.imageboard.site.getThread(savedPost.item.thread.identifier);
													}
													on ThreadNotFoundException {
														newThread = await savedPost.imageboard.site.getThreadFromArchive(savedPost.item.thread.identifier);
														hadToUseArchive = true;
													}
													if (newThread != savedPost.item.thread || hadToUseArchive) {
														savedPost.item.thread = newThread;
														final state = savedPost.imageboard.persistence.getThreadStateIfExists(savedPost.item.thread.identifier);
														state?.thread = newThread;
														await state?.save();
														savedPost.item.post = newThread.posts.firstWhere((p) => p.id == savedPost.item.post.id);
														savedPost.imageboard.persistence.didUpdateSavedPost();
													}
												},
												onThumbnailTap: (initialAttachment) {
													final attachments = _postListController.items.where((_) => _.item.post.attachment != null).map((_) => _.item.post.attachment!).toList();
													showGallery(
														context: context,
														attachments: attachments,
														replyCounts: {
															for (final item in _postListController.items.where((_) => _.item.post.attachment != null)) item.item.post.attachment!: item.item.post.replyIds.length
														},
														initialAttachment: attachments.firstWhere((a) => a.id == initialAttachment.id),
														onChange: (attachment) {
															_postListController.animateTo((p) => p.item.thread.attachment?.id == attachment.id);
														},
														semanticParentIds: [-2]
													);
												}
											)
										)
									)
								),
								filterHint: 'Search saved threads'
							);
						}
					),
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
					masterBuilder: (context, selected, setter) => StreamBuilder(
						stream: savedAttachmentsNotifiersAnimation,
						builder: (context, child) {
							final list = ImageboardRegistry.instance.imageboards.expand((i) => i.persistence.savedAttachments.values.map((p) => ImageboardScoped(
								imageboard: i,
								item: p
							))).toList();
							list.sort((a, b) => b.item.savedTime.compareTo(a.item.savedTime));
							return GridView.builder(
								itemCount: list.length,
								itemBuilder: (context, i) => ImageboardScope(
									imageboardKey: list[i].imageboard.key,
									child: GestureDetector(
										child: Container(
											decoration: BoxDecoration(
												color: Colors.transparent,
												borderRadius: const BorderRadius.all(Radius.circular(4)),
												border: Border.all(color: list[i] == selected ? CupertinoTheme.of(context).primaryColor : Colors.transparent, width: 2)
											),
											margin: const EdgeInsets.all(4),
											child: Hero(
												tag: AttachmentSemanticLocation(
													attachment: list[i].item.attachment,
													semanticParents: [-5]
												),
												child: SavedAttachmentThumbnail(
													file: list[i].item.file,
													fit: BoxFit.contain
												)
											)
										),
										onTap: () => setter(list[i])
									)
								),
								gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
									crossAxisCount: 4
								)
							);
						}
					),
					detailBuilder: (selectedValue, poppedOut) => BuiltDetailPane(
						widget: selectedValue == null ? _placeholder('Select an attachment') : ImageboardScope(
							imageboardKey: selectedValue.imageboard.key,
							child: GalleryPage(
								initialAttachment: selectedValue.item.attachment,
								attachments: [selectedValue.item.attachment],
								overrideSources: {
									selectedValue.item.attachment: selectedValue.item.file.uri
								},
								semanticParentIds: poppedOut ? [-5] : [-6],
								allowScroll: poppedOut,
								updateOverlays: false
							)
						),
						pageRouteBuilder: transparentPageRouteBuilder
					)
				)
			]
		);
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
		return AnimatedSize(
			duration: const Duration(milliseconds: 300),
			child: Container(
				padding: const EdgeInsets.all(8),
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						for (final i in ImageboardRegistry.instance.imageboards) AnimatedBuilder(
							animation: i.threadWatcher,
							builder: (context, _) => Row(
								children: [
									const SizedBox(width: 16),
									Expanded(
										child: Column(
											mainAxisSize: MainAxisSize.min,
											crossAxisAlignment: CrossAxisAlignment.center,
											children: [
												AutoSizeText(i.site.name, maxLines: 1),
												const SizedBox(height: 8),
												if (i.threadWatcher.nextUpdate != null && i.threadWatcher.lastUpdate != null) ClipRRect(
													borderRadius: const BorderRadius.all(Radius.circular(8)),
													child: TimedRebuilder(
														enabled: widget.isActive,
														interval: const Duration(seconds: 1),
														builder: (context) {
															final now = DateTime.now();
															return LinearProgressIndicator(
																value: now.difference(i.threadWatcher.lastUpdate!).inSeconds / i.threadWatcher.nextUpdate!.difference(i.threadWatcher.lastUpdate!).inSeconds,
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
										onPressed: i.threadWatcher.update,
										child: const Icon(CupertinoIcons.refresh)
									),
									CupertinoSwitch(
										value: i.threadWatcher.active,
										onChanged: (val) {
											if (val) {
												i.threadWatcher.update();
											}
											else {
												i.threadWatcher.cancel();
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
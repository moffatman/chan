import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:chan/widgets/saved_attachment_thumbnail.dart';
import 'package:chan/widgets/thread_row.dart';
import 'package:chan/widgets/timed_rebuilder.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

class _PostThreadCombo implements Filterable {
	final Post post;
	final Thread thread;
	_PostThreadCombo({
		required this.post,
		required this.thread
	});

	@override
	bool operator == (dynamic o) => (o is _PostThreadCombo) && (o.post.id == post.id) && (o.thread.identifier == thread.identifier);
	@override
	int get hashCode => post.hashCode * 31 + thread.hashCode;

	@override
	String get board => post.board;
	@override
	int get id => post.id;
	@override
	String? getFilterFieldText(String fieldName) => post.getFilterFieldText(fieldName);
	@override
	bool get hasFile => post.hasFile;
	@override
	bool get isThread => false;
}
class SavedPage extends StatefulWidget {
	const SavedPage({
		Key? key
	}) : super(key: key);

	@override
	createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
	final _threadListController = RefreshableListController<PersistentThreadState>();
	final _postListController = RefreshableListController<SavedPost>();

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

	ObstructingPreferredSizeWidget _navigationBar(String title) {
		final settings = context.watch<EffectiveSettings>();
		return CupertinoNavigationBar(
			transitionBetweenRoutes: false,
			middle: Text(title),
			trailing: CupertinoButton(
				padding: EdgeInsets.zero,
				child: const Icon(Icons.sort),
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
		final persistence = context.watch<Persistence>();
		return MultiMasterDetailPage(
			id: 'saved',
			paneCreator: () => [
				MultiMasterPane<ThreadIdentifier>(
					navigationBar: _navigationBar('Saved Threads'),
					icon: Icons.topic,
					masterBuilder: (context, selectedThread, threadSetter) {
						return SafeArea(
							child: Column(
								children: [
									const ThreadWatcherControls(),
									Divider(
										thickness: 1,
										height: 0,
										color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2)
									),
									Expanded(
										child: ValueListenableBuilder(
											valueListenable: persistence.threadStateBox.listenable(),
											builder: (context, Box<PersistentThreadState> box, child) {
												final states = box.toMap().values.where((s) => s.savedTime != null).toList();
												if (settings.savedThreadsSortingMethod == ThreadSortingMethod.savedTime) {
													states.sort((a, b) => b.savedTime!.compareTo(a.savedTime!));
												}
												else if (settings.savedThreadsSortingMethod == ThreadSortingMethod.lastPostTime) {
													final noDate = DateTime.fromMillisecondsSinceEpoch(0);
													states.sort((a, b) => (b.thread?.posts.last.time ?? noDate).compareTo(a.thread?.posts.last.time ?? noDate));
												}
												return RefreshableList<PersistentThreadState>(
													controller: _threadListController,
													listUpdater: () => throw UnimplementedError(),
													id: 'saved',
													disableUpdates: true,
													initialList: states,
													itemBuilder: (context, state) => GestureDetector(
														behavior: HitTestBehavior.opaque,
														child: ThreadRow(
															thread: state.thread!,
															isSelected: state.thread!.identifier == selectedThread,
															showBoardName: true,
															onThumbnailLoadError: (error, stackTrace) {
																context.read<SavedThreadWatcher>().fixBrokenThread(state.thread!.identifier);
															},
															semanticParentIds: const [-4],
															onThumbnailTap: (initialAttachment) {
																final attachments = _threadListController.items.where((_) => _.thread?.attachment != null).map((_) => _.thread!.attachment!).toList();
																showGallery(
																	context: context,
																	attachments: attachments,
																	initialAttachment: attachments.firstWhere((a) => a.id == initialAttachment.id),
																	onChange: (attachment) {
																		_threadListController.animateTo((p) => p.thread?.attachment?.id == attachment.id);
																	},
																	semanticParentIds: [-4]
																);
															}
														),
														onTap: () => threadSetter(state.thread!.identifier)
													),
													filterHint: 'Search saved threads'
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
							widget: selectedThread != null ? ThreadPage(
								thread: selectedThread,
								boardSemanticId: -4
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
					icon: Icons.person,
					masterBuilder: (context, selected, setter) => ValueListenableBuilder(
						valueListenable: persistence.threadStateBox.listenable(),
						builder: (context, Box<PersistentThreadState> box, child) {
							final replies = <_PostThreadCombo>[];
							for (final s in box.values) {
								if (s.thread != null) {
									for (final id in s.youIds) {
										final reply = s.thread!.posts.tryFirstWhere((p) => p.id == id);
										if (reply != null) {
											replies.add(_PostThreadCombo(
												post: reply,
												thread: s.thread!
											));
										}
									}
								}
							}
							replies.sort((a, b) => b.post.time.compareTo(a.post.time));
							return RefreshableList<_PostThreadCombo>(
								listUpdater: () => throw UnimplementedError(),
								id: 'yourPosts',
								disableUpdates: true,
								initialList: replies,
								itemBuilder: (context, item) => ChangeNotifierProvider<PostSpanZoneData>(
									create: (context) => PostSpanRootZoneData(
										site: context.read<ImageboardSite>(),
										thread: item.thread,
										semanticRootIds: [-8]
									),
									child: PostRow(
										post: item.post,
										isSelected: item == selected,
										onTap: () => setter(item)
									)
								)
							);
						}
					),
					detailBuilder: (selected, poppedOut) => BuiltDetailPane(
						widget: selected == null ? _placeholder('Select a post') : ThreadPage(
							thread: selected.post.threadIdentifier,
							initialPostId: selected.post.id,
							boardSemanticId: -8
						),
						pageRouteBuilder: fullWidthCupertinoPageRouteBuilder
					)
				),
				MultiMasterPane<SavedPost>(
					navigationBar: _navigationBar('Saved Posts'),
					icon: Icons.reply,
					masterBuilder: (context, selected, setter) => AnimatedBuilder(
						animation: persistence.savedPostsNotifier,
						builder: (context, child) {
							final savedPosts = persistence.savedPosts.values.toList();
							if (settings.savedThreadsSortingMethod == ThreadSortingMethod.savedTime) {
								savedPosts.sort((a, b) => b.savedTime.compareTo(a.savedTime));
							}
							else if (settings.savedThreadsSortingMethod == ThreadSortingMethod.lastPostTime) {
								savedPosts.sort((a, b) => b.post.time.compareTo(a.post.time));
							}
							return RefreshableList<SavedPost>(
								controller: _postListController,
								listUpdater: () => throw UnimplementedError(),
								id: 'saved',
								disableUpdates: true,
								initialList: savedPosts,
								itemBuilder: (context, savedPost) => ChangeNotifierProvider<PostSpanZoneData>(
									create: (context) => PostSpanRootZoneData(
										site: context.read<ImageboardSite>(),
										thread: savedPost.thread,
										semanticRootIds: [-2]
									),
									child: PostRow(
										post: savedPost.post,
										isSelected: savedPost == selected,
										onTap: () => setter(savedPost),
										onThumbnailTap: (initialAttachment) {
											final attachments = _postListController.items.where((_) => _.thread.attachment != null).map((_) => _.thread.attachment!).toList();
											showGallery(
												context: context,
												attachments: attachments,
												initialAttachment: attachments.firstWhere((a) => a.id == initialAttachment.id),
												onChange: (attachment) {
													_postListController.animateTo((p) => p.thread.attachment?.id == attachment.id);
												},
												semanticParentIds: [-2]
											);
										}
									)
								),
								filterHint: 'Search saved threads'
							);
						}
					),
					detailBuilder: (selected, poppedOut) => BuiltDetailPane(
						widget: selected == null ? _placeholder('Select a post') : ThreadPage(
							thread: selected.post.threadIdentifier,
							initialPostId: selected.post.id,
							boardSemanticId: -2
						),
						pageRouteBuilder: fullWidthCupertinoPageRouteBuilder
					)
				),
				MultiMasterPane<SavedAttachment>(
					title: const Text('Saved Attachments'),
					icon: Icons.image,
					masterBuilder: (context, selected, setter) => AnimatedBuilder(
						animation: persistence.savedAttachmentsNotifier,
						builder: (context, child) {
							final list = persistence.savedAttachments.values.toList();
							list.sort((a, b) => b.savedTime.compareTo(a.savedTime));
							return GridView.builder(
								itemCount: list.length,
								itemBuilder: (context, i) {
									return GestureDetector(
										child: Container(
											decoration: BoxDecoration(
												color: Colors.transparent,
												borderRadius: const BorderRadius.all(Radius.circular(4)),
												border: Border.all(color: list[i] == selected ? CupertinoTheme.of(context).primaryColor : Colors.transparent, width: 2)
											),
											margin: const EdgeInsets.all(4),
											child: Hero(
												tag: AttachmentSemanticLocation(
													attachment: list[i].attachment,
													semanticParents: [-5]
												),
												child: SavedAttachmentThumbnail(
													file: list[i].file,
													fit: BoxFit.cover
												)
											)
										),
										onTap: () => setter(list[i])
									);
								},
								gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
									crossAxisCount: 4
								)
							);
						}
					),
					detailBuilder: (selectedValue, poppedOut) => BuiltDetailPane(
						widget: selectedValue == null ? _placeholder('Select an attachment') : GalleryPage(
							initialAttachment: selectedValue.attachment,
							attachments: [selectedValue.attachment],
							overrideSources: {
								selectedValue.attachment: selectedValue.file.uri
							},
							semanticParentIds: poppedOut ? [-5] : [-6],
							allowScroll: poppedOut
						),
						pageRouteBuilder: transparentPageRouteBuilder
					)
				)
			]
		);
	}
}

class ThreadWatcherControls extends StatefulWidget {
	const ThreadWatcherControls({
		Key? key
	}) : super(key: key);

	@override
	createState() => _ThreadWatcherControls();
}
class _ThreadWatcherControls extends State<ThreadWatcherControls> {
	@override
	Widget build(BuildContext context) {
		final watcher = context.watch<SavedThreadWatcher>();
		return AnimatedSize(
			duration: const Duration(milliseconds: 300),
			child: Container(
				padding: const EdgeInsets.all(8),
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						Row(
							children: [
								const SizedBox(width: 16),
								Expanded(
									child: Column(
										mainAxisSize: MainAxisSize.min,
										crossAxisAlignment: CrossAxisAlignment.center,
										children: [
											const Text('Thread Watcher'),
											const SizedBox(height: 8),
											if (watcher.nextUpdate != null && watcher.lastUpdate != null) ClipRRect(
												borderRadius: const BorderRadius.all(Radius.circular(8)),
												child: TimedRebuilder(
													interval: const Duration(seconds: 1),
													builder: (context) {
														final now = DateTime.now();
														return LinearProgressIndicator(
															value: now.difference(watcher.lastUpdate!).inSeconds / watcher.nextUpdate!.difference(watcher.lastUpdate!).inSeconds,
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
									child: const Icon(Icons.refresh),
									onPressed: watcher.update
								),
								CupertinoSwitch(
									value: watcher.active,
									onChanged: (val) {
										if (val) {
											watcher.update();
										}
										else {
											watcher.cancel();
										}
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
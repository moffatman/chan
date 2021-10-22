import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/thread.dart';
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
	List<String> getSearchableText() => post.getSearchableText();
}
class SavedPage extends StatefulWidget {
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
				child: Icon(Icons.sort),
				onPressed: () {
					showCupertinoModalPopup<DateTime>(
						context: context,
						builder: (context) => CupertinoActionSheet(
							title: const Text('Sort by...'),
							actions: {
								ThreadSortingMethod.SavedTime: 'Saved Date',
								ThreadSortingMethod.LastPostTime: 'Posted Date',
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
		return MultiMasterDetailPage(
			panes: [
				MultiMasterPane<ThreadIdentifier>(
					id: 'savedThreads',
					navigationBar: _navigationBar('Saved Threads'),
					icon: Icons.topic,
					masterBuilder: (context, selectedThread, threadSetter) {
						return SafeArea(
							child: Column(
								children: [
									ThreadWatcherControls(),
									Divider(
										thickness: 1,
										height: 0,
										color: CupertinoTheme.of(context).primaryColor.withBrightness(0.2)
									),
									Expanded(
										child: ValueListenableBuilder(
											valueListenable: Persistence.threadStateBox.listenable(),
											builder: (context, Box<PersistentThreadState> box, child) {
												final states = box.toMap().values.where((s) => s.savedTime != null).toList();
												if (settings.savedThreadsSortingMethod == ThreadSortingMethod.SavedTime) {
													states.sort((a, b) => b.savedTime!.compareTo(a.savedTime!));
												}
												else if (settings.savedThreadsSortingMethod == ThreadSortingMethod.LastPostTime) {
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
															onThumbnailLoadError: (error) {
																context.read<ThreadWatcher>().fixBrokenThread(state.thread!.identifier);
															},
															semanticParentIds: [-4],
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
							widget: selectedThread != null ? ThreadPage(thread: selectedThread) : _placeholder('Select a thread'),
							pageRouteBuilder: fullWidthCupertinoPageRouteBuilder
						);
					}
				),
				MultiMasterPane<_PostThreadCombo>(
					id: 'yourPosts',
					navigationBar: CupertinoNavigationBar(
						transitionBetweenRoutes: false,
						middle: Text('Your Posts')
					),
					icon: Icons.person,
					masterBuilder: (context, selected, setter) => ValueListenableBuilder(
						valueListenable: Persistence.threadStateBox.listenable(),
						builder: (context, Box<PersistentThreadState> box, child) {
							final replies = <_PostThreadCombo>[];
							for (final s in box.values) {
								if (s.thread != null) {
									for (final r in s.receipts) {
										final reply = s.thread!.posts.tryFirstWhere((p) => p.id == r.id);
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
										semanticRootId: -8
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
						),
						pageRouteBuilder: fullWidthCupertinoPageRouteBuilder
					)
				),
				MultiMasterPane<SavedPost>(
					id: 'savedPosts',
					navigationBar: _navigationBar('Saved Posts'),
					icon: Icons.reply,
					masterBuilder: (context, selected, setter) => ValueListenableBuilder(
						valueListenable: Persistence.savedPostsBox.listenable(),
						builder: (context, Box<SavedPost> box, child) {
							final savedPosts = box.values.toList();
							if (settings.savedThreadsSortingMethod == ThreadSortingMethod.SavedTime) {
								savedPosts.sort((a, b) => b.savedTime.compareTo(a.savedTime));
							}
							else if (settings.savedThreadsSortingMethod == ThreadSortingMethod.LastPostTime) {
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
										semanticRootId: -2
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
						),
						pageRouteBuilder: fullWidthCupertinoPageRouteBuilder
					)
				),
				MultiMasterPane<SavedAttachment>(
					id: 'savedAttachments',
					title: Text('Saved Attachments'),
					icon: Icons.image,
					masterBuilder: (context, selected, setter) => ValueListenableBuilder(
						valueListenable: Persistence.savedAttachmentBox.listenable(),
						builder: (context, box, child) {
							final list = Persistence.savedAttachmentBox.values.toList();
							list.sort((a, b) => b.savedTime.compareTo(a.savedTime));
							return GridView.builder(
								itemCount: list.length,
								itemBuilder: (context, i) {
									return GestureDetector(
										child: Container(
											decoration: BoxDecoration(
												color: Colors.transparent,
												borderRadius: BorderRadius.all(Radius.circular(4)),
												border: Border.all(color: list[i] == selected ? Colors.blue : Colors.transparent, width: 2)
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
								gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
	createState() => _ThreadWatcherControls();
}
class _ThreadWatcherControls extends State<ThreadWatcherControls> {
	@override
	Widget build(BuildContext context) {
		final watcher = context.watch<ThreadWatcher>();
		return AnimatedSize(
			duration: Duration(milliseconds: 300),
			child: Container(
				padding: EdgeInsets.all(8),
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						Row(
							children: [
								Text('Thread Watcher'),
								Spacer(),
								CupertinoButton(
									child: Icon(Icons.refresh),
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
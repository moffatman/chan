import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:chan/widgets/reply_box.dart';
import 'package:chan/widgets/util.dart';
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

	ThreadPage({
		required this.thread,
		this.initialPostId,
		this.initiallyUseArchive = false
	});

	@override
	createState() => _ThreadPageState();
}

class _ThreadPageState extends State<ThreadPage> with TickerProviderStateMixin {
	late PersistentThreadState persistentState;
	bool showReplyBox = false;
	final _subNavigatorKey = GlobalKey<NavigatorState>();

	final _listController = RefreshableListController<Post>();
	late PostSpanRootZoneData zone;
	bool blocked = false;
	bool _unnaturallyScrolling = false;

	Future<void> _blockAndScrollToPostIfNeeded() async {
		final int? scrollToId = widget.initialPostId ?? persistentState.lastSeenPostId;
		if (persistentState.thread != null && scrollToId != null) {
			setState(() {
				blocked = true;
				_unnaturallyScrolling = true;
			});
			try {
				await WidgetsBinding.instance!.endOfFrame;
				await _listController.animateTo((post) => post.id == scrollToId, orElseLast: (post) => post.id <= scrollToId, alignment: 1.0, duration: Duration(milliseconds: 1));
				await WidgetsBinding.instance!.endOfFrame;
			}
			catch (e, st) {
				print('Error scrolling');
				print(e);
				print(st);
			}
			setState(() {
				blocked = false;
			});
			await Future.delayed(Duration(milliseconds: 200));
			_unnaturallyScrolling = false;
		}
	}

	@override
	void initState() {
		super.initState();
		persistentState = Persistence.getThreadState(widget.thread, updateOpenedTime: true);
		persistentState.useArchive |= widget.initiallyUseArchive;
		persistentState.save();
		zone = PostSpanRootZoneData(
			board: widget.thread.board,
			threadPosts: persistentState.thread?.posts ?? [],
			site: context.read<ImageboardSite>(),
			threadId: widget.thread.id,
			threadState: persistentState,
			onNeedScrollToPost: (post) {
				_subNavigatorKey.currentState!.popUntil((route) => route.isFirst);
				Future.delayed(Duration(milliseconds: 150), () => _listController.animateTo((val) => val.id == post.id));
			}
		);
		_listController.slowScrollUpdates.listen((_) {
			if (persistentState.thread != null && !_unnaturallyScrolling) {
				final newLastSeen = persistentState.thread!.posts[_listController.lastVisibleIndex].id;	
				if (newLastSeen > (persistentState.lastSeenPostId ?? 0)) {
					persistentState.lastSeenPostId = newLastSeen;
					persistentState.save();
				}
			}
		});
		_blockAndScrollToPostIfNeeded();
	}

	@override
	void didUpdateWidget(ThreadPage old) {
		super.didUpdateWidget(old);
		if (widget.thread.board != old.thread.board || widget.thread.id != old.thread.id) {
			persistentState.save(); // Save old state in case it had pending scroll update to save
			persistentState = Persistence.getThreadState(widget.thread, updateOpenedTime: true);
			persistentState.useArchive |= widget.initiallyUseArchive;
			final oldZone = zone;
			Future.delayed(Duration(milliseconds: 100), () => oldZone.dispose());
			zone = PostSpanRootZoneData(
				board: widget.thread.board,
				threadPosts: persistentState.thread?.posts ?? [],
				site: context.read<ImageboardSite>(),
				threadId: widget.thread.id,
				threadState: persistentState
			);
			persistentState.save();
			_blockAndScrollToPostIfNeeded();
			setState(() {});
		}
	}

	void _showGallery({bool initiallyShowChrome = true, Attachment? initialAttachment}) {
		final attachments = persistentState.thread!.posts.where((_) => _.attachment != null).map((_) => _.attachment!).toList();
		showGallery(
			context: context,
			attachments: attachments,
			initiallyShowChrome: initiallyShowChrome,
			initialAttachment: (initialAttachment == null) ? null : attachments.firstWhere((a) => a.id == initialAttachment.id),
			onChange: (attachment) {
				_listController.animateTo((p) => p.attachment?.id == attachment.id);
			},
			semanticParentIds: []
		);
	}

	Widget _limitCounter(int value, int? maximum) {
		if (maximum != null && (value >= maximum * 0.8)) {
			return Text('$value / $maximum ', style: TextStyle(
				color: value >= maximum ? Colors.red : null
			));
		}
		else {
			return Text('$value ');
		}
	}

	@override
	Widget build(BuildContext context) {
		final properScrollController = PrimaryScrollController.of(context)!;
		String title = persistentState.thread?.title ?? '/${widget.thread.board}/${widget.thread.id}';
		if (persistentState.thread?.isArchived ?? false) {
			title += ' (Archived)';
		}
		return Provider(
			create: (context) => GlobalKey<ReplyBoxState>(),
			child: CupertinoPageScaffold(
				navigationBar: CupertinoNavigationBar(
					transitionBetweenRoutes: false,
					middle: AutoSizeText(title),
					trailing: Row(
						mainAxisSize: MainAxisSize.min,
						children: [
							CupertinoButton(
								padding: EdgeInsets.zero,
								child: Icon(persistentState.savedTime == null ? Icons.bookmark_outline : Icons.bookmark),
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
								padding: EdgeInsets.zero,
								child: Icon(Icons.reply),
								onPressed: persistentState.thread?.isArchived == true ? null : () {
									setState(() {
										showReplyBox = !showReplyBox;
									});
								}
							)
						]
					)
				),
				child: Builder(
					builder: (context) => Column(
						children: [
							Flexible(
								flex: 1,
								child: MediaQuery(
									data: MediaQuery.of(context).removePadding(removeBottom: true),
									child: Navigator(
										key: _subNavigatorKey,
										initialRoute: '/',
										onGenerateRoute: (RouteSettings settings) => TransparentRoute(
											builder: (context) => Shortcuts(
												shortcuts: {
													LogicalKeySet(LogicalKeyboardKey.keyG): const OpenGalleryIntent()
												},
												child: Actions(
													actions: {
														OpenGalleryIntent: CallbackAction<OpenGalleryIntent>(
															onInvoke: (i) {
																final nextPostWithImage = persistentState.thread?.posts.skip(_listController.firstVisibleIndex).firstWhere((p) => p.attachment != null, orElse: () {
																	return persistentState.thread!.posts.take(_listController.firstVisibleIndex).firstWhere((p) => p.attachment != null);
																});
																if (nextPostWithImage != null) {
																	_showGallery(initialAttachment: nextPostWithImage.attachment);
																}
															}
														)
													},
													child: Focus(
														autofocus: true,
														child: Stack(
															fit: StackFit.expand,
															children: [
																ChangeNotifierProvider<PostSpanZoneData>.value(
																	value: zone,
																	child: PrimaryScrollController(
																		controller: properScrollController,
																		child: RefreshableList<Post>(
																			id: '/${widget.thread.board}/${widget.thread.id}',
																			disableUpdates: persistentState.thread?.isArchived ?? false,
																			autoUpdateDuration: const Duration(seconds: 60),
																			initialList: persistentState.thread?.posts,
																			footer: Container(
																				padding: EdgeInsets.all(16),
																				child: (persistentState.thread == null) ? null : Row(
																					children: [
																						Spacer(),
																						_limitCounter(persistentState.thread!.replyCount, Persistence.getBoard(widget.thread.board).threadCommentLimit),
																						Icon(Icons.reply_rounded),
																						Spacer(),
																						_limitCounter(persistentState.thread!.imageCount, Persistence.getBoard(widget.thread.board).threadImageLimit),
																						Icon(Icons.image),
																						Spacer(),
																						if (persistentState.thread!.uniqueIPCount != null) ...[
																							Text('${persistentState.thread!.uniqueIPCount} '),
																							Icon(Icons.person),
																							Spacer(),
																						],
																						if (persistentState.thread!.currentPage != null) ...[
																							_limitCounter(persistentState.thread!.currentPage!, Persistence.getBoard(widget.thread.board).pageCount),
																							Icon(Icons.insert_drive_file_rounded),
																							Spacer()
																						],
																						if (persistentState.thread!.isArchived) ...[
																							Text('Archived '),
																							Icon(Icons.archive, color: Colors.grey),
																							Spacer()
																						]
																					]
																				)
																			),
																			remedies: {
																				ThreadNotFoundException: (context, updater) => CupertinoButton.filled(
																					child: Text('Try archive'),
																					onPressed: () {
																						persistentState.useArchive = true;
																						persistentState.save();
																						updater();
																					}
																				)
																			},
																			listUpdater: () async {
																				final _thread = persistentState.useArchive ? 
																					await context.read<ImageboardSite>().getThreadFromArchive(widget.thread) :
																					await context.read<ImageboardSite>().getThread(widget.thread);
																				final bool firstLoad = persistentState.thread == null;
																				if (_thread != persistentState.thread) {
																					persistentState.thread = _thread;
																					zone.threadPosts = _thread.posts;
																					if (firstLoad) await _blockAndScrollToPostIfNeeded();
																					await persistentState.save();
																					setState(() {});
																					// The thread might switch in this interval
																					final thisThreadId = _thread.identifier;
																					Future.delayed(Duration(milliseconds: 100), () {
																						if (persistentState.thread?.identifier == thisThreadId && !_unnaturallyScrolling) {
																							if (_listController.lastVisibleIndex != -1) {
																								persistentState.lastSeenPostId = max(persistentState.lastSeenPostId ?? 0, persistentState.thread!.posts[_listController.lastVisibleIndex].id);  
																								persistentState.save();
																								setState(() {});
																							}
																							else {
																								print('Failed to find last visible post after an update in $thisThreadId');
																							}
																						}
																					});
																				}
																				return _thread.posts;
																			},
																			controller: _listController,
																			itemBuilder: (context, post) {
																				return PostRow(
																					post: post,
																					onThumbnailTap: (attachment) {
																						_showGallery(initialAttachment: attachment);
																					}
																				);
																			},
																			filteredItemBuilder: (context, post, resetPage) {
																				return PostRow(
																					post: post,
																					onThumbnailTap: (attachment) {
																						_showGallery(initialAttachment: attachment);
																					},
																					onTap: () {
																						resetPage();
																						Future.delayed(Duration(milliseconds: 250), () => _listController.animateTo((val) => val.id == post.id));
																					}
																				);
																			},
																			filterHint: 'Search in thread'
																		)
																	)
																),
																StreamBuilder(
																	stream: _listController.slowScrollUpdates,
																	builder: (context, a) {
																		final redCount = persistentState.unseenRepliesToYou?.length ?? 0;
																		final whiteCount = persistentState.unseenReplyCount ?? 0;
																		final radiusAlone = BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8));
																		final scrollToBottom = () => _listController.animateTo((post) => post.id == persistentState.thread!.posts.last.id, alignment: 1.0);
																		if (redCount > 0 || whiteCount > 0) {
																			return Align(
																				alignment: Alignment.bottomRight,
																				child: GestureDetector(
																					child: Row(
																						mainAxisSize: MainAxisSize.min,
																						children: [
																							if (redCount > 0) Container(
																								decoration: BoxDecoration(
																									borderRadius: (whiteCount > 0) ? BorderRadius.only(topLeft: Radius.circular(8)) : radiusAlone,
																									color: Colors.red
																								),
																								padding: EdgeInsets.all(8),
																								margin: (whiteCount > 0) ? null : EdgeInsets.only(right: 16),
																								child: Text(
																									redCount.toString(),
																									textAlign: TextAlign.center
																								)
																							),
																							if (whiteCount > 0) Container(
																								decoration: BoxDecoration(
																									borderRadius: (redCount > 0) ? BorderRadius.only(topRight: Radius.circular(8)) : radiusAlone,
																									color: CupertinoTheme.of(context).primaryColor
																								),
																								padding: EdgeInsets.all(8),
																								margin: EdgeInsets.only(right: 16),
																								child: Text(
																									whiteCount.toString(),
																									style: TextStyle(
																										color: CupertinoTheme.of(context).scaffoldBackgroundColor
																									),
																									textAlign: TextAlign.center
																								)
																							)
																						]
																					),
																					onTap: () => _listController.animateTo((post) => post.id == persistentState.lastSeenPostId, alignment: 1.0),
																					onLongPress: scrollToBottom
																				)
																			);
																		}
																		else if ((persistentState.thread != null) && (_listController.lastVisibleIndex != persistentState.thread!.posts.length - 1)) {
																			return Align(
																				alignment: Alignment.bottomRight,
																				child: GestureDetector(
																					child: Container(
																						decoration: BoxDecoration(
																							borderRadius: radiusAlone,
																							color: CupertinoTheme.of(context).primaryColor
																						),
																						padding: EdgeInsets.all(8),
																						margin: EdgeInsets.only(right: 16),
																						child: Icon(Icons.vertical_align_bottom, color: CupertinoTheme.of(context).scaffoldBackgroundColor)
																					),
																					onTap: scrollToBottom
																				)
																			);
																		}
																		else {
																			return Container();
																		}
																	}
																),
																if (blocked) Container(
																	color: CupertinoTheme.of(context).scaffoldBackgroundColor,
																	child: Center(
																		child: CupertinoActivityIndicator()
																	)
																)
															]
														)
													)
												)
											)
										)
									)
								)
							),
							ReplyBox(
								key: context.read<GlobalKey<ReplyBoxState>>(),
								board: widget.thread.board,
								threadId: widget.thread.id,
								visible: showReplyBox,
								onReplyPosted: (receipt) {
									persistentState.savedTime = DateTime.now();
									persistentState.save();
									setState(() {
										showReplyBox = false;
									});
								},
								onRequestFocus: () {
									setState(() {
										showReplyBox = true;
									});
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
		_listController.dispose();
	}
}
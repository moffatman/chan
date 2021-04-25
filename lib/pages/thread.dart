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

	final _focusNode = FocusNode();
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
				await _listController.animateTo((post) => post.id == scrollToId, alignment: 1.0, duration: Duration(milliseconds: 1));
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

	@override
	Widget build(BuildContext context) {
		String title = persistentState.thread?.title ?? '/${widget.thread.board}/${widget.thread.id}';
		if (persistentState.thread?.isArchived ?? false) {
			title += ' (Archived)';
		}
		return Provider(
			create: (context) => GlobalKey<ReplyBoxState>(),
			child: Builder(
				builder: (context) => CupertinoPageScaffold(
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
											if (showReplyBox) {
												context.read<GlobalKey<ReplyBoxState>>().currentState!.shouldRequestFocusNow();
											}
											else {
												_focusNode.requestFocus();
											}
										});
									}
								)
							]
						)
					),
					child: Column(
						children: [
							Flexible(
								flex: 1,
								child: Navigator(
									key: _subNavigatorKey,
									initialRoute: '/',
									onGenerateRoute: (RouteSettings settings) => TransparentRoute(
										builder: (context) => RawKeyboardListener(
											autofocus: true,
											focusNode: _focusNode,
											onKey: (event) {
												if (event is RawKeyDownEvent) {
													if (event.logicalKey == LogicalKeyboardKey.keyG) {
														final nextPostWithImage = persistentState.thread?.posts.skip(_listController.firstVisibleIndex).firstWhere((p) => p.attachment != null, orElse: () {
															return persistentState.thread!.posts.take(_listController.firstVisibleIndex).firstWhere((p) => p.attachment != null);
														});
														if (nextPostWithImage != null) {
															_showGallery(initialAttachment: nextPostWithImage.attachment);
														}
													}
												}
											},
											child: Stack(
												fit: StackFit.expand,
												children: [
													ChangeNotifierProvider<PostSpanZoneData>.value(
														value: zone,
														child: RefreshableList<Post>(
															id: '/${widget.thread.board}/${widget.thread.id}',
															updateDisabledText: persistentState.thread?.isArchived == true ? 'Archived' : null,
															autoUpdateDuration: const Duration(seconds: 60),
															initialList: persistentState.thread?.posts,
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
																if (_thread.posts.length != (persistentState.thread?.posts.length ?? 0)) {
																	persistentState.thread = _thread;
																	zone.threadPosts = _thread.posts;
																	if (firstLoad) await _blockAndScrollToPostIfNeeded();
																	await persistentState.save();
																	setState(() {});
																	Future.delayed(Duration(milliseconds: 100), () {
																		if (persistentState.thread != null && !_unnaturallyScrolling) {
																			persistentState.lastSeenPostId = max(persistentState.lastSeenPostId ?? 0, persistentState.thread!.posts[_listController.lastVisibleIndex].id);	
																			persistentState.save();
																			setState(() {});
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
													),
													StreamBuilder(
														stream: _listController.slowScrollUpdates,
														builder: (context, a) {
															if ((persistentState.unseenReplyCount ?? 0) > 0) {
																return SafeArea(
																	child: Align(
																		alignment: Alignment.bottomRight,
																		child: Container(
																			decoration: BoxDecoration(
																				borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
																				color: Colors.red
																			),
																			padding: EdgeInsets.all(4),
																			margin: EdgeInsets.only(right: 16),
																			child: Text(persistentState.unseenReplyCount.toString())
																		)
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
							),
							Visibility(
								visible: showReplyBox,
								maintainState: true,
								child: SafeArea(
									top: false,
									child: ReplyBox(
										key: context.read<GlobalKey<ReplyBoxState>>(),
										thread: widget.thread,
										threadState: persistentState,
										onReplyPosted: () {
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
								)
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
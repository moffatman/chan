import 'package:auto_size_text/auto_size_text.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/models/board.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:chan/widgets/reply_box.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';

import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class ThreadPage extends StatefulWidget {
	final ImageboardBoard board;
	final int id;
	final int? initialPostId;
	final bool initiallyUseArchive;

	ThreadPage({
		required this.board,
		required this.id,
		this.initialPostId,
		this.initiallyUseArchive = false
	});

	@override
	createState() => _ThreadPageState();
}

class _ThreadPageState extends State<ThreadPage> with TickerProviderStateMixin {
	late PersistentThreadState persistentState;
	bool showReplyBox = false;

	final _focusNode = FocusNode();
	final _listController = RefreshableListController<Post>();

	@override
	void initState() {
		super.initState();
		persistentState = Persistence.getThreadState(widget.board.name, widget.id);
		persistentState.useArchive |= widget.initiallyUseArchive;
		persistentState.save();
		_listController.slowScrollUpdates.listen((_) {
			persistentState.lastSeenPostId = _listController.findNextMatch((_) => true)?.id;
			persistentState.save();
		});
		final int? scrollToId = widget.initialPostId ?? persistentState.lastSeenPostId;
		if (persistentState.thread != null && scrollToId != null) {
			Future.delayed(Duration(milliseconds: 50), () => _listController.scrollToFirstMatching((post) => post.id == scrollToId));
		}
	}

	@override
	void didUpdateWidget(ThreadPage old) {
		super.didUpdateWidget(old);
		if (widget.board != old.board || widget.id != old.id) {
			persistentState = Persistence.getThreadState(widget.board.name, widget.id);
			persistentState.useArchive |= widget.initiallyUseArchive;
			persistentState.save();
			setState(() {});
		}
	}

	void _showGallery({bool initiallyShowChrome = true, Attachment? initialAttachment}) {
		showGallery(
			context: context,
			attachments: persistentState.thread!.posts.where((_) => _.attachment != null).map((_) => _.attachment!).toList(),
			initiallyShowChrome: initiallyShowChrome,
			initialAttachment: initialAttachment,
			onChange: (attachment) {
				_listController.scrollToFirstMatching((post) {
					return post.attachment == attachment;
				});
			},
			semanticParentIds: []
		);
	}

	@override
	Widget build(BuildContext context) {
		final title = persistentState.thread?.title ?? '/${widget.board.name}/${widget.id}';
		return Provider(
			create: (context) => GlobalKey<ReplyBoxState>(),
			child: Builder(
				builder: (context) => CupertinoPageScaffold(
					navigationBar: CupertinoNavigationBar(
						transitionBetweenRoutes: false,
						middle: AutoSizeText(title),
						trailing: CupertinoButton(
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
					),
					child: Column(
						children: [
							Flexible(
								flex: 1,
								child: Navigator(
									initialRoute: '/',
									onGenerateRoute: (RouteSettings settings) => TransparentRoute(
										builder: (context) => RawKeyboardListener(
											autofocus: true,
											focusNode: _focusNode,
											onKey: (event) {
												if (event is RawKeyDownEvent) {
													if (event.logicalKey == LogicalKeyboardKey.keyG) {
														final nextPostWithImage = _listController.findNextMatch((post) => post.attachment != null);
														if (nextPostWithImage != null) {
															_showGallery(initialAttachment: nextPostWithImage.attachment);
														}
													}
												}
											},
											child: RefreshableList<Post>(
												id: '/${widget.board.name}/${widget.id}',
												updateDisabledText: persistentState.thread?.isArchived == true ? 'Archived' : null,
												autoUpdateDuration: const Duration(seconds: 60),
												initialList: persistentState.thread?.posts,
												additionalProviders: [
													Provider<PersistentThreadState>.value(value: persistentState)
												],
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
														await context.read<ImageboardSite>().getThreadFromArchive(widget.board.name, widget.id) :
														await context.read<ImageboardSite>().getThread(widget.board.name, widget.id);
													final int? scrollToId = widget.initialPostId ?? persistentState.lastSeenPostId;
													if (persistentState.thread == null && scrollToId != null) {
														Future.delayed(Duration(milliseconds: 50), () => _listController.scrollToFirstMatching((post) => post.id == scrollToId));
													}
													persistentState.thread = _thread;
													await persistentState.save();
													setState(() {});
													return _thread.posts;
												},
												controller: _listController,
												itemBuilder: (context, post) {
													return Provider.value(
														value: post,
														child: PostRow(
															onThumbnailTap: (attachment, {Object? tag}) {
																_showGallery(initialAttachment: attachment);
															},
															onNeedScrollToAnotherPost: (post) => _listController.scrollToFirstMatching((val) => val == post)
														)
													);
												},
												filteredItemBuilder: (context, post, resetPage) {
													return Provider.value(
														value: post,
														child: PostRow(
															onThumbnailTap: (attachment, {Object? tag}) {
																_showGallery(initialAttachment: attachment);
															},
															onTap: () {
																resetPage();
																Future.delayed(Duration(milliseconds: 250), () => _listController.scrollToFirstMatching((val) => val == post));
															}
														)
													);
												},
												filterHint: 'Search in thread'
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
										board: widget.board,
										threadId: widget.id,
										threadState: persistentState,
										onReplyPosted: () {
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
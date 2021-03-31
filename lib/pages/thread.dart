import 'package:auto_size_text/auto_size_text.dart';
import 'package:chan/models/attachment.dart';
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

	ThreadPage({
		required this.board,
		required this.id,
		this.initialPostId
	});

	@override
	createState() => _ThreadPageState();
}

class _ThreadPageState extends State<ThreadPage> with TickerProviderStateMixin {
	PersistentThreadState? persistentState;
	Thread? thread;
	bool initialized = false;
	bool showReplyBox = false;

	final _focusNode = FocusNode();
	final _listController = RefreshableListController<Post>();

	@override
	void initState() {
		super.initState();
		_getThreadState();
		_listController.slowScrollUpdates.listen((_) {
			persistentState?.lastSeenPostId = _listController.findNextMatch((_) => true)?.id;
			persistentState?.save();
		});
	}

	@override
	void didUpdateWidget(ThreadPage old) {
		super.didUpdateWidget(old);
		if (widget.board != old.board || widget.id != old.id) {
			setState(() {
				thread = null;
				persistentState = null;
			});
			_getThreadState();
		}
	}

	Future<void> _getThreadState() async {
		persistentState = await Persistence.getThreadState(widget.board.name, widget.id);
		setState(() {});
	}

	void _showGallery({bool initiallyShowChrome = true, Attachment? initialAttachment}) {
		showGallery(
			context: context,
			attachments: thread!.posts.where((_) => _.attachment != null).map((_) => _.attachment!).toList(),
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
		final title = thread?.title ?? '/${widget.board.name}/${widget.id}';
		return CupertinoPageScaffold(
			navigationBar: CupertinoNavigationBar(
				middle: AutoSizeText(title),
				trailing: CupertinoButton(
					padding: EdgeInsets.zero,
					child: Icon(Icons.reply),
					onPressed: () {
						setState(() {
							showReplyBox = !showReplyBox;
							if (showReplyBox) {
								replyBoxKey.currentState!.shouldRequestFocusNow();
							}
							else {
								_focusNode.requestFocus();
							}
						});
					}
				)
			),
			child: (persistentState == null) ? Center(
				child: CircularProgressIndicator()
				): Column(
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
										autoUpdateDuration: const Duration(seconds: 60),
										additionalProviders: [
											Provider<PersistentThreadState>.value(value: persistentState!)
										],
										listUpdater: () async {
											final _thread = await context.read<ImageboardSite>().getThread(widget.board.name, widget.id);
											final int? scrollToId = widget.initialPostId ?? persistentState?.lastSeenPostId;
											if (thread == null && scrollToId != null) {
												Future.delayed(Duration(milliseconds: 50), () => _listController.scrollToFirstMatching((post) => post.id == scrollToId));
											}
											setState(() {
												thread = _thread;
											});
											return _thread.posts;
										},
										controller: _listController,
										itemBuilder: (context, post) {
											return Provider.value(
												value: post,
												child: PostRow(
													onThumbnailTap: (attachment, {Object? tag}) {
														_showGallery(initialAttachment: attachment);
													}
												)
											);
										},
										filteredItemBuilder: (context, post, resetPage) {
											return GestureDetector(
												child: Provider.value(
													value: post,
													child: PostRow(
														onThumbnailTap: (attachment, {Object? tag}) {
															_showGallery(initialAttachment: attachment);
														}
													)
												),
												onTap: () {
													resetPage();
													Future.delayed(Duration(milliseconds: 250), () => _listController.scrollToFirstMatching((val) => val == post));
												}
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
						child: ReplyBox(
							key: replyBoxKey,
							board: widget.board,
							threadId: widget.id,
							threadState: persistentState!,
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
				]
			)
		);
	}

	@override
	void dispose() {
		super.dispose();
		_listController.dispose();
	}
}
import 'package:chan/models/attachment.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/provider_list.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';

import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class ThreadPage extends StatefulWidget {
	final String board;
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

class _ThreadPageState extends State<ThreadPage> {
	Thread? thread;

	FocusNode _focusNode = FocusNode();
	ProviderListController<Post> _listController = ProviderListController();

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
		final title = thread?.title ?? '/${widget.board}/${widget.id}';
		return CupertinoPageScaffold(
			navigationBar: CupertinoNavigationBar(
				middle: Text(title)
			),
			child: RawKeyboardListener(
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
				child: ProviderList<Post>(
					id: '/${widget.board}/${widget.id}',
					listUpdater: () async {
						final _thread = await context.read<ImageboardSite>().getThread(widget.board, widget.id);
						if (thread == null && widget.initialPostId != null) {
							Future.delayed(Duration(milliseconds: 50), () => _listController.scrollToFirstMatching((post) => post.id == widget.initialPostId));
						}
						setState(() {
							thread = _thread;
						});
						return _thread.posts;
					},
					controller: _listController,
					builder: (context, post) {
						return Provider.value(
							value: post,
							child: PostRow(
								onThumbnailTap: (attachment, {Object? tag}) {
									_showGallery(initialAttachment: attachment);
								}
							)
						);
					},
					searchBuilder: (context, post, resetPage) {
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
					searchHint: 'Search in thread'
				)
			)
		);
	}
}
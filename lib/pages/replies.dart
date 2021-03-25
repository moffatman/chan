import 'dart:math';

import 'package:chan/models/post.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/widgets/post_expander.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RepliesPage extends StatefulWidget {
	final List<Post> threadPosts;
	final Post repliedToPost;
	final List<int> parentIds;

	RepliesPage({
		required this.threadPosts,
		required this.repliedToPost,
		required this.parentIds
	});

	@override
	createState() => _RepliesPageState();
}

class _RepliesPageState extends State<RepliesPage> {
	late final ScrollController _controller;

	@override
	void initState() {
		super.initState();
		_controller = ScrollController(initialScrollOffset: 150.0 + 100.0 * (widget.repliedToPost.replyIds.length - 1));
	}

	@override
	Widget build(BuildContext context) {
		final replies = widget.threadPosts.where((post) => widget.repliedToPost.replyIds.contains(post.id)).toList();
		final newParentIds = widget.parentIds.followedBy([widget.repliedToPost.id]).toList();
		return Stack(
			fit: StackFit.expand,
			children: [
				Container(
					color: Colors.black38
				),
				SafeArea(
					child: Listener(
						onPointerUp: (event) {
							final overscrollTop = _controller.position.minScrollExtent - _controller.position.pixels;
							final overscrollBottom = _controller.position.pixels - _controller.position.maxScrollExtent;
							if (max(overscrollTop, overscrollBottom) > 50) {
								Navigator.of(context).pop();
							}
						},
						child: MultiProvider(
							providers: [
								Provider.value(value: widget.threadPosts),
								ChangeNotifierProvider(create: (_) => ExpandingPostZone(newParentIds))
							],
							child: SingleChildScrollView(
								controller: _controller,
								reverse: true,
								physics: AlwaysScrollableScrollPhysics(),
								child: Column(
									mainAxisSize: MainAxisSize.max,
									mainAxisAlignment: MainAxisAlignment.end,
									children: replies.map((reply) {
										return Provider.value(
											value: reply,
											child: PostRow(
												onThumbnailTap: (attachment, {Object? tag}) {
													showGallery(
														context: context,
														attachments: [attachment],
														semanticParentIds: newParentIds
													);
												}
											)
										);
									}).toList()
								)
							)
						)
					)
				)
			]
		);
	}
}
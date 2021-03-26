import 'dart:math';

import 'package:chan/models/post.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/widgets/post_expander.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PostsPage extends StatefulWidget {
	final List<Post> threadPosts;
	final List<int> postsIdsToShow;
	final List<int> parentIds;

	PostsPage({
		required this.threadPosts,
		required this.postsIdsToShow,
		required this.parentIds
	});

	@override
	createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> {
	late final ScrollController _controller;

	@override
	void initState() {
		super.initState();
		_controller = ScrollController(initialScrollOffset: -150.0 - 100.0 * (widget.postsIdsToShow.length - 1));
	}

	@override
	Widget build(BuildContext context) {
		final replies = widget.threadPosts.where((post) => widget.postsIdsToShow.contains(post.id)).toList();
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
								ChangeNotifierProvider(create: (_) => ExpandingPostZone(widget.parentIds))
							],
							child: CustomScrollView(
								controller: _controller,
								physics: AlwaysScrollableScrollPhysics(),
								slivers: [
									SliverFillRemaining(
										hasScrollBody: false,
										child: Column(
											mainAxisSize: MainAxisSize.max,
											mainAxisAlignment: MainAxisAlignment.center,
											children: replies.map((reply) {
												return Provider.value(
													value: reply,
													child: PostRow(
														onThumbnailTap: (attachment, {Object? tag}) {
															showGallery(
																context: context,
																attachments: [attachment],
																semanticParentIds: widget.parentIds
															);
														}
													)
												);
											}).toList()
										)
									)
								]
							)
						)
					)
				)
			]
		);
	}

	@override
	void dispose() {
		super.dispose();
		_controller.dispose();
	}
}
import 'package:chan/models/post.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/widgets/post_expander.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chan/pages/overscroll_modal.dart';

class PostsPage extends StatelessWidget {
	final List<Post> threadPosts;
	final List<int> postsIdsToShow;
	final List<int> parentIds;
	final void Function(Post post)? onTapPost;

	PostsPage({
		required this.threadPosts,
		required this.postsIdsToShow,
		required this.parentIds,
		this.onTapPost
	});

	@override
	Widget build(BuildContext context) {
		final replies = threadPosts.where((post) => postsIdsToShow.contains(post.id)).toList();
		return OverscrollModalPage(
			child: MultiProvider(
				providers: [
					Provider.value(value: threadPosts),
					ChangeNotifierProvider(create: (_) => ExpandingPostZone(parentIds))
				],
				child: Column(
					children: replies.map((reply) {
						return GestureDetector(
							child: Provider.value(
								value: reply,
								child: PostRow(
									onThumbnailTap: (attachment, {Object? tag}) {
										showGallery(
											context: context,
											attachments: [attachment],
											semanticParentIds: parentIds
										);
									},
									onNeedScrollToAnotherPost: (post) {
										Navigator.of(context).pop();
										onTapPost!(post);
									},
								)
							),
							onTap: () {
								if (onTapPost != null) {
									Navigator.of(context).pop();
									onTapPost!(reply);
								}
							}
						);
					}).toList()
				)
			),
			heightEstimate: 100.0 * (postsIdsToShow.length - 1)
		);
	}
}
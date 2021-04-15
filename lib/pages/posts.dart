import 'package:chan/models/post.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chan/pages/overscroll_modal.dart';

class PostsPage extends StatelessWidget {
	final PostSpanZoneData zone;
	final List<int> postsIdsToShow;
	final void Function(Post post)? onTapPost;

	PostsPage({
		required this.postsIdsToShow,
		required this.zone,
		this.onTapPost,
	});

	@override
	Widget build(BuildContext context) {
		final replies = [];
		for (final id in postsIdsToShow) {
			final matchingPost = zone.threadPosts.where((p) => p.id == id);
			if (matchingPost.isNotEmpty) {
				replies.add(matchingPost.first);
			}
			else {
				final archivedPost = zone.postFromArchive(id);
				if (archivedPost != null) {
					replies.add(archivedPost);
				}
			}
		}
		return OverscrollModalPage(
			child: ChangeNotifierProvider.value(
				value: zone,
				child: Builder(
					builder: (ctx) => Column(
						children: replies.map((reply) {
							return PostRow(
								post: reply,
								onThumbnailTap: (attachment) {
									showGallery(
										context: context,
										attachments: [attachment],
										semanticParentIds: ctx.read<PostSpanZoneData>().stackIds
									);
								},
								onNeedScrollToAnotherPost: (post) {
									Navigator.of(context).pop();
									onTapPost!(post);
								},
								onTap: () {
									if (onTapPost != null) {
										Navigator.of(context).pop();
										onTapPost!(reply);
									}
								}	
							);
						}).toList()
					)
				)
			),
			heightEstimate: 100.0 * (postsIdsToShow.length - 1)
		);
	}
}
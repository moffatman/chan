import 'package:chan/models/post.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chan/pages/overscroll_modal.dart';
import 'package:chan/util.dart';

class PostsPage extends StatelessWidget {
	final PostSpanZoneData zone;
	final List<int> postsIdsToShow;

	PostsPage({
		required this.postsIdsToShow,
		required this.zone
	});

	@override
	Widget build(BuildContext context) {
		final List<Post> replies = [];
		for (final id in postsIdsToShow) {
			final matchingPost = zone.threadPosts.tryFirstWhere((p) => p.id == id);
			if (matchingPost != null) {
				replies.add(matchingPost);
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
					builder: (ctx) => ListView(
						shrinkWrap: true,
						children: replies.map((reply) {
							return PostRow(
								post: reply,
								onThumbnailTap: (attachment) {
									showGallery(
										context: context,
										attachments: [attachment],
										semanticParentIds: ctx.read<PostSpanZoneData>().stackIds
									);
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
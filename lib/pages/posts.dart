import 'package:chan/models/attachment.dart';
import 'package:chan/models/post.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chan/pages/overscroll_modal.dart';
import 'package:chan/util.dart';

class PostsPage extends StatefulWidget {
	final PostSpanZoneData zone;
	final List<int> postsIdsToShow;

	PostsPage({
		required this.postsIdsToShow,
		required this.zone
	});

	@override
	createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> {
	Map<Post, BuildContext> postContexts = Map();

	@override
	void didUpdateWidget(PostsPage old) {
		super.didUpdateWidget(old);
		if (widget.zone != old.zone || widget.postsIdsToShow != old.postsIdsToShow) {
			postContexts = {};
		}
	}

	@override
	Widget build(BuildContext context) {
		final List<Post> replies = [];
		for (final id in widget.postsIdsToShow) {
			final matchingPost = widget.zone.thread.posts.tryFirstWhere((p) => p.id == id);
			if (matchingPost != null) {
				replies.add(matchingPost);
			}
			else {
				final archivedPost = widget.zone.postFromArchive(id);
				if (archivedPost != null) {
					replies.add(archivedPost);
				}
			}
		}
		final attachments = replies.expand<Attachment>((a) => a.attachment == null ? [] : [a.attachment!]).toList();
		return OverscrollModalPage(
			child: ChangeNotifierProvider.value(
				value: widget.zone,
				child: Builder(
					builder: (ctx) => ListView(
						shrinkWrap: true,
						physics: NeverScrollableScrollPhysics(),
						children: replies.map((reply) {
							return Builder(
								builder: (context) {
									postContexts[reply] = context;
									return PostRow(
										post: reply,
										onThumbnailTap: (attachment) {
											showGallery(
												context: context,
												attachments: attachments,
												initialAttachment: attachment,
												semanticParentIds: ctx.read<PostSpanZoneData>().stackIds,
												onChange: (attachment) {
													final match = postContexts.entries.tryFirstWhere((p) =>  p.key.attachment == attachment);
													if (match != null) {
														Scrollable.ensureVisible(match.value, alignment: 0.5, duration: const Duration(milliseconds: 200));
													}
												}
											);
										}
									);
								}
							);
						}).toList()
					)
				)
			),
			heightEstimate: 100.0 * (widget.postsIdsToShow.length - 1)
		);
	}
}
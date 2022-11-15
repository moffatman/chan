import 'package:chan/models/attachment.dart';
import 'package:chan/models/post.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chan/pages/overscroll_modal.dart';
import 'package:chan/util.dart';

class PostsPage extends StatefulWidget {
	final PostSpanZoneData zone;
	final int? postIdForBackground;
	final List<int> postsIdsToShow;
	final ValueChanged<Post>? onTap;

	const PostsPage({
		required this.postsIdsToShow,
		this.postIdForBackground,
		required this.zone,
		this.onTap,
		Key? key
	}) : super(key: key);

	@override
	createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> {
	Map<Post, BuildContext> postContexts = {};

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
		for (final method in widget.zone.postSortingMethods) {
			mergeSort<Post>(replies, compare: method);
		}
		final attachments = replies.expand<Attachment>((a) => a.attachments).toList();
		final postForBackground = widget.postIdForBackground == null ? null : widget.zone.thread.posts.tryFirstWhere((p) => p.id == widget.postIdForBackground);
		return ChangeNotifierProvider.value(
			value: widget.zone,
			child: OverscrollModalPage(
				background: postForBackground == null ? null : PostRow(
					post: postForBackground,
					isSelected: true
				),
				heightEstimate: 100.0 * (widget.postsIdsToShow.length - 1),
				child: ListView.separated(
					shrinkWrap: true,
					primary: false,
					physics: const NeverScrollableScrollPhysics(),
					separatorBuilder: (context, i) => Divider(
						thickness: 1,
						height: 0,
						color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2)
					),
					itemCount: replies.length,
					itemBuilder: (context, i) {
						final reply = replies[i];
						postContexts[reply] = context;
						return PostRow(
							post: reply,
							onTap: widget.onTap == null ? null : () => widget.onTap!(reply),
							onThumbnailTap: (attachment) {
								showGallery(
									context: context,
									attachments: attachments,
									replyCounts: {
										for (final reply in replies)
											for (final attachment in reply.attachments)
												attachment: reply.replyIds.length
									},
									initialAttachment: attachment,
									semanticParentIds: context.read<PostSpanZoneData>().stackIds,
									onChange: (attachment) {
										final match = postContexts.entries.tryFirstWhere((p) =>  p.key.attachments.contains(attachment));
										if (match != null) {
											Scrollable.ensureVisible(match.value, alignment: 0.5, duration: const Duration(milliseconds: 200));
										}
									}
								);
							}
						);
					}
				)
			)
		);
	}
}
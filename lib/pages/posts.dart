import 'dart:math';

import 'package:chan/models/attachment.dart';
import 'package:chan/models/post.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chan/pages/overscroll_modal.dart';

class PostsPage extends StatelessWidget {
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
	Widget build(BuildContext context) {
		final List<Post> replies = [];
		for (final id in postsIdsToShow) {
			final matchingPost = zone.thread.posts.tryFirstWhere((p) => p.id == id);
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
		for (final method in zone.postSortingMethods) {
			mergeSort<Post>(replies, compare: method);
		}
		final attachments = replies.expand<Attachment>((a) => a.attachments).toList();
		final postForBackground = postIdForBackground == null ? null : zone.thread.posts.tryFirstWhere((p) => p.id == postIdForBackground);
		return ChangeNotifierProvider.value(
			value: zone,
			child: OverscrollModalPage.sliver(
				background: postForBackground == null ? null : PostRow(
					post: postForBackground,
					isSelected: true
				),
				heightEstimate: 100.0 * (postsIdsToShow.length - 1),
				sliver: SliverList(
					delegate: SliverChildBuilderDelegate(
						addRepaintBoundaries: false,
						childCount: max(0, (replies.length * 2) - 1),
						(context, j) {
							if (j % 2 == 0) {
								final i = j ~/ 2;
								final reply = replies[i];
								return PostRow(
									post: reply,
									onTap: onTap == null ? null : () => onTap!(reply),
									onDoubleTap: zone.onNeedScrollToPost == null ? null : () => zone.onNeedScrollToPost!(reply),
									onThumbnailTap: (attachment) {
										showGallery(
											context: context,
											attachments: attachments,
											replyCounts: {
												for (final reply in replies)
													for (final attachment in reply.attachments)
														attachment: reply.replyIds.length
											},
											isAttachmentAlreadyDownloaded: zone.threadState?.isAttachmentDownloaded,
											onAttachmentDownload: zone.threadState?.didDownloadAttachment,
											initialAttachment: attachment,
											semanticParentIds: context.read<PostSpanZoneData>().stackIds,
											onChange: (attachment) {
												Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 200));
											}
										);
									}
								);
							}
							return Divider(
								thickness: 1,
								height: 0,
								color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2)
							);
						}
					)
				)
			)
		);
	}
}
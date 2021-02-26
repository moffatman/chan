import 'package:chan/models/post_element.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/post_expander.dart';
import 'package:flutter/material.dart';

import 'package:timeago/timeago.dart' as timeago;

import 'package:chan/models/post.dart';
import 'package:chan/models/attachment.dart';

import 'package:provider/provider.dart';
import 'package:chan/widgets/util.dart';
class PostRow extends StatelessWidget {
	final ValueChanged<Attachment>? onThumbnailTap;

	const PostRow({
		this.onThumbnailTap
	});

	@override
	Widget build(BuildContext context) {
		final post = context.watch<Post>();
		final openedFromPostId = context.watchOrNull<ParentPost>()?.id;
		return Container(
			decoration: BoxDecoration(border: (openedFromPostId != null) ? Border.all(width: 0, color: Theme.of(context).colorScheme.onBackground) : Border(bottom: BorderSide(width: 0, color: Theme.of(context).colorScheme.onBackground))),
			child: Row(
				crossAxisAlignment: CrossAxisAlignment.start,
				mainAxisAlignment: MainAxisAlignment.start,
				mainAxisSize: MainAxisSize.max,
				children: [
					post.attachment == null ? SizedBox(width: 0, height: 0) : GestureDetector(
						child: AttachmentThumbnail(
							attachment: post.attachment!
						),
						onTap: () {
							onThumbnailTap?.call(post.attachment!);
						}
					),
					Expanded(
						child: Container(
							padding: EdgeInsets.all(8),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								mainAxisSize: MainAxisSize.min,
								children: [
									ChangeNotifierProvider<ExpandingPostZone>(
										create: (_) => ExpandingPostZone(),
										child: Wrap(
											spacing: 8,
											runSpacing: 3,
											children: [
												Text(post.id.toString(), style: TextStyle(color: Colors.grey)),
												Text(timeago.format(post.time), style: TextStyle(color: Theme.of(context).colorScheme.onBackground)),
												...post.replies.map((reply) => QuoteLinkElement(reply.id)),
												...post.replies.map((reply) => ExpandingPost(post: reply, parentId: post.id))
											]
										)
									),
									ChangeNotifierProvider<ExpandingPostZone>(
										create: (_) => ExpandingPostZone(),
										child: Wrap(
											children: post.elements.expand((element) {
												if (element is QuoteLinkElement) {
													return [element, ExpandingPost(post: context.watch<List<Post>>().firstWhere((p) => p.id == element.id), parentId: post.id)];
												}
												else {
													return [element];
												}
											}).toList()
										)
									)
								]
							)
						)
					)
				]
			)
		);
	}
}
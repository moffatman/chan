import 'package:chan/models/post_element.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/post_expander.dart';
import 'package:flutter/material.dart';

import 'package:timeago/timeago.dart' as timeago;

import 'package:chan/models/post.dart';
import 'package:chan/models/attachment.dart';

import 'package:provider/provider.dart';
import 'package:chan/widgets/util.dart';

import 'dart:math';

class PostRow extends StatelessWidget {
	final void Function(Attachment, {Object tag})? onThumbnailTap;

	const PostRow({
		this.onThumbnailTap
	});

	@override
	Widget build(BuildContext context) {
		final post = context.watch<Post>();
		final openedFromPostId = context.watchOrNull<ExpandingPostZone>()?.parentId;
		final randomHeroTag = Random().nextDouble().toString();
		return Container(
			padding: EdgeInsets.all(8),
			decoration: BoxDecoration(border: (openedFromPostId != null) ? Border.all(width: 0) : Border(bottom: BorderSide(width: 0))),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					ChangeNotifierProvider<ExpandingPostZone>(
						create: (_) => ExpandingPostZone(post.id),
						child: Builder(
							builder: (ctx) => Text.rich(
								TextSpan(
									children: [
										TextSpan(
											text: post.name,
											style: TextStyle(fontWeight: FontWeight.w600)
										),
										TextSpan(
											text: post.id.toString(),
											style: TextStyle(color: Colors.grey)
										),
										TextSpan(
											text: timeago.format(post.time)
										),
										...post.replyIds.map((id) => PostQuoteLinkSpan(id).build(ctx)),
										...post.replyIds.map((id) => WidgetSpan(
											child: ExpandingPost(id)
										))
									].expand((span) => [TextSpan(text: ' '), span]).skip(1).toList()
								)
							)
						)
					),
					Row(
						crossAxisAlignment: CrossAxisAlignment.start,
						mainAxisAlignment: MainAxisAlignment.start,
						mainAxisSize: MainAxisSize.max,
						children: [
							post.attachment == null ? SizedBox(width: 0, height: 0) : GestureDetector(
								child: AttachmentThumbnail(
									attachment: post.attachment!,
									heroTag: (openedFromPostId == null) ? null : randomHeroTag
								),
								onTap: () {
									onThumbnailTap?.call(post.attachment!, tag: randomHeroTag);
								}
							),
							Expanded(
								child: Container(
									padding: EdgeInsets.all(8),
									child: ChangeNotifierProvider<ExpandingPostZone>(
										create: (_) => ExpandingPostZone(post.id),
										child: Builder(
											builder: (ctx) => Text.rich(post.span.build(ctx))
										)
									)
								)
							)
						]
					),
				]
			)
		);
	}
}
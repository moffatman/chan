import 'package:chan/models/post_element.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/post_expander.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
		final parentIds = context.watchOrNull<ExpandingPostZone>()?.parentIds ?? [];
		final randomHeroTag = Random().nextDouble().toString();
		return Container(
			padding: EdgeInsets.only(left: 8, right: 8),
			decoration: BoxDecoration(
				border: parentIds.isNotEmpty ? Border.all(width: 0) : null,
				color: CupertinoTheme.of(context).scaffoldBackgroundColor
			),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					ChangeNotifierProvider<ExpandingPostZone>(
						create: (_) => ExpandingPostZone(parentIds.followedBy([post.id]).toList()),
						child: Builder(
							builder: (ctx) => DefaultTextStyle(
								child: Text.rich(
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
												text: formatTime(post.time)
											),
											...post.replyIds.map((id) => PostQuoteLinkSpan(id).build(ctx)),
											...post.replyIds.map((id) => WidgetSpan(
												child: ExpandingPost(id)
											))
										].expand((span) => [TextSpan(text: ' '), span]).skip(1).toList()
									)
								),
								style: DefaultTextStyle.of(context).style.copyWith(fontSize: 14)
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
									hero: AttachmentSemanticLocation(
										attachment: post.attachment!,
										semanticParents: parentIds
									)
								),
								onTap: () {
									onThumbnailTap?.call(post.attachment!, tag: randomHeroTag);
								}
							),
							Expanded(
								child: Container(
									padding: EdgeInsets.all(8),
									child: ChangeNotifierProvider<ExpandingPostZone>(
										create: (_) => ExpandingPostZone(parentIds.followedBy([post.id]).toList()),
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
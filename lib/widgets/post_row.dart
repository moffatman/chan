import 'package:chan/models/post_element.dart';
import 'package:chan/pages/posts.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/post_expander.dart';
import 'package:chan/widgets/reply_box.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
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
		final threadPosts = context.watch<List<Post>>();
		final parentIds = context.watchOrNull<ExpandingPostZone>()?.parentIds ?? [];
		final randomHeroTag = Random().nextDouble().toString();
		final settings = context.watch<Settings>();
		return Container(
			padding: EdgeInsets.all(8),
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
												style: TextStyle(color: Colors.grey),
												recognizer: TapGestureRecognizer()..onTap = () {
													replyBoxKey.currentState?.onTapPostId(post.id);
												}
											),
											TextSpan(
												text: formatTime(post.time)
											),
											if (!settings.useTouchLayout) ...[
												...post.replyIds.map((id) => PostQuoteLinkSpan(id).build(ctx)),
												...post.replyIds.map((id) => WidgetSpan(
													child: ExpandingPost(id)
												))
											]
										].expand((span) => [TextSpan(text: ' '), span]).skip(1).toList()
									)
								),
								style: DefaultTextStyle.of(context).style.copyWith(fontSize: 14)
							)
						)
					),
					IntrinsicHeight(
						child: Row(
							crossAxisAlignment: CrossAxisAlignment.stretch,
							mainAxisAlignment: MainAxisAlignment.start,
							mainAxisSize: MainAxisSize.max,
							children: [
								if (post.attachment != null) Column(
									mainAxisSize: MainAxisSize.min,
									children: [
										GestureDetector(
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
									]
								),
								Expanded(
									child: Container(
										padding: EdgeInsets.all(8),
										child: Stack(
											fit: StackFit.passthrough,
											children: [
												ChangeNotifierProvider<ExpandingPostZone>(
													create: (_) => ExpandingPostZone(parentIds.followedBy([post.id]).toList()),
													child: Builder(
														builder: (ctx) => Text.rich(
															TextSpan(
																children: [
																	post.span.build(ctx),
																	// Placeholder to guarantee the stacked reply button is not on top of text
																	if (settings.useTouchLayout && post.replyIds.isNotEmpty) TextSpan(
																		text: List.filled(post.replyIds.length.toString().length + 3, '1').join(),
																		style: TextStyle(color: CupertinoTheme.of(context).scaffoldBackgroundColor)
																	)
																]
															)
														)
													)
												),
												if (settings.useTouchLayout && post.replyIds.isNotEmpty) Positioned.fill(
													child: Align(
														alignment: Alignment.bottomRight,
														child: CupertinoButton(
															alignment: Alignment.bottomRight,
															padding: EdgeInsets.zero,
															child: Row(
																mainAxisSize: MainAxisSize.min,
																children: [
																	Icon(
																		Icons.reply_rounded,
																		color: Colors.red,
																		size: 14
																	),
																	SizedBox(width: 4),
																	Text(
																		post.replyIds.length.toString(),
																		style: TextStyle(
																			color: Colors.red,
																			fontWeight: FontWeight.bold,
																		)
																	)
																]
															),
															onPressed: () {
																Navigator.of(context).push(
																	TransparentRoute(
																		builder: (ctx) => PostsPage(
																			threadPosts: threadPosts,
																			postsIdsToShow: post.replyIds,
																			parentIds: parentIds.followedBy([post.id]).toList()
																		)
																	)
																);
															}
														)
													)
												)
											]
										)
									)
								)
							]
						)
					)
				]
			)
		);
	}
}
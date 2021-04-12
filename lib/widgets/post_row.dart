import 'package:chan/widgets/post_spans.dart';
import 'package:chan/models/search.dart';
import 'package:chan/pages/posts.dart';
import 'package:chan/pages/search_query.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/context_menu.dart';
import 'package:chan/widgets/thread_spans.dart';
import 'package:chan/widgets/reply_box.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:share/share.dart';
import 'package:cupertino_back_gesture/src/cupertino_page_route.dart' as cpr;

import 'package:chan/models/post.dart';
import 'package:chan/models/attachment.dart';

import 'package:provider/provider.dart';
import 'package:chan/widgets/util.dart';

class PostRow extends StatelessWidget {
	final Post post;
	final ValueChanged<Attachment>? onThumbnailTap;
	final void Function(Post post)? onNeedScrollToAnotherPost;
	final VoidCallback? onTap;
	final bool showCrossThreadLabel;
	final bool allowTappingLinks;

	const PostRow({
		required this.post,
		this.onTap,
		this.onThumbnailTap,
		this.onNeedScrollToAnotherPost,
		this.showCrossThreadLabel = true,
		this.allowTappingLinks = true
	});

	@override
	Widget build(BuildContext context) {
		final site = context.watch<ImageboardSite>();
		final zone = context.watchOrNull<PostSpanZoneData>() ?? PostSpanRootZoneData(
			board: post.board,
			threadId: post.threadId,
			site: site,
			threadPosts: [post]
		);
		final settings = context.watch<EffectiveSettings>();
		final isYou = zone.threadState?.youIds.contains(post.id) ?? false;
		final child = ContextMenu(
			actions: [
				ContextMenuAction(
					child: Text('Share link'),
					trailingIcon: Icons.ios_share,
					onPressed: () {
						Share.share(site.getWebUrl(post.threadIdentifier, post.id));
					}
				),
				if (post.attachment != null) ...[
					ContextMenuAction(
						child: Text('Search archive'),
						trailingIcon: Icons.image,
						onPressed: () {
							context.read<GlobalKey<NavigatorState>>().currentState!.push(cpr.CupertinoPageRoute(
								builder: (context) => SearchQueryPage(ImageboardArchiveSearchQuery(boards: [post.board], md5: post.attachment!.md5))
							));
						}
					),
					ContextMenuAction(
						child: Text('Search Google'),
						trailingIcon: Icons.image,
						onPressed: () => openBrowser(context, Uri.https('www.google.com', '/searchbyimage', {
							'image_url': post.attachment!.url.toString(),
							'safe': 'off'
						}))
					),
					ContextMenuAction(
						child: Text('Search Yandex'),
						trailingIcon: Icons.image,
						onPressed: () => openBrowser(context, Uri.https('yandex.com', '/images/search', {
							'rpt': 'imageview',
							'url': post.attachment!.url.toString()
						}))
					)
				]
			],
			child: GestureDetector(
				onTap: onTap,
				child: Container(
					padding: EdgeInsets.all(8),
					decoration: BoxDecoration(
						border: zone.stackIds.isNotEmpty ? Border.all(width: 0) : null,
						color: CupertinoTheme.of(context).scaffoldBackgroundColor
					),
					child: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							PostSpanZone(
								postId: post.id,
								builder: (ctx) => DefaultTextStyle(
									child: Text.rich(
										TextSpan(
											children: [
												TextSpan(
													text: post.name + (isYou ? ' (You)' : ''),
													style: TextStyle(fontWeight: FontWeight.w600, color: isYou ? Colors.red : null)
												),
												if (post.posterId != null) IDSpan(
													id: post.posterId!,
													onPressed: () => Navigator.of(context).push(TransparentRoute(
														builder: (ctx) => PostsPage(
															postsIdsToShow: zone.threadPosts.where((p) => p.posterId == post.posterId).map((p) => p.id).toList(),
															zone: zone,
															onTapPost: onNeedScrollToAnotherPost
														)
													))
												),
												if (post.flag != null) ...[
													FlagSpan(post.flag!),
													TextSpan(
														text: post.flag!.name,
														style: TextStyle(
															fontStyle: FontStyle.italic
														)
													)
												],
												TextSpan(
													text: formatTime(post.time)
												),
												TextSpan(
													text: post.id.toString(),
													style: TextStyle(color: Colors.grey),
													recognizer: TapGestureRecognizer()..onTap = () {
														context.read<GlobalKey<ReplyBoxState>>().currentState?.onTapPostId(post.id);
													}
												),
												if (!settings.useTouchLayout) ...[
													...post.replyIds.map((id) => PostQuoteLinkSpan(
														board: post.board,
														threadId: post.threadId,
														postId: id,
														dead: false
													).build(ctx, PostSpanRenderOptions(
														showCrossThreadLabel: showCrossThreadLabel,
														addExpandingPosts: false
													))),
													...post.replyIds.map((id) => WidgetSpan(
														child: ExpandingPost(id)
													))
												]
											].expand((span) => [TextSpan(text: ' '), span]).skip(1).toList()
										)
									),
									style: DefaultTextStyle.of(context).style.copyWith(fontSize: 14)
								)
							),
							SizedBox(height: 2),
							Flexible(
								child: IntrinsicHeight(
									child: Row(
										crossAxisAlignment: CrossAxisAlignment.stretch,
										mainAxisAlignment: MainAxisAlignment.start,
										mainAxisSize: MainAxisSize.max,
										children: [
											if (post.attachment != null) Align(
												alignment: Alignment.topCenter,
												child: GestureDetector(
													child: AttachmentThumbnail(
														attachment: post.attachment!,
														hero: AttachmentSemanticLocation(
															attachment: post.attachment!,
															semanticParents: zone.stackIds
														)
													),
													onTap: () {
														onThumbnailTap?.call(post.attachment!);
													}
												)
											),
											Expanded(
												child: PostSpanZone(
													postId: post.id,
													builder: (ctx) => Container(
														padding: EdgeInsets.all(8),
														child: Stack(
															fit: StackFit.passthrough,
															children: [
																IgnorePointer(
																	ignoring: !allowTappingLinks,
																	child: Text.rich(
																		TextSpan(
																			children: [
																				post.span.build(ctx, PostSpanRenderOptions(
																					onNeedScrollToAnotherPost: onNeedScrollToAnotherPost,
																					showCrossThreadLabel: showCrossThreadLabel
																				)),
																				// Placeholder to guarantee the stacked reply button is not on top of text
																				if (settings.useTouchLayout && post.replyIds.isNotEmpty) TextSpan(
																					text: List.filled(post.replyIds.length.toString().length + 3, '1').join(),
																					style: TextStyle(color: CupertinoTheme.of(context).scaffoldBackgroundColor)
																				)
																			]
																		),
																		overflow: TextOverflow.fade
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
																			onPressed: () => Navigator.of(context).push(
																				TransparentRoute(
																					builder: (ctx) => PostsPage(
																						postsIdsToShow: post.replyIds,
																						zone: zone.childZoneFor(post.id),
																						onTapPost: onNeedScrollToAnotherPost
																					)
																				)
																			)
																		)
																	)
																)
															]
														)
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
			)
		);
		if (context.watchOrNull<PostSpanZoneData>() == null) {
			return ChangeNotifierProvider.value(
				value: zone,
				child: child
			);
		}
		else {
			return child;
		}
	}
}
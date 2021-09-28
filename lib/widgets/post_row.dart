import 'package:chan/services/persistence.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/models/search.dart';
import 'package:chan/pages/posts.dart';
import 'package:chan/pages/search_query.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/context_menu.dart';
import 'package:chan/widgets/slider_builder.dart';
import 'package:chan/widgets/thread_spans.dart';
import 'package:chan/widgets/reply_box.dart';
import 'package:chan/widgets/weak_navigator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:chan/widgets/cupertino_page_route.dart';

import 'package:chan/models/post.dart';
import 'package:chan/models/attachment.dart';

import 'package:provider/provider.dart';
import 'package:chan/widgets/util.dart';
import 'package:chan/util.dart';
import 'package:hive_flutter/hive_flutter.dart';

class PostRow extends StatelessWidget {
	final Post post;
	final ValueChanged<Attachment>? onThumbnailTap;
	final VoidCallback? onTap;
	final VoidCallback? onRequestArchive;
	final bool showCrossThreadLabel;
	final bool allowTappingLinks;
	final bool shrinkWrap;
	final bool isSelected;

	const PostRow({
		required this.post,
		this.onTap,
		this.onThumbnailTap,
		this.onRequestArchive,
		this.showCrossThreadLabel = true,
		this.allowTappingLinks = true,
		this.shrinkWrap = false,
		this.isSelected = false
	});

	@override
	Widget build(BuildContext context) {
		return ValueListenableBuilder(
			valueListenable: Persistence.savedPostsBox.listenable(keys: [post.globalId]),
			builder: (context, box, child) {
				final site = context.watch<ImageboardSite>();
				Post _post = Persistence.getSavedPost(post)?.post ?? post;
				final zone = context.watch<PostSpanZoneData>();
				final settings = context.watch<EffectiveSettings>();
				final receipt = zone.threadState?.receipts.tryFirstWhere((r) => r.id == _post.id);
				final openReplies = () {
					if (_post.replyIds.isNotEmpty) {
						WeakNavigator.push(context, PostsPage(
								postsIdsToShow: _post.replyIds,
								postIdForBackground: _post.id,
								zone: zone.childZoneFor(_post.id)
							)
						);
					}
				};
				final content = (double factor) => PostSpanZone(
					postId: _post.id,
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
												_post.span.build(ctx, PostSpanRenderOptions(
													showCrossThreadLabel: showCrossThreadLabel
												)),
												// Placeholder to guarantee the stacked reply button is not on top of text
												if (settings.useTouchLayout && _post.replyIds.isNotEmpty) TextSpan(
													text: List.filled(_post.replyIds.length.toString().length + 3, '1').join(),
													style: TextStyle(color: Colors.transparent)
												)
											]
										),
										overflow: TextOverflow.fade
									)
								),
								if (settings.useTouchLayout && _post.replyIds.isNotEmpty) Positioned.fill(
									child: Align(
										alignment: Alignment.bottomRight,
										child: CupertinoButton(
											alignment: Alignment.bottomRight,
											padding: EdgeInsets.zero,
											child: Transform.scale(
												alignment: Alignment.bottomRight,
												scale: 1 + factor.clamp(0, 1),
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
															_post.replyIds.length.toString(),
															style: TextStyle(
																color: Colors.red,
																fontWeight: FontWeight.bold
															)
														)
													]
												)
											),
											onPressed: openReplies
										)
									)
								)
							]
						)
					)
				);
				final innerChild = (context, slideFactor) => GestureDetector(
					onTap: onTap,
					child: Container(
						padding: EdgeInsets.all(8),
						decoration: BoxDecoration(
							border: zone.stackIds.isNotEmpty ? Border.all(width: 0) : null,
							color: isSelected ? ((CupertinoTheme.of(context).brightness == Brightness.light) ? Colors.grey.shade400 : Colors.grey.shade800) : CupertinoTheme.of(context).scaffoldBackgroundColor
						),
						child: Column(
							mainAxisSize: MainAxisSize.min,
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								ClipRect(
									child: PostSpanZone(
										postId: _post.id,
										builder: (ctx) => Text.rich(
											TextSpan(
												children: [
													TextSpan(
														text: _post.name + ((receipt != null) ? ' (You)' : ''),
														style: TextStyle(fontWeight: FontWeight.w600, color: (receipt != null) ? Colors.red : null)
													),
													if (_post.posterId != null) IDSpan(
														id: _post.posterId!,
														onPressed: () => WeakNavigator.push(context, PostsPage(
															postsIdsToShow: zone.thread.posts.where((p) => p.posterId == _post.posterId).map((p) => p.id).toList(),
															zone: zone
														))
													),
													if (_post.flag != null) ...[
														FlagSpan(_post.flag!),
														TextSpan(
															text: _post.flag!.name,
															style: TextStyle(
																fontStyle: FontStyle.italic
															)
														)
													],
													TextSpan(
														text: formatTime(_post.time)
													),
													TextSpan(
														text: _post.id.toString(),
														style: TextStyle(color: Colors.grey),
														recognizer: TapGestureRecognizer()..onTap = () {
															ctx.read<GlobalKey<ReplyBoxState>>().currentState?.onTapPostId(_post.id);
														}
													),
													if (!settings.useTouchLayout) ...[
														..._post.replyIds.map((id) => PostQuoteLinkSpan(
															board: _post.board,
															threadId: _post.threadId,
															postId: id,
															dead: false
														).build(ctx, PostSpanRenderOptions(
															showCrossThreadLabel: showCrossThreadLabel,
															addExpandingPosts: false
														))),
														..._post.replyIds.map((id) => WidgetSpan(
															child: ExpandingPost(id),
														))
													]
												].expand((span) => [TextSpan(text: ' '), span]).skip(1).toList()
											)
										)
									)
								),
								SizedBox(height: 2),
								Flexible(
									child: IntrinsicHeight(
										child: Row(
											crossAxisAlignment: CrossAxisAlignment.stretch,
											mainAxisAlignment: MainAxisAlignment.start,
											mainAxisSize: MainAxisSize.min,
											children: [
												if (_post.attachment != null) Align(
													alignment: Alignment.topCenter,
													child: GestureDetector(
														child: AttachmentThumbnail(
															attachment: _post.attachment!,
															thread: _post.threadIdentifier,
															hero: AttachmentSemanticLocation(
																attachment: _post.attachment!,
																semanticParents: zone.stackIds
															)
														),
														onTap: () {
															onThumbnailTap?.call(_post.attachment!);
														}
													)
												)
												else if (_post.attachmentDeleted) Center(
													child: SizedBox(
														width: 75,
														height: 75,
														child: GestureDetector(
															behavior: HitTestBehavior.opaque,
															child: Icon(Icons.broken_image, size: 36),
															onTap: onRequestArchive
														)
													)
												),
												if (shrinkWrap) Flexible(
													child: content(slideFactor)
												)
												else Expanded(
													child: content(slideFactor)
												)
											]
										)
									)
								)
							]
						)
					)
				);
				final child = ContextMenu(
					actions: [
						if (zone.stackIds.isNotEmpty && zone.onNeedScrollToPost != null) ContextMenuAction(
							child: Text('Scroll to post'),
							trailingIcon: Icons.subdirectory_arrow_right,
							onPressed: () => zone.onNeedScrollToPost!(_post)
						),
						if (Persistence.getSavedPost(post) == null) ContextMenuAction(
							child: Text('Save Post'),
							trailingIcon: Icons.bookmark_add,
							onPressed: () {
								Persistence.savePost(_post, zone.thread);
							}
						)
						else ContextMenuAction(
							child: Text('Unsave Post'),
							trailingIcon: Icons.bookmark_remove,
							onPressed: () {
								Persistence.getSavedPost(post)?.delete();
							}
						),
						ContextMenuAction(
							child: Text('Share link'),
							trailingIcon: Icons.ios_share,
							onPressed: () {
								final offset = (context.findRenderObject() as RenderBox?)?.localToGlobal(Offset.zero);
								final size = context.findRenderObject()?.semanticBounds.size;
								Share.share(site.getWebUrl(_post.threadIdentifier, _post.id), sharePositionOrigin: (offset != null && size != null) ? offset & size : null);
							}
						),
						if (receipt != null) ContextMenuAction(
							child: Text('Delete post'),
							trailingIcon: Icons.delete,
							onPressed: () {
								try {
									site.deletePost(_post.board, receipt);
								}
								catch (error) {
									alertError(context, error.toString());
								}
							}
						),
						if (_post.attachment != null) ...[
							ContextMenuAction(
								child: Text('Search archive'),
								trailingIcon: Icons.image,
								onPressed: () {
									context.read<GlobalKey<NavigatorState>>().currentState!.push(FullWidthCupertinoPageRoute(
										builder: (context) => SearchQueryPage(ImageboardArchiveSearchQuery(boards: [_post.board], md5: _post.attachment!.md5))
									));
								}
							),
							ContextMenuAction(
								child: Text('Search Google'),
								trailingIcon: Icons.image,
								onPressed: () => openBrowser(context, Uri.https('www.google.com', '/searchbyimage', {
									'image_url': _post.attachment!.url.toString(),
									'safe': 'off'
								}))
							),
							ContextMenuAction(
								child: Text('Search Yandex'),
								trailingIcon: Icons.image,
								onPressed: () => openBrowser(context, Uri.https('yandex.com', '/images/search', {
									'rpt': 'imageview',
									'url': _post.attachment!.url.toString()
								}))
							)
						]
					],
					child: (_post.replyIds.isNotEmpty) ? SliderBuilder(
						popup: PostsPage(
							postsIdsToShow: _post.replyIds,
							postIdForBackground: _post.id,
							zone: zone.childZoneFor(_post.id)
						),
						builder: innerChild
					) : innerChild(context, 0.0)
				);
				if (context.watch<PostSpanZoneData?>() == null) {
					return ChangeNotifierProvider.value(
						value: zone,
						child: child
					);
				}
				else {
					return child;
				}
			}
		);
	}
}
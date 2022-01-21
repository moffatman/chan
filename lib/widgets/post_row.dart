import 'package:chan/pages/selectable_post.dart';
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

class PostRow extends StatelessWidget {
	final Post post;
	final ValueChanged<Attachment>? onThumbnailTap;
	final VoidCallback? onTap;
	final VoidCallback? onRequestArchive;
	final bool showCrossThreadLabel;
	final bool allowTappingLinks;
	final bool shrinkWrap;
	final bool isSelected;
	final Function(Object?, StackTrace?)? onThumbnailLoadError;

	const PostRow({
		required this.post,
		this.onTap,
		this.onThumbnailTap,
		this.onThumbnailLoadError,
		this.onRequestArchive,
		this.showCrossThreadLabel = true,
		this.allowTappingLinks = true,
		this.shrinkWrap = false,
		this.isSelected = false,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		final site = context.watch<ImageboardSite>();
		Post _post = context.watch<Persistence>().getSavedPost(post)?.post ?? post;
		if (_post.attachment?.url != post.attachment?.url) {
			_post.attachment = post.attachment;
			context.watch<Persistence>().didUpdateSavedPost();
		}
		final zone = context.watch<PostSpanZoneData>();
		final settings = context.watch<EffectiveSettings>();
		final receipt = zone.threadState?.receipts.tryFirstWhere((r) => r.id == _post.id);
		final isYourPost = receipt != null || (zone.threadState?.postsMarkedAsYou.contains(post.id) ?? false);
		Border? border;
		if (isYourPost) {
			border = Border(
				left: BorderSide(color: CupertinoTheme.of(context).textTheme.actionTextStyle.color ?? Colors.red, width: 10)
			);
		}
		if (zone.threadState?.replyIdsToYou?.contains(post.id) ?? false) {
			border = Border(
				left: BorderSide(color: CupertinoTheme.of(context).textTheme.actionTextStyle.color?.towardsBlack(0.5) ?? const Color.fromARGB(255, 90, 30, 30), width: 10)
			);
		}
		openReplies() {
			if (_post.replyIds.isNotEmpty) {
				WeakNavigator.push(context, PostsPage(
						postsIdsToShow: _post.replyIds,
						postIdForBackground: _post.id,
						zone: zone.childZoneFor(_post.id)
					)
				);
			}
		}
		content(double factor) => PostSpanZone(
			postId: _post.id,
			builder: (ctx) => Container(
				padding: const EdgeInsets.all(8),
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
											style: const TextStyle(color: Colors.transparent)
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
													CupertinoIcons.reply_thick_solid,
													color: CupertinoTheme.of(context).textTheme.actionTextStyle.color,
													size: 14
												),
												const SizedBox(width: 4),
												Text(
													_post.replyIds.length.toString(),
													style: TextStyle(
														color: CupertinoTheme.of(context).textTheme.actionTextStyle.color,
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
		innerChild(BuildContext context, double slideFactor) => GestureDetector(
			onTap: onTap,
			child: Container(
				padding: const EdgeInsets.all(8),
				decoration: BoxDecoration(
					border: border,
					color: isSelected ? CupertinoTheme.of(context).primaryColorWithBrightness(0.4) : CupertinoTheme.of(context).scaffoldBackgroundColor,
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
												text: context.read<EffectiveSettings>().filterProfanity(_post.name) + (isYourPost ? ' (You)' : ''),
												style: TextStyle(fontWeight: FontWeight.w600, color: isYourPost ? CupertinoTheme.of(context).textTheme.actionTextStyle.color : null)
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
													style: const TextStyle(
														fontStyle: FontStyle.italic
													)
												)
											],
											TextSpan(
												text: formatTime(_post.time)
											),
											TextSpan(
												text: _post.id.toString(),
												style: const TextStyle(color: Colors.grey),
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
													child: ExpandingPost(id: id),
												))
											]
										].expand((span) => [const TextSpan(text: ' '), span]).skip(1).toList()
									)
								)
							)
						),
						const SizedBox(height: 2),
						Flexible(
							child: IntrinsicHeight(
								child: Row(
									crossAxisAlignment: CrossAxisAlignment.stretch,
									mainAxisAlignment: MainAxisAlignment.start,
									mainAxisSize: MainAxisSize.min,
									children: [
										if (_post.attachment != null && settings.showImages(context, _post.board)) Align(
											alignment: Alignment.topCenter,
											child: GestureDetector(
												child: Stack(
													alignment: Alignment.center,
													fit: StackFit.loose,
													children: [
														AttachmentThumbnail(
															attachment: _post.attachment!,
															thread: _post.threadIdentifier,
															onLoadError: onThumbnailLoadError,
															hero: AttachmentSemanticLocation(
																attachment: _post.attachment!,
																semanticParents: zone.stackIds
															)
														),
														if (_post.attachment?.type == AttachmentType.webm) SizedBox(
															width: 75,
															height: 75,
															child: Center(
																child: AspectRatio(
																	aspectRatio: (_post.attachment!.width ?? 1) / (_post.attachment!.height ?? 1),
																	child: Align(
																		alignment: Alignment.bottomRight,
																		child: Container(
																			decoration: BoxDecoration(
																				borderRadius: const BorderRadius.only(topLeft: Radius.circular(6)),
																				color: CupertinoTheme.of(context).scaffoldBackgroundColor,
																				border: Border.all(color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2))
																			),
																			padding: const EdgeInsets.all(2),
																			child: const Icon(CupertinoIcons.play_arrow_solid, size: 16)
																		)
																	)
																)
															)
														)
													]
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
													child: const Icon(CupertinoIcons.question_square, size: 36),
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
				if (zone.stackIds.length > 2 && zone.onNeedScrollToPost != null) ContextMenuAction(
					child: const Text('Scroll to post'),
					trailingIcon: CupertinoIcons.return_icon,
					onPressed: () => zone.onNeedScrollToPost!(_post)
				),
				if (context.watch<Persistence>().getSavedPost(post) == null) ContextMenuAction(
					child: const Text('Save Post'),
					trailingIcon: CupertinoIcons.bookmark,
					onPressed: () {
						context.read<Persistence>().savePost(_post, zone.thread);
					}
				)
				else ContextMenuAction(
					child: const Text('Unsave Post'),
					trailingIcon: CupertinoIcons.bookmark_fill,
					onPressed: () {
						context.read<Persistence>().unsavePost(post);
					}
				),
				if (zone.threadState != null) ...[
					if (zone.threadState!.postsMarkedAsYou.contains(_post.id)) ContextMenuAction(
							child: const Text('Unmark as You'),
							trailingIcon: CupertinoIcons.person_badge_minus,
							onPressed: () {
								zone.threadState!.postsMarkedAsYou.remove(_post.id);
								zone.threadState!.save();
							}
						)
					else ContextMenuAction(
							child: const Text('Mark as You'),
							trailingIcon: CupertinoIcons.person_badge_plus,
							onPressed: () {
								zone.threadState!.postsMarkedAsYou.add(_post.id);
								zone.threadState!.savedTime ??= DateTime.now();
								zone.threadState!.save();
							}
						),
					if (zone.threadState!.hiddenPostIds.contains(_post.id)) ContextMenuAction(
						child: const Text('Unhide post'),
						trailingIcon: CupertinoIcons.eye_slash_fill,
						onPressed: () {
							zone.threadState!.unHidePost(_post.id);
							zone.threadState!.save();
						}
					)
					else ContextMenuAction(
						child: const Text('Hide post'),
						trailingIcon: CupertinoIcons.eye_slash,
						onPressed: () {
							zone.threadState!.hidePost(_post.id);
							zone.threadState!.save();
						}
					)
				],
				ContextMenuAction(
					child: const Text('Select text'),
					trailingIcon: CupertinoIcons.selection_pin_in_out,
					onPressed: () {
						WeakNavigator.push(context, SelectablePostPage(
							post: _post,
							zone: zone,
							onQuoteText: (text) => context.read<GlobalKey<ReplyBoxState>>().currentState?.onQuoteText(text)
						));
					}
				),
				ContextMenuAction(
					child: const Text('Share link'),
					trailingIcon: CupertinoIcons.share,
					onPressed: () {
						final offset = (context.findRenderObject() as RenderBox?)?.localToGlobal(Offset.zero);
						final size = context.findRenderObject()?.semanticBounds.size;
						Share.share(site.getWebUrl(_post.board, _post.threadId, _post.id), sharePositionOrigin: (offset != null && size != null) ? offset & size : null);
					}
				),
				ContextMenuAction(
					child: const Text('Report Post'),
					trailingIcon: CupertinoIcons.exclamationmark_octagon,
					onPressed: () {
						openBrowser(context, context.read<ImageboardSite>().getPostReportUrl(_post.board, _post.id));
					}
				),
				if (receipt != null) ContextMenuAction(
					child: const Text('Delete Post'),
					trailingIcon: CupertinoIcons.delete,
					onPressed: () {
						try {
							site.deletePost(_post.board, receipt);
						}
						catch (error) {
							alertError(context, error.toStringDio());
						}
					}
				),
				if (_post.attachment != null) ...[
					ContextMenuAction(
						child: const Text('Search archives'),
						trailingIcon: Icons.image_search,
						onPressed: () {
							context.read<GlobalKey<NavigatorState>>().currentState!.push(FullWidthCupertinoPageRoute(
								builder: (context) => SearchQueryPage(query: ImageboardArchiveSearchQuery(boards: [_post.board], md5: _post.attachment!.md5))
							));
						}
					),
					ContextMenuAction(
						child: const Text('Search Google'),
						trailingIcon: Icons.image_search,
						onPressed: () => openBrowser(context, Uri.https('www.google.com', '/searchbyimage', {
							'image_url': _post.attachment!.url.toString(),
							'safe': 'off'
						}))
					),
					ContextMenuAction(
						child: const Text('Search Yandex'),
						trailingIcon: Icons.image_search,
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
}
import 'package:chan/pages/selectable_post.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/notifications.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/reverse_image_search.dart';
import 'package:chan/services/share.dart';
import 'package:chan/services/soundposts.dart';
import 'package:chan/widgets/popup_attachment.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/pages/posts.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/context_menu.dart';
import 'package:chan/widgets/slider_builder.dart';
import 'package:chan/widgets/thread_spans.dart';
import 'package:chan/widgets/reply_box.dart';
import 'package:chan/widgets/weak_gesture_recognizer.dart';
import 'package:chan/widgets/weak_navigator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:chan/models/post.dart';
import 'package:chan/models/attachment.dart';
import 'package:provider/provider.dart';
import 'package:chan/widgets/util.dart';
import 'package:chan/util.dart';

class PostRow extends StatelessWidget {
	final Post post;
	final ValueChanged<Attachment>? onThumbnailTap;
	final VoidCallback? onTap;
	final VoidCallback? onDoubleTap;
	final VoidCallback? onRequestArchive;
	final bool showCrossThreadLabel;
	final bool allowTappingLinks;
	final bool shrinkWrap;
	final bool isSelected;
	final Function(Object?, StackTrace?)? onThumbnailLoadError;
	final PostSpanRenderOptions? baseOptions;
	final bool showSiteIcon;
	final bool showBoardName;
	final bool showYourPostBorder;
	final bool highlight;
	final Widget? overrideReplyCount;
	final bool dim;
	final bool showPostNumber;

	const PostRow({
		required this.post,
		this.onTap,
		this.onDoubleTap,
		this.onThumbnailTap,
		this.onThumbnailLoadError,
		this.onRequestArchive,
		this.showCrossThreadLabel = true,
		this.allowTappingLinks = true,
		this.shrinkWrap = false,
		this.isSelected = false,
		this.showSiteIcon = false,
		this.showBoardName = false,
		this.showYourPostBorder = true,
		this.highlight = false,
		this.baseOptions,
		this.overrideReplyCount,
		this.dim = false,
		this.showPostNumber = true,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		final rootContext = context;
		final site = context.watch<ImageboardSite>();
		final notifications = context.watch<Notifications>();
		final savedPost = context.select<Persistence, SavedPost?>((p) => p.getSavedPost(post));
		Post latestPost = savedPost?.post ?? post;
		bool didUpdateAttachments = false;
		for (int i = 0; i < latestPost.attachments.length; i++) {
			final attachment = post.attachments.tryFirstWhere((a) => a.id == latestPost.attachments[i].id);
			if (attachment?.url != latestPost.attachments[i].url) {
				latestPost.attachments[i] = attachment!;
				didUpdateAttachments = true;
			}
		}
		if (didUpdateAttachments) {
			context.read<Persistence>().didUpdateSavedPost();
		}
		else if (latestPost.replyIds.length != post.replyIds.length) {
			latestPost.replyIds = post.replyIds;
			context.read<Persistence>().didUpdateSavedPost();
		}
		final parentZone = context.watch<PostSpanZoneData>();
		final translatedPostSnapshot = parentZone.translatedPost(post.id);
		final settings = context.watch<EffectiveSettings>();
		final receipt = parentZone.threadState?.receipts.tryFirstWhere((r) => r.id == latestPost.id);
		final isYourPost = receipt != null || (parentZone.threadState?.postsMarkedAsYou.contains(post.id) ?? false);
		Border? border;
		if (isYourPost && showYourPostBorder) {
			border = Border(
				left: BorderSide(color: CupertinoTheme.of(context).textTheme.actionTextStyle.color ?? Colors.red, width: 10)
			);
		}
		else if (parentZone.threadState?.replyIdsToYou(Filter.of(context))?.contains(post.id) ?? false) {
			border = Border(
				left: BorderSide(color: CupertinoTheme.of(context).textTheme.actionTextStyle.color?.towardsBlack(0.5) ?? const Color.fromARGB(255, 90, 30, 30), width: 10)
			);
		}
		final replyIds = latestPost.replyIds.toList();
		replyIds.removeWhere((id) {
			final replyPost = parentZone.thread.posts.tryFirstWhere((p) => p.id == id);
			if (replyPost != null) {
				if (Filter.of(context).filter(replyPost)?.type.hide == true) {
					return true;
				}
			}
			return false;
		});
		openReplies() {
			if (replyIds.isNotEmpty) {
				WeakNavigator.push(context, PostsPage(
						postsIdsToShow: replyIds,
						postIdForBackground: latestPost.id,
						zone: parentZone.childZoneFor(latestPost.id)
					)
				);
			}
		}
		content(double factor) => PostSpanZone(
			postId: latestPost.id,
			builder: (ctx) => Padding(
				padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
				child: IgnorePointer(
					ignoring: !allowTappingLinks,
					child: ConditionalOnTapUp(
						condition: (d) => ctx.read<PostSpanZoneData>().canTap(d.position),
						onTapUp: (d) {
							if (!ctx.read<PostSpanZoneData>().onTap(d.globalPosition)) {
								onTap?.call();
							}
						},
						child: Text.rich(
							TextSpan(
								children: [
									if ((!parentZone.tree || (post.parentId != latestPost.threadId && (baseOptions?.highlightString?.isNotEmpty ?? false))) && !site.explicitIds && post.parentId != null) ...[
										PostQuoteLinkSpan(
											board: latestPost.board,
											threadId: latestPost.threadId,
											postId: latestPost.parentId!,
											dead: false
										).build(
											ctx, ctx.watch<PostSpanZoneData>(), settings, (baseOptions ?? PostSpanRenderOptions()).copyWith(
												shrinkWrap: shrinkWrap
											)
										),
										const TextSpan(text: '\n'),
									],
									(translatedPostSnapshot?.data ?? latestPost).span.build(
										ctx, ctx.watch<PostSpanZoneData>(), settings,
										(baseOptions ?? PostSpanRenderOptions()).copyWith(
											showCrossThreadLabel: showCrossThreadLabel,
											shrinkWrap: shrinkWrap,
											postInject: overrideReplyCount != null ? WidgetSpan(
												alignment: PlaceholderAlignment.top,
												child: Visibility(
													visible: false,
													maintainSize: true,
													maintainAnimation: true,
													maintainState: true,
													child: Padding(
														padding: const EdgeInsets.only(left: 8, right: 8),
														child: overrideReplyCount!
													)
												)
											) : (replyIds.isEmpty ? null : TextSpan(
												text: List.filled(replyIds.length.toString().length + 4, '1').join(),
												style: const TextStyle(color: Colors.transparent)
											))
										)
									),
									// In practice this is the height of a line of text
									const WidgetSpan(
										child: SizedBox(
											width: double.infinity,
											height: 0
										)
									)
								]
							),
							overflow: TextOverflow.fade
						)
					)
				)
			)
		);
		innerChild(BuildContext context, double slideFactor) {
			final mainRow = [
				const SizedBox(width: 8),
				if (latestPost.attachments.isNotEmpty && settings.showImages(context, latestPost.board)) Padding(
					padding: (settings.imagesOnRight && replyIds.isNotEmpty) ? const EdgeInsets.only(bottom: 32) : EdgeInsets.zero,
					child: ClippingBox(
						fade: true,
						child: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								...latestPost.attachments.map((attachment) => PopupAttachment(
									attachment: attachment,
									child: CupertinoButton(
										padding: EdgeInsets.zero,
										minSize: 0,
										child: Container(
											alignment: Alignment.center,
											constraints: BoxConstraints(
												minWidth: settings.thumbnailSize,
												minHeight: 75
											),
											child: Stack(
												children: [
													AttachmentThumbnail(
														attachment: attachment,
														thread: latestPost.threadIdentifier,
														onLoadError: onThumbnailLoadError,
														hero: TaggedAttachment(
															attachment: attachment,
															semanticParentIds: parentZone.stackIds
														),
														fit: settings.squareThumbnails ? BoxFit.cover : BoxFit.contain,
														shrinkHeight: !settings.squareThumbnails,
														shrinkWidth: !settings.squareThumbnails
													),
													if (attachment.soundSource != null || attachment.isVideoOrGif || attachment.type == AttachmentType.url) Positioned.fill(
														child: Align(
															alignment: Alignment.bottomRight,
															child: Container(
																decoration: BoxDecoration(
																	borderRadius: const BorderRadius.only(topLeft: Radius.circular(6)),
																	color: CupertinoTheme.of(context).scaffoldBackgroundColor,
																	border: Border.all(color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2))
																),
																padding: const EdgeInsets.all(2),
																child: attachment.soundSource != null ?
																	const Icon(CupertinoIcons.volume_up, size: 16) :
																	attachment.isVideoOrGif ?
																		const Icon(CupertinoIcons.play_arrow_solid, size: 16) :
																		const Icon(CupertinoIcons.link, size: 16)
															)
														)
													)
												]
											)
										),
										onPressed: () {
											onThumbnailTap?.call(attachment);
										}
									)
								)).expand((x) => [const SizedBox(height: 8), x]),
								const SizedBox(height: 8)
							]
						)
					)
				)
				else if (latestPost.attachmentDeleted) Center(
					child: SizedBox(
						width: 75,
						height: 75,
						child: CupertinoButton(
							onPressed: onRequestArchive,
							child: const Icon(CupertinoIcons.question_square, size: 36)
						)
					)
				),
				if (shrinkWrap) Flexible(
					child: content(slideFactor)
				)
				else Expanded(
					child: content(slideFactor)
				),
				const SizedBox(width: 8)
			];
			return RawGestureDetector(
				gestures: {
					WeakDoubleTapGestureRecognizer: GestureRecognizerFactoryWithHandlers<WeakDoubleTapGestureRecognizer>(
						() => WeakDoubleTapGestureRecognizer(debugOwner: this),
						(recognizer) => recognizer..onDoubleTap = onDoubleTap
					),
					TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
						() => TapGestureRecognizer(debugOwner: this),
						(recognizer) => recognizer..onTap = onTap
					)
				},
				child: Container(
					decoration: BoxDecoration(
						border: border,
						color: isSelected ?
							CupertinoTheme.of(context).primaryColorWithBrightness(0.4) :
								highlight ? CupertinoTheme.of(context).primaryColorWithBrightness(0.1) : CupertinoTheme.of(context).scaffoldBackgroundColor,
					),
					child: Stack(
						children: [
							Opacity(
								opacity: dim ? 0.5 : 1,
								child: Column(
									mainAxisSize: MainAxisSize.min,
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										const SizedBox(height: 8),
										Padding(
											padding: const EdgeInsets.only(left: 8, right: 8),
											child: PostSpanZone(
												postId: latestPost.id,
												builder: (ctx) => ValueListenableBuilder<bool>(
													valueListenable: settings.supportMouse,
													builder: (context, supportMouse, child) => Text.rich(
														TextSpan(
															children: [
																...buildPostInfoRow(
																	post: latestPost,
																	isYourPost: isYourPost,
																	showSiteIcon: showSiteIcon,
																	showBoardName: showBoardName,
																	settings: settings,
																	site: site,
																	context: context,
																	zone: ctx.watch<PostSpanZoneData>(),
																	showPostNumber: showPostNumber
																),
																if (supportMouse) ...[
																	...replyIds.map((id) => PostQuoteLinkSpan(
																		board: latestPost.board,
																		threadId: latestPost.threadId,
																		postId: id,
																		dead: false
																	).build(ctx, ctx.watch<PostSpanZoneData>(), settings, (baseOptions ?? PostSpanRenderOptions()).copyWith(
																		showCrossThreadLabel: showCrossThreadLabel,
																		addExpandingPosts: false,
																		shrinkWrap: shrinkWrap
																	))),
																	...replyIds.map((id) => WidgetSpan(
																		child: ExpandingPost(id: id),
																	))
																].expand((span) => [span, const TextSpan(text: ' ')])
															]
														)
													)
												)
											)
										),
										const SizedBox(height: 2),
										Flexible(
											child: Row(
												crossAxisAlignment: CrossAxisAlignment.start,
												mainAxisAlignment: MainAxisAlignment.start,
												mainAxisSize: MainAxisSize.min,
												children: settings.imagesOnRight ? mainRow.reversed.toList() : mainRow
											)
										)
									]
								)
							),
							if (overrideReplyCount != null) Positioned.fill(
								child: Align(
									alignment: Alignment.bottomRight,
									child: DecoratedBox(
										decoration: BoxDecoration(
											gradient: LinearGradient(
												begin: Alignment.centerRight,
												end: Alignment.centerLeft,
												colors: [
													settings.theme.backgroundColor,
													settings.theme.backgroundColor.withOpacity(0)
												]
											)
										),
										child: Padding(
											padding: const EdgeInsets.all(16),
											child: overrideReplyCount!
										)
									)
								)
							)
							else if (replyIds.isNotEmpty) Positioned.fill(
								child: Align(
									alignment: Alignment.bottomRight,
									child: CupertinoButton(
										alignment: Alignment.bottomRight,
										padding: const EdgeInsets.only(bottom: 16, right: 16),
										onPressed: openReplies,
										child: Transform.scale(
											alignment: Alignment.bottomRight,
											scale: 1 + slideFactor.clamp(0, 1),
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
														replyIds.length.toString(),
														style: TextStyle(
															color: CupertinoTheme.of(context).textTheme.actionTextStyle.color,
															fontWeight: FontWeight.bold
														)
													)
												]
											)
										)
									)
								)
							),
							if (savedPost != null || translatedPostSnapshot != null) Positioned.fill(
								child: Align(
									alignment: Alignment.topRight,
									child: Opacity(
										opacity: dim ? 0.5 : 1,
										child: Container(
											decoration: BoxDecoration(
												borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8)),
												color: CupertinoTheme.of(context).scaffoldBackgroundColor,
												border: Border.all(color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2))
											),
											padding: const EdgeInsets.only(top: 2, bottom: 2, left: 6, right: 6),
											child: Row(
												mainAxisSize: MainAxisSize.min,
												children: [
													if (translatedPostSnapshot != null) const Icon(Icons.translate),
													if (translatedPostSnapshot?.hasError ?? false) GestureDetector(
														onTap: () => alertError(context, translatedPostSnapshot?.error?.toStringDio() ?? 'Unknown'),
														child: const Icon(CupertinoIcons.exclamationmark_triangle)
													)
													else if (translatedPostSnapshot?.hasData == false) const CupertinoActivityIndicator(),
													if (savedPost != null) const Icon(CupertinoIcons.bookmark_fill, size: 18)
												]
											)
										)
									)
								)
							)
						]
					)
				)
			);
		}
		return ContextMenu(
			actions: [
				if (site.supportsPosting && context.read<GlobalKey<ReplyBoxState>?>()?.currentState != null) ContextMenuAction(
					child: const Text('Reply'),
					trailingIcon: CupertinoIcons.reply,
					onPressed: () => context.read<GlobalKey<ReplyBoxState>>().currentState?.onTapPostId(post.id)
				),
				ContextMenuAction(
					child: const Text('Select text'),
					trailingIcon: CupertinoIcons.selection_pin_in_out,
					onPressed: () {
						WeakNavigator.push(context, SelectablePostPage(
							post: latestPost,
							zone: parentZone,
							onQuoteText: (text) => context.read<GlobalKey<ReplyBoxState>>().currentState?.onQuoteText(text, fromId: latestPost.id)
						));
					}
				),
				ContextMenuAction(
					child: const Text('Share text'),
					trailingIcon: CupertinoIcons.share,
					onPressed: () {
						final offset = (rootContext.findRenderObject() as RenderBox?)?.localToGlobal(Offset.zero);
						final size = rootContext.findRenderObject()?.semanticBounds.size;
						shareOne(
							context: context,
							text: (translatedPostSnapshot?.data ?? latestPost).span.buildText(),
							type: "text",
							sharePositionOrigin: (offset != null && size != null) ? offset & size : null
						);
					}
				),
				if (parentZone.stackIds.length > 2 && parentZone.onNeedScrollToPost != null) ContextMenuAction(
					child: const Text('Scroll to post'),
					trailingIcon: CupertinoIcons.return_icon,
					onPressed: () => parentZone.onNeedScrollToPost!(latestPost)
				),
				if (savedPost == null) ContextMenuAction(
					child: const Text('Save post'),
					trailingIcon: CupertinoIcons.bookmark,
					onPressed: () {
						context.read<Persistence>().savePost(latestPost, parentZone.thread);
					}
				)
				else ContextMenuAction(
					child: const Text('Unsave post'),
					trailingIcon: CupertinoIcons.bookmark_fill,
					onPressed: () {
						context.read<Persistence>().unsavePost(post);
					}
				),
				if (parentZone.threadState != null) ...[
					if (isYourPost) ContextMenuAction(
							child: const Text('Unmark as You'),
							trailingIcon: CupertinoIcons.person_badge_minus,
							onPressed: () {
								parentZone.threadState!.receipts.removeWhere((r) => r.id == latestPost.id);
								parentZone.threadState!.postsMarkedAsYou.remove(latestPost.id);
								parentZone.threadState!.didUpdatePostsMarkedAsYou();
								parentZone.threadState!.save();
							}
						)
					else ContextMenuAction(
							child: const Text('Mark as You'),
							trailingIcon: CupertinoIcons.person_badge_plus,
							onPressed: () async {
								parentZone.threadState!.postsMarkedAsYou.add(latestPost.id);
								parentZone.threadState!.didUpdatePostsMarkedAsYou();
								if (site.supportsPushNotifications) {
									await promptForPushNotificationsIfNeeded(context);
								}
								notifications.subscribeToThread(
									thread: parentZone.threadState!.identifier,
									lastSeenId: parentZone.threadState!.thread?.posts.last.id ?? latestPost.id,
									localYousOnly: notifications.getThreadWatch(parentZone.threadState!.identifier)?.localYousOnly ?? true,
									pushYousOnly: notifications.getThreadWatch(parentZone.threadState!.identifier)?.localYousOnly ?? true,
									push: true,
									youIds: parentZone.threadState!.freshYouIds()
								);
								parentZone.threadState!.save();
							}
						),
					if (parentZone.threadState!.hiddenPostIds.contains(latestPost.id)) ContextMenuAction(
						child: const Text('Unhide post'),
						trailingIcon: CupertinoIcons.eye_slash_fill,
						onPressed: () {
							parentZone.threadState!.unHidePost(latestPost.id);
							parentZone.threadState!.save();
						}
					)
					else ...[
						ContextMenuAction(
							child: const Text('Hide post'),
							trailingIcon: CupertinoIcons.eye_slash,
							onPressed: () {
								parentZone.threadState!.hidePost(latestPost.id);
								parentZone.threadState!.save();
							}
						),
						ContextMenuAction(
							child: const Text('Hide post and replies'),
							trailingIcon: CupertinoIcons.eye_slash,
							onPressed: () {
								parentZone.threadState!.hidePost(latestPost.id, tree: true);
								parentZone.threadState!.save();
							}
						),
					],
					if (latestPost.posterId != null && parentZone.threadState!.hiddenPosterIds.contains(latestPost.posterId)) ContextMenuAction(
						child: RichText(text: TextSpan(
							children: [
								const TextSpan(text: 'Unhide from '),
								IDSpan(id: latestPost.posterId!, onPressed: null)
							]
						)),
						trailingIcon: CupertinoIcons.eye_slash_fill,
						onPressed: () {
							parentZone.threadState!.unHidePosterId(latestPost.posterId!);
							parentZone.threadState!.save();
						}
					)
					else if (latestPost.posterId != null) ContextMenuAction(
						child: RichText(text: TextSpan(
							children: [
								const TextSpan(text: 'Hide from '),
								IDSpan(id: latestPost.posterId!, onPressed: null)
							]
						)),
						trailingIcon: CupertinoIcons.eye_slash,
						onPressed: () {
							parentZone.threadState!.hidePosterId(latestPost.posterId!);
							parentZone.threadState!.save();
						}
					),
					if (context.select<Persistence, bool>((p) => p.browserState.areMD5sHidden(latestPost.md5s))) ContextMenuAction(
						child: Text('Unhide by image${latestPost.attachments.length != 1 ? 's' : ''}'),
						trailingIcon: CupertinoIcons.eye_slash_fill,
						onPressed: () {
							context.read<Persistence>().browserState.unHideByMD5s(latestPost.md5s);
							context.read<Persistence>().didUpdateHiddenMD5s();
							parentZone.threadState!.save();
						}
					)
					else if (latestPost.attachments.isNotEmpty) ContextMenuAction(
						child: const Text('Hide by image'),
						trailingIcon: CupertinoIcons.eye_slash,
						onPressed: () async {
							final persistence = context.read<Persistence>();
							final attachment = await whichAttachment(context, latestPost.attachments);
							if (attachment == null) {
								return;
							}
							persistence.browserState.hideByMD5(attachment.md5);
							persistence.didUpdateHiddenMD5s();
							parentZone.threadState!.save();
						}
					)
				],
				ContextMenuAction(
					child: const Text('Share link'),
					trailingIcon: CupertinoIcons.share,
					onPressed: () {
						final offset = (rootContext.findRenderObject() as RenderBox?)?.localToGlobal(Offset.zero);
						final size = rootContext.findRenderObject()?.semanticBounds.size;
						shareOne(
							context: context,
							text: site.getWebUrl(latestPost.board, latestPost.threadId, latestPost.id),
							type: "text",
							sharePositionOrigin: (offset != null && size != null) ? offset & size : null
						);
					}
				),
				if (translatedPostSnapshot?.hasData == true) ContextMenuAction(
					child: const Text('Original'),
					trailingIcon: Icons.translate,
					onPressed: () {
						parentZone.clearTranslatedPosts(post.id);
					}
				)
				else ContextMenuAction(
					child: const Text('Translate'),
					trailingIcon: Icons.translate,
					onPressed: () async {
						try {
							await parentZone.translatePost(post.id);
						}
						catch (e) {
							alertError(context, e.toStringDio());
						}
					}
				),
				ContextMenuAction(
					child: const Text('Report post'),
					trailingIcon: CupertinoIcons.exclamationmark_octagon,
					onPressed: () {
						openBrowser(context, context.read<ImageboardSite>().getPostReportUrl(latestPost.board, latestPost.threadId, latestPost.id));
					}
				),
				if (receipt != null) ContextMenuAction(
					child: const Text('Delete post'),
					trailingIcon: CupertinoIcons.delete,
					isDestructiveAction: true,
					onPressed: () async {
						await site.deletePost(latestPost.board, latestPost.threadId, receipt);
						// ignore: use_build_context_synchronously
						showToast(context: context, message: 'Deleted post /${latestPost.board}/${receipt.id}', icon: CupertinoIcons.delete);
					}
				),
				if (latestPost.attachments.isNotEmpty) ...buildImageSearchActions(context, () => whichAttachment(context, latestPost.attachments))
			],
			child: (replyIds.isNotEmpty) ? SliderBuilder(
				popup: PostsPage(
					postsIdsToShow: replyIds,
					postIdForBackground: latestPost.id,
					zone: parentZone.childZoneFor(latestPost.id)
				),
				builder: innerChild
			) : innerChild(context, 0.0)
		);
	}
}
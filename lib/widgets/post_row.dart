import 'package:chan/pages/selectable_post.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/notifications.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/widgets/popup_attachment.dart';
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
		final persistence = context.watch<Persistence>();
		final notifications = context.watch<Notifications>();
		final savedPost = persistence.getSavedPost(post);
		Post latestPost = savedPost?.post ?? post;
		if (latestPost.attachment?.url != post.attachment?.url) {
			latestPost.attachment = post.attachment;
			context.watch<Persistence>().didUpdateSavedPost();
		}
		else if (latestPost.replyIds.length != post.replyIds.length) {
			latestPost.replyIds = post.replyIds;
			context.watch<Persistence>().didUpdateSavedPost();
		}
		final zone = context.watch<PostSpanZoneData>();
		final settings = context.watch<EffectiveSettings>();
		final receipt = zone.threadState?.receipts.tryFirstWhere((r) => r.id == latestPost.id);
		final isYourPost = receipt != null || (zone.threadState?.postsMarkedAsYou.contains(post.id) ?? false);
		Border? border;
		if (isYourPost) {
			border = Border(
				left: BorderSide(color: CupertinoTheme.of(context).textTheme.actionTextStyle.color ?? Colors.red, width: 10)
			);
		}
		else if (zone.threadState?.replyIdsToYou(Filter.of(context))?.contains(post.id) ?? false) {
			border = Border(
				left: BorderSide(color: CupertinoTheme.of(context).textTheme.actionTextStyle.color?.towardsBlack(0.5) ?? const Color.fromARGB(255, 90, 30, 30), width: 10)
			);
		}
		final replyIds = latestPost.replyIds.toList();
		replyIds.removeWhere((id) {
			final replyPost = zone.thread.posts.tryFirstWhere((p) => p.id == id);
			if (replyPost != null) {
				if (Filter.of(context).filter(replyPost)?.type == FilterResultType.hide) {
					return true;
				}
			}
			return false;
		});
		String makeAttachmentInfo() {
			String text = '';
			if (settings.showFilenameOnPosts) {
				text += '${latestPost.attachment?.filename} ';
			}
			if (settings.showFilesizeOnPosts || settings.showFileDimensionsOnPosts) {
				text += '(';
				bool firstItemPassed = false;
				if (settings.showFilesizeOnPosts) {
					text += '${((latestPost.attachment?.sizeInBytes ?? 0) / 1024).round()} KB';
					firstItemPassed = true;
				}
				if (settings.showFileDimensionsOnPosts) {
					if (firstItemPassed) {
						text += ', ';
					}
					text += '${latestPost.attachment?.width}x${latestPost.attachment?.height}';
				}
				text += ') ';
			}
			return text;
		}
		openReplies() {
			if (replyIds.isNotEmpty) {
				WeakNavigator.push(context, PostsPage(
						postsIdsToShow: replyIds,
						postIdForBackground: latestPost.id,
						zone: zone.childZoneFor(latestPost.id)
					)
				);
			}
		}
		content(double factor) => PostSpanZone(
			postId: latestPost.id,
			builder: (ctx) => Padding(
				padding: const EdgeInsets.all(8),
				child: IgnorePointer(
					ignoring: !allowTappingLinks,
					child: ClippingBox(
						child: post.span.buildWidget(
							ctx,
							PostSpanRenderOptions(
								showCrossThreadLabel: showCrossThreadLabel,
								shrinkWrap: shrinkWrap,
							),
							postInject: (replyIds.isEmpty) ? null : TextSpan(
								text: List.filled(replyIds.length.toString().length + 4, '1').join(),
								style: const TextStyle(color: Colors.transparent)
							)
						)
					)
				)
			)
		);
		innerChild(BuildContext context, double slideFactor) {
			final mainRow = [
				const SizedBox(width: 8),
				if (latestPost.attachment != null && settings.showImages(context, latestPost.board)) Padding(
					padding: (settings.imagesOnRight && replyIds.isNotEmpty) ? const EdgeInsets.only(bottom: 32) : EdgeInsets.zero,
					child: PopupAttachment(
						attachment: latestPost.attachment!,
						child: GestureDetector(
							child: Stack(
								alignment: Alignment.center,
								fit: StackFit.loose,
								children: [
									AttachmentThumbnail(
										attachment: latestPost.attachment!,
										thread: latestPost.threadIdentifier,
										onLoadError: onThumbnailLoadError,
										hero: AttachmentSemanticLocation(
											attachment: latestPost.attachment!,
											semanticParents: zone.stackIds
										)
									),
									if (latestPost.attachment?.type == AttachmentType.webm) SizedBox(
										width: settings.thumbnailSize,
										height: settings.thumbnailSize,
										child: Center(
											child: AspectRatio(
												aspectRatio: (latestPost.attachment!.width ?? 1) / (latestPost.attachment!.height ?? 1),
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
								onThumbnailTap?.call(latestPost.attachment!);
							}
						)
					)
				)
				else if (latestPost.attachmentDeleted) Center(
					child: SizedBox(
						width: 75,
						height: 75,
						child: GestureDetector(
							behavior: HitTestBehavior.opaque,
							onTap: onRequestArchive,
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
			return GestureDetector(
				onTap: onTap,
				child: Container(
					padding: const EdgeInsets.only(bottom: 8),
					decoration: BoxDecoration(
						border: border,
						color: isSelected ? CupertinoTheme.of(context).primaryColorWithBrightness(0.4) : CupertinoTheme.of(context).scaffoldBackgroundColor,
					),
					child: Stack(
						children: [
							Column(
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
															if (settings.showNameOnPosts) TextSpan(
																text: context.read<EffectiveSettings>().filterProfanity(latestPost.name) + (isYourPost ? ' (You)' : ''),
																style: TextStyle(fontWeight: FontWeight.w600, color: isYourPost ? CupertinoTheme.of(context).textTheme.actionTextStyle.color : null)
															)
															else if (isYourPost) TextSpan(
																text: '(You)',
																style: TextStyle(fontWeight: FontWeight.w600, color: CupertinoTheme.of(context).textTheme.actionTextStyle.color)
															),
															if (settings.showTripOnPosts && latestPost.trip != null) TextSpan(
																text: '${context.read<EffectiveSettings>().filterProfanity(latestPost.trip!)} ',
																style: TextStyle(color: isYourPost ? CupertinoTheme.of(context).textTheme.actionTextStyle.color : null)
															)
															else if (settings.showNameOnPosts || isYourPost) const TextSpan(text: ' '),
															if (latestPost.posterId != null) ...[
																IDSpan(
																	id: latestPost.posterId!,
																	onPressed: () => WeakNavigator.push(context, PostsPage(
																		postsIdsToShow: zone.thread.posts.where((p) => p.posterId == latestPost.posterId).map((p) => p.id).toList(),
																		zone: zone
																	))
																),
																const TextSpan(text: ' ')
															],
															if (latestPost.attachment != null) ...[
																TextSpan(
																	text: makeAttachmentInfo(),
																	style: TextStyle(
																		color: CupertinoTheme.of(context).primaryColorWithBrightness(0.8)
																	)
																)
															],
															if (settings.showPassOnPosts && latestPost.passSinceYear != null) ...[
																PassSinceSpan(
																	sinceYear: latestPost.passSinceYear!,
																	site: site
																),
																const TextSpan(text: ' ')
															],
															if (latestPost.flag != null) ...[
																if (settings.showFlagOnPosts) ...[
																	FlagSpan(latestPost.flag!),
																	const TextSpan(text: ' ')
																],
																if (settings.showCountryNameOnPosts) TextSpan(
																	text: '${latestPost.flag!.name} ',
																	style: const TextStyle(
																		fontStyle: FontStyle.italic
																	)
																)
															],
															if (settings.showAbsoluteTimeOnPosts)	TextSpan(
																text: '${formatTime(latestPost.time)} '
															),
															if (settings.showRelativeTimeOnPosts) TextSpan(
																text: '${formatRelativeTime(latestPost.time)} ago '
															),
															TextSpan(
																text: latestPost.id.toString(),
																style: TextStyle(color: CupertinoTheme.of(context).primaryColor.withOpacity(0.5)),
																recognizer: TapGestureRecognizer()..onTap = () {
																	ctx.read<GlobalKey<ReplyBoxState>>().currentState?.onTapPostId(latestPost.id);
																}
															),
															if (supportMouse) ...[
																...replyIds.map((id) => PostQuoteLinkSpan(
																	board: latestPost.board,
																	threadId: latestPost.threadId,
																	postId: id,
																	dead: false
																).build(ctx, PostSpanRenderOptions(
																	showCrossThreadLabel: showCrossThreadLabel,
																	addExpandingPosts: false,
																	shrinkWrap: shrinkWrap
																))),
																...replyIds.map((id) => WidgetSpan(
																	child: ExpandingPost(id: id),
																))
															].expand((span) => [const TextSpan(text: ' '), span])
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
							),
							if (replyIds.isNotEmpty) Positioned.fill(
								child: Align(
									alignment: Alignment.bottomRight,
									child: CupertinoButton(
										alignment: Alignment.bottomRight,
										padding: const EdgeInsets.only(bottom: 8, right: 16),
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
							if (savedPost != null) Positioned.fill(
								child: Align(
									alignment: Alignment.topRight,
									child: Container(
										decoration: BoxDecoration(
											borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8)),
											color: CupertinoTheme.of(context).scaffoldBackgroundColor,
											border: Border.all(color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2))
										),
										padding: const EdgeInsets.only(top: 2, bottom: 2, left: 6, right: 6),
										child: const Icon(CupertinoIcons.bookmark_fill, size: 18)
									)
								)
							)
						]
					)
				)
			);
		}
		final child = ContextMenu(
			actions: [
				if (context.read<GlobalKey<ReplyBoxState>?>()?.currentState != null) ContextMenuAction(
					child: const Text('Reply'),
					trailingIcon: CupertinoIcons.reply,
					onPressed: () => context.read<GlobalKey<ReplyBoxState>>().currentState?.onTapPostId(post.id)
				),
				if (zone.stackIds.length > 2 && zone.onNeedScrollToPost != null) ContextMenuAction(
					child: const Text('Scroll to post'),
					trailingIcon: CupertinoIcons.return_icon,
					onPressed: () => zone.onNeedScrollToPost!(latestPost)
				),
				if (savedPost == null) ContextMenuAction(
					child: const Text('Save Post'),
					trailingIcon: CupertinoIcons.bookmark,
					onPressed: () {
						context.read<Persistence>().savePost(latestPost, zone.thread);
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
					if (isYourPost) ContextMenuAction(
							child: const Text('Unmark as You'),
							trailingIcon: CupertinoIcons.person_badge_minus,
							onPressed: () {
								zone.threadState!.receipts.removeWhere((r) => r.id == latestPost.id);
								zone.threadState!.postsMarkedAsYou.remove(latestPost.id);
								zone.threadState!.save();
							}
						)
					else ContextMenuAction(
							child: const Text('Mark as You'),
							trailingIcon: CupertinoIcons.person_badge_plus,
							onPressed: () async {
								zone.threadState!.postsMarkedAsYou.add(latestPost.id);
								await promptForPushNotificationsIfNeeded(context);
								notifications.subscribeToThread(zone.threadState!.identifier, zone.threadState!.thread?.posts.last.id ?? latestPost.id, notifications.getThreadWatch(zone.threadState!.identifier)?.yousOnly ?? true, zone.threadState!.youIds);
								zone.threadState!.save();
							}
						),
					if (zone.threadState!.hiddenPostIds.contains(latestPost.id)) ContextMenuAction(
						child: const Text('Unhide post'),
						trailingIcon: CupertinoIcons.eye_slash_fill,
						onPressed: () {
							zone.threadState!.unHidePost(latestPost.id);
							zone.threadState!.save();
						}
					)
					else ...[
						ContextMenuAction(
							child: const Text('Hide post'),
							trailingIcon: CupertinoIcons.eye_slash,
							onPressed: () {
								zone.threadState!.hidePost(latestPost.id);
								zone.threadState!.save();
							}
						),
						ContextMenuAction(
							child: const Text('Hide post and replies'),
							trailingIcon: CupertinoIcons.eye_slash,
							onPressed: () {
								zone.threadState!.hidePost(latestPost.id, tree: true);
								zone.threadState!.save();
							}
						),
					],
					if (latestPost.posterId != null && zone.threadState!.hiddenPosterIds.contains(latestPost.posterId)) ContextMenuAction(
						child: RichText(text: TextSpan(
							children: [
								const TextSpan(text: 'Unhide from '),
								IDSpan(id: latestPost.posterId!, onPressed: null)
							]
						)),
						trailingIcon: CupertinoIcons.eye_slash_fill,
						onPressed: () {
							zone.threadState!.unHidePosterId(latestPost.posterId!);
							zone.threadState!.save();
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
							zone.threadState!.hidePosterId(latestPost.posterId!);
							zone.threadState!.save();
						}
					),
					if (latestPost.attachment?.md5 != null && persistence.browserState.isMD5Hidden(latestPost.attachment?.md5)) ContextMenuAction(
						child: const Text('Unhide by image'),
						trailingIcon: CupertinoIcons.eye_slash_fill,
						onPressed: () {
							persistence.browserState.unHideByMD5(latestPost.attachment!.md5);
							persistence.didUpdateBrowserState();
							zone.threadState!.save();
						}
					)
					else if (latestPost.attachment?.md5 != null) ContextMenuAction(
						child: const Text('Hide by image'),
						trailingIcon: CupertinoIcons.eye_slash,
						onPressed: () {
							persistence.browserState.hideByMD5(latestPost.attachment!.md5);
							persistence.didUpdateBrowserState();
							zone.threadState!.save();
						}
					)
				],
				ContextMenuAction(
					child: const Text('Select text'),
					trailingIcon: CupertinoIcons.selection_pin_in_out,
					onPressed: () {
						WeakNavigator.push(context, SelectablePostPage(
							post: latestPost,
							zone: zone,
							onQuoteText: (text) => context.read<GlobalKey<ReplyBoxState>>().currentState?.onQuoteText(text, fromId: latestPost.id)
						));
					}
				),
				ContextMenuAction(
					child: const Text('Share link'),
					trailingIcon: CupertinoIcons.share,
					onPressed: () {
						final offset = (context.findRenderObject() as RenderBox?)?.localToGlobal(Offset.zero);
						final size = context.findRenderObject()?.semanticBounds.size;
						shareOne(
							text: site.getWebUrl(latestPost.board, latestPost.threadId, latestPost.id),
							type: "text",
							sharePositionOrigin: (offset != null && size != null) ? offset & size : null
						);
					}
				),
				ContextMenuAction(
					child: const Text('Report Post'),
					trailingIcon: CupertinoIcons.exclamationmark_octagon,
					onPressed: () {
						openBrowser(context, context.read<ImageboardSite>().getPostReportUrl(latestPost.board, latestPost.id));
					}
				),
				if (receipt != null) ContextMenuAction(
					child: const Text('Delete Post'),
					trailingIcon: CupertinoIcons.delete,
					isDestructiveAction: true,
					onPressed: () async {
						try {
							await site.deletePost(latestPost.board, receipt);
							showToast(context: context, message: 'Deleted post /${latestPost.board}/${receipt.id}', icon: CupertinoIcons.delete);
						}
						catch (error) {
							alertError(context, error.toStringDio());
						}
					}
				),
				if (latestPost.attachment != null) ...[
					ContextMenuAction(
						child: const Text('Search archives'),
						trailingIcon: Icons.image_search,
						onPressed: () {
							openSearch(context: context, query: ImageboardArchiveSearchQuery(boards: [latestPost.board], md5: latestPost.attachment!.md5));
						}
					),
					ContextMenuAction(
						child: const Text('Search Google'),
						trailingIcon: Icons.image_search,
						onPressed: () => openBrowser(context, Uri.https('www.google.com', '/searchbyimage', {
							'image_url': latestPost.attachment!.url.toString(),
							'safe': 'off'
						}))
					),
					ContextMenuAction(
						child: const Text('Search Yandex'),
						trailingIcon: Icons.image_search,
						onPressed: () => openBrowser(context, Uri.https('yandex.com', '/images/search', {
							'rpt': 'imageview',
							'url': latestPost.attachment!.url.toString()
						}))
					)
				]
			],
			child: (replyIds.isNotEmpty) ? SliderBuilder(
				popup: PostsPage(
					postsIdsToShow: replyIds,
					postIdForBackground: latestPost.id,
					zone: zone.childZoneFor(latestPost.id)
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
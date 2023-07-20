import 'package:chan/pages/selectable_post.dart';
import 'package:chan/services/delete_post.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/notifications.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/post_selection.dart';
import 'package:chan/services/posts_image.dart';
import 'package:chan/services/report_post.dart';
import 'package:chan/services/reverse_image_search.dart';
import 'package:chan/services/share.dart';
import 'package:chan/services/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/cupertino_inkwell.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/popup_attachment.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/pages/posts.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/context_menu.dart';
import 'package:chan/widgets/refreshable_list.dart';
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

class _PostHidingDialog extends StatefulWidget {
	final Post post;
	final PersistentThreadState threadState;
	final RefreshableListFilterReason? listFilterReason;

	const _PostHidingDialog({
		required this.post,
		required this.threadState,
		required this.listFilterReason
	});

	@override
	createState() => _PostHidingDialogState();
}

class _PostHidingDialogState extends State<_PostHidingDialog> {
	@override
	Widget build(BuildContext context) {
		return AdaptiveAlertDialog(
			title: const Text('Post Hiding'),
			content: Column(
				mainAxisSize: MainAxisSize.min,
				children: [
					const SizedBox(height: 16),
					if (widget.listFilterReason != null) ...[
						Text('This post has been filtered by another source:\n${widget.listFilterReason?.reason}\n\nYou can override that by setting "manual control" to "Show" below.'),
						const SizedBox(height: 16)
					],
					const Text('Manual control', style: TextStyle(fontSize: 17)),
					const SizedBox(height: 8),
					AdaptiveChoiceControl<PostHidingState>(
						knownWidth: 100,
						children: const {
							PostHidingState.none: (null, 'None'),
							PostHidingState.shown: (null, 'Show'),
							PostHidingState.hidden: (null, 'Hide'),
							PostHidingState.treeHidden: (null, 'Hide with replies')
						},
						groupValue: widget.threadState.getPostHiding(widget.post.id),
						onValueChanged: (newState) {
							widget.threadState.setPostHiding(widget.post.id, newState);
							widget.threadState.save();
							setState(() {});
						},
					),
					if (widget.post.posterId != null) Padding(
						padding: const EdgeInsets.all(16),
						child: Row(
							children: [
								Expanded(
									child: RichText(text: TextSpan(
										children: [
											const TextSpan(text: 'Hide from ', style: TextStyle(fontSize: 17)),
											IDSpan(id: widget.post.posterId!, onPressed: null)
										]
									))
								),
								Checkbox.adaptive(
									value: widget.threadState.hiddenPosterIds.contains(widget.post.posterId),
									onChanged: (value) {
										if (value!) {
											widget.threadState.hidePosterId(widget.post.posterId!);
											widget.threadState.save();
										}
										else {
											widget.threadState.unHidePosterId(widget.post.posterId!);
											widget.threadState.save();
										}
										setState(() {});
									}
								)
							]
						)
					),
					if (widget.post.attachments.isNotEmpty) ...[
						const SizedBox(height: 16),
						const Text('Hide by image', style: TextStyle(fontSize: 17))
					],
					for (final attachment in widget.post.attachments) Padding(
						padding: const EdgeInsets.all(8),
						child: Row(
							mainAxisAlignment: MainAxisAlignment.spaceBetween,
							children: [
								AttachmentThumbnail(
									attachment: attachment,
									width: 75,
									height: 75,
									mayObscure: false
								),
								Checkbox.adaptive(
									value: context.select<Settings, bool>((p) => p.isMD5Hidden(attachment.md5)),
									onChanged: attachment.md5.isEmpty ? null : (value) {
										if (value!) {
											Settings.instance.hideByMD5(attachment.md5);
										}
										else {
											Settings.instance.unHideByMD5(attachment.md5);
										}
										Settings.instance.didEdit();
										widget.threadState.save();
										setState(() {});
									}
								)
							]
						)
					)
				]
			),
			actions: [
				AdaptiveDialogAction(
					child: const Text('Close'),
					onPressed: () => Navigator.pop(context)
				)
			],
		);
	}
}

class PostRow extends StatelessWidget {
	final Post post;
	final ValueChanged<Attachment>? onThumbnailTap;
	final bool propagateOnThumbnailTap;
	final VoidCallback? onTap;
	final VoidCallback? onDoubleTap;
	final bool showCrossThreadLabel;
	final bool allowTappingLinks;
	final bool shrinkWrap;
	final bool isSelected;
	final void Function(Object?, StackTrace?)? onThumbnailLoadError;
	final PostSpanRenderOptions? baseOptions;
	final bool showSiteIcon;
	final bool showBoardName;
	final bool showYourPostBorder;
	final bool highlight;
	final Widget? overrideReplyCount;
	final bool showReplyCount;
	final bool dim;
	final bool showPostNumber;
	final double? largeImageWidth;
	final bool revealYourPosts;
	final bool revealSpoilerImages;
	final PostQuoteLinkSpan? expandedInlineWithin;
	final bool forceAbsoluteTime;

	const PostRow({
		required this.post,
		this.onTap,
		this.onDoubleTap,
		this.onThumbnailTap,
		this.propagateOnThumbnailTap = false,
		this.onThumbnailLoadError,
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
		this.showReplyCount = true,
		this.dim = false,
		this.showPostNumber = true,
		this.largeImageWidth,
		this.revealYourPosts = true,
		this.revealSpoilerImages = false,
		this.expandedInlineWithin,
		this.forceAbsoluteTime = false,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		if (post.isPageStub) {
			return Padding(
				padding: const EdgeInsets.all(4),
				child: Row(
					mainAxisAlignment: MainAxisAlignment.center,
					children: [
						const Icon(CupertinoIcons.doc, size: 16),
						const SizedBox(width: 8),
						Flexible(
							child: Text(
								'Page ${post.id.abs()}',
								textAlign: TextAlign.center,
								style: const TextStyle(
									fontSize: 16
								)
							)
						)
					]
				)
			);
		}
		final rootContext = context;
		final imageboard = context.watch<Imageboard>();
		final site = imageboard.site;
		final notifications = context.watch<Notifications>();
		final savedPost = context.select<Persistence, SavedPost?>((p) => p.getSavedPost(post));
		Post latestPost = savedPost?.post ?? post;
		bool didUpdateAttachments = false;
		for (int i = 0; i < latestPost.attachments_.length; i++) {
			final attachment = post.attachments_.tryFirstWhere((a) => a.id == latestPost.attachments_[i].id);
			if (attachment != null && attachment.url != latestPost.attachments_[i].url) {
				latestPost.attachments_[i] = attachment;
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
		final settings = context.watch<Settings>();
		final theme = context.watch<SavedTheme>();
		final parentZoneThreadState = parentZone.imageboard.persistence.getThreadStateIfExists(post.threadIdentifier);
		final receipt = parentZoneThreadState?.receipts.tryFirstWhere((r) => r.id == latestPost.id);
		final isYourPost = revealYourPosts && (receipt?.markAsYou ?? false) || (parentZoneThreadState?.postsMarkedAsYou.contains(post.id) ?? false);
		Border? border;
		final largeImageWidth = this.largeImageWidth ?? settings.centeredPostThumbnailSize;
		// These use attachments_ on purpose to avoid pulling out inlines
		final List<Attachment> largeAttachments = largeImageWidth == null ? [] : latestPost.attachments_;
		final List<Attachment> smallAttachments = largeImageWidth == null ? latestPost.attachments_ : [];
		final withinSelectable = SelectionContainer.maybeOf(context) != null;
		if (isYourPost && showYourPostBorder) {
			border = Border(
				left: BorderSide(color: theme.secondaryColor, width: 10)
			);
		}
		else if (parentZoneThreadState?.replyIdsToYou()?.contains(post.id) ?? false) {
			border = Border(
				left: BorderSide(color: theme.secondaryColor.towardsBlack(0.5), width: 10)
			);
		}
		final replyIds = latestPost.replyIds.toList();
		replyIds.removeWhere((id) {
			final replyPost = parentZone.findPost(id);
			if (replyPost != null) {
				if (Filter.of(context).filter(imageboard.key, replyPost)?.type.hide == true) {
					return true;
				}
			}
			return false;
		});
		if (post.threadId != parentZone.primaryThreadId) {
			// This post is from an old thread.
			// Add replyIds from the main thread.
			replyIds.addAll(parentZone.findThread(parentZone.primaryThreadId)?.posts.expand((p) sync* {
				if (p.repliedToIds.contains(post.id)) {
					yield p.id;
				}
			}) ?? []);
		}
		final backgroundColor = isSelected ?
			theme.primaryColor.withOpacity(0.25) :
			highlight ?
				theme.primaryColor.withOpacity(settings.newPostHighlightBrightness) :
				Colors.transparent;
		final listFilterReason = context.watch<RefreshableListFilterReason?>();
		final isPostHiddenByThreadState = switch(parentZoneThreadState?.getPostHiding(latestPost.id)) {
			PostHidingState.shown => false,
			PostHidingState.hidden || PostHidingState.treeHidden => true,
			_ => null
		} ?? (
			(parentZoneThreadState?.hiddenPosterIds.contains(latestPost.posterId) ?? false) ||
			settings.areMD5sHidden(latestPost.md5s)
		);
		final isPostHidden = isPostHiddenByThreadState || listFilterReason != null;
		final cloverStyleRepliesButton = (settings.cloverStyleRepliesButton && replyIds.isNotEmpty && parentZone.style != PostSpanZoneStyle.tree);
		openReplies() {
			if (replyIds.isNotEmpty) {
				WeakNavigator.push(context, PostsPage(
					postsIdsToShow: replyIds,
					postIdForBackground: latestPost.id,
					zone: parentZone.childZoneFor(latestPost.id),
					isRepliesForPostId: latestPost.id,
					onThumbnailTap: propagateOnThumbnailTap ? onThumbnailTap : null,
				));
			}
		}
		final Widget? attachments;
		if (smallAttachments.isNotEmpty && settings.showImages(context, latestPost.board)) {
			attachments = Padding(
				padding: settings.imagesOnRight ? const EdgeInsets.only(left: 8) : const EdgeInsets.only(right: 8),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					mainAxisSize: MainAxisSize.min,
					children: [
						...smallAttachments.map((attachment) => PopupAttachment(
							attachment: attachment,
							child: CupertinoButton(
								padding: EdgeInsets.zero,
								minSize: 0,
								onPressed: bind1(onThumbnailTap, attachment),
								child: ConstrainedBox(
									constraints: const BoxConstraints(
										minHeight: 51
									),
									child: AttachmentThumbnail(
										attachment: attachment,
										revealSpoilers: revealSpoilerImages,
										thread: latestPost.threadIdentifier,
										onLoadError: onThumbnailLoadError,
										hero: TaggedAttachment(
											attachment: attachment,
											semanticParentIds: parentZone.stackIds
										),
										fit: settings.squareThumbnails ? BoxFit.cover : BoxFit.contain,
										shrinkHeight: !settings.squareThumbnails,
										mayObscure: true,
										cornerIcon: AttachmentThumbnailCornerIcon(
											backgroundColor: theme.backgroundColor,
											borderColor: theme.primaryColorWithBrightness(0.2),
											size: null
										)
									)
								)
							))
						).expand((x) => [x, const SizedBox(height: 8)])
					]
				)
			);
		}
		else if (latestPost.attachmentDeleted) {
			attachments = SizedBox(
				width: 75,
				height: 75,
				child:
					parentZone.isLoadingPostFromArchive(post.board, post.id) ?
						const CircularProgressIndicator.adaptive() :
						switch (parentZone.postFromArchiveError(post.board, post.id)) {
							(Object error, StackTrace stackTrace) => CupertinoInkwell(
								onPressed: () => alertError(context, error, stackTrace, actions: {
									'Retry': () => parentZone.loadPostFromArchive(post.board, post.id)
								}),
								child: const Icon(CupertinoIcons.exclamationmark_triangle, size: 36)
							),
							null => CupertinoInkwell(
								onPressed: () => parentZone.loadPostFromArchive(post.board, post.id),
								child: const Icon(CupertinoIcons.xmark_square, size: 36)
							)
						}
			);
		}
		else {
			attachments = null;
		}
		final content = Builder(
			builder: (ctx) => Padding(
				padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
				child: ConditionalOnTapUp(
					condition: (d) => allowTappingLinks && ctx.read<PostSpanZoneData>().canTap(d.position),
					onTapUp: (d) {
						if (!ctx.read<PostSpanZoneData>().onTap(d.globalPosition)) {
							onTap?.call();
						}
					},
					child: Text.rich(
						TextSpan(
							children: [
								if (attachments != null) WidgetSpan(
									child: attachments,
									floating: settings.imagesOnRight ? PlaceholderFloating.right : PlaceholderFloating.left,
									alignment: latestPost.span.hasVeryTallWidgetSpan ? PlaceholderAlignment.top : PlaceholderAlignment.middle
								),
								if (
									// The site uses parentIds
									!site.explicitIds &&
									// The post has a parentId
									post.parentId != null &&
									// The parentId is not obvious based on context
									post.parentId != parentZone.stackIds.tryLast
								) ...[
									PostQuoteLinkSpan(
										board: latestPost.board,
										threadId: latestPost.threadId,
										postId: latestPost.parentId!,
										key: const ValueKey('parentId op quotelink')
									).build(
										ctx, ctx.watch<PostSpanZoneData>(), settings, theme, (baseOptions ?? const PostSpanRenderOptions()).copyWith(
											shrinkWrap: shrinkWrap,
											ignorePointer: !allowTappingLinks
										)
									),
									const TextSpan(text: '\n'),
								],
								(translatedPostSnapshot?.data ?? latestPost).span.build(
									ctx, ctx.watch<PostSpanZoneData>(), settings, theme,
									(baseOptions ?? const PostSpanRenderOptions()).copyWith(
										showCrossThreadLabel: showCrossThreadLabel,
										shrinkWrap: shrinkWrap,
										onThumbnailTap: onThumbnailTap,
										propagateOnThumbnailTap: propagateOnThumbnailTap,
										onThumbnailLoadError: onThumbnailLoadError,
										revealSpoilerImages: revealSpoilerImages,
										addExpandingPosts: settings.supportMouse != TristateSystemSetting.a,
										ignorePointer: !allowTappingLinks,
										postInject: showReplyCount ? (overrideReplyCount != null ? WidgetSpan(
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
										) : ((settings.cloverStyleRepliesButton || replyIds.isEmpty) ? null : WidgetSpan(
											child: SizedBox(width: (4 + replyIds.length.toString().length) * 8),
											floating: PlaceholderFloating.right
										))) : null
									)
								),
								const TextSpan(text: '\n'),
								// In practice this is the height of a line of text
								const WidgetSpan(
									child: SizedBox.shrink()
								)
							]
						),
						overflow: TextOverflow.fade
					)
				)
			)
		);
		innerChild(BuildContext context, double slideFactor) {
			final mainRow = [
				const SizedBox(width: 8),
				if (shrinkWrap) Flexible(
					child: content
				)
				else Expanded(
					child: content
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
						color: backgroundColor,
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
										Row(
											children: [
												Expanded(
													child: Padding(
														padding: const EdgeInsets.only(left: 8, right: 8),
														child: Consumer<MouseSettings>(
															builder: (ctx, mouseSettings, child) => Text.rich(
																TextSpan(
																	children: [
																		buildPostInfoRow(
																			post: latestPost,
																			isYourPost: isYourPost,
																			showSiteIcon: showSiteIcon,
																			showBoardName: showBoardName,
																			settings: settings,
																			theme: theme,
																			site: site,
																			context: context,
																			zone: ctx.watch<PostSpanZoneData>(),
																			showPostNumber: showPostNumber,
																			forceAbsoluteTime: forceAbsoluteTime,
																			propagatedOnThumbnailTap: baseOptions?.propagateOnThumbnailTap == true ? onThumbnailTap : null,
																			interactive: allowTappingLinks
																		),
																		if (mouseSettings.supportMouse) ...replyIds.map((id) => PostQuoteLinkSpan(
																			board: latestPost.board,
																			threadId: latestPost.threadId,
																			postId: id,
																			key: ValueKey('replyId $id')
																		)).expand((link) => [
																			link.build(ctx, ctx.watch<PostSpanZoneData>(), settings, theme, (baseOptions ?? const PostSpanRenderOptions()).copyWith(
																				showCrossThreadLabel: showCrossThreadLabel,
																				addExpandingPosts: false,
																				shrinkWrap: shrinkWrap,
																				ignorePointer: !allowTappingLinks
																			)),
																			WidgetSpan(
																				child: ExpandingPost(link: link),
																			),
																			const TextSpan(text: ' ')
																		])
																	]
																)
															)
														)
													)
												),
												Builder(
													builder: (context) {
														final zone = context.watch<ContextMenuHint?>();
														if (zone == null || zone.mode == ContextMenuHintMode.longPressEnabled) {
															return const SizedBox.shrink();
														}
														return Padding(
															padding: const EdgeInsets.only(right: 12),
															child: AdaptiveIconButton(
																icon: SelectionContainer.disabled(
																	child: Text.rich(
																		TextSpan(
																			text: String.fromCharCode(CupertinoIcons.ellipsis.codePoint),
																			style: TextStyle(
																				fontSize: 24.0,
																				fontFamily: CupertinoIcons.ellipsis.fontFamily,
																				package: CupertinoIcons.ellipsis.fontPackage,
																				height: 0.7
																			),
																		),
																	),
																),
																minSize: 0,
																padding: const EdgeInsets.symmetric(horizontal: 4),
																onPressed: zone.mode == ContextMenuHintMode.longPressDisabled ? () {
																	zone.open(
																		from: context.globalPaintBounds
																	);
																} : null
															)
														);
													}
												)
											]
										),
										if (largeAttachments.isNotEmpty && settings.showImages(context, latestPost.board)) ...largeAttachments.map((a) => Align(
											child: Padding(
												padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
												child: CupertinoInkwell(
													padding: EdgeInsets.zero,
													minSize: 0,
													onPressed: bind1(onThumbnailTap, a),
													child: AttachmentThumbnail(
														attachment: a,
														revealSpoilers: revealSpoilerImages,
														onLoadError: onThumbnailLoadError,
														thread: latestPost.threadIdentifier,
														width: largeImageWidth,
														height: largeImageWidth,
														shrinkHeight: true,
														overrideFullQuality: true,
														mayObscure: true,
														hero: TaggedAttachment(
															attachment: a,
															semanticParentIds: parentZone.stackIds
														),
														cornerIcon: AttachmentThumbnailCornerIcon(
															backgroundColor: theme.backgroundColor,
															borderColor: theme.primaryColorWithBrightness(0.2),
															size: (largeImageWidth ?? 300) / 10
														)
													)
												)
											)
										))
										else const SizedBox(height: 2),
										Flexible(
											child: Row(
												crossAxisAlignment: CrossAxisAlignment.start,
												mainAxisAlignment: MainAxisAlignment.start,
												mainAxisSize: MainAxisSize.min,
												children: mainRow
											)
										),
										if (cloverStyleRepliesButton) SizedBox(
											height: 24 * settings.textScale
										)
									]
								)
							),
							if (showReplyCount)
								if (overrideReplyCount != null) Positioned.fill(
									child: Align(
										alignment: Alignment.bottomRight,
										child: DecoratedBox(
											decoration: BoxDecoration(
												gradient: LinearGradient(
													begin: Alignment.centerRight,
													end: Alignment.centerLeft,
													colors: [
														Color.alphaBlend(backgroundColor, theme.backgroundColor),
														Color.alphaBlend(backgroundColor, theme.backgroundColor).withOpacity(0)
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
								else if (cloverStyleRepliesButton) Positioned.fill(
									child: Align(
										alignment: Alignment.bottomLeft,
										child: AdaptiveIconButton(
											padding: EdgeInsets.zero,
											minSize: 0,
											onPressed: openReplies,
											icon: SizedBox(
												width: double.infinity,
												child: Padding(
													padding: const EdgeInsets.only(left: 16, bottom: 16),
													child: SelectionContainer.disabled(
														child: Text(
															describeCount(replyIds.length, 'reply', plural: 'replies'),
															style: TextStyle(
																fontSize: 17 + (7 * slideFactor.clamp(0, 1)),
																color: theme.primaryColor.withOpacity(0.7)
															)
														)
													)
												)
											)
										)
									)
								)
								else if (!settings.cloverStyleRepliesButton && replyIds.isNotEmpty) Positioned.fill(
									child: Align(
										alignment: Alignment.bottomRight,
										child: CupertinoInkwell(
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
															color: theme.secondaryColor,
															size: 14
														),
														const SizedBox(width: 4),
														SelectionContainer.disabled(
															child: Text(
																replyIds.length.toString(),
																style: TextStyle(
																	color: theme.secondaryColor,
																	fontWeight: FontWeight.bold,
																	fontVariations: CommonFontVariations.bold
																)
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
												color: theme.backgroundColor,
												border: Border.all(color: theme.primaryColorWithBrightness(0.2))
											),
											padding: const EdgeInsets.only(top: 2, bottom: 2, left: 6, right: 6),
											child: Row(
												mainAxisSize: MainAxisSize.min,
												children: [
													if (translatedPostSnapshot != null) const Icon(Icons.translate),
													if (translatedPostSnapshot?.hasError ?? false) GestureDetector(
														onTap: () => alertError(context, translatedPostSnapshot?.error?.toStringDio() ?? 'Unknown', translatedPostSnapshot?.stackTrace),
														child: const Icon(CupertinoIcons.exclamationmark_triangle)
													)
													else if (translatedPostSnapshot?.hasData == false) const CircularProgressIndicator.adaptive(),
													if (savedPost != null) Icon(Adaptive.icons.bookmarkFilled, size: 18)
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
		final replyBoxZone = context.watch<ReplyBoxZone?>();
		final imageSearchActions = buildImageSearchActions(context, latestPost.attachments);
		return ContextMenu(
			backgroundColor: theme.backgroundColor,
			enableLongPress: !withinSelectable,
			contextMenuBuilderBuilder: replyBoxZone == null ? makeGeneralContextMenuBuilder : (getSelection) => makePostContextMenuBuilder(
				zone: parentZone,
				replyBoxZone: replyBoxZone,
				context: context,
				post: latestPost,
				getSelection: getSelection
			),
			actions: [
				if (site.supportsPosting && replyBoxZone != null) ContextMenuAction(
					child: const Text('Reply'),
					trailingIcon: CupertinoIcons.reply,
					onPressed: () => replyBoxZone.onTapPostId(post.threadId, post.id)
				),
				ContextMenuAction(
					child: const Text('Quotelink all'),
					trailingIcon: CupertinoIcons.reply_all,
					onPressed: () {
						// Remove single-line quotelinks
						replyBoxZone?.onQuoteText(latestPost.span.buildText().replaceAll(RegExp(r'^>>\d+\n', multiLine: true), ''), backlink: latestPost.identifier);
					}
				),
				ContextMenuAction(
					child: const Text('Select text'),
					trailingIcon: CupertinoIcons.selection_pin_in_out,
					onPressed: () {
						WeakNavigator.push(context, SelectablePostPage(
							post: latestPost,
							zone: parentZone,
							onQuoteText: (String text, {required bool includeBacklink}) => context.read<ReplyBoxZone>().onQuoteText(text, backlink: includeBacklink ? latestPost.identifier : null)
						));
					}
				),
				ContextMenuAction(
					child: const Text('Share text'),
					trailingIcon: Adaptive.icons.share,
					onPressed: () async {
						await shareOne(
							context: context,
							text: (translatedPostSnapshot?.data ?? latestPost).span.buildText(),
							type: "text",
							sharePositionOrigin: rootContext.globalSemanticBounds
						);
					}
				),
				if (parentZone.style != PostSpanZoneStyle.tree && parentZone.stackIds.length > 2 && parentZone.onNeedScrollToPost != null) ContextMenuAction(
					child: const Text('Scroll to post'),
					trailingIcon: CupertinoIcons.return_icon,
					onPressed: () => parentZone.onNeedScrollToPost!(latestPost)
				),
				if (savedPost == null) ContextMenuAction(
					child: const Text('Save post'),
					trailingIcon: Adaptive.icons.bookmark,
					onPressed: () {
						context.read<Persistence>().savePost(latestPost);
					}
				)
				else ContextMenuAction(
					child: const Text('Unsave post'),
					trailingIcon: Adaptive.icons.bookmarkFilled,
					onPressed: () {
						final persistence = context.read<Persistence>();
						persistence.unsavePost(post);
						showUndoToast(
							context: context,
							message: 'Unsaved post',
							onUndo: () {
								persistence.savePost(latestPost);
							}
						);
					}
				),
				if (parentZoneThreadState != null) ...[
					if (isYourPost) ContextMenuAction(
							child: const Text('Unmark as You'),
							trailingIcon: CupertinoIcons.person_badge_minus,
							onPressed: () async {
								for (final r in parentZoneThreadState.receipts) {
									if (r.id == latestPost.id) {
										r.markAsYou = false;
									}
								}
								parentZoneThreadState.postsMarkedAsYou.remove(latestPost.id);
								final posterId = post.posterId;
								if (posterId != null) {
									final toUnmark = <int>{};
									for (final otherPost in parentZone.findThread(post.threadId)?.posts ?? <Post>[]) {
										if (otherPost.id != post.id && otherPost.posterId == posterId && parentZoneThreadState.youIds.contains(otherPost.id)) {
											toUnmark.add(otherPost.id);
										}
									}
									if (toUnmark.isNotEmpty) {
										final confirmed = await confirm(
											context,
											toUnmark.length == 1
												? 'There is one other marked post in this thread with the same ID ($posterId). Unmark it as (You) too?'
												: 'There are ${toUnmark.length} other marked posts in this thread with the same ID ($posterId). Unmark them as (You) too?',
											actionName: 'Unmark'
										);
										if (confirmed) {
											parentZoneThreadState.postsMarkedAsYou.removeWhere(toUnmark.contains);
											for (final r in parentZoneThreadState.receipts) {
												if (toUnmark.remove(r.id)) {
													r.markAsYou = false;
												}
											}
										}
									}
								}
								parentZoneThreadState.didUpdateYourPosts();
								parentZoneThreadState.save();
							}
						)
					else ContextMenuAction(
						child: const Text('Mark as You'),
						trailingIcon: CupertinoIcons.person_badge_plus,
						onPressed: () async {
							bool markedReceipt = false;
							for (final r in parentZoneThreadState.receipts) {
								if (r.id == latestPost.id) {
									r.markAsYou = true;
									markedReceipt = true;
								}
							}
							if (!markedReceipt) {
								parentZoneThreadState.postsMarkedAsYou.add(latestPost.id);
							}
							final posterId = post.posterId;
							if (posterId != null) {
								final toMark = <int>{};
								for (final otherPost in parentZone.findThread(post.threadId)?.posts ?? <Post>[]) {
									if (otherPost.id != post.id && otherPost.posterId == posterId && !parentZoneThreadState.youIds.contains(otherPost.id)) {
										toMark.add(otherPost.id);
									}
								}
								if (toMark.isNotEmpty) {
									final confirmed = await confirm(
										context,
										toMark.length == 1
											? 'There is one other unmarked post in this thread with the same ID ($posterId). Mark it as (You) too?'
											: 'There are ${toMark.length} other unmarked posts in this thread with the same ID ($posterId). Mark them as (You) too?',
										actionName: 'Mark'
									);
									if (confirmed) {
										for (final id in toMark) {
											final existingReceipt = parentZoneThreadState.receipts.tryFirstWhere((r) => r.id == id);
											if (existingReceipt != null) {
												existingReceipt.markAsYou = true;
											}
											else {
												parentZoneThreadState.postsMarkedAsYou.add(id);
											}
										}
									}
								}
							}
							parentZoneThreadState.didUpdateYourPosts();
							if (settings.watchThreadAutomaticallyWhenReplying) {
								if (site.supportsPushNotifications && context.mounted) {
									await promptForPushNotificationsIfNeeded(context);
								}
								notifications.subscribeToThread(
									thread: parentZoneThreadState.identifier,
									lastSeenId: parentZoneThreadState.thread?.posts.last.id ?? latestPost.id,
									localYousOnly: (parentZoneThreadState.threadWatch ?? settings.defaultThreadWatch)?.localYousOnly ?? true,
									pushYousOnly: (parentZoneThreadState.threadWatch ?? settings.defaultThreadWatch)?.pushYousOnly ?? true,
									foregroundMuted: (parentZoneThreadState.threadWatch ?? settings.defaultThreadWatch)?.foregroundMuted ?? false,
									push: (parentZoneThreadState.threadWatch ?? settings.defaultThreadWatch)?.push ?? true,
									youIds: parentZoneThreadState.freshYouIds(),
									notifyOnSecondLastPage: (parentZoneThreadState.threadWatch ?? settings.defaultThreadWatch)?.notifyOnSecondLastPage ?? false,
									notifyOnLastPage: (parentZoneThreadState.threadWatch ?? settings.defaultThreadWatch)?.notifyOnLastPage ?? true,
									notifyOnDead: (parentZoneThreadState.threadWatch ?? settings.defaultThreadWatch)?.notifyOnDead ?? false
								);
							}
							parentZoneThreadState.save();
						}
					),
					if (isPostHiddenByThreadState) ContextMenuAction(
						child: const Text('Unhide post'),
						trailingIcon: CupertinoIcons.eye_slash_fill,
						onPressed: () {
							parentZoneThreadState.setPostHiding(latestPost.id, PostHidingState.none);
							parentZoneThreadState.save();
						}
					)
					else ...[
						ContextMenuAction(
							child: const Text('Hide post'),
							trailingIcon: CupertinoIcons.eye_slash,
							onPressed: () {
								parentZoneThreadState.setPostHiding(latestPost.id, PostHidingState.hidden);
								parentZoneThreadState.save();
							}
						),
						ContextMenuAction(
							child: const Text('Hide post and replies'),
							trailingIcon: CupertinoIcons.eye_slash,
							onPressed: () {
								parentZoneThreadState.setPostHiding(latestPost.id, PostHidingState.treeHidden);
								parentZoneThreadState.save();
							}
						),
					],
					ContextMenuAction(
						child: isPostHidden ? const Text('Unhide...') : const Text('Hide...'),
						trailingIcon: isPostHidden ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
						onPressed: () {
							final imageboard = context.read<Imageboard>();
							showAdaptiveDialog(
								barrierDismissible: true,
								context: context,
								builder: (context) => ImageboardScope(
									imageboardKey: null,
									imageboard: imageboard,
									child: _PostHidingDialog(
										post: latestPost,
										threadState: parentZoneThreadState,
										listFilterReason: isPostHiddenByThreadState ? null : listFilterReason
									)
								)
							);
						}
					)
				],
				ContextMenuAction(
					child: const Text('Share link'),
					trailingIcon: Adaptive.icons.share,
					onPressed: () async {
						await shareOne(
							context: context,
							text: site.getWebUrl(
								board: latestPost.board,
								threadId: latestPost.threadId,
								postId: latestPost.id,
								archiveName: latestPost.archiveName ?? parentZoneThreadState?.thread?.archiveName
							),
							type: "text",
							sharePositionOrigin: rootContext.globalSemanticBounds
						);
					}
				),
				ContextMenuAction(
					child: const Text('Share as image'),
					trailingIcon: Adaptive.icons.photo,
					onPressed: () async {
						final style = await composeShareablePostsStyle(context: context, post: post);
						if (style == null) {
							return;
						}
						if (context.mounted) {
							try {
								final file = await modalLoad(context, 'Rendering...', (c) => sharePostsAsImage(context: context, primaryPostId: post.id, style: style));
								if (context.mounted) {
									shareOne(
										context: context,
										text: file.path,
										type: 'file',
										sharePositionOrigin: null
									);
								}
							}
							catch (e, st) {
								Future.error(e, st); // Report to crashlytics
								if (context.mounted) {
									alertError(context, e, st);
								}
							}
						}
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
							await parentZone.translatePost(post);
						}
						catch (e, st) {
							if (context.mounted) {
								alertError(context, e, st);
							}
						}
					}
				),
				ContextMenuAction(
					child: const Text('Report post'),
					trailingIcon: CupertinoIcons.exclamationmark_octagon,
					onPressed: () => reportPost(
						context: context,
						site: site,
						post: latestPost.identifier
					)
				),
				if (receipt != null) ...[
					if (!latestPost.attachmentDeleted && latestPost.attachments.isNotEmpty) ContextMenuAction(
						child: Text('Delete ${latestPost.attachments.tryFirst?.type.noun}${latestPost.attachments.length > 1 ? 's' : ''}'),
						trailingIcon: CupertinoIcons.delete,
						isDestructiveAction: true,
						onPressed: () => deletePost(
							context: context,
							imageboard: context.read<Imageboard>(),
							thread: latestPost.threadIdentifier,
							receipt: receipt,
							imageOnly: true
						)
					),
					ContextMenuAction(
						child: const Text('Delete post'),
						trailingIcon: CupertinoIcons.delete,
						isDestructiveAction: true,
						onPressed: () => deletePost(
							context: context,
							imageboard: context.read<Imageboard>(),
							thread: latestPost.threadIdentifier,
							receipt: receipt,
							imageOnly: false
						)
					)
				],
				if (latestPost.attachments.isNotEmpty) ContextMenuAction(
					child: Text('Share ${latestPost.attachments.first.type.noun} link'),
					trailingIcon: CupertinoIcons.link,
					onPressed: () async {
						final which = await whichAttachment(context, latestPost.attachments);
						if (which == null || !context.mounted) {
							return;
						}
						await shareOne(
							context: context,
							text: which.url,
							type: "text",
							sharePositionOrigin: rootContext.globalSemanticBounds
						);
					}
				),
				if (imageSearchActions.length == 1) imageSearchActions.first
				else if (imageSearchActions.length > 1) ContextMenuAction(
					child: const Text('Search image'),
					trailingIcon: Icons.image_search,
					onPressed: () async {
						await showAdaptiveModalPopup(
							context: context,
							builder: (context) => AdaptiveActionSheet(
								actions: imageSearchActions.toActionSheetActions(context),
								cancelButton: AdaptiveActionSheetAction(
									onPressed: () => Navigator.pop(context),
									child: const Text('Cancel')
								)
							)
						);
					}
				)
			],
			child: PostSpanZone(
				postId: latestPost.id,
				link: expandedInlineWithin,
				style: expandedInlineWithin != null ? PostSpanZoneStyle.expandedInline : null,
				child: (replyIds.isNotEmpty) ? SliderBuilder(
					popup: PostsPage(
						postsIdsToShow: replyIds,
						postIdForBackground: latestPost.id,
						zone: parentZone.childZoneFor(latestPost.id),
						isRepliesForPostId: latestPost.id,
						onThumbnailTap: propagateOnThumbnailTap ? onThumbnailTap : null
					),
					cancelable: settings.cancellableRepliesSlideGesture,
					builder: innerChild
				) : innerChild(context, 0.0)
			)
		);
	}
}
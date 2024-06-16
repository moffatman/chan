import 'dart:math';
import 'dart:ui';

import 'package:chan/models/attachment.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/screen_size_hacks.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/context_menu.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/popup_attachment.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/thread_spans.dart';
import 'package:chan/widgets/util.dart';
import 'package:chan/widgets/widget_decoration.dart';
import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import 'package:chan/models/thread.dart';

class ThreadCounters extends StatelessWidget {
	final Imageboard imageboard;
	final Thread thread;
	final PersistentThreadState? threadState;
	final bool showPageNumber;
	final bool countsUnreliable;
	final bool showChrome;
	final Alignment alignment;
	final bool showUnseenColors;
	final bool showUnseenCounters;
	final bool? forceShowInHistory;

	const ThreadCounters({
		required this.imageboard,
		required this.thread,
		required this.threadState,
		this.showPageNumber = false,
		required this.countsUnreliable,
		this.showChrome = true,
		required this.alignment,
		this.showUnseenColors = true,
		this.showUnseenCounters = true,
		this.forceShowInHistory,
		super.key
	});

	@override
	Widget build(BuildContext context) {
		final site = imageboard.site;
		final settings = context.watch<Settings>();
		final theme = context.watch<SavedTheme>();
		final latestThread = threadState?.thread ?? thread;
		final int latestReplyCount = max(max(thread.replyCount, latestThread.replyCount), latestThread.posts_.length - 1);
		final int latestImageCount = (thread.isSticky && latestReplyCount == 1000) ? latestThread.imageCount : max(thread.imageCount, latestThread.imageCount);
		int unseenReplyCount = 0;
		int unseenYouCount = 0;
		int unseenImageCount = 0;
		final grey = theme.primaryColorWithBrightness(0.6);
		Color? replyCountColor;
		Color? imageCountColor;
		Color? otherMetadataColor;
		final threadSeen = threadState?.lastSeenPostId != null && (forceShowInHistory ?? (threadState?.showInHistory ?? false));
		bool showReplyTimeInsteadOfReplyCount = false;
		if (site.isPaged) {
			showReplyTimeInsteadOfReplyCount = thread.posts_.tryFirst?.time != thread.posts_.tryLast?.time;
			final catalogLastTime = thread.posts_.tryLast?.time;
			final threadLastTime = threadState?.thread?.posts_.tryLast?.time;
			if (catalogLastTime != null &&
			    threadLastTime != null &&
					!catalogLastTime.isAfter(threadLastTime)) {
				// No new posts
				replyCountColor = grey;
				otherMetadataColor = grey;
				imageCountColor = grey;
			}
		}
		else if (threadSeen && showUnseenCounters) {
			if (threadState?.useTree ?? imageboard.persistence.browserState.useTree ?? site.useTree) {
				unseenReplyCount = (threadState?.unseenReplyCount() ?? 0) + (max(thread.replyCount, latestThread.replyCount) - (threadState!.thread?.replyCount ?? 0));
			}
			else {
				unseenReplyCount = (threadState?.unseenReplyCount() ?? 0) + ((latestReplyCount + 1) - latestThread.posts_.length);
			}
			unseenYouCount = threadState?.unseenReplyIdsToYouCount() ?? 0;
			unseenImageCount = (threadState?.unseenImageCount() ?? 0) + ((latestImageCount + thread.attachments.length) - (threadState?.thread?.posts_.expand((x) => x.attachments).length ?? 0));
			replyCountColor = unseenReplyCount <= 0 ? grey : null;
			imageCountColor = unseenImageCount <= 0 ? grey : null;
			otherMetadataColor = unseenReplyCount <= 0 && unseenImageCount <= 0 ? grey : null;
		}
		else if (!showUnseenColors) {
			replyCountColor = grey;
			imageCountColor = grey;
			otherMetadataColor = grey;
		}
		final children = [
			if (threadState?.youIds.contains(thread.id) ?? false) ...[
				Text(
					'(You)',
					style: TextStyle(
						fontWeight: FontWeight.w600,
						color: theme.secondaryColor
					)
				),
				const SizedBox(width: 4)
			],
			if (thread.isSticky) ... [
				Icon(CupertinoIcons.pin, color: otherMetadataColor, size: 18),
				const SizedBox(width: 4),
			],
			if (latestThread.isArchived) ... [
				Icon(CupertinoIcons.archivebox, color: grey, size: 18),
				const SizedBox(width: 4),
			],
			if (latestThread.isDeleted) ... [
				Icon(CupertinoIcons.trash, color: grey, size: 18),
				const SizedBox(width: 4),
			],
			if (showPageNumber && latestThread.currentPage != null) ...[
				Icon(CupertinoIcons.doc, size: 18, color: otherMetadataColor),
				const SizedBox(width: 2),
				Text('${latestThread.currentPage}', style: TextStyle(color: otherMetadataColor)),
				const SizedBox(width: 6)
			],
			if (settings.showTimeInCatalogStats) ...[
				if (settings.showClockIconInCatalog) ...[
					Icon(CupertinoIcons.clock, color: otherMetadataColor, size: 18),
					const SizedBox(width: 4),
				],
				Text(latestThread.time.year < 2000 ? '—' : formatRelativeTime(latestThread.time), style: TextStyle(color: otherMetadataColor)),
				const SizedBox(width: 4),
			],
			if (site.supportsThreadUpvotes) ...[
				Icon(CupertinoIcons.arrow_up, color: otherMetadataColor, size: 18),
				const SizedBox(width: 2),
				Text(latestThread.posts_.first.upvotes?.toString() ?? '—', style: TextStyle(color: otherMetadataColor)),
				const SizedBox(width: 6),
			],
			if (settings.showReplyCountInCatalog) ...[
				Icon(CupertinoIcons.reply, size: 18, color: replyCountColor),
				const SizedBox(width: 4),
				if (showReplyTimeInsteadOfReplyCount) Text(formatRelativeTime(thread.posts_.tryLast?.time ?? thread.time), style: TextStyle(color: replyCountColor))
				else if (countsUnreliable && latestThread == thread) const Text('—')
				else Text((latestReplyCount - unseenReplyCount).toString(), style: TextStyle(color: (threadSeen || !showUnseenColors) ? grey : null)),
				if (unseenReplyCount > 0) Text('+$unseenReplyCount'),
				if (unseenYouCount > 0) Text(' (+$unseenYouCount)', style: TextStyle(color: theme.secondaryColor)),
				const SizedBox(width: 2),
			],
			if (settings.showImageCountInCatalog && site.showImageCount) ...[
				const SizedBox(width: 6),
				Icon(Adaptive.icons.photo, size: 18, color: imageCountColor),
				const SizedBox(width: 4),
				if (latestImageCount > unseenImageCount) ...[
					Text((latestImageCount - unseenImageCount).toString(), style: TextStyle(color: (threadSeen || !showUnseenColors) ? grey : null)),
					if (unseenImageCount > 0) Text('+$unseenImageCount'),
				]
				else if (unseenImageCount == 0 && (countsUnreliable && latestThread == thread)) const Text('—')
				else Text('$unseenImageCount', style: TextStyle(color: (threadSeen || !showUnseenColors) ? grey : null)),
				const SizedBox(width: 2),
			],
			if (site.isPaged) ...[
				const SizedBox(width: 6),
				Icon(CupertinoIcons.doc, size: 18, color: otherMetadataColor),
				const SizedBox(width: 4),
				Text((-(switch (thread.posts_.tryLast?.isPageStub) {
					true => thread.posts_.tryLast?.id,
					false => thread.posts_.tryLast?.parentId,
					null => null
				} ?? -1)).toString(), style: TextStyle(color: otherMetadataColor))
			]
		];
		if (children.isEmpty) {
			return const SizedBox.shrink();
		}
		final row = FittedBox(
			alignment: alignment,
			fit: BoxFit.scaleDown,
			child: Row(
				mainAxisSize: MainAxisSize.min,
				crossAxisAlignment: CrossAxisAlignment.center,
				children: [
					if (showChrome) const SizedBox(width: 4),
					...children
				]
			)
		);
		if (!showChrome) {
			return row;
		}
		return Container(
			decoration: BoxDecoration(
				borderRadius: settings.useFullWidthForCatalogCounters ? null : (settings.imagesOnRight ? const BorderRadius.only(topRight: Radius.circular(8)) : const BorderRadius.only(topLeft: Radius.circular(8))),
				color: theme.backgroundColor,
				border:  settings.useFullWidthForCatalogCounters ? Border(
					top: BorderSide(color: theme.primaryColorWithBrightness(0.2)),
				) : Border.all(color: theme.primaryColorWithBrightness(0.2))
			),
			margin: settings.useFullWidthForCatalogCounters ? EdgeInsets.zero : (settings.imagesOnRight ? const EdgeInsets.only(right: 10) : const EdgeInsets.only(left: 10)),
			padding: settings.useFullWidthForCatalogCounters ? const EdgeInsets.all(4) : const EdgeInsets.all(2),
			child: SizedBox(
				width: settings.useFullWidthForCatalogCounters ? double.infinity : null,
				height: 20 * settings.textScale,
				child: row
			)
		);
	}
}

class ThreadRow extends StatelessWidget {
	final Thread thread;
	final bool isSelected;
	final Function(Object?, StackTrace?)? onThumbnailLoadError;
	final ValueChanged<Attachment>? onThumbnailTap;
	final Iterable<int> semanticParentIds;
	final bool contentFocus;
	final bool showSiteIcon;
	final bool showBoardName;
	final bool countsUnreliable;
	final PostSpanRenderOptions? baseOptions;
	final bool dimReadThreads;
	final bool showLastReplies;
	final bool showPageNumber;
	final bool? forceShowInHistory;

	const ThreadRow({
		required this.thread,
		required this.isSelected,
		this.onThumbnailLoadError,
		this.onThumbnailTap,
		this.contentFocus = false,
		this.showSiteIcon = false,
		this.showBoardName = false,
		this.countsUnreliable = false,
		this.semanticParentIds = const [],
		this.baseOptions,
		this.dimReadThreads = false,
		this.showLastReplies = false,
		this.showPageNumber = false,
		this.forceShowInHistory,
		Key? key
	}) : super(key: key);

	static final _leadingWwwPattern = RegExp(r'^www\.');

	Widget _build(BuildContext context, PersistentThreadState? threadState) {
		final settings = context.watch<Settings>();
		final theme = context.watch<SavedTheme>();
		final imageboard = context.watch<Imageboard>();
		final site = context.watch<ImageboardSite>();
		final latestThread = threadState?.thread ?? thread;
		final int latestReplyCount = max(max(thread.replyCount, latestThread.replyCount), latestThread.posts_.length - 1);
		final int latestImageCount = (thread.isSticky && latestReplyCount == 1000) ? latestThread.imageCount : max(thread.imageCount, latestThread.imageCount);
		int unseenReplyCount = 0;
		int unseenImageCount = 0;
		final grey = theme.primaryColorWithBrightness(0.6);
		Color? otherMetadataColor;
		String? threadAsUrl;
		final firstUrl = latestThread.attachments.tryFirstWhere((a) => a.type == AttachmentType.url)?.url;
		final backgroundColor = isSelected ? theme.primaryColorWithBrightness(0.2) : theme.backgroundColor;
		final opacityBasedBackgroundColor = isSelected ? theme.primaryColor.withOpacity(0.25) : null;
		final borderColor = isSelected ? theme.primaryColorWithBrightness(0.8) : theme.primaryColorWithBrightness(0.2);
		if (firstUrl != null) {
			threadAsUrl = Uri.parse(firstUrl).host.replaceFirst(_leadingWwwPattern, '');
		}
		if (threadState?.lastSeenPostId != null) {
			if (threadState?.useTree ?? imageboard.persistence.browserState.useTree ?? site.useTree) {
				unseenReplyCount = (threadState?.unseenReplyCount() ?? 0) + (max(thread.replyCount, latestThread.replyCount) - (threadState!.thread?.replyCount ?? 0));
			}
			else {
				unseenReplyCount = (threadState?.unseenReplyCount() ?? 0) + ((latestReplyCount + 1) - latestThread.posts_.length);
			}
			unseenImageCount = (threadState?.unseenImageCount() ?? 0) + ((latestImageCount + thread.attachments.length) - (threadState?.thread?.posts_.expand((x) => x.attachments).length ?? 0));
			otherMetadataColor = unseenReplyCount <= 0 && unseenImageCount <= 0 ? grey : null;
		}
		final watch = threadState?.threadWatch;
		final dimThisThread = dimReadThreads && !isSelected && threadState != null && (watch == null || unseenReplyCount == 0) && (forceShowInHistory ?? threadState.showInHistory);
		final approxScreenWidth = estimateWidth(context);
		final columns = contentFocus ? (approxScreenWidth / settings.catalogGridWidth).floor() : 1;
		final approxWidth = approxScreenWidth / columns;
		final inContextMenuHack = context.watch<ContextMenuHint?>() != null;
		final approxHeight = (contentFocus ? settings.catalogGridHeight : settings.maxCatalogRowHeight) * (inContextMenuHack ? 5 : 1);
		Widget makeCounters() => ThreadCounters(
			countsUnreliable: countsUnreliable,
			imageboard: imageboard,
			thread: thread,
			threadState: threadState,
			showPageNumber: showPageNumber,
			alignment: Alignment.centerRight,
			forceShowInHistory: forceShowInHistory
		);
		final countersPlaceholderWidget = Visibility(
			visible: false,
			maintainState: true,
			maintainAnimation: true,
			maintainSize: true,
			child: Padding(
				padding: const EdgeInsets.only(top: 2),
				child: approxWidth < 150 ? SizedBox(height: DefaultTextStyle.of(context).style.fontSize ?? 17, width: double.infinity) : makeCounters()
			)
		);
		final countersPlaceholder = WidgetSpan(
			alignment: PlaceholderAlignment.top,
			child: countersPlaceholderWidget
		);
		final borderRadius = (contentFocus && settings.catalogGridModeCellBorderRadiusAndMargin) ? const BorderRadius.all(Radius.circular(8)) : BorderRadius.zero;
		final double subheaderFontSize = site.classicCatalogStyle ? 16 : 15;
		final spaceSpan = site.classicCatalogStyle ? const TextSpan(text: ' ') : const TextSpan(text: ' ', style: TextStyle(fontSize: 15));
		final headerRow = [
			if (settings.showNameInCatalog && !(settings.hideDefaultNamesInCatalog && latestThread.posts_.first.name == site.defaultUsername)) ...[
				TextSpan(
					text: settings.filterProfanity(site.formatUsername(latestThread.posts_.first.name)),
					style: TextStyle(
						fontWeight: FontWeight.w600,
						fontSize: subheaderFontSize
					)
				),
				spaceSpan
			],
			if (settings.showFlagInCatalogHeader && latestThread.posts_.first.flag != null) ...[
				makeFlagSpan(
					context: context,
					zone: null,
					flag: latestThread.posts_.first.flag!,
					includeTextOnlyContent: true,
					appendLabels: settings.showCountryNameInCatalogHeader,
					style: TextStyle(
						fontSize: subheaderFontSize,
						color: theme.primaryColor.withOpacity(0.75)
					)
				),
				spaceSpan
			],
			if (settings.showTimeInCatalogHeader) ...[
				TextSpan(
					text: formatTime(latestThread.time),
					style: TextStyle(
						fontSize: subheaderFontSize
					)
				),
				spaceSpan
			],
			if (showSiteIcon) WidgetSpan(
				alignment: PlaceholderAlignment.middle,
				child: Padding(
					padding: const EdgeInsets.only(right: 4),
					child: ImageboardIcon(
						boardName: thread.board
					)
				)
			),
			if (showBoardName || (settings.showIdInCatalogHeader && site.explicitIds)) TextSpan(
				text: showBoardName ?
						site.explicitIds ?
							'${site.formatBoardNameWithoutTrailingSlash(latestThread.board)}/${latestThread.id} ' :
							site.formatBoardName(latestThread.board) :
					'${latestThread.id} ',
				style: TextStyle(
					color: Colors.grey,
					fontSize: subheaderFontSize
				)
			)
		];
		if (latestThread.title?.isNotEmpty == true) {
			final titleSpan = PostTextSpan(settings.filterProfanity(latestThread.title!)).build(context, PostSpanRootZoneData(thread: thread, imageboard: imageboard, style: PostSpanZoneStyle.linear), settings, theme, (baseOptions ?? const PostSpanRenderOptions()).copyWith(
				baseTextStyle: site.classicCatalogStyle ? TextStyle(fontWeight: FontWeight.bold, color: theme.titleColor) : null
			));
			if (site.classicCatalogStyle) {
				if (headerRow.any((t) => t is TextSpan && (t.toPlainText(includePlaceholders: false, includeSemanticsLabels: false).trim().isNotEmpty))) {
					headerRow.add(const TextSpan(text: '\n'));
				}
				headerRow.add(titleSpan);
			}
			else {
				if (headerRow.isNotEmpty) {
					headerRow.insert(0, const TextSpan(text: '\n', style: TextStyle(fontSize: 3)));
					headerRow.insert(0, const TextSpan(text: '\n', style: TextStyle(fontSize: 3)));
				}
				if (threadAsUrl != null) {
					headerRow.insert(0, TextSpan(text: threadAsUrl, style: const TextStyle(color: Colors.grey)));
					headerRow.insert(0, const TextSpan(text: '\n'));
				}
				headerRow.insert(0, titleSpan);
				if (!latestThread.title!.contains(latestThread.flair?.name ?? '')) {
					headerRow.insert(0, const TextSpan(text: ' '));
					headerRow.insert(0, makeFlagSpan(
						context: context,
						zone: null,
						flag: latestThread.flair!,
						includeTextOnlyContent: true,
						appendLabels: false,
						style: TextStyle(color: theme.primaryColor.withOpacity(0.75))
					));
				}
			}
		}
		List<Widget> rowChildren() => [
			const SizedBox(width: 8),
			if (latestThread.attachments.isNotEmpty && settings.showImages(context, latestThread.board)) Padding(
				padding: const EdgeInsets.only(top: 8, bottom: 8),
				child: ClippingBox(
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: latestThread.attachments.map((attachment) => PopupAttachment(
							attachment: attachment,
							child: CupertinoButton(
								padding: EdgeInsets.zero,
								minSize: 0,
								child: ConstrainedBox(
									constraints: BoxConstraints(
										minHeight: 75,
										maxHeight: attachment.type == AttachmentType.url ? 75 : double.infinity
									),
									child: AttachmentThumbnail(
										onLoadError: onThumbnailLoadError,
										attachment: attachment,
										thread: latestThread.identifier,
										mayObscure: true,
										hero: TaggedAttachment(
											attachment: attachment,
											semanticParentIds: semanticParentIds
										),
										fit: settings.squareThumbnails ? BoxFit.cover : BoxFit.contain,
										shrinkHeight: !settings.squareThumbnails,
										showIconInCorner: (
											backgroundColor: backgroundColor,
											borderColor: borderColor,
											size: null
										)
									)
								),
								onPressed: () => onThumbnailTap?.call(attachment)
							)
						)).expand((x) => [const SizedBox(height: 8), x]).skip(1).toList()
					)
				)
			)
			else if (latestThread.attachmentDeleted) Center(
				child: SizedBox(
					width: settings.thumbnailSize,
					height: settings.thumbnailSize,
					child: const Icon(CupertinoIcons.xmark_square, size: 36)
				)
			),
			Expanded(
				child: Container(
					constraints: const BoxConstraints(minHeight: 75),
					padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
					child: ChangeNotifierProvider<PostSpanZoneData>(
						create: (ctx) => PostSpanRootZoneData(
							thread: latestThread,
							imageboard: imageboard,
							style: PostSpanZoneStyle.linear
						),
						builder: (context, _) => IgnorePointer(
							child: Text.rich(
								TextSpan(
									children: [
										if (headerRow.isNotEmpty) TextSpan(
											children: [
												...headerRow,
											]
										),
										if (site.classicCatalogStyle) ...[
											if (headerRow.isNotEmpty) const TextSpan(text: '\n'),
											latestThread.posts_.first.span.build(
												context, context.watch<PostSpanZoneData>(), settings, theme,
												(baseOptions ?? const PostSpanRenderOptions()).copyWith(
													maxLines: 1 + (approxHeight / ((DefaultTextStyle.of(context).style.fontSize ?? 17) * (DefaultTextStyle.of(context).style.height ?? 1.2))).lazyCeil() - (thread.title?.isNotEmpty == true ? 1 : 0) - (headerRow.isNotEmpty ? 1 : 0),
													charactersPerLine: (approxWidth / (0.55 * (DefaultTextStyle.of(context).style.fontSize ?? 17) * (DefaultTextStyle.of(context).style.height ?? 1.2))).lazyCeil(),
													postInject: settings.useFullWidthForCatalogCounters || (showLastReplies && thread.posts_.length > 1)	? null : countersPlaceholder,
													ensureTrailingNewline: true
												)
											)
										]
										else if (!settings.useFullWidthForCatalogCounters && !(showLastReplies && thread.posts_.length > 1)) countersPlaceholder,
										// Uuse thread and not latestThread
										// The last replies should be only those from the catalog/search query
										if (showLastReplies) ...[
											if (thread.posts.length > 1) const WidgetSpan(
												child: SizedBox(
													width: double.infinity,
													height: 16
												)
											),
											...thread.posts.skip(max(1, thread.posts.length - 3)).where((p) => !p.isStub && !p.isPageStub).map((post) => WidgetSpan(
												child: TransformedMediaQuery(
													transformation: (context, mq) => mq.copyWith(textScaler: TextScaler.noScaling),
														child: Padding(
														padding: const EdgeInsets.only(bottom: 16),
														child: Row(
															mainAxisSize: MainAxisSize.min,
															crossAxisAlignment: CrossAxisAlignment.start,
															children: [
																Text('>>', style: TextStyle(color: theme.primaryColorWithBrightness(0.1), fontWeight: FontWeight.bold)),
																const SizedBox(width: 4),
																Flexible(
																	child: PostRow(
																		post: post,
																		baseOptions: baseOptions,
																		shrinkWrap: true,
																		highlight: true,
																		showPostNumber: true
																	)
																)
															]
														)
													)
												)
											))
										]
									]
								),
								overflow: TextOverflow.fade
							)
						)
					)
				)
			)
		];
		Widget buildContentFocused() {
			final attachment = latestThread.attachments.tryFirst;
			Widget? att = attachment == null || !settings.showImages(context, thread.board) ? null : Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				mainAxisSize: MainAxisSize.min,
				mainAxisAlignment: MainAxisAlignment.center,
				children: [
					Flexible(
						fit: switch (settings.useStaggeredCatalogGrid) {
							true => switch (settings.catalogGridModeCropThumbnails && settings.catalogGridModeAttachmentInBackground) {
								true => FlexFit.tight, // fill background (this relies on the maxIntrinsicHeight trick in the renderobject below)
								false => FlexFit.loose, // pick the proper ratio
							},
							false => switch (settings.catalogGridModeShowMoreImageIfLessText && !settings.catalogGridModeAttachmentInBackground) {
								true => FlexFit.loose, // show at proper ratio
								false => FlexFit.tight // expand above text
							}
						},
						child: PopupAttachment(
							attachment: attachment,
							child: GestureDetector(
								child: WidgetDecoration(
									position: DecorationPosition.foreground,
									decoration: (latestThread.attachments.length > 1 || attachment.icon != null) ? Align(
										alignment: switch ((settings.catalogGridModeAttachmentInBackground, settings.catalogGridModeTextAboveAttachment)) {
											(true, true) => Alignment.bottomLeft,
											(true, false) => Alignment.topRight,
											(false, true) => Alignment.topRight,
											(false, false) => Alignment.bottomRight
										},
										child: Container(
											decoration: BoxDecoration(
												borderRadius: settings.catalogGridModeAttachmentInBackground ?
																				settings.catalogGridModeTextAboveAttachment ?
																					const BorderRadius.only(topRight: Radius.circular(6)) :
																					const BorderRadius.only(bottomLeft: Radius.circular(6))
																				: const BorderRadius.only(topLeft: Radius.circular(6)),
												color: backgroundColor,
												border: Border.all(color: borderColor)
											),
											padding: const EdgeInsets.all(2),
											child: Row(
												mainAxisSize: MainAxisSize.min,
												children: [
													if (attachment.icon != null) Icon(attachment.icon, size: 19),
													if (latestThread.attachments.length > 1 && attachment.icon != null) const SizedBox(width: 4),
													if (latestThread.attachments.length > 1) ...[
														Text('${latestThread.attachments.length} '),
														Icon(Adaptive.icons.photos, size: 19)
													]
												]
											)
										)
									) : null,
									child: AttachmentThumbnail(
										fit: settings.catalogGridModeCropThumbnails ? BoxFit.cover : BoxFit.contain,
										attachment: attachment,
										expand: settings.catalogGridModeShowMoreImageIfLessText || settings.catalogGridModeAttachmentInBackground,
										height: settings.catalogGridHeight / 2,
										thread: latestThread.identifier,
										onLoadError: onThumbnailLoadError,
										mayObscure: true,
										hero: TaggedAttachment(
											attachment: attachment,
											semanticParentIds: semanticParentIds
										)
									)
								),
								onTap: () => onThumbnailTap?.call(attachment)
							)
						)
					),
					if (!settings.catalogGridModeCropThumbnails && settings.catalogGridModeTextAboveAttachment && !settings.useFullWidthForCatalogCounters && !settings.catalogGridModeAttachmentInBackground) countersPlaceholderWidget
				]
			);
			final txt = Padding(
				padding: const EdgeInsets.all(8),
				child: ChangeNotifierProvider<PostSpanZoneData>(
					create: (ctx) => PostSpanRootZoneData(
						thread: latestThread,
						imageboard: imageboard,
						style: PostSpanZoneStyle.linear
					),
					builder: (ctx, _) {
						final others = [
							if (site.classicCatalogStyle && latestThread.posts_.first.text.isNotEmpty) latestThread.posts_.first.span.build(ctx, ctx.watch<PostSpanZoneData>(), settings, theme, (baseOptions ?? const PostSpanRenderOptions()).copyWith(
								maxLines: 1 + (approxHeight / ((DefaultTextStyle.of(context).style.fontSize ?? 17) * (DefaultTextStyle.of(context).style.height ?? 1.2))).lazyCeil() - (headerRow.isNotEmpty ? 1 : 0),
								charactersPerLine: (approxWidth / (0.4 * (DefaultTextStyle.of(context).style.fontSize ?? 17) * (DefaultTextStyle.of(context).style.height ?? 1.2))).lazyCeil(),
							)),
							if (!settings.useFullWidthForCatalogCounters && !settings.catalogGridModeTextAboveAttachment) countersPlaceholder,
							if (!settings.catalogGridModeAttachmentInBackground && !settings.catalogGridModeShowMoreImageIfLessText && !settings.useStaggeredCatalogGrid) TextSpan(text: '\n' * 25)
						];
						return IgnorePointer(
							child: Text.rich(
								TextSpan(
									children: [
										...headerRow,
										if (headerRow.isNotEmpty && others.isNotEmpty) const TextSpan(text: '\n'),
										...others
									]
								),
								maxLines: settings.catalogGridModeTextLinesLimit
							)
						);
					}
				)
			);
			if (settings.catalogGridModeAttachmentInBackground) {
				if (dimThisThread && att != null) {
					att = ColorFiltered(
						colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
						child: att
					);
				}
				final txt_ = ClipRect(
					child: BackdropFilter(
						filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
						child: Container(
							color: backgroundColor.withOpacity(0.8),
							width: double.infinity,
							child: txt
						)
					)
				);
				if (att == null) {
					return txt_;
				}
				return ConstrainedBox(
					constraints: BoxConstraints(
						minHeight: min(settings.catalogGridHeight / 2, settings.thumbnailSize * 2)
					),
					child: _ContentFocusedStack(
						attachment: att,
						text: txt_,
						textAlignment: switch (settings.catalogGridModeTextAboveAttachment) {
							true => Alignment.topCenter,
							false => Alignment.bottomCenter
						}
					)
				);
			}
			else {
				final att_ = att;
				if (att_ == null) {
					return txt;
				}
				return _ContentFocusedMultiChildWidget(
					textAboveAttachment: settings.catalogGridModeTextAboveAttachment,
					attachmentSize: settings.catalogGridModeShowMoreImageIfLessText ? null : settings.catalogGridHeight / 2,
					attachment: att_,
					text: txt
				);
			}
		}
		Widget content = contentFocus ? buildContentFocused() : Row(
			crossAxisAlignment: site.classicCatalogStyle ? CrossAxisAlignment.start : CrossAxisAlignment.center,
			mainAxisSize: MainAxisSize.max,
			children: settings.imagesOnRight ? rowChildren().reversed.toList() : rowChildren()
		);
		if (dimThisThread) {
			content = Opacity(
				opacity: 0.5,
				child: content
			);
		}
		Widget child = Stack(
			fit: StackFit.passthrough,
			children: [
				if (settings.useFullWidthForCatalogCounters) Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						if (contentFocus && !settings.useStaggeredCatalogGrid) Expanded(
							child: content
						)
						else Flexible(
							child: content
						),
						makeCounters()
					]
				)
				else ...[
					content,
					Positioned.fill(
						child: Align(
							alignment: settings.imagesOnRight ? Alignment.bottomLeft : Alignment.bottomRight,
							child: makeCounters()
						)
					)
				],
				if (watch != null || threadState?.savedTime != null) Positioned.fill(
					child: Align(
						alignment: Alignment.topRight,
						child: Container(
							decoration: BoxDecoration(
								borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8)),
								color: backgroundColor,
								border: Border.all(color: borderColor)
							),
							padding: const EdgeInsets.only(top: 2, bottom: 2, left: 6, right: 6),
							child: Row(
								mainAxisSize: MainAxisSize.min,
								children: [
									if (threadState?.showInHistory == false && forceShowInHistory == true) Icon(CupertinoIcons.eye_slash, color: otherMetadataColor, size: 18),
									if (watch != null) Icon(CupertinoIcons.bell_fill, color: otherMetadataColor, size: 18),
									if (watch?.push == true && watch?.pushYousOnly == false) Icon(CupertinoIcons.asterisk_circle, color: otherMetadataColor, size: 18),
									if (threadState?.savedTime != null) Icon(Adaptive.icons.bookmarkFilled, color: otherMetadataColor, size: 18)
								]
							)
						)
					)
				)
			]
		);
		final container = Container(
			decoration: BoxDecoration(
				color: (settings.materialStyle && Material.maybeOf(context)?.color == theme.backgroundColor) ? opacityBasedBackgroundColor : backgroundColor,
				border: contentFocus ? Border.all(color: borderColor) : null,
				borderRadius: borderRadius
			),
			margin: (contentFocus && settings.catalogGridModeCellBorderRadiusAndMargin) ? const EdgeInsets.all(4) : null,
			child: borderRadius != BorderRadius.zero ? ClipRRect(
				borderRadius: borderRadius,
				child: child
			) : child
		);
		return contentFocus ? TransformedMediaQuery(
			transformation: (context, mq) => mq.copyWith(
				textScaler: ChainedLinearTextScaler(
					parent: mq.textScaler,
					textScaleFactor: Settings.catalogGridModeTextScaleSetting.watch(context)
				)
			),
			child: container
		) : container;
	}

	@override
	Widget build(BuildContext context) {
		return AnimatedBuilder(
			animation: context.read<Persistence>().listenForPersistentThreadStateChanges(thread.identifier),
			builder: (context, child) {
				final threadState = context.read<Persistence>().getThreadStateIfExists(thread.identifier);
				if (threadState == null) {
					return _build(context, threadState);
				}
				else {
					return ListenableBuilder(
						listenable: threadState,
						builder: (context, _) => _build(context, context.read<Persistence>().getThreadStateIfExists(thread.identifier))
					);
				}
			}
		);
	}
}

enum _ContentFocusedMultiChildLayoutId {
	attachment,
	text
}

class _ContentFocusedMultiChildWidget extends SlottedMultiChildRenderObjectWidget<_ContentFocusedMultiChildLayoutId, RenderBox> {
	final Widget attachment;
	final Widget text;
	final bool textAboveAttachment;
	final double? attachmentSize;

	const _ContentFocusedMultiChildWidget({
		required this.attachment,
		required this.text,
		required this.textAboveAttachment,
		required this.attachmentSize
	});

	@override
	Widget? childForSlot(_ContentFocusedMultiChildLayoutId slot) {
		return switch (slot) {
			_ContentFocusedMultiChildLayoutId.attachment => attachment,
			_ContentFocusedMultiChildLayoutId.text => text
		};
	}

	@override
	_RenderContentFocusedMultiChildWidget createRenderObject(BuildContext context) {
		return _RenderContentFocusedMultiChildWidget(
			textAboveAttachment: textAboveAttachment,
			attachmentSize: attachmentSize
		);
	}

	@override
	void updateRenderObject(BuildContext context, _RenderContentFocusedMultiChildWidget renderObject) {
		renderObject
			..textAboveAttachment = textAboveAttachment
			..attachmentSize = attachmentSize;
	}

	@override
	Iterable<_ContentFocusedMultiChildLayoutId> get slots => [_ContentFocusedMultiChildLayoutId.attachment, _ContentFocusedMultiChildLayoutId.text];
}

class _RenderContentFocusedMultiChildWidget extends RenderBox with SlottedContainerRenderObjectMixin<_ContentFocusedMultiChildLayoutId, RenderBox> {
	bool _textAboveAttachment;
	set textAboveAttachment(bool v) {
		if (v == _textAboveAttachment) {
			return;
		}
		_textAboveAttachment = v;
		markNeedsLayout();
	}

	double? _attachmentSize;
	set attachmentSize(double? v) {
		if (v == _attachmentSize) {
			return;
		}
		_attachmentSize = v;
		markNeedsLayout();
	}

	_RenderContentFocusedMultiChildWidget({
		required bool textAboveAttachment,
		required double? attachmentSize
	}) : _textAboveAttachment = textAboveAttachment, _attachmentSize = attachmentSize;

	RenderBox? get _attachment => childForSlot(_ContentFocusedMultiChildLayoutId.attachment);
	RenderBox? get _text => childForSlot(_ContentFocusedMultiChildLayoutId.text);

	@override
	Iterable<RenderBox> get children {
		// Hit test order (text first)
		return [
			if (_text != null) _text!,
			if (_attachment != null) _attachment!
		];
	}

	@override
	void performLayout() {
		final constraints = this.constraints;
		final attachmentSize = _attachmentSize;
		if (attachmentSize == null) {
			// Let Attachment pick its own size first (within reason)
			_attachment!.layout(BoxConstraints(
				minWidth: constraints.maxWidth,
				maxWidth: constraints.maxWidth,
				minHeight: 50,
				maxHeight: constraints.maxHeight - 80
			), parentUsesSize: true);
			_text!.layout(BoxConstraints(
				minWidth: constraints.maxWidth,
				maxWidth: constraints.maxWidth,
				minHeight: max(0, constraints.minHeight - _attachment!.size.height),
				maxHeight: constraints.maxHeight - _attachment!.size.height
			), parentUsesSize: true);
		}
		else {
			// First find out attachment desired size
			_attachment!.layout(BoxConstraints(
				minWidth: constraints.maxWidth,
				maxWidth: constraints.maxWidth,
				minHeight: 0,
				maxHeight: attachmentSize
			), parentUsesSize: true);
			_text!.layout(BoxConstraints(
				minWidth: constraints.maxWidth,
				maxWidth: constraints.maxWidth,
				minHeight: min(constraints.minHeight, min(constraints.maxHeight, 0)),
				maxHeight: max(0, constraints.maxHeight - _attachment!.size.height)
			), parentUsesSize: true);
			_attachment!.layout(BoxConstraints(
				minWidth: constraints.maxWidth,
				maxWidth: constraints.maxWidth,
				minHeight: (constraints.minHeight - _text!.size.height).clamp(0, double.infinity),
				maxHeight: (constraints.maxHeight - _text!.size.height).clamp(0, double.infinity)
			), parentUsesSize: true);
		}
		(_text!.parentData as BoxParentData).offset = Offset(0, _textAboveAttachment ? 0 : _attachment!.size.height);
		(_attachment!.parentData as BoxParentData).offset = Offset(0, _textAboveAttachment ? _text!.size.height : 0);
		size = Size(constraints.maxWidth, min(constraints.maxHeight, _text!.size.height + _attachment!.size.height));
	}

	@override
	void paint(PaintingContext context, Offset offset) {
		context.paintChild(_attachment!, offset + (_attachment!.parentData! as BoxParentData).offset);
		context.paintChild(_text!, offset + (_text!.parentData! as BoxParentData).offset);
	}

	@override
	bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
		for (final RenderBox child in children) {
			final BoxParentData parentData = child.parentData! as BoxParentData;
			final bool isHit = result.addWithPaintOffset(
				offset: parentData.offset,
				position: position,
				hitTest: (BoxHitTestResult result, Offset transformed) {
					assert(transformed == position - parentData.offset);
					return child.hitTest(result, position: transformed);
				}
			);
			if (isHit) {
				return true;
			}
		}
		return false;
	}

	@override
	double computeMinIntrinsicWidth(double height) {
		return max(_text!.getMinIntrinsicWidth(height), _attachment!.getMinIntrinsicWidth(height));
	}

	@override
	double computeMaxIntrinsicWidth(double height) {
		return min(_text!.getMaxIntrinsicWidth(height), _attachment!.getMaxIntrinsicWidth(height));
	}

	@override
	double computeMinIntrinsicHeight(double width) {
		return _attachment!.getMinIntrinsicHeight(width) + _text!.getMinIntrinsicHeight(width);
	}

	@override
	double computeMaxIntrinsicHeight(double width) {
		return _attachment!.getMaxIntrinsicHeight(width) + _text!.getMaxIntrinsicHeight(width);
	}

	@override
	Size computeDryLayout(BoxConstraints constraints) {
		final constraints = this.constraints;
		final attachmentSize = _attachmentSize;
		Size attachment;
		final Size text;
		if (attachmentSize == null) {
			// Let Attachment pick its own size first (within reason)
			attachment = _attachment!.getDryLayout(BoxConstraints(
				minWidth: constraints.maxWidth,
				maxWidth: constraints.maxWidth,
				minHeight: 50,
				maxHeight: constraints.maxHeight - 80
			));
			text = _text!.getDryLayout(BoxConstraints(
				minWidth: constraints.maxWidth,
				maxWidth: constraints.maxWidth,
				minHeight: max(0, constraints.minHeight - attachment.height),
				maxHeight: constraints.maxHeight - attachment.height
			));
		}
		else {
			// First find out attachment desired size
			attachment = _attachment!.getDryLayout(BoxConstraints(
				minWidth: constraints.maxWidth,
				maxWidth: constraints.maxWidth,
				minHeight: 0,
				maxHeight: attachmentSize
			));
			text = _text!.getDryLayout(BoxConstraints(
				minWidth: constraints.maxWidth,
				maxWidth: constraints.maxWidth,
				minHeight: min(constraints.minHeight, min(constraints.maxHeight, 0)),
				maxHeight: max(0, constraints.maxHeight - attachment.height)
			));
			attachment = _attachment!.getDryLayout(BoxConstraints(
				minWidth: constraints.maxWidth,
				maxWidth: constraints.maxWidth,
				minHeight: (constraints.minHeight - text.height).clamp(0, double.infinity),
				maxHeight: (constraints.maxHeight - text.height).clamp(0, double.infinity)
			));
		}
		return Size(constraints.maxWidth, attachment.height + text.height);
	}
}


class _ContentFocusedStack extends SlottedMultiChildRenderObjectWidget<_ContentFocusedMultiChildLayoutId, RenderBox> {
	final Widget attachment;
	final Widget text;
	final Alignment textAlignment;

	const _ContentFocusedStack({
		required this.attachment,
		required this.text,
		required this.textAlignment,
	});

	@override
	Widget? childForSlot(_ContentFocusedMultiChildLayoutId slot) {
		return switch (slot) {
			_ContentFocusedMultiChildLayoutId.attachment => attachment,
			_ContentFocusedMultiChildLayoutId.text => text
		};
	}

	@override
	_RenderContentFocusedStack createRenderObject(BuildContext context) {
		return _RenderContentFocusedStack(textAlignment: textAlignment);
	}

	@override
	void updateRenderObject(BuildContext context, _RenderContentFocusedStack renderObject) {
		renderObject.textAlignment = textAlignment;
	}

	@override
	Iterable<_ContentFocusedMultiChildLayoutId> get slots => [_ContentFocusedMultiChildLayoutId.attachment, _ContentFocusedMultiChildLayoutId.text];
}

class _RenderContentFocusedStack extends RenderBox with SlottedContainerRenderObjectMixin<_ContentFocusedMultiChildLayoutId, RenderBox> {
	Alignment _textAlignment;
	set textAlignment(Alignment v) {
		if (v == _textAlignment) {
			return;
		}
		_textAlignment = v;
		markNeedsLayout();
	}

	_RenderContentFocusedStack({
		required Alignment textAlignment
	}) : _textAlignment = textAlignment;

	RenderBox? get _attachment => childForSlot(_ContentFocusedMultiChildLayoutId.attachment);
	RenderBox? get _text => childForSlot(_ContentFocusedMultiChildLayoutId.text);

	@override
	Iterable<RenderBox> get children {
		// Hit test order (text first)
		return [
			if (_text != null) _text!,
			if (_attachment != null) _attachment!
		];
	}

	@override
	void performLayout() {
		final constraints = this.constraints;
		if (constraints.hasTightHeight) {
			// Let Attachment pick its own size first (within reason)
			_attachment!.layout(BoxConstraints(
				minWidth: constraints.maxWidth,
				maxWidth: constraints.maxWidth,
				minHeight: constraints.minHeight,
				maxHeight: constraints.maxHeight
			), parentUsesSize: true);
			_text!.layout(BoxConstraints(
				minWidth: constraints.maxWidth,
				maxWidth: constraints.maxWidth,
				minHeight: 0,
				maxHeight: _attachment!.size.height
			), parentUsesSize: true);
			size = _attachment!.size;
		}
		else if (constraints.minHeight > 0) {
			_text!.layout(BoxConstraints(
				minWidth: constraints.maxWidth,
				maxWidth: constraints.maxWidth,
				minHeight: 0,
				maxHeight: constraints.maxHeight
			), parentUsesSize: true);
			final intrinsicHeight = _attachment!.getMaxIntrinsicHeight(constraints.maxWidth);
			if (intrinsicHeight > _text!.size.height) {
				// Attachment bigger than text
				if (intrinsicHeight < constraints.minHeight) {
					// Force to at least min
					_attachment!.layout(BoxConstraints(
						minWidth: constraints.maxWidth,
						maxWidth: constraints.maxWidth,
						minHeight: constraints.minHeight,
						maxHeight: constraints.minHeight
					), parentUsesSize: true);
				}
				else {
					// Show at intrinsic height
					_attachment!.layout(BoxConstraints(
						minWidth: constraints.maxWidth,
						maxWidth: constraints.maxWidth,
						minHeight: constraints.minHeight,
						maxHeight: intrinsicHeight.clamp(constraints.minHeight, constraints.maxHeight)
					), parentUsesSize: true);
				}
				size = _attachment!.size;
			}
			else {
				// Just force attachment to text size
				final height = max(_text!.size.height, constraints.minHeight);
				_attachment!.layout(BoxConstraints(
					minWidth: constraints.maxWidth,
					maxWidth: constraints.maxWidth,
					minHeight: height,
					maxHeight: height
				), parentUsesSize: true);
				size = Size(constraints.maxWidth, height);
			}
		}
		else {
			_text!.layout(BoxConstraints(
				minWidth: constraints.maxWidth,
				maxWidth: constraints.maxWidth,
				minHeight: 0,
				maxHeight: constraints.maxHeight
			), parentUsesSize: true);
			// Force attachment to same size as text
			_attachment!.layout(BoxConstraints(
				minWidth: constraints.maxWidth,
				maxWidth: constraints.maxWidth,
				minHeight: max(constraints.minHeight, _text!.size.height),
				maxHeight: constraints.maxHeight
			), parentUsesSize: true);
			size = _attachment!.size;
		}
		(_text!.parentData as BoxParentData).offset = _textAlignment.inscribe(_text!.size, Offset.zero & size).topLeft;
		(_attachment!.parentData as BoxParentData).offset = Offset.zero;
	}

	@override
	void paint(PaintingContext context, Offset offset) {
		context.paintChild(_attachment!, offset + (_attachment!.parentData! as BoxParentData).offset);
		context.paintChild(_text!, offset + (_text!.parentData! as BoxParentData).offset);
	}

	@override
	bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
		for (final RenderBox child in children) {
			final BoxParentData parentData = child.parentData! as BoxParentData;
			final bool isHit = result.addWithPaintOffset(
				offset: parentData.offset,
				position: position,
				hitTest: (BoxHitTestResult result, Offset transformed) {
					assert(transformed == position - parentData.offset);
					return child.hitTest(result, position: transformed);
				}
			);
			if (isHit) {
				return true;
			}
		}
		return false;
	}

	@override
	double computeMinIntrinsicWidth(double height) {
		return max(_text!.getMinIntrinsicWidth(height), _attachment!.getMinIntrinsicWidth(height));
	}

	@override
	double computeMaxIntrinsicWidth(double height) {
		return min(_text!.getMaxIntrinsicWidth(height), _attachment!.getMaxIntrinsicWidth(height));
	}

	@override
	double computeMinIntrinsicHeight(double width) {
		return max(_attachment!.getMinIntrinsicHeight(width), _text!.getMinIntrinsicHeight(width));
	}

	@override
	double computeMaxIntrinsicHeight(double width) {
		return min(_attachment!.getMaxIntrinsicHeight(width), _text!.getMaxIntrinsicHeight(width));
	}

	@override
	Size computeDryLayout(BoxConstraints constraints) {
		if (constraints.hasTightHeight) {
			return constraints.biggest;
		}
		else if (constraints.minHeight > 0) {
			final text = _text!.getDryLayout(BoxConstraints(
				minWidth: constraints.maxWidth,
				maxWidth: constraints.maxWidth,
				minHeight: 0,
				maxHeight: constraints.maxHeight
			));
			final intrinsicHeight = _attachment!.getMaxIntrinsicHeight(constraints.maxWidth);
			if (intrinsicHeight > text.height) {
				// Attachment bigger than text
				if (intrinsicHeight < constraints.minHeight) {
					// Force to at least min
					return _attachment!.getDryLayout(BoxConstraints(
						minWidth: constraints.maxWidth,
						maxWidth: constraints.maxWidth,
						minHeight: constraints.minHeight,
						maxHeight: constraints.minHeight
					));
				}
				else {
					// Show at intrinsic height
					return _attachment!.getDryLayout(BoxConstraints(
						minWidth: constraints.maxWidth,
						maxWidth: constraints.maxWidth,
						minHeight: constraints.minHeight,
						maxHeight: intrinsicHeight.clamp(constraints.minHeight, constraints.maxHeight)
					));
				}
			}
			else {
				// Just force attachment to text size
				return Size(constraints.maxWidth, max(text.height, constraints.minHeight));
			}
		}
		else {
			final text = _text!.getDryLayout(BoxConstraints(
				minWidth: constraints.maxWidth,
				maxWidth: constraints.maxWidth,
				minHeight: 0,
				maxHeight: constraints.maxHeight
			));
			// Force attachment to same size as text
			return _attachment!.getDryLayout(BoxConstraints(
				minWidth: constraints.maxWidth,
				maxWidth: constraints.maxWidth,
				minHeight: max(constraints.minHeight, text.height),
				maxHeight: constraints.maxHeight
			));
		}
	}
}

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
import 'package:chan/widgets/cupertino_inkwell.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/popup_attachment.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/thread_spans.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import 'package:chan/models/thread.dart';

extension _GetLastPageNumber on Thread {
	int get _lastPageNumber =>
		-(switch (posts_.tryLast?.isPageStub) {
			true => posts_.tryLast?.id,
			false => posts_.tryLast?.parentId,
			null => null
		} ?? -1);
}

TextSpan buildThreadCounters({
	required Settings settings,
	required Imageboard imageboard,
	required SavedTheme theme,
	required PersistentThreadState? threadState,
	required Thread thread,
	bool showPageNumber = false,
	required bool countsUnreliable,
	bool showUnseenColors = true,
	bool showUnseenCounters = true,
	bool? forceShowInHistory,
	required bool showChrome
}) {
	final site = imageboard.site;
	final latestThread = threadState?.thread ?? thread;
	final int latestReplyCount = max(max(thread.replyCount, latestThread.replyCount), (site.isPaged || latestThread.isEndless) ? 0 : latestThread.posts_.length - 1);
	final int latestImageCount = (thread.isSticky && latestReplyCount == 1000) ? latestThread.imageCount : max(thread.imageCount, latestThread.imageCount);
	int unseenReplyCount = 0;
	int unseenYouCount = 0;
	int unseenImageCount = 0;
	final grey = theme.primaryColorWithBrightness(0.6);
	Color? replyCountColor;
	Color? imageCountColor;
	Color? pageCountColor;
	Color? otherMetadataColor;
	final threadSeen = threadState?.lastSeenPostId != null && (forceShowInHistory ?? (threadState?.showInHistory ?? false));
	bool showReplyTimeInsteadOfReplyCount = false;
	if (threadSeen && (site.isPaged || thread.isEndless)) {
		// image count stuff intentionally not covered here...
		unseenReplyCount = threadState?.unseenReplyCount() ?? 0;
		unseenImageCount = threadState?.unseenImageCount() ?? 0;
		imageCountColor = unseenImageCount <= 0 ? grey : null;
		unseenYouCount = threadState?.unseenReplyIdsToYouCount() ?? 0;
		final catalogLastTime = thread.lastUpdatedTime ?? thread.posts_.tryLast?.time;
		final stateLastTime = threadState?.thread?.lastUpdatedTime ?? threadState?.thread?.posts_.tryLast?.time;
		print('${thread.identifier} catalogLastTime=$catalogLastTime, stateLastTime=$stateLastTime');
		showReplyTimeInsteadOfReplyCount = catalogLastTime != null &&
				stateLastTime != null &&
				catalogLastTime.isAfter(stateLastTime);
		if (!showReplyTimeInsteadOfReplyCount && unseenReplyCount == 0) {
			// No new posts
			replyCountColor = grey;
			otherMetadataColor = grey;
		}
		if (thread._lastPageNumber == latestThread._lastPageNumber) {
			pageCountColor = grey;
		}
	}
	else if (threadSeen && threadState?.lastSeenPostId != null && showUnseenCounters) {
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
	const space = TextSpan(text: ' ');
	final parts = <TextSpan>[
		if (threadState?.youIds.contains(thread.id) ?? false) TextSpan(
			text: '(You)',
			style: TextStyle(
				fontWeight: FontWeight.w600,
				fontVariations: CommonFontVariations.w600,
				color: theme.secondaryColor
			)
		),
		if (thread.isSticky) IconSpan(icon: CupertinoIcons.pin, color: otherMetadataColor, size: 18),
		if (latestThread.isArchived) IconSpan(icon: CupertinoIcons.archivebox, color: grey, size: 18),
		if (latestThread.isDeleted) IconSpan(icon: CupertinoIcons.trash, color: grey, size: 18),
		if (showPageNumber && latestThread.currentPage != null) TextSpan(
			children: [
				if (!settings.cloverStyleCatalogCounters) ...[
					IconSpan(icon: CupertinoIcons.doc, size: 18, color: otherMetadataColor),
					space,
				]
				else const TextSpan(text: 'p'),
				TextSpan(text: '${latestThread.currentPage}', style: TextStyle(color: otherMetadataColor)),
			]
		),
		if (settings.showTimeInCatalogStats) TextSpan(
			children: [
				if (settings.showClockIconInCatalog) ...[
					IconSpan(icon: CupertinoIcons.clock, color: otherMetadataColor, size: 18),
					space
				],
				TextSpan(text: latestThread.time.year < 2000 ? '—' : formatRelativeTime(latestThread.time), style: TextStyle(color: otherMetadataColor)),
			]
		),
		if (site.supportsThreadUpvotes) TextSpan(
			children: [
				IconSpan(icon: CupertinoIcons.arrow_up, color: otherMetadataColor, size: 18),
				space,
				TextSpan(text: latestThread.posts_.first.upvotes?.toString() ?? '—', style: TextStyle(color: otherMetadataColor)),
			]
		),
		if (settings.showReplyCountInCatalog) TextSpan(
			children: [
				if (!settings.cloverStyleCatalogCounters) ...[
					IconSpan(icon: CupertinoIcons.reply, size: 18, color: replyCountColor),
					space,
				],
				if (showReplyTimeInsteadOfReplyCount) TextSpan(text: formatRelativeTime(thread.lastUpdatedTime ?? thread.posts_.tryLast?.time ?? thread.time), style: TextStyle(color: replyCountColor))
				else if (countsUnreliable && latestThread == thread) const TextSpan(text: '—')
				else TextSpan(text: (latestReplyCount - unseenReplyCount).toString(), style: TextStyle(color: (threadSeen || !showUnseenColors) ? grey : null)),
				if (unseenReplyCount > 0) TextSpan(text: '+$unseenReplyCount'),
				if (unseenYouCount > 0) TextSpan(text: ' (+$unseenYouCount)', style: TextStyle(color: theme.secondaryColor)),
				if (settings.cloverStyleCatalogCounters)
					if (settings.useFullWidthForCatalogCounters)
						if (latestImageCount == 1)
							TextSpan(text: ' reply', style: TextStyle(color: imageCountColor))
						else
							TextSpan(text: ' replies', style: TextStyle(color: imageCountColor))
					else
						TextSpan(text: 'R', style: TextStyle(color: replyCountColor)),
			]
		),
		if (settings.showImageCountInCatalog && site.showImageCount) TextSpan(
			children: [
				if (!settings.cloverStyleCatalogCounters) ...[
					const TextSpan(text: '\u2009'), // To provide even appearance as photos icon is wide
					IconSpan(icon: CupertinoIcons.photo, size: 18, color: imageCountColor),
					space,
				],
				if (latestImageCount > unseenImageCount) ...[
					TextSpan(text: (latestImageCount - unseenImageCount).toString(), style: TextStyle(color: (threadSeen || !showUnseenColors) ? grey : null)),
					if (unseenImageCount > 0) TextSpan(text: '+$unseenImageCount'),
				]
				else if (unseenImageCount == 0 && (countsUnreliable && latestThread == thread)) const TextSpan(text: '—')
				else TextSpan(text: '$unseenImageCount', style: TextStyle(color: (threadSeen || !showUnseenColors) ? grey : null)),
				if (settings.cloverStyleCatalogCounters)
					if (settings.useFullWidthForCatalogCounters)
						if (latestImageCount == 1)
							TextSpan(text: ' image', style: TextStyle(color: imageCountColor))
						else
							TextSpan(text: ' images', style: TextStyle(color: imageCountColor))
					else
						TextSpan(text: 'I', style: TextStyle(color: imageCountColor))
			]
		),
		if (site.isPaged) TextSpan(
			children: [
				IconSpan(icon: CupertinoIcons.doc, size: 18, color: pageCountColor),
				space,
				TextSpan(text: (thread._lastPageNumber).toString(), style: TextStyle(color: pageCountColor)),
			]
		)
	];
	final between = settings.cloverStyleCatalogCounters ? TextSpan(text: ', ', style: TextStyle(color: otherMetadataColor)) : const TextSpan(text: '  ');
	// Lazy way of inserting between each member
	for (int i = parts.length - 1; i > 0; i--) {
		parts.insert(i, between);
	}
	if (showChrome) {
		// Padding
		parts.insert(0, space);
		parts.add(space);
	}
	return TextSpan(children: parts);
}

class _ThreadCounters extends StatelessWidget {
	final TextSpan counters;
	final bool useFittedBox;
	final bool showChrome;
	final Alignment alignment;

	const _ThreadCounters({
		required this.counters,
		required this.useFittedBox,
		required this.showChrome,
		required this.alignment,
	});

	@override
	Widget build(BuildContext context) {
		if (counters.children?.isEmpty ?? false) {
			return const SizedBox.shrink();
		}
		final row = useFittedBox ? FittedBox(
			alignment: alignment,
			fit: BoxFit.scaleDown,
			child: Text.rich(counters)
		) : Text.rich(counters, maxLines: 1, overflow: TextOverflow.ellipsis);
		if (!showChrome) {
			return row;
		}
		final settings = context.watch<Settings>();
		final theme = context.watch<SavedTheme>();
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

enum ThreadRowStyle {
	row,
	grid,
	staggeredGrid;
	bool get isGrid => this != row;
}

class ThreadRow extends StatelessWidget {
	final Thread thread;
	final bool isSelected;
	final Function(Object?, StackTrace?)? onThumbnailLoadError;
	final ValueChanged<Attachment>? onThumbnailTap;
	final Iterable<int> semanticParentIds;
	final ThreadRowStyle style;
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
		this.style = ThreadRowStyle.row,
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
		final int latestReplyCount = max(max(thread.replyCount, latestThread.replyCount), (site.isPaged || thread.isEndless) ? 0 : (latestThread.posts_.length - 1));
		final grey = theme.primaryColorWithBrightness(0.6);
		String? threadAsUrl;
		final firstUrl = latestThread.attachments.tryFirstWhere((a) => a.type == AttachmentType.url)?.url;
		final backgroundColor = isSelected ? theme.primaryColorWithBrightness(0.2) : theme.backgroundColor;
		final opacityBasedBackgroundColor = isSelected ? theme.primaryColor.withOpacity(0.25) : null;
		final borderColor = isSelected ? theme.primaryColorWithBrightness(0.8) : theme.primaryColorWithBrightness(0.2);
		if (firstUrl != null) {
			threadAsUrl = Uri.parse(firstUrl).host.replaceFirst(_leadingWwwPattern, '');
		}
		final threadSeen = threadState != null && (forceShowInHistory ?? threadState.showInHistory);
		final bool hasUnseenReplies;
		if ((threadState?.unseenReplyCount() ?? 0) > 0) {
			hasUnseenReplies = true;
		}
		else if (site.isPaged || thread.isEndless) {
			final catalogLastTime = thread.lastUpdatedTime ?? thread.posts_.tryLast?.time;
			final stateLastTime = threadState?.thread?.lastUpdatedTime ?? threadState?.thread?.posts_.tryLast?.time;
			hasUnseenReplies = catalogLastTime != null && stateLastTime != null && catalogLastTime.isAfter(stateLastTime);
		}
		else if (threadSeen) {
			if (threadState.useTree ?? imageboard.persistence.browserState.useTree ?? site.useTree) {
				hasUnseenReplies = max(thread.replyCount, latestThread.replyCount) > (threadState.thread?.replyCount ?? 0);
			}
			else {
				hasUnseenReplies = ((latestReplyCount + 1) > latestThread.posts_.length);
			}
		}
		else {
			hasUnseenReplies = false;
		}
		final otherMetadataColor = hasUnseenReplies ? null : grey;
		final watch = threadState?.threadWatch;
		final dimThisThread = dimReadThreads && !isSelected && threadSeen && (watch == null || !hasUnseenReplies);
		final approxWidth = style.isGrid ? settings.catalogGridWidth : estimateWidth(context);
		final inContextMenuHack = context.watch<ContextMenuHint?>() != null;
		double? approxHeight = style.isGrid ? settings.catalogGridHeight : settings.maxCatalogRowHeight;
		if (approxHeight != null) {
			approxHeight *= (inContextMenuHack ? 5 : 1);
		}
		final countersSpan = buildThreadCounters(
			settings: settings,
			theme: theme,
			countsUnreliable: countsUnreliable,
			imageboard: imageboard,
			thread: thread,
			threadState: threadState,
			showPageNumber: showPageNumber,
			forceShowInHistory: forceShowInHistory,
			showChrome: true
		);
		final textScaler = MediaQuery.textScalerOf(context);
		final countersPlaceholderWidget = SizedBox(
			height: textScaler.scale(20) + 5 + 5,
			width: textScaler.scale(7.5) * countersSpan.toPlainText().length
		);
		final countersPlaceholder = WidgetSpan(
			alignment: PlaceholderAlignment.top,
			floating: PlaceholderFloating.right,
			child: countersPlaceholderWidget
		);
		final borderRadius = (style.isGrid && settings.catalogGridModeCellBorderRadiusAndMargin) ? const BorderRadius.all(Radius.circular(8)) : BorderRadius.zero;
		final double subheaderFontSize = site.classicCatalogStyle ? 16 : 15;
		final spaceSpan = site.classicCatalogStyle ? const TextSpan(text: ' ') : const TextSpan(text: ' ', style: TextStyle(fontSize: 15));
		final headerRow = [
			if (settings.showNameInCatalog && !(settings.hideDefaultNamesInCatalog && latestThread.posts_.first.name == site.defaultUsername)) ...[
				TextSpan(
					text: settings.filterProfanity(site.formatUsername(latestThread.posts_.first.name)),
					style: TextStyle(
						fontWeight: FontWeight.w600,
						fontVariations: CommonFontVariations.w600,
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
				baseTextStyle: site.classicCatalogStyle ? TextStyle(fontWeight: FontWeight.bold, fontVariations: CommonFontVariations.bold, color: theme.titleColor) : null
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
		List<Widget> rowChildren() {
			final Widget? attachments;
			if (latestThread.attachments.isNotEmpty && settings.showImages(context, latestThread.board)) {
				attachments = Padding(
					padding: settings.imagesOnRight ? const EdgeInsets.only(left: 8) : const EdgeInsets.only(right: 8),
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: latestThread.attachments.map((attachment) => PopupAttachment(
							attachment: attachment,
							child: CupertinoInkwell(
								padding: EdgeInsets.zero,
								minSize: 0,
								onPressed: onThumbnailTap == null ? null : () => onThumbnailTap?.call(attachment),
								child: ConstrainedBox(
									constraints: BoxConstraints(
										minHeight: attachment.type == AttachmentType.url ? 75 : 51,
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
										cornerIcon: AttachmentThumbnailCornerIcon(
											backgroundColor: backgroundColor,
											borderColor: borderColor,
											size: null
										)
									)
								)
							)
						)).expand((x) => [x, const SizedBox(height: 8)]).toList()
					)
				);
			}
			else if (latestThread.attachmentDeleted) {
				attachments = SizedBox(
					width: settings.thumbnailSize,
					height: settings.thumbnailSize,
					child: const Icon(CupertinoIcons.xmark_square, size: 36)
				);
			}
			else {
				attachments = null;
			}
			return [
				const SizedBox(width: 8),
				if (!site.classicCatalogStyle && attachments != null) Padding(
					padding: const EdgeInsets.only(top: 8),
					child: attachments,
				),
				Expanded(
					child: Container(
						constraints: const BoxConstraints(minHeight: 75),
						padding: const EdgeInsets.only(top: 8, right: 8),
						child: ChangeNotifierProvider<PostSpanZoneData>(
							create: (ctx) => PostSpanRootZoneData(
								thread: latestThread,
								imageboard: imageboard,
								style: PostSpanZoneStyle.linear
							),
							builder: (context, _) => Text.rich(
								TextSpan(
									children: [
										if (site.classicCatalogStyle && attachments != null) WidgetSpan(
											child: attachments,
											floating: settings.imagesOnRight ? PlaceholderFloating.right : PlaceholderFloating.left,
											alignment: latestThread.posts_.first.span.hasVeryTallWidgetSpan ? PlaceholderAlignment.top : PlaceholderAlignment.middle
										),
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
													ignorePointer: true,
													maxLines: switch (approxHeight) {
														double approxHeight => 1 + (approxHeight / ((DefaultTextStyle.of(context).style.fontSize ?? 17) * (DefaultTextStyle.of(context).style.height ?? 1.2))).lazyCeil() - (thread.title?.isNotEmpty == true ? 1 : 0) - (headerRow.isNotEmpty ? 1 : 0),
														null => null
													},
													charactersPerLine: (approxWidth / (0.55 * (DefaultTextStyle.of(context).style.fontSize ?? 17) * (DefaultTextStyle.of(context).style.height ?? 1.2))).lazyCeil(),
													postInject: settings.useFullWidthForCatalogCounters || (showLastReplies && thread.posts_.length > 1)	? null : countersPlaceholder,
													ensureTrailingNewline: true
												)
											)
										]
										else if (!settings.useFullWidthForCatalogCounters && !(showLastReplies && thread.posts_.length > 1))
											if (settings.imagesOnRight && !site.classicCatalogStyle) ...[
												const TextSpan(text: '\n'),
												WidgetSpan(
													child: countersPlaceholderWidget
												)
											]
											else countersPlaceholder,
										// Hack to avoid extra line with same height of countersPlaceholder
										const TextSpan(text: ' ', style: TextStyle(fontSize: 0)),
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
																Text('>>', style: TextStyle(color: theme.primaryColorWithBrightness(0.1), fontWeight: FontWeight.bold, fontVariations: CommonFontVariations.bold)),
																const SizedBox(width: 4),
																Flexible(
																	child: IgnorePointer(
																		child: PostRow(
																			post: post,
																			baseOptions: baseOptions,
																			shrinkWrap: true,
																			highlight: true,
																			showPostNumber: true
																		)
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
								//overflow: TextOverflow.fade
							)
						)
					)
				),
				if (settings.imagesOnRight) const SizedBox(width: 8)
			];
		}
		Widget buildContentFocused() {
			final attachment = latestThread.attachments.tryFirst;
			Widget? att = attachment == null || !settings.showImages(context, thread.board) ? null : Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				mainAxisSize: MainAxisSize.min,
				mainAxisAlignment: MainAxisAlignment.center,
				children: [
					Flexible(
						fit: switch (style == ThreadRowStyle.staggeredGrid) {
							true => switch (settings.catalogGridModeCropThumbnails && settings.catalogGridModeAttachmentInBackground) {
								true => FlexFit.tight, // fill background (this relies on the maxIntrinsicHeight trick in the renderobject below)
								false => FlexFit.loose, // pick the proper ratio
							},
							false => switch (settings.catalogGridModeShowMoreImageIfLessText && !settings.catalogGridModeAttachmentInBackground) {
								true => switch (settings.catalogGridModeCropThumbnails) {
									true => FlexFit.tight, // fill
									false => FlexFit.loose, // show at proper ratio
								},
								false => FlexFit.tight // expand above text
							}
						},
						child: PopupAttachment(
							attachment: attachment,
							child: GestureDetector(
								onTap: onThumbnailTap == null ? null : () => onThumbnailTap?.call(attachment),
								child: ConstrainedBox(
									constraints: BoxConstraints(
										maxHeight: settings.useStaggeredCatalogGrid && attachment.type == AttachmentType.url ? settings.thumbnailSize : double.infinity
									),
									child: AttachmentThumbnail(
										fit: attachment.type == AttachmentType.url || settings.catalogGridModeCropThumbnails ? BoxFit.cover : BoxFit.contain,
										attachment: attachment,
										expand: settings.catalogGridModeShowMoreImageIfLessText || settings.catalogGridModeAttachmentInBackground,
										height: style == ThreadRowStyle.staggeredGrid ? settings.catalogGridHeight / 2 : null,
										thread: latestThread.identifier,
										onLoadError: onThumbnailLoadError,
										mayObscure: true,
										cornerIcon: AttachmentThumbnailCornerIcon(
											backgroundColor: backgroundColor,
											borderColor: borderColor,
											size: 19,
											alignment: switch ((settings.catalogGridModeAttachmentInBackground, settings.catalogGridModeTextAboveAttachment)) {
												(true, true) => Alignment.bottomLeft,
												(true, false) => Alignment.topRight,
												(false, true) => Alignment.topRight,
												(false, false) => Alignment.bottomRight
											},
											appendText: latestThread.attachments.length > 1 ? TextSpan(
												children: [
													TextSpan(text: '${latestThread.attachments.length} '),
													TextSpan(
														text: String.fromCharCode(Adaptive.icons.photos.codePoint),
														style: TextStyle(
															fontSize: 16,
															height: kTextHeightNone,
															fontFamily: Adaptive.icons.photos.fontFamily,
															color: theme.primaryColor,
															package: Adaptive.icons.photos.fontPackage
														)
													),
													const TextSpan(text: ' ')
												]
											) : null
										),
										hero: TaggedAttachment(
											attachment: attachment,
											semanticParentIds: semanticParentIds
										)
									)
								)
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
								maxLines: switch (approxHeight) {
									double approxHeight => 1 + (approxHeight / ((DefaultTextStyle.of(context).style.fontSize ?? 17) * (DefaultTextStyle.of(context).style.height ?? 1.2))).lazyCeil() - (headerRow.isNotEmpty ? 1 : 0),
									null => null
								},
								charactersPerLine: (approxWidth / (0.4 * (DefaultTextStyle.of(context).style.fontSize ?? 17) * (DefaultTextStyle.of(context).style.height ?? 1.2))).lazyCeil(),
							)),
							if (!settings.useFullWidthForCatalogCounters && !settings.catalogGridModeTextAboveAttachment) WidgetSpan(
								child: SizedBox(
									width: double.infinity,
									child: countersPlaceholderWidget
								)
							),
							if (!settings.catalogGridModeAttachmentInBackground && !settings.catalogGridModeShowMoreImageIfLessText && style == ThreadRowStyle.grid) TextSpan(text: '\n' * 25)
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
			if (headerRow.isEmpty && latestThread.posts_.first.text.isEmpty) {
				// Avoid too big blank space when there is no text
				return Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						att ?? const SizedBox.shrink(),
						if (!settings.useFullWidthForCatalogCounters) countersPlaceholderWidget
					]
				);
			}
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
					attachmentSizing: switch (settings.catalogGridModeShowMoreImageIfLessText) {
						true => switch (settings.catalogGridModeCropThumbnails) {
							true => _ContentFocusedMultiChildWidgetAttachmentSizing.atLeastHalf,
							false => _ContentFocusedMultiChildWidgetAttachmentSizing.upToHalf
						},
						false => _ContentFocusedMultiChildWidgetAttachmentSizing.fixed
					},
					attachment: ConstrainedBox(
						constraints: BoxConstraints(
							maxHeight: MediaQuery.sizeOf(context).height / 2,
						),
						child: att_
					),
					text: txt
				);
			}
		}
		Widget content = style.isGrid ? buildContentFocused() : Row(
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
						if (style == ThreadRowStyle.grid) Expanded(
							child: content
						)
						else Flexible(
							child: content
						),
						_ThreadCounters(
							counters: countersSpan,
							useFittedBox: true,
							showChrome: true,
							alignment: settings.cloverStyleCatalogCounters ? Alignment.centerLeft : Alignment.centerRight,
						)
					]
				)
				else ...[
					content,
					Positioned.fill(
						child: Align(
							alignment: settings.imagesOnRight ? Alignment.bottomLeft : Alignment.bottomRight,
							child: _ThreadCounters(
								counters: countersSpan,
								useFittedBox: true,
								showChrome: true,
								alignment: settings.cloverStyleCatalogCounters ? Alignment.centerLeft : Alignment.centerRight,
							)
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
				border: style.isGrid ? Border.all(color: borderColor) : null,
				borderRadius: borderRadius
			),
			margin: (style.isGrid && settings.catalogGridModeCellBorderRadiusAndMargin) ? const EdgeInsets.all(4) : null,
			child: borderRadius != BorderRadius.zero ? ClipRRect(
				borderRadius: borderRadius,
				child: child
			) : child
		);
		return style.isGrid ? TransformedMediaQuery(
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

enum _ContentFocusedMultiChildWidgetAttachmentSizing {
	fixed,
	upToHalf,
	atLeastHalf
}

class _ContentFocusedMultiChildWidget extends SlottedMultiChildRenderObjectWidget<_ContentFocusedMultiChildLayoutId, RenderBox> {
	final Widget attachment;
	final Widget text;
	final bool textAboveAttachment;
	final _ContentFocusedMultiChildWidgetAttachmentSizing attachmentSizing;

	const _ContentFocusedMultiChildWidget({
		required this.attachment,
		required this.text,
		required this.textAboveAttachment,
		required this.attachmentSizing
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
			attachmentSizing: attachmentSizing
		);
	}

	@override
	void updateRenderObject(BuildContext context, _RenderContentFocusedMultiChildWidget renderObject) {
		renderObject
			..textAboveAttachment = textAboveAttachment
			..attachmentSizing = attachmentSizing;
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

	_ContentFocusedMultiChildWidgetAttachmentSizing _attachmentSizing;
	set attachmentSizing(_ContentFocusedMultiChildWidgetAttachmentSizing v) {
		if (v == _attachmentSizing) {
			return;
		}
		_attachmentSizing = v;
		markNeedsLayout();
	}

	_RenderContentFocusedMultiChildWidget({
		required bool textAboveAttachment,
		required _ContentFocusedMultiChildWidgetAttachmentSizing attachmentSizing
	}) : _textAboveAttachment = textAboveAttachment, _attachmentSizing = attachmentSizing;

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
		if (_attachmentSizing == _ContentFocusedMultiChildWidgetAttachmentSizing.upToHalf) {
			// Let Attachment pick its own size first (within reason, without forcing)
			_attachment!.layout(BoxConstraints(
				minWidth: constraints.maxWidth,
				maxWidth: constraints.maxWidth,
				minHeight: min(50, constraints.maxHeight - 80),
				maxHeight: constraints.maxHeight - 80
			), parentUsesSize: true);
			_text!.layout(BoxConstraints(
				minWidth: constraints.maxWidth,
				maxWidth: constraints.maxWidth,
				minHeight: max(0, constraints.minHeight - _attachment!.size.height),
				maxHeight: constraints.maxHeight - _attachment!.size.height
			), parentUsesSize: true);
		}
		else if (_attachmentSizing == _ContentFocusedMultiChildWidgetAttachmentSizing.atLeastHalf) {
			// First give text up to half the space
			_text!.layout(BoxConstraints(
				minWidth: constraints.maxWidth,
				maxWidth: constraints.maxWidth,
				minHeight: 0,
				maxHeight: constraints.maxHeight / 2
			), parentUsesSize: true);
			// Then give attachment the rest
			_attachment!.layout(BoxConstraints(
				minWidth: constraints.maxWidth,
				maxWidth: constraints.maxWidth,
				minHeight: max(0, constraints.minHeight - _text!.size.height),
				maxHeight: constraints.maxHeight - _text!.size.height
			), parentUsesSize: true);
		}
		else if (_attachmentSizing == _ContentFocusedMultiChildWidgetAttachmentSizing.fixed) {
			// First find out attachment desired size
			_attachment!.layout(BoxConstraints(
				minWidth: constraints.maxWidth,
				maxWidth: constraints.maxWidth,
				minHeight: 0,
				maxHeight: constraints.maxHeight / 2
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
		size = Size(constraints.maxWidth, constraints.hasTightHeight ? constraints.maxHeight : min(constraints.maxHeight, _text!.size.height + _attachment!.size.height));
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
		Size attachment;
		final Size text;
		if (_attachmentSizing == _ContentFocusedMultiChildWidgetAttachmentSizing.upToHalf) {
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
		else if (_attachmentSizing == _ContentFocusedMultiChildWidgetAttachmentSizing.atLeastHalf) {
			text = _text!.getDryLayout(BoxConstraints(
				minWidth: constraints.maxWidth,
				maxWidth: constraints.maxWidth,
				minHeight: 0,
				maxHeight: constraints.maxHeight / 2
			));
			// Then give attachment the rest
			attachment = _attachment!.getDryLayout(BoxConstraints(
				minWidth: constraints.maxWidth,
				maxWidth: constraints.maxWidth,
				minHeight: max(0, constraints.minHeight - text.height),
				maxHeight: constraints.maxHeight - text.height
			));
		}
		else if (_attachmentSizing == _ContentFocusedMultiChildWidgetAttachmentSizing.fixed) {
			// First find out attachment desired size
			attachment = _attachment!.getDryLayout(BoxConstraints(
				minWidth: constraints.maxWidth,
				maxWidth: constraints.maxWidth,
				minHeight: 0,
				maxHeight: max(constraints.minHeight, constraints.maxHeight / 2)
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
		else {
			throw Exception('this should never happen');
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

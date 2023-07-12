import 'dart:math';
import 'dart:ui';

import 'package:chan/models/attachment.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/popup_attachment.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/thread_spans.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chan/models/thread.dart';

class ThreadRow extends StatelessWidget {
	final Thread thread;
	final bool isSelected;
	final Function(Object?, StackTrace?)? onThumbnailLoadError;
	final ValueChanged<Attachment>? onThumbnailTap;
	final Iterable<int> semanticParentIds;
	final bool contentFocus;
	final bool contentFocusBorderRadiusAndPadding;
	final bool showSiteIcon;
	final bool showBoardName;
	final bool countsUnreliable;
	final PostSpanRenderOptions? baseOptions;
	final bool dimReadThreads;
	final bool showLastReplies;
	final bool showPageNumber;

	const ThreadRow({
		required this.thread,
		required this.isSelected,
		this.onThumbnailLoadError,
		this.onThumbnailTap,
		this.contentFocus = false,
		this.contentFocusBorderRadiusAndPadding = false,
		this.showSiteIcon = false,
		this.showBoardName = false,
		this.countsUnreliable = false,
		this.semanticParentIds = const [],
		this.baseOptions,
		this.dimReadThreads = false,
		this.showLastReplies = false,
		this.showPageNumber = false,
		Key? key
	}) : super(key: key);

	Widget _build(BuildContext context, PersistentThreadState? threadState) {
		final settings = context.watch<EffectiveSettings>();
		final theme = context.watch<SavedTheme>();
		final imageboard = context.watch<Imageboard>();
		final site = context.watch<ImageboardSite>();
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
		String? threadAsUrl;
		final firstUrl = latestThread.attachments.tryFirstWhere((a) => a.type == AttachmentType.url)?.url;
		final backgroundColor = isSelected ? theme.primaryColorWithBrightness(0.2) : theme.backgroundColor;
		final opacityBasedBackgroundColor = isSelected ? theme.primaryColor.withOpacity(0.25) : null;
		final borderColor = isSelected ? theme.primaryColorWithBrightness(0.8) : theme.primaryColorWithBrightness(0.2);
		if (firstUrl != null) {
			threadAsUrl = Uri.parse(firstUrl).host.replaceFirst(RegExp(r'^www\.'), '');
		}
		if (threadState?.lastSeenPostId != null) {
			if (threadState?.useTree ?? context.read<Persistence>().browserState.useTree ?? site.useTree) {
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
		final watch = threadState?.threadWatch;
		final dimThisThread = dimReadThreads && !isSelected && threadState != null && (watch == null || unseenReplyCount == 0);
		Widget makeCounters() => Container(
			decoration: BoxDecoration(
				borderRadius: settings.useFullWidthForCatalogCounters ? null : const BorderRadius.only(topLeft: Radius.circular(8)),
				color: theme.backgroundColor,
				border:  settings.useFullWidthForCatalogCounters ? Border(
					top: BorderSide(color: theme.primaryColorWithBrightness(0.2)),
				) : Border.all(color: theme.primaryColorWithBrightness(0.2))
			),
			margin: settings.useFullWidthForCatalogCounters ? EdgeInsets.zero : const EdgeInsets.only(left: 10),
			padding: settings.useFullWidthForCatalogCounters ? const EdgeInsets.all(4) : const EdgeInsets.all(2),
			child: SizedBox(
				width: settings.useFullWidthForCatalogCounters ? double.infinity : null,
				height: 20 * settings.textScale,
				child: FittedBox(
					alignment: Alignment.centerRight,
					fit: BoxFit.scaleDown,
					child: Row(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.center,
						children: [
							const SizedBox(width: 4),
							if (latestThread.isSticky) ... [
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
							if (site.isReddit || site.isHackerNews) ...[
								Icon(CupertinoIcons.arrow_up, color: otherMetadataColor, size: 18),
								const SizedBox(width: 2),
								Text(latestThread.posts_.first.upvotes?.toString() ?? '—', style: TextStyle(color: otherMetadataColor)),
								const SizedBox(width: 6),
							],
							Icon(CupertinoIcons.reply, size: 18, color: replyCountColor),
							const SizedBox(width: 4),
							if (countsUnreliable && latestThread == thread) const Text('—')
							else Text((latestReplyCount - unseenReplyCount).toString(), style: TextStyle(color: threadState?.lastSeenPostId == null ? null : grey)),
							if (unseenReplyCount > 0) Text('+$unseenReplyCount'),
							if (unseenYouCount > 0) Text(' (+$unseenYouCount)', style: TextStyle(color: theme.secondaryColor)),
							const SizedBox(width: 2),
							if (settings.showImageCountInCatalog && site.showImageCount) ...[
								const SizedBox(width: 6),
								Icon(Adaptive.icons.photo, size: 18, color: imageCountColor),
								const SizedBox(width: 4),
								if (latestImageCount > unseenImageCount) ...[
									Text((latestImageCount - unseenImageCount).toString(), style: TextStyle(color: threadState?.lastSeenPostId == null ? null : grey)),
									if (unseenImageCount > 0) Text('+$unseenImageCount'),
								]
								else if (unseenImageCount == 0 && (countsUnreliable && latestThread == thread)) const Text('—')
								else Text('$unseenImageCount', style: TextStyle(color: threadState?.lastSeenPostId != null ? grey : null)),
								const SizedBox(width: 2),
							]
						]
					)
				)
			)
		);
		final countersPlaceholder = WidgetSpan(
			alignment: PlaceholderAlignment.top,
			child: Visibility(
				visible: false,
				maintainState: true,
				maintainAnimation: true,
				maintainSize: true,
				child: Padding(
					padding: const EdgeInsets.only(top: 2),
					child: LayoutBuilder(
						builder: (context, constraints) {
							final fontSize = DefaultTextStyle.of(context).style.fontSize ?? 17;
							if (constraints.maxWidth < 150) {
								return SizedBox(height: fontSize + 12, width: double.infinity);	
							}
							return makeCounters();
						}
					)
				)
			)
		);
		final borderRadius = (contentFocus && contentFocusBorderRadiusAndPadding) ? const BorderRadius.all(Radius.circular(8)) : BorderRadius.zero;
		final double? subheaderFontSize = site.classicCatalogStyle ? null : 15;
		final spaceSpan = site.classicCatalogStyle ? const TextSpan(text: ' ') : const TextSpan(text: ' ', style: TextStyle(fontSize: 15));
		final headerRow = [
			if (settings.showNameInCatalog && !(settings.hideDefaultNamesInCatalog && latestThread.posts_.first.name == site.defaultUsername)) ...[
				TextSpan(
					text: settings.filterProfanity(latestThread.posts_.first.name),
					style: TextStyle(
						fontWeight: FontWeight.w600,
						fontSize: subheaderFontSize
					)
				),
				spaceSpan
			],
			if (settings.showFlagInCatalogHeader && latestThread.posts_.first.flag != null) ...[
				FlagSpan(latestThread.posts_.first.flag!),
				spaceSpan
			],
			if (settings.showCountryNameInCatalogHeader && latestThread.posts_.first.flag != null) ...[
				TextSpan(	
					text: latestThread.posts_.first.flag!.name,
					style: TextStyle(
						fontSize: subheaderFontSize
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
							'${site.formatBoardName(site.persistence.getBoard(latestThread.board)).replaceFirst(RegExp(r'\/$'), '')}/${latestThread.id} ' :
							site.formatBoardName(site.persistence.getBoard(latestThread.board)) :
					'${latestThread.id} ',
				style: TextStyle(
					color: Colors.grey,
					fontSize: subheaderFontSize
				)
			)
		];
		if (latestThread.title?.isNotEmpty == true) {
			final titleSpan = PostTextSpan(settings.filterProfanity(latestThread.title!)).build(context, PostSpanRootZoneData(thread: thread, imageboard: imageboard), settings, theme, (baseOptions ?? const PostSpanRenderOptions()).copyWith(
				baseTextStyle: site.classicCatalogStyle ? TextStyle(fontWeight: FontWeight.bold, color: theme.titleColor) : null
			));
			if (site.classicCatalogStyle) {
				if (headerRow.isNotEmpty) {
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
					headerRow.insert(0, TextSpan(	
						text: '${latestThread.flair!.name} ',
						style: const TextStyle(
							color: Colors.grey
						)
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
										minWidth: settings.thumbnailSize
									),
									child: Center(
										child: Stack(
											children: [
												AttachmentThumbnail(
													onLoadError: onThumbnailLoadError,
													attachment: attachment,
													thread: latestThread.identifier,
													hero: TaggedAttachment(
														attachment: attachment,
														semanticParentIds: semanticParentIds
													),
													fit: settings.squareThumbnails ? BoxFit.cover : BoxFit.contain,
													shrinkHeight: !settings.squareThumbnails,
													shrinkWidth: !settings.squareThumbnails
												),
												if (attachment.icon != null) Positioned.fill(
													child: Align(
														alignment: Alignment.bottomRight,
														child: Container(
															decoration: BoxDecoration(
																borderRadius: const BorderRadius.only(topLeft: Radius.circular(6)),
																color: backgroundColor,
																border: Border.all(color: borderColor)
															),
															padding: const EdgeInsets.all(2),
															child: Icon(attachment.icon, size: 16)
														)
													)
												)
											]
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
							imageboard: imageboard
						),
						child: IgnorePointer(
							child: LayoutBuilder(
								builder: (context, constraints) => Text.rich(
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
														avoidBuggyClippers: true,
														maxLines: 1 + (constraints.maxHeight / ((DefaultTextStyle.of(context).style.fontSize ?? 17) * (DefaultTextStyle.of(context).style.height ?? 1.2))).lazyCeil() - (thread.title?.isNotEmpty == true ? 1 : 0) - (headerRow.isNotEmpty ? 1 : 0),
														charactersPerLine: (constraints.maxWidth / (0.55 * (DefaultTextStyle.of(context).style.fontSize ?? 17) * (DefaultTextStyle.of(context).style.height ?? 1.2))).lazyCeil(),
														postInject: (showLastReplies && thread.posts_.length > 1)	? null : countersPlaceholder
													)
												)
											]
											else if (!(showLastReplies && thread.posts_.length > 1)) countersPlaceholder,
											// Uuse thread and not latestThread
											// The last replies should be only those from the catalog/search query
											if (showLastReplies) ...[
												if (thread.posts.length > 1) const WidgetSpan(
													child: SizedBox(
														width: double.infinity,
														height: 16
													)
												),
												...thread.posts.skip(max(1, thread.posts.length - 3)).map((post) => WidgetSpan(
													child: TransformedMediaQuery(
														transformation: (mq) => mq.copyWith(textScaleFactor: 1),
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
			)
		];
		final showFlairInContentFocus = !settings.catalogGridModeAttachmentInBackground && !(latestThread.title ?? '').contains(latestThread.flair?.name ?? '');
		List<Widget> buildContentFocused() {
			final attachment = latestThread.attachments.tryFirst;
			Widget? att = attachment == null ? null : LayoutBuilder(
				builder: (context, constraints) {
					return PopupAttachment(
						attachment: attachment,
						child: GestureDetector(
							child: Stack(
								children: [
									AttachmentThumbnail(
										width: constraints.maxWidth,
										height: constraints.maxHeight,
										fit: BoxFit.cover,
										attachment: attachment,
										thread: latestThread.identifier,
										onLoadError: onThumbnailLoadError,
										hero: TaggedAttachment(
											attachment: attachment,
											semanticParentIds: semanticParentIds
										)
									),
									if (latestThread.attachments.length > 1 || attachment.icon != null) Positioned(
										top: settings.catalogGridModeAttachmentInBackground ? 0 : null,
										bottom: settings.catalogGridModeAttachmentInBackground ? null : 0,
										right: 0,
										child: Container(
											decoration: BoxDecoration(
												borderRadius: settings.catalogGridModeAttachmentInBackground ?
													const BorderRadius.only(bottomLeft: Radius.circular(6)) :
													const BorderRadius.only(topLeft: Radius.circular(6)),
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
									)
								]
							),
							onTap: () => onThumbnailTap?.call(attachment)
						)
					);
				}
			);
			final txt = Padding(
				padding: const EdgeInsets.all(8),
				child: ChangeNotifierProvider<PostSpanZoneData>(
					create: (ctx) => PostSpanRootZoneData(
						thread: latestThread,
						imageboard: imageboard
					),
					child: LayoutBuilder(
						builder: (ctx, constraints) => IgnorePointer(
							child: Text.rich(
								TextSpan(
									children: [
										if (showFlairInContentFocus && latestThread.attachments.isEmpty) const TextSpan(
											text: '\n'
										),
										if (latestThread.title?.isNotEmpty ?? false) TextSpan(
											text: '${settings.filterProfanity(latestThread.title!)}\n',
											style: site.classicCatalogStyle ? TextStyle(fontWeight: FontWeight.bold, color: theme.titleColor) : null,
										),
										if (settings.catalogGridModeAttachmentInBackground && !(latestThread.title ?? '').contains(latestThread.flair?.name ?? '')) TextSpan(
											text: '${latestThread.flair?.name}\n',
											style: const TextStyle(fontWeight: FontWeight.w300, fontSize: 15)
										),
										if (site.classicCatalogStyle) latestThread.posts_.first.span.build(ctx, ctx.watch<PostSpanZoneData>(), settings, theme, (baseOptions ?? const PostSpanRenderOptions()).copyWith(
											maxLines: 1 + (constraints.maxHeight / ((DefaultTextStyle.of(context).style.fontSize ?? 17) * (DefaultTextStyle.of(context).style.height ?? 1.2))).lazyCeil() - (thread.title?.isNotEmpty == true ? 1 : 0),
											charactersPerLine: (constraints.maxWidth / (0.4 * (DefaultTextStyle.of(context).style.fontSize ?? 17) * (DefaultTextStyle.of(context).style.height ?? 1.2))).lazyCeil(),
											avoidBuggyClippers: true
										)),
										countersPlaceholder
									]
								),
								maxLines: settings.catalogGridModeTextLinesLimit
							)
						)
					)
				)
			);
			if (settings.catalogGridModeAttachmentInBackground) {
				if (dimThisThread) {
					att = ColorFiltered(
						colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
						child: att
					);
				}
				return [
					if (att != null) att,
					Align(
						alignment: Alignment.bottomCenter,
						child: ClipRect(
							child: BackdropFilter(
								filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
								child: Container(
									color: backgroundColor.withOpacity(0.8),
									width: double.infinity,
									child: txt
								)
							)
						)
					)
				];
			}
			else {
				final gridTextMaxHeight = (settings.catalogGridHeight / 2) - 20;
				if (att == null) {
					return [txt];
				}
				return [
					Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							Expanded(
								child: att
							),
							ConstrainedBox(
								constraints: BoxConstraints(
									minHeight: settings.catalogGridModeShowMoreImageIfLessText ? 25 : gridTextMaxHeight,
									maxHeight: gridTextMaxHeight
								),
								child: txt
							)
						]
					)
				];
			}
		}
		Widget content = contentFocus ? Stack(
			fit: StackFit.passthrough,
			children: buildContentFocused()
		) : Row(
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
				content,
				Positioned.fill(
					child: Align(
						alignment: Alignment.bottomRight,
						child: makeCounters()
					)
				),
				if (contentFocus && showFlairInContentFocus) Positioned(
					top: 0,
					left: 0,
					child: Container(
						decoration: BoxDecoration(
							borderRadius: const BorderRadius.only(bottomRight: Radius.circular(6)),
							color: backgroundColor,
							border: Border.all(color: borderColor)
						),
						padding: const EdgeInsets.all(2),
						child: Text(latestThread.flair!.name)
					)
				),
				if (watch != null || threadState?.savedTime != null || threadState?.showInHistory == false) Positioned.fill(
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
									if (watch != null) Icon(CupertinoIcons.bell_fill, color: otherMetadataColor, size: 18),
									if (watch?.localYousOnly == false) Icon(CupertinoIcons.asterisk_circle, color: otherMetadataColor, size: 18),
									if (threadState?.savedTime != null) Icon(Adaptive.icons.bookmarkFilled, color: otherMetadataColor, size: 18),
									if (threadState?.showInHistory == false) Icon(CupertinoIcons.eye_slash, color: otherMetadataColor, size: 18)
								]
							)
						)
					)
				)
			]
		);
		return Container(
			decoration: BoxDecoration(
				color: (Material.maybeOf(context)?.color == theme.backgroundColor) ? opacityBasedBackgroundColor : backgroundColor,
				border: contentFocus ? Border.all(color: borderColor) : null,
				borderRadius: borderRadius
			),
			margin: (contentFocus && contentFocusBorderRadiusAndPadding) ? const EdgeInsets.all(4) : null,
			child: borderRadius != BorderRadius.zero ? ClipRRect(
				borderRadius: borderRadius,
				child: child
			) : child
		);
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
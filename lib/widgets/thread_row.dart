import 'dart:math';

import 'package:chan/models/attachment.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/notifications.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/soundposts.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/popup_attachment.dart';
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
		Key? key
	}) : super(key: key);

	Widget _build(BuildContext context, PersistentThreadState? threadState) {
		final settings = context.watch<EffectiveSettings>();
		final site = context.watch<ImageboardSite>();
		final latestThread = threadState?.thread ?? thread;
		final int latestReplyCount = max(max(thread.replyCount, latestThread.replyCount), latestThread.posts_.length - 1);
		final int latestImageCount = (thread.isSticky && latestReplyCount == 1000) ? latestThread.imageCount : max(thread.imageCount, latestThread.imageCount);
		int unseenReplyCount = 0;
		int unseenYouCount = 0;
		int unseenImageCount = 0;
		final grey = CupertinoTheme.of(context).primaryColorWithBrightness(0.6);
		Color? replyCountColor;
		Color? imageCountColor;
		Color? otherMetadataColor;
		String? threadAsUrl;
		final firstUrl = latestThread.attachments.tryFirstWhere((a) => a.type == AttachmentType.url)?.url;
		if (firstUrl != null) {
			threadAsUrl = Uri.parse(firstUrl).host.replaceFirst(RegExp(r'^www\.'), '');
		}
		if (threadState?.lastSeenPostId != null) {
			final filter = Filter.of(context);
			if (threadState?.useTree ?? context.read<Persistence>().browserState.useTree ?? site.useTree) {
				unseenReplyCount = (threadState?.unseenReplyCount(filter) ?? 0) + (max(thread.replyCount, latestThread.replyCount) - (threadState!.thread?.replyCount ?? 0));
			}
			else {
				unseenReplyCount = (threadState?.unseenReplyCount(filter) ?? 0) + ((latestReplyCount + 1) - latestThread.posts_.length);
			}
			unseenYouCount = threadState?.unseenReplyIdsToYouCount(filter) ?? 0;
			unseenImageCount = (threadState?.unseenImageCount(filter) ?? 0) + ((latestImageCount + thread.attachments.length) - (threadState?.thread?.posts_.expand((x) => x.attachments).length ?? 0));
			replyCountColor = unseenReplyCount <= 0 ? grey : null;
			imageCountColor = unseenImageCount <= 0 ? grey : null;
			otherMetadataColor = unseenReplyCount <= 0 && unseenImageCount <= 0 ? grey : null;
		}
		final notifications = context.watch<Notifications>();
		final watch = notifications.getThreadWatch(thread.identifier);
		Widget makeCounters() => Container(
			decoration: BoxDecoration(
				borderRadius: settings.useFullWidthForCatalogCounters ? null : const BorderRadius.only(topLeft: Radius.circular(8)),
				color: CupertinoTheme.of(context).scaffoldBackgroundColor,
				border:  settings.useFullWidthForCatalogCounters ? Border(
					top: BorderSide(color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2)),
				) : Border.all(color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2))
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
							if (settings.showTimeInCatalogStats) FittedBox(
								fit: BoxFit.contain,
									child: Row(
									mainAxisSize: MainAxisSize.min,
									children: [
										if (settings.showClockIconInCatalog) ...[
											Icon(CupertinoIcons.clock, color: otherMetadataColor, size: 18),
											const SizedBox(width: 4)
										],
										Text(latestThread.time.year < 2000 ? '—' : formatRelativeTime(latestThread.time), style: TextStyle(color: otherMetadataColor)),
										const SizedBox(width: 4),
									]
								)
							),
							if (site.isReddit || site.isHackerNews) FittedBox(
								fit: BoxFit.contain,
									child: Row(
									mainAxisSize: MainAxisSize.min,
									children: [
										Icon(CupertinoIcons.arrow_up, color: otherMetadataColor, size: 18),
										const SizedBox(width: 2),
										Text(latestThread.posts_.first.upvotes?.toString() ?? '—', style: TextStyle(color: otherMetadataColor)),
										const SizedBox(width: 6),
									]
								)
							),
							FittedBox(
								fit: BoxFit.contain,
								child: Row(
									mainAxisSize: MainAxisSize.min,
									children: [
										Icon(CupertinoIcons.reply, size: 18, color: replyCountColor),
										const SizedBox(width: 4),
										if ((latestReplyCount - unseenReplyCount) == 0 && (countsUnreliable && latestThread == thread)) const Text('—')
										else Text((latestReplyCount - unseenReplyCount).toString(), style: TextStyle(color: threadState?.lastSeenPostId == null ? null : grey)),
										if (unseenReplyCount > 0) Text('+$unseenReplyCount'),
										if (unseenYouCount > 0) Text(' (+$unseenYouCount)', style: TextStyle(color: CupertinoTheme.of(context).textTheme.actionTextStyle.color)),
										const SizedBox(width: 2),
									]
								)
							),
							if (settings.showImageCountInCatalog && site.showImageCount) FittedBox(
								fit: BoxFit.contain,
								child: Row(
									mainAxisSize: MainAxisSize.min,
									children: [
										const SizedBox(width: 6),
										Icon(CupertinoIcons.photo, size: 18, color: imageCountColor),
										const SizedBox(width: 4),
										if (latestImageCount > unseenImageCount) ...[
											Text((latestImageCount - unseenImageCount).toString(), style: TextStyle(color: threadState?.lastSeenPostId == null ? null : grey)),
											if (unseenImageCount > 0) Text('+$unseenImageCount'),
										]
										else if (unseenImageCount == 0 && (countsUnreliable && latestThread == thread)) const Text('—')
										else Text('$unseenImageCount', style: TextStyle(color: threadState?.lastSeenPostId != null ? grey : null)),
										const SizedBox(width: 2)
									]
								)
							)
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
			final titleSpan = PostTextSpan(settings.filterProfanity(latestThread.title!)).build(context, PostSpanRootZoneData(thread: thread, site: site), settings, (baseOptions ?? PostSpanRenderOptions()).copyWith(
				baseTextStyle: site.classicCatalogStyle ? TextStyle(fontWeight: FontWeight.bold, color: settings.theme.titleColor) : null
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
												if (attachment.soundSource != null || attachment.type.isVideo || attachment.type == AttachmentType.url) Positioned.fill(
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
																attachment.type.isVideo ?
																	const Icon(CupertinoIcons.play_arrow_solid, size: 16) :
																	const Icon(CupertinoIcons.link, size: 16)
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
							site: site
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
													context, context.watch<PostSpanZoneData>(), settings,
													(baseOptions ?? PostSpanRenderOptions()).copyWith(
														avoidBuggyClippers: true,
														maxLines: 1 + (constraints.maxHeight / ((DefaultTextStyle.of(context).style.fontSize ?? 17) * (DefaultTextStyle.of(context).style.height ?? 1.2))).lazyCeil() - (thread.title?.isNotEmpty == true ? 1 : 0) - (headerRow.isNotEmpty ? 1 : 0),
														charactersPerLine: (constraints.maxWidth / (0.55 * (DefaultTextStyle.of(context).style.fontSize ?? 17) * (DefaultTextStyle.of(context).style.height ?? 1.2))).lazyCeil(),
														postInject: countersPlaceholder
													)
												)
											]
											else countersPlaceholder
										]
									)
								)
							)
						)
					)
				)
			)
		];
		final showFlairInContentFocus = !settings.catalogGridModeAttachmentInBackground && !(latestThread.title ?? '').contains(latestThread.flair?.name ?? '');
		List<Widget> buildContentFocused() {
			final atts = latestThread.attachments.map((attachment) => LayoutBuilder(
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
									if (attachment.soundSource != null || attachment.type.isVideo || attachment.type == AttachmentType.url) Positioned(
										top: settings.catalogGridModeAttachmentInBackground ? 0 : null,
										bottom: settings.catalogGridModeAttachmentInBackground ? null : 0,
										right: 0,
										child: Container(
											decoration: BoxDecoration(
												borderRadius: settings.catalogGridModeAttachmentInBackground ?
													const BorderRadius.only(bottomLeft: Radius.circular(6)) :
													const BorderRadius.only(topLeft: Radius.circular(6)),
												color: CupertinoTheme.of(context).scaffoldBackgroundColor,
												border: Border.all(color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2))
											),
											padding: const EdgeInsets.all(2),
											child: attachment.soundSource != null ?
												const Icon(CupertinoIcons.volume_up) :
												attachment.type.isVideo ?
													const Icon(CupertinoIcons.play_arrow_solid) :
													const Icon(CupertinoIcons.link)
										)
									)
								]
							),
							onTap: () => onThumbnailTap?.call(attachment)
						)
					);
				}
			)).toList();
			final txt = Padding(
				padding: const EdgeInsets.all(8),
				child: ChangeNotifierProvider<PostSpanZoneData>(
					create: (ctx) => PostSpanRootZoneData(
						thread: latestThread,
						site: site
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
											style: site.classicCatalogStyle ? TextStyle(fontWeight: FontWeight.bold, color: settings.theme.titleColor) : null,
										),
										if (settings.useCatalogGrid && settings.catalogGridModeAttachmentInBackground && !(latestThread.title ?? '').contains(latestThread.flair?.name ?? '')) TextSpan(
											text: '${latestThread.flair?.name}\n',
											style: const TextStyle(fontWeight: FontWeight.w300, fontSize: 15)
										),
										if (site.classicCatalogStyle) latestThread.posts_.first.span.build(ctx, ctx.watch<PostSpanZoneData>(), settings, (baseOptions ?? PostSpanRenderOptions()).copyWith(
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
				return [
					Column(
						children: atts.map((a) => Expanded(
							child: a
						)).toList()
					),
					Align(
						alignment: Alignment.bottomCenter,
						child: Container(
							color: CupertinoTheme.of(context).scaffoldBackgroundColor.withOpacity(0.75),
							width: double.infinity,
							child: txt
						)
					)
				];
			}
			else {
				final gridTextMaxHeight = (settings.catalogGridHeight / 2) - 20;
				if (atts.isEmpty) {
					return [txt];
				}
				return [
					Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							for (final att in atts) Expanded(
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
		if (dimReadThreads && !isSelected && threadState != null && (watch == null || unseenReplyCount == 0)) {
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
							color: CupertinoTheme.of(context).scaffoldBackgroundColor,
							border: Border.all(color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2))
						),
						padding: const EdgeInsets.all(2),
						child: Text(latestThread.flair!.name)
					)
				),
				if (watch != null || threadState?.savedTime != null) Positioned.fill(
					child: Align(
						alignment: Alignment.topRight,
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
									if (watch != null) Icon(CupertinoIcons.bell_fill, color: otherMetadataColor, size: 18),
									if (watch?.localYousOnly == false) Icon(CupertinoIcons.asterisk_circle, color: otherMetadataColor, size: 18),
									if (threadState?.savedTime != null) Icon(CupertinoIcons.bookmark_fill, color: otherMetadataColor, size: 18)
								]
							)
						)
					)
				)
			]
		);
		return Container(
			decoration: BoxDecoration(
				color: isSelected ? CupertinoTheme.of(context).primaryColorWithBrightness(0.4) : CupertinoTheme.of(context).scaffoldBackgroundColor,
				border: contentFocus ? Border.all(color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2)) : null,
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
					return ValueListenableBuilder(
						valueListenable: threadState.lastSeenPostIdNotifier,
						builder: (context, _, __) => _build(context, context.read<Persistence>().getThreadStateIfExists(thread.identifier))
					);
				}
			}
		);
	}
}
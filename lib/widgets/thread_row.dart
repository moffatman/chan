import 'dart:math';

import 'package:chan/models/attachment.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/notifications.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
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

extension LazyCeil on double {
	int lazyCeil() {
		if (isFinite) {
			return ceil();
		}
		return 99999999;
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
		Key? key
	}) : super(key: key);

	Widget _build(BuildContext context, PersistentThreadState? threadState) {
		final settings = context.watch<EffectiveSettings>();
		final latestThread = threadState?.thread ?? thread;
		final int latestReplyCount = max(thread.replyCount, latestThread.replyCount);
		final int latestImageCount = max(thread.imageCount, latestThread.imageCount);
		int unseenReplyCount = 0;
		int unseenYouCount = 0;
		int unseenImageCount = 0;
		final grey = CupertinoTheme.of(context).primaryColorWithBrightness(0.6);
		Color? replyCountColor;
		Color? imageCountColor;
		Color? otherMetadataColor;
		if (threadState?.lastSeenPostId != null) {
			final filter = Filter.of(context);
			unseenReplyCount = (threadState?.unseenReplyCount(filter) ?? 0) + ((latestReplyCount + 1) - latestThread.posts.length);
			unseenYouCount = threadState?.unseenReplyIdsToYouCount(filter) ?? 0;
			unseenImageCount = (threadState?.unseenImageCount(filter) ?? 0) + ((latestImageCount + 1) - (threadState?.thread?.posts.expand((x) => x.attachments).length ?? 0));
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
			padding: settings.useFullWidthForCatalogCounters ? const EdgeInsets.all(4) : const EdgeInsets.all(2),
			child: SizedBox(
				width: settings.useFullWidthForCatalogCounters ? double.infinity : null,
				child: Wrap(
					verticalDirection: VerticalDirection.up,
					alignment: WrapAlignment.end,
					runSpacing: 4,
					crossAxisAlignment: WrapCrossAlignment.center,
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
									Text(formatRelativeTime(thread.time), style: TextStyle(color: otherMetadataColor)),
									const SizedBox(width: 4),
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
									if ((latestReplyCount - unseenReplyCount) == 0 && countsUnreliable) const Text('--')
									else Text((latestReplyCount - unseenReplyCount).toString(), style: TextStyle(color: threadState?.lastSeenPostId == null ? null : grey)),
									if (unseenReplyCount > 0) Text('+$unseenReplyCount'),
									if (unseenYouCount > 0) Text(' (+$unseenYouCount)', style: TextStyle(color: CupertinoTheme.of(context).textTheme.actionTextStyle.color)),
									const SizedBox(width: 2),
								]
							)
						),
						if (settings.showImageCountInCatalog) FittedBox(
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
									else if (unseenImageCount == 0 && countsUnreliable) const Text('--')
									else Text('$unseenImageCount', style: TextStyle(color: threadState?.lastSeenPostId != null ? grey : null)),
									const SizedBox(width: 2)
								]
							)
						)
					]
				)
			)
		);
		final borderRadius = contentFocus ? const BorderRadius.all(Radius.circular(8)) : BorderRadius.zero;
		final headerRow = [
			if (settings.showNameInCatalog) ...[
				TextSpan(
					text: settings.filterProfanity(latestThread.posts_.first.name),
					style: const TextStyle(fontWeight: FontWeight.w600)
				),
				const TextSpan(text: ' ')
			],
			if (settings.showFlagInCatalogHeader && latestThread.flag != null) ...[
				FlagSpan(latestThread.flag!),
				const TextSpan(text: ' '),
			],
			if (settings.showCountryNameInCatalogHeader && latestThread.flag != null) ...[
				TextSpan(
					text: latestThread.flag!.name,
					style: const TextStyle(
						fontStyle: FontStyle.italic
					)
				),
				const TextSpan(text: ' ')
			],
			if (settings.showTimeInCatalogHeader) ...[
				TextSpan(
					text: formatTime(latestThread.time)
				),
				const TextSpan(text: ' ')
			],
			if (showSiteIcon) const WidgetSpan(
				alignment: PlaceholderAlignment.middle,
				child: ImageboardIcon()
			),
			if (showBoardName || settings.showIdInCatalogHeader) TextSpan(
				text: showBoardName ?
					'/${latestThread.board}/${latestThread.id}' :
					latestThread.id.toString(),
				style: const TextStyle(color: Colors.grey)
			)
		];
		if (thread.title?.isNotEmpty == true) {
			if (headerRow.isNotEmpty) {
				headerRow.add(const TextSpan(text: '\n'));
			}
			headerRow.add(PostTextSpan(latestThread.title!).build(context, PostSpanRootZoneData(thread: thread, site: context.read<ImageboardSite>()), settings, (baseOptions ?? PostSpanRenderOptions()).copyWith(
				baseTextStyle: const TextStyle(fontWeight: FontWeight.bold)
			)));
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
							child: GestureDetector(
								child: Stack(
									alignment: Alignment.center,
									fit: StackFit.loose,
									children: [
										AttachmentThumbnail(
											onLoadError: onThumbnailLoadError,
											attachment: attachment,
											thread: latestThread.identifier,
											hero: AttachmentSemanticLocation(
												attachment: attachment,
												semanticParents: semanticParentIds
											)
										),
										if (attachment.type == AttachmentType.webm) SizedBox(
											width: settings.thumbnailSize,
											height: settings.thumbnailSize,
											child: Center(
												child: AspectRatio(
													aspectRatio: attachment.spoiler ? 1 : ((attachment.width ?? 1) / (attachment.height ?? 1)),
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
								onTap: () => onThumbnailTap?.call(attachment)
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
					constraints: BoxConstraints(minHeight: settings.thumbnailSize),
					padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
					child: ChangeNotifierProvider<PostSpanZoneData>(
						create: (ctx) => PostSpanRootZoneData(
							thread: latestThread,
							site: context.watch<ImageboardSite>()
						),
						child: IgnorePointer(
							child: LayoutBuilder(
								builder: (context, constraints) => Text.rich(
									TextSpan(
										children: [
											if (headerRow.isNotEmpty) TextSpan(
												children: [
													...headerRow,
													const TextSpan(text: '\n')
												]
											),
											latestThread.posts_.first.span.build(
												context, context.watch<PostSpanZoneData>(), settings,
												(baseOptions ?? PostSpanRenderOptions()).copyWith(
													avoidBuggyClippers: true,
													maxLines: (constraints.maxHeight / ((DefaultTextStyle.of(context).style.fontSize ?? 17) * (DefaultTextStyle.of(context).style.height ?? 1.2))).lazyCeil() - (thread.title?.isNotEmpty == true ? 1 : 0) - (headerRow.isNotEmpty ? 1 : 0),
													charactersPerLine: (constraints.maxWidth / (0.55 * (DefaultTextStyle.of(context).style.fontSize ?? 17) * (DefaultTextStyle.of(context).style.height ?? 1.2))).lazyCeil(),
													postInject: WidgetSpan(
														alignment: PlaceholderAlignment.top,
														child: Visibility(
															visible: false,
															maintainState: true,
															maintainAnimation: true,
															maintainSize: true,
															child: makeCounters()
														)
													)
												)
											)
										]
									)
								)
							)
						)
					)
				)
			)
		];
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
										hero: null
									),
									if (attachment.type == AttachmentType.webm) Positioned(
										bottom: 0,
										right: 0,
										child: Container(
											decoration: BoxDecoration(
												borderRadius: const BorderRadius.only(topLeft: Radius.circular(6)),
												color: CupertinoTheme.of(context).scaffoldBackgroundColor,
												border: Border.all(color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2))
											),
											padding: const EdgeInsets.all(2),
											child: const Icon(CupertinoIcons.play_arrow_solid)
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
						site: context.watch<ImageboardSite>()
					),
					child: LayoutBuilder(
						builder: (ctx, constraints) => IgnorePointer(
							child: Text.rich(
								TextSpan(
									children: [
										if (thread.title != null) TextSpan(
											text: '${settings.filterProfanity(latestThread.title!)}\n',
											style: const TextStyle(fontWeight: FontWeight.bold),
										),
										latestThread.posts_.first.span.build(ctx, ctx.watch<PostSpanZoneData>(), settings, (baseOptions ?? PostSpanRenderOptions()).copyWith(
											maxLines: (constraints.maxHeight / ((DefaultTextStyle.of(context).style.fontSize ?? 17) * (DefaultTextStyle.of(context).style.height ?? 1.2))).lazyCeil() - (thread.title?.isNotEmpty == true ? 1 : 0),
											charactersPerLine: (constraints.maxWidth / (0.4 * (DefaultTextStyle.of(context).style.fontSize ?? 17) * (DefaultTextStyle.of(context).style.height ?? 1.2))).lazyCeil(),
											avoidBuggyClippers: true
										)),
										WidgetSpan(
											child: Visibility(
												visible: false,
												maintainState: true,
												maintainAnimation: true,
												maintainSize: true,
												child: makeCounters()
											)
										)
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
							color: CupertinoTheme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
							width: double.infinity,
							child: txt
						)
					)
				];
			}
			else {
				return [
					Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							for (final att in atts) Expanded(
								child: att
							),
							ConstrainedBox(
								constraints: BoxConstraints(minHeight: 25, maxHeight: (settings.catalogGridHeight / 2) - 20),
								child: txt
							)
						]
					)
				];
			}
		}
		final child = Stack(
			fit: StackFit.passthrough,
			children: [
				if (contentFocus) ...buildContentFocused()
				else Row(
					crossAxisAlignment: CrossAxisAlignment.start,
					mainAxisSize: MainAxisSize.max,
					children: settings.imagesOnRight ? rowChildren().reversed.toList() : rowChildren()
				),
				Positioned.fill(
					child: Align(
						alignment: Alignment.bottomRight,
						child: Row(
							children: [
								if (!contentFocus) SizedBox(width: settings.thumbnailSize + 8 + 4),
								Expanded(
									child: Align(
										alignment: Alignment.bottomRight,
										child: makeCounters()
									)
								)
							]
						)
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
			margin: contentFocus ? const EdgeInsets.all(4) : null,
			child: borderRadius != BorderRadius.zero ? ClipRRect(
				borderRadius: borderRadius,
				child: child
			) : child
		);
	}

	@override
	Widget build(BuildContext context) {
		return ValueListenableBuilder(
			valueListenable: context.read<Persistence>().listenForPersistentThreadStateChanges(thread.identifier),
			builder: (context, box, child) {
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
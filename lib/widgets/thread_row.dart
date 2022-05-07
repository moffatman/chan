import 'dart:math';

import 'package:chan/models/attachment.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/notifications.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/hover_popup.dart';
import 'package:chan/widgets/popup_attachment.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/thread_spans.dart';
import 'package:chan/widgets/util.dart';
import 'package:extended_image/extended_image.dart';
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
	final bool showBoardName;
	final bool countsUnreliable;
	const ThreadRow({
		required this.thread,
		required this.isSelected,
		this.onThumbnailLoadError,
		this.onThumbnailTap,
		this.contentFocus = false,
		this.showBoardName = false,
		this.countsUnreliable = false,
		this.semanticParentIds = const [],
		Key? key
	}) : super(key: key);

	Widget _build(BuildContext context, PersistentThreadState? threadState) {
		final settings = context.watch<EffectiveSettings>();
		final _thread = threadState?.thread ?? thread;
		final int latestReplyCount = max(thread.replyCount, _thread.replyCount);
		final int latestImageCount = max(thread.imageCount, _thread.imageCount);
		int unseenReplyCount = 0;
		int unseenYouCount = 0;
		int unseenImageCount = 0;
		final grey = CupertinoTheme.of(context).primaryColorWithBrightness(0.6);
		Color? replyCountColor;
		Color? imageCountColor;
		Color? otherMetadataColor;
		if (threadState?.lastSeenPostId != null) {
			final _filter = Filter.of(context);
			unseenReplyCount = (threadState?.unseenReplyCount(_filter) ?? 0) + ((latestReplyCount + 1) - _thread.posts.length);
			unseenYouCount = threadState?.unseenReplyIdsToYou(_filter)?.length ?? 0;
			unseenImageCount = (threadState?.unseenImageCount(_filter) ?? 0) + ((latestImageCount + 1) - (threadState?.thread?.posts.where((x) => x.attachment != null).length ?? 0));
			replyCountColor = unseenReplyCount == 0 ? grey : null;
			imageCountColor = unseenImageCount == 0 ? grey : null;
			otherMetadataColor = unseenReplyCount == 0 && unseenImageCount == 0 ? grey : null;
		}
		final notifications = context.watch<Notifications>();
		final watch = notifications.getThreadWatch(thread.identifier);
		Widget _makeCounters() => Container(
			decoration: BoxDecoration(
				borderRadius: const BorderRadius.only(topLeft: Radius.circular(8)),
				color: CupertinoTheme.of(context).scaffoldBackgroundColor,
				border: Border.all(color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2))
			),
			padding: const EdgeInsets.all(2),
			child: Wrap(
				verticalDirection: VerticalDirection.up,
				alignment: WrapAlignment.end,
				runSpacing: 4,
				crossAxisAlignment: WrapCrossAlignment.center,
				children: [
					const SizedBox(width: 4),
					if (_thread.isSticky) ... [
						Icon(CupertinoIcons.pin, color: otherMetadataColor, size: 18),
						const SizedBox(width: 4),
					],
					if (_thread.isArchived) ... [
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
		);
		final borderRadius = contentFocus ? const BorderRadius.all(Radius.circular(8)) : BorderRadius.zero;
		final headerRow = [
			if (settings.showNameInCatalog) ...[
				TextSpan(
					text: settings.filterProfanity(_thread.posts[0].name),
					style: const TextStyle(fontWeight: FontWeight.w600)
				),
				const TextSpan(text: ' ')
			],
			if (settings.showFlagInCatalogHeader && _thread.flag != null) ...[
				FlagSpan(_thread.flag!),
				const TextSpan(text: ' '),
				TextSpan(
					text: _thread.flag!.name,
					style: const TextStyle(
						fontStyle: FontStyle.italic
					)
				),
				const TextSpan(text: ' ')
			],
			if (settings.showTimeInCatalogHeader) ...[
				TextSpan(
					text: formatTime(_thread.time)
				),
				const TextSpan(text: ' ')
			],
			if (showBoardName || settings.showIdInCatalogHeader) TextSpan(
				text: showBoardName ?
					'/${_thread.board}/${_thread.id}' :
					_thread.id.toString(),
				style: const TextStyle(color: Colors.grey)
			)
		];
		if (thread.title?.isNotEmpty == true) {
			if (headerRow.isNotEmpty) {
				headerRow.add(const TextSpan(text: '\n'));
			}
			headerRow.add(TextSpan(
				text: settings.filterProfanity(_thread.title!),
				style: const TextStyle(fontWeight: FontWeight.bold)
			));
		}
		List<Widget> rowChildren() => [
			if (_thread.attachment != null && settings.showImages(context, _thread.board)) Padding(
				padding: const EdgeInsets.only(top: 8, bottom: 8),
				child: PopupAttachment(
					attachment: _thread.attachment!,
					child: GestureDetector(
						child: Stack(
							alignment: Alignment.center,
							fit: StackFit.loose,
							children: [
								AttachmentThumbnail(
									onLoadError: onThumbnailLoadError,
									attachment: _thread.attachment!,
									thread: _thread.identifier,
									hero: AttachmentSemanticLocation(
										attachment: _thread.attachment!,
										semanticParents: semanticParentIds
									)
								),
								if (_thread.attachment?.type == AttachmentType.webm) SizedBox(
									width: 75,
									height: 75,
									child: Center(
										child: AspectRatio(
											aspectRatio: (_thread.attachment!.width ?? 1) / (_thread.attachment!.height ?? 1),
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
						onTap: () => onThumbnailTap?.call(_thread.attachment!)
					)
				)
			)
			else if (_thread.attachmentDeleted) const Center(
				child: SizedBox(
					width: 75,
					height: 75,
					child: Icon(CupertinoIcons.xmark_square, size: 36)
				)
			),
			Expanded(
				child: Container(
					constraints: const BoxConstraints(minHeight: 75),
					padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
					child: ChangeNotifierProvider<PostSpanZoneData>(
						create: (ctx) => PostSpanRootZoneData(
							thread: _thread,
							site: context.watch<ImageboardSite>()
						),
						child: Builder(
							builder: (ctx) => IgnorePointer(
								child: LayoutBuilder(
									builder: (context, constraints) => ClippingBox(
										child: _thread.posts[0].span.buildWidget(
											ctx,
											PostSpanRenderOptions(
												avoidBuggyClippers: true,
												maxLines: ((constraints.maxHeight - (DefaultTextStyle.of(context).style.fontSize ?? 17)) / (DefaultTextStyle.of(context).style.fontSize ?? 17)).lazyCeil()
											),
											preInjectRow: headerRow.isEmpty ? null : Text.rich(
												TextSpan(
													children: headerRow
												)
											),
											postInject: WidgetSpan(
												alignment: PlaceholderAlignment.top,
												child: Visibility(
													visible: false,
													maintainState: true,
													maintainAnimation: true,
													maintainSize: true,
													child: _makeCounters()
												)
											)
										)
									)
								)
							)
						)
					)
				)
			)
		];
		final child = Stack(
			fit: StackFit.passthrough,
			children: [
				if (contentFocus) ...[
					Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							if (_thread.attachment != null) Flexible(
								child: LayoutBuilder(
									builder: (context, constraints) {
										return PopupAttachment(
											attachment: _thread.attachment!,
											child: Stack(
												children: [
													HoverPopup(
														style: HoverPopupStyle.floating,
														child: AttachmentThumbnail(
															width: constraints.maxWidth,
															height: constraints.maxHeight,
															fit: BoxFit.cover,
															attachment: _thread.attachment!,
															thread: _thread.identifier,
															onLoadError: onThumbnailLoadError,
															hero: null
														),
														popup: ExtendedImage.network(
															_thread.attachment!.url.toString(),
															cache: true
														)
													),
													if (_thread.attachment?.type == AttachmentType.webm) Positioned(
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
											)
										);
									}
								)
							),
							Expanded(
								child: Container(
									constraints: const BoxConstraints(minHeight: 25),
									padding: const EdgeInsets.all(8),
									child: ChangeNotifierProvider<PostSpanZoneData>(
										create: (ctx) => PostSpanRootZoneData(
											thread: _thread,
											site: context.watch<ImageboardSite>()
										),
										child: Builder(
											builder: (ctx) => IgnorePointer(
												child: ClippingBox(
													child: _thread.posts[0].span.buildWidget(
														ctx,
														PostSpanRenderOptions(
															avoidBuggyClippers: true
														),
														preInjectRow: (thread.title == null) ? null : Text.rich(
															TextSpan(
																text: settings.filterProfanity(_thread.title!),
																style: const TextStyle(fontWeight: FontWeight.bold)
															)
														),
														postInject: WidgetSpan(
															child: Visibility(
																visible: false,
																maintainState: true,
																maintainAnimation: true,
																maintainSize: true,
																child: _makeCounters()
															)
														)
													)
												)
											)
										)
									)
								)
							)
						]
					)
				]
				else Row(
					crossAxisAlignment: CrossAxisAlignment.start,
					mainAxisSize: MainAxisSize.max,
					children: settings.imagesOnRight ? rowChildren().reversed.toList() : rowChildren()
				),
				Positioned.fill(
					child: Align(
						alignment: Alignment.bottomRight,
						child: _makeCounters()
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
			padding: contentFocus ? null : const EdgeInsets.only(left: 8),
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
			valueListenable: context.watch<Persistence>().listenForPersistentThreadStateChanges(thread.identifier),
			builder: (context, box, child) {
				final threadState = context.watch<Persistence>().getThreadStateIfExists(thread.identifier);
				if (threadState == null) {
					return _build(context, threadState);
				}
				else {
					return ValueListenableBuilder(
						valueListenable: threadState.lastSeenPostIdNotifier,
						builder: (context, _, __) => _build(context, context.watch<Persistence>().getThreadStateIfExists(thread.identifier))
					);
				}
			}
		);
	}
}
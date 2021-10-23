import 'dart:math';

import 'package:chan/models/attachment.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/thread_spans.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chan/models/thread.dart';

class ThreadRow extends StatelessWidget {
	final Thread thread;
	final bool isSelected;
	final ValueChanged<Object?>? onThumbnailLoadError;
	final ValueChanged<Attachment>? onThumbnailTap;
	final Iterable<int> semanticParentIds;
	const ThreadRow({
		required this.thread,
		required this.isSelected,
		this.onThumbnailLoadError,
		this.onThumbnailTap,
		this.semanticParentIds = const []
	});
	@override
	Widget build(BuildContext context) {
		return ValueListenableBuilder(
			valueListenable: Persistence.threadStateBox.listenable(keys: ['${thread.board}/${thread.id}']),
			builder: (context, box, child) {
				final threadState = Persistence.getThreadStateIfExists(thread.identifier);
				final _thread = threadState?.thread ?? thread;
				final int latestReplyCount = max(thread.replyCount, _thread.replyCount);
				final int latestImageCount = max(thread.imageCount, _thread.imageCount);
				int unseenReplyCount = 0;
				int unseenYouCount = 0;
				int unseenImageCount = 0;
				Color? replyCountColor;
				Color? imageCountColor;
				if (threadState?.lastSeenPostId != null) {
					unseenReplyCount = (threadState?.unseenReplyCount ?? 0) + ((latestReplyCount + 1) - _thread.posts.length);
					unseenYouCount = threadState?.unseenRepliesToYou?.length ?? 0;
					unseenImageCount = (threadState?.unseenImageCount ?? 0) + ((latestImageCount + 1) - (threadState?.thread?.posts.where((x) => x.attachment != null).length ?? 0));
					replyCountColor = unseenReplyCount == 0 ? Colors.grey : null;
					imageCountColor = unseenImageCount == 0 ? Colors.grey : null;
				}
				return Container(
					decoration: BoxDecoration(
						color: isSelected ? ((CupertinoTheme.of(context).brightness == Brightness.light) ? Colors.grey.shade400 : Colors.grey.shade800) : CupertinoTheme.of(context).scaffoldBackgroundColor
					),
					padding: EdgeInsets.only(left: 8, top: 8),
					child: Stack(
						fit: StackFit.passthrough,
						children: [
							Row(
								crossAxisAlignment: CrossAxisAlignment.start,
								mainAxisSize: MainAxisSize.max,
								children: [
									if (_thread.attachment != null && context.watch<EffectiveSettings>().showImages(_thread.board)) Column(
										mainAxisSize: MainAxisSize.min,
										children: [
											Flexible(
												child: Container(
													padding: EdgeInsets.only(bottom: 8),
													child: GestureDetector(
														child: AttachmentThumbnail(
															attachment: _thread.attachment!,
															thread: _thread.identifier,
															onLoadError: onThumbnailLoadError,
															hero: AttachmentSemanticLocation(
																attachment: _thread.attachment!,
																semanticParents: semanticParentIds
															)
														),
														onTap: () => onThumbnailTap?.call(_thread.attachment!)
													)
												)
											)
										]
									)
									else if (_thread.attachmentDeleted) Center(
										child: SizedBox(
											width: 75,
											height: 75,
											child: Icon(Icons.broken_image, size: 36)
										)
									),
									Expanded(
										child: Container(
											constraints: BoxConstraints(maxHeight: 125, minHeight: 75),
											padding: EdgeInsets.only(left: 8, right: 8),
											child: ChangeNotifierProvider<PostSpanZoneData>(
												create: (ctx) => PostSpanRootZoneData(
													thread: _thread,
													site: context.watch<ImageboardSite>()
												),
												child: Builder(
													builder: (ctx) => IgnorePointer(
														child: Text.rich(
															TextSpan(
																children: [
																	TextSpan(
																		children: [
																			TextSpan(
																				text: context.read<EffectiveSettings>().filterProfanity(_thread.posts[0].name),
																				style: TextStyle(fontWeight: FontWeight.w600)
																			),
																			TextSpan(text: ' '),
																			if (_thread.flag != null) ...[
																				FlagSpan(_thread.flag!),
																				TextSpan(text: ' '),
																				TextSpan(
																					text: _thread.flag!.name,
																					style: TextStyle(
																						fontStyle: FontStyle.italic
																					)
																				),
																				TextSpan(text: ' ')
																			],
																			TextSpan(
																				text: formatTime(_thread.time)
																			),
																			TextSpan(text: ' '),
																			TextSpan(
																				text: _thread.id.toString(),
																				style: TextStyle(color: Colors.grey)
																			),
																			TextSpan(text: '\n')
																		]
																	),
																	if (_thread.title != null) TextSpan(
																		text: context.read<EffectiveSettings>().filterProfanity(_thread.title!) + '\n',
																		style: TextStyle(fontWeight: FontWeight.bold)
																	),
																	_thread.posts[0].span.build(ctx, PostSpanRenderOptions())
																]
															),
															overflow: TextOverflow.fade
														)
													)
												)
											)
										)
									)
								]
							),
							Positioned.fill(
								child: Align(
									alignment: Alignment.bottomRight,
									child: Container(
										decoration: BoxDecoration(
											borderRadius: BorderRadius.only(topLeft: Radius.circular(8)),
											color: CupertinoTheme.of(context).scaffoldBackgroundColor,
											border: Border.all(color: CupertinoTheme.of(context).primaryColor.withBrightness(0.2))
										),
										padding: EdgeInsets.all(2),
										child: Row(
											mainAxisSize: MainAxisSize.min,
											crossAxisAlignment: CrossAxisAlignment.center,
											children: [
												SizedBox(width: 4),
												if (_thread.isSticky) ...[
													Icon(Icons.push_pin, size: 18),
													SizedBox(width: 4),
												],
												if (_thread.isArchived) ...[
													Icon(Icons.archive, color: Colors.grey, size: 18),
													SizedBox(width: 4),
												],
												Icon(Icons.reply_rounded, size: 18, color: replyCountColor),
												SizedBox(width: 4),
												Text(latestReplyCount.toString(), style: TextStyle(color: replyCountColor)),
												if (unseenReplyCount > 0) Text(' (+$unseenReplyCount)'),
												if (unseenYouCount > 0) Text(' (+$unseenYouCount)', style: TextStyle(color: Colors.red)),
												SizedBox(width: 8),
												Icon(Icons.image, size: 18, color: imageCountColor),
												SizedBox(width: 4),
												Text(latestImageCount.toString(), style: TextStyle(color: imageCountColor)),
												if (unseenImageCount > 0) Text(' (+$unseenImageCount)'),
												SizedBox(width: 2)
											]
										)
									)
								)
							)
						]
					)
				);
			}
		);
	}
}
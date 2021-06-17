import 'package:chan/models/attachment.dart';
import 'package:chan/services/persistence.dart';
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
				final unseenReplyCount = threadState?.unseenReplyCount ?? 0;
				final unseenYouCount = threadState?.unseenRepliesToYou?.length ?? 0;
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
									if (_thread.attachment != null) Column(
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
									),
									Expanded(
										child: Container(
											constraints: BoxConstraints(maxHeight: 125),
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
																				text: _thread.posts[0].name,
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
																		],
																		style: TextStyle(fontSize: 14)
																	),
																	if (_thread.title != null) TextSpan(
																		text: _thread.title! + '\n',
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
										child: Row(
											mainAxisSize: MainAxisSize.min,
											crossAxisAlignment: CrossAxisAlignment.center,
											children: [
												SizedBox(width: 4),
												if (_thread.isSticky) ...[
													Icon(Icons.push_pin, size: 14),
													SizedBox(width: 4),
												],
												if (_thread.isArchived) ...[
													Icon(Icons.archive, size: 14, color: Colors.grey),
													SizedBox(width: 4),
												],
												Text(_thread.replyCount.toString(), style: TextStyle(fontSize: 14)),
												if (unseenReplyCount > 0) Text(' (+$unseenReplyCount)', style: TextStyle(fontSize: 14)),
												if (unseenYouCount > 0) Text(' (+$unseenYouCount)', style: TextStyle(fontSize: 14, color: Colors.red)),
												SizedBox(width: 4),
												Icon(Icons.reply_rounded, size: 14),
												SizedBox(width: 8),
												Text(_thread.imageCount.toString(), style: TextStyle(fontSize: 14)),
												SizedBox(width: 4),
												Icon(Icons.image, size: 14),
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
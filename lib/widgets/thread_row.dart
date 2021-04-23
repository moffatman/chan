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
	const ThreadRow({
		required this.thread,
		required this.isSelected,
	});
	@override
	Widget build(BuildContext context) {
		return ValueListenableBuilder(
			valueListenable: Persistence.threadStateBox.listenable(keys: ['${thread.board}/${thread.id}']),
			builder: (context, box, child) {
				final unseenReplyCount = Persistence.getThreadStateIfExists(thread.identifier)?.unseenReplyCount ?? 0;
				return Container(
					padding: EdgeInsets.all(8),
					decoration: BoxDecoration(
						color: isSelected ? ((CupertinoTheme.of(context).brightness == Brightness.light) ? Colors.grey.shade400 : Colors.grey.shade800) : CupertinoTheme.of(context).scaffoldBackgroundColor
					),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						mainAxisSize: MainAxisSize.min,
						children: [
							Text.rich(
								TextSpan(
									children: [
										TextSpan(
											text: thread.posts[0].name,
											style: TextStyle(fontWeight: FontWeight.w600)
										),
										TextSpan(text: ' '),
										if (thread.flag != null) ...[
											FlagSpan(thread.flag!),
											TextSpan(text: ' '),
											TextSpan(
												text: thread.flag!.name,
												style: TextStyle(
													fontStyle: FontStyle.italic
												)
											),
											TextSpan(text: ' ')
										],
										TextSpan(
											text: formatTime(thread.time)
										),
										TextSpan(text: ' '),
										TextSpan(
											text: thread.id.toString(),
											style: TextStyle(color: Colors.grey)
										)
									],
									style: TextStyle(fontSize: 14)
								)
							),
							SizedBox(height: 4),
							Flexible(
								child: IntrinsicHeight(
									child: Row(
										crossAxisAlignment: CrossAxisAlignment.stretch,
										mainAxisSize: MainAxisSize.max,
										mainAxisAlignment: MainAxisAlignment.center,
										children: [
											if (thread.attachment != null) Align(
												alignment: Alignment.topCenter,
												child: AttachmentThumbnail(
													attachment: thread.attachment!
												)
											),
											Expanded(
												child: Container(
													constraints: BoxConstraints(maxHeight: 100),
													padding: EdgeInsets.only(left: 8, right: 8),
													child: ChangeNotifierProvider<PostSpanZoneData>(
														create: (ctx) => PostSpanRootZoneData(
															board: thread.board,
															threadId: thread.id,
															threadState: null,
															site: context.watch<ImageboardSite>(),
															threadPosts: []
														),
														child: Builder(
															builder: (ctx) => IgnorePointer(
																child: Text.rich(
																	TextSpan(
																		children: [
																			if (thread.title != null) TextSpan(
																				text: thread.title! + '\n',
																				style: TextStyle(fontWeight: FontWeight.bold)
																			),
																			thread.posts[0].span.build(ctx, PostSpanRenderOptions())
																		]
																	),
																	overflow: TextOverflow.fade
																)
															)
														)
													)
												)
											),
											Column(
												mainAxisSize: MainAxisSize.max,
												mainAxisAlignment: MainAxisAlignment.end,
												crossAxisAlignment: CrossAxisAlignment.end,
												children: [
													if (thread.isSticky) ...[
														Icon(Icons.push_pin, size: 14),
														SizedBox(height: 4),
													],
													if (thread.isArchived) ...[
														Icon(Icons.archive, size: 14, color: Colors.grey),
														SizedBox(height: 4),
													],
													if (unseenReplyCount > 0) ...[
														Row(
															mainAxisAlignment: MainAxisAlignment.end,
															children: [
																Text('+$unseenReplyCount', style: TextStyle(fontSize: 14, color: Colors.red))
															]
														),
														SizedBox(height: 4),
													],
													Container(
														width: 40,
														child: Row(
															mainAxisAlignment: MainAxisAlignment.end,
															children: [
																Text(thread.replyCount.toString(), style: TextStyle(fontSize: 14)),
																SizedBox(width: 4),
																Icon(Icons.reply_rounded, size: 14)
															]
														)
													),
													SizedBox(height: 4),
													Container(
														width: 40,
														child: Row(
															mainAxisAlignment: MainAxisAlignment.end,
															children: [
																Text(thread.imageCount.toString(), style: TextStyle(fontSize: 14)),
																SizedBox(width: 4),
																Icon(Icons.image, size: 14)
															]
														)
													)
												]
											),
										]
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
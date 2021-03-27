import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';

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
								TextSpan(
									text: thread.id.toString(),
									style: TextStyle(color: Colors.grey)
								),
								TextSpan(text: ' '),
								TextSpan(
									text: formatTime(thread.posts[0].time)
								)
							],
							style: TextStyle(fontSize: 14)
						)
					),
					SizedBox(height: 4),
					IntrinsicHeight(
						child: Row(
							crossAxisAlignment: CrossAxisAlignment.start,
							mainAxisSize: MainAxisSize.max,
							mainAxisAlignment: MainAxisAlignment.center,
							children: [
								if (thread.attachment != null)
									AttachmentThumbnail(
										attachment: thread.attachment!
									),
								Expanded(
									child: Container(
										constraints: BoxConstraints(maxHeight: 100),
										padding: EdgeInsets.only(left: 8, right: 8),
										child: Column(
											mainAxisSize: MainAxisSize.min,
											crossAxisAlignment: CrossAxisAlignment.start,
											mainAxisAlignment: MainAxisAlignment.start,
											children: [
												if (thread.title != null) Text(thread.title!, style: TextStyle(fontWeight: FontWeight.bold)),
												Flexible(child: Provider.value(
													value: thread.posts[0],
													child: Builder(
														builder: (ctx) => IgnorePointer(
															child: Text.rich(thread.posts[0].span.build(ctx), overflow: TextOverflow.fade)
														)
													)
												)),
											]
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
										Container(
											width: 40,
											child: Row(
												mainAxisAlignment: MainAxisAlignment.spaceBetween,
												children: [
													Text(thread.imageCount.toString(), style: TextStyle(fontSize: 14)),
													Icon(Icons.image, size: 14)
												]
											)
										),
										SizedBox(height: 4),
										Container(
											width: 40,
											child: Row(
												mainAxisAlignment: MainAxisAlignment.spaceBetween,
												children: [
													Text(thread.replyCount.toString(), style: TextStyle(fontSize: 14)),
													Icon(Icons.comment, size: 14)
												]
											)
										)
									]
								),
							]
						)
					)
				]
			)
		);
	}
}
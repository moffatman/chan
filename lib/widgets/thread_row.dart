import 'package:chan/widgets/attachment_thumbnail.dart';

import 'package:flutter/material.dart';

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
			decoration: BoxDecoration(
				color: isSelected ? Color(0xFFCCCCCC) : null,
				border: Border(bottom: BorderSide(width: 0, color: Theme.of(context).colorScheme.onBackground))
			),
			child: Row(
				crossAxisAlignment: CrossAxisAlignment.start,
				mainAxisSize: MainAxisSize.max,
				children: [
					if (thread.attachment != null)
						AttachmentThumbnail(
							attachment: thread.attachment!
						),
					Expanded(child: Container(
						padding: EdgeInsets.all(8),
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							mainAxisAlignment: MainAxisAlignment.start,
							children: [
								if (thread.title != null) Text(thread.title!, style: TextStyle(color: Theme.of(context).colorScheme.onBackground)),
								Wrap(children: thread.posts[0].elements)
							]
						)
					))
				]
			)
		);
	}
}
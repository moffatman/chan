import 'package:cached_network_image/cached_network_image.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';

import 'package:flutter/material.dart';

import 'package:chan/models/thread.dart';

class ThreadRow extends StatelessWidget {
	final Thread thread;
	final bool isSelected;
  final bool isDesktop;
	const ThreadRow({
		@required this.thread,
		@required this.isSelected,
    @required this.isDesktop
	});
	@override
	Widget build(BuildContext context) {
		return Container(
			child: Row(
				crossAxisAlignment: CrossAxisAlignment.start,
				mainAxisSize: MainAxisSize.max,
				children: [
					if (thread.attachment != null)
						AttachmentThumbnail(
              attachment: thread.attachment,
              isDesktop: isDesktop
            ),
					Expanded(child: Container(
						padding: EdgeInsets.all(8),
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							mainAxisAlignment: MainAxisAlignment.start,
							children: [
								if (thread.title != null) Text(thread.title),
								Wrap(children: thread.posts[0].elements.map((element) => element.toWidget()).toList())
							]
						)
					))
				]
			)
		);
	}
}
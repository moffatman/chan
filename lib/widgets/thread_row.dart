import 'package:cached_network_image/cached_network_image.dart';

import 'package:flutter/material.dart';

import 'package:chan/models/thread.dart';

class ThreadRow extends StatelessWidget {
	final Thread thread;
	final bool isSelected;
	const ThreadRow({
		@required this.thread,
		@required this.isSelected
	});
	@override
	Widget build(BuildContext context) {
		return Container(
			child: Row(
				crossAxisAlignment: CrossAxisAlignment.start,
				mainAxisSize: MainAxisSize.max,
				children: [
					if (thread.attachment != null)
						CachedNetworkImage(
							width: 75,
							height: 75,
							fit: BoxFit.cover,
							placeholder: (BuildContext context, String url) {
								return SizedBox(
									width: 75,
									height: 75,
									child: Center(
										child: CircularProgressIndicator()
									)
								);
							},
							imageUrl: thread.attachment.thumbnailUrl
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
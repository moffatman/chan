import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:timeago/timeago.dart' as timeago;

import 'package:chan/models/post.dart';
import 'package:chan/models/attachment.dart';

class PostRow extends StatelessWidget {
	final Post post;

	const PostRow({
		@required this.post
	});

	@override
	Widget build(BuildContext context) {
		return Container(
			decoration: BoxDecoration(border: Border(bottom: BorderSide(width: 0, color: Colors.black))),
			child: Row(
				crossAxisAlignment: CrossAxisAlignment.start,
				mainAxisAlignment: MainAxisAlignment.start,
				mainAxisSize: MainAxisSize.max,
				children: [
					post.attachment == null ? SizedBox(width: 0, height: 0) : (CachedNetworkImage(
						width: 75,
						height: 75,
						fit: BoxFit.cover,
						placeholder: (BuildContext context, String url) {
							return Center(child: CircularProgressIndicator());
						},
						imageUrl: post.attachment.thumbnailUrl
					)),
					Expanded(
						child: Container(
							padding: EdgeInsets.all(8),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								mainAxisSize: MainAxisSize.min,
								children: [
									Row(
										mainAxisAlignment: MainAxisAlignment.spaceBetween,
										mainAxisSize: MainAxisSize.max,
										children: [
											Text(post.id.toString(), style: TextStyle(color: Colors.grey)),
											Text(timeago.format(post.time))
										]
									),
									Wrap(children: post.elements.map((element) => element.toWidget()).toList())
								]
							)
						)
					)
				]
			)
		);
	}
}
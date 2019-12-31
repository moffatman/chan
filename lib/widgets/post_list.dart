import 'package:chan/models/attachment.dart';
import 'package:flutter/material.dart';

import 'package:chan/models/post.dart';

import 'post_row.dart';

class PostList extends StatelessWidget {
	final List<Post> list;
	final ValueChanged<Attachment> onThumbnailTap;

	PostList({
		@required this.list,
		this.onThumbnailTap
	});
	
	@override
	Widget build(BuildContext context) {
		return ListView.separated(
			physics: ClampingScrollPhysics(),
			shrinkWrap: true,
			itemCount: list.length,
			itemBuilder: (BuildContext context, int i) {
				return PostRow(
					post: list[i],
					onThumbnailTap: onThumbnailTap
				);
			},
			separatorBuilder: (BuildContext context, int i) {
				return Divider(
					height: 0
				);
			},
		);
	}
}
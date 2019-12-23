import 'package:flutter/material.dart';

import 'package:chan/models/post.dart';

import 'post_row.dart';

class PostList extends StatelessWidget {
	final List<Post> list;
	PostList({@required this.list});
	
	@override
	Widget build(BuildContext context) {
		return ListView.separated(
			physics: ClampingScrollPhysics(),
			shrinkWrap: true,
			itemCount: list.length,
			itemBuilder: (BuildContext context, int i) {
				return PostRow(
					post: list[i]
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
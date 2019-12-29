import 'package:flutter/material.dart';

import 'package:chan/models/post.dart';

import 'post_row.dart';

class PostList extends StatelessWidget {
	final List<Post> list;
  final bool isDesktop;
	PostList({
    @required this.list,
    @required this.isDesktop
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
          isDesktop: isDesktop
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
import 'package:chan/providers/provider.dart';
import 'package:flutter/material.dart';

import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';

import 'package:chan/widgets/post_list.dart';
import 'package:chan/widgets/data_stream_provider.dart';

class ThreadPage extends StatelessWidget {
	final Thread thread;
	final ImageboardProvider provider;
	final GlobalKey<RefreshIndicatorState> refreshKey = GlobalKey();

	ThreadPage({
		@required this.thread,
		@required this.provider
	}) {
		print('created thread page');
	}
	
	@override
	Widget build(BuildContext context) {
		return DataProvider<Thread>(
			updater: () => provider.getThread(thread.board, thread.id),
			initialValue: thread,
			builder: (BuildContext context, dynamic thread, Future<void> Function() requestUpdate) {
				/*Stream<List<Post>> postsStream = stream.handleError((Error error) {
					Scaffold.of(context).showSnackBar(SnackBar(
						content: Text(error.toString())
					));
				}).map((t) => t.posts);*/
				return Scaffold(
					appBar: AppBar(title: Text(thread.id.toString())),
					body: RefreshIndicator(
						key: refreshKey,
						onRefresh: requestUpdate,
						child: ListView(
							children: [
								PostList(list: thread.posts),
								RaisedButton(
									onPressed: () {
										refreshKey.currentState.show();
									},
									child: const Text('Refresh')
								)
							]
						)
					)
				);
			}
		);
	}
}
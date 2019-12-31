import 'package:chan/models/attachment.dart';
import 'package:chan/providers/provider.dart';
import 'package:chan/widgets/attachment_gallery.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';

import 'package:chan/widgets/post_list.dart';
import 'package:chan/widgets/data_stream_provider.dart';
import 'package:chan/widgets/chan_site.dart';

class ThreadPage extends StatefulWidget {
	final Thread thread;
	final ValueChanged<Attachment> onThumbnailTap;
	final GlobalKey<RefreshIndicatorState> refreshKey = GlobalKey();

	ThreadPage({
		@required this.thread,
		this.onThumbnailTap
	});

	@override
	createState() => _ThreadPageState();
}

class _ThreadPageState extends State<ThreadPage> {
	List<Attachment> attachments;

	@override
	Widget build(BuildContext context) {
		return DataProvider<Thread>(
			id: ChanSite.of(context).provider.name + '/' + widget.thread.board + '/' + widget.thread.id.toString(),
			updater: () => ChanSite.of(context).provider.getThread(widget.thread.board, widget.thread.id),
			initialValue: widget.thread,
			onError: (_context, error) {
				Scaffold.of(_context).showSnackBar(SnackBar(
					content: Text("Error: " + error.toString())
				));
			},
			placeholder: (context, Thread thread) {
				return Scaffold(
					appBar: AppBar(title: Text(thread.id.toString())),
					body: Center(
						child: CircularProgressIndicator()
					)
				);
			},
			builder: (BuildContext context, Thread thread, Future<void> Function() requestUpdate) {
				return Scaffold(
					appBar: AppBar(title: Text(thread.id.toString())),
					body: RefreshIndicator(
						key: widget.refreshKey,
						onRefresh: requestUpdate,
						child: ListView(
							children: [
								PostList(
									list: thread.posts,
									onThumbnailTap: (attachment) {
										Navigator.of(context).push(CupertinoPageRoute(builder: (ctx) => Scaffold(
											appBar: AppBar(),
											body: AttachmentGallery(
												attachments: thread.posts.where((_) => _.attachment != null).map((_) => _.attachment).toList(),
												initialAttachment: attachment
											)
										)));
									},
								),
								RaisedButton(
									onPressed: () {
										widget.refreshKey.currentState.show();
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
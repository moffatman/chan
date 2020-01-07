import 'package:chan/models/attachment.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/providers/provider.dart';
import 'package:chan/widgets/attachment_gallery.dart';
import 'package:chan/widgets/gallery_manager.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/provider_list.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';

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
	Thread thread;

	@override
	Widget build(BuildContext context) {
		return CupertinoPageScaffold(
			child: ProviderList<Post>(
				title: '/${widget.thread.board}/${widget.thread.id}',
				listUpdater: () async {
					final _thread = await ChanSite.of(context).provider.getThread(widget.thread.board, widget.thread.id);
					setState(() {
						thread = _thread;
					});
					return _thread.posts;
				},
				builder: (context, post) {
					return PostRow(
						post: post,
						onThumbnailTap: (attachment) {
							showGallery(
								context: context,
								attachments: thread.posts.where((_) => _.attachment != null).map((_) => _.attachment).toList(),
								initialAttachment: attachment
							);
						}
					);
				}
			)
		);
	}
}
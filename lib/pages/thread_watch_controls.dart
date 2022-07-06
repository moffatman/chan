import 'package:chan/models/thread.dart';
import 'package:chan/pages/overscroll_modal.dart';
import 'package:chan/services/notifications.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

enum _ThreadWatchingStatus {
	off,
	yousOnly,
	allPosts
}

class ThreadWatchControlsPage extends StatelessWidget {
	final ThreadIdentifier thread;
	const ThreadWatchControlsPage({
		required this.thread,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		final persistence = context.watch<Persistence>(); // rebuild when watch changes
		final notifications = context.watch<Notifications>();
		ThreadWatch? watch = notifications.getThreadWatch(thread);
		_ThreadWatchingStatus localWatcherStatus = _ThreadWatchingStatus.off;
		_ThreadWatchingStatus pushWatcherStatus = _ThreadWatchingStatus.off;
		if (watch != null) {
			localWatcherStatus = watch.localYousOnly ? _ThreadWatchingStatus.yousOnly : _ThreadWatchingStatus.allPosts;
			if (watch.push) {
				pushWatcherStatus = watch.pushYousOnly ? _ThreadWatchingStatus.yousOnly : _ThreadWatchingStatus.allPosts;
			}
		}
		return OverscrollModalPage(
			child: Container(
				width: double.infinity,
				padding: const EdgeInsets.all(16),
				color: CupertinoTheme.of(context).scaffoldBackgroundColor,
				alignment: Alignment.center,
				child: ConstrainedBox(
					constraints: const BoxConstraints(
						maxWidth: 500
					),
					child: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							Center(
								child: Text('Thread notifications for /${thread.board}/${thread.id}', style: const TextStyle(
									fontSize: 18
								))
							),
							const SizedBox(height: 16),
							const Text('Local Watcher'),
							Padding(
								padding: const EdgeInsets.all(16),
								child: CupertinoSegmentedControl<_ThreadWatchingStatus>(
									children: const {
										_ThreadWatchingStatus.off: Padding(
											padding: EdgeInsets.all(8),
											child: Text('Off')
										),
										_ThreadWatchingStatus.yousOnly: Padding(
											padding: EdgeInsets.all(8),
											child: Text('(You)s only')
										),
										_ThreadWatchingStatus.allPosts: Padding(
											padding: EdgeInsets.all(8),
											child: Text('All posts')
										)
									},
									groupValue: localWatcherStatus,
									onValueChanged: (v) {
										if (watch == null) {
											final ts = persistence.getThreadStateIfExists(thread);
											notifications.subscribeToThread(
												thread: thread,
												lastSeenId: ts?.lastSeenPostId ?? thread.id,
												localYousOnly: v == _ThreadWatchingStatus.yousOnly,
												pushYousOnly: true,
												youIds: ts?.youIds ?? [],
												push: false
											);
										}
										else {
											switch (v) {
												case _ThreadWatchingStatus.off:
													notifications.removeThreadWatch(watch);
													break;
												case _ThreadWatchingStatus.yousOnly:
													watch.localYousOnly = true;
													notifications.didUpdateThreadWatch(watch);
													break;
												case _ThreadWatchingStatus.allPosts:
													watch.localYousOnly = false;
													notifications.didUpdateThreadWatch(watch);
													break;
											}
										}
									}
								)
							),
							const SizedBox(height: 16),
							const Text('Push Notifications'),
							Padding(
								padding: const EdgeInsets.all(16),
								child: CupertinoSegmentedControl<_ThreadWatchingStatus>(
									children: const {
										_ThreadWatchingStatus.off: Padding(
											padding: EdgeInsets.all(8),
											child: Text('Off')
										),
										_ThreadWatchingStatus.yousOnly: Padding(
											padding: EdgeInsets.all(8),
											child: Text('(You)s only')
										),
										_ThreadWatchingStatus.allPosts: Padding(
											padding: EdgeInsets.all(8),
											child: Text('All posts')
										)
									},
									groupValue: pushWatcherStatus,
									onValueChanged: (v) {
										if (watch == null) {
											final ts = persistence.getThreadStateIfExists(thread);
											notifications.subscribeToThread(
												thread: thread,
												lastSeenId: ts?.lastSeenPostId ?? thread.id,
												localYousOnly: v == _ThreadWatchingStatus.yousOnly,
												pushYousOnly: v == _ThreadWatchingStatus.yousOnly,
												youIds: ts?.youIds ?? [],
												push: true
											);
										}
										else {
											switch (v) {
												case _ThreadWatchingStatus.off:
													watch.push = false;
													break;
												case _ThreadWatchingStatus.yousOnly:
													watch.push = true;
													watch.pushYousOnly = true;
													break;
												case _ThreadWatchingStatus.allPosts:
													watch.push = true;
													watch.localYousOnly = false;
													watch.pushYousOnly = false;
													break;
											}
											notifications.didUpdateThreadWatch(watch, possiblyDisabledPush: true);
										}
									}
								)
							)
						]
					)
				)
			)
		);
	}
}
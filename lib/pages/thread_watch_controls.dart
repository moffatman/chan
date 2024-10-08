import 'package:chan/models/thread.dart';
import 'package:chan/pages/overscroll_modal.dart';
import 'package:chan/services/notifications.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/util.dart';
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
		final settings = context.watch<Settings>();
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
				color: ChanceTheme.backgroundColorOf(context),
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
								child: AdaptiveSegmentedControl<_ThreadWatchingStatus>(
									children: const {
										_ThreadWatchingStatus.off: (null, 'Off'),
										_ThreadWatchingStatus.yousOnly: (null, '(You)s only'),
										_ThreadWatchingStatus.allPosts: (null, 'All posts')
									},
									groupValue: localWatcherStatus,
									onValueChanged: (v) {
										if (watch == null) {
											final ts = persistence.getThreadStateIfExists(thread);
											notifications.subscribeToThread(
												thread: thread,
												lastSeenId: ts?.lastSeenPostId ?? ts?.thread?.posts_.last.id ?? thread.id,
												localYousOnly: v == _ThreadWatchingStatus.yousOnly,
												pushYousOnly: true,
												youIds: ts?.youIds ?? [],
												push: false,
												notifyOnSecondLastPage: settings.defaultThreadWatch?.notifyOnSecondLastPage ?? false,
												notifyOnLastPage: settings.defaultThreadWatch?.notifyOnLastPage ?? true,
												notifyOnDead: settings.defaultThreadWatch?.notifyOnDead ?? false
											);
										}
										else {
											switch (v) {
												case _ThreadWatchingStatus.off:
													notifications.removeWatch(watch);
													break;
												case _ThreadWatchingStatus.yousOnly:
													watch.localYousOnly = true;
													notifications.didUpdateWatch(watch);
													break;
												case _ThreadWatchingStatus.allPosts:
													watch.localYousOnly = false;
													notifications.didUpdateWatch(watch);
													break;
											}
										}
									}
								)
							),
							if (context.watch<ImageboardSite>().supportsPushNotifications) ...[
								const SizedBox(height: 16),
								const Text('Push Notifications'),
								Padding(
									padding: const EdgeInsets.all(16),
									child: AdaptiveSegmentedControl<_ThreadWatchingStatus>(
										children: const {
											_ThreadWatchingStatus.off: (null, 'Off'),
											_ThreadWatchingStatus.yousOnly: (null, '(You)s only'),
											_ThreadWatchingStatus.allPosts: (null, 'All posts')
										},
										groupValue: pushWatcherStatus,
										onValueChanged: (v) {
											if (watch == null) {
												final ts = persistence.getThreadStateIfExists(thread);
												notifications.subscribeToThread(
													thread: thread,
													lastSeenId: ts?.lastSeenPostId ?? ts?.thread?.posts_.last.id ?? thread.id,
													localYousOnly: v == _ThreadWatchingStatus.yousOnly,
													pushYousOnly: v == _ThreadWatchingStatus.yousOnly,
													youIds: ts?.youIds ?? [],
													push: true,
													notifyOnSecondLastPage: settings.defaultThreadWatch?.notifyOnSecondLastPage ?? false,
													notifyOnLastPage: settings.defaultThreadWatch?.notifyOnLastPage ?? true,
													notifyOnDead: settings.defaultThreadWatch?.notifyOnDead ?? false
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
												notifications.didUpdateWatch(watch, possiblyDisabledPush: true);
											}
										}
									)
								),
								const SizedBox(height: 16),
								Row(
									children: [
										const Expanded(
											child: Text('Alert when on second-last page')
										),
										const SizedBox(width: 8),
										AdaptiveSwitch(
											value: (watch?.notifyOnSecondLastPage ?? false) && (watch?.push ?? false),
											onChanged: (v) {
												if (watch == null) {
													final ts = persistence.getThreadStateIfExists(thread);
													notifications.subscribeToThread(
														thread: thread,
														lastSeenId: ts?.lastSeenPostId ?? ts?.thread?.posts_.last.id ?? thread.id,
														localYousOnly: true,
														pushYousOnly: true,
														youIds: ts?.youIds ?? [],
														push: true,
														notifyOnSecondLastPage: v,
														notifyOnLastPage: settings.defaultThreadWatch?.notifyOnLastPage ?? true,
														notifyOnDead: settings.defaultThreadWatch?.notifyOnDead ?? false
													);
												}
												else {
													watch.push |= v;
													watch.notifyOnSecondLastPage = v;
													notifications.didUpdateWatch(watch);
												}
											}
										)
									]
								),
								const SizedBox(height: 16),
								Row(
									children: [
										const Expanded(
											child: Text('Alert when on last page')
										),
										const SizedBox(width: 8),
										AdaptiveSwitch(
											value: (watch?.notifyOnLastPage ?? false) && (watch?.push ?? false),
											onChanged: (v) {
												if (watch == null) {
													final ts = persistence.getThreadStateIfExists(thread);
													notifications.subscribeToThread(
														thread: thread,
														lastSeenId: ts?.lastSeenPostId ?? ts?.thread?.posts_.last.id ?? thread.id,
														localYousOnly: true,
														pushYousOnly: true,
														youIds: ts?.youIds ?? [],
														push: true,
														notifyOnSecondLastPage: settings.defaultThreadWatch?.notifyOnSecondLastPage ?? false,
														notifyOnLastPage: v,
														notifyOnDead: settings.defaultThreadWatch?.notifyOnDead ?? false
													);
												}
												else {
													watch.push |= v;
													watch.notifyOnLastPage = v;
													notifications.didUpdateWatch(watch);
												}
											}
										)
									]
								),
								const SizedBox(height: 16),
								Row(
									children: [
										const Expanded(
											child: Text('Alert when thread dies')
										),
										const SizedBox(width: 8),
										AdaptiveSwitch(
											value: (watch?.notifyOnDead ?? false) && (watch?.push ?? false),
											onChanged: (v) {
												if (watch == null) {
													final ts = persistence.getThreadStateIfExists(thread);
													notifications.subscribeToThread(
														thread: thread,
														lastSeenId: ts?.lastSeenPostId ?? ts?.thread?.posts_.last.id ?? thread.id,
														localYousOnly: true,
														pushYousOnly: true,
														youIds: ts?.youIds ?? [],
														push: true,
														notifyOnSecondLastPage: settings.defaultThreadWatch?.notifyOnDead ?? false,
														notifyOnLastPage: settings.defaultThreadWatch?.notifyOnLastPage ?? true,
														notifyOnDead: v
													);
												}
												else {
													watch.push |= v;
													watch.notifyOnDead = v;
													notifications.didUpdateWatch(watch);
												}
											}
										)
									]
								),
								const SizedBox(height: 16),
								Row(
									children: [
										const Expanded(
											child: Text('In-App Notifications')
										),
										const SizedBox(width: 8),
										AdaptiveSwitch(
											value: !(watch?.foregroundMuted ?? true) && (watch?.push ?? false),
											onChanged: (v) {
												if (watch == null && v) {
													final ts = persistence.getThreadStateIfExists(thread);
													notifications.subscribeToThread(
														thread: thread,
														lastSeenId: ts?.lastSeenPostId ?? ts?.thread?.posts_.last.id ?? thread.id,
														localYousOnly: true,
														pushYousOnly: true,
														youIds: ts?.youIds ?? [],
														push: true,
														notifyOnSecondLastPage: settings.defaultThreadWatch?.notifyOnSecondLastPage ?? false,
														notifyOnLastPage: settings.defaultThreadWatch?.notifyOnLastPage ?? true,
														notifyOnDead: settings.defaultThreadWatch?.notifyOnDead ?? false
													);
												}
												else if (watch != null) {
													if (v) {
														watch.push = true;
														notifications.foregroundUnmuteThread(watch.threadIdentifier);
													}
													else {
														notifications.foregroundMuteThread(watch.threadIdentifier);
													}
												}
											}
										)
									]
								),
								const SizedBox(height: 16),
								Row(
									mainAxisAlignment: MainAxisAlignment.center,
									children: [
										AdaptiveButton(
											onPressed: (watch != null && !(settings.defaultThreadWatch?.settingsEquals(watch) ?? false)) ? () async {
												final ok = await confirm(context, 'After setting a default watch setting, this menu will only open when long-pressing the watch icon.');
												if (ok != true) {
													return;
												}
												Settings.defaultThreadWatchSetting.value = ThreadWatch(
													board: '',
													threadId: 0,
													lastSeenId: 0,
													localYousOnly: watch.localYousOnly,
													youIds: [],
													pushYousOnly: watch.pushYousOnly,
													foregroundMuted: watch.foregroundMuted,
													push: watch.push,
													notifyOnSecondLastPage: watch.notifyOnSecondLastPage,
													notifyOnLastPage: watch.notifyOnLastPage,
													notifyOnDead: watch.notifyOnDead,
													watchTime: DateTime.now()
												);
											} : null,
											child: const Text('Use as default without asking')
										),
										AdaptiveIconButton(
											onPressed: settings.defaultThreadWatch == null ? null : () {
												Settings.defaultThreadWatchSetting.value = null;
											},
											icon: const Icon(CupertinoIcons.xmark)
										)
									]
								)
							]
						]
					)
				)
			)
		);
	}
}
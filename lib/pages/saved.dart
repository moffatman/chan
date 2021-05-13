import 'package:chan/models/thread.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/widgets/thread_row.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

class SavedPage extends StatelessWidget {
	@override
	Widget build(BuildContext context) {
		final settings = context.watch<EffectiveSettings>();
		return MasterDetailPage<ThreadIdentifier>(
			masterBuilder: (context, selectedThread, threadSetter) {
				return CupertinoPageScaffold(
					navigationBar: CupertinoNavigationBar(
						transitionBetweenRoutes: false,
						middle: Text('Saved'),
						trailing: CupertinoButton(
							padding: EdgeInsets.zero,
							child: Icon(Icons.sort),
							onPressed: () {
								showCupertinoModalPopup<DateTime>(
									context: context,
									builder: (context) => CupertinoActionSheet(
										title: const Text('Sort by...'),
										actions: {
											ThreadSortingMethod.SavedTime: 'Saved Order',
											ThreadSortingMethod.LastPostTime: 'Bump Order',
										}.entries.map((entry) => CupertinoActionSheetAction(
											child: Text(entry.value, style: TextStyle(
												fontWeight: entry.key == settings.savedThreadsSortingMethod ? FontWeight.bold : null
											)),
											onPressed: () {
												settings.savedThreadsSortingMethod = entry.key;
												Navigator.of(context, rootNavigator: true).pop();
											}
										)).toList(),
										cancelButton: CupertinoActionSheetAction(
											child: const Text('Cancel'),
											onPressed: () => Navigator.of(context, rootNavigator: true).pop()
										)
									)
								);
							}
						)
					),
					child: SafeArea(
						child: Column(
							children: [
								ThreadWatcherControls(),
								Divider(
									thickness: 1,
									height: 0,
									color: CupertinoTheme.of(context).primaryColor.withBrightness(0.2)
								),
								Expanded(
									child: ValueListenableBuilder(
										valueListenable: Persistence.threadStateBox.listenable(),
										builder: (context, Box<PersistentThreadState> box, child) {
											final states = box.toMap().entries.where((e) => e.value.savedTime != null).toList();
											if (settings.savedThreadsSortingMethod == ThreadSortingMethod.SavedTime) {
												states.sort((a, b) => b.value.savedTime!.compareTo(a.value.savedTime!));
											}
											else if (settings.savedThreadsSortingMethod == ThreadSortingMethod.LastPostTime) {
												final noDate = DateTime.fromMillisecondsSinceEpoch(0);
												states.sort((a, b) => (b.value.thread?.posts.last.time ?? noDate).compareTo(a.value.thread?.posts.last.time ?? noDate));
											}
											return ListView.separated(
												itemCount: states.length,
												separatorBuilder: (context, i) => Divider(
													thickness: 1,
													height: 0,
													color: CupertinoTheme.of(context).primaryColor.withBrightness(0.2)
												),
												itemBuilder: (context, i) => GestureDetector(
													behavior: HitTestBehavior.opaque,
													child: ThreadRow(
														thread: states[i].value.thread!,
														isSelected: states[i].value.thread!.identifier == selectedThread,
														onThumbnailLoadError: (error) {
															context.read<ThreadWatcher>().fixBrokenThread(states[i].value.thread!.identifier);
														},
													),
													onTap: () => threadSetter(states[i].value.thread!.identifier)
												)
											);
										}
									)
								)
							]
						)
					)
				);
			},
			detailBuilder: (context, selectedThread) {
				return selectedThread != null ? ThreadPage(thread: selectedThread) : Container(
					decoration: BoxDecoration(
						color: CupertinoTheme.of(context).scaffoldBackgroundColor,
					),
					child: Center(
						child: Text('Select a thread')
					)
				);
			}
		);
	}
}

class ThreadWatcherControls extends StatefulWidget {
	createState() => _ThreadWatcherControls();
}
class _ThreadWatcherControls extends State<ThreadWatcherControls> with SingleTickerProviderStateMixin {
	@override
	Widget build(BuildContext context) {
		final watcher = context.watch<ThreadWatcher>();
		return AnimatedSize(
			duration: Duration(milliseconds: 300),
			vsync: this,
			child: Container(
				padding: EdgeInsets.all(8),
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						Row(
							children: [
								Text('Thread Watcher'),
								Spacer(),
								CupertinoButton(
									child: Icon(Icons.refresh),
									onPressed: watcher.update
								),
								CupertinoSwitch(
									value: watcher.active,
									onChanged: (val) {
										if (val) {
											watcher.update();
										}
										else {
											watcher.cancel();
										}
									}
								)
							]
						)
					]
				)
			)
		);
	}
}
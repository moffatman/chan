import 'package:chan/models/thread.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/widgets/context_menu.dart';
import 'package:chan/widgets/thread_row.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HistoryPage extends StatelessWidget {
	@override
	Widget build(BuildContext context) {
		return MasterDetailPage<ThreadIdentifier>(
			masterBuilder: (context, selectedThread, threadSetter) {
				return CupertinoPageScaffold(
					navigationBar: CupertinoNavigationBar(
						transitionBetweenRoutes: false,
						middle: Text('History')
					),
					child: ValueListenableBuilder(
						valueListenable: Persistence.threadStateBox.listenable(),
						builder: (context, Box<PersistentThreadState> box, child) {
							final states = box.toMap().entries.where((e) => e.value.thread != null).toList();
							states.sort((a, b) => b.value.lastOpenedTime.compareTo(a.value.lastOpenedTime));
							return ListView.separated(
								itemCount: states.length,
								separatorBuilder: (context, i) => Divider(
									thickness: 1,
									height: 0,
									color: CupertinoTheme.of(context).primaryColor.withBrightness(0.2)
								),
								itemBuilder: (context, i) => ContextMenu(
									child: GestureDetector(
										behavior: HitTestBehavior.opaque,
										child: ThreadRow(
											thread: states[i].value.thread!,
											isSelected: states[i].value.thread!.identifier == selectedThread
										),
										onTap: () => threadSetter(states[i].value.thread!.identifier)
									),
									actions: [
										ContextMenuAction(
											child: Text('Remove'),
											onPressed: states[i].value.delete,
											trailingIcon: Icons.delete,
											isDestructiveAction: true
										)
									]
								)
							);
						}
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
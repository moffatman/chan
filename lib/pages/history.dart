import 'package:chan/models/thread.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/widgets/context_menu.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:chan/widgets/thread_row.dart';
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
							final states = box.toMap().values.where((s) => s.thread != null).toList();
							states.sort((a, b) => b.lastOpenedTime.compareTo(a.lastOpenedTime));
							return RefreshableList<PersistentThreadState>(
								listUpdater: () => throw UnimplementedError(),
								id: 'history',
								disableUpdates: true,
								initialList: states,
								itemBuilder: (context, state) => ContextMenu(
									child: GestureDetector(
										behavior: HitTestBehavior.opaque,
										child: ThreadRow(
											thread: state.thread!,
											isSelected: state.thread!.identifier == selectedThread
										),
										onTap: () => threadSetter(state.thread!.identifier)
									),
									actions: [
										ContextMenuAction(
											child: Text('Remove'),
											onPressed: state.delete,
											trailingIcon: Icons.delete,
											isDestructiveAction: true
										)
									]
								),
								filterHint: 'Search history'
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
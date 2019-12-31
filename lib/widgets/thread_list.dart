import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'package:chan/models/thread.dart';

import 'thread_row.dart';

class ThreadList extends StatelessWidget {
	final List<Thread> list;
	final ValueChanged<Thread> onThreadSelected;
	final Thread selectedThread;

	const ThreadList({
		@required this.list,
		@required this.onThreadSelected,
		@required this.selectedThread
	});
	
	@override
	Widget build(BuildContext context) {
		if (list != null) {
			return ListView.separated(
				shrinkWrap: true,
				itemBuilder: (BuildContext context, int i) {
					return InkWell(
						onTap: () {
							onThreadSelected(list[i]);
						},
						child: ThreadRow(
							thread: list[i],
							isSelected: list[i] == selectedThread
						)
					);
				},
				itemCount: list.length,
				separatorBuilder: (BuildContext context, int i) {
					return Divider(
						height: 0
					);
				}
			);
		}
		else {
			return Center(
				child: CircularProgressIndicator()
			);
		}
	}
}
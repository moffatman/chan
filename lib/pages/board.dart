import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/provider_list.dart';
import 'package:chan/widgets/thread_row.dart';
import 'package:flutter/cupertino.dart';

import 'package:chan/models/thread.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BoardPage extends StatelessWidget {
	final ValueChanged<Thread> onThreadSelected;
	final Thread? selectedThread;
	final String board;
	final VoidCallback? onHeaderTapped;
	BoardPage({
		required this.onThreadSelected,
		this.selectedThread,
		required this.board,
		this.onHeaderTapped
	});

	@override
	Widget build(BuildContext context) {
		final site = context.watch<ImageboardSite>();
		return CupertinoPageScaffold(
			navigationBar: CupertinoNavigationBar(
				middle: GestureDetector(
					onTap: onHeaderTapped,
					child: Row(
						mainAxisSize: MainAxisSize.min,
						children: [
							Text('/$board/'),
							Icon(Icons.arrow_drop_down)
						]
					)
				)
			),
			child: ProviderList<Thread>(
				listUpdater: () => site.getCatalog(board),
				id: '/$board/',
				lazy: true,
				builder: (context, thread) {
					return GestureDetector(
						behavior: HitTestBehavior.opaque,
						child: ThreadRow(
							thread: thread,
							isSelected: thread == selectedThread
						),
						onTap: () => onThreadSelected(thread)
					);
				}
			)
		);
	}
}
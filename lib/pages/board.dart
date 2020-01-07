import 'package:chan/widgets/provider_list.dart';
import 'package:chan/widgets/thread_row.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';

import 'package:chan/models/thread.dart';
import 'package:chan/widgets/chan_site.dart';
import 'package:flutter/material.dart';

class BoardPage extends StatelessWidget {
	final void Function(Thread selectedThread) onThreadSelected;
	final Thread selectedThread;
	final String board;
	BoardPage({
		@required this.onThreadSelected,
		@required this.selectedThread,
		@required this.board
	});

	@override
	Widget build(BuildContext context) {
		final site = ChanSite.of(context).provider;
		return CupertinoPageScaffold(
			child: ProviderList<Thread>(
				listUpdater: () => site.getCatalog(board),
				title: '/$board/',
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
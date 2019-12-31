import 'package:flutter/material.dart';

import 'package:chan/models/thread.dart';
import 'package:chan/widgets/chan_site.dart';
import 'package:chan/widgets/data_stream_provider.dart';
import 'package:chan/widgets/thread_list.dart';

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
		return Scaffold(
			appBar: AppBar(
				title: Text(site.name + ': ' + board),
			),
			body: DataProvider<List<Thread>>(
				id: site.name + '/' + board,
				updater: () => site.getCatalog(board),
				initialValue: [],
				placeholder: (BuildContext context, value) {
					return Center(
						child: CircularProgressIndicator()
					);
				},
				builder: (BuildContext context, List<Thread> catalog, Future<void> Function() requestUpdate) {
					return RefreshIndicator(
						onRefresh: requestUpdate,
						child: ThreadList(
							list: catalog,
							selectedThread: null,
							onThreadSelected: onThreadSelected
						)
					);
				},
				onError: (_context, error) {
					Scaffold.of(_context).showSnackBar(SnackBar(
						content: Text('Error loading: $error')
					));
				}
			)
		);
	}
}
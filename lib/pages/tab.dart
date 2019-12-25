import 'package:chan/models/thread.dart';
import 'package:chan/providers/provider.dart';
import 'package:chan/widgets/thread_list.dart';

import 'package:flutter/material.dart';

import 'package:chan/pages/thread.dart';

import 'package:chan/widgets/data_stream_provider.dart';
import 'package:chan/widgets/provider_provider.dart';

class ImageboardTab extends StatefulWidget {
	final bool isInTabletLayout;
	final ImageboardProvider initialSite;
	final String initialBoard;
	const ImageboardTab({
		@required this.isInTabletLayout,
		this.initialBoard,
		this.initialSite
	});
	@override
	_ImageboardTabState createState() => _ImageboardTabState();
}

const List<Thread> emptyThreadList = [];

class _ImageboardTabState extends State<ImageboardTab> {
	ImageboardProvider site;
	String board;
	Thread selectedThread;
	@override
	initState() {
		super.initState();
		setState(() {
			site = widget.initialSite;
			board = widget.initialBoard;
		});
	}
	Widget _buildTablet(BuildContext context) {
		return Row(
				children: [
					Flexible(
						flex: 1,
						child: Scaffold(
							appBar: AppBar(
								title: Text(site.name + ': ' + board)
							),
							body: DataProvider<List<Thread>>(
								updater: () => site.getCatalog(board),
								initialValue: emptyThreadList,
								builder: (BuildContext context, dynamic catalog, Future<void> Function() requestUpdate) {
									return RefreshIndicator(
										onRefresh: requestUpdate,
										child: catalog != null ? ThreadList(
											list: catalog as List<Thread>,
											selectedThread: selectedThread,
											onThreadSelected: (thread) {
												setState(() {
													selectedThread = thread;
												});
											},
										) : Center(
											child: CircularProgressIndicator()
										)
									);
								}
							)
						)
					),
					VerticalDivider(
						width: 0
					),
					Flexible(
						flex: 3,
						child: selectedThread != null ? ThreadPage(
							thread: selectedThread,
							provider: site
						) : Center(child: Text('Select a thread'))
					)
				]
			);
	}
	Widget _buildPhone(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: Text('xd'),
			),
			body: DataProvider<List<Thread>>(
				updater: () => site.getCatalog(board),
				initialValue: emptyThreadList,
				builder: (BuildContext context, List<Thread> catalog, Future<void> Function() requestUpdate) {
					return RefreshIndicator(
						onRefresh: requestUpdate,
						child: ThreadList(
							list: catalog,
							selectedThread: selectedThread,
							onThreadSelected: (thread) {
								Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => ThreadPage(thread: selectedThread, provider: site)));
							},
						)
					);
				}
			)
		);
	}
	@override
	Widget build(BuildContext context) {
		return ProviderProvider(
			provider: site,
			child: widget.isInTabletLayout ? _buildTablet(context) : _buildPhone(context)
		);
	}
}
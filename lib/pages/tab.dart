import 'package:chan/models/thread.dart';
import 'package:chan/providers/provider.dart';
import 'package:chan/widgets/thread_list.dart';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'package:chan/pages/thread.dart';

import 'package:chan/widgets/data_stream_provider.dart';
import 'package:chan/widgets/provider_provider.dart';

class ImageboardTab extends StatefulWidget {
	final bool isInTabletLayout;
	final ImageboardProvider initialSite;
	final String initialBoard;
  final bool isDesktop;
	const ImageboardTab({
		@required this.isInTabletLayout,
    @required this.isDesktop,
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
                id: site.name + '/' + board,
								updater: () => site.getCatalog(board),
								initialValue: emptyThreadList,
                placeholder: (context, value) {
                  return Center(
                    child: CircularProgressIndicator()
                  );
                },
								builder: (BuildContext context, dynamic catalog, Future<void> Function() requestUpdate) {
									return RefreshIndicator(
										onRefresh: requestUpdate,
										child: catalog != null ? ThreadList(
											list: catalog as List<Thread>,
											selectedThread: selectedThread,
                      isDesktop: widget.isDesktop,
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
							provider: site,
              isDesktop: widget.isDesktop
						) : Center(child: Text('Select a thread'))
					)
				]
			);
	}
	Widget _buildPhone(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: Text(site.name + ': ' + board),
			),
			body: DataProvider<List<Thread>>(
        id: site.name + '/' + board,
				updater: () => site.getCatalog(board),
				initialValue: emptyThreadList,
        placeholder: (BuildContext context, value) {
          return Center(
            child: CircularProgressIndicator()
          );
        },
				builder: (BuildContext context, dynamic catalog, Future<void> Function() requestUpdate) {
					return RefreshIndicator(
						onRefresh: requestUpdate,
						child: ThreadList(
							list: catalog as List<Thread>,
							selectedThread: null,
              isDesktop: widget.isDesktop,
							onThreadSelected: (thread) {
								Navigator.of(context).push(CupertinoPageRoute(builder: (ctx) => ThreadPage(
                  thread: thread,
                  provider: site,
                  isDesktop: widget.isDesktop
                )));
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
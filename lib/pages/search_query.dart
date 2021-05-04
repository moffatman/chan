import 'package:chan/models/search.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/pages/search.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chan/widgets/cupertino_page_route.dart';


class SearchQueryPage extends StatefulWidget {
	final ImageboardArchiveSearchQuery query;
	SearchQueryPage(this.query);
	createState() => _SearchQueryPageState();
}

class _SearchQueryPageState extends State<SearchQueryPage> {
	ImageboardArchiveSearchResult? result;
	String? errorMessage;
	int? page;

	@override
	void initState() {
		super.initState();
		_runQuery();
	}

	void _runQuery() async {
		setState(() {
			this.result = null;
			this.errorMessage = null;
		});
		try {
			this.result = await context.read<ImageboardSite>().search(widget.query, page: page ?? 1);
			page = result!.page;
			if (mounted) setState(() {});
		}
		catch (e, st) {
			print(e);
			print(st);
			this.errorMessage = e.toString();
			if (mounted) setState(() {});
		}
	}

	Widget _buildPagination() {
		return Row(
			mainAxisAlignment: MainAxisAlignment.spaceAround,
			children: [
				CupertinoButton(
					child: Text('1'),
					onPressed: (result!.page == 1) ? null : () {
						page = 1;
						_runQuery();
					}
				),
				Spacer(),
				CupertinoButton(
					child: Icon(Icons.navigate_before),
					onPressed: (result!.page == 1) ? null : () {
						page = page! - 1;
						_runQuery();
					}
				),
				Text('Page ${result!.page}'),
				CupertinoButton(
					child: Icon(Icons.navigate_next),
					onPressed: (result!.page == result!.maxPage) ? null : () {
						page = page! + 1;
						_runQuery();
					}
				),
				Spacer(),
				CupertinoButton(
					child: Text('${result!.maxPage}'),
					onPressed: (result!.page == result!.maxPage) ? null : () {
						page = result!.maxPage;
						_runQuery();
					}
				),
			]
		);
	}

	Widget _build(BuildContext context) {
		if (this.result != null) {
			return ListView.builder(
				itemCount: result!.posts.length + 2,
				itemBuilder: (context, i) {
					if (i == 0 || i == result!.posts.length + 1) {
						return _buildPagination();
					}
					final post = result!.posts[i - 1];
					return PostRow(
						post: post,
						onThumbnailTap: (attachment) => showGallery(
							context: context,
							attachments: [attachment],
							semanticParentIds: []
						),
						showCrossThreadLabel: false,
						allowTappingLinks: false,
						onTap: () async {
							Navigator.of(context).push(FullWidthCupertinoPageRoute(
								builder: (context) => ThreadPage(
									thread: post.threadIdentifier,
									initialPostId: post.id,
									initiallyUseArchive: true
								)
							));
						}
					);
				}
			);
		}
		else if (this.errorMessage != null) {
			return Center(
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						ErrorMessageCard(this.errorMessage!),
						CupertinoButton(
							child: Text('Retry'),
							onPressed: _runQuery
						)
					]
				)
			);
		}
		else {
			return Center(
				child: CupertinoActivityIndicator()
			);
		}
	}

	@override
	Widget build(BuildContext context) {
		return CupertinoPageScaffold(
			navigationBar: CupertinoNavigationBar(
				transitionBetweenRoutes: false,
				middle: Row(
					children: [
						Text('Results:'),
						...describeQuery(widget.query)
					]
				)
			),
			child: _build(context)
		);
	}
}
import 'package:chan/models/search.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/pages/search.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chan/widgets/cupertino_page_route.dart';


class SearchQueryPage extends StatefulWidget {
	final ImageboardArchiveSearchQuery query;
	const SearchQueryPage({
		required this.query,
		Key? key
	}) : super(key: key);

	@override
	createState() => _SearchQueryPageState();
}

class _SearchQueryPageState extends State<SearchQueryPage> {
	ImageboardArchiveSearchResult? result;
	String? errorMessage;
	int? page;
	bool loading = true;

	@override
	void initState() {
		super.initState();
		_runQuery();
	}

	void _runQuery() async {
		setState(() {
			errorMessage = null;
			loading = true;
		});
		try {
			result = await context.read<ImageboardSite>().search(widget.query, page: page ?? 1);
			page = result!.page;
			loading = false;
			if (mounted) setState(() {});
		}
		catch (e, st) {
			print(e);
			print(st);
			errorMessage = e.toString();
			loading = false;
			if (mounted) setState(() {});
		}
	}

	Widget _buildPagination() {
		return Row(
			mainAxisAlignment: MainAxisAlignment.spaceAround,
			children: [
				CupertinoButton(
					child: const Text('1'),
					onPressed: (loading || result!.page == 1) ? null : () {
						page = 1;
						_runQuery();
					}
				),
				const Spacer(),
				CupertinoButton(
					child: const Icon(Icons.navigate_before),
					onPressed: (loading || result!.page == 1) ? null : () {
						page = page! - 1;
						_runQuery();
					}
				),
				Text('Page $page'),
				CupertinoButton(
					child: const Icon(Icons.navigate_next),
					onPressed: (loading || result!.page == result!.maxPage) ? null : () {
						page = page! + 1;
						_runQuery();
					}
				),
				const Spacer(),
				CupertinoButton(
					child: Text('${result!.maxPage}'),
					onPressed: (loading || result!.page == result!.maxPage) ? null : () {
						page = result!.maxPage;
						_runQuery();
					}
				),
			]
		);
	}

	Widget _build(BuildContext context) {
		if (errorMessage != null) {
			return Center(
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						ErrorMessageCard(errorMessage!),
						CupertinoButton(
							child: const Text('Retry'),
							onPressed: _runQuery
						)
					]
				)
			);
		}
		else if (!loading && result != null) {
			return ListView.builder(
				itemCount: result!.posts.length + 2,
				itemBuilder: (context, i) {
					if (i == 0 || i == result!.posts.length + 1) {
						return _buildPagination();
					}
					final post = result!.posts[i - 1];
					return ChangeNotifierProvider<PostSpanZoneData>(
						create: (context) => PostSpanRootZoneData(
							site: context.read<ImageboardSite>(),
							thread: Thread(
								board: post.threadIdentifier.board,
								id: post.threadIdentifier.id,
								isDeleted: false,
								isArchived: false,
								title: '',
								isSticky: false,
								replyCount: -1,
								imageCount: -1,
								time: DateTime.fromMicrosecondsSinceEpoch(0),
								posts: [],
							),
							semanticRootId: -7
						),
						child: PostRow(
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
						)
					);
				}
			);
		}
		return Column(
			children: [
				if (result != null) SafeArea(
					bottom: false,
					child: _buildPagination()
				),
				const Expanded(
					child: Center(
						child: CupertinoActivityIndicator()
					)
				)
			]
		);
	}

	@override
	Widget build(BuildContext context) {
		return CupertinoPageScaffold(
			navigationBar: CupertinoNavigationBar(
				transitionBetweenRoutes: false,
				middle: Row(
					children: [
						const Text('Results:'),
						...describeQuery(widget.query)
					]
				)
			),
			child: _build(context)
		);
	}
}
import 'package:chan/models/search.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/search.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/thread_row.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


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
	ValueNotifier<AsyncSnapshot<ImageboardArchiveSearchResultPage>> result = ValueNotifier(const AsyncSnapshot.waiting());
	int? page;
	bool get loading => result.value.connectionState == ConnectionState.waiting;

	@override
	void initState() {
		super.initState();
		_runQuery();
	}

	void _runQuery() async {
		final siteToUse = result.value.data?.archive ?? context.read<ImageboardSite>();
		result.value = const AsyncSnapshot.waiting();
		try {
			result.value = AsyncSnapshot.withData(ConnectionState.done, await siteToUse.search(widget.query, page: page ?? 1));
			page = result.value.data?.page;
			if (mounted) setState(() {});
		}
		catch (e, st) {
			print(e);
			print(st);
			result.value = AsyncSnapshot.withError(ConnectionState.done, e);
			if (mounted) setState(() {});
		}
	}

	Widget _buildPagination(VoidCallback onChange) {
		return Row(
			mainAxisAlignment: MainAxisAlignment.spaceAround,
			children: [
				CupertinoButton(
					child: const Text('1'),
					onPressed: (loading || result.value.data?.page == 1) ? null : () {
						page = 1;
						_runQuery();
						onChange();
					}
				),
				const Spacer(),
				CupertinoButton(
					child: const Icon(CupertinoIcons.chevron_left),
					onPressed: (loading || result.value.data?.page == 1) ? null : () {
						page = page! - 1;
						_runQuery();
						onChange();
					}
				),
				Text('Page $page'),
				CupertinoButton(
					child: const Icon(CupertinoIcons.chevron_right),
					onPressed: (loading || result.value.data?.page == result.value.data?.maxPage) ? null : () {
						page = page! + 1;
						_runQuery();
						onChange();
					}
				),
				const Spacer(),
				CupertinoButton(
					child: Text('${result.value.data?.maxPage}'),
					onPressed: (loading || result.value.data?.page == result.value.data?.maxPage) ? null : () {
						page = result.value.data?.maxPage;
						_runQuery();
						onChange();
					}
				),
			]
		);
	}

	Widget _build(BuildContext context, ImageboardArchiveSearchResult? currentValue, ValueChanged<ImageboardArchiveSearchResult?> setValue) {
		if (result.value.error != null) {
			return Center(
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						ErrorMessageCard(result.value.error!.toStringDio()),
						CupertinoButton(
							child: const Text('Retry'),
							onPressed: _runQuery
						)
					]
				)
			);
		}
		else if (!loading && result.value.hasData) {
			return ListView.separated(
				itemCount: result.value.data!.posts.length + 2,
				itemBuilder: (context, i) {
					if (i == 0 || i == result.value.data!.posts.length + 1) {
						return _buildPagination(() => setValue(currentValue));
					}
					final row = result.value.data!.posts[i - 1];
					if (row.post != null) {
						return ChangeNotifierProvider<PostSpanZoneData>(
							create: (context) => PostSpanRootZoneData(
								site: context.read<ImageboardSite>(),
								thread: Thread(
									board: row.post!.threadIdentifier.board,
									id: row.post!.threadIdentifier.id,
									isDeleted: false,
									isArchived: false,
									title: '',
									isSticky: false,
									replyCount: -1,
									imageCount: -1,
									time: DateTime.fromMicrosecondsSinceEpoch(0),
									posts: [],
								),
								semanticRootIds: [-7]
							),
							child: PostRow(
								post: row.post!,
								onThumbnailTap: (attachment) => showGallery(
									context: context,
									attachments: [attachment],
									semanticParentIds: [-7]
								),
								showCrossThreadLabel: false,
								allowTappingLinks: false,
								isSelected: currentValue == row,
								onTap: () => setValue(row)
							)
						);
					}
					else {
						return GestureDetector(
							onTap: () => setValue(row),
							child: ThreadRow(
								thread: row.thread!,
								onThumbnailTap: (attachment) => showGallery(
									context: context,
									attachments: [attachment],
									semanticParentIds: [-7]
								),
								isSelected: currentValue == row,
								countsUnreliable: true
							)
						);
					}
				},
				separatorBuilder: (context, i) => Divider(
					thickness: 1,
					height: 0,
					color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2)
				)
			);
		}
		return Column(
			children: [
				if (result.value.hasData) SafeArea(
					bottom: false,
					child: _buildPagination(() => setValue(currentValue))
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
		final nav = Navigator.of(context);
		return MasterDetailPage<ImageboardArchiveSearchResult>(
			id: widget.query,
			masterBuilder: (context, currentValue, setValue) => AnimatedBuilder(
				animation: result,
				builder: (context, child) => CupertinoPageScaffold(
					navigationBar: CupertinoNavigationBar(
						transitionBetweenRoutes: false,
						leading: CupertinoButton(
							padding: EdgeInsets.zero,
							child: const Icon(CupertinoIcons.chevron_left),
							onPressed: () => nav.pop()
						),
						middle: FittedBox(
							fit: BoxFit.contain,
							child: Row(
								mainAxisSize: MainAxisSize.min,
								children: [
									const Text('Results:'),
									...describeQuery(widget.query)
								]
							)
						)
					),
					child: _build(context, currentValue, setValue)
				)
			),
			detailBuilder: (post, poppedOut) => BuiltDetailPane(
				widget: post != null ? ThreadPage(
					thread: post.threadIdentifier,
					initialPostId: post.id,
					initiallyUseArchive: true,
					boardSemanticId: -1
				) : Builder(
					builder: (context) => Container(
						decoration: BoxDecoration(
							color: CupertinoTheme.of(context).scaffoldBackgroundColor,
						),
						child: const Center(
							child: Text('Select a search result')
						)
					)
				),
				pageRouteBuilder: fullWidthCupertinoPageRouteBuilder
			)
		);
	}
}
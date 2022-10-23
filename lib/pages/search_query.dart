import 'package:chan/models/search.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/pages/search.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/cupertino_page_route.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/thread_row.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


class SearchQueryPage extends StatefulWidget {
	final ImageboardArchiveSearchQuery query;
	final ImageboardScoped<ImageboardArchiveSearchResult>? selectedResult;
	final ValueChanged<ImageboardScoped<ImageboardArchiveSearchResult>?> onResultSelected;
	const SearchQueryPage({
		required this.query,
		required this.selectedResult,
		required this.onResultSelected,
		Key? key
	}) : super(key: key);

	@override
	createState() => _SearchQueryPageState();
}

class _SearchQueryPageState extends State<SearchQueryPage> {
	AsyncSnapshot<ImageboardArchiveSearchResultPage> result = const AsyncSnapshot.waiting();
	int? page;
	bool get loading => result.connectionState == ConnectionState.waiting;

	@override
	void initState() {
		super.initState();
		_runQuery();
	}

	void _runQuery() async {
		final siteToUse = result.data?.archive ?? context.read<ImageboardSite>();
		final lastResult = result.data;
		result = const AsyncSnapshot.waiting();
		setState(() {});
		try {
			final newResult = await siteToUse.search(widget.query, page: page ?? 1, lastResult: lastResult);
			result = AsyncSnapshot.withData(ConnectionState.done, newResult);
			page = result.data?.page;
			if (mounted) setState(() {});
		}
		catch (e, st) {
			print(e);
			print(st);
			result = AsyncSnapshot.withError(ConnectionState.done, e);
			if (mounted) setState(() {});
		}
	}

	Widget _buildPagination(VoidCallback onChange) {
		return Row(
			mainAxisAlignment: MainAxisAlignment.spaceAround,
			children: [
				CupertinoButton(
					padding: EdgeInsets.zero,
					onPressed: (loading || result.data?.page == 1) ? null : () {
						page = 1;
						_runQuery();
						onChange();
					},
					child: const Text('1')
				),
				const Spacer(),
				CupertinoButton(
					padding: EdgeInsets.zero,
					onPressed: (loading || result.data?.page == 1) ? null : () {
						page = page! - 1;
						_runQuery();
						onChange();
					},
					child: const Icon(CupertinoIcons.chevron_left)
				),
				CupertinoButton(
					padding: EdgeInsets.zero,
					onPressed: (loading || result.data?.maxPage == 1 || result.data?.maxPage == null) ? null : () async {
						final controller = TextEditingController();
						final selectedPage = await showCupertinoDialog<int>(
							context: context,
							barrierDismissible: true,
							builder: (context) => CupertinoAlertDialog(
								title: const Text('Go to page'),
								content: Padding(
									padding: const EdgeInsets.only(top: 8),
									child: CupertinoTextField(
										controller: controller,
										autofocus: true,
										keyboardType: TextInputType.number,
										onSubmitted: (str) {
											Navigator.pop(context, int.tryParse(str));
										}
									)
								),
								actions: [
									CupertinoDialogAction(
										child: const Text('Cancel'),
										onPressed: () {
											Navigator.of(context).pop();
										}
									),
									CupertinoDialogAction(
										isDefaultAction: true,
										onPressed: () {
											Navigator.of(context).pop(int.tryParse(controller.text));
										},
										child: const Text('OK')
									)
								]
							)
						);
						if (selectedPage != null) {
							page = selectedPage;
							_runQuery();
							onChange();
						}
						controller.dispose();
					},
					child: Text('Page $page')
				),
				CupertinoButton(
					padding: EdgeInsets.zero,
					onPressed: (loading || result.data?.page == result.data?.maxPage) ? null : () {
						page = page! + 1;
						_runQuery();
						onChange();
					},
					child: const Icon(CupertinoIcons.chevron_right)
				),
				const Spacer(),
				CupertinoButton(
					padding: EdgeInsets.zero,
					onPressed: (loading || result.data?.page == result.data?.maxPage || result.data?.maxPage == null) ? null : () {
						page = result.data?.maxPage;
						_runQuery();
						onChange();
					},
					child: Text('${result.data?.maxPage ?? '--'}')
				),
			]
		);
	}

	Widget _build(BuildContext context, ImageboardScoped<ImageboardArchiveSearchResult>? currentValue, ValueChanged<ImageboardScoped<ImageboardArchiveSearchResult>?> setValue) {
		if (result.error != null) {
			return Center(
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						ErrorMessageCard(result.error!.toStringDio()),
						CupertinoButton(
							onPressed: _runQuery,
							child: const Text('Retry')
						)
					]
				)
			);
		}
		else if (!loading && result.hasData) {
			return MaybeCupertinoScrollbar(
				child: ListView.separated(
					itemCount: result.data!.posts.length + 2,
					itemBuilder: (context, i) {
						if (i == 0 || i == result.data!.posts.length + 1) {
							return _buildPagination(() => setValue(currentValue));
						}
						final row = result.data!.posts[i - 1];
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
										posts_: [],
										attachments: []
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
									showBoardName: true,
									allowTappingLinks: false,
									isSelected: currentValue?.item == row,
									onTap: () => setValue(ImageboardScoped(
										imageboard: context.read<Imageboard>(),
										item: row
									)),
									baseOptions: PostSpanRenderOptions(
										highlightString: widget.query.query
									),
								)
							);
						}
						else {
							return GestureDetector(
								onTap: () => setValue(ImageboardScoped(
									imageboard: context.read<Imageboard>(),
									item: row
								)),
								child: ThreadRow(
									thread: row.thread!,
									onThumbnailTap: (attachment) => showGallery(
										context: context,
										attachments: [attachment],
										semanticParentIds: [-7]
									),
									isSelected: currentValue?.item == row,
									countsUnreliable: true,
									showBoardName: true,
									baseOptions: PostSpanRenderOptions(
										highlightString: widget.query.query.isEmpty ? null : widget.query.query
									),
								)
							);
						}
					},
					separatorBuilder: (context, i) => Divider(
						thickness: 1,
						height: 0,
						color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2)
					)
				)
			);
		}
		return Column(
			children: [
				if (result.hasData) SafeArea(
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
		return CupertinoPageScaffold(
			navigationBar: CupertinoNavigationBar(
				transitionBetweenRoutes: false,
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
			child: _build(context, widget.selectedResult, widget.onResultSelected)
		);
	}
}

openSearch({
	required BuildContext context,
	required ImageboardArchiveSearchQuery query
}) {
	Navigator.of(context).push(FullWidthCupertinoPageRoute(
		builder: (context) => ImageboardScope(
			imageboardKey: query.imageboardKey,
			child: SearchQueryPage(
				query: query,
				onResultSelected: (result) {
					if (result != null) {
						Navigator.of(context).push(FullWidthCupertinoPageRoute(
							builder: (context) => ImageboardScope(
								imageboardKey: null,
								imageboard: result.imageboard,
								child: ThreadPage(
									thread: result.item.threadIdentifier,
									initialPostId: result.item.id,
									initiallyUseArchive: true,
									boardSemanticId: -1
								)
							),
							showAnimations: context.read<EffectiveSettings>().showAnimations
						));
					}
				},
				selectedResult: null
			)
		),
		showAnimations: context.read<EffectiveSettings>().showAnimations
	));
}
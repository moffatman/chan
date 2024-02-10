import 'package:chan/models/search.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/search.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
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
	final SelectedSearchResult? selectedResult;
	final ValueChanged<SelectedSearchResult?> onResultSelected;
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

	Widget _buildPagination() {
		return Row(
			mainAxisAlignment: MainAxisAlignment.spaceAround,
			children: [
				AdaptiveIconButton(
					onPressed: (loading || result.data?.page == 1) ? null : () {
						page = 1;
						_runQuery();
					},
					icon: const Text('1')
				),
				const Spacer(flex: 2),
				AdaptiveIconButton(
					minSize: 0,
					onPressed: (loading || result.data?.page == 1) ? null : () {
						page = page! - 1;
						_runQuery();
					},
					icon: const Icon(CupertinoIcons.chevron_left)
				),
				const Spacer(),
				AdaptiveIconButton(
					onPressed: (loading || result.data?.maxPage == 1 || result.data?.maxPage == null) ? null : () async {
						final controller = TextEditingController();
						final selectedPage = await showAdaptiveDialog<int>(
							context: context,
							barrierDismissible: true,
							builder: (context) => AdaptiveAlertDialog(
								title: const Text('Go to page'),
								content: Padding(
									padding: const EdgeInsets.only(top: 8),
									child: AdaptiveTextField(
										controller: controller,
										enableIMEPersonalizedLearning: context.watch<EffectiveSettings>().enableIMEPersonalizedLearning,
										autofocus: true,
										keyboardType: TextInputType.number,
										onSubmitted: (str) {
											Navigator.pop(context, int.tryParse(str));
										}
									)
								),
								actions: [
									AdaptiveDialogAction(
										isDefaultAction: true,
										onPressed: () {
											Navigator.of(context).pop(int.tryParse(controller.text));
										},
										child: const Text('Go')
									),
									AdaptiveDialogAction(
										child: const Text('Cancel'),
										onPressed: () {
											Navigator.of(context).pop();
										}
									)
								]
							)
						);
						if (selectedPage != null) {
							page = selectedPage;
							_runQuery();
						}
						controller.dispose();
					},
					icon: Text('Page $page')
				),
				const Spacer(),
				AdaptiveIconButton(
					minSize: 0,
					onPressed: (loading || result.data?.page == result.data?.maxPage) ? null : () {
						page = page! + 1;
						_runQuery();
					},
					icon: const Icon(CupertinoIcons.chevron_right)
				),
				const Spacer(flex: 2),
				AdaptiveIconButton(
					onPressed: (loading || result.data?.page == result.data?.maxPage || result.data?.maxPage == null) ? null : () {
						page = result.data?.maxPage;
						_runQuery();
					},
					icon: Text('${result.data?.maxPage ?? '—'}')
				),
			]
		);
	}

	Widget _build(BuildContext context, SelectedSearchResult? currentValue, ValueChanged<SelectedSearchResult?> setValue) {
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
			return MaybeScrollbar(
				child: ListView.separated(
					itemCount: result.data!.posts.length + 2,
					itemBuilder: (context, i) {
						if (i == 0 || i == result.data!.posts.length + 1) {
							return _buildPagination();
						}
						final row = result.data!.posts[i - 1];
						if (row.post != null) {
							return ChangeNotifierProvider<PostSpanZoneData>(
								create: (context) => PostSpanRootZoneData(
									imageboard: context.read<Imageboard>(),
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
									semanticRootIds: [-7],
									style: PostSpanZoneStyle.linear
								),
								child: PostRow(
									post: row.post!,
									onThumbnailTap: (attachment) => showGallery(
										context: context,
										attachments: [attachment],
										semanticParentIds: [-7],
										heroOtherEndIsBoxFitCover: context.read<EffectiveSettings>().squareThumbnails
									),
									showCrossThreadLabel: false,
									showBoardName: true,
									allowTappingLinks: false,
									showPostNumber: false,
									isSelected: (context.read<MasterDetailHint?>()?.twoPane != false) && currentValue?.result == row,
									onTap: () => setValue(SelectedSearchResult(
										imageboard: context.read<Imageboard>(),
										result: row,
										threadSearch: null,
										fromArchive: result.data!.archive.isArchive
									)),
									baseOptions: PostSpanRenderOptions(
										highlightString: widget.query.query
									),
								)
							);
						}
						else {
							final matchingPostIndex = row.thread!.posts_.indexWhere((p) => p.span.buildText().toLowerCase().contains(widget.query.query.toLowerCase()));
							return GestureDetector(
								onTap: () => setValue(SelectedSearchResult(
									imageboard: context.read<Imageboard>(),
									result: row,
									// Only do a thread-search if we have a match in lastReplies and not OP
									threadSearch: (matchingPostIndex > 0) ? widget.query.query : null,
									fromArchive: result.data!.archive.isArchive
								)),
								child: ThreadRow(
									thread: row.thread!,
									onThumbnailTap: (attachment) => showGallery(
										context: context,
										attachments: [attachment],
										semanticParentIds: [-7],
										heroOtherEndIsBoxFitCover: context.read<EffectiveSettings>().squareThumbnails
									),
									isSelected: (context.read<MasterDetailHint?>()?.twoPane != false) && currentValue?.result == row,
									countsUnreliable: true,
									semanticParentIds: const [-7],
									showBoardName: true,
									showLastReplies: true,
									baseOptions: PostSpanRenderOptions(
										highlightString: widget.query.query.isEmpty ? null : widget.query.query
									),
								)
							);
						}
					},
					separatorBuilder: (context, i) => const ChanceDivider()
				)
			);
		}
		return Column(
			children: [
				if (result.hasData) SafeArea(
					bottom: false,
					child: _buildPagination()
				),
				const Expanded(
					child: Center(
						child: CircularProgressIndicator.adaptive()
					)
				)
			]
		);
	}

	@override
	Widget build(BuildContext context) {
		return AdaptiveScaffold(
			bar: AdaptiveBar(
				title: FittedBox(
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
			body: _build(context, widget.selectedResult, widget.onResultSelected)
		);
	}
}

openSearch({
	required BuildContext context,
	required ImageboardArchiveSearchQuery query
}) {
	Navigator.of(context).push(adaptivePageRoute(
		builder: (context) => ImageboardScope(
			imageboardKey: query.imageboardKey,
			child: SearchQueryPage(
				query: query,
				onResultSelected: (result) {
					if (result != null) {
						Navigator.of(context).push(adaptivePageRoute(
							builder: (context) => ImageboardScope(
								imageboardKey: null,
								imageboard: result.imageboard,
								child: ThreadPage(
									thread: result.result.threadIdentifier,
									initialPostId: result.result.id,
									initiallyUseArchive: result.fromArchive,
									initialSearch: result.threadSearch,
									boardSemanticId: -1
								)
							)
						));
					}
				},
				selectedResult: null
			)
		)
	));
}
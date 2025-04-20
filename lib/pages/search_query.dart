import 'package:chan/models/attachment.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/search.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/board_switcher.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/search.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/report_bug.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/search_query_editor.dart';
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
		final lastResult = result.data;
		result = const AsyncSnapshot.waiting();
		setState(() {});
		try {
			final siteToUse = result.data?.archive ?? ImageboardRegistry.instance.getImageboard(widget.query.imageboardKey)!.site;
			final newResult = await siteToUse.search(widget.query, page: page ?? 1, lastResult: lastResult, priority: RequestPriority.interactive);
			result = AsyncSnapshot.withData(ConnectionState.done, newResult);
			page = result.data?.page;
			if (mounted) setState(() {});
		}
		catch (e, st) {
			print(e);
			print(st);
			result = AsyncSnapshot.withError(ConnectionState.done, e, st);
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
					onPressed: (loading || result.data?.maxPage == 1 || result.data?.canJumpToArbitraryPage == false) ? null : () async {
						final controller = TextEditingController();
						final selectedPage = await showAdaptiveDialog<int>(
							context: context,
							barrierDismissible: true,
							builder: (context) => StatefulBuilder(
								builder: (context, setDialogState) {
									final isOK = switch (int.tryParse(controller.text)) {
										null || <=0 => false,
										int x => switch (result.data?.maxPage) {
											int max => x <= max,
											null => true
										}
									};
									return AdaptiveAlertDialog(
										title: const Text('Go to page'),
										content: Padding(
											padding: const EdgeInsets.only(top: 8),
											child: AdaptiveTextField(
												controller: controller,
												enableIMEPersonalizedLearning: context.watch<Settings>().enableIMEPersonalizedLearning,
												autofocus: true,
												keyboardType: TextInputType.number,
												onChanged: (str) {
													setDialogState(() {});
												},
												onSubmitted: (str) {
													if (isOK) {
														Navigator.pop(context, int.tryParse(str));
													}
													else {
														showToast(
															context: context,
															icon: CupertinoIcons.number,
															message: 'Invalid page number'
														);
													}
												}
											)
										),
										actions: [
											AdaptiveDialogAction(
												isDefaultAction: true,
												onPressed: isOK ? () => Navigator.of(context).pop(int.tryParse(controller.text)) : null,
												child: const Text('Go')
											),
											AdaptiveDialogAction(
												child: const Text('Cancel'),
												onPressed: () {
													Navigator.of(context).pop();
												}
											)
										]
									);
								}
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

	Future<void> _showGallery(BuildContext context, Attachment initialAttachment) async {
		final imageboard = context.read<Imageboard>();
		await showGallery(
			context: context,
			attachments: [
				for (final item in result.data!.posts)
					for (final attachment in (item.post?.attachments ?? item.thread?.attachments ?? const <Attachment>[]))
						attachment
			],
			initialAttachment: initialAttachment,
			semanticParentIds: [-7],
			threads: {
				for (final item in result.data!.posts)
					if (item.thread case Thread thread)
						for (final attachment in thread.attachments)
							attachment: imageboard.scope(thread)
			},
			posts: {
				for (final item in result.data!.posts)
					if (item.post case Post post)
						for (final attachment in post.attachments)
							attachment: imageboard.scope(post)
			},
			heroOtherEndIsBoxFitCover: Settings.instance.squareThumbnails
		);
	}

	Widget _build(BuildContext context, SelectedSearchResult? currentValue, ValueChanged<SelectedSearchResult?> setValue) {
		if (result.error != null) {
			return Center(
				child: ErrorMessageCard(result.error!.toStringDio(), remedies: {
					'Retry': _runQuery,
					...generateBugRemedies(result.error!, result.stackTrace!, context)
				})
			);
		}
		else if (!loading && result.hasData) {
			final queryPattern = RegExp(RegExp.escape(widget.query.query), caseSensitive: false);
			return ImageboardScope(
				imageboardKey: widget.query.imageboardKey,
				child: MaybeScrollbar(
					child: ListView.separated(
						itemCount: result.data!.posts.length + 2,
						itemBuilder: (context, i) {
							if (i == 0 || i == result.data!.posts.length + 1) {
								return _buildPagination();
							}
							final row = result.data!.posts[i - 1];
							final imageboard = context.read<Imageboard>();
							if (row.post != null) {
								return ChangeNotifierProvider<PostSpanZoneData>(
									create: (context) => PostSpanRootZoneData(
										imageboard: imageboard,
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
									child: ValueListenableBuilder(
										valueListenable: imageboard.persistence.listenForPersistentThreadStateChanges(row.post!.threadIdentifier),
										builder: (context, threadState, child) {
											return Opacity(
												opacity: (threadState?.showInHistory ?? false) ? 0.5 : 1.0,
												child: child
											);
										},
										child: PostRow(
											post: row.post!,
											onThumbnailTap: (attachment) => _showGallery(context, attachment),
											showCrossThreadLabel: false,
											showBoardName: true,
											allowTappingLinks: false,
											showPostNumber: false,
											isSelected: (context.watch<MasterDetailLocation?>()?.twoPane != false) && currentValue?.result == row,
											onTap: () => setValue(SelectedSearchResult(
												imageboard: imageboard,
												result: row,
												threadSearch: null,
												fromArchive: result.data!.archive.isArchive ? result.data!.archive.name : null
											)),
											baseOptions: PostSpanRenderOptions(
												highlightPattern: widget.query.query.isEmpty ? null : queryPattern
											),
										)
									)
								);
							}
							else {
								final matchingPostIndex = row.thread!.posts_.indexWhere((p) => p.span.buildText().toLowerCase().contains(widget.query.query.toLowerCase()));
								return GestureDetector(
									onTap: () => setValue(SelectedSearchResult(
										imageboard: imageboard,
										result: row,
										// Only do a thread-search if we have a match in lastReplies and not OP
										threadSearch: (matchingPostIndex > 0) ? widget.query.query : null,
										fromArchive: result.data!.archive.isArchive ? result.data!.archive.name : null
									)),
									child: ThreadRow(
										thread: row.thread!,
										onThumbnailTap: (attachment) => _showGallery(context, attachment),
										isSelected: (context.watch<MasterDetailLocation?>()?.twoPane != false) && currentValue?.result == row,
										replyCountUnreliable: result.data!.replyCountsUnreliable,
										imageCountUnreliable: result.data!.imageCountsUnreliable,
										semanticParentIds: const [-7],
										showBoardName: true,
										dimReadThreads: true,
										showLastReplies: true,
										baseOptions: PostSpanRenderOptions(
											highlightPattern: widget.query.query.isEmpty ? null : queryPattern
										),
									)
								);
							}
						},
						separatorBuilder: (context, i) => const ChanceDivider()
					)
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
							const Text('Results | ', style: CommonTextStyles.bold),
							...describeQuery(widget.query)
						]
					)
				),
				actions: [
					AdaptiveIconButton(
						icon: const Icon(CupertinoIcons.pencil),
						onPressed: () async {
							bool changed = false;
							final controller = TextEditingController(text: widget.query.query);
							await showAdaptiveModalPopup(
								context: context,
								builder: (context) => StatefulBuilder(
									builder: (context, setState) => AdaptiveActionSheet(
										message: Column(
											mainAxisSize: MainAxisSize.min,
											children: [
												const Text('Board'),
												const SizedBox(height: 16),
												AdaptiveFilledButton(
													onPressed: () async {
														final newBoard = await Navigator.of(context).push<ImageboardScoped<ImageboardBoard>>(TransparentRoute(
															builder: (ctx) => const BoardSwitcherPage()
														));
														if (newBoard != null) {
															widget.query.imageboardKey = newBoard.imageboard.key;
															widget.query.boards = [newBoard.item.name];
															changed = true;
															setState(() {});
														}
													},
													child: Row(
														mainAxisSize: MainAxisSize.min,
														children: [
															ImageboardIcon(imageboardKey: widget.query.imageboardKey, boardName: widget.query.boards.tryFirst),
															if (widget.query.boards.isNotEmpty) ...[
																const SizedBox(width: 4),
																Text(widget.query.boards.tryFirst ?? '<null>')
															]
														]
													)
												),
												const SizedBox(height: 32),
												CupertinoTextField(
													placeholder: 'Query',
													controller: controller,
													onChanged: (v) {
														widget.query.query = v;
													},
													onSubmitted: (v) {
														widget.query.query = v;
														changed = true;
														Navigator.pop(context);
													}
												),
												SearchQueryEditor(
													query: widget.query,
													onChanged: () {
														changed = true;
														setState(() {});
													},
													onSubmitted: () {
														changed = true;
														Navigator.pop(context);
													},
													knownWidth: 300
												)
											]
										),
										actions: [
											AdaptiveActionSheetAction(
												onPressed: () => Navigator.pop(context),
												child: const Text('Close')
											)
										]
									)
								)
							);
							controller.dispose();
							if (changed && mounted) {
								_runQuery();
							}
						}
					)
				]
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
		builder: (context) => SearchQueryPage(
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
	);
}
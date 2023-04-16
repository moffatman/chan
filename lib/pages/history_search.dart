import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/thread_row.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HistorySearchResult {
	final Thread thread;
	final Post? post;
	HistorySearchResult(this.thread, [this.post]);

	PostIdentifier get identifier => post?.identifier ?? PostIdentifier.thread(thread.identifier);

	@override toString() => 'HistorySearchResult(thread: $thread, post: $post)';
}


class HistorySearchPage extends StatefulWidget {
	final String query;
	final ImageboardScoped<PostIdentifier>? selectedResult;
	final ValueChanged<ImageboardScoped<PostIdentifier>?> onResultSelected;

	const HistorySearchPage({
		required this.query,
		required this.selectedResult,
		required this.onResultSelected,
		super.key
	});

	@override
	createState() => _HistorySearchPageState();
}

class _HistorySearchPageState extends State<HistorySearchPage> {
	int numer = 0;
	int denom = 1;
	List<ImageboardScoped<HistorySearchResult>>? results;

	@override
	void initState() {
		super.initState();
		_runQuery();
	}

	Future<void> _runQuery() async {
		final theseResults = <ImageboardScoped<HistorySearchResult>>[];
		setState(() {});
		denom = Persistence.sharedThreadStateBox.values.length;
		await Future.wait(Persistence.sharedThreadStateBox.values.map((threadState) async {
			if (threadState.imageboard == null || !threadState.showInHistory || !mounted) {
				numer++;
				return;
			}
			final thread = threadState.thread ?? await Persistence.getCachedThread(threadState.imageboardKey, threadState.board, threadState.id);
			if (thread != null) {
				for (final post in thread.posts) {
					if (post.span.buildText().contains(RegExp(RegExp.escape(widget.query), caseSensitive: false))) {
						if (post.id == thread.id) {
							theseResults.add(threadState.imageboard!.scope(HistorySearchResult(thread, null)));
						}
						else {
							theseResults.add(threadState.imageboard!.scope(HistorySearchResult(thread, post)));
						}
					}
				}
			}
			if (!mounted) return;
			numer++;
			setState(() {});
		}));
		if (!mounted) {
			return;
		}
		theseResults.sort((a, b) => (b.item.post?.time ?? b.item.thread.time).compareTo(a.item.post?.time ?? a.item.thread.time));
		results = theseResults;
		setState(() {});
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
							Text('${results != null ? '${results?.length} results' : 'Searching'}: ${widget.query}'),
						]
					)
				)
			),
			child: (results == null) ? Center(
				child: SizedBox(
					width: 100,
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							ClipRRect(
								borderRadius: const BorderRadius.all(Radius.circular(8)),
								child: LinearProgressIndicator(
									value: numer / denom,
									backgroundColor: CupertinoTheme.of(context).primaryColor.withOpacity(0.3),
									color: CupertinoTheme.of(context).primaryColor,
									minHeight: 8
								)
							),
							const SizedBox(height: 8),
							Text('$numer / $denom')
						]
					)
				)
			) : MaybeCupertinoScrollbar(
				child: ListView.separated(
					itemCount: results!.length,
					itemBuilder: (context, i) {
						final row = results![i];
						if (row.item.post != null) {
							return ImageboardScope(
								imageboardKey: null,
								imageboard: row.imageboard,
								child: ChangeNotifierProvider<PostSpanZoneData>(
									create: (context) => PostSpanRootZoneData(
										site: row.imageboard.site,
										thread: row.item.thread,
										semanticRootIds: [-11]
									),
									builder: (context, _) => PostRow(
										post: row.item.post!,
										onThumbnailTap: (attachment) => showGallery(
											context: context,
											attachments: [attachment],
											semanticParentIds: [-11],
											heroOtherEndIsBoxFitCover: false
										),
										showCrossThreadLabel: false,
										showBoardName: true,
										allowTappingLinks: false,
										isSelected: (context.read<MasterDetailHint?>()?.twoPane != false) && widget.selectedResult?.imageboard == row.imageboard && widget.selectedResult?.item == row.item.identifier,
										onTap: () => widget.onResultSelected(row.imageboard.scope(row.item.identifier)),
										baseOptions: PostSpanRenderOptions(
											highlightString: widget.query
										),
									)
								)
							);
						}
						else {
							return ImageboardScope(
								imageboardKey: null,
								imageboard: row.imageboard,
								child: Builder(
									builder: (context) => CupertinoButton(
										padding: EdgeInsets.zero,
										onPressed: () => widget.onResultSelected(row.imageboard.scope(row.item.identifier)),
										child: ThreadRow(
											thread: row.item.thread,
											onThumbnailTap: (attachment) => showGallery(
												context: context,
												attachments: [attachment],
												semanticParentIds: [-11],
												heroOtherEndIsBoxFitCover: false
											),
											isSelected: (context.read<MasterDetailHint?>()?.twoPane != false) && widget.selectedResult?.imageboard == row.imageboard && widget.selectedResult?.item == row.item.identifier,
											countsUnreliable: true,
											showBoardName: true,
											baseOptions: PostSpanRenderOptions(
												highlightString: widget.query.isEmpty ? null : widget.query
											),
										)
									)
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
			)
		);
	}

	@override
	void dispose() {
		super.dispose();
	}
}
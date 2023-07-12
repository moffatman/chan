import 'package:chan/models/board.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/board_switcher.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/refreshable_list.dart';
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
	ImageboardScoped<ImageboardBoard>? _filterBoard;
	DateTime? _filterDateStart;
	DateTime? _filterDateEnd;
	bool? _filterHasAttachment;
	bool? _filterContainsLink;
	bool? _filterIsThread;

	@override
	void initState() {
		super.initState();
		_runQuery();
	}

	Future<void> _runQuery() async {
		final theseResults = <ImageboardScoped<HistorySearchResult>>[];
		setState(() {});
		numer = 0;
		denom = Persistence.sharedThreadStateBox.values.length;
		await Future.wait(Persistence.sharedThreadStateBox.values.map((threadState) async {
			if (threadState.imageboard == null ||
			    !threadState.showInHistory ||
					!mounted ||
					(_filterBoard != null &&
					(_filterBoard!.imageboard != threadState.imageboard ||
						_filterBoard!.item.name != threadState.board))) {
				numer++;
				return;
			}
			final thread = await threadState.getThread();
			final query = RegExp(RegExp.escape(widget.query), caseSensitive: false);
			if (thread != null) {
				for (final post in thread.posts) {
					if (widget.query.isNotEmpty && !post.span.buildText().contains(query)) {
						continue;
					}
					if (_filterIsThread != null && _filterIsThread != (post.id == thread.id)) {
						continue;
					}
					if (_filterContainsLink != null && _filterContainsLink != post.span.containsLink) {
						continue;
					}
					if (_filterHasAttachment != null && _filterHasAttachment != post.attachments.isNotEmpty) {
						continue;
					}
					if (_filterDateStart != null && _filterDateStart!.isAfter(post.time)) {
						continue;
					}
					if (_filterDateEnd != null && _filterDateEnd!.isBefore(post.time)) {
						continue;
					}
					if (post.id == thread.id) {
						theseResults.add(threadState.imageboard!.scope(HistorySearchResult(thread, null)));
					}
					else {
						theseResults.add(threadState.imageboard!.scope(HistorySearchResult(thread, post)));
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
		return AdaptiveScaffold(
			bar: AdaptiveBar(
				title: FittedBox(
					fit: BoxFit.contain,
					child: Row(
						mainAxisSize: MainAxisSize.min,
						children: [
							Text('${results != null ? '${results?.length} results' : 'Searching'}${widget.query.isNotEmpty ? ' for "${widget.query}"' : ''}'),
							...[
								if (_filterBoard != null) Row(
									mainAxisSize: MainAxisSize.min,
									children: [
										ImageboardIcon(
											imageboardKey: _filterBoard!.imageboard.key,
											boardName: _filterBoard!.item.name
										),
										const SizedBox(width: 8),
										Text(_filterBoard!.imageboard.site.formatBoardName(_filterBoard!.item))
									]
								),
								if (_filterDateStart != null && _filterDateEnd != null)
									Text(_filterDateStart!.startOfDay == _filterDateEnd!.startOfDay ?
										_filterDateStart!.toISO8601Date :
										'${_filterDateStart?.toISO8601Date} -> ${_filterDateEnd?.toISO8601Date}')
								else ...[
									if (_filterDateStart != null) Text('After ${_filterDateStart?.toISO8601Date}'),
									if (_filterDateEnd != null) Text('Before ${_filterDateEnd?.toISO8601Date}')
								],
								if (_filterIsThread != null)
									_filterIsThread! ? const Text('Threads') : const Text('Replies'),
								if (_filterHasAttachment != null)
									_filterHasAttachment! ? const Text('With attachment(s)') : const Text('Without attachment(s)'),
								if (_filterContainsLink != null)
									_filterContainsLink! ? const Text('Containing link(s)') : const Text('Not containing link(s)')
							].map((child) => Container(
								margin: const EdgeInsets.only(left: 4, right: 4),
								padding: const EdgeInsets.all(4),
								decoration: BoxDecoration(
									color: ChanceTheme.primaryColorOf(context).withOpacity(0.3),
									borderRadius: const BorderRadius.all(Radius.circular(4))
								),
								child: child
							))
						]
					)
				),
				actions: [
					AdaptiveIconButton(
						minSize: 0,
						onPressed: () async {
							bool anyChange = false;
							await showAdaptiveModalPopup(
								context: context,
								builder: (context) => StatefulBuilder(
									builder: (context, setDialogState) => AdaptiveActionSheet(
										title: const Text('History filters'),
										message: DefaultTextStyle(
											style: DefaultTextStyle.of(context).style,
											child: Column(
												mainAxisSize: MainAxisSize.min,
												children: [
													Row(
														mainAxisAlignment: MainAxisAlignment.center,
														children: [
															AdaptiveFilledButton(
																padding: const EdgeInsets.all(8),
																onPressed: () async {
																	final newBoard = await Navigator.of(context).push<ImageboardScoped<ImageboardBoard>>(TransparentRoute(
																		builder: (ctx) => BoardSwitcherPage(
																			initialImageboardKey: _filterBoard?.imageboard.key
																		)
																	));
																	if (newBoard != null) {
																		_filterBoard = newBoard;
																		setDialogState(() {});
																		anyChange = true;
																	}
																},
																child: Row(
																	mainAxisSize: MainAxisSize.min,
																	children: _filterBoard == null ? const [
																		Text('Board: any')
																	] : [
																		const Text('Board: '),
																		ImageboardIcon(
																			imageboardKey: _filterBoard!.imageboard.key,
																			boardName: _filterBoard!.item.name
																		),
																		const SizedBox(width: 8),
																		Text(_filterBoard!.imageboard.site.formatBoardName(_filterBoard!.item))
																	]
																)
															),
															if (_filterBoard != null) AdaptiveIconButton(
																onPressed: () {
																	_filterBoard = null;
																	anyChange = true;
																	setDialogState(() {});
																},
																icon: const Icon(CupertinoIcons.xmark)
															)
														]
													),
													const SizedBox(height: 16),
													AdaptiveFilledButton(
														padding: const EdgeInsets.all(8),
														onPressed: () async {
															_filterDateStart = (await pickDate(
																context: context,
																initialDate: _filterDateStart
															))?.startOfDay;
															setDialogState(() {});
															anyChange = true;
														},
														child: Text(_filterDateStart == null ? 'Pick Start Date' : 'Start Date: ${_filterDateStart?.toISO8601Date}')
													),
													const SizedBox(height: 16),
													AdaptiveFilledButton(
														padding: const EdgeInsets.all(8),
														onPressed: () async {
															_filterDateEnd = (await pickDate(
																context: context,
																initialDate: _filterDateEnd
															))?.endOfDay;
															setDialogState(() {});
															anyChange = true;
														},
														child: Text(_filterDateStart == null ? 'Pick End Date' : 'End Date: ${_filterDateEnd?.toISO8601Date}')
													),
													const SizedBox(height: 16),
													AdaptiveSegmentedControl<NullSafeOptional>(
														groupValue: _filterIsThread.value,
														children: const {
															NullSafeOptional.false_: (null, 'Only replies'),
															NullSafeOptional.null_: (null, 'Any'),
															NullSafeOptional.true_: (null, 'Only threads')
														},
														onValueChanged: (v) {
															_filterIsThread = v.value;
															setDialogState(() {});
															anyChange = true;
														}
													),
													const SizedBox(height: 16),
													AdaptiveSegmentedControl<NullSafeOptional>(
														groupValue: _filterHasAttachment.value,
														children: const {
															NullSafeOptional.false_: (null, 'Only without attachment(s)'),
															NullSafeOptional.null_: (null, 'Any'),
															NullSafeOptional.true_: (null, 'Only with attachment(s)')
														},
														onValueChanged: (v) {
															_filterHasAttachment = v.value;
															setDialogState(() {});
															anyChange = true;
														}
													),
													const SizedBox(height: 16),
													AdaptiveSegmentedControl<NullSafeOptional>(
														groupValue: _filterContainsLink.value,
														children: const {
															NullSafeOptional.false_: (null, 'Only without link(s)'),
															NullSafeOptional.null_: (null, 'Any'),
															NullSafeOptional.true_: (null, 'Only with link(s)')
														},
														onValueChanged: (v) {
															_filterContainsLink = v.value;
															setDialogState(() {});
															anyChange = true;
														}
													)
												]
											)
										),
										actions: [
											AdaptiveActionSheetAction(
												onPressed: () => Navigator.pop(context),
												child: const Text('Done')
											)
										]
									)
								)
							);
							if (anyChange) {
								setState(() {
									results = null;
								});
								_runQuery();
							}
						},
						icon: const Icon(CupertinoIcons.slider_horizontal_3)
					)
				]
			),
			body: (results == null) ? Center(
				child: SizedBox(
					width: 100,
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							ClipRRect(
								borderRadius: const BorderRadius.all(Radius.circular(8)),
								child: LinearProgressIndicator(
									value: numer / denom,
									backgroundColor: ChanceTheme.primaryColorOf(context).withOpacity(0.3),
									color: ChanceTheme.primaryColorOf(context),
									minHeight: 8
								)
							),
							const SizedBox(height: 8),
							Text('$numer / $denom')
						]
					)
				)
			) : MaybeScrollbar(
				child: RefreshableList<ImageboardScoped<HistorySearchResult>>(
					listUpdater: () => throw UnimplementedError(),
					id: 'historysearch',
					filterableAdapter: (i) => i.item.post ?? i.item.thread,
					initialList: results,
					disableUpdates: true,
					itemBuilder: (context, row) {
						if (row.item.post != null) {
							return ImageboardScope(
								imageboardKey: null,
								imageboard: row.imageboard,
								child: ChangeNotifierProvider<PostSpanZoneData>(
									create: (context) => PostSpanRootZoneData(
										imageboard: row.imageboard,
										thread: row.item.thread,
										semanticRootIds: [-11]
									),
									builder: (context, _) => PostRow(
										post: row.item.post!,
										onThumbnailTap: (attachment) => showGallery(
											context: context,
											attachments: [attachment],
											semanticParentIds: [-11],
											heroOtherEndIsBoxFitCover: context.read<EffectiveSettings>().squareThumbnails
										),
										showCrossThreadLabel: false,
										showBoardName: true,
										showSiteIcon: ImageboardRegistry.instance.count > 1,
										allowTappingLinks: false,
										isSelected: (context.read<MasterDetailHint?>()?.twoPane != false) && widget.selectedResult?.imageboard == row.imageboard && widget.selectedResult?.item == row.item.identifier,
										onTap: () {
											row.imageboard.persistence.getThreadState(row.item.identifier.thread).thread ??= row.item.thread;
											widget.onResultSelected(row.imageboard.scope(row.item.identifier));
										},
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
										onPressed: () {
											row.imageboard.persistence.getThreadState(row.item.identifier.thread).thread ??= row.item.thread;
											widget.onResultSelected(row.imageboard.scope(row.item.identifier));
										},
										child: ThreadRow(
											thread: row.item.thread,
											onThumbnailTap: (attachment) => showGallery(
												context: context,
												attachments: [attachment],
												semanticParentIds: [-11],
												heroOtherEndIsBoxFitCover: context.read<EffectiveSettings>().squareThumbnails
											),
											isSelected: (context.read<MasterDetailHint?>()?.twoPane != false) && widget.selectedResult?.imageboard == row.imageboard && widget.selectedResult?.item == row.item.identifier,
											showBoardName: true,
											showSiteIcon: ImageboardRegistry.instance.count > 1,
											baseOptions: PostSpanRenderOptions(
												highlightString: widget.query.isEmpty ? null : widget.query
											),
										)
									)
								)
							);
						}
					}
				)
			)
		);
	}

	@override
	void dispose() {
		super.dispose();
	}
}
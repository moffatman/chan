import 'package:chan/models/board.dart';
import 'package:chan/models/search.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/search_query.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/search_query_editor.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'board_switcher.dart';

class SelectedSearchResult {
	final Imageboard imageboard;
	final ImageboardArchiveSearchResult result;
	final String? threadSearch;
	final bool fromArchive;

	const SelectedSearchResult({
		required this.imageboard,
		required this.result,
		required this.threadSearch,
		required this.fromArchive
	});

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		(other is SelectedSearchResult) &&
		(other.imageboard == imageboard) &&
		(other.result == result) &&
		(other.threadSearch == threadSearch) &&
		(other.fromArchive == fromArchive);
	
	@override
	int get hashCode => Object.hash(imageboard, result, threadSearch, fromArchive);
}

extension _PreferBoardSpecificSearch on ImageboardSite {
	bool get preferBoardSpecificSearch =>
		// There are multiple boards on this site
		supportsMultipleBoards
		// Full-site and board search have different support (assuming board search is more powerful)
		&& supportsSearch('').options != supportsSearch(null).options;
}

class SearchPage extends StatefulWidget {
	const SearchPage({
		Key? key
	}) : super(key: key);

	@override
	createState() => SearchPageState();
}

class SearchPageState extends State<SearchPage> {
	final masterDetailKey = GlobalKey<MultiMasterDetailPageState>();
	late final ValueNotifier<SelectedSearchResult?> _valueInjector;

	@override
	void initState() {
		super.initState();
		_valueInjector = ValueNotifier(null);
	}

	void onSearchComposed(ImageboardArchiveSearchQuery query) {
		Persistence.recentSearches.handleSearch(query.clone());
		Persistence.didUpdateRecentSearches();
		masterDetailKey.currentState!.masterKey.currentState!.push(adaptivePageRoute(
			builder: (context) => ValueListenableBuilder(
				valueListenable: _valueInjector,
				builder: (context, SelectedSearchResult? selectedResult, child) {
					return SearchQueryPage(
						query: query,
						selectedResult: _valueInjector.value,
						onResultSelected: (result) {
							masterDetailKey.currentState!.setValue(0, result);
						}
					);
				}
			),
			settings: dontAutoPopSettings
		));
	}

	@override
	Widget build(BuildContext context) {
		return MultiMasterDetailPage(
			id: 'search',
			key: masterDetailKey,
			showChrome: false,
			paneCreator: () => [
				MultiMasterPane<SelectedSearchResult>(
					masterBuilder: (context, currentValue, setValue) {
						final v = context.watch<MasterDetailHint>().currentValue;
						WidgetsBinding.instance.addPostFrameCallback((_){
							_valueInjector.value = v;
						});
						return SearchComposePage(
							onSearchComposed: onSearchComposed,
							onManualResult: (result) => setValue(result)
						);
					},
					detailBuilder: (post, setter, poppedOut) => BuiltDetailPane(
						widget: post != null ? ImageboardScope(
							imageboardKey: null,
							imageboard: post.imageboard,
							child: ThreadPage(
								thread: post.result.threadIdentifier,
								initialPostId: post.result.id,
								initiallyUseArchive: post.fromArchive,
								initialSearch: post.threadSearch,
								boardSemanticId: -1
							)
						) : const AdaptiveScaffold(
							body: Center(
								child: Text('Select a search result')
							)
						),
						pageRouteBuilder: fullWidthCupertinoPageRouteBuilder
					)
				)
			]
		);
	}

	@override
	void dispose() {
		super.dispose();
		_valueInjector.dispose();
	}
}

class SearchComposePage extends StatefulWidget {
	final ValueChanged<ImageboardArchiveSearchQuery> onSearchComposed;
	final ValueChanged<SelectedSearchResult> onManualResult;

	const SearchComposePage({
		required this.onSearchComposed,
		required this.onManualResult,
		Key? key
	}) : super(key: key);

	@override
	createState() => _SearchComposePageState();
}

class _SearchComposePageState extends State<SearchComposePage> {
	late final TextEditingController _controller;
	late final FocusNode _focusNode;
	late ImageboardArchiveSearchQuery query;
	bool _searchFocused = false;
	bool _showingPicker = false;
	String? _lastImageboardKey;
	String? _lastBoardName;

	@override
	void initState() {
		super.initState();
		_controller = TextEditingController();
		_focusNode = FocusNode();
		final imageboard = Persistence.tabs[Persistence.currentTabIndex].imageboard;
		_lastImageboardKey = imageboard?.key;
		_lastBoardName = Persistence.tabs[Persistence.currentTabIndex].board;
		query = ImageboardArchiveSearchQuery(
			imageboardKey: _lastImageboardKey,
			boards: [
				if ((imageboard?.site.preferBoardSpecificSearch ?? false) && _lastBoardName != null) _lastBoardName!
			]
		);
		_focusNode.addListener(() {
			final bool isFocused = _focusNode.hasFocus;
			if (mounted && isFocused && !_searchFocused && !_showingPicker) {
				setState(() {
					_searchFocused = isFocused;
				});
			}
		});
		Persistence.recentSearchesListenable.addListener(_onRecentSearchesUpdate);
	}

	void _onRecentSearchesUpdate() {
		setState(() {});
	}

	void _submitQuery() {
		FocusManager.instance.primaryFocus!.unfocus();
		setState(() {
			_searchFocused = false;
		});
		widget.onSearchComposed(query);
	}

	@override
	Widget build(BuildContext context) {
		final firstCompatibleImageboard = ImageboardRegistry.instance.imageboards.tryFirstWhere((i) => i.site.supportsSearch(null).options.text || i.site.supportsSearch('').options.text);
		if (firstCompatibleImageboard == null) {
			return const Center(
				child: ErrorMessageCard('No added sites with search support')
			);
		}
		final currentImageboard = Persistence.tabs[Persistence.currentTabIndex].imageboard ?? firstCompatibleImageboard;
		if (currentImageboard.key != _lastImageboardKey && (currentImageboard.site.supportsSearch(null).options.text || currentImageboard.site.supportsSearch('').options.text)) {
			if (query.imageboardKey == _lastImageboardKey) {
				query.imageboardKey = currentImageboard.key;
				query.boards = [];
				_lastBoardName = null;
			}
		}
		_lastImageboardKey = currentImageboard.key;
		final currentBoardName = Persistence.tabs[Persistence.currentTabIndex].board;
		if (currentBoardName != _lastBoardName) {
			if (
				query.boards.tryLast == _lastBoardName
				&& currentImageboard.site.preferBoardSpecificSearch
				&& currentBoardName != null) {
				query.boards = [
					currentBoardName
				];
			}
			_lastBoardName = currentBoardName;
		}
		final imageboard = query.imageboard;
		final String? boardName;
		if (imageboard != null && query.boards.isNotEmpty) {
			boardName = imageboard.site.formatBoardName(query.boards.first);
		}
		else {
			boardName = null;
		}
		final primaryColor = ChanceTheme.primaryColorOf(context);
		Widget boardPicker({
			required double rightPadding,
			required bool showBoardName,
			required double maxWidth
		}) => Container(
			padding: const EdgeInsets.only(top: 4, bottom: 4),
			constraints: BoxConstraints(
				maxWidth: maxWidth + rightPadding
			),
			child: CupertinoButton(
				color: primaryColor.withOpacity(0.3),
				alignment: Alignment.centerLeft,
				minSize: 0,
				padding: EdgeInsets.only(left: 10, right: rightPadding),
				child: Row(
					mainAxisSize: MainAxisSize.min,
					children: [
						const SizedBox(height: 44),
						if (query.imageboardKey != null) ...[
							ImageboardIcon(imageboardKey: query.imageboardKey),
							const SizedBox(width: 4),
						]
						else const SizedBox(width: 20),
						if (showBoardName && query.boards.isNotEmpty && (imageboard?.site.supportsMultipleBoards ?? true)) Flexible(
							child: Text(
								'${boardName ?? '/${query.boards.first}'} ',
								style: TextStyle(
									color: primaryColor,
									fontSize: 17
								),
								maxLines: 1,
								overflow: TextOverflow.ellipsis
							)
						)
					]
				),
				onPressed: () async {
					final newBoard = await Navigator.of(context).push<ImageboardScoped<ImageboardBoard>>(TransparentRoute(
						builder: (ctx) => BoardSwitcherPage(
							initialImageboardKey: query.imageboardKey,
							filterImageboards: (b) => b.site.supportsSearch('').options.text,
							allowPickingWholeSites: true
						)
					));
					if (newBoard != null) {
						setState(() {
							query.imageboardKey = newBoard.imageboard.key;
							query.boards = newBoard.item.name.isEmpty ? [] : [newBoard.item.name];
						});
					}
				}
			)
		);
		final support = imageboard?.site.supportsSearch(query.boards.tryFirst);
		final options = support?.options ?? const ImageboardSearchOptions();
		return AdaptiveScaffold(
			resizeToAvoidBottomInset: false,
			disableAutoBarHiding: true, // Don't hide search bar
			bar: AdaptiveBar(
				title: Row(
					children: [
						Expanded(
							child: LayoutBuilder(
								builder: (context, constraints) {
									final showBoardName = constraints.maxWidth > 250;
									final searchPlaceholderPrefix = showBoardName ? '' : query.boards.tryFirst ?? '';
									return Stack(
										fit: StackFit.expand,
										children: [
											Align(
												alignment: Alignment.centerLeft,
												child: boardPicker(
													rightPadding: 30,
													showBoardName: showBoardName,
													maxWidth: constraints.maxWidth / 3
												)
											),
											Row(
												children: [
													Visibility(
														maintainState: true,
														maintainSize: true,
														maintainAnimation: true,
														visible: false,
														child: boardPicker(
															rightPadding: 5,
															showBoardName: showBoardName,
															maxWidth: constraints.maxWidth / 3
														)
													),
													Expanded(
														child: Padding(
															padding: const EdgeInsets.only(top: 4, bottom: 4),
															child: DecoratedBox(
																decoration: BoxDecoration(
																	borderRadius: ChanceTheme.materialOf(context) ? const BorderRadius.all(Radius.circular(4)) : const BorderRadius.all(Radius.circular(9)),
																	color: ChanceTheme.backgroundColorOf(context)
																),
																child: AdaptiveSearchTextField(
																	placeholder: 'Search ${searchPlaceholderPrefix.isEmpty ? '' : '$searchPlaceholderPrefix on '}${support?.name ?? 'archives'}...',
																	focusNode: _focusNode,
																	controller: _controller,
																	onSubmitted: (String q) {
																		_submitQuery();
																	},
																	enableIMEPersonalizedLearning: Settings.enableIMEPersonalizedLearningSetting.watch(context),
																	smartQuotesType: SmartQuotesType.disabled,
																	smartDashesType: SmartDashesType.disabled,
																	suffixVisible: _searchFocused,
																	prefixIcon: constraints.maxWidth < 150 ? null : CupertinoIcons.search,
																	onSuffixTap: () {
																		_focusNode.unfocus();
																		_controller.clear();
																		_searchFocused = false;
																		query = ImageboardArchiveSearchQuery(
																			imageboardKey: query.imageboardKey,
																			boards: query.boards
																		);
																		setState(() {});
																	},
																	onChanged: (String q) {
																		query.query = q;
																		setState(() {});
																	}
																)
															)
														)
													)
												]
											)
										]
									);
								}
							)
						),
						AdaptiveIconButton(
							icon: const Icon(CupertinoIcons.number_square),
							onPressed: () async {
								final idController = TextEditingController();
								final initialBoard = await Navigator.of(context).push<ImageboardScoped<ImageboardBoard>>(TransparentRoute(
									builder: (ctx) => const BoardSwitcherPage()
								));
								if (context.mounted && initialBoard != null) {
									ImageboardScoped<ImageboardBoard> board = initialBoard;
									final target = await showAdaptiveDialog<(Imageboard, String, int)>(
										context: context,
										barrierDismissible: true,
										builder: (context) => StatefulBuilder(
											builder: (context, setInnerState) => AdaptiveAlertDialog(
												title: const Text('Go to post'),
												content: Column(
													mainAxisSize: MainAxisSize.min,
													children: [
														const SizedBox(height: 8),
														CupertinoButton(
															onPressed: () async {
																final newBoard = await Navigator.of(context).push<ImageboardScoped<ImageboardBoard>>(TransparentRoute(
																	builder: (ctx) => const BoardSwitcherPage()
																));
																if (newBoard != null) {
																	setInnerState(() {
																		board = newBoard;
																	});
																}
															},
															child: Row(
																mainAxisSize: MainAxisSize.min,
																children: [
																	ImageboardIcon(imageboardKey: board.imageboard.key, boardName: board.item.name),
																	const SizedBox(width: 4),
																	Text(board.item.name, style: const TextStyle(
																		color: Colors.white
																	))
																]
															)
														),
														const SizedBox(height: 8),
														AdaptiveTextField(
															controller: idController,
															enableIMEPersonalizedLearning: false,
															placeholder: 'Post ID',
															autofocus: true,
															keyboardType: TextInputType.number,
															onChanged: (_) => setInnerState(() {}),
															onSubmitted: (str) {
																Navigator.of(context).pop((board.imageboard, board.item.name, int.parse(idController.text)));
															}
														)
													]
												),
												actions: [
													AdaptiveDialogAction(
														isDefaultAction: true,
														onPressed: int.tryParse(idController.text) != null ? () {
															Navigator.of(context).pop((board.imageboard, board.item.name, int.parse(idController.text)));
														} : null,
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
										)
									);
									idController.dispose();
									if (mounted && target != null) {
										try {
											final result = await modalLoad(context, 'Finding post...', (controller) async {
												try {
													final thread = await target.$1.site.getThread(ThreadIdentifier(target.$2, target.$3), priority: RequestPriority.interactive);
													return SelectedSearchResult(
														fromArchive: false,
														threadSearch: null,
														imageboard: target.$1,
														result: ImageboardArchiveSearchResult.thread(thread)
													);
												}
												on ThreadNotFoundException {
													// Not a thread
												}
												final post = await target.$1.site.getPostFromArchive(target.$2, target.$3, priority: RequestPriority.interactive);
												try {
													final liveThread = await target.$1.site.getThread(post.threadIdentifier, priority: RequestPriority.interactive);
													final livePost = liveThread.posts_.firstWhere((p) => p.id == target.$3);
													return SelectedSearchResult(
														fromArchive: false,
														threadSearch: null,
														imageboard: target.$1,
														result: ImageboardArchiveSearchResult.post(livePost)
													);
												}
												catch (_) {
													// Truly archived
													return SelectedSearchResult(
														fromArchive: true,
														threadSearch: null,
														imageboard: target.$1,
														result: ImageboardArchiveSearchResult.post(post)
													);
												}
											});
											widget.onManualResult(result);
										}
										catch (e) {
											if (context.mounted) {
												alertError(context, e.toStringDio());
											}
										}
									}
								}
							}
						)
					]
				)
			),
			body: AnimatedSwitcher(
				duration: const Duration(milliseconds: 300),
				switchInCurve: Curves.easeIn,
				switchOutCurve: Curves.easeOut,
				child: (_searchFocused &&
				        query.imageboardKey != null &&
								options.hasOptions
								) ? Align(
					alignment: Alignment.topCenter,
					child: SingleChildScrollView(
						key: const ValueKey(true),
						child: SearchQueryEditor(
							query: query,
							onChanged: () {
								setState(() {});
							},
							onPickerHide: () {
								_showingPicker = false;
							},
							onPickerShow: () {
								_showingPicker = true;
							},
							onSubmitted: _submitQuery,
						)
					)
				) : ListView(
					key: const ValueKey(false),
					children: Persistence.recentSearches.entries.map((q) {
						return GestureDetector(
							behavior: HitTestBehavior.opaque,
							onTap: () => widget.onSearchComposed(q),
							child: Container(
								decoration: BoxDecoration(
									border: Border(bottom: BorderSide(color: ChanceTheme.primaryColorWithBrightness20Of(context)))
								),
								padding: const EdgeInsets.all(16),
								child: Row(
									children: [
										Expanded(
											child: Wrap(
												runSpacing: 8,
												crossAxisAlignment: WrapCrossAlignment.center,
												children: describeQuery(q)
											)
										),
										CupertinoButton(
											padding: EdgeInsets.zero,
											child: const Icon(CupertinoIcons.xmark),
											onPressed: () {
												Persistence.recentSearches.remove(q);
												Persistence.didUpdateRecentSearches();
												setState(() {});
											}
										)
									]
								)
							)
						);
					}).toList()
				)
			)
		);
	}

	@override
	void dispose() {
		super.dispose();
		Persistence.recentSearchesListenable.removeListener(_onRecentSearchesUpdate);
		_controller.dispose();
		_focusNode.dispose();
	}
}

List<Widget> describeQuery(ImageboardArchiveSearchQuery q) {
	final imageboard = ImageboardRegistry.instance.getImageboard(q.imageboardKey);
	return [
		if (q.imageboardKey != null) ImageboardIcon(imageboardKey: q.imageboardKey),
		if (q.boards.isNotEmpty && (imageboard?.site.supportsMultipleBoards ?? true)) ...q.boards.map((boardName) {
			final formattedBoardName = imageboard?.site.formatBoardName(boardName);
			return _SearchQueryFilterTag(formattedBoardName ?? '/$boardName/');
		})
		else const SizedBox(width: 8),
		Text(q.query),
		if (q.mediaFilter == MediaFilter.onlyWithMedia) const _SearchQueryFilterTag('With images'),
		if (q.mediaFilter == MediaFilter.onlyWithNoMedia) const _SearchQueryFilterTag('Without images'),
		if (q.postTypeFilter == PostTypeFilter.onlyOPs) const _SearchQueryFilterTag('Threads'),
		if (q.postTypeFilter == PostTypeFilter.onlyReplies) const _SearchQueryFilterTag('Replies'),
		if (q.postTypeFilter == PostTypeFilter.onlyReplies) const _SearchQueryFilterTag('Stickies'),
		if (q.startDate != null) _SearchQueryFilterTag('After ${q.startDate!.toISO8601Date}'),
		if (q.endDate != null) _SearchQueryFilterTag('Before ${q.endDate!.toISO8601Date}'),
		if (q.md5 != null) _SearchQueryFilterTag('MD5: ${q.md5}'),
		if (q.deletionStatusFilter == PostDeletionStatusFilter.onlyDeleted) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(CupertinoIcons.trash)),
		if (q.deletionStatusFilter == PostDeletionStatusFilter.onlyNonDeleted) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(CupertinoIcons.trash_slash)),
		if (q.subject?.isNotEmpty ?? false) _SearchQueryFilterTag('Subject: ${q.subject}'),
		if (q.name?.isNotEmpty ?? false) _SearchQueryFilterTag('Name: ${q.name}'),
		if (q.trip?.isNotEmpty ?? false) _SearchQueryFilterTag('Trip: ${q.trip}')
	];
}

class _SearchQueryFilterTag extends StatelessWidget {
	final String filterDescription;
	const _SearchQueryFilterTag(this.filterDescription);
	@override
	Widget build(BuildContext context) {
		return Container(
			margin: const EdgeInsets.only(left: 4, right: 4),
			padding: const EdgeInsets.all(4),
			decoration: BoxDecoration(
				color: ChanceTheme.primaryColorOf(context).withOpacity(0.3),
				borderRadius: const BorderRadius.all(Radius.circular(4))
			),
			child: Text(filterDescription)
		);
	}
}
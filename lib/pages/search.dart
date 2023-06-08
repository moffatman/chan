import 'dart:convert';

import 'package:chan/models/board.dart';
import 'package:chan/models/search.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/search_query.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/pick_attachment.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/cupertino_adaptive_segmented_control.dart';
import 'package:chan/widgets/cupertino_dialog.dart';
import 'package:chan/widgets/cupertino_text_field2.dart';
import 'package:chan/widgets/cupertino_thin_button.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/util.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:chan/widgets/cupertino_page_route.dart';
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
		(other is SelectedSearchResult) &&
		(other.imageboard == imageboard) &&
		(other.result == result) &&
		(other.threadSearch == threadSearch) &&
		(other.fromArchive == fromArchive);
	
	@override
	int get hashCode => Object.hash(imageboard, result, threadSearch, fromArchive);
}

class SearchPage extends StatefulWidget {
	const SearchPage({
		Key? key
	}) : super(key: key);

	@override
	createState() => SearchPageState();
}

class SearchPageState extends State<SearchPage> {
	final _masterDetailKey = GlobalKey<MultiMasterDetailPageState>();
	late final ValueNotifier<SelectedSearchResult?> _valueInjector;

	@override
	void initState() {
		super.initState();
		_valueInjector = ValueNotifier(null);
	}

	void onSearchComposed(ImageboardArchiveSearchQuery query) {
		Persistence.recentSearches.handleSearch(query.clone());
		Persistence.didUpdateRecentSearches();
		_masterDetailKey.currentState!.masterKey.currentState!.push(FullWidthCupertinoPageRoute(
			builder: (context) => ValueListenableBuilder(
				valueListenable: _valueInjector,
				builder: (context, SelectedSearchResult? selectedResult, child) {
					final child = SearchQueryPage(
						query: query,
						selectedResult: _valueInjector.value,
						onResultSelected: (result) {
							_masterDetailKey.currentState!.setValue(0, result);
						}
					);
					if (query.imageboardKey == null) {
						return child;
					}
					return ImageboardScope(
						imageboardKey: query.imageboardKey!,
						child: child
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
			key: _masterDetailKey,
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
						) : Builder(
							builder: (context) => Container(
								decoration: BoxDecoration(
									color: ChanceTheme.backgroundColorOf(context),
								),
								child: const Center(
									child: Text('Select a search result')
								)
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

enum _MediaFilter {
	none,
	onlyWithMedia,
	onlyWithNoMedia,
	withSpecificMedia
}

extension _ConvertToPublic on _MediaFilter {
	MediaFilter? get value {
		switch (this) {
			case _MediaFilter.none:
				return MediaFilter.none;
			case _MediaFilter.onlyWithMedia:
				return MediaFilter.onlyWithMedia;
			case _MediaFilter.onlyWithNoMedia:
				return MediaFilter.onlyWithNoMedia;
			default:
				return null;
		}
	}
}

extension _ConvertToPrivate on MediaFilter {
	_MediaFilter? get value {
		switch (this) {
			case MediaFilter.none:
				return _MediaFilter.none;
			case MediaFilter.onlyWithMedia:
				return _MediaFilter.onlyWithMedia;
			case MediaFilter.onlyWithNoMedia:
				return _MediaFilter.onlyWithNoMedia;
		}
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
	late final TextEditingController _subjectFieldController;
	late final TextEditingController _nameFieldController;
	late final TextEditingController _tripFieldController;

	@override
	void initState() {
		super.initState();
		_controller = TextEditingController();
		_focusNode = FocusNode();
		_lastImageboardKey = Persistence.tabs[Persistence.currentTabIndex].imageboardKey;
		query = ImageboardArchiveSearchQuery(
			imageboardKey: _lastImageboardKey,
			boards: []
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
		_subjectFieldController = TextEditingController();
		_nameFieldController = TextEditingController();
		_tripFieldController = TextEditingController();
	}

	void _onRecentSearchesUpdate() {
		setState(() {});
	}

	@override
	Widget build(BuildContext context) {
		final firstCompatibleImageboard = ImageboardRegistry.instance.imageboards.tryFirstWhere((i) => i.site.supportsSearch);
		if (firstCompatibleImageboard == null) {
			return const Center(
				child: ErrorMessageCard('No added sites with search support')
			);
		}
		final currentImageboard = Persistence.tabs[Persistence.currentTabIndex].imageboard ?? firstCompatibleImageboard;
		if (currentImageboard.key != _lastImageboardKey && currentImageboard.site.supportsSearch) {
			if (query.imageboardKey == _lastImageboardKey) {
				query.imageboardKey = currentImageboard.key;
			}
		}
		_lastImageboardKey = currentImageboard.key;
		final imageboard = ImageboardRegistry.instance.getImageboard(query.imageboardKey ?? '');
		final String? boardName;
		if (imageboard != null && query.boards.isNotEmpty) {
			boardName = imageboard.site.formatBoardName(imageboard.persistence.getBoard(query.boards.first));
		}
		else {
			boardName = null;
		}
		return CupertinoPageScaffold(
			resizeToAvoidBottomInset: false,
			navigationBar: CupertinoNavigationBar(
				transitionBetweenRoutes: false,
				middle: Stack(
					fit: StackFit.expand,
					children: [
						Row(
							children: [
								Container(
									padding: const EdgeInsets.only(top: 4, bottom: 4),
									child: CupertinoButton(
										color: ChanceTheme.primaryColorOf(context).withOpacity(0.3),
										alignment: Alignment.centerLeft,
										padding: const EdgeInsets.only(left: 10, right: 20),
										child: Row(
											mainAxisSize: MainAxisSize.min,
											children: [
												if (ImageboardRegistry.instance.count > 1 && query.imageboardKey != null) ...[
													ImageboardIcon(imageboardKey: query.imageboardKey),
													const SizedBox(width: 4),
												],
												if (query.boards.isNotEmpty && (imageboard?.site.supportsMultipleBoards ?? true)) Text(boardName ?? '/${query.boards.first}', style: const TextStyle(
													color: Colors.white
												))
											]
										),
										onPressed: () async {
											final newBoard = await Navigator.of(context).push<ImageboardScoped<ImageboardBoard>>(TransparentRoute(
												builder: (ctx) => BoardSwitcherPage(
													initialImageboardKey: query.imageboardKey,
													filterImageboards: (b) => b.site.supportsSearch,
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
								)
							]
						),
						Row(
							children: [
								Visibility(
									maintainState: true,
									maintainSize: true,
									maintainAnimation: true,
									visible: false,
									child: Container(
										padding: const EdgeInsets.only(left: 10, right: 5),
										child: Row(
											mainAxisSize: MainAxisSize.min,
											children: [
												if (ImageboardRegistry.instance.count > 1 && query.imageboardKey != null) ...[
													ImageboardIcon(imageboardKey: query.imageboardKey),
													const SizedBox(width: 4),
												],
												if (query.boards.isNotEmpty && (imageboard?.site.supportsMultipleBoards ?? true)) Text(boardName ?? '/${query.boards.first}', style: const TextStyle(
													color: Colors.white
												))
											]
										)
									)
								),
								Expanded(
									child: Container(
										margin: const EdgeInsets.only(top: 4, bottom: 4),
										child: Stack(
											fit: StackFit.expand,
											children: [
												Container(
													decoration: BoxDecoration(
														borderRadius: const BorderRadius.all(Radius.circular(9)),
														color: ChanceTheme.barColorOf(context)
													),
												),
												CupertinoSearchTextField2(
													placeholder: 'Search archives...',
													focusNode: _focusNode,
													controller: _controller,
													onSubmitted: (String q) {
														_controller.clear();
														FocusManager.instance.primaryFocus!.unfocus();
														widget.onSearchComposed(query);
													},
													enableIMEPersonalizedLearning: context.select<EffectiveSettings, bool>((s) => s.enableIMEPersonalizedLearning),
													smartQuotesType: SmartQuotesType.disabled,
													smartDashesType: SmartDashesType.disabled,
													onSuffixTap: () {
														_controller.clear();
														FocusManager.instance.primaryFocus!.unfocus();
													},
													onChanged: (String q) {
														query.query = q;
														setState(() {});
													}
												)
											]
										)
									)
								),
								if (_searchFocused) CupertinoButton(
									padding: const EdgeInsets.only(left: 8),
									child: const Text('Cancel'),
									onPressed: () {
										FocusManager.instance.primaryFocus!.unfocus();
										_controller.clear();
										_searchFocused = false;
										query = ImageboardArchiveSearchQuery(
											imageboardKey: query.imageboardKey,
											boards: query.boards
										);
										setState(() {});
									}
								),
								CupertinoButton(
									padding: const EdgeInsets.only(left: 8),
									child: const Icon(CupertinoIcons.number_square),
									onPressed: () async {
										final idController = TextEditingController();
										final initialBoard = await Navigator.of(context).push<ImageboardScoped<ImageboardBoard>>(TransparentRoute(
											builder: (ctx) => const BoardSwitcherPage()
										));
										if (context.mounted && initialBoard != null) {
											ImageboardScoped<ImageboardBoard> board = initialBoard;
											final target = await showCupertinoDialog<(Imageboard, String, int)>(
												context: context,
												barrierDismissible: true,
												builder: (context) => StatefulBuilder(
													builder: (context, setInnerState) => CupertinoAlertDialog2(
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
																CupertinoTextField2(
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
															CupertinoDialogAction2(
																child: const Text('Cancel'),
																onPressed: () {
																	Navigator.of(context).pop();
																}
															),
															CupertinoDialogAction2(
																isDefaultAction: true,
																onPressed: int.tryParse(idController.text) != null ? () {
																	Navigator.of(context).pop((board.imageboard, board.item.name, int.parse(idController.text)));
																} : null,
																child: const Text('OK')
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
															final thread = await target.$1.site.getThread(ThreadIdentifier(target.$2, target.$3), interactive: true);
															return ImageboardArchiveSearchResult.thread(thread);
														}
														on ThreadNotFoundException {
															// Not a thread
														}
														final post = await target.$1.site.getPostFromArchive(target.$2, target.$3, interactive: true);
														return ImageboardArchiveSearchResult.post(post);
													});
													widget.onManualResult(SelectedSearchResult(
														fromArchive: true,
														threadSearch: null,
														imageboard: target.$1,
														result: result
													));
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
					]
				)
			),
			child: AnimatedSwitcher(
				duration: const Duration(milliseconds: 300),
				switchInCurve: Curves.easeIn,
				switchOutCurve: Curves.easeOut,
				child: (_searchFocused &&
				        query.imageboardKey != null &&
								(ImageboardRegistry.instance.getImageboard(query.imageboardKey!)?.site.supportsSearchOptions ?? false) &&
								(query.boards.isNotEmpty || (ImageboardRegistry.instance.getImageboard(query.imageboardKey!)?.site.supportsGlobalSearchOptions ?? false))
								) ? ListView(
					key: const ValueKey(true),
					children: [
						const SizedBox(height: 16),
						CupertinoAdaptiveSegmentedControl<PostTypeFilter>(
							children: const {
								PostTypeFilter.none: (null, 'All posts'),
								PostTypeFilter.onlyOPs: (null, 'Threads'),
								PostTypeFilter.onlyReplies: (null, 'Replies'),
								PostTypeFilter.onlyStickies: (null, 'Stickies')
							},
							groupValue: query.postTypeFilter,
							onValueChanged: (newValue) {
								query.postTypeFilter = newValue;
								setState(() {});
							}
						),
						const SizedBox(height: 16),
						CupertinoAdaptiveSegmentedControl<_MediaFilter>(
							children: const {
								_MediaFilter.none: (null, 'All posts'),
								_MediaFilter.onlyWithMedia: (null, 'With images'),
								_MediaFilter.onlyWithNoMedia: (null, 'Without images'),
								_MediaFilter.withSpecificMedia: (null, 'With MD5')
							},
							groupValue: query.md5 == null ? query.mediaFilter.value : _MediaFilter.withSpecificMedia,
							onValueChanged: (newValue) async {
								if (newValue.value != null) {
									query.md5 = null;
									query.mediaFilter = newValue.value!;
								}
								else {
									_showingPicker = true;
									final file = await pickAttachment(context: context);
									_showingPicker = false;
									if (file != null) {
										query.md5 = base64Encode(md5.convert(await file.readAsBytes()).bytes);
										query.mediaFilter = MediaFilter.none;
									}
								}
								setState(() {});
							}
						),
						const SizedBox(height: 16),
						CupertinoAdaptiveSegmentedControl<PostDeletionStatusFilter>(
							children: const {
								PostDeletionStatusFilter.none: (null, 'All posts'),
								PostDeletionStatusFilter.onlyDeleted: (null, 'Only deleted'),
								PostDeletionStatusFilter.onlyNonDeleted: (null, 'Only non-deleted')
							},
							groupValue: query.deletionStatusFilter,
							onValueChanged: (newValue) {
								query.deletionStatusFilter = newValue;
								setState(() {});
							}
						),
						const SizedBox(height: 16),
						Wrap(
							runSpacing: 16,
							alignment: WrapAlignment.center,
							runAlignment: WrapAlignment.center,
							children: [
								Container(
									padding: const EdgeInsets.symmetric(horizontal: 8),
									child: CupertinoThinButton(
										filled: query.startDate != null,
										child: Text(
											(query.startDate != null) ? 'Posted after ${query.startDate!.toISO8601Date}' : 'Posted after...',
											textAlign: TextAlign.center
										),
										onPressed: () async {
											_showingPicker = true;
											final newDate = await pickDate(
												context: context,
												initialDate: query.startDate
											);
											_showingPicker = false;
											setState(() {
												query.startDate = newDate;
											});
										}
									)
								),
								Container(
									padding: const EdgeInsets.symmetric(horizontal: 8),
									child: CupertinoThinButton(
										filled: query.endDate != null,
										child: Text(
											(query.endDate != null) ? 'Posted before ${query.endDate!.toISO8601Date}' : 'Posted before...',
											textAlign: TextAlign.center
										),
										onPressed: () async {
											_showingPicker = true;
											final newDate = await pickDate(
												context: context,
												initialDate: query.endDate
											);
											_showingPicker = false;
											setState(() {
												query.endDate = newDate;
											});
										}
									)
								)
							]
						),
						Wrap(
							alignment: WrapAlignment.center,
							runAlignment: WrapAlignment.center,
							children: [
								for (final field in [
									(
										name: 'Subject',
										cb: (String s) => query.subject = s,
										controller: _subjectFieldController
									),
									(
										name: 'Name',
										cb: (String s) => query.name = s,
										controller: _nameFieldController
									),
									(
										name: 'Trip',
										cb: (String s) => query.trip = s,
										controller: _tripFieldController
									)
								]) Container(
									width: 200,
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Text(field.name),
											const SizedBox(height: 4),
											CupertinoTextField2(
												controller: field.controller,
												onChanged: field.cb
											)
										]
									)
								)
							]
						),
						if (query.md5 != null) Container(
							padding: const EdgeInsets.only(top: 16),
							alignment: Alignment.center,
							child: Text('MD5: ${query.md5}')
						)
					]
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
		_subjectFieldController.dispose();
		_nameFieldController.dispose();
		_tripFieldController.dispose();
	}
}

List<Widget> describeQuery(ImageboardArchiveSearchQuery q) {
	final imageboard = ImageboardRegistry.instance.getImageboard(q.imageboardKey ?? '');
	return [
		if (ImageboardRegistry.instance.count > 1 && q.imageboardKey != null) ImageboardIcon(imageboardKey: q.imageboardKey),
		if (q.boards.isNotEmpty && (imageboard?.site.supportsMultipleBoards ?? true)) ...q.boards.map((boardName) {
			final board = imageboard?.persistence.getBoard(boardName);
			final formattedBoardName = board == null ? null : imageboard!.site.formatBoardName(board);
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
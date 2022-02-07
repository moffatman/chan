import 'dart:convert';

import 'package:chan/models/board.dart';
import 'package:chan/models/search.dart';
import 'package:chan/pages/imageboard_switcher.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/search_query.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/pick_attachment.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/cupertino_thin_button.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/util.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:chan/widgets/cupertino_page_route.dart';
import 'package:provider/provider.dart';
import 'board_switcher.dart';

class SearchPage extends StatefulWidget {
	const SearchPage({
		Key? key
	}) : super(key: key);

	@override
	createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
	final _valueInjector = ValueNotifier<ImageboardArchiveSearchResult?>(null);
	@override
	Widget build(BuildContext context) {
		return MasterDetailPage<ImageboardArchiveSearchResult>(
			id: 'search',
			masterBuilder: (context, currentValue, setValue) {
				WidgetsBinding.instance.addPostFrameCallback((_){
					_valueInjector.value = currentValue;
				});
				return SearchComposePage(
					onSearchComposed: (query) {
						Navigator.of(context).push(FullWidthCupertinoPageRoute(
							builder: (context) => ValueListenableBuilder(
								valueListenable: _valueInjector,
								builder: (context, ImageboardArchiveSearchResult? selectedResult, child) {
									final child = SearchQueryPage(
										query: query,
										selectedResult: _valueInjector.value,
										onResultSelected: setValue
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
							showAnimations: context.read<EffectiveSettings>().showAnimations,
							settings: dontAutoPopSettings
						));
					},
				);
			},
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

final _clearedDate = DateTime.fromMillisecondsSinceEpoch(0);

class SearchComposePage extends StatefulWidget {
	final ValueChanged<ImageboardArchiveSearchQuery> onSearchComposed;

	const SearchComposePage({
		required this.onSearchComposed,
		Key? key
	}) : super(key: key);

	@override
	createState() => _SearchComposePageState();
}

class _SearchComposePageState extends State<SearchComposePage> {
	final _controller = TextEditingController();
	final _focusNode = FocusNode();
	late ImageboardArchiveSearchQuery query;
	DateTime? _chosenDate;
	bool _searchFocused = false;
	bool _showingPicker = false;
	late String? _lastImageboardKey;
	late String? _lastBoardName;

	@override
	void initState() {
		super.initState();
		_lastImageboardKey = Persistence.tabs[Persistence.currentTabIndex].imageboardKey;
		_lastBoardName = Persistence.tabs[Persistence.currentTabIndex].board?.name;
		query = ImageboardArchiveSearchQuery(
			imageboardKey: _lastImageboardKey,
			boards: [
				if (_lastBoardName != null) _lastBoardName!
			]
		);
		_focusNode.addListener(() {
			final bool isFocused = _focusNode.hasFocus;
			if (mounted && (isFocused != _searchFocused) && !_showingPicker) {
				setState(() {
					_searchFocused = isFocused;
				});
			}
		});
	}

	Future<DateTime?> _getDate(DateTime? initialDate) {
		_chosenDate = initialDate ?? DateTime.now();
		return showCupertinoModalPopup<DateTime>(
			context: context,
			builder: (context) => Container(
				color: CupertinoTheme.of(context).scaffoldBackgroundColor,
				child: SafeArea(
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							SizedBox(
								height: 300,
								child: CupertinoDatePicker(
									mode: CupertinoDatePickerMode.date,
									initialDateTime: initialDate,
									onDateTimeChanged: (newDate) {
										_chosenDate = newDate;
									}
								)
							),
							Row(
								mainAxisAlignment: MainAxisAlignment.spaceEvenly,
								children: [
									CupertinoButton(
										child: const Text('Cancel'),
										onPressed: () => Navigator.of(context).pop()
									),
									CupertinoButton(
										child: const Text('Clear Date'),
										onPressed: () => Navigator.of(context).pop(_clearedDate)
									),
									CupertinoButton(
										child: const Text('Done'),
										onPressed: () => Navigator.of(context).pop(_chosenDate)
									)
								]
							)
						]
					)
				)
			)
		);
	}

	@override
	Widget build(BuildContext context) {
		final currentBoardName = Persistence.tabs[Persistence.currentTabIndex].board?.name ?? 'tv';
		if (currentBoardName != _lastBoardName) {
			if (query.boards.isEmpty || query.boards.first == _lastBoardName) {
				query.boards = [currentBoardName];
			}
			_lastBoardName = currentBoardName;
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
										color: CupertinoTheme.of(context).primaryColor.withOpacity(0.3),
										alignment: Alignment.centerLeft,
										padding: const EdgeInsets.only(left: 10, right: 20),
										child: Text('/${query.boards.first}/', style: const TextStyle(
											color: Colors.white
										)),
										onPressed: () async {
											final newBoard = await Navigator.of(context).push<ImageboardScoped<ImageboardBoard>>(TransparentRoute(
												builder: (ctx) => ImageboardSwitcherPage(
													builder: (ctx) => const BoardSwitcherPage()
												),
												showAnimations: context.read<EffectiveSettings>().showAnimations
											));
											if (newBoard != null) {
												setState(() {
													query.imageboardKey = newBoard.imageboard.key;
													query.boards = [newBoard.item.name];
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
										child: Text('/${query.boards.first}/', style: const TextStyle(
											color: Colors.black,
											fontWeight: FontWeight.bold
										))
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
														color: CupertinoTheme.of(context).barBackgroundColor
													),
												),
												CupertinoSearchTextField(
													placeholder: 'Search archives...',
													focusNode: _focusNode,
													controller: _controller,
													onSubmitted: (String q) {
														_controller.clear();
														FocusManager.instance.primaryFocus!.unfocus();
														Persistence.recentSearches.add(query.clone());
														Persistence.didUpdateRecentSearches();
														widget.onSearchComposed(query);
													},
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
				child: _searchFocused ? ListView(
					key: const ValueKey(true),
					children: [
						const SizedBox(height: 16),
						CupertinoSegmentedControl<PostTypeFilter>(
							children: const {
								PostTypeFilter.none: Text('All posts'),
								PostTypeFilter.onlyOPs: Text('Threads'),
								PostTypeFilter.onlyReplies: Text('Replies')
							},
							groupValue: query.postTypeFilter,
							onValueChanged: (newValue) {
								query.postTypeFilter = newValue;
								setState(() {});
							}
						),
						const SizedBox(height: 16),
						LayoutBuilder(
							builder: (context, constraints) {
								TextStyle? style;
								if (constraints.maxWidth < 290) {
									style = const TextStyle(
										fontSize: 10
									);
								}
								else if (constraints.maxWidth < 350) {
									style = const TextStyle(
										fontSize: 13
									);
								}
								return CupertinoSegmentedControl<_MediaFilter>(
									children: {
										_MediaFilter.none: Text('All posts', textAlign: TextAlign.center, style: style),
										_MediaFilter.onlyWithMedia: Text('With images', textAlign: TextAlign.center, style: style),
										_MediaFilter.onlyWithNoMedia: Padding(
											padding: const EdgeInsets.all(8),
											child: Text('Without images', textAlign: TextAlign.center, style: style)
										),
										_MediaFilter.withSpecificMedia: Text('With MD5', textAlign: TextAlign.center, style: style)
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
								);
							}
						),
						const SizedBox(height: 16),
						CupertinoSegmentedControl<PostDeletionStatusFilter>(
							children: const {
								PostDeletionStatusFilter.none: Text('All posts'),
								PostDeletionStatusFilter.onlyDeleted: Text('Only deleted'),
								PostDeletionStatusFilter.onlyNonDeleted: Text('Only non-deleted')
							},
							groupValue: query.deletionStatusFilter,
							onValueChanged: (newValue) {
								query.deletionStatusFilter = newValue;
								setState(() {});
							}
						),
						const SizedBox(height: 16),
						Row(
							children: [
								Expanded(
									child: Container(
										padding: const EdgeInsets.only(left: 16, right: 8),
										child: CupertinoThinButton(
											filled: query.startDate != null,
											child: Text(
												(query.startDate != null) ? 'Posted after ${query.startDate!.year}-${query.startDate!.month.toString().padLeft(2, '0')}-${query.startDate!.day.toString().padLeft(2, '0')}' : 'Posted after...',
												textAlign: TextAlign.center
											),
											onPressed: () async {
												_showingPicker = true;
												final newDate = await _getDate(query.startDate);
												_showingPicker = false;
												if (newDate != null) {
													setState(() {
														query.startDate = (newDate == _clearedDate) ? null : newDate;
													});
												}
											}
										)
									)
								),
								Expanded(
									child: Container(
										padding: const EdgeInsets.only(left: 8, right: 16),
										child: CupertinoThinButton(
											filled: query.endDate != null,
											child: Text(
												(query.endDate != null) ? 'Posted before ${query.endDate!.year}-${query.endDate!.month.toString().padLeft(2, '0')}-${query.endDate!.day.toString().padLeft(2, '0')}' : 'Posted before...',
												textAlign: TextAlign.center
											),
											onPressed: () async {
												_showingPicker = true;
												final newDate = await _getDate(query.endDate);
												_showingPicker = false;
												if (newDate != null) {
													setState(() {
														query.endDate = (newDate == _clearedDate) ? null : newDate;
													});
												}
											}
										)
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
							onTap: () {
								Persistence.recentSearches.bump(q);
								Persistence.didUpdateRecentSearches();
								widget.onSearchComposed(q);
							},
							child: Container(
								decoration: BoxDecoration(
									border: Border(bottom: BorderSide(color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2)))
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
}

List<Widget> describeQuery(ImageboardArchiveSearchQuery q) {
	return [
		...q.boards.map(
			(board) => _SearchQueryFilterTag('/$board/')
		),
		Text(q.query),
		if (q.mediaFilter == MediaFilter.onlyWithMedia) const _SearchQueryFilterTag('With images'),
		if (q.mediaFilter == MediaFilter.onlyWithNoMedia) const _SearchQueryFilterTag('Without images'),
		if (q.postTypeFilter == PostTypeFilter.onlyOPs) const _SearchQueryFilterTag('Threads'),
		if (q.postTypeFilter == PostTypeFilter.onlyReplies) const _SearchQueryFilterTag('Replies'),
		if (q.startDate != null) _SearchQueryFilterTag('After ${q.startDate!.year}-${q.startDate!.month.toString().padLeft(2, '0')}-${q.startDate!.day.toString().padLeft(2, '0')}'),
		if (q.endDate != null) _SearchQueryFilterTag('Before ${q.endDate!.year}-${q.endDate!.month.toString().padLeft(2, '0')}-${q.endDate!.day.toString().padLeft(2, '0')}'),
		if (q.md5 != null) _SearchQueryFilterTag('MD5: ${q.md5}'),
		if (q.deletionStatusFilter == PostDeletionStatusFilter.onlyDeleted) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(CupertinoIcons.trash)),
		if (q.deletionStatusFilter == PostDeletionStatusFilter.onlyNonDeleted) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(CupertinoIcons.trash_slash))
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
				color: CupertinoTheme.of(context).primaryColor.withOpacity(0.3),
				borderRadius: const BorderRadius.all(Radius.circular(4))
			),
			child: Text(filterDescription)
		);
	}
}
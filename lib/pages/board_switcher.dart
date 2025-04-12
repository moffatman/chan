import 'dart:async';
import 'dart:math';

import 'package:chan/models/board.dart';
import 'package:chan/services/apple.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/util.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/context_menu.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/scroll_tracker.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

extension _Unnullify on ImageboardScoped<ImageboardBoard?> {
	ImageboardScoped<ImageboardBoard> get unnullify => ImageboardScoped(
		imageboard: imageboard,
		item: item!
	);
}

extension _Nullify on ImageboardScoped<ImageboardBoard> {
	ImageboardScoped<ImageboardBoard?> get nullify => ImageboardScoped(
		imageboard: imageboard,
		item: item
	);
}

class _Board {
	final Imageboard imageboard;
	final ImageboardBoard item;
	final int typeaheadIndex;
	final int matchIndex;
	final int favsIndex;
	final int imageboardPriorityIndex;

	_Board(ImageboardScoped<ImageboardBoard> board, {
		required this.typeaheadIndex,
		required this.matchIndex,
		required this.favsIndex,
		required this.imageboardPriorityIndex
	}) : imageboard = board.imageboard, item = board.item;

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is _Board &&
		other.imageboard == imageboard &&
		other.item == item &&
		other.typeaheadIndex == typeaheadIndex &&
		other.matchIndex == matchIndex &&
		other.favsIndex == favsIndex &&
		other.imageboardPriorityIndex == imageboardPriorityIndex;
	
	@override
	int get hashCode => Object.hash(imageboard, item, typeaheadIndex, matchIndex, favsIndex, imageboardPriorityIndex);
}

class BoardSwitcherPage extends StatefulWidget {
	final bool Function(Imageboard imageboard)? filterImageboards;
	final String? initialImageboardKey;
	final bool currentlyPickingFavourites;
	final bool allowPickingWholeSites;

	const BoardSwitcherPage({
		this.currentlyPickingFavourites = false,
		this.filterImageboards,
		this.initialImageboardKey,
		this.allowPickingWholeSites = false,
		Key? key
	}) : super(key: key);

	@override
	createState() => _BoardSwitcherPageState();
}

class _BoardSwitcherPageState extends State<BoardSwitcherPage> {
	late final FocusNode _focusNode;
	late List<Imageboard> allImageboards;
	int currentImageboardIndex = 0;
	Imageboard get currentImageboard => allImageboards[currentImageboardIndex];
	late List<ImageboardScoped<ImageboardBoard>> boards;
	static final typeaheads = <Imageboard, Trie<List<ImageboardBoard>>>{};
	static final typeaheadLoadings = <Imageboard, Set<String>>{};
	String searchString = '';
	late final ScrollController scrollController;
	late final ValueNotifier<Color?> _backgroundColor;
	int _pointersDownCount = 0;
	bool _popping = false;
	int _selectedIndex = 0;
	bool _showSelectedItem = isOnMac;
	late TextEditingController _textEditingController;
	late StreamSubscription<BoxEvent> _boardsBoxSubscription;
	final Map<ImageboardScoped<ImageboardBoard?>, BuildContext> _contexts = {};

	bool isPhoneSoftwareKeyboard() {
		return MediaQueryData.fromView(View.of(context)).viewInsets.bottom > 100;
	}

	void _fetchBoards() {
		if (widget.currentlyPickingFavourites) {
			boards = currentImageboard.persistence.boards.map(currentImageboard.scope).toList();
		}
		else {
			boards = [];
			for (final entry in Persistence.sharedBoardsBox.mapEntries) {
				if (entry.key is! String) {
					continue;
				}
				final key = entry.key as String;
				final slashIndex = key.indexOf('/');
				if (slashIndex == -1) {
					continue;
				}
				final imageboardKey = key.substring(0, slashIndex);
				final imageboard = ImageboardRegistry.instance.getImageboard(imageboardKey);
				if (imageboard == null) {
					continue;
				}
				boards.add(imageboard.scope(entry.value));
			}
			if (widget.allowPickingWholeSites) {
				for (final imageboard in allImageboards) {
					if (imageboard.site.supportsMultipleBoards) {
						boards.add(imageboard.scope(ImageboardBoard(
							name: '',
							title: imageboard.site.name,
							isWorksafe: false,
							webmAudioAllowed: false
						)));
					}
				}
			}
		}
	}

	@override
	void initState() {
		super.initState();
		scrollController = ScrollController();
		_backgroundColor = ValueNotifier<Color?>(null);
		_focusNode = FocusNode();
		allImageboards = ImageboardRegistry.instance.imageboards.where((i) => widget.filterImageboards?.call(i) ?? true).toList();
		currentImageboardIndex = allImageboards.indexOf(ImageboardRegistry.instance.getImageboard(widget.initialImageboardKey) ?? allImageboards.first);
		if (currentImageboardIndex == -1) {
			currentImageboardIndex = 0;
		}
		currentImageboard.refreshBoards();
		_fetchBoards();
		scrollController.addListener(_onScroll);
		if (Settings.instance.boardSwitcherHasKeyboardFocus) {
			Future.delayed(const Duration(milliseconds: 500), _checkForKeyboard);
		}
		ImageboardRegistry.instance.addListener(_onImageboardRegistryUpdate);
		_boardsBoxSubscription = Persistence.sharedBoardsBox.watch().listen(_onBoardsBoxUpdate);
		ScrollTracker.instance.slowScrollDirection.value = VerticalDirection.down;
		_textEditingController = TextEditingController();
	}

	void _onImageboardRegistryUpdate() {
		final newAllImageboards = ImageboardRegistry.instance.imageboards.where((i) => widget.filterImageboards?.call(i) ?? true).toList();
		currentImageboardIndex = max(0, newAllImageboards.indexOf(currentImageboard));
		allImageboards = newAllImageboards;
		_fetchBoards();
		setState(() {});
	}

	void _onBoardsBoxUpdate(BoxEvent _) {
		_fetchBoards();
		setState(() {});
	}

	void _checkForKeyboard() {
		if (!mounted) {
			return;
		}
		if (!_focusNode.hasFocus) {
			return;
		}
		_showSelectedItem = !isPhoneSoftwareKeyboard();
		setState(() {});
	}

	double _getOverscroll() {
		final overscrollTop = scrollController.position.minScrollExtent - scrollController.position.pixels;
		final overscrollBottom = scrollController.position.pixels - scrollController.position.maxScrollExtent;
		return max(overscrollTop, overscrollBottom);
	}

	void _onScroll() {
		if (_focusNode.hasFocus && isPhoneSoftwareKeyboard()) {
			_focusNode.unfocus();
		}
		_backgroundColor.value = context.read<SavedTheme>().backgroundColor.withOpacity(1.0 - max(0, _getOverscroll() / 50).clamp(0, 1));
	}

	Future<void> _updateTypeaheadBoards(String rawQuery) async {
		final query = rawQuery.toLowerCase();
		final typeaheadLoading = typeaheadLoadings[currentImageboard] ??= {};
		final typeahead = typeaheads[currentImageboard] ??= Trie();
		if (query.isEmpty || typeaheadLoading.contains(query) || typeahead.contains(query)) {
			return;
		}
		final imageboard = currentImageboard;
		typeaheadLoading.add(query);
		try {
			final newTypeaheadBoards = await imageboard.site.getBoardsForQuery(query);
			if (currentImageboard != imageboard) {
				// Site switched
				return;
			}
			typeahead.insert(query, newTypeaheadBoards);
			if (mounted) {
				setState(() {});
			}
		}
		catch (e, st) {
			Future.error(e, st);
		}
		finally {
			typeaheadLoading.remove(query);
		}
	}

	List<ImageboardScoped<ImageboardBoard>> getFilteredBoards() {
		final settings = Settings.instance;
		final normalized = searchString.toLowerCase();
		final matchingOtherImageboards = allImageboards.where((i) => i != currentImageboard && i.site.name.toLowerCase().contains(normalized)).toSet();
		final imageboards = allImageboards.toList();
		imageboards.remove(currentImageboard);
		imageboards.insert(0, currentImageboard);
		final favsList = imageboards.expand((i) => i.persistence.browserState.favouriteBoards.map(i.scope)).toList();
		final favsOrder = {
			for (final pair in favsList.asMap().entries)
				pair.value.imageboard.scope(pair.value.item): pair.key
		};
		final imageboardPriority = {
			for (final i in imageboards.asMap().entries)
				i.value: i.key
		};
		List<_Board> filteredBoards = boards.tryMap((board) {
			if (!settings.showBoard(board.item)) {
				return null;
			}
			final matchIndex = board.item.boardKey.s.indexOf(normalized);
			if (
				!(
					// Name match
					matchIndex != -1 ||
					// Title match
					(!board.imageboard.site.allowsArbitraryBoards && board.item.title.toLowerCase().contains(normalized)) ||
					// Site name match
					matchingOtherImageboards.contains(board.imageboard)
				)
			) {
				return null;
			}
			final favsIndex = favsOrder[board.imageboard.scope(board.item.boardKey)];
			if (widget.currentlyPickingFavourites && favsIndex != null) {
				return null;
			}
			if (!widget.currentlyPickingFavourites && settings.onlyShowFavouriteBoardsInSwitcher && favsIndex == null) {
				return null;
			}
			return _Board(board,
				typeaheadIndex: 0,
				matchIndex: matchIndex,
				favsIndex: favsIndex ?? favsOrder.length,
				imageboardPriorityIndex: imageboardPriority[board.imageboard] ?? imageboards.length
			);
		}).toList();
		if (normalized.isEmpty) {
			filteredBoards.sort((a, b) {
				final imageboardComparison = a.imageboardPriorityIndex - b.imageboardPriorityIndex;
				if (imageboardComparison != 0) {
					return imageboardComparison;
				}
				return a.favsIndex - b.favsIndex;
			});
			return filteredBoards.map((b) => b.imageboard.scope(b.item)).toList();
		}
		else {
			final existingNames = filteredBoards.map((b) => b.item.boardKey).toSet();
			final typeahead = typeaheads[currentImageboard] ??= Trie();
			for (final (depth, boards) in typeahead.descend(normalized)) {
				for (final board in boards) {
					if (existingNames.contains(board.boardKey)) {
						continue;
					}
					existingNames.add(board.boardKey);
					final matchIndex = board.boardKey.s.indexOf(normalized);
					if (matchIndex == -1/* && !board.title.toLowerCase().contains(normalized)*/) {
						// This drops all the "relevant" boards that don't actually match
						continue;
					}
					filteredBoards.add(_Board(currentImageboard.scope(board),
						typeaheadIndex: 1 + depth,
						matchIndex: matchIndex,
						// Don't treat it as a favourite
						favsIndex: favsOrder.length,
						imageboardPriorityIndex: 0 // currentImageboard
					));
				}
			}
			filteredBoards.sort((a, b) {
				final exactMatchA = a.matchIndex == 0 && a.item.boardKey.s.length == normalized.length && a.imageboard == currentImageboard && a.typeaheadIndex == 0;
				final exactMatchB = b.matchIndex == 0 && b.item.boardKey.s.length == normalized.length && b.imageboard == currentImageboard && b.typeaheadIndex == 0;
				if (exactMatchA && !exactMatchB) {
					return -1;
				}
				if (exactMatchB && !exactMatchA) {
					return 1;
				}
				// Only match favourites if it matches beginning of name
				final favA = a.matchIndex == 0 && a.favsIndex < favsOrder.length;
				final favB = b.matchIndex == 0 && b.favsIndex < favsOrder.length;
				if (favA && !favB) {
					return -1;
				}
				if (favB && !favA) {
					return 1;
				}
				// matchIndex = -1 means it matched based on title or site name
				if (a.matchIndex == -1 && b.matchIndex != -1) {
					return 1;
				}
				if (b.matchIndex == -1 && a.matchIndex != -1) {
					return -1;
				}
				final imageboardComparison = a.imageboardPriorityIndex - b.imageboardPriorityIndex;
				if (imageboardComparison != 0) {
					return imageboardComparison;
				}
				final typeaheadComparison = a.typeaheadIndex - b.typeaheadIndex;
				if (typeaheadComparison != 0) {
					return typeaheadComparison;
				}
				final matchComparison = a.matchIndex - b.matchIndex;
				if (matchComparison != 0) {
					return matchComparison;
				}
				return a.item.boardKey.s.compareTo(b.item.boardKey.s);
			});
			final ret = filteredBoards.map((b) => b.imageboard.scope(b.item)).toList();
			if (!settings.onlyShowFavouriteBoardsInSwitcher && currentImageboard.site.allowsArbitraryBoards) {
				final fakeBoard = ImageboardBoard(
					name: searchString,
					title: '',
					isWorksafe: false,
					webmAudioAllowed: true
				);
				if (ret.isEmpty) {
					return [currentImageboard.scope(fakeBoard)];
				}
				final exactMatchBoardIndex = filteredBoards.indexWhere(
					(b) => b.matchIndex == 0 && b.item.boardKey.s.length == normalized.length && b.imageboardPriorityIndex == 0);
				if (exactMatchBoardIndex == -1) {
					ret.insert(1, currentImageboard.scope(fakeBoard));
				}
				else if (exactMatchBoardIndex > 1) {
					final exactMatchBoard = ret.removeAt(exactMatchBoardIndex);
					ret.insert(1, exactMatchBoard);
				}
			}
			return ret;
		}
	}

	void _afterScroll() {
		if (!_popping && _pointersDownCount == 0) {
			if (_getOverscroll() > 50) {
				_popping = true;
				lightHapticFeedback();
				Navigator.pop(context);
			}
		}
	}

	Future<void> _pop(ImageboardScoped<ImageboardBoard> item) async {
		if (item.imageboard.persistence.maybeGetBoard(item.item.name) == null) {
			// In case it is found by typeahead or something
			await item.imageboard.persistence.setBoard(item.item.name, item.item);
		}
		if (mounted) {
			Navigator.pop(context, item);
		}
	}

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<Settings>();
		_backgroundColor.value ??= ChanceTheme.backgroundColorOf(context);
		final List<ImageboardScoped<ImageboardBoard?>> filteredBoards = getFilteredBoards().map((x) => x.nullify).toList();
		if (!widget.currentlyPickingFavourites) {
			// Add a dummy entry at the end to suggest switching to search
			filteredBoards.addAll(allImageboards.where((i) {
				return i != currentImageboard && i.site.allowsArbitraryBoards;
			}).map((i) => i.scope(null)));
		}
		final effectiveSelectedIndex = filteredBoards.isEmpty ? 0 : _selectedIndex.clamp(0, filteredBoards.length - 1);
		return AdaptiveScaffold(
			disableAutoBarHiding: true,
			resizeToAvoidBottomInset: false,
			backgroundColor: Colors.transparent,
			bar: AdaptiveBar(
				title: FractionallySizedBox(
					widthFactor: 0.75,
					child: CallbackShortcuts(
						bindings: {
							LogicalKeySet(LogicalKeyboardKey.arrowDown): () {
								if (effectiveSelectedIndex < filteredBoards.length - 1) {
									setState(() {
										_selectedIndex++;
									});
									final context = _contexts[filteredBoards[_selectedIndex]];
									if (context != null) {
										Scrollable.ensureVisible(context, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
									}
								}
							},
							LogicalKeySet(LogicalKeyboardKey.arrowUp): () {
								if (effectiveSelectedIndex > 0) {
									setState(() {
										_selectedIndex--;
									});
									final context = _contexts[filteredBoards[_selectedIndex]];
									if (context != null) {
										Scrollable.ensureVisible(context, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart);
									}
								}
							}
						},
						child: AdaptiveTextField(
							autofocus: settings.boardSwitcherHasKeyboardFocus,
							enableIMEPersonalizedLearning: settings.enableIMEPersonalizedLearning,
							smartDashesType: SmartDashesType.disabled,
							smartQuotesType: SmartQuotesType.disabled,
							autocorrect: false,
							placeholder: 'Board...',
							textAlign: TextAlign.center,
							focusNode: _focusNode,
							enableSuggestions: false,
							suffixMode: OverlayVisibilityMode.editing,
							controller: _textEditingController,
							suffix: Padding(
								padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 5, 2),
								child: AdaptiveIconButton(
									onPressed: () {
										_textEditingController.clear();
										_updateTypeaheadBoards('');
										setState(() {
											searchString = '';
										});
									},
									minSize: 0,
									padding: EdgeInsets.zero,
									icon: Icon(CupertinoIcons.xmark_circle_fill, size: MediaQuery.textScalerOf(context).scale(20))
								)
							),
							onTap: () {
								scrollController.jumpTo(scrollController.position.pixels);
								if (!_showSelectedItem) {
									Future.delayed(const Duration(milliseconds: 500), _checkForKeyboard);
								}
							},
							onSubmitted: (String board) {
								if (filteredBoards.isNotEmpty) {
									final selected = filteredBoards[effectiveSelectedIndex];
									if (selected.item != null) {
										lightHapticFeedback();
										_pop(selected.unnullify);
										return;
									}
									setState(() {
										currentImageboardIndex = allImageboards.indexOf(selected.imageboard);
									});
									_updateTypeaheadBoards(searchString);
								}
								_focusNode.requestFocus();
							},
							onChanged: (String newSearchString) {
								_updateTypeaheadBoards(newSearchString);
								setState(() {
									searchString = newSearchString;
								});
							}
						)
					)
				),
				actions: [
					if (!widget.currentlyPickingFavourites) AdaptiveIconButton(
						icon: const Icon(CupertinoIcons.gear),
						onPressed: () async {
							final theme = context.read<SavedTheme>();
							await showAdaptiveDialog(
								barrierDismissible: true,
								context: context,
								builder: (context) => AdaptiveAlertDialog(
									content: StatefulBuilder(
										builder: (context, setDialogState) => Column(
											mainAxisSize: MainAxisSize.min,
											crossAxisAlignment: CrossAxisAlignment.stretch,
											children: [
												Padding(
													padding: const EdgeInsets.symmetric(horizontal: 16),
													child: AdaptiveThinButton(
														padding: const EdgeInsets.all(8),
														child: const Center(
															child: Row(
																mainAxisSize: MainAxisSize.min,
																children: [
																	Icon(CupertinoIcons.star),
																	Text(' Edit Favorites')
																]
															)
														),
														onPressed: () => showAdaptiveDialog(
															barrierDismissible: true,
															context: context,
															builder: (context) => StatefulBuilder(
																builder: (context, setDialogState) => AdaptiveAlertDialog(
																	title: Padding(
																		padding: const EdgeInsets.only(bottom: 16),
																		child: Row(
																			mainAxisAlignment: MainAxisAlignment.center,
																			children: [
																				if (allImageboards.length > 1) Padding(
																					padding: const EdgeInsets.only(right: 8),
																					child: ImageboardIcon(
																						imageboardKey: currentImageboard.key,
																					)
																				),
																				const Flexible(
																					child: Text('Favourite boards')
																				)
																			]
																		)
																	),
																	content: SizedBox(
																		height: 300,
																		child: ReorderableList(
																			itemCount: currentImageboard.persistence.browserState.favouriteBoards.length,
																			onReorder: (oldIndex, newIndex) {
																				if (oldIndex < newIndex) {
																					newIndex -= 1;
																				}
																				final board = currentImageboard.persistence.browserState.favouriteBoards.removeAt(oldIndex);
																				currentImageboard.persistence.browserState.favouriteBoards.insert(newIndex, board);
																				setDialogState(() {});
																			},
																			itemBuilder: (context, i) => ReorderableDelayedDragStartListener(
																				index: i,
																				key: ValueKey(currentImageboard.persistence.browserState.favouriteBoards[i]),
																				child: Padding(
																					padding: const EdgeInsets.all(4),
																					child: Container(
																						decoration: BoxDecoration(
																							borderRadius: const BorderRadius.all(Radius.circular(4)),
																							color: theme.primaryColor.withOpacity(0.1)
																						),
																						padding: const EdgeInsets.only(left: 16),
																						child: Row(
																							children: [
																								Expanded(
																									child: AutoSizeText(
																										currentImageboard.site.formatBoardName(currentImageboard.persistence.browserState.favouriteBoards[i].s),
																										style: const TextStyle(fontSize: 20),
																										maxLines: 1
																									),
																								),
																								AdaptiveIconButton(
																									icon: const Icon(CupertinoIcons.delete),
																									onPressed: () {
																										currentImageboard.persistence.browserState.favouriteBoards.remove(currentImageboard.persistence.browserState.favouriteBoards[i]);
																										setDialogState(() {});
																									}
																								)
																							]
																						)
																					)
																				)
																			)
																		)
																	),
																	actions: [
																		AdaptiveDialogAction(
																			child: const Text('Add board'),
																			onPressed: () async {
																				final board = await Navigator.push<ImageboardScoped<ImageboardBoard>>(context, TransparentRoute(
																					builder: (ctx) => ImageboardScope(
																						imageboardKey: null,
																						imageboard: currentImageboard,
																						child: BoardSwitcherPage(currentlyPickingFavourites: true, initialImageboardKey: currentImageboard.key)
																					)
																				));
																				if (board != null && !currentImageboard.persistence.browserState.favouriteBoards.contains(board.item.boardKey)) {
																					currentImageboard.persistence.browserState.favouriteBoards.add(board.item.boardKey);
																					setDialogState(() {});
																				}
																			}
																		),
																		AdaptiveDialogAction(
																			child: const Text('Close'),
																			onPressed: () => Navigator.pop(context)
																		)
																	]
																)
															)
														)
													)
												),
												const SizedBox(height: 16),
												AdaptiveSegmentedControl<bool>(
													children: const {
														false: (null, 'All boards'),
														true: (null, 'Only favourites')
													},
													groupValue: settings.onlyShowFavouriteBoardsInSwitcher,
													onValueChanged: (setting) {
														Settings.onlyShowFavouriteBoardsInSwitcherSetting.value = setting;
														setDialogState(() {});
													}
												),
												const SizedBox(height: 16),
												AdaptiveSegmentedControl<bool>(
													children: const {
														false: (null, 'Grid'),
														true: (null, 'List')
													},
													groupValue: settings.useBoardSwitcherList,
													onValueChanged: (setting) {
														Settings.useBoardSwitcherListSetting.value = setting;
														setDialogState(() {});
													}
												),
												const SizedBox(height: 16),
												Row(
													children: [
														const Expanded(
															child: Text('Show keyboard when opening'),
														),
														const SizedBox(width: 8),
														AdaptiveSwitch(
															value: settings.boardSwitcherHasKeyboardFocus,
															onChanged: (v) {
																settings.boardSwitcherHasKeyboardFocus = v;
																setDialogState(() {});
															}
														)
													]
												)
											]
										)
									),
									actions: [
										AdaptiveDialogAction(
											child: const Text('Close'),
											onPressed: () => Navigator.pop(context)
										)
									]
								)
							);
							currentImageboard.persistence.didUpdateBrowserState();
							setState(() {});
						}
					)
				]
			),
			body: Listener(
				onPointerDown: (event) {
					_pointersDownCount++;
				},
				onPointerCancel: (event) {
					_pointersDownCount--;
				},
				onPointerUp: (event) {
					_pointersDownCount--;
					_afterScroll();
				},
				onPointerPanZoomStart: (event) {
					_pointersDownCount++;
				},
				onPointerPanZoomEnd: (event) {
					_pointersDownCount--;
					_afterScroll();
				},
				child: Stack(
					children: [
						ValueListenableBuilder<Color?>(
							valueListenable: _backgroundColor,
							builder: (context, color, child) => Container(
								color: color
							)
						),
						(filteredBoards.isEmpty) ? const Center(
							child: Text('No matching boards')
						) : Builder(
							builder: (context) => settings.useBoardSwitcherList ? ListView.separated(
								physics: const AlwaysScrollableScrollPhysics(),
								controller: scrollController,
								padding: const EdgeInsets.only(top: 4, bottom: 4) + MediaQuery.paddingOf(context),
								separatorBuilder: (context, i) => const SizedBox(height: 2),
								itemCount: filteredBoards.length,
								itemBuilder: (context, i) {
									final board = filteredBoards[i].item;
									final imageboard = filteredBoards[i].imageboard;
									final isSelected = _showSelectedItem && i == effectiveSelectedIndex;
									final Widget child;
									if (board != null) {
										child = ContextMenu(
											backgroundColor: Colors.transparent,
											actions: [
												if (imageboard.persistence.browserState.favouriteBoards.contains(board.boardKey)) ContextMenuAction(
													child: const Text('Unfavourite'),
													trailingIcon: CupertinoIcons.star,
													onPressed: () {
														imageboard.persistence.browserState.favouriteBoards.remove(board.boardKey);
														setState(() {});
													}
												)
												else ContextMenuAction(
													child: const Text('Favourite'),
													trailingIcon: CupertinoIcons.star_fill,
													onPressed: () {
														imageboard.persistence.browserState.favouriteBoards.add(board.boardKey);
														setState(() {});
													}
												),
												if (board.additionalDataTime != null) ContextMenuAction(
													child: const Text('Remove'),
													trailingIcon: CupertinoIcons.delete,
													onPressed: () {
														imageboard.persistence.removeBoard(board.name);
														_fetchBoards();
														setState(() {});
													}
												)
											],
											child: CupertinoButton(
												padding: EdgeInsets.zero,
												child: Container(
													padding: const EdgeInsets.all(4),
													height: 64,
													decoration: BoxDecoration(
														borderRadius: const BorderRadius.all(Radius.circular(4)),
														color: board.isWorksafe ? Colors.blue.withOpacity(isSelected ? 0.3 : 0.1) : Colors.red.withOpacity(isSelected ? 0.3 : 0.1)
													),
													child: Stack(
														fit: StackFit.expand,
														children: [
															Row(
																crossAxisAlignment: CrossAxisAlignment.center,
																children: [
																	const SizedBox(width: 16),
																	ImageboardIcon(
																		imageboardKey: imageboard.key,
																		boardName: board.name,
																		size: 24
																	),
																	const SizedBox(width: 16),
																	Expanded(
																		child: Column(
																			mainAxisSize: MainAxisSize.min,
																			crossAxisAlignment: CrossAxisAlignment.stretch,
																			children: [
																				AutoSizeText(
																					board.name.isNotEmpty ? imageboard.site.formatBoardName(board.name) : board.title,
																					maxFontSize: 20,
																					minFontSize: 13,
																					maxLines: 1,
																					textAlign: TextAlign.left,
																					overflow: TextOverflow.ellipsis,
																					style: isSelected ? CommonTextStyles.bold : null
																				),
																				if (board.name.isNotEmpty) AutoSizeText(
																					board.title,
																					maxFontSize: 15,
																					minFontSize: 13,
																					maxLines: 1,
																					textAlign: TextAlign.left,
																					overflow: TextOverflow.ellipsis
																				),
																			]
																		)
																	),
																	const SizedBox(width: 16)
																]
															),
															if (imageboard.persistence.browserState.favouriteBoards.contains(board.boardKey)) const Align(
																alignment: Alignment.topRight,
																child: Padding(
																	padding: EdgeInsets.only(top: 4, right: 4),
																	child: Icon(CupertinoIcons.star_fill, size: 15)
																)
															)
														]
													)
												),
												onPressed: () {
													lightHapticFeedback();
													_pop(imageboard.scope(board));
												}
											)
										);
									}
									else {
										child = CupertinoButton(
											padding: EdgeInsets.zero,
											child: Container(
												padding: const EdgeInsets.all(4),
												height: 64,
												decoration: BoxDecoration(
													borderRadius: const BorderRadius.all(Radius.circular(4)),
													color: Colors.red.withOpacity(isSelected ? 0.3 : 0.1)
												),
												child: Stack(
													fit: StackFit.expand,
													children: [
														Row(
															crossAxisAlignment: CrossAxisAlignment.center,
															children: [
																const SizedBox(width: 16),
																ImageboardIcon(
																	imageboardKey: imageboard.key
																),
																const SizedBox(width: 16),
																Flexible(
																	child: AutoSizeText(
																		'Search ${imageboard.site.name}',
																		maxFontSize: 20,
																		minFontSize: 15,
																		maxLines: 1,
																		textAlign: TextAlign.left,
																		overflow: TextOverflow.ellipsis,
																		style: isSelected ? CommonTextStyles.bold : null
																	)
																),
																const SizedBox(width: 16)
															]
														)
													]
												)
											),
											onPressed: () {
												setState(() {
													currentImageboardIndex = allImageboards.indexOf(imageboard);
												});
												_updateTypeaheadBoards(searchString);
											}
										);
									}
									return BuildContextMapRegistrant(
										map: _contexts,
										value: filteredBoards[i],
										child: child
									);
								}
							) : GridView.extent(
								physics: const AlwaysScrollableScrollPhysics(),
								controller: scrollController,
								padding: const EdgeInsets.only(top: 4, bottom: 4) + MediaQuery.paddingOf(context),
								maxCrossAxisExtent: 125,
								mainAxisSpacing: 4,
								childAspectRatio: 1.2,
								crossAxisSpacing: 4,
								children: filteredBoards.map((item) {
									final imageboard = item.imageboard;
									final board = item.item;
									final isSelected = _showSelectedItem && item == filteredBoards[effectiveSelectedIndex];
									final Widget child;
									if (board != null) {
										child = ContextMenu(
											backgroundColor: Colors.transparent,
											actions: [
												if (imageboard.persistence.browserState.favouriteBoards.contains(board.boardKey)) ContextMenuAction(
													child: const Text('Unfavourite'),
													trailingIcon: CupertinoIcons.star,
													onPressed: () {
														imageboard.persistence.browserState.favouriteBoards.remove(board.boardKey);
														setState(() {});
													}
												)
												else ContextMenuAction(
													child: const Text('Favourite'),
													trailingIcon: CupertinoIcons.star_fill,
													onPressed: () {
														imageboard.persistence.browserState.favouriteBoards.add(board.boardKey);
														setState(() {});
													}
												),
												if (board.additionalDataTime != null) ContextMenuAction(
													child: const Text('Remove'),
													trailingIcon: CupertinoIcons.delete,
													onPressed: () {
														imageboard.persistence.removeBoard(board.name);
														_fetchBoards();
														setState(() {});
													}
												)
											],
											child: CupertinoButton(
												padding: EdgeInsets.zero,
												child: Container(
													padding: const EdgeInsets.all(4),
													decoration: BoxDecoration(
														borderRadius: const BorderRadius.all(Radius.circular(4)),
														color: board.isWorksafe ? Colors.blue.withOpacity(isSelected ? 0.3 : 0.1) : Colors.red.withOpacity(isSelected ? 0.3 : 0.1)
													),
													child: Stack(
														children: [
															if (allImageboards.length > 1) Align(
																alignment: Alignment.topLeft,
																child: Padding(
																	padding: const EdgeInsets.only(top: 2, left: 2),
																	child: ImageboardIcon(
																		imageboardKey: imageboard.key,
																		boardName: board.name
																	)
																)
															),
															if (imageboard.persistence.browserState.favouriteBoards.contains(board.boardKey)) const Align(
																alignment: Alignment.topRight,
																child: Padding(
																	padding: EdgeInsets.only(top: 2, right: 2),
																	child: Icon(CupertinoIcons.star_fill, size: 15)
																)
															),
															Column(
																mainAxisAlignment: MainAxisAlignment.start,
																crossAxisAlignment: CrossAxisAlignment.center,
																children: [
																	const SizedBox(height: 20),
																	if (board.name.isNotEmpty) Flexible(
																		child: Center(
																			child: AutoSizeText(
																				imageboard.site.formatBoardName(board.name),
																				textAlign: TextAlign.center,
																				maxLines: 1,
																				minFontSize: 0,
																				style: isSelected ? CommonTextStyles.bold : null
																			)
																		)
																	),
																	if (board.title.isNotEmpty) Flexible(
																		child: Center(
																			child: AutoSizeText(
																				board.title,
																				maxFontSize: board.name.isNotEmpty ? 14 : double.infinity,
																				maxLines: 2,
																				textAlign: TextAlign.center,
																				overflow: TextOverflow.ellipsis
																			)
																		)
																	)
																]
															)
														]
													)
												),
												onPressed: () {
													lightHapticFeedback();
													_pop(item.unnullify);
												}
											)
										);
									}
									else {
										child = CupertinoButton(
											padding: EdgeInsets.zero,
											child: Container(
												padding: const EdgeInsets.all(4),
												decoration: BoxDecoration(
													borderRadius: const BorderRadius.all(Radius.circular(4)),
													color: Colors.red.withOpacity(isSelected ? 0.3 : 0.1)
												),
												child: Stack(
													children: [
														if (allImageboards.length > 1) Align(
															alignment: Alignment.topLeft,
															child: Padding(
																padding: const EdgeInsets.only(top: 2, left: 2),
																child: ImageboardIcon(
																	imageboardKey: imageboard.key
																)
															)
														),
														Column(
															mainAxisAlignment: MainAxisAlignment.start,
															crossAxisAlignment: CrossAxisAlignment.center,
															children: [
																const SizedBox(height: 20),
																if (imageboard.site.supportsMultipleBoards) Flexible(
																	child: AutoSizeText(
																		'Search ${imageboard.site.name}',
																		textAlign: TextAlign.center,
																		style: isSelected ? CommonTextStyles.bold : null
																	)
																)
															]
														)
													]
												)
											),
											onPressed: () {
												setState(() {
													currentImageboardIndex = allImageboards.indexOf(imageboard);
												});
												_updateTypeaheadBoards(searchString);
											}
										);
									}
									return BuildContextMapRegistrant(
										map: _contexts,
										value: item,
										child: child
									);
								}).toList()
							)
						),
						if (widget.currentlyPickingFavourites) Positioned.fill(
							child: Align(
								alignment: Alignment.bottomCenter,
								child: Builder(
									builder: (context) => Container(
										margin: MediaQuery.paddingOf(context),
										padding: const EdgeInsets.all(16),
										width: 300 * Settings.textScaleSetting.watch(context),
										child: Container(
											decoration: BoxDecoration(
												borderRadius: BorderRadius.circular(16),
												color: ChanceTheme.backgroundColorOf(context)
											),
											padding: const EdgeInsets.all(16),
											child: const Row(
												mainAxisAlignment: MainAxisAlignment.center,
												children: [
													Icon(CupertinoIcons.star_fill),
													SizedBox(width: 8),
													Flexible(
														child: AutoSizeText('Add favorite board', textAlign: TextAlign.center, maxLines: 1)
													)
												]
											)
										)
									)
								)
							)
						)
						else Positioned.fill(
							child: GestureDetector(
								behavior: HitTestBehavior.translucent,
								onHorizontalDragEnd: (details) {
									if (details.velocity.pixelsPerSecond.dx > 0 && currentImageboardIndex > 0) {
										setState(() {
											currentImageboardIndex--;
										});
									}
									else if (details.velocity.pixelsPerSecond.dx < 0 && currentImageboardIndex < allImageboards.length - 1) {
										setState(() {
											currentImageboardIndex++;
										});
									}
								},
								child: Align(
									alignment: Alignment.bottomCenter,
									child: Builder(
										builder: (context) => Container(
											margin: MediaQuery.paddingOf(context),
											padding: const EdgeInsets.all(16),
											width: 300 * Settings.textScaleSetting.watch(context),
											child: Container(
												decoration: BoxDecoration(
													borderRadius: BorderRadius.circular(16),
													color: ChanceTheme.backgroundColorOf(context)
												),
												padding: const EdgeInsets.all(16),
												child: Row(
													crossAxisAlignment: CrossAxisAlignment.center,
													children: [
														AdaptiveIconButton(
															minSize: 0,
															onPressed: (currentImageboardIndex == 0) ? null : () {
																setState(() {
																	currentImageboardIndex--;
																});
																currentImageboard.refreshBoards();
															},
															icon: const Icon(CupertinoIcons.chevron_left)
														),
														const SizedBox(width: 8),
														Expanded(
															child: Row(
																mainAxisAlignment: MainAxisAlignment.center,
																children: [
																	ImageboardIcon(imageboardKey: currentImageboard.key),
																	const SizedBox(width: 8),
																	Flexible(
																		child: AutoSizeText(currentImageboard.site.name, textAlign: TextAlign.center, maxLines: 1)
																	)
																]
															)
														),
														const SizedBox(width: 8),
														AdaptiveIconButton(
															minSize: 0,
															onPressed: (currentImageboardIndex + 1 >= allImageboards.length) ? null : () {
																setState(() {
																	currentImageboardIndex++;
																});
																currentImageboard.refreshBoards();
															},
															icon: const Icon(CupertinoIcons.chevron_right)
														)
													]
												)
											)
										)
									)
								)
							)
						)
					]
				)
			)
		);
	}

	@override
	void dispose() {
		super.dispose();
		scrollController.dispose();
		_backgroundColor.dispose();
		_focusNode.dispose();
		_textEditingController.dispose();
		ImageboardRegistry.instance.removeListener(_onImageboardRegistryUpdate);
		_boardsBoxSubscription.cancel();
	}
}
import 'dart:math';
import 'dart:ui';

import 'package:chan/models/board.dart';
import 'package:chan/services/apple.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/widgets/context_menu.dart';
import 'package:chan/widgets/cupertino_dialog.dart';
import 'package:chan/widgets/cupertino_switch2.dart';
import 'package:chan/widgets/cupertino_text_field2.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/util.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/services.dart';
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
	late final FocusNode _listenerFocusNode;
	late List<Imageboard> allImageboards;
	int currentImageboardIndex = 0;
	Imageboard get currentImageboard => allImageboards[currentImageboardIndex];
	late List<ImageboardScoped<ImageboardBoard>> boards;
	({String query, List<ImageboardScoped<ImageboardBoard>> results}) typeahead = const (query: '', results: []);
	String searchString = '';
	String? errorMessage;
	late final ScrollController scrollController;
	late final ValueNotifier<Color?> _backgroundColor;
	int _pointersDownCount = 0;
	bool _popping = false;
	int _selectedIndex = 0;
	bool _showSelectedItem = isOnMac;

	bool isPhoneSoftwareKeyboard() {
		return MediaQueryData.fromView(View.of(context)).viewInsets.bottom > 100;
	}

	void _fetchBoards() {
		if (widget.currentlyPickingFavourites) {
			boards = currentImageboard.persistence.boards.map(currentImageboard.scope).toList();
		}
		else {
			boards = allImageboards.expand((i) => i.persistence.boards.map(i.scope)).toList();
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
		boards.sort((a, b) => a.item.name.compareTo(b.item.name));
	}

	@override
	void initState() {
		super.initState();
		scrollController = ScrollController();
		_backgroundColor = ValueNotifier<Color?>(null);
		_focusNode = FocusNode();
		_listenerFocusNode = FocusNode();
		allImageboards = ImageboardRegistry.instance.imageboards.where((i) => widget.filterImageboards?.call(i) ?? true).toList();
		currentImageboardIndex = allImageboards.indexOf(ImageboardRegistry.instance.getImageboard(widget.initialImageboardKey ?? '____nothing') ?? allImageboards.first);
		if (currentImageboardIndex == -1) {
			currentImageboardIndex = 0;
		}
		currentImageboard.refreshBoards();
		_fetchBoards();
		scrollController.addListener(_onScroll);
		if (context.read<EffectiveSettings>().boardSwitcherHasKeyboardFocus) {
			Future.delayed(const Duration(milliseconds: 500), _checkForKeyboard);
		}
		ImageboardRegistry.instance.addListener(_onImageboardRegistryUpdate);
	}

	void _onImageboardRegistryUpdate() {
		final newAllImageboards = ImageboardRegistry.instance.imageboards.where((i) => widget.filterImageboards?.call(i) ?? true).toList();
		currentImageboardIndex = max(0, newAllImageboards.indexOf(currentImageboard));
		allImageboards = newAllImageboards;
		_fetchBoards();
		setState(() {});
	}

	void _checkForKeyboard() {
		if (!mounted) {
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
		_backgroundColor.value = ChanceTheme.backgroundColorOf(context).withOpacity(1.0 - max(0, _getOverscroll() / 50).clamp(0, 1));
	}

	Future<void> _updateTypeaheadBoards(String query) async {
		if (query.isEmpty) {
			setState(() {
				typeahead = const (query: '', results: []);
			});
			return;
		}
		final newTypeaheadBoards = await currentImageboard.site.getBoardsForQuery(query);
		if (mounted && searchString.indexOf(query) == 0 && query.length > typeahead.query.length) {
			setState(() {
				typeahead = (query: query, results: newTypeaheadBoards.map(currentImageboard.scope).toList());
			});
		}
	}

	List<ImageboardScoped<ImageboardBoard>> getFilteredBoards() {
		final settings = context.read<EffectiveSettings>();
		final normalized = searchString.toLowerCase();
		List<ImageboardScoped<ImageboardBoard>> filteredBoards = boards.where((board) {
			return
				settings.showBoard(board.item) &&
				(board.item.name.toLowerCase().contains(normalized) ||
				 board.item.title.toLowerCase().contains(normalized));
		}).toList();
		if (searchString.isNotEmpty) {
			mergeSort<ImageboardScoped<ImageboardBoard>>(filteredBoards, compare: (a, b) {
				return a.item.name.length - b.item.name.length;
			});
		}
		mergeSort<ImageboardScoped<ImageboardBoard>>(filteredBoards, compare: (a, b) {
			return a.item.name.toLowerCase().indexOf(normalized) - b.item.name.toLowerCase().indexOf(normalized);
		});
		mergeSort<ImageboardScoped<ImageboardBoard>>(filteredBoards, compare: (a, b) {
			return (b.item.name.toLowerCase().contains(normalized) ? 1 : 0) - (a.item.name.contains(normalized) ? 1 : 0);
		});
		final imageboards = allImageboards.toList();
		imageboards.remove(currentImageboard);
		imageboards.insert(0, currentImageboard);
		if (searchString.isEmpty) {
			final favsList = imageboards.expand((i) => i.persistence.browserState.favouriteBoards.map(i.scope)).toList();
			if (widget.currentlyPickingFavourites) {
				filteredBoards.removeWhere((b) => favsList.any((f) => f.imageboard == b.imageboard && f.item == b.item.name));
			}
			else {
				final favs = {
					for (final pair in favsList.asMap().entries)
						pair.value: pair.key
				};
				mergeSort<ImageboardScoped<ImageboardBoard>>(filteredBoards, compare: (a, b) {
					return (favs[a.imageboard.scope(a.item.name)] ?? favs.length) - (favs[b.imageboard.scope(b.item.name)] ?? favs.length);
				});
			}
		}
		final imageboardPriority = {
			for (final i in imageboards.asMap().entries)
				i.value: i.key
		};
		mergeSort<ImageboardScoped<ImageboardBoard>>(filteredBoards, compare: (a, b) {
			return (imageboardPriority[a.imageboard] ?? imageboards.length) - (imageboardPriority[b.imageboard] ?? imageboards.length);
		});
		if (searchString.isNotEmpty) {
			for (final board in typeahead.results) {
				if (!filteredBoards.any((b) => b.item.name == board.item.name && b.imageboard == currentImageboard)) {
					filteredBoards.add(board);
				}
			}
		}
		if (settings.onlyShowFavouriteBoardsInSwitcher) {
			final favs = imageboards.expand((i) => i.persistence.browserState.favouriteBoards.map(i.scope)).toList();
			filteredBoards = filteredBoards.where((b) => favs.any((f) => f.imageboard == b.imageboard && f.item == b.item.name)).toList();
		}
		mergeSort<ImageboardScoped<ImageboardBoard>>(filteredBoards, compare: (a, b) {
			return ((b.item.name.isEmpty ? b.item.title : b.item.name).toLowerCase().startsWith(normalized) ? 1 : 0) - ((a.item.name.isEmpty ? a.item.title : a.item.name).startsWith(normalized) ? 1 : 0);
		});
		if (searchString.isNotEmpty && !settings.onlyShowFavouriteBoardsInSwitcher) {
			if (currentImageboard.site.allowsArbitraryBoards) {
				final fakeBoard = ImageboardBoard(
					name: searchString,
					title: '',
					isWorksafe: false,
					webmAudioAllowed: true
				);
				if (filteredBoards.isEmpty) {
					filteredBoards.add(currentImageboard.scope(fakeBoard));
				}
				else if (!filteredBoards.any((b) => b.item.name == searchString && b.imageboard == currentImageboard)) {
					filteredBoards.insert(1, currentImageboard.scope(fakeBoard));
				}
			}
		}
		return filteredBoards;
	}

	void _afterScroll() {
		if (!_popping && _pointersDownCount == 0) {
			if (_getOverscroll() > 50) {
				_popping = true;
				Navigator.pop(context);
			}
		}
	}

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<EffectiveSettings>();
		_backgroundColor.value ??= ChanceTheme.backgroundColorOf(context);
		final List<ImageboardScoped<ImageboardBoard?>> filteredBoards = getFilteredBoards().map((x) => x.nullify).toList();
		filteredBoards.addAll(allImageboards.where((i) {
			return i != currentImageboard && i.site.allowsArbitraryBoards;
		}).map((i) => i.scope(null)));
		final effectiveSelectedIndex = min(_selectedIndex, filteredBoards.length - 1);
		return Stack(
			children: [
				CupertinoPageScaffold(
					resizeToAvoidBottomInset: false,
					backgroundColor: Colors.transparent,
					navigationBar: CupertinoNavigationBar(
						transitionBetweenRoutes: false,
						middle: LayoutBuilder(
							builder: (context, box) {
								return SizedBox(
									width: box.maxWidth * 0.75,
									child: KeyboardListener(
										focusNode: _listenerFocusNode,
										onKeyEvent: (e) {
											if (e is! KeyDownEvent) {
												return;
											}
											switch (e.logicalKey) {
												case LogicalKeyboardKey.arrowDown:
													if (effectiveSelectedIndex < filteredBoards.length - 1) {
														setState(() {
															_selectedIndex++;
														});
													}
													break;
												case LogicalKeyboardKey.arrowUp:
												if (effectiveSelectedIndex > 0) {
													setState(() {
														_selectedIndex--;
													});
												}
												break;
											}
										},
										child: CupertinoTextField2(
											autofocus: settings.boardSwitcherHasKeyboardFocus,
											enableIMEPersonalizedLearning: settings.enableIMEPersonalizedLearning,
											smartDashesType: SmartDashesType.disabled,
											smartQuotesType: SmartQuotesType.disabled,
											autocorrect: false,
											placeholder: 'Board...',
											textAlign: TextAlign.center,
											focusNode: _focusNode,
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
														Navigator.of(context).pop(selected.unnullify);
														return;
													}
													setState(() {
														currentImageboardIndex = allImageboards.indexOf(selected.imageboard);
													});
													typeahead = const (query: '', results: []);
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
								);
							}
						),
						trailing: widget.currentlyPickingFavourites ? null : CupertinoButton(
							padding: EdgeInsets.zero,
							child: const Icon(CupertinoIcons.gear),
							onPressed: () async {
								await showCupertinoDialog(
									barrierDismissible: true,
									context: context,
									builder: (context) => CupertinoAlertDialog2(
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
										content: StatefulBuilder(
											builder: (context, setDialogState) => SizedBox(
												width: 100,
												height: 350,
												child: Stack(
													children: [
														ReorderableList(
															padding: const EdgeInsets.only(bottom: 128),
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
																			color: ChanceTheme.primaryColorOf(context).withOpacity(0.1)
																		),
																		padding: const EdgeInsets.only(left: 16),
																		child: Row(
																			children: [
																				Expanded(
																					child: AutoSizeText(
																						currentImageboard.site.formatBoardName(currentImageboard.persistence.getBoard(currentImageboard.persistence.browserState.favouriteBoards[i])),
																						style: const TextStyle(fontSize: 20),
																						maxLines: 1
																					),
																				),
																				CupertinoButton(
																					child: const Icon(CupertinoIcons.delete),
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
														),
														Align(
															alignment: Alignment.bottomCenter,
															child: ClipRect(
																child: BackdropFilter(
																	filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
																		child: Container(
																		color: ChanceTheme.backgroundColorOf(context).withOpacity(0.1),
																		child: Column(
																			mainAxisSize: MainAxisSize.min,
																			crossAxisAlignment: CrossAxisAlignment.stretch,
																			children: [
																				CupertinoButton(
																					child: const Row(
																						mainAxisAlignment: MainAxisAlignment.center,
																						children: [
																							Icon(CupertinoIcons.add),
																							Text(' Add board')
																						]
																					),
																					onPressed: () async {
																						final board = await Navigator.push<ImageboardScoped<ImageboardBoard>>(context, TransparentRoute(
																							builder: (ctx) => ImageboardScope(
																								imageboardKey: null,
																								imageboard: currentImageboard,
																								child: const BoardSwitcherPage(currentlyPickingFavourites: true)
																							)
																						));
																						if (board != null && !currentImageboard.persistence.browserState.favouriteBoards.contains(board.item.name)) {
																							currentImageboard.persistence.browserState.favouriteBoards.add(board.item.name);
																							setDialogState(() {});
																						}
																					}
																				),
																				CupertinoSegmentedControl<bool>(
																					children: const {
																						false: Padding(
																							padding: EdgeInsets.all(8),
																							child: Text('All boards', textAlign: TextAlign.center)
																						),
																						true: Padding(
																							padding: EdgeInsets.all(8),
																							child: Text('Only favourites', textAlign: TextAlign.center)
																						)
																					},
																					groupValue: settings.onlyShowFavouriteBoardsInSwitcher,
																					onValueChanged: (setting) {
																						settings.onlyShowFavouriteBoardsInSwitcher = setting;
																					}
																				),
																				const SizedBox(height: 8),
																				CupertinoSegmentedControl<bool>(
																					children: const {
																						false: Text('Grid'),
																						true: Text('List')
																					},
																					groupValue: settings.useBoardSwitcherList,
																					onValueChanged: (setting) {
																						settings.useBoardSwitcherList = setting;
																					}
																				),
																				const SizedBox(height: 8),
																				Row(
																					children: [
																						const Expanded(
																							child: Text('Show keyboard when opening'),
																						),
																						const SizedBox(width: 8),
																						CupertinoSwitch2(
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
																	)
																)
															)
														)
													]
												)
											)
										),
										actions: [
											CupertinoDialogAction2(
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
					),
					child: Listener(
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
								) : SafeArea(
									child: settings.useBoardSwitcherList ? ListView.separated(
										physics: const AlwaysScrollableScrollPhysics(),
										controller: scrollController,
										padding: const EdgeInsets.only(top: 4, bottom: 4),
										separatorBuilder: (context, i) => const SizedBox(height: 2),
										itemCount: filteredBoards.length,
										itemBuilder: (context, i) {
											final board = filteredBoards[i].item;
											final imageboard = filteredBoards[i].imageboard;
											final isSelected = _showSelectedItem && i == effectiveSelectedIndex;
											if (board != null) {
												return ContextMenu(
													actions: [
														if (currentImageboard.persistence.browserState.favouriteBoards.contains(board.name)) ContextMenuAction(
															child: const Text('Unfavourite'),
															trailingIcon: CupertinoIcons.star,
															onPressed: () {
																currentImageboard.persistence.browserState.favouriteBoards.remove(board.name);
																setState(() {});
															}
														)
														else ContextMenuAction(
															child: const Text('Favourite'),
															trailingIcon: CupertinoIcons.star_fill,
															onPressed: () {
																currentImageboard.persistence.browserState.favouriteBoards.add(board.name);
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
																				imageboardKey: imageboard.key
																			),
																			const SizedBox(width: 16),
																			if (board.icon != null) ...[
																				ClipOval(
																					child: SizedBox(
																						width: 30,
																						height: 30,
																						child: FittedBox(
																							fit: BoxFit.contain,
																							child: ExtendedImage.network(board.icon!.toString())
																						)
																					)
																				),
																				const SizedBox(width: 16)
																			],
																			Expanded(
																				child: Column(
																					mainAxisSize: MainAxisSize.min,
																					crossAxisAlignment: CrossAxisAlignment.stretch,
																					children: [
																						AutoSizeText(
																							board.name.isNotEmpty ? imageboard.site.formatBoardName(board) : board.title,
																							maxFontSize: 20,
																							minFontSize: 13,
																							maxLines: 1,
																							textAlign: TextAlign.left,
																							overflow: TextOverflow.ellipsis,
																							style: TextStyle(
																								fontWeight: isSelected ? FontWeight.bold : null
																							)
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
																	if (imageboard.persistence.browserState.favouriteBoards.contains(board.name)) const Align(
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
															Navigator.of(context).pop(imageboard.scope(board));
														}
													)
												);
											}
											else {
												return CupertinoButton(
													padding: EdgeInsets.zero,
													child: Container(
														padding: const EdgeInsets.all(4),
														height: 64,
														decoration: BoxDecoration(
															borderRadius: const BorderRadius.all(Radius.circular(4)),
															color: Colors.red.withOpacity(0.1)
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
																				overflow: TextOverflow.ellipsis
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
														typeahead = const (query: '', results: []);
														_updateTypeaheadBoards(searchString);
													}
												);
											}
										}
									) : GridView.extent(
										physics: const AlwaysScrollableScrollPhysics(),
										controller: scrollController,
										padding: const EdgeInsets.only(top: 4, bottom: 4),
										maxCrossAxisExtent: 125,
										mainAxisSpacing: 4,
										childAspectRatio: 1.2,
										crossAxisSpacing: 4,
										children: filteredBoards.map((item) {
											final imageboard = item.imageboard;
											final board = item.item;
											final isSelected = _showSelectedItem && item == filteredBoards[effectiveSelectedIndex];
											if (board != null) {
												return ContextMenu(
													actions: [
														if (currentImageboard.persistence.browserState.favouriteBoards.contains(board.name)) ContextMenuAction(
															child: const Text('Unfavourite'),
															trailingIcon: CupertinoIcons.star,
															onPressed: () {
																currentImageboard.persistence.browserState.favouriteBoards.remove(board.name);
																setState(() {});
															}
														)
														else ContextMenuAction(
															child: const Text('Favourite'),
															trailingIcon: CupertinoIcons.star_fill,
															onPressed: () {
																currentImageboard.persistence.browserState.favouriteBoards.add(board.name);
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
																	if (imageboard.persistence.browserState.favouriteBoards.contains(board.name)) const Align(
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
																						imageboard.site.formatBoardName(board),
																						textAlign: TextAlign.center,
																						maxLines: 1,
																						minFontSize: 0,
																						style: TextStyle(
																							fontSize: 24,
																							fontWeight: isSelected ? FontWeight.bold : null
																						)
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
															Navigator.of(context).pop(item.unnullify);
														}
													)
												);
											}
											return CupertinoButton(
												padding: EdgeInsets.zero,
												child: Container(
													padding: const EdgeInsets.all(4),
													decoration: BoxDecoration(
														borderRadius: const BorderRadius.all(Radius.circular(4)),
														color: Colors.red.withOpacity(0.1)
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
																			style: const TextStyle(
																				fontSize: 24
																			)
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
													typeahead = const (query: '', results: []);
													_updateTypeaheadBoards(searchString);
												}
											);
										}).toList()
									)
								)
							]
						)
					)
				),
				Positioned.fill(
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
							child: Container(
								padding: const EdgeInsets.all(16),
								width: 300 * context.select<EffectiveSettings, double>((s) => s.textScale),
								child: Container(
									decoration: BoxDecoration(
										borderRadius: BorderRadius.circular(16),
										color: ChanceTheme.backgroundColorOf(context)
									),
									padding: const EdgeInsets.all(16),
									child: Row(
										crossAxisAlignment: CrossAxisAlignment.center,
										children: [
											CupertinoButton(
												padding: EdgeInsets.zero,
												minSize: 0,
												onPressed: (currentImageboardIndex == 0) ? null : () {
													setState(() {
														currentImageboardIndex--;
													});
													currentImageboard.refreshBoards();
												},
												child: const Icon(CupertinoIcons.chevron_left)
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
											CupertinoButton(
												padding: EdgeInsets.zero,
												minSize: 0,
												onPressed: (currentImageboardIndex + 1 >= allImageboards.length) ? null : () {
													setState(() {
														currentImageboardIndex++;
													});
													currentImageboard.refreshBoards();
												},
												child: const Icon(CupertinoIcons.chevron_right)
											)
										]
									)
								)
							)
						)
					)
				)
			]
		);
	}

	@override
	void dispose() {
		super.dispose();
		scrollController.dispose();
		_backgroundColor.dispose();
		_focusNode.dispose();
		ImageboardRegistry.instance.removeListener(_onImageboardRegistryUpdate);
	}
}
import 'dart:math';
import 'dart:ui';

import 'package:chan/models/board.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:provider/provider.dart';

class BoardSwitcherPage extends StatefulWidget {
	final bool currentlyPickingFavourites;
	const BoardSwitcherPage({
		this.currentlyPickingFavourites = false,
		Key? key
	}) : super(key: key);

	@override
	createState() => _BoardSwitcherPageState();
}

class _BoardSwitcherPageState extends State<BoardSwitcherPage> {
	final _focusNode = FocusNode();
	late List<ImageboardBoard> boards;
	late List<ImageboardBoard> _filteredBoards;
	String? errorMessage;
	final scrollController = ScrollController();
	final _backgroundColor = ValueNotifier<Color?>(null);
	int _pointersDownCount = 0;
	bool _popping = false;

	@override
	void initState() {
		super.initState();
		boards = context.read<Persistence>().boards.values.toList();
		scrollController.addListener(_onScroll);
		final settings = context.read<EffectiveSettings>();
		context.read<ImageboardSite>().getBoards().then((freshBoards) => setState(() {
			boards = freshBoards;
			_filteredBoards = freshBoards.where((b) => settings.showBoard(context, b.name)).toList();
			_sortByFavourite();
		}));
		_filteredBoards = boards.where((b) => settings.showBoard(context, b.name)).toList();
		_sortByFavourite();
	}

	double _getOverscroll() {
		final overscrollTop = scrollController.position.minScrollExtent - scrollController.position.pixels;
		final overscrollBottom = scrollController.position.pixels - scrollController.position.maxScrollExtent;
		return max(overscrollTop, overscrollBottom);
	}

	void _onScroll() {
		if (_focusNode.hasFocus) {
			_focusNode.unfocus();
		}
		_backgroundColor.value = CupertinoTheme.of(context).scaffoldBackgroundColor.withOpacity(1.0 - max(0, _getOverscroll() / 50).clamp(0, 1));
	}

	void _sortByFavourite() {
		final favsList = context.read<Persistence>().browserState.favouriteBoards;
		if (widget.currentlyPickingFavourites) {
			_filteredBoards.removeWhere((b) => favsList.contains(b.name));
		}
		else {
			final favs = {
				for (final pair in favsList.asMap().entries)
					pair.value: pair.key
			};
			mergeSort<ImageboardBoard>(_filteredBoards, compare: (a, b) {
				return (favs[a.name] ?? favs.length) - (favs[b.name] ?? favs.length);
			});
		}
	}

	@override
	Widget build(BuildContext context) {
		_backgroundColor.value ??= CupertinoTheme.of(context).scaffoldBackgroundColor;
		final browserState = context.watch<Persistence>().browserState;
		return CupertinoPageScaffold(
			resizeToAvoidBottomInset: false,
			backgroundColor: Colors.transparent,
			navigationBar: CupertinoNavigationBar(
				transitionBetweenRoutes: false,
				middle: LayoutBuilder(
					builder: (context, box) {
						return SizedBox(
							width: box.maxWidth * 0.75,
							child: CupertinoTextField(
								autofocus: context.read<EffectiveSettings>().boardSwitcherHasKeyboardFocus,
								autocorrect: false,
								placeholder: 'Board...',
								textAlign: TextAlign.center,
								focusNode: _focusNode,
								onTap: () {
									context.read<EffectiveSettings>().boardSwitcherHasKeyboardFocus = true;
								},
								onSubmitted: (String board) {
									if (_filteredBoards.isNotEmpty) {
										Navigator.of(context).pop(_filteredBoards.first);
									}
									else {
										_focusNode.requestFocus();
									}
								},
								onChanged: (String searchString) {
									_filteredBoards = boards.where((board) {
										return board.name.toLowerCase().contains(searchString) || board.title.toLowerCase().contains(searchString);
									}).toList();
									mergeSort<ImageboardBoard>(_filteredBoards, compare: (a, b) {
										return a.name.length - b.name.length;
									});
									mergeSort<ImageboardBoard>(_filteredBoards, compare: (a, b) {
										return a.name.indexOf(searchString) - b.name.indexOf(searchString);
									});
									mergeSort<ImageboardBoard>(_filteredBoards, compare: (a, b) {
										return (b.name.contains(searchString) ? 1 : 0) - (a.name.contains(searchString) ? 1 : 0);
									});
									if (searchString.isEmpty) {
										_sortByFavourite();
									}
									final settings = context.read<EffectiveSettings>();
									_filteredBoards = _filteredBoards.where((b) => settings.showBoard(context, b.name)).toList();
									setState(() {});
								}
							)
						);
					}
				),
				trailing: widget.currentlyPickingFavourites ? null : CupertinoButton(
					padding: EdgeInsets.zero,
					child: browserState.favouriteBoards.isEmpty ? const Icon(CupertinoIcons.star) : const Icon(CupertinoIcons.star_fill),
					onPressed: () async {
						await showCupertinoDialog(
							barrierDismissible: true,
							context: context,
							builder: (context) => CupertinoAlertDialog(
								title: const Padding(
									padding: EdgeInsets.only(bottom: 16),
									child: Text('Favourite boards')
								),
								content: StatefulBuilder(
									builder: (context, setDialogState) => SizedBox(
										width: 100,
										height: 350,
										child: Stack(
											children: [
												ReorderableList(
													padding: const EdgeInsets.only(bottom: 64),
													itemCount: browserState.favouriteBoards.length,
													onReorder: (oldIndex, newIndex) {
														if (oldIndex < newIndex) {
															newIndex -= 1;
														}
														final board = browserState.favouriteBoards.removeAt(oldIndex);
														browserState.favouriteBoards.insert(newIndex, board);
														setDialogState(() {});
													},
													itemBuilder: (context, i) => ReorderableDelayedDragStartListener(
														index: i,
														key: ValueKey(browserState.favouriteBoards[i]),
														child: Padding(
															padding: const EdgeInsets.all(4),
															child: Container(
																decoration: BoxDecoration(
																	borderRadius: const BorderRadius.all(Radius.circular(4)),
																	color: CupertinoTheme.of(context).primaryColor.withOpacity(0.1)
																),
																padding: const EdgeInsets.only(left: 16),
																child: Row(
																	children: [
																		Text('/${browserState.favouriteBoards[i]}/', style: const TextStyle(fontSize: 20)),
																		const Spacer(),
																		CupertinoButton(
																			child: const Icon(CupertinoIcons.delete),
																			onPressed: () {
																				browserState.favouriteBoards.remove(browserState.favouriteBoards[i]);
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
																color: CupertinoTheme.of(context).scaffoldBackgroundColor.withOpacity(0.1),
																child: CupertinoButton(
																	child: Row(
																		mainAxisAlignment: MainAxisAlignment.center,
																		children: const [
																			Icon(CupertinoIcons.add),
																			Text(' Add board')
																		]
																	),
																	onPressed: () async {
																		final board = await Navigator.push<ImageboardBoard>(context, TransparentRoute(
																			builder: (context) => const BoardSwitcherPage(currentlyPickingFavourites: true)
																		));
																		if (board != null && !browserState.favouriteBoards.contains(board.name)) {
																			browserState.favouriteBoards.add(board.name);
																			setDialogState(() {});
																		}
																	}
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
									CupertinoDialogAction(
										child: const Text('Close'),
										onPressed: () => Navigator.pop(context)
									)
								]
							)
						);
						context.read<Persistence>().didUpdateBrowserState();
						_sortByFavourite();
						setState(() {});
					}
				)
			),
			child: Listener(
				onPointerDown: (event) {
					_pointersDownCount++;
				},
				onPointerUp: (event) {
					_pointersDownCount--;
					if (!_popping && _pointersDownCount == 0) {
						if (_getOverscroll() > 50) {
							_popping = true;
							Navigator.pop(context);
						}
						else {
							context.read<EffectiveSettings>().boardSwitcherHasKeyboardFocus = false;
						}
					}
				},
				child: Stack(
					children: [
						ValueListenableBuilder<Color?>(
							valueListenable: _backgroundColor,
							builder: (context, color, child) => Container(
								color: color
							)
						),
						(_filteredBoards.isEmpty) ? const Center(
							child: Text('No matching boards')
						) : SafeArea(
							child: GridView.extent(
								physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
								controller: scrollController,
								padding: const EdgeInsets.only(top: 4, bottom: 4),
								maxCrossAxisExtent: 125,
								mainAxisSpacing: 4,
								childAspectRatio: 1.2,
								crossAxisSpacing: 4,
								children: _filteredBoards.map((board) {
									return GestureDetector(
										child: Container(
											padding: const EdgeInsets.all(4),
											decoration: BoxDecoration(
												borderRadius: const BorderRadius.all(Radius.circular(4)),
												color: board.isWorksafe ? Colors.blue.withOpacity(0.1) : Colors.red.withOpacity(0.1)
											),
											child: Stack(
												children: [
													Column(
														mainAxisAlignment: MainAxisAlignment.start,
														crossAxisAlignment: CrossAxisAlignment.center,
														children: [
															Flexible(
																child: Center(
																	child: Text(
																		'/${board.name}/',
																		style: const TextStyle(
																			fontSize: 24
																		)
																	)
																)
															),
															const SizedBox(height: 8),
															Flexible(
																child: Center(
																	child: AutoSizeText(board.title, maxFontSize: 14, maxLines: 2, textAlign: TextAlign.center)
																)
															)
														]
													),
													if (browserState.favouriteBoards.contains(board.name)) const Align(
														alignment: Alignment.topRight,
														child: Padding(
															padding: EdgeInsets.only(top: 4, right: 4),
															child: Icon(CupertinoIcons.star_fill, size: 15)
														)
													)
												]
											)
										),
										onTap: () {
											Navigator.of(context).pop(board);
										}
									);
								}).toList()
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
	}
}
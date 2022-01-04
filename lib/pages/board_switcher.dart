import 'package:chan/models/board.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:provider/provider.dart';

class BoardSwitcherPage extends StatefulWidget {
	const BoardSwitcherPage({Key? key}) : super(key: key);

	@override
	createState() => _BoardSwitcherPageState();
}

class _BoardSwitcherPageState extends State<BoardSwitcherPage> {
	final _focusNode = FocusNode();
	late List<ImageboardBoard> boards;
	late List<ImageboardBoard> _filteredBoards;
	String? errorMessage;

	@override
	void initState() {
		super.initState();
		boards = context.read<Persistence>().boardBox.toMap().values.toList();
		context.read<ImageboardSite>().getBoards().then((b) => setState(() {
			boards = b;
			_filteredBoards = b;
		}));
		final settings = context.read<EffectiveSettings>();
		_filteredBoards = boards.where((b) => settings.showBoard(context, b.name)).toList();
	}

	@override
	Widget build(BuildContext context) {
		return CupertinoPageScaffold(
			resizeToAvoidBottomInset: false,
			navigationBar: CupertinoNavigationBar(
				transitionBetweenRoutes: false,
				middle: LayoutBuilder(
					builder: (context, box) {
						return SizedBox(
							width: box.maxWidth * 0.75,
							child: CupertinoTextField(
								autofocus: true,
								autocorrect: false,
								placeholder: 'Board...',
								textAlign: TextAlign.center,
								focusNode: _focusNode,
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
									final settings = context.read<EffectiveSettings>();
									_filteredBoards = _filteredBoards.where((b) => settings.showBoard(context, b.name)).toList();
									setState(() {});
								}
							)
						);
					}
				)
			),
			child: (_filteredBoards.isEmpty) ? const Center(
				child: Text('No matching boards')
			) : SafeArea(
				child: GridView.extent(
					padding: const EdgeInsets.only(top: 4, bottom: 4),
					maxCrossAxisExtent: 125,
					mainAxisSpacing: 4,
					childAspectRatio: 1.2,
					crossAxisSpacing: 4,
					shrinkWrap: true,
					children: _filteredBoards.map((board) {
						return GestureDetector(
							child: Container(
								padding: const EdgeInsets.all(4),
								decoration: BoxDecoration(
									borderRadius: const BorderRadius.all(Radius.circular(4)),
									color: board.isWorksafe ? Colors.blue.withOpacity(0.1) : Colors.red.withOpacity(0.1)
								),
								child: Column(
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
								)
							),
							onTap: () {
								Navigator.of(context).pop(board);
							}
						);
					}).toList()
				)
			)
		);
	}
}
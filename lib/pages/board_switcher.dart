import 'package:chan/models/board.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:auto_size_text/auto_size_text.dart';

class BoardSwitcherPage extends StatefulWidget {
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
		boards = Persistence.boardBox.toMap().values.toList();
		_filteredBoards = boards;
	}

	@override
	Widget build(BuildContext context) {
		return CupertinoPageScaffold(
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
									setState(() {});
								}
							)
						);
					}
				)
			),
			child: (_filteredBoards.isEmpty) ? Center(
				child: Text('No matching boards')
			) : SafeArea(
				child: GridView.count(
					padding: EdgeInsets.only(top: 4, bottom: 4),
					crossAxisCount: context.watch<EffectiveSettings>().useTouchLayout ? 3 : 1,
					childAspectRatio: context.watch<EffectiveSettings>().useTouchLayout ? 1.7 : 2.5,
					mainAxisSpacing: 4,
					crossAxisSpacing: 4,
					shrinkWrap: true,
					children: _filteredBoards.map((board) {
						return GestureDetector(
							child: Container(
								padding: EdgeInsets.all(8),
								decoration: BoxDecoration(
									borderRadius: BorderRadius.all(Radius.circular(4)),
									color: board.isWorksafe ? Colors.blue.withOpacity(0.1) : Colors.red.withOpacity(0.1)
								),
								child: Column(
									mainAxisAlignment: MainAxisAlignment.center,
									crossAxisAlignment: CrossAxisAlignment.center,
									children: [
										Text(
											'/${board.name}/',
											style: TextStyle(
												fontSize: 24
											)
										),
										SizedBox(height: 8),
										AutoSizeText('${board.title}', maxLines: 1)
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
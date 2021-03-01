import 'package:chan/sites/imageboard_site.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BoardSwitcherPage extends StatefulWidget {
	createState() => _BoardSwitcherPageState();
}

class _BoardSwitcherPageState extends State<BoardSwitcherPage> {
	String searchString = '';
	@override
	Widget build(BuildContext context) {
		return CupertinoPageScaffold(
			navigationBar: CupertinoNavigationBar(
				middle: LayoutBuilder(
					builder: (context, box) {
						return SizedBox(
							width: box.maxWidth * 0.75,
							child: CupertinoTextField(
								autofocus: true,
								autocorrect: false,
								placeholder: "Board...",
								textAlign: TextAlign.center,
								onSubmitted: (String board) {
									Navigator.of(context).pop(board);
								},
								onChanged: (String newSearchString) {
									setState(() {
										searchString = newSearchString.toLowerCase();
									});
								}
							)
						);
					}
				)
			),
			backgroundColor: Colors.transparent,
			child: Container(
				decoration: BoxDecoration(
					color: CupertinoTheme.of(context).scaffoldBackgroundColor,
					border: Border(bottom: BorderSide(width: 0))
				),
				child: FutureBuilder<List<ImageboardBoard>>(
					future: context.watch<ImageboardSite>().getBoards(),
					builder: (context, boards) {
						if (boards.hasData) {
							final filteredBoards = boards.data!.where((board) {
								return board.name.toLowerCase().contains(searchString) || board.title.toLowerCase().contains(searchString);
							}).toList();
							return ListView.builder(
								shrinkWrap: true,
								itemBuilder: (context, i) {
									if (i % 2 == 0) {
										final board = filteredBoards[i ~/ 2];
										return GestureDetector(
											child: Container(
												padding: EdgeInsets.all(8),
												child: Center(
													child: Text(
														'/${board.name}/ - ${board.title}',
														textAlign: TextAlign.center
													)
												)
											),
											onTap: () {
												Navigator.of(context).pop(board.name);
											}
										);
									}
									else {
										return Divider(
											height: 0
										);
									}
								},
								itemCount: (filteredBoards.length * 2) - 1
							);
						}
						else if (boards.hasError) {
							return Center(
								child: Text(boards.error.toString())
							);
						}
						else {
							return Center(
								child: CircularProgressIndicator()
							);
						}
					}
				)
			)
		);
	}
}
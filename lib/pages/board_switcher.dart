import 'package:chan/sites/imageboard_site.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:auto_size_text/auto_size_text.dart';

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
							mergeSort<ImageboardBoard>(filteredBoards, compare: (a, b) {
								return a.name.length - b.name.length;
							});
							mergeSort<ImageboardBoard>(filteredBoards, compare: (a, b) {
								return a.name.indexOf(searchString) - b.name.indexOf(searchString);
							});
							mergeSort<ImageboardBoard>(filteredBoards, compare: (a, b) {
								return (b.name.contains(searchString) ? 1 : 0) - (a.name.contains(searchString) ? 1 : 0);
							});
							return SafeArea(
								child: GridView.count(
									padding: EdgeInsets.only(top: 4, bottom: 4),
									crossAxisCount: 3,
									childAspectRatio: 1.7,
									mainAxisSpacing: 4,
									crossAxisSpacing: 4,
									shrinkWrap: true,
									children: filteredBoards.map((board) {
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
												Navigator.of(context).pop(board.name);
											}
										);
									}).toList()
								)
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
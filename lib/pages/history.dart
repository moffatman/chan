import 'package:chan/pages/thread.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/widgets/thread_row.dart';
import 'package:flutter/cupertino.dart';
import 'package:cupertino_back_gesture/src/cupertino_page_route.dart' as cpr;
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HistoryPage extends StatelessWidget {
	@override
	Widget build(BuildContext context) {
		return CupertinoPageScaffold(
			navigationBar: CupertinoNavigationBar(
				transitionBetweenRoutes: false,
				middle: Text('History')
			),
			child: Center(
				child: ValueListenableBuilder(
					valueListenable: Persistence.threadStateBox.listenable(),
					builder: (context, Box<PersistentThreadState> box, child) {
						final states = box.toMap().entries.toList();
						states.sort((a, b) => b.value.lastOpenedTime.compareTo(a.value.lastOpenedTime));
						return ListView.builder(
							itemCount: states.length,
							itemBuilder: (context, i) => (states[i].value.thread != null) ? GestureDetector(
								behavior: HitTestBehavior.opaque,
								child: ThreadRow(
									thread: states[i].value.thread!,
									isSelected: false
								),
								onTap: () => Navigator.of(context).push(cpr.CupertinoPageRoute(builder: (ctx) => ThreadPage(board: Persistence.boardBox.get(states[i].value.thread!.board)!, id: states[i].value.thread!.id)))
							) : Text(states[i].key)
						);
					}
				)
			)
		);
	}
}
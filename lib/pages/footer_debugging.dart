

import 'package:chan/pages/scrolling_debugging.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:flutter/cupertino.dart';

class FooterDebuggingPage extends StatefulWidget {
	const FooterDebuggingPage({
		Key? key
	}) : super(key: key);

	@override
	createState() => _FooterDebuggingPageState();
}

class _FooterDebuggingPageState extends State<FooterDebuggingPage> {
	final controller = RefreshableListController<FakeItem>();
	int i = 100;

	@override
	Widget build(BuildContext context) {
		return CupertinoPageScaffold(
			navigationBar: const CupertinoNavigationBar(
				middle: Text('Footer debugging')
			),
			child: RefreshableList<FakeItem>(
				id: 'debuggingList',
				controller: controller,
				itemBuilder: (context, item) => SizedBox(height: 150, child: Text(item.id.toString())),
				listUpdater: () async {
					//await Future.delayed(const Duration(seconds: 1));
					return List.generate(++i, (i) => FakeItem(i));
				}
			)
		);
	}
}


import 'package:chan/services/filtering.dart';
import 'package:chan/widgets/adaptive.dart';
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
	final controller = RefreshableListController<EmptyFilterable>();
	int i = 100;

	@override
	Widget build(BuildContext context) {
		return AdaptiveScaffold(
			bar: const AdaptiveBar(
				title: Text('Footer debugging')
			),
			body: RefreshableList<EmptyFilterable>(
				id: 'debuggingList',
				filterableAdapter: null,
				controller: controller,
				itemBuilder: (context, item) => SizedBox(height: 150, child: Text(item.id.toString())),
				listUpdater: () async {
					//await Future.delayed(const Duration(seconds: 1));
					return List.generate(++i, (i) => EmptyFilterable(i));
				}
			)
		);
	}
}
import 'package:flutter/cupertino.dart';

class SavedPage extends StatelessWidget {
	@override
	Widget build(BuildContext context) {
		return CupertinoPageScaffold(
			navigationBar: CupertinoNavigationBar(
				transitionBetweenRoutes: false,
				middle: Text('Saved')
			),
			child: Center(
				child: Text('Unimplemented')
			)
		);
	}
}
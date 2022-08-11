import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';

class SocketDebuggingPage extends StatelessWidget {
	const SocketDebuggingPage({
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return CupertinoPageScaffold(
			navigationBar: const CupertinoNavigationBar(
				transitionBetweenRoutes: false,
				middle: Text('Socket Stress Test')
			),
			child: GridView.builder(
				gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
					maxCrossAxisExtent: 100
				),
				itemBuilder: (context, i) => ExtendedImage.network(
					//'https://via.placeholder.com/90x90.png?text=$i',
					'http://192.168.2.182:8080/$i',
					cache: true,
					retries: 0
				)
			)
		);
	}
}
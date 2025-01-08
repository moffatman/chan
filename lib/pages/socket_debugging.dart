import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/network_image.dart';
import 'package:flutter/cupertino.dart';

class SocketDebuggingPage extends StatelessWidget {
	const SocketDebuggingPage({
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return AdaptiveScaffold(
			bar: const AdaptiveBar(
				title: Text('Socket Stress Test')
			),
			body: GridView.builder(
				gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
					maxCrossAxisExtent: 100
				),
				itemBuilder: (context, i) => CNetworkImage(
					//'https://via.placeholder.com/90x90.png?text=$i',
					url: 'http://192.168.2.182:8080/$i',
					cache: true,
					client: null
				)
			)
		);
	}
}
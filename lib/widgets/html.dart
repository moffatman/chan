import 'package:chan/services/html_rendering.dart';
import 'package:chan/services/theme.dart';
import 'package:flutter/cupertino.dart';

class HTMLWidget extends StatelessWidget {
	final String html;
	final Color? color;
	const HTMLWidget({
		required this.html,
		this.color,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return Image(
			image: HTMLImageProvider(html, primaryColor: ChanceTheme.primaryColorOf(context)),
			loadingBuilder: (context, child, chunk) {
				if (chunk == null) {
					return child;
				}
				return Opacity(
					opacity: 0.5,
					child: Text(html)
				);
			},
		);
	}
}

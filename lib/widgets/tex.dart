import 'package:chan/services/tex_rendering.dart';
import 'package:chan/services/theme.dart';
import 'package:flutter/cupertino.dart';

class TexWidget extends StatelessWidget {
	final String tex;
	final Color? color;
	const TexWidget({
		required this.tex,
		this.color,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return Image(
			image: TeXImageProvider(
				tex,
				color: color ?? ChanceTheme.primaryColorOf(context)
			),
			frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
				if (frame != null) {
					return child;
				}
				return Opacity(
					opacity: 0.5,
					child: Text(tex)
				);
			},
		);
	}
}
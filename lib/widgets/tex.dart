import 'package:chan/services/tex_rendering.dart';
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
		return ColorFiltered(
			colorFilter: ColorFilter.mode(color ?? CupertinoTheme.of(context).primaryColor, BlendMode.srcIn),
			child: Image(
				image: TeXImageProvider(
					tex,
					textScaleFactor: MediaQuery.of(context, MediaQueryAspect.textScaleFactor).textScaleFactor
				),
				loadingBuilder: (context, child, chunk) {
					if (chunk == null) {
						return child;
					}
					return Opacity(
						opacity: 0.5,
						child: Text(tex)
					);
				},
			)
		);
	}
}
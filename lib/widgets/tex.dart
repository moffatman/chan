import 'package:chan/services/tex_rendering.dart';
import 'package:flutter/cupertino.dart';

class TexWidget extends StatelessWidget {
	final String tex;
	const TexWidget({
		required this.tex,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return ColorFiltered(
			colorFilter: ColorFilter.mode(CupertinoTheme.of(context).primaryColor, BlendMode.srcIn),
			child: Image(
				image: TeXImageProvider(tex)
			)
		);
	}
}
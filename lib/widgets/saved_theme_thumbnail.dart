import 'package:chan/services/settings.dart';
import 'package:flutter/widgets.dart';

class SavedThemeThumbnail extends StatelessWidget {
	final SavedTheme theme;

	const SavedThemeThumbnail({
		required this.theme,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				Flexible(
					flex: 4,
					fit: FlexFit.tight,
					child: Container(
						color: theme.backgroundColor,
						padding: const EdgeInsets.all(8),
						child: Align(
							alignment: Alignment.topLeft,
							child: FittedBox(
								child: Column(
									mainAxisSize: MainAxisSize.min,
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Text('>>1 (OP)', style: TextStyle(color: theme.secondaryColor, decoration: TextDecoration.underline)),
										Text('>Quote', style: TextStyle(color: theme.quoteColor)),
										Text('Text', style: TextStyle(color: theme.primaryColor))
									]
								)
							)
						)
					)
				),
				Flexible(
					fit: FlexFit.tight,
					child: Container(color: theme.barColor)
				)
			]
		);
	}
}
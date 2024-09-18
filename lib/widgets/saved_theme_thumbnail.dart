import 'dart:ui';

import 'package:chan/services/settings.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/widgets.dart';

class SavedThemeThumbnail extends StatelessWidget {
	final SavedTheme theme;
	final bool showTitleAndTextField;

	const SavedThemeThumbnail({
		required this.theme,
		this.showTitleAndTextField = false,
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
										if (showTitleAndTextField) Text('Title', style: TextStyle(color: theme.titleColor, fontWeight: FontWeight.w600, fontVariations: CommonFontVariations.w600)),
										Text('>>1 (OP)', style: TextStyle(color: theme.secondaryColor, decoration: TextDecoration.underline)),
										Text('>Quote', style: TextStyle(color: theme.quoteColor)),
										Text('Text', style: TextStyle(color: theme.primaryColor)),
										if (showTitleAndTextField) Container(
											decoration: BoxDecoration(
												color: theme.textFieldColor,
												border: Border.all(
													color: theme.brightness == Brightness.light ?const Color(0x33000000) : const Color(0x33FFFFFF),
													width: 0
												),
												borderRadius: const BorderRadius.all(Radius.circular(5.0))
											),
											padding: const EdgeInsets.all(6),
											margin: const EdgeInsets.symmetric(vertical: 2),
											child: Text('Text field', style: TextStyle(color: theme.primaryColor))
										)
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
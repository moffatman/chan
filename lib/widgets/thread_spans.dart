import 'package:chan/sites/imageboard_site.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FlagSpan extends WidgetSpan {
	FlagSpan(ImageboardFlag flag) : super(
		child: SizedBox(
			width: flag.imageWidth,
			height: flag.imageHeight,
			child: ExtendedImage.network(
				flag.imageUrl,
				cache: true,
				enableLoadState: false
			)
		),
		alignment: PlaceholderAlignment.middle
	);
}

class _IDColor {
	final Color background;
	final Color foreground;
	_IDColor({
		required this.background,
		required this.foreground
	});
}

_IDColor _calculateIdColor(String id) {
	int hash = 0;
	for (final codeUnit in id.codeUnits) {
		hash = ((hash << 5) - hash) + codeUnit;
	}
	final background = Color.fromARGB(255, (hash >> 24) & 0xFF, (hash >> 16) & 0xFF, (hash >> 8) & 0xFF);
	return _IDColor(
		foreground: (((background.red * 0.299) + (background.blue * 0.587) + (background.green * 0.114)) > 125) ? Colors.black : Colors.white,
		background: background
	);
}

class IDSpan extends WidgetSpan {
	IDSpan({
		required String id,
		required VoidCallback? onPressed
	}) : super(
		child: CupertinoButton(
			child: Container(
				decoration: BoxDecoration(
					color: _calculateIdColor(id).background,
					borderRadius: BorderRadius.all(Radius.circular(3))
				),
				padding: EdgeInsets.only(left: 4, right: 4),
				child: Text(
					id,
					style: TextStyle(
						color: _calculateIdColor(id).foreground
					)
				)
			),
			padding: EdgeInsets.zero,
			minSize: 0,
			onPressed: onPressed
		),
		alignment: PlaceholderAlignment.middle
	);
}
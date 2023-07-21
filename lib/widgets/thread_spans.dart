import 'package:chan/models/flag.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class _ImageboardFlag extends StatelessWidget {
	final ImageboardFlag flag;

	const _ImageboardFlag(this.flag);

	@override
	Widget build(BuildContext context) {
		if (flag.imageWidth == 0 || flag.imageHeight == 0) {
			return const SizedBox.shrink();
		}
		return SizedBox(
			width: flag.imageWidth,
			height: flag.imageHeight,
			child: ExtendedImage.network(
				flag.imageUrl,
				cache: true,
				enableLoadState: false,
				headers: context.read<ImageboardSite>().getHeaders(Uri.parse(flag.imageUrl))
			)
		);
	}
}

class _Flag extends StatelessWidget {
	final Flag flag;

	const _Flag(this.flag);

	@override
	Widget build(BuildContext context) {
		if (flag is ImageboardFlag) {
			return _ImageboardFlag(flag as ImageboardFlag);
		}
		bool paddingBeforeNextImage = false;
		final children = <Widget>[];
		for (final part in (flag as ImageboardMultiFlag).parts) {
			if (part.imageUrl.isNotEmpty && paddingBeforeNextImage) {
				children.add(const SizedBox(width: 4));
			}
			children.add(_ImageboardFlag(part));
			if (part.imageUrl.isNotEmpty) {
				paddingBeforeNextImage = true;
			}
		}
		return Row(
			mainAxisSize: MainAxisSize.min,
			children: children
		);
	}
}

class FlagSpan extends WidgetSpan {
	FlagSpan(Flag flag) : super(
		child: _Flag(flag),
		alignment: PlaceholderAlignment.middle
	);
}

class PassSinceSpan extends TextSpan {
	PassSinceSpan({
		required int sinceYear,
		required ImageboardSite site
	}) : super(
		children: [
			WidgetSpan(
				child: Row(
					mainAxisSize: MainAxisSize.min,
					children: [
						SizedBox(
							width: 16,
							height: 16,
							child: ExtendedImage.network(
								site.passIconUrl.toString(),
								cache: true,
								enableLoadState: false
							)
						),
						Text(sinceYear.toString())
					]
				),
				alignment: PlaceholderAlignment.bottom
			)
		]
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
		foreground: (((background.red * 0.299) + (background.green * 0.587) + (background.blue * 0.114)) > 125) ? Colors.black : Colors.white,
		background: background
	);
}

class IDSpan extends WidgetSpan {
	IDSpan({
		required String id,
		required VoidCallback? onPressed
	}) : super(
		child: CupertinoButton(
			padding: EdgeInsets.zero,
			minSize: 0,
			onPressed: onPressed,
			child: Container(
				decoration: BoxDecoration(
					color: _calculateIdColor(id).background,
					borderRadius: const BorderRadius.all(Radius.circular(3))
				),
				padding: const EdgeInsets.only(left: 4, right: 4),
				child: Text(
					id,
					style: TextStyle(
						color: _calculateIdColor(id).foreground
					)
				)
			)
		),
		alignment: PlaceholderAlignment.middle
	);
}
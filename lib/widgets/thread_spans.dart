import 'package:chan/models/flag.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/util.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class _ImageboardFlag extends StatelessWidget {
	final ImageboardFlag flag;
	final TextStyle? style;

	const _ImageboardFlag(this.flag, this.style);

	@override
	Widget build(BuildContext context) {
		if (flag.imageWidth == 0 || flag.imageHeight == 0) {
			return Text(flag.name, style: style, textScaler: TextScaler.noScaling);
		}
		return SizedBox(
			width: flag.imageWidth,
			height: flag.imageHeight,
			child: GestureDetector(
				onTap: () => showToast(
					context: context,
					message: flag.name,
					icon: CupertinoIcons.flag
				),
				child: ExtendedImage.network(
					flag.imageUrl,
					cache: true,
					enableLoadState: false,
					headers: context.read<ImageboardSite>().getHeaders(Uri.parse(flag.imageUrl))
				)
			)
		);
	}
}

InlineSpan makeFlagSpan({
	required Flag flag,
	required bool includeTextOnlyContent,
	required bool appendLabels,
	TextStyle? style
}) {
	final parts = (flag is ImageboardMultiFlag) ? flag.parts : [flag as ImageboardFlag];
	bool padding = false;
	final children = <InlineSpan>[];
	for (final part in parts) {
		if (!includeTextOnlyContent && part.imageUrl.isEmpty) {
			continue;
		}
		if (padding) {
			children.add(const TextSpan(text: ' '));
		}
		children.add(WidgetSpan(
			child: _ImageboardFlag(part, style),
			alignment: PlaceholderAlignment.middle
		));
		if (part.name.isNotEmpty && part.imageUrl.isNotEmpty && appendLabels) {
			children.add(TextSpan(text: ' ${part.name}', style: style));
		}
		padding = true;
	}
	return TextSpan(
		children: children
	);
}

class PassSinceSpan extends TextSpan {
	PassSinceSpan({
		required int sinceYear,
		required ImageboardSite site
	}) : super(
		children: [
			TextualWidgetSpan(
				text: sinceYear.toString(),
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
						Text(sinceYear.toString(), textScaler: TextScaler.noScaling)
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
					),
					textScaler: TextScaler.noScaling
				)
			)
		),
		alignment: PlaceholderAlignment.middle
	);
}
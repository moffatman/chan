import 'package:chan/models/flag.dart';
import 'package:chan/pages/posts.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/util.dart';
import 'package:chan/widgets/weak_navigator.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

InlineSpan makeFlagSpan({
	required BuildContext? context,
	required PostSpanZoneData? zone,
	required Flag flag,
	required bool includeTextOnlyContent,
	required bool appendLabels,
	TextStyle? style
}) {
	bool padding = false;
	final children = <InlineSpan>[];
	for (final part in flag.parts) {
		if (!includeTextOnlyContent && part.imageUrl.isEmpty) {
			continue;
		}
		if (padding) {
			children.add(const TextSpan(text: ' '));
		}
		final onTap = context == null ? null : () {
			final (String, VoidCallback)? easyButton;
			if (zone == null) {
				easyButton = null;
			}
			else {
				final postIdsToShow = zone.findThread(zone.primaryThreadId)?.posts.where((p) => p.flag?.parts.contains(part) ?? false).map((p) => p.id).toList() ?? [];
				if (postIdsToShow.length < 2) {
					// Don't bother
					easyButton = null;
				}
				else {
					easyButton = ('${postIdsToShow.length} posts', () => WeakNavigator.push(context, PostsPage(
						postsIdsToShow: postIdsToShow,
						zone: zone
					)));
				}
			}
			showToast(
				context: context,
				message: flag.name,
				icon: CupertinoIcons.flag,
				easyButton: easyButton
			);
		};
		if (part.imageWidth == 0 || part.imageHeight == 0) {
			children.add(TextSpan(text: flag.name));
		}
		else {
			children.add(WidgetSpan(
				alignment: PlaceholderAlignment.middle,
				child: Builder(
					builder: (context) => SizedBox(
						width: part.imageWidth,
						height: part.imageHeight,
						child: GestureDetector(
							onTap: onTap,
							child: ExtendedImage.network(
								part.imageUrl,
								cache: true,
								enableLoadState: false,
								headers: context.read<ImageboardSite>().getHeaders(Uri.parse(part.imageUrl))
							)
						)
					)
				)
			));
		}
		if (part.name.isNotEmpty && part.imageUrl.isNotEmpty && appendLabels) {
			children.add(TextSpan(text: ' ${part.name}', recognizer: TapGestureRecognizer()..onTap = onTap));
		}
		padding = true;
	}
	return TextSpan(
		children: children,
		style: style
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
						Text(sinceYear.toString(), textScaler: TextScaler.noScaling, style: const TextStyle(fontSize: 16))
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
						color: _calculateIdColor(id).foreground,
						fontSize: 16
					),
					textScaler: TextScaler.noScaling
				)
			)
		),
		alignment: PlaceholderAlignment.middle
	);
}
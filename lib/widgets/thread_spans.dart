import 'dart:math';

import 'package:chan/models/flag.dart';
import 'package:chan/pages/posts.dart';
import 'package:chan/services/countries.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/cupertino_inkwell.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/network_image.dart';
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
		Widget fallbackWidget() => switch (kCountries.values.tryFirstWhere((c) {
			return c.name == part.name;
		}) ?? kCountries.values.tryFirstWhere((c) {
			return part.name.contains(c.name);
		})) {
			CountryFlag country => Text(country.emoji, style: const TextStyle(height: 1)),
			null => Icon(CupertinoIcons.flag_slash, size: min(part.imageWidth, part.imageHeight))
		};
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
				icon: null,
				iconWidget: SizedBox(
					width: part.imageWidth,
					height: part.imageHeight,
					child: CNetworkImage(
						url: part.imageUrl,
						client: context.read<ImageboardSite>().client,
						width: part.imageWidth,
						height: part.imageHeight,
						cache: true,
						enableLoadState: true,
						loadStateChanged: (state) => switch (state.extendedImageLoadState) {
							LoadState.completed => null,
							LoadState.loading => const SizedBox.shrink(),
							LoadState.failed => fallbackWidget()
						}
					)
				),
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
							child: CNetworkImage(
								url: part.imageUrl,
								client: context.read<ImageboardSite>().client,
								cache: true,
								enableLoadState: true,
								loadStateChanged: (state) => switch (state.extendedImageLoadState) {
									LoadState.completed => null,
									LoadState.loading => const SizedBox.shrink(),
									LoadState.failed => fallbackWidget()
								}
							)
						)
					)
				)
			));
		}
		if (part.name.isNotEmpty && part.imageUrl.isNotEmpty && appendLabels) {
			children.add(TextSpan(text: ' ${part.name}', recognizer: TapGestureRecognizer(debugOwner: flag)..onTap = onTap));
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
						ImageboardSiteLoginSystemIcon(
							loginSystem: site.loginSystem
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
	final codeUnits = id.codeUnits;
	for (int i = 0; i < max(7, codeUnits.length); i++) {
		// Hash shorter than 7 letters will not use full color range. Just wrap the text
		hash = ((hash << 5) - hash) + codeUnits[i % codeUnits.length];
	}
	final background = Color.fromARGB(255, (hash >> 24) & 0xFF, (hash >> 16) & 0xFF, (hash >> 8) & 0xFF);
	return _IDColor(
		foreground: (((background.r * 0.299) + (background.g * 0.587) + (background.b * 0.114)) > 0.49) ? Colors.black : Colors.white,
		background: background
	);
}

class IDSpan extends WidgetSpan {
	IDSpan({
		required String id,
		required VoidCallback? onPressed
	}) : super(
		child: CupertinoInkwell(
			padding: EdgeInsets.zero,
			minimumSize: Size.zero,
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

class NSFWLabel extends StatelessWidget {
	const NSFWLabel({
		super.key
	});

	@override
	Widget build(BuildContext context) {
		return const DecoratedBox(
			decoration: BoxDecoration(
				borderRadius: BorderRadius.all(Radius.circular(4)),
				border: Border.fromBorderSide(BorderSide(color: Colors.red))
			),
			child: Padding(
				padding: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
				child: Text('NSFW', style: TextStyle(color: Colors.red, fontSize: 14))
			)
		);
	}
}

class NSFWSpan extends WidgetSpan {
	const NSFWSpan() : super(
		child: const NSFWLabel()
	);
}

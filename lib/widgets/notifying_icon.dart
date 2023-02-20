import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';

class StationaryNotifyingIcon extends StatelessWidget {
	final Widget icon;
	final int primary;
	final int secondary;
	final double topOffset;

	const StationaryNotifyingIcon({
		required this.icon,
		required this.primary,
		this.secondary = 0,
		this.topOffset = 0,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		const r = Radius.circular(10);
		return Stack(
			clipBehavior: Clip.none,
			children: [
				icon,
				if (primary > 0 || secondary > 0) Positioned(
					right: -10,
					top: -10 + topOffset,
					child: Row(
						children: [
							if (primary > 0) Container(
								decoration: BoxDecoration(
									color: CupertinoTheme.of(context).textTheme.actionTextStyle.color,
									borderRadius: (secondary > 0) ? const BorderRadius.only(topLeft: r, bottomLeft: r) : const BorderRadius.all(r)
								),
								constraints: const BoxConstraints(
									minWidth: 20
								),
								height: 20,
								alignment: Alignment.center,
								padding: const EdgeInsets.all(2),
								child: AutoSizeText(
									primary.toString(),
									maxLines: 1,
									minFontSize: 0,
									textAlign: TextAlign.center,
									style: const TextStyle(
										color: Colors.white
									)
								)
							),
							if (secondary > 0) Container(
								decoration: BoxDecoration(
									color: CupertinoTheme.of(context).primaryColor,
									borderRadius: (primary > 0) ? const BorderRadius.only(topRight: r, bottomRight: r) : const BorderRadius.all(r)
								),
								constraints: const BoxConstraints(
									minWidth: 20
								),
								height: 20,
								alignment: Alignment.center,
								padding: const EdgeInsets.all(2),
								child: AutoSizeText(
									secondary.toString(),
									maxLines: 1,
									minFontSize: 0,
									textAlign: TextAlign.center,
									style: TextStyle(
										color: CupertinoTheme.of(context).scaffoldBackgroundColor
									)
								)
							)
						]
					)
				)
			]
		);
	}
}

class NotifyingIcon extends StatelessWidget {
	final Widget icon;
	final ValueListenable<int> primaryCount;
	final ValueListenable<int>? secondaryCount;
	final double topOffset;
	const NotifyingIcon({
		required this.icon,
		required this.primaryCount,
		this.secondaryCount,
		this.topOffset = 0,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return ValueListenableBuilder(
			valueListenable: primaryCount,
			builder: (BuildContext context, int primary, Widget? child) => (secondaryCount == null) ? StationaryNotifyingIcon(
				icon: icon,
				primary: primary
			) : ValueListenableBuilder(
				valueListenable: secondaryCount!,
				builder: (BuildContext context, int secondary, Widget? child) => StationaryNotifyingIcon(
					icon: icon,
					primary: primary,
					secondary: secondary,
					topOffset: topOffset
				)
			)
		);
	}
}
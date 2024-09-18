import 'package:chan/services/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';

class StationaryNotifyingIcon extends StatelessWidget {
	final Widget icon;
	final int primary;
	final int secondary;
	final double topOffset;
	final bool sideBySide;

	const StationaryNotifyingIcon({
		required this.icon,
		required this.primary,
		this.secondary = 0,
		this.topOffset = 0,
		this.sideBySide = false,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		const r = Radius.circular(10);
		final child = sideBySide ? Column(
			mainAxisAlignment: MainAxisAlignment.center,
			children: [
				if (primary > 0) Container(
					decoration: BoxDecoration(
						color: ChanceTheme.secondaryColorOf(context),
						borderRadius: const BorderRadius.all(r)
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
						style: TextStyle(
							color: (ChanceTheme.secondaryColorOf(context).computeLuminance() > 0.5) ? Colors.black : Colors.white
						)
					)
				),
				if (primary > 0 && secondary > 0) const SizedBox(height: 2),
				if (secondary > 0) Container(
					decoration: BoxDecoration(
						color: ChanceTheme.primaryColorOf(context),
						borderRadius: const BorderRadius.all(r)
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
							color: ChanceTheme.backgroundColorOf(context)
						)
					)
				)
			]
		) : Row(
			children: [
				if (primary > 0) Container(
					decoration: BoxDecoration(
						color: ChanceTheme.secondaryColorOf(context),
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
						style: TextStyle(
							color: (ChanceTheme.secondaryColorOf(context).computeLuminance() > 0.5) ? Colors.black : Colors.white
						)
					)
				),
				if (secondary > 0) Container(
					decoration: BoxDecoration(
						color: ChanceTheme.primaryColorOf(context),
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
							color: ChanceTheme.backgroundColorOf(context)
						)
					)
				)
			]
		);
		if (sideBySide) {
			return Row(
				mainAxisSize: MainAxisSize.min,
				children: [
					icon,
					const SizedBox(width: 2),
					child
				]
			);
		}
		return Stack(
			clipBehavior: Clip.none,
			children: [
				icon,
				if (primary > 0 || secondary > 0) Positioned(
					right: -10,
					top: -10 + topOffset,
					child: IgnorePointer(
						child: child
					)
				)
			]
		);
	}
}

class NotifyingIcon extends StatelessWidget {
	final Widget icon;
	final ValueListenable<int>? primaryCount;
	final ValueListenable<int>? secondaryCount;
	final double topOffset;
	final bool sideBySide;
	const NotifyingIcon({
		required this.icon,
		this.primaryCount,
		this.secondaryCount,
		this.topOffset = 0,
		this.sideBySide = false,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		final primaryCount = this.primaryCount;
		final secondaryCount = this.secondaryCount;
		return (primaryCount == null) ? ValueListenableBuilder(
			valueListenable: secondaryCount!,
			builder: (BuildContext context, int secondary, Widget? child) => StationaryNotifyingIcon(
				icon: icon,
				primary: 0,
				secondary: secondary,
				topOffset: topOffset,
				sideBySide: sideBySide
			)
		): ValueListenableBuilder(
			valueListenable: primaryCount,
			builder: (BuildContext context, int primary, Widget? child) => (secondaryCount == null) ? StationaryNotifyingIcon(
				icon: icon,
				primary: primary,
				sideBySide: sideBySide
			) : ValueListenableBuilder(
				valueListenable: secondaryCount,
				builder: (BuildContext context, int secondary, Widget? child) => StationaryNotifyingIcon(
					icon: icon,
					primary: primary,
					secondary: secondary,
					topOffset: topOffset,
					sideBySide: sideBySide
				)
			)
		);
	}
}
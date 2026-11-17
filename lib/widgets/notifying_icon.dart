import 'package:chan/services/theme.dart';
import 'package:chan/widgets/segmented.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';

class StationaryNotifyingIcon extends StatelessWidget {
	final Widget icon;
	final int primary;
	final int secondary;
	final double topOffset;
	final bool sideBySide;
	final double sideBySideRightPadding;
	final bool constrainBadge;
	final bool showBadge;
	final Duration badgeAnimationDuration;

	const StationaryNotifyingIcon({
		required this.icon,
		required this.primary,
		this.secondary = 0,
		this.topOffset = 0,
		this.sideBySide = false,
		this.sideBySideRightPadding = 0,
		this.constrainBadge = false,
		this.showBadge = true,
		this.badgeAnimationDuration = Duration.zero,
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
		) : SegmentedWidget(
			radius: r,
			padding: const EdgeInsets.all(2),
			segments: [
				if (primary > 0) SegmentedWidgetSegment(
					color: ChanceTheme.secondaryColorOf(context),
					child: Container(
						constraints: const BoxConstraints(
							minWidth: 16
						),
						height: 16,
						padding: const EdgeInsets.all(1),
						alignment: Alignment.center,
						child: AutoSizeText(
							primary.toString(),
							maxLines: 1,
							minFontSize: 0,
							textAlign: TextAlign.center,
							style: TextStyle(
								color: (ChanceTheme.secondaryColorOf(context).computeLuminance() > 0.5) ? Colors.black : Colors.white
							)
						)
					)
				),
				if (secondary > 0) SegmentedWidgetSegment(
					color: ChanceTheme.primaryColorOf(context),
					child: Container(
						constraints: const BoxConstraints(
							minWidth: 16
						),
						height: 16,
						padding: const EdgeInsets.all(1),
						alignment: Alignment.center,
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
				)
			]
		);
		if (sideBySide) {
			return Row(
				mainAxisSize: MainAxisSize.min,
				children: [
					icon,
					if (primary > 0 || secondary > 0) const SizedBox(width: 2),
					child,
					if (primary > 0 || secondary > 0) SizedBox(width: sideBySideRightPadding)
				]
			);
		}
		final badge = constrainBadge ? FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: child) : child;
		return Stack(
			clipBehavior: Clip.none,
			children: [
				if (constrainBadge) Align(alignment: Alignment.center, child: icon)
				else icon,
				if (primary > 0 || secondary > 0) Positioned(
					left: constrainBadge ? 0 : null,
					right: constrainBadge ? 0 : -10,
					top: -10 + topOffset,
					child: IgnorePointer(
						child: badgeAnimationDuration == Duration.zero ? (showBadge ? badge : const SizedBox.shrink()) : AnimatedOpacity(
							opacity: showBadge ? 1 : 0,
							duration: badgeAnimationDuration,
							curve: Curves.easeInOut,
							child: AnimatedScale(
								scale: showBadge ? 1 : 0,
								duration: badgeAnimationDuration,
								curve: Curves.easeInOut,
								alignment: Alignment.bottomCenter,
								child: badge
							)
						)
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
	final double sideBySideRightPadding;
	final bool constrainBadge;
	final bool showBadge;
	final Duration badgeAnimationDuration;
	const NotifyingIcon({
		required this.icon,
		this.primaryCount,
		this.secondaryCount,
		this.topOffset = 0,
		this.sideBySideRightPadding = 0,
		this.sideBySide = false,
		this.constrainBadge = false,
		this.showBadge = true,
		this.badgeAnimationDuration = Duration.zero,
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
				constrainBadge: constrainBadge,
				showBadge: showBadge,
				badgeAnimationDuration: badgeAnimationDuration,
				secondary: secondary,
				topOffset: topOffset,
				sideBySide: sideBySide,
				sideBySideRightPadding: sideBySideRightPadding
			)
		): ValueListenableBuilder(
			valueListenable: primaryCount,
			builder: (BuildContext context, int primary, Widget? child) => (secondaryCount == null) ? StationaryNotifyingIcon(
				icon: icon,
				primary: primary,
				constrainBadge: constrainBadge,
				showBadge: showBadge,
				badgeAnimationDuration: badgeAnimationDuration,
				sideBySide: sideBySide,
				sideBySideRightPadding: sideBySideRightPadding
			) : ValueListenableBuilder(
				valueListenable: secondaryCount,
				builder: (BuildContext context, int secondary, Widget? child) => StationaryNotifyingIcon(
					icon: icon,
					primary: primary,
					constrainBadge: constrainBadge,
					showBadge: showBadge,
					badgeAnimationDuration: badgeAnimationDuration,
					secondary: secondary,
					topOffset: topOffset,
					sideBySide: sideBySide,
					sideBySideRightPadding: sideBySideRightPadding
				)
			)
		);
	}
}

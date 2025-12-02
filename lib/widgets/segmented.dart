import 'dart:async';

import 'package:chan/widgets/cupertino_inkwell.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';

class SegmentedWidgetSegment {
	final Color color;
	final Widget child;
	final FutureOr Function()? onPressed;

	const SegmentedWidgetSegment({
		required this.color,
		required this.child,
		this.onPressed
	});

	Widget _build(BorderRadius? borderRadius, EdgeInsets padding) {
		final child = Container(
			decoration: BoxDecoration(
				borderRadius: borderRadius,
				color: color
			),
			padding: padding,
			child: this.child
		);
		if (onPressed != null) {
			return Builder(
				builder: (context) => CupertinoInkwell(
					padding: EdgeInsets.zero,
					minimumSize: Size.zero,
					onPressed: wrapButtonCallback(context, onPressed),
					child: child
				)
			);
		}
		return child;
	}
}

class SegmentedWidget extends StatelessWidget {
	final List<SegmentedWidgetSegment> segments;
	final Radius radius;
	final EdgeInsets padding;

	const SegmentedWidget({
		required this.segments,
		required this.radius,
		this.padding = const EdgeInsets.all(8),
		super.key
	});

	@override
	Widget build(BuildContext context) {
		return switch (segments) {
			[] => const SizedBox.shrink(),
			[SegmentedWidgetSegment single] => single._build(BorderRadius.all(radius), padding),
			[SegmentedWidgetSegment first, ...List<SegmentedWidgetSegment> middle, SegmentedWidgetSegment last] => Row(
				mainAxisSize: MainAxisSize.min,
				children: [
					first._build(BorderRadius.only(topLeft: radius, bottomLeft: radius), padding),
					...middle.map((segment) => segment._build(null, padding)),
					last._build(BorderRadius.only(topRight: radius, bottomRight: radius), padding)
				]
			)
		};
	}
}
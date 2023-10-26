import 'dart:math' as math;

import 'package:flutter/widgets.dart';

class StickyMediaQuery extends StatefulWidget {
	final bool top;
	final bool left;
	final bool right;
	final bool bottom;
	final Widget child;

	const StickyMediaQuery({
		this.top = false,
		this.left = false,
		this.right = false,
		this.bottom = false,
		required this.child,
		Key? key
	}) : super(key: key);

	@override
	createState() => _StickyMediaQueryState();
}

class _StickyMediaQueryState extends State<StickyMediaQuery> {
	Size? _lastSize;
	final Map<Orientation, EdgeInsets> map = {};

	@override
	Widget build(BuildContext context) {
		final mq = MediaQuery.of(context);
		final lastSize = _lastSize;
		if (lastSize != null &&
		    math.max(
					(lastSize.height - mq.size.height).abs(),
					(lastSize.width - mq.size.width).abs()
				) > 100) {
			// More than 100 px change in either width or height,, reset the sticky values
			map.clear();
		}
		_lastSize = mq.size;
		final data = map.update(mq.orientation, (old) {
			return (
				mq.viewPadding.clamp(EdgeInsets.only(
					left: widget.left ? old.left : 0,
					top: widget.top ? old.top : 0,
					right: widget.right ? old.right : 0,
					bottom: widget.bottom ? old.bottom : 0
				), const EdgeInsets.all(double.infinity)).resolve(TextDirection.ltr)
			);
		}, ifAbsent: () => mq.viewPadding);
		return MediaQuery(
			data: mq.copyWith(
				padding: (data - mq.viewInsets).clamp(EdgeInsets.zero, const EdgeInsets.all(double.infinity)).resolve(TextDirection.ltr),
				viewPadding: data
			),
			child: widget.child
		);
	}
}
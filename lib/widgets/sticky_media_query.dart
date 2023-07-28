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
	final Map<Orientation, (EdgeInsets padding, EdgeInsets viewPadding)> map = {};

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
				mq.padding.clamp(EdgeInsets.only(
					left: widget.left ? old.$1.left : 0,
					top: widget.top ? old.$1.top : 0,
					right: widget.right ? old.$1.right : 0,
					bottom: widget.bottom ? old.$1.bottom : 0
				), const EdgeInsets.all(double.infinity)).resolve(TextDirection.ltr),
				mq.padding.clamp(EdgeInsets.only(
					left: widget.left ? old.$2.left : 0,
					top: widget.top ? old.$2.top : 0,
					right: widget.right ? old.$2.right : 0,
					bottom: widget.bottom ? old.$2.bottom : 0
				), const EdgeInsets.all(double.infinity)).resolve(TextDirection.ltr)
			);
		}, ifAbsent: () => (mq.padding, mq.viewPadding));
		return MediaQuery(
			data: mq.copyWith(
				padding: data.$1,
				viewPadding: data.$2
			),
			child: widget.child
		);
	}
}
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
	final Map<Orientation, (EdgeInsets padding, EdgeInsets viewPadding)> map = {};

	@override
	Widget build(BuildContext context) {
		final data = map.update(MediaQuery.of(context).orientation, (old) {
			return (
				MediaQuery.of(context).padding.clamp(EdgeInsets.only(
					left: widget.left ? old.$0.left : 0,
					top: widget.top ? old.$0.top : 0,
					right: widget.right ? old.$0.right : 0,
					bottom: widget.bottom ? old.$0.bottom : 0
				), const EdgeInsets.all(double.infinity)).resolve(TextDirection.ltr),
				MediaQuery.of(context).padding.clamp(EdgeInsets.only(
					left: widget.left ? old.$1.left : 0,
					top: widget.top ? old.$1.top : 0,
					right: widget.right ? old.$1.right : 0,
					bottom: widget.bottom ? old.$1.bottom : 0
				), const EdgeInsets.all(double.infinity)).resolve(TextDirection.ltr)
			);
		}, ifAbsent: () => (MediaQuery.of(context).padding, MediaQuery.of(context).viewPadding));
		return MediaQuery(
			data: MediaQuery.of(context).copyWith(
				padding: data.$0,
				viewPadding: data.$1
			),
			child: widget.child
		);
	}
}
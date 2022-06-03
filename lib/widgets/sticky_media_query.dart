import 'package:flutter/widgets.dart';
import 'package:tuple/tuple.dart';

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
	final Map<Orientation, Tuple2<EdgeInsets, EdgeInsets>> map = {};

	@override
	Widget build(BuildContext context) {
		final data = map.update(MediaQuery.of(context).orientation, (old) {
			return Tuple2(
				MediaQuery.of(context).padding.clamp(EdgeInsets.only(
					left: widget.left ? old.item1.left : 0,
					top: widget.top ? old.item1.top : 0,
					right: widget.right ? old.item1.right : 0,
					bottom: widget.bottom ? old.item1.bottom : 0
				), const EdgeInsets.all(double.infinity)).resolve(TextDirection.ltr),
				MediaQuery.of(context).padding.clamp(EdgeInsets.only(
					left: widget.left ? old.item2.left : 0,
					top: widget.top ? old.item2.top : 0,
					right: widget.right ? old.item2.right : 0,
					bottom: widget.bottom ? old.item2.bottom : 0
				), const EdgeInsets.all(double.infinity)).resolve(TextDirection.ltr)
			);
		}, ifAbsent: () => Tuple2(MediaQuery.of(context).padding, MediaQuery.of(context).viewPadding));
		return MediaQuery(
			data: MediaQuery.of(context).copyWith(
				padding: data.item1,
				viewPadding: data.item2
			),
			child: widget.child
		);
	}
}
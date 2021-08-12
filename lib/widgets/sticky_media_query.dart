import 'package:flutter/widgets.dart';

class StickyMediaQuery extends StatefulWidget {
	final bool top;
	final bool left;
	final bool right;
	final bool bottom;
	final Widget child;

	StickyMediaQuery({
		this.top = false,
		this.left = false,
		this.right = false,
		this.bottom = false,
		required this.child
	});

	createState() => _StickyMediaQueryState();
}

class _StickyMediaQueryState extends State<StickyMediaQuery> {
	late EdgeInsets _insets;

	void initState() {
		super.initState();
		_insets = MediaQuery.of(context).padding;
	}

	Widget build(BuildContext context) {
		print('MediaQuery top padding is ${MediaQuery.of(context).padding.top}');
		_insets = MediaQuery.of(context).padding.clamp(EdgeInsets.only(
			left: widget.left ? _insets.left : 0,
			top: widget.top ? _insets.top : 0,
			right: widget.right ? _insets.right : 0,
			bottom: widget.bottom ? _insets.bottom : 0
		), EdgeInsets.all(double.nan)).resolve(Directionality.of(context));
		print('_insets top padding is ${_insets.top}');
		return MediaQuery(
			data: MediaQuery.of(context).copyWith(padding: _insets),
			child: widget.child
		);
	}
}
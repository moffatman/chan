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
	EdgeInsets? _padding;
	EdgeInsets? _viewPadding;

	@override
	Widget build(BuildContext context) {
		_padding ??= MediaQuery.of(context).padding;
		_viewPadding ??= MediaQuery.of(context).viewPadding;
		_padding = MediaQuery.of(context).padding.clamp(EdgeInsets.only(
			left: widget.left ? _padding!.left : 0,
			top: widget.top ? _padding!.top : 0,
			right: widget.right ? _padding!.right : 0,
			bottom: widget.bottom ? _padding!.bottom : 0
		), const EdgeInsets.all(double.nan)).resolve(TextDirection.ltr);
		_viewPadding = MediaQuery.of(context).padding.clamp(EdgeInsets.only(
			left: widget.left ? _viewPadding!.left : 0,
			top: widget.top ? _viewPadding!.top : 0,
			right: widget.right ? _viewPadding!.right : 0,
			bottom: widget.bottom ? _viewPadding!.bottom : 0
		), const EdgeInsets.all(double.nan)).resolve(TextDirection.ltr);
		return MediaQuery(
			data: MediaQuery.of(context).copyWith(
				padding: _padding,
				viewPadding: _viewPadding
			),
			child: widget.child
		);
	}
}
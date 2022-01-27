import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';

enum HoverPopupStyle {
	attached,
	floating
}

class HoverPopup<T> extends StatefulWidget {
	final Widget child;
	final Widget? popup;
	final Widget Function(T? value)? popupBuilder;
	final HoverPopupStyle style;
	final T Function()? setup;
	final Function(T?)? softSetup;
	final void Function(T?)? softCleanup;
	final void Function(T?)? cleanup;
	final Duration valueLifetime;
	final Offset? anchor;
	const HoverPopup({
		required this.child,
		this.popup,
		this.popupBuilder,
		required this.style,
		this.setup,
		this.softSetup,
		this.softCleanup,
		this.cleanup,
		this.valueLifetime = const Duration(seconds: 30),
		this.anchor,
		Key? key
	}) : super(key: key);
	
	@override
	_HoverPopupState<T> createState() => _HoverPopupState<T>();
}

class _HoverPopupState<T> extends State<HoverPopup<T>> {
	GlobalKey<_FloatingHoverPopupState>? _globalKey;
	OverlayEntry? _entry;
	T? _value;
	Timer? _cleanupTimer;

	@override
	Widget build(BuildContext context) {
		return MouseRegion(
			onEnter: (event) {
				if (_entry != null) {
					return;
				}
				final RenderBox? childBox = context.findRenderObject() as RenderBox;
				if (childBox == null || !childBox.attached) {
					return;
				}
				_cleanupTimer?.cancel();
				if (_value == null) {
					_value = widget.setup?.call();
				}
				else {
					widget.softSetup?.call(_value);
				}
				if (widget.style == HoverPopupStyle.attached) {
					final childTop = childBox.localToGlobal(Offset.zero).dy;
					final childBottom = childBox.localToGlobal(Offset(0, childBox.size.height)).dy;
					final childCenterHorizontal = childBox.localToGlobal(Offset(childBox.size.width / 2, 0)).dx;
					final topOfUsableSpace = MediaQuery.of(context).size.height / 2;
					final left = childBox.localToGlobal(Offset.zero).dx;
					final cblg = childBox.localToGlobal(Offset(childBox.size.width, 0)).dx;
					_entry = OverlayEntry(
						builder: (context) {
							final showOnRight = childCenterHorizontal > (MediaQuery.of(context).size.width / 2);
							return Positioned(
								right: showOnRight ? (MediaQuery.of(context).size.width - cblg) : null,
								left: showOnRight ? null : left,
								bottom: (childTop > topOfUsableSpace) ? MediaQuery.of(context).size.height - childTop : null,
								top: (childTop > topOfUsableSpace) ? null : childBottom,
								child: ConstrainedBox(
									constraints: BoxConstraints(
										maxWidth: MediaQuery.of(context).size.width / 2
									),
									child: widget.popupBuilder?.call(_value) ?? widget.popup
								)
							);
						}
					);
				}
				else if (widget.style == HoverPopupStyle.floating) {
					_globalKey = GlobalKey();
					_entry = OverlayEntry(
						builder: (context) => _FloatingHoverPopup(
							key: _globalKey,
							child: (widget.popupBuilder?.call(_value) ?? widget.popup)!,
							anchor: widget.anchor,
							initialMousePosition: event.position,
						)
					);
				}
				Overlay.of(context, rootOverlay: true)!.insert(_entry!);
			},
			onHover: (event) {
				_globalKey?.currentState?.updateMousePosition(event.position);
			},
			onExit: (event) {
				widget.softCleanup?.call(_value);
				_cleanupTimer = Timer(widget.valueLifetime, () {
					widget.cleanup?.call(_value);
					_value = null;
				});
				_entry?.remove();
				_entry = null;
			},
			child: widget.child
		);
	}

	@override
	void dispose() {
		super.dispose();
		_entry?.remove();
	}
}

class _FloatingHoverPopup extends StatefulWidget {
	final Widget child;
	final Offset initialMousePosition;
	final Offset? anchor;

	const _FloatingHoverPopup({
		required this.child,
		required this.initialMousePosition,
		this.anchor,
		Key? key
	}) : super(key: key);

	@override
	createState() => _FloatingHoverPopupState();
}

class _FloatingHoverPopupState extends State<_FloatingHoverPopup> {
	late Offset _mousePosition;

	@override
	void initState() {
		super.initState();
		_mousePosition = widget.initialMousePosition;
	}

	void updateMousePosition(Offset newMousePosition) {
		setState(() {
			_mousePosition = newMousePosition;
		});
	}

	@override
	Widget build(BuildContext context) {
		return IgnorePointer(
			child: CustomSingleChildLayout(
				delegate: _FloatingHoverPopupLayoutDelegate(
					mousePosition: _mousePosition,
					anchor: widget.anchor
				),
				child: widget.child
			)
		);
	}
}

const _idealCursorGap = 30;

class _FloatingHoverPopupLayoutDelegate extends SingleChildLayoutDelegate {
	// Assuming this is in the same coordinates
	final Offset mousePosition;
	final Offset? anchor;

	const _FloatingHoverPopupLayoutDelegate({
		required this.mousePosition,
		this.anchor
	});

	@override
	BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
		return ((anchor == null) ? constraints : constraints.enforce(BoxConstraints(
			maxWidth: max(constraints.maxWidth - mousePosition.dx - (anchor?.dx ?? 0), mousePosition.dx - (anchor?.dx ?? 0))
		))).loosen();
	}

	@override
	Offset getPositionForChild(Size size, Size childSize) {
		final double top = (anchor == null) ?
			(mousePosition.dy / size.height) * (size.height - childSize.height) :
			max(0, mousePosition.dy + anchor!.dy);
		if (mousePosition.dx > (size.width / 2)) {
			// Put image to left of cursor
			return Offset(
				max(0, mousePosition.dx - childSize.width - (anchor?.dx ?? _idealCursorGap)),
				top
			);
		}
		else {
			// Put image to right of cursor
			return Offset(
				min(size.width - childSize.width, mousePosition.dx + (anchor?.dx ?? _idealCursorGap)),
				top
			);
		}
	}

	@override
	bool shouldRelayout(_FloatingHoverPopupLayoutDelegate oldDelegate) {
		return mousePosition != oldDelegate.mousePosition;
	}
}
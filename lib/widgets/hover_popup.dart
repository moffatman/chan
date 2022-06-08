import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:chan/services/settings.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

enum HoverPopupStyle {
	attached,
	floating
}

class HoverPopup<T> extends StatefulWidget {
	final Widget child;
	final Widget? popup;
	final Widget Function(T? value, bool isWithinScalerBlurrer)? popupBuilder;
	final HoverPopupStyle style;
	final T Function()? setup;
	final T? Function(T?)? softSetup;
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
	createState() => _HoverPopupState<T>();
}

class _HoverPopupState<T> extends State<HoverPopup<T>> {
	GlobalKey<_FloatingHoverPopupState>? _globalKey;
	OverlayEntry? _entry;
	T? _value;
	Timer? _cleanupTimer;

	GlobalKey<_ScalerBlurrerState>? _touchGlobalKey;
	Offset? _touchStart;
	OverlayEntry? _touchEntry;
	late final LongPressGestureRecognizer recognizer;

	@override
	void initState() {
		super.initState();
		recognizer = LongPressGestureRecognizer(
			duration: kLongPressTimeout ~/ 2,
			postAcceptSlopTolerance: 99999
		)
		..onLongPressStart = _onLongPressStart
		..onLongPressMoveUpdate = _onLongPressMoveUpdate
		..onLongPressEnd = _onLongPressEnd
		..onLongPressCancel = _onLongPressDone
		..gestureSettings = context.findAncestorWidgetOfExactType<MediaQuery>()?.data.gestureSettings;
	}

	void _onLongPressStart(LongPressStartDetails details) {
		if (_touchEntry != null) {
			return;
		}
		final RenderBox? childBox = context.findRenderObject() as RenderBox?;
		if (childBox == null || !childBox.attached) {
			return;
		}
		_cleanupTimer?.cancel();
		if (_value == null) {
			_value = widget.setup?.call();
		}
		else {
			_value = widget.softSetup?.call(_value);
		}
		_touchGlobalKey = GlobalKey();
		_touchStart = details.globalPosition;
		final scale = 1 / context.read<EffectiveSettings>().interfaceScale;
		_touchEntry = OverlayEntry(
			builder: (context) => RootCustomScale(
				scale: scale,
				child: IgnorePointer(
					child: Center(
						child: _ScalerBlurrer(
							key: _touchGlobalKey,
							child: (widget.popupBuilder?.call(_value, true) ?? widget.popup)!
						)
					)
				)
			)
		);
		Overlay.of(context, rootOverlay: true)!.insert(_touchEntry!);
	}

	void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
		_touchGlobalKey?.currentState?.setScale(
			blur: 20 - (25 * max(details.localOffsetFromOrigin.dy / min(400, MediaQuery.of(context, MediaQueryAspect.height).size.height - _touchStart!.dy), (-1 * details.localOffsetFromOrigin.dy) / min(400, _touchStart!.dy)).abs().clamp(0, 1)),
			scale: 0.1 + (1.1 * (details.localOffsetFromOrigin.dx / min(400, MediaQuery.of(context, MediaQueryAspect.width).size.width)).abs()).clamp(0, 0.9)
		);
	}

	void _onLongPressDone() {
		widget.softCleanup?.call(_value);
		_cleanupTimer = Timer(widget.valueLifetime, () {
			widget.cleanup?.call(_value);
			_value = null;
		});
		_touchEntry?.remove();
		_touchEntry = null;
	}

	void _onLongPressEnd(LongPressEndDetails details) => _onLongPressDone();

	@override
	Widget build(BuildContext context) {
		return Listener(
			onPointerDown: (e) => recognizer.addPointer(e),
			child: MouseRegion(
				onEnter: (event) {
					if (!context.read<EffectiveSettings>().supportMouse.value) {
						return;
					}
					if (_entry != null) {
						return;
					}
					final RenderBox? childBox = context.findRenderObject() as RenderBox?;
					if (childBox == null || !childBox.attached) {
						return;
					}
					_cleanupTimer?.cancel();
					if (_value == null) {
						_value = widget.setup?.call();
					}
					else {
						_value = widget.softSetup?.call(_value);
					}
					if (widget.style == HoverPopupStyle.attached) {
						final childTop = childBox.localToGlobal(Offset.zero).dy;
						final childBottom = childBox.localToGlobal(Offset(0, childBox.size.height)).dy;
						final childCenterHorizontal = childBox.localToGlobal(Offset(childBox.size.width / 2, 0)).dx;
						final topOfUsableSpace = MediaQuery.of(context, MediaQueryAspect.height).size.height / 2;
						final left = childBox.localToGlobal(Offset.zero).dx;
						final cblg = childBox.localToGlobal(Offset(childBox.size.width, 0)).dx;
						_entry = OverlayEntry(
							builder: (context) {
								final showOnRight = childCenterHorizontal > (MediaQuery.of(context, MediaQueryAspect.width).size.width / 2);
								return Positioned(
									right: showOnRight ? (MediaQuery.of(context, MediaQueryAspect.width).size.width - cblg) : null,
									left: showOnRight ? null : left,
									bottom: (childTop > topOfUsableSpace) ? MediaQuery.of(context, MediaQueryAspect.height).size.height - childTop : null,
									top: (childTop > topOfUsableSpace) ? null : childBottom,
									child: ConstrainedBox(
										constraints: BoxConstraints(
											maxWidth: MediaQuery.of(context, MediaQueryAspect.width).size.width / 2
										),
										child: widget.popupBuilder?.call(_value, false) ?? widget.popup
									)
								);
							}
						);
					}
					else if (widget.style == HoverPopupStyle.floating) {
						_globalKey = GlobalKey();
						final scale = 1 / context.read<EffectiveSettings>().interfaceScale;
						_entry = OverlayEntry(
							builder: (context) => RootCustomScale(
								scale: scale,
								child: _FloatingHoverPopup(
									key: _globalKey,
									scale: scale,
									anchor: widget.anchor,
									initialMousePosition: event.position,
									child: (widget.popupBuilder?.call(_value, false) ?? widget.popup)!
								)
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
			)
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
	final double scale;

	const _FloatingHoverPopup({
		required this.child,
		required this.initialMousePosition,
		this.anchor,
		this.scale = 1.0,
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
		_mousePosition = widget.initialMousePosition.scale(widget.scale, widget.scale);
	}

	void updateMousePosition(Offset newMousePosition) {
		setState(() {
			_mousePosition = newMousePosition.scale(widget.scale, widget.scale);
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

class _ScalerBlurrer extends StatefulWidget {
	final Widget child;

	const _ScalerBlurrer({
		required this.child,
		Key? key
	}) : super(key: key);

	@override
	createState() => _ScalerBlurrerState();
}

class _ScalerBlurrerState extends State<_ScalerBlurrer> {
	double blur = 50.0;
	double scale = 0.1;

	void setScale({
		required double blur,
		required double scale
	}) {
		setState(() {
			this.blur = blur;
			this.scale = scale;
		});
	}

	@override
	Widget build(BuildContext context) {
		return ImageFiltered(
			imageFilter: ImageFilter.blur(
				sigmaX: blur,
				sigmaY: blur,
				tileMode: TileMode.decal
			),
			child: Transform.scale(
				scale: scale,
				alignment: Alignment.center,
				child: widget.child
			)
		);
	}
}
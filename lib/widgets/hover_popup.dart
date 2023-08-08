import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:chan/services/imageboard.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/util.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/scroll_tracker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

extension _MinimumScale on ImagePeekingSetting {
	double get minimumScale => switch (this) {
		ImagePeekingSetting.unsafe => 0.4,
		ImagePeekingSetting.ultraUnsafe => 1.0,
		_ => 0.1
	};

	bool get unsafe => switch (this) {
		ImagePeekingSetting.unsafe => true,
		ImagePeekingSetting.ultraUnsafe => true,
		_ => false
	};
}

enum HoverPopupStyle {
	attached,
	floating
}

enum HoverPopupPhase {
	start,
	end
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
	final bool Function(HoverPopupPhase)? alternativeHandler;
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
		this.alternativeHandler,
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
	bool _alternativelyHandled = false;

	GlobalKey<_ScalerBlurrerState>? _touchGlobalKey;
	Offset? _touchStart;
	OverlayEntry? _touchEntry;
	late final LongPressGestureRecognizer recognizer;
	PointerEvent? _wouldStart;
	Timer? _startTimer;
	DateTime? _startTime;

	@override
	void initState() {
		super.initState();
		ScrollTracker.instance.isScrolling.addListener(_onIsScrollingChange);
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

	void _onIsScrollingChange() {
		if (!ScrollTracker.instance.isScrolling.value && _wouldStart != null) {
			_maybeStart(_wouldStart!);
		}
		else if (ScrollTracker.instance.isScrolling.value) {
			_maybeStop();
		}
	}

	void _onTimer() {
		_startTimer = null;
		if (_wouldStart != null) {
			_maybeStart(_wouldStart!);
		}
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
		_touchGlobalKey = GlobalKey(debugLabel: '_HoverPopupState._touchGlobalKey');
		_touchStart = details.globalPosition;
		_touchEntry = OverlayEntry(
			builder: (_) => ImageboardScope(
				imageboardKey: null,
				imageboard: context.read<Imageboard>(),
				child:IgnorePointer(
					child: Center(
						child: _ScalerBlurrer(
							key: _touchGlobalKey,
							child: (widget.popupBuilder?.call(_value, true) ?? widget.popup)!
						)
					)
				)
			)
		);
		Overlay.of(context, rootOverlay: true).insert(_touchEntry!);
		lightHapticFeedback();
	}

	void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
		final setting = context.read<EffectiveSettings>().imagePeeking;
		final size = MediaQuery.sizeOf(context);
		final shortestSide = min(size.shortestSide, 400);
		_touchGlobalKey?.currentState?.setScale(
			blur: setting.unsafe ? 0 : 20 - (25 * max(details.localOffsetFromOrigin.dy / min(shortestSide, size.height - _touchStart!.dy), (-1 * details.localOffsetFromOrigin.dy) / min(shortestSide, _touchStart!.dy)).abs().clamp(0, 1)),
			scale: setting.minimumScale + (1.1 * ((setting.unsafe ? details.localOffsetFromOrigin.distance : details.localOffsetFromOrigin.dx) / shortestSide).abs()).clamp(0, 1 - setting.minimumScale)
		);
	}

	void _onLongPressDone() {
		widget.softCleanup?.call(_value);
		_cleanupTimer = Timer(widget.valueLifetime, () {
			widget.cleanup?.call(_value);
			_value = null;
		});
		_touchEntry?.remove();
		if (_touchEntry != null) {
			lightHapticFeedback();
		}
		_touchEntry = null;
	}

	void _onLongPressEnd(LongPressEndDetails details) => _onLongPressDone();

	void _maybeStart(PointerEvent event) {
		final settings = context.read<EffectiveSettings>();
		final now = DateTime.now();
		final startTime = _startTime ??= now.add(Duration(milliseconds: settings.hoverPopupDelayMilliseconds));
		if (startTime.isAfter(now)) {
			_startTimer ??= Timer(startTime.difference(now), _onTimer);
			_wouldStart = event;
			return;
		}
		if (ScrollTracker.instance.isScrolling.value) {
			_wouldStart = event;
			return;
		}
		if (!settings.supportMouse.value) {
			return;
		}
		if (_entry != null) {
			return;
		}
		if (_alternativelyHandled) {
			return;
		}
		if (widget.alternativeHandler != null) {
			_alternativelyHandled = widget.alternativeHandler?.call(HoverPopupPhase.start) ?? false;
			if (_alternativelyHandled) {
				return;
			}
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
			final topOfUsableSpace = MediaQuery.sizeOf(context).height / 2;
			final left = childBox.localToGlobal(Offset.zero).dx;
			final cblg = childBox.localToGlobal(Offset(childBox.size.width, 0)).dx;
			_entry = OverlayEntry(
				builder: (_) {
					final showOnRight = childCenterHorizontal > (MediaQuery.sizeOf(context).width / 2);
					return Positioned(
						right: showOnRight ? (MediaQuery.sizeOf(context).width - cblg) : null,
						left: showOnRight ? null : left,
						bottom: (childTop > topOfUsableSpace) ? MediaQuery.sizeOf(context).height - childTop : null,
						top: (childTop > topOfUsableSpace) ? null : childBottom,
						child: ConstrainedBox(
							constraints: BoxConstraints(
								maxWidth: MediaQuery.sizeOf(context).width / 2
							),
							child: ImageboardScope(
								imageboardKey: null,
								imageboard: context.read<Imageboard>(),
								child: (widget.popupBuilder?.call(_value, false) ?? widget.popup)!
							)
						)
					);
				}
			);
		}
		else if (widget.style == HoverPopupStyle.floating) {
			_globalKey = GlobalKey(debugLabel: '_HoverPopupState._globalKey');
			final scale = 1 / context.read<EffectiveSettings>().interfaceScale;
			_entry = OverlayEntry(
				builder: (_) => _FloatingHoverPopup(
					key: _globalKey,
					scale: scale,
					anchor: widget.anchor,
					initialMousePosition: event.position,
					child: ImageboardScope(
						imageboardKey: null,
						imageboard: context.read<Imageboard>(),
						child: (widget.popupBuilder?.call(_value, false) ?? widget.popup)!
					)
				)
			);
		}
		Overlay.of(context, rootOverlay: true).insert(_entry!);
	}

	void _maybeStop() {
		_startTimer?.cancel();
		_startTimer = null;
		_startTime = null;
		_wouldStart = null;
		if (_alternativelyHandled) {
			widget.alternativeHandler?.call(HoverPopupPhase.end);
			_alternativelyHandled = false;
		}
		if (_entry == null) {
			return;
		}
		widget.softCleanup?.call(_value);
		_cleanupTimer = Timer(widget.valueLifetime, () {
			widget.cleanup?.call(_value);
			_value = null;
		});
		_entry?.remove();
		_entry = null;
	}

	@override
	Widget build(BuildContext context) {
		return Listener(
			onPointerDown: (e) {
				if (context.read<EffectiveSettings>().imagePeeking != ImagePeekingSetting.disabled) {
					recognizer.addPointer(e);
				}
			},
			child: MouseRegion(
				onEnter: (event) {
					_maybeStart(event);
				},
				onHover: (event) {
					_globalKey?.currentState?.updateMousePosition(event.position);
				},
				onExit: (event) {
					_maybeStop();
				},
				child: widget.child
			)
		);
	}

	@override
	void dispose() {
		super.dispose();
		_maybeStop();
		ScrollTracker.instance.isScrolling.removeListener(_onIsScrollingChange);
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
	late double blur;
	late double scale;

	@override
	void initState() {
		super.initState();
		final setting = context.read<EffectiveSettings>().imagePeeking;
		scale = setting.minimumScale;
		blur = setting.unsafe ? 0 : 50;
	}

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
		return ClipRect(
			child: ImageFiltered(
				enabled: blur > 0.1,
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
			)
		);
	}
}
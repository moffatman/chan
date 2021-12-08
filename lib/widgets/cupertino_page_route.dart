// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This file is a modified copy of Flutter's cupertino `route.dart`
// with back swipe gesture accepted in the full width of app

import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:chan/widgets/weak_gesture_recognizer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

const double _kMinFlingVelocity = 1.0; // Screen widths per second.

const int _kMaxDroppedSwipePageForwardAnimationTime = 800; // Milliseconds.

const int _kMaxPageBackAnimationTime = 300; // Milliseconds.

final Animatable<Offset> _kRightMiddleTween = Tween<Offset>(
	begin: const Offset(1.0, 0.0),
	end: Offset.zero,
);

final Animatable<Offset> _kMiddleLeftTween = Tween<Offset>(
	begin: Offset.zero,
	end: const Offset(-1.0/3.0, 0.0),
);

final Animatable<Offset> _kBottomUpTween = Tween<Offset>(
	begin: const Offset(0.0, 1.0),
	end: Offset.zero,
);

final DecorationTween _kGradientShadowTween = DecorationTween(
	begin: _CupertinoEdgeShadowDecoration.none, // No decoration initially.
	end: const _CupertinoEdgeShadowDecoration(
		edgeGradient: LinearGradient(
			// Spans 5% of the page.
			begin: AlignmentDirectional(0.90, 0.0),
			end: AlignmentDirectional.centerEnd,
			// Eyeballed gradient used to mimic a drop shadow on the start side only.
			colors: <Color>[
				Color(0x00000000),
				Color(0x04000000),
				Color(0x12000000),
				Color(0x38000000),
			],
			stops: <double>[0.0, 0.3, 0.6, 1.0],
		),
	),
);

mixin CupertinoRouteTransitionMixin<T> on PageRoute<T> {
	@protected
	Widget buildContent(BuildContext context);

	String? get title;

	ValueNotifier<String?>? _previousTitle;

	ValueListenable<String?> get previousTitle {
		assert(
			_previousTitle != null,
			'Cannot read the previousTitle for a route that has not yet been installed',
		);
		return _previousTitle!;
	}

	@override
	void didChangePrevious(Route<dynamic>? previousRoute) {
		final String? previousTitleString = previousRoute is CupertinoRouteTransitionMixin
			? previousRoute.title : null;
		if (_previousTitle == null) {
			_previousTitle = ValueNotifier<String?>(previousTitleString);
		} else {
			_previousTitle!.value = previousTitleString;
		}
		super.didChangePrevious(previousRoute);
	}

	@override
	Duration get transitionDuration => (this is! FullWidthCupertinoPageRoute || (this as FullWidthCupertinoPageRoute).showAnimations) ? const Duration(milliseconds: 400) : Duration.zero;

	@override
	Color? get barrierColor => null;

	@override
	String? get barrierLabel => null;

	@override
	bool canTransitionTo(TransitionRoute<dynamic> nextRoute) {
		return nextRoute is CupertinoRouteTransitionMixin && !nextRoute.fullscreenDialog;
	}

	static bool isPopGestureInProgress(PageRoute<dynamic> route) {
		return route.navigator!.userGestureInProgress;
	}

	bool get popGestureInProgress => isPopGestureInProgress(this);

	bool get popGestureEnabled => _isPopGestureEnabled(this);

	static bool _isPopGestureEnabled<T>(PageRoute<T> route) {
		if (route.isFirst) {
			return false;
		}
		if (route.willHandlePopInternally) {
			return false;
		}
		if (route.hasScopedWillPopCallback) {
			return false;
		}
		if (route.fullscreenDialog) {
			return false;
		}
		if (route.animation!.status != AnimationStatus.completed) {
			return false;
		}
		if (route.secondaryAnimation!.status != AnimationStatus.dismissed) {
			return false;
		}
		if (isPopGestureInProgress(route)) {
			return false;
		}

		return true;
	}

	@override
	Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
		final Widget child = buildContent(context);
		final Widget result = Semantics(
			scopesRoute: true,
			explicitChildNodes: true,
			child: child,
		);
		return result;
	}

	static _CupertinoBackGestureController<T> _startPopGesture<T>(PageRoute<T> route) {
		assert(_isPopGestureEnabled(route));

		return _CupertinoBackGestureController<T>(
			navigator: route.navigator!,
			controller: route.controller!, // protected access
		);
	}

	static Widget buildPageTransitions<T>(
		PageRoute<T> route,
		BuildContext context,
		Animation<double> animation,
		Animation<double> secondaryAnimation,
		Widget child,
	) {
		final bool linearTransition = isPopGestureInProgress(route);
		if (route.fullscreenDialog) {
			return CupertinoFullscreenDialogTransition(
				primaryRouteAnimation: animation,
				secondaryRouteAnimation: secondaryAnimation,
				child: child,
				linearTransition: linearTransition,
			);
		} else {
			return CupertinoPageTransition(
				primaryRouteAnimation: animation,
				secondaryRouteAnimation: secondaryAnimation,
				linearTransition: linearTransition,
				child: _CupertinoBackGestureDetector<T>(
					enabledCallback: () => _isPopGestureEnabled<T>(route),
					onStartPopGesture: () => _startPopGesture<T>(route),
					child: child,
				),
			);
		}
	}

	@override
	Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
		return buildPageTransitions<T>(this, context, animation, secondaryAnimation, child);
	}
}

class FullWidthCupertinoPageRoute<T> extends PageRoute<T> with CupertinoRouteTransitionMixin<T> {
	final bool showAnimations;
	FullWidthCupertinoPageRoute({
		required this.builder,
		this.title,
		RouteSettings? settings,
		this.maintainState = true,
		required this.showAnimations,
		bool fullscreenDialog = false,
	}) : super(settings: settings, fullscreenDialog: fullscreenDialog) {
		assert(opaque);
	}

	final WidgetBuilder builder;

	@override
	Widget buildContent(BuildContext context) => builder(context);

	@override
	final String? title;

	@override
	final bool maintainState;

	@override
	String get debugLabel => '${super.debugLabel}(${settings.name})';
}

class _PageBasedCupertinoPageRoute<T> extends PageRoute<T> with CupertinoRouteTransitionMixin<T> {
	_PageBasedCupertinoPageRoute({
		required CupertinoPage<T> page,
	}) : super(settings: page) {
		assert(opaque);
	}

	CupertinoPage<T> get _page => settings as CupertinoPage<T>;

	@override
	Widget buildContent(BuildContext context) => _page.child;

	@override
	String? get title => _page.title;

	@override
	bool get maintainState => _page.maintainState;

	@override
	bool get fullscreenDialog => _page.fullscreenDialog;

	@override
	String get debugLabel => '${super.debugLabel}(${_page.name})';
}

class CupertinoPage<T> extends Page<T> {
	const CupertinoPage({
		required this.child,
		this.maintainState = true,
		this.title,
		this.fullscreenDialog = false,
		LocalKey? key,
		String? name,
		Object? arguments,
	}) : super(key: key, name: name, arguments: arguments);

	final Widget child;

	final String? title;

	final bool maintainState;

	final bool fullscreenDialog;

	@override
	Route<T> createRoute(BuildContext context) {
		return _PageBasedCupertinoPageRoute<T>(page: this);
	}
}

class CupertinoPageTransition extends StatelessWidget {
	CupertinoPageTransition({
		Key? key,
		required Animation<double> primaryRouteAnimation,
		required Animation<double> secondaryRouteAnimation,
		required this.child,
		required bool linearTransition,
	}) : _primaryPositionAnimation =
			(linearTransition
				? primaryRouteAnimation
				: CurvedAnimation(
					parent: primaryRouteAnimation,
					curve: Curves.linearToEaseOut,
					reverseCurve: Curves.easeInToLinear,
				)
			).drive(_kRightMiddleTween),
		_secondaryPositionAnimation =
			(linearTransition
				? secondaryRouteAnimation
				: CurvedAnimation(
					parent: secondaryRouteAnimation,
					curve: Curves.linearToEaseOut,
					reverseCurve: Curves.easeInToLinear,
				)
			).drive(_kMiddleLeftTween),
		_primaryShadowAnimation =
			(linearTransition
				? primaryRouteAnimation
				: CurvedAnimation(
					parent: primaryRouteAnimation,
					curve: Curves.linearToEaseOut,
				)
			).drive(_kGradientShadowTween),
		super(key: key);

	final Animation<Offset> _primaryPositionAnimation;
	final Animation<Offset> _secondaryPositionAnimation;
	final Animation<Decoration> _primaryShadowAnimation;

	final Widget child;

	@override
	Widget build(BuildContext context) {
		assert(debugCheckHasDirectionality(context));
		final TextDirection textDirection = Directionality.of(context);
		return SlideTransition(
			position: _secondaryPositionAnimation,
			textDirection: textDirection,
			transformHitTests: false,
			child: SlideTransition(
				position: _primaryPositionAnimation,
				textDirection: textDirection,
				child: DecoratedBoxTransition(
					decoration: _primaryShadowAnimation,
					child: child,
				),
			),
		);
	}
}

class CupertinoFullscreenDialogTransition extends StatelessWidget {
	CupertinoFullscreenDialogTransition({
		Key? key,
		required Animation<double> primaryRouteAnimation,
		required Animation<double> secondaryRouteAnimation,
		required this.child,
		required bool linearTransition,
	}) : _positionAnimation = CurvedAnimation(
			parent: primaryRouteAnimation,
			curve: Curves.linearToEaseOut,
			reverseCurve: Curves.linearToEaseOut.flipped,
		).drive(_kBottomUpTween),
		_secondaryPositionAnimation =
			(linearTransition
				? secondaryRouteAnimation
				: CurvedAnimation(
					parent: secondaryRouteAnimation,
					curve: Curves.linearToEaseOut,
					reverseCurve: Curves.easeInToLinear,
				)
			).drive(_kMiddleLeftTween),
		super(key: key);

	final Animation<Offset> _positionAnimation;
	final Animation<Offset> _secondaryPositionAnimation;

	final Widget child;

	@override
	Widget build(BuildContext context) {
		assert(debugCheckHasDirectionality(context));
		final TextDirection textDirection = Directionality.of(context);
		return SlideTransition(
			position: _secondaryPositionAnimation,
			textDirection: textDirection,
			transformHitTests: false,
			child: SlideTransition(
				position: _positionAnimation,
				child: child,
			),
		);
	}
}

class _CupertinoBackGestureDetector<T> extends StatefulWidget {
	const _CupertinoBackGestureDetector({
		Key? key,
		required this.enabledCallback,
		required this.onStartPopGesture,
		required this.child,
	}) : super(key: key);

	final Widget child;

	final ValueGetter<bool> enabledCallback;

	final ValueGetter<_CupertinoBackGestureController<T>> onStartPopGesture;

	@override
	_CupertinoBackGestureDetectorState<T> createState() => _CupertinoBackGestureDetectorState<T>();
}

class _CupertinoBackGestureDetectorState<T> extends State<_CupertinoBackGestureDetector<T>> {
	_CupertinoBackGestureController<T>? _backGestureController;

	late WeakHorizontalDragGestureRecognizer _recognizer;

	@override
	void initState() {
		super.initState();
		// This value was estimated from some iOS behaviours
		_recognizer = WeakHorizontalDragGestureRecognizer(weakness: 2.5, sign: 1, debugOwner: this)
		..onStart = _handleDragStart
		..onUpdate = _handleDragUpdate
		..onEnd = _handleDragEnd
		..onCancel = _handleDragCancel;
	}

	@override
	void dispose() {
		_recognizer.dispose();
		super.dispose();
	}

	void _handleDragStart(DragStartDetails details) {
		assert(mounted);
		assert(_backGestureController == null);
		_backGestureController = widget.onStartPopGesture();
	}

	void _handleDragUpdate(DragUpdateDetails details) {
		assert(mounted);
		assert(_backGestureController != null);
		_backGestureController!.dragUpdate(_convertToLogical(details.primaryDelta! / context.size!.width));
	}

	void _handleDragEnd(DragEndDetails details) {
		assert(mounted);
		assert(_backGestureController != null);
		_backGestureController!.dragEnd(_convertToLogical(details.velocity.pixelsPerSecond.dx / context.size!.width));
		_backGestureController = null;
	}

	void _handleDragCancel() {
		assert(mounted);
		_backGestureController?.dragEnd(0.0);
		_backGestureController = null;
	}

	void _handlePointerDown(PointerDownEvent event) {
		if (widget.enabledCallback()) {
			_recognizer.addPointer(event);
		}
	}

	void _handlePointerPanZoomStart(PointerPanZoomStartEvent event) {
		if (widget.enabledCallback()) {
			_recognizer.addPointerPanZoom(event);
		}
	}

	double _convertToLogical(double value) {
		switch (Directionality.of(context)) {
			case TextDirection.rtl:
				return -value;
			case TextDirection.ltr:
				return value;
		}
	}

	@override
	Widget build(BuildContext context) {
		assert(debugCheckHasDirectionality(context));
		return Stack(
			fit: StackFit.passthrough,
			children: <Widget>[
				widget.child,
				PositionedDirectional(
					start: 0.0,
					width: MediaQuery.of(context).size.width,
					top: 0.0,
					bottom: 0.0,
					child: Listener(
						onPointerDown: _handlePointerDown,
						onPointerPanZoomStart: _handlePointerPanZoomStart,
						behavior: HitTestBehavior.translucent,
					),
				),
			],
		);
	}
}

class _CupertinoBackGestureController<T> {
	_CupertinoBackGestureController({
		required this.navigator,
		required this.controller,
	}) {
		navigator.didStartUserGesture();
	}

	final AnimationController controller;
	final NavigatorState navigator;

	void dragUpdate(double delta) {
		controller.value -= delta;
	}

	void dragEnd(double velocity) {
		const Curve animationCurve = Curves.fastLinearToSlowEaseIn;
		final bool animateForward;

		if (velocity.abs() >= _kMinFlingVelocity) {
			animateForward = velocity <= 0;
		}
		else {
			animateForward = controller.value > 0.5;
		}

		if (animateForward) {
			final int droppedPageForwardAnimationTime = min(
				lerpDouble(_kMaxDroppedSwipePageForwardAnimationTime, 0, controller.value)!.floor(),
				_kMaxPageBackAnimationTime,
			);
			controller.animateTo(1.0, duration: Duration(milliseconds: droppedPageForwardAnimationTime), curve: animationCurve);
		} else {
			navigator.pop();

			if (controller.isAnimating) {
				final int droppedPageBackAnimationTime = lerpDouble(0, _kMaxDroppedSwipePageForwardAnimationTime, controller.value)!.floor();
				controller.animateBack(0.0, duration: Duration(milliseconds: droppedPageBackAnimationTime), curve: animationCurve);
			}
		}

		if (controller.isAnimating) {
			late AnimationStatusListener animationStatusCallback;
			animationStatusCallback = (AnimationStatus status) {
				navigator.didStopUserGesture();
				controller.removeStatusListener(animationStatusCallback);
			};
			controller.addStatusListener(animationStatusCallback);
		} else {
			navigator.didStopUserGesture();
		}
	}
}

class _CupertinoEdgeShadowDecoration extends Decoration {
	const _CupertinoEdgeShadowDecoration({ this.edgeGradient });

	static const _CupertinoEdgeShadowDecoration none =
		_CupertinoEdgeShadowDecoration();

	final LinearGradient? edgeGradient;

	static _CupertinoEdgeShadowDecoration? lerp(
		_CupertinoEdgeShadowDecoration? a,
		_CupertinoEdgeShadowDecoration? b,
		double t,
	) {
		if (a == null && b == null) {
			return null;
		}
		return _CupertinoEdgeShadowDecoration(
			edgeGradient: LinearGradient.lerp(a?.edgeGradient, b?.edgeGradient, t),
		);
	}

	@override
	_CupertinoEdgeShadowDecoration lerpFrom(Decoration? a, double t) {
		if (a is _CupertinoEdgeShadowDecoration) {
			return _CupertinoEdgeShadowDecoration.lerp(a, this, t)!;
		}
		return _CupertinoEdgeShadowDecoration.lerp(null, this, t)!;
	}

	@override
	_CupertinoEdgeShadowDecoration lerpTo(Decoration? b, double t) {
		if (b is _CupertinoEdgeShadowDecoration) {
			return _CupertinoEdgeShadowDecoration.lerp(this, b, t)!;
		}
		return _CupertinoEdgeShadowDecoration.lerp(this, null, t)!;
	}

	@override
	_CupertinoEdgeShadowPainter createBoxPainter([ VoidCallback? onChanged ]) {
		return _CupertinoEdgeShadowPainter(this, onChanged);
	}

	@override
	bool operator ==(Object other) {
		if (other.runtimeType != runtimeType) {
			return false;
		}
		return other is _CupertinoEdgeShadowDecoration
			&& other.edgeGradient == edgeGradient;
	}

	@override
	int get hashCode => edgeGradient.hashCode;

	@override
	void debugFillProperties(DiagnosticPropertiesBuilder properties) {
		super.debugFillProperties(properties);
		properties.add(DiagnosticsProperty<LinearGradient>('edgeGradient', edgeGradient));
	}
}

class _CupertinoEdgeShadowPainter extends BoxPainter {
	_CupertinoEdgeShadowPainter(
		this._decoration,
		VoidCallback? onChange,
	) : super(onChange);

	final _CupertinoEdgeShadowDecoration _decoration;

	@override
	void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
		final LinearGradient? gradient = _decoration.edgeGradient;
		if (gradient == null) {
			return;
		}
		final TextDirection? textDirection = configuration.textDirection;
		assert(textDirection != null);
		final double deltaX;
		switch (textDirection!) {
			case TextDirection.rtl:
				deltaX = configuration.size!.width;
				break;
			case TextDirection.ltr:
				deltaX = -configuration.size!.width;
				break;
		}
		final Rect rect = (offset & configuration.size!).translate(deltaX, 0.0);
		final Paint paint = Paint()
			..shader = gradient.createShader(rect, textDirection: textDirection);

		canvas.drawRect(rect, paint);
	}
}
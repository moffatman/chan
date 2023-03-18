import 'dart:io';
import 'dart:math' as math;

import 'package:chan/widgets/weak_gesture_recognizer.dart';
import 'package:chan/widgets/weak_navigator.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

class SliderBuilder extends StatefulWidget {
	final Widget Function(BuildContext context, double factor) builder;
  final Widget popup;
	final double activationDistance;
	const SliderBuilder({
		required this.builder,
		required this.popup,
		this.activationDistance = 50,
		Key? key
	}) : super(key: key);
	@override
	createState() => _SliderBuilderState();
}

class _SliderBuilderState extends State<SliderBuilder> {
	// We need to use a horizontal drag gesture recognizer to claim
	// But the recognizer which does the tracking should be a pan recognizer
	// So that vertical ending gestures will have their velocity set correctly
	late final WeakHorizontalDragGestureRecognizer _claimingRecognizer;
	late final WeakPanGestureRecognizer _recognizingRecognizer;
	late final GestureArenaTeam _team;
	VoidCallback? pop;
	bool _disposing = false;
	bool _disposeDelayed = false;
	double factor = 0;
	bool insertedEarly = false;

	@override
	void initState() {
		super.initState();
		_team = GestureArenaTeam();
		_recognizingRecognizer = WeakPanGestureRecognizer(weakness: 9999, allowedToAccept: false, debugOwner: this)
		..onUpdate = _handleDragUpdate
		..onEnd = _handleDragEnd
		..onCancel = _handleDragCancel
		..team = _team
		..gestureSettings = context.findAncestorWidgetOfExactType<MediaQuery>()?.data.gestureSettings;
		_team.captain = _recognizingRecognizer;
		_claimingRecognizer = WeakHorizontalDragGestureRecognizer(weakness: 2, sign: -1, debugOwner: this)
		..onStart = (e) {}
		..team = _team
		..gestureSettings = context.findAncestorWidgetOfExactType<MediaQuery>()?.data.gestureSettings;
	}

	void _handleDragUpdate(DragUpdateDetails details) {
		if (!insertedEarly) {
			pop = WeakNavigator.pushAndReturnCallback(context, widget.popup);
			insertedEarly = true;
		}
		if (mounted) {
			setState(() {
				factor -= details.delta.dx / widget.activationDistance;
			});
		}
	}

	void _handleDragEnd(DragEndDetails details) {
		if (details.velocity.pixelsPerSecond.direction.abs() > math.pi * 0.75) {
			if (!insertedEarly) {
				WeakNavigator.push(context, widget.popup);
			}
		}
		else if (details.velocity != Velocity.zero) {
			if (pop != null) {
				pop?.call();
			}
			else {
				WeakNavigator.pop(context);
			}
		}
		pop = null;
		if (_disposeDelayed) {
			_claimingRecognizer.dispose();
			_recognizingRecognizer.dispose();
		}
		if (mounted) {
			setState(() {
				factor = 0;
				insertedEarly = false;
			});
		}
	}

	void _handleDragCancel() {
		pop = null;
		if (_disposeDelayed) {
			_claimingRecognizer.dispose();
			_recognizingRecognizer.dispose();
		}
		if (mounted && !_disposing) {
			setState(() {
				factor = 0;
			});
		}
	}

	@override
	Widget build(BuildContext context) {
		return Listener(
			child: TweenAnimationBuilder<double>(
				tween: Tween<double>(begin: 0, end: factor),
				curve: Curves.easeOutQuart,
				duration: const Duration(milliseconds: 50),
				builder: (context, smoothedFactor, child) => widget.builder(context, smoothedFactor)
			),
			onPointerDown: (e) {
				if (eventTooCloseToEdge(e)) {
					return;
				}
				_recognizingRecognizer.addPointer(e);
				_claimingRecognizer.addPointer(e);
			},
			onPointerPanZoomStart: (e) {
				_recognizingRecognizer.addPointerPanZoom(e);
				_claimingRecognizer.addPointerPanZoom(e);
			}
		);
	}

	@override
	void dispose() {
		if (pop == null) {
			_disposing = true;
			_recognizingRecognizer.dispose();
			_claimingRecognizer.dispose();
		}
		else {
			_disposeDelayed = true;
		}
		super.dispose();
	}
}
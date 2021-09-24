import 'dart:math' as math;

import 'package:chan/widgets/weak_gesture_recognizer.dart';
import 'package:chan/widgets/weak_navigator.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

class SliderBuilder extends StatefulWidget {
	final Widget Function(BuildContext context, double factor) builder;
  final Widget popup;
	final double activationDistance;
	SliderBuilder({
		required this.builder,
		required this.popup,
		this.activationDistance = 50
	});
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
		..team = _team;
		_team.captain = _recognizingRecognizer;
		_claimingRecognizer = WeakHorizontalDragGestureRecognizer(weakness: 2, sign: -1, debugOwner: this)
		..onStart = (e) {}
		..team = _team;
	}

	void _handleDragUpdate(DragUpdateDetails details) {
		if (!insertedEarly) {
			WeakNavigator.push(context, widget.popup);
			insertedEarly = true;
		}
		setState(() {
			factor -= details.delta.dx / widget.activationDistance;
		});
	}

	void _handleDragEnd(DragEndDetails details) {
		if ((details.velocity == Velocity.zero) || (details.velocity.pixelsPerSecond.direction.abs() > math.pi * 0.75)) {
			if (!insertedEarly) {
				WeakNavigator.push(context, widget.popup);
			}
		}
		else {
			WeakNavigator.pop(context);
		}
		setState(() {
			factor = 0;
			insertedEarly = false;
		});
	}

	void _handleDragCancel() {
		setState(() {
			factor = 0;
		});
	}

	@override
	Widget build(BuildContext context) {
		return Listener(
			child: TweenAnimationBuilder<double>(
				tween: Tween<double>(begin: 0, end: factor),
				curve: Curves.easeOutQuart,
				duration: const Duration(milliseconds: 50),
				builder: (context, _factor, child) => widget.builder(context, _factor)
			),
			onPointerDown: (e) {
				_recognizingRecognizer.addPointer(e);
				_claimingRecognizer.addPointer(e);
			}
		);
	}
}
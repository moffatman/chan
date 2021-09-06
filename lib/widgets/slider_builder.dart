import 'package:chan/widgets/weak_gesture_recognizer.dart';
import 'package:flutter/widgets.dart';

class SliderBuilder extends StatefulWidget {
	final Widget Function(BuildContext context, double factor) builder;
	final VoidCallback onActivation;
	final double activationDistance;
	SliderBuilder({
		required this.builder,
		required this.onActivation,
		this.activationDistance = 50
	});
	@override
	createState() => _SliderBuilderState();
}

class _SliderBuilderState extends State<SliderBuilder> {
	late final WeakHorizontalDragGestureRecognizer _recognizer;
	double factor = 0;

	@override
	void initState() {
		super.initState();
		_recognizer = WeakHorizontalDragGestureRecognizer(weakness: 2, sign: -1, debugOwner: this)
		..onStart = _handleDragStart
		..onUpdate = _handleDragUpdate
		..onEnd = _handleDragEnd
		..onCancel = _handleDragCancel;
	}

	void _handleDragStart(DragStartDetails details) {
		
	}

	void _handleDragUpdate(DragUpdateDetails details) {
		setState(() {
			factor -= (details.primaryDelta ?? 0) / widget.activationDistance;
		});
	}

	void _handleDragEnd(DragEndDetails details) {
		if (factor > 1) {
			widget.onActivation();
		}
		setState(() {
			factor = 0;
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
			child: widget.builder(context, factor),
			onPointerDown: (e) => _recognizer.addPointer(e)
		);
	}
}
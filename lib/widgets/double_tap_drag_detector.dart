import 'package:chan/widgets/double_tap_drag_recognizer.dart';
import 'package:flutter/widgets.dart';

class DoubleTapDragDetector extends StatefulWidget {
	final Widget child;
	final bool Function()? shouldStart;
	final GestureDoubleTapDragUpdateCallback? onDoubleTapDrag;
	final VoidCallback? onDoubleTapDragEnd;

	const DoubleTapDragDetector({
		required this.child,
		this.shouldStart,
		this.onDoubleTapDrag,
		this.onDoubleTapDragEnd,
		Key? key
	}) : super(key: key);

	@override
	createState() => _DoubleTapDragDetectorState();
}

class _DoubleTapDragDetectorState extends State<DoubleTapDragDetector> {
	late final recognizer = DoubleTapDragGestureRecognizer()
		..onDoubleTapDrag = _onUpdate
		..onDoubleTap = _onEnd
		..gestureSettings = context.findAncestorWidgetOfExactType<MediaQuery>()?.data.gestureSettings;

	void _onUpdate(DoubleTapDragUpdateDetails details) {
		widget.onDoubleTapDrag?.call(details);
	}

	void _onEnd() {
		widget.onDoubleTapDragEnd?.call();
	}

	@override
	Widget build(BuildContext context) {
		return Listener(
			onPointerDown: (event) {
				if (widget.shouldStart?.call() ?? true) {
					recognizer.addPointer(event);
				}
			},
			child: widget.child
		);
	}
}
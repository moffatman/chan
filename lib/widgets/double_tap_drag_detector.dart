import 'package:chan/widgets/double_tap_drag_recognizer.dart';
import 'package:flutter/widgets.dart';

class DoubleTapDragDetector extends StatefulWidget {
	final Widget child;
	final bool Function()? shouldStart;
	final GestureDoubleTapDragUpdateCallback? onDoubleTapDrag;
	final GestureDoubleTapDragUpdateCallback? onDoubleTapDragEnd;
	final VoidCallback? onSingleTap;

	const DoubleTapDragDetector({
		required this.child,
		this.shouldStart,
		this.onDoubleTapDrag,
		this.onDoubleTapDragEnd,
		this.onSingleTap,
		Key? key
	}) : super(key: key);

	@override
	createState() => _DoubleTapDragDetectorState();
}

class _DoubleTapDragDetectorState extends State<DoubleTapDragDetector> {
	late final DoubleTapDragGestureRecognizer recognizer;
	
	@override
	void initState() {
		super.initState();
		recognizer = DoubleTapDragGestureRecognizer()
			..onDoubleTapDrag = _onUpdate
			..onDoubleTapDone = _onEnd
			..onDoubleTapCancel = _onCancel
			..gestureSettings = context.findAncestorWidgetOfExactType<MediaQuery>()?.data.gestureSettings;
	}
	
	void _onCancel() {
		widget.onSingleTap?.call();
	}

	void _onUpdate(DoubleTapDragUpdateDetails details) {
		widget.onDoubleTapDrag?.call(details);
	}

	void _onEnd(DoubleTapDragUpdateDetails details) {
		widget.onDoubleTapDragEnd?.call(details);
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

	@override
	void dispose() {
		super.dispose();
		recognizer.dispose();
	}
}
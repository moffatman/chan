import 'dart:math' as math;

import 'package:chan/services/util.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/util.dart';
import 'package:chan/widgets/weak_gesture_recognizer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

enum PullTabPosition {
	left,
	right
}

class PullTabTab {
	final Widget child;
	final VoidCallback onActivation;
	const PullTabTab({
		required this.child,
		required this.onActivation
	});
}

class PullTab extends StatefulWidget {
	final Widget child;
	final PullTabTab? tab;
	final PullTabPosition position;

	const PullTab({
		required this.child,
		required this.tab,
		this.position = PullTabPosition.right,
		Key? key
	}) : super(key: key);
	@override
	createState() => _PullTabState();
}

class _PullTabState extends State<PullTab> {
	// We need to use a horizontal drag gesture recognizer to claim
	// But the recognizer which does the tracking should be a pan recognizer
	// So that vertical ending gestures will have their velocity set correctly
	late final WeakHorizontalDragGestureRecognizer _claimingRecognizer;
	late final WeakPanGestureRecognizer _recognizingRecognizer;
	late final GestureArenaTeam _team;
	double dragDistance = 0;
	double scrollDistance = 0;

	@override
	void initState() {
		super.initState();
		_team = GestureArenaTeam();
		_recognizingRecognizer = WeakPanGestureRecognizer(weakness: 9999, allowedToAccept: false, debugOwner: this)
		..onStart = _handleDragStart
		..onUpdate = _handleDragUpdate
		..onEnd = _handleDragEnd
		..onCancel = _handleDragCancel
		..team = _team
		..gestureSettings = context.findAncestorWidgetOfExactType<MediaQuery>()?.data.gestureSettings;
		_team.captain = _recognizingRecognizer;
		_claimingRecognizer = WeakHorizontalDragGestureRecognizer(weakness: 2, sign: rtl ? -1 : 1, debugOwner: this)
		..onStart = (e) {}
		..team = _team
		..gestureSettings = context.findAncestorWidgetOfExactType<MediaQuery>()?.data.gestureSettings;
	}

	double get width => context.findRenderObject()?.paintBounds.width ?? MediaQuery.of(context).size.width;
	double get height => context.findRenderObject()?.paintBounds.height ?? MediaQuery.of(context).size.height;

	bool get disabled => widget.tab == null;
	bool get rtl => widget.position == PullTabPosition.left;
	bool get inActive => dragDistance.abs() > (width / 6);

	@override
	void didUpdateWidget(PullTab oldWidget) {
		super.didUpdateWidget(oldWidget);
		_claimingRecognizer.sign = rtl ? -1 : 1;
	}

	void _handleDragStart(DragStartDetails details) {
		scrollDistance = details.localPosition.dy - (height / 2);
	}

	void _handleDragUpdate(DragUpdateDetails details) {
		if (disabled) return;
		setState(() {
			dragDistance += details.delta.dx;
			//scrollDistance += details.delta.dy;
		});
	}

	void _handleDragEnd(DragEndDetails details) {
		if (disabled) return;
		if ((inActive || details.velocity.pixelsPerSecond.distance > kMinFlingVelocity) &&
				((rtl && (details.velocity.pixelsPerSecond.direction.abs() > math.pi * 0.75 || details.velocity.pixelsPerSecond.distance == 0)) ||
				 (!rtl && details.velocity.pixelsPerSecond.direction.abs() < math.pi * 0.25))) {
			lightHapticFeedback();
			try {
				widget.tab?.onActivation();
			}
			catch (e) {
				alertError(context, e.toStringDio());
			}
		}
		setState(() {
			dragDistance = 0;
		});
	}

	void _handleDragCancel() {
		setState(() {
			dragDistance = 0;
		});
	}

	@override
	Widget build(BuildContext context) {
		return Listener(
			behavior: HitTestBehavior.translucent,
			child: Stack(
				fit: StackFit.expand,
				children: [
					widget.child,
					Visibility(
						visible: dragDistance != 0,
						child: IgnorePointer(
							child: Transform.translate(
								offset: Offset((rtl ? width : -width) + dragDistance.clamp(-300, 300), scrollDistance),
								child: Align(
									alignment: Alignment.centerRight,
									child: Container(
										width: double.infinity,
										height: 150,
										alignment: rtl ? Alignment.centerLeft : Alignment.centerRight,
										padding: const EdgeInsets.symmetric(horizontal: 16),
										decoration: BoxDecoration(
											borderRadius: rtl ?
												const BorderRadius.only(topLeft: Radius.circular(32), bottomLeft: Radius.circular(32)) :
												const BorderRadius.only(topRight: Radius.circular(32), bottomRight: Radius.circular(32)),
											color: CupertinoTheme.of(context).textTheme.actionTextStyle.color
										),
										child: Row(
											mainAxisSize: MainAxisSize.min,
											children: [
												if (rtl) TweenAnimationBuilder<double>(
													duration: const Duration(milliseconds: 350),
													curve: Curves.ease,
													tween: Tween(begin: 0, end: inActive ? math.pi : 0),
													builder: (context, angle, child) => Transform.rotate(
														angle: angle,
														child: child
													),
													child: const Icon(Icons.arrow_back)
												),
												const SizedBox(width: 16),
												widget.tab?.child ?? const Text('Pick'),
												const SizedBox(width: 16),
												if (!rtl) TweenAnimationBuilder<double>(
													duration: const Duration(milliseconds: 350),
													curve: Curves.ease,
													tween: Tween(begin: 0, end: inActive ? math.pi : 0),
													builder: (context, angle, child) => Transform.rotate(
														angle: angle,
														child: child
													),
													child: const Icon(Icons.arrow_forward)
												)
											]
										)
									)
								)
							)
						)
					)
				]
			),
			onPointerDown: (e) {
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
		super.dispose();
		_recognizingRecognizer.dispose();
		_claimingRecognizer.dispose();
	}
}
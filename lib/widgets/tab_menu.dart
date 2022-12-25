import 'dart:async';

import 'package:chan/services/settings.dart';
import 'package:chan/services/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TabMenuAction {
	final IconData icon;
	final VoidCallback onPressed;
	final bool isDestructiveAction;

	const TabMenuAction({
		required this.icon,
		required this.onPressed,
		this.isDestructiveAction = false
	});
}

class _TabMenuOverlay extends StatefulWidget {
	final Rect origin;
	final AxisDirection direction;
	final List<TabMenuAction> actions;
	final VoidCallback onDone;

	const _TabMenuOverlay({
		required this.origin,
		required this.direction,
		required this.actions,
		required this.onDone
	});
	
	@override
	createState() => _TabMenuOverlayState();
}

class _TabMenuOverlayState extends State<_TabMenuOverlay> with TickerProviderStateMixin {
	Size? lastSize;
	late final AnimationController _animationController;
	late final Animation<double> _animation;
	bool fakeDone = false;

	@override
	void initState() {
		super.initState();
		_animationController = AnimationController(
			vsync: this,
			duration: const Duration(milliseconds: 150)
		)..forward();
		_animation = CurvedAnimation(
			parent: _animationController,
			curve: Curves.ease
		);
	}

	void onDone() async {
		setState(() {
			fakeDone = true;
		});
		lightHapticFeedback();
		await _animationController.reverse().orCancel;
		widget.onDone();
	}
	
	@override
	Widget build(BuildContext context) {
		final screenSize = MediaQuery.of(context).size;
		lastSize ??= screenSize;
		if (screenSize != lastSize) {
			// window was resized
			onDone();
		}
		BorderRadius borderRadius;
		switch (widget.direction) {
			case AxisDirection.up:
				borderRadius = const BorderRadius.only(
					topLeft: Radius.circular(16),
					topRight: Radius.circular(16)
				);
				break;
			case AxisDirection.right:
				borderRadius = const BorderRadius.only(
					topRight: Radius.circular(16),
					bottomRight: Radius.circular(16)
				);
				break;
			case AxisDirection.down:
				borderRadius = const BorderRadius.only(
					bottomLeft: Radius.circular(16),
					bottomRight: Radius.circular(16)
				);
				break;
			case AxisDirection.left:
				borderRadius = const BorderRadius.only(
					topLeft: Radius.circular(16),
					bottomLeft: Radius.circular(16)
				);
				break;
		}
		final menu = Container(
			decoration: BoxDecoration(
				color: CupertinoTheme.of(context).barBackgroundColor,
				borderRadius: borderRadius
			),
			child: Flex(
				direction: widget.direction == AxisDirection.down || widget.direction == AxisDirection.up ? Axis.vertical : Axis.horizontal,
				children: widget.actions.map((action) => CupertinoButton(
					onPressed: () {
						action.onPressed();
						onDone();
					},
					child: Icon(action.icon, color: action.isDestructiveAction ? Colors.red : null)
				)).toList()
			)
		);
		return IgnorePointer(
			ignoring: fakeDone,
			child: AnimatedBuilder(
				animation: _animation,
				child: FadeTransition(
					opacity: _animation,
					child: menu
				),
				builder: (context, child) => Stack(
					fit: StackFit.expand,
					children: [
						GestureDetector(
							onTap: onDone,
							behavior: HitTestBehavior.opaque
						),
						if (widget.direction == AxisDirection.up) Positioned(
							left: widget.origin.left,
							width: widget.origin.width,
							bottom: (screenSize.height / context.select<EffectiveSettings, double>((s) => s.interfaceScale)) - widget.origin.top - (1 - _animation.value) * 15,
							child: child!
						)
						else if (widget.direction == AxisDirection.right) Positioned(
							left: widget.origin.right - (1 - _animation.value) * 15,
							height: widget.origin.height,
							top: widget.origin.top,
							child: child!
						)
					]
				)
			)
		);
	}

	@override
	void dispose() {
		_animationController.dispose();
		super.dispose();
	}
}

Future<void> showTabMenu({
	required BuildContext context,
	required Rect origin,
	required AxisDirection direction,
	required List<TabMenuAction> actions
}) async {
	final completer = Completer<void>();
	final entry = OverlayEntry(
		builder: (context) => _TabMenuOverlay(
			origin: Rect.fromPoints(
				origin.topLeft / context.read<EffectiveSettings>().interfaceScale,
				origin.bottomRight / context.read<EffectiveSettings>().interfaceScale
			),
			direction: direction,
			actions: actions,
			onDone: completer.complete
		)
	);
	Overlay.of(context, rootOverlay: true).insert(entry);
	await completer.future;
	entry.remove();
}

import 'dart:async';

import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TabMenuAction {
	final IconData icon;
	final String title;
	final VoidCallback onPressed;
	final bool isDestructiveAction;
	final bool disabled;

	const TabMenuAction({
		required this.icon,
		required this.title,
		required this.onPressed,
		this.isDestructiveAction = false,
		this.disabled = false
	});
}

class _TabMenuOverlay extends StatefulWidget {
	final Rect origin;
	final AxisDirection direction;
	final List<TabMenuAction> actions;
	final VoidCallback onDone;
	final bool showTitles;

	const _TabMenuOverlay({
		required this.origin,
		required this.direction,
		required this.actions,
		required this.onDone,
		this.showTitles = true
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
		final screenSize = MediaQuery.sizeOf(context);
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
		final actions = widget.actions.map((action) => AdaptiveIconButton(
			padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
			onPressed: action.disabled ? null : () {
				action.onPressed();
				onDone();
			},
			icon: Column(
				mainAxisSize: MainAxisSize.min,
				children: [
					Icon(action.icon, color: !action.disabled && action.isDestructiveAction ? Colors.red : null),
					if (axisDirectionToAxis(widget.direction) == Axis.horizontal && widget.showTitles) ...[
						const SizedBox(height: 4),
						Flexible(
							child: Text(action.title, overflow: TextOverflow.visible, style: const TextStyle(fontSize: 15))
						)
					]
				]
			)
		)).toList();
		final menu = Container(
			decoration: BoxDecoration(
				color: ChanceTheme.barColorOf(context),
				borderRadius: borderRadius
			),
			child: Flex(
				direction: axisDirectionToAxis(widget.direction),
				children: axisDirectionIsReversed(widget.direction) ? actions.reversed.toList() : actions
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
							onPanEnd: (d) => onDone(),
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
	required List<TabMenuAction> actions,
	bool showTitles = true
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
			showTitles: showTitles,
			onDone: completer.complete
		)
	);
	Overlay.of(context, rootOverlay: true).insert(entry);
	await completer.future;
	entry.remove();
}

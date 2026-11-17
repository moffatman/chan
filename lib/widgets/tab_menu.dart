import 'dart:async';
import 'dart:math';

import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/notifying_icon.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class TabMenuAction {
	final IconData icon;
	final String title;
	final VoidCallback? onPressed;
	final VoidCallback? onLongPress;
	final Color? color;
	final ValueListenable<int>? primaryCount;
	final ValueListenable<int>? secondaryCount;
	final bool isDestructiveAction;
	final bool? isSelected;

	const TabMenuAction({
		required this.icon,
		required this.title,
		required this.onPressed,
		this.onLongPress,
		this.color,
		this.primaryCount,
		this.secondaryCount,
		this.isSelected,
		this.isDestructiveAction = false
	});

	Widget buildIcon({bool constrainBadge = false}) {
		final widget = Icon(icon, color: onPressed != null && isDestructiveAction ? Colors.red : color);
		return primaryCount == null && secondaryCount == null ? widget : NotifyingIcon(
			icon: widget,
			constrainBadge: constrainBadge,
			primaryCount: primaryCount,
			secondaryCount: secondaryCount
		);
	}
}

class _TabMenuOverlay extends StatefulWidget {
	final Rect origin;
	final AxisDirection direction;
	final List<TabMenuAction> actions;
	final VoidCallback onDone;
	final Axis? titles;

	const _TabMenuOverlay({
		required this.origin,
		required this.direction,
		required this.actions,
		required this.onDone,
		required this.titles
	});
	
	@override
	createState() => _TabMenuOverlayState();
}

final _allOpenTabMenuClosers = <VoidCallback>[];

class _TabMenuOverlayState extends State<_TabMenuOverlay> with SingleTickerProviderStateMixin {
	Size? lastSize;
	late final AnimationController _animationController;
	late final Animation<double> _animation;
	bool fakeDone = false;
	int? _swipePointer;
	Offset? _swipeOrigin;

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
		_allOpenTabMenuClosers.add(onDone);
	}

	void onDone() async {
		if (fakeDone) {
			return;
		}
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
		final padding = MediaQuery.paddingOf(context);
		final horizontal = axisDirectionToAxis(widget.direction) == Axis.horizontal;
		final menuHeight = max(widget.origin.height, widget.titles == Axis.vertical ? 80.0 : 44.0);
		final menuTop = max(padding.top, min(widget.origin.top, screenSize.height - padding.bottom - menuHeight));
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
		final actions = widget.actions.map((action) {
			final icon = action.buildIcon();
			final titles = widget.titles;
			return Semantics(
				selected: action.isSelected,
				child: Opacity(
					opacity: action.isSelected == false ? 0.5 : 1,
					child: GestureDetector(
						onLongPress: action.onLongPress == null ? null : () {
							action.onLongPress!.call();
							onDone();
						},
						child: AdaptiveIconButton(
							padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
							onPressed: action.onPressed == null ? null : () {
								action.onPressed?.call();
								onDone();
							},
							icon: titles == null ? icon : Flex(
								direction: titles,
								mainAxisSize: MainAxisSize.min,
								crossAxisAlignment: CrossAxisAlignment.center,
								children: [
									icon,
									const SizedBox(height: 4, width: 8),
									Flexible(
										child: Text(
											action.title,
											overflow: TextOverflow.visible,
											textAlign: TextAlign.center,
											style: widget.origin.size.aspectRatio < 1.5
												// Not much space (near-square), shrink font
												? const TextStyle(fontSize: 15) : null
										)
									)
								]
							)
						)
					)
				)
			);
		}).toList();
		final menuContent = Flex(
			mainAxisSize: MainAxisSize.min,
			direction: axisDirectionToAxis(widget.direction),
			children: [
				for (final action in axisDirectionIsReversed(widget.direction) ? actions.reversed : actions)
					if (horizontal) Flexible(child: action)
					else action
			]
		);
		final menu = Container(
			decoration: BoxDecoration(
				color: ChanceTheme.barColorOf(context),
				borderRadius: borderRadius
			),
			child: ConstrainedBox(
				constraints: BoxConstraints(
					maxWidth: horizontal ? max(0,
						widget.direction == AxisDirection.left
							? widget.origin.left - padding.left
							: screenSize.width - widget.origin.right - padding.right
					) : double.infinity,
					maxHeight: horizontal ? double.infinity : max(0,
						widget.direction == AxisDirection.up
							? widget.origin.top - padding.top
							: screenSize.height - widget.origin.bottom - padding.bottom
					)
				),
				child: horizontal ? menuContent : SingleChildScrollView(
					reverse: widget.direction == AxisDirection.up,
					child: menuContent
				)
			)
		);
		return IgnorePointer(
			ignoring: fakeDone,
			child: AnimatedBuilder(
				animation: _animation,
				child: FadeTransition(
					opacity: _animation,
					child: Listener(
						// Observe the swipe without competing with a scrollable menu.
						behavior: HitTestBehavior.opaque,
						onPointerDown: (event) {
							if (_swipePointer != null) return;
							_swipePointer = event.pointer;
							_swipeOrigin = event.position;
						},
						onPointerCancel: (event) {
							if (_swipePointer != event.pointer) return;
							_swipePointer = null;
							_swipeOrigin = null;
						},
						onPointerUp: (event) {
							if (_swipePointer != event.pointer) return;
							final delta = event.position - _swipeOrigin!;
							_swipePointer = null;
							_swipeOrigin = null;
							final closingDistance = switch (widget.direction) {
								AxisDirection.up => delta.dy,
								AxisDirection.down => -delta.dy,
								AxisDirection.left => delta.dx,
								AxisDirection.right => -delta.dx
							};
							final crossDistance = horizontal ? delta.dy.abs() : delta.dx.abs();
							if (closingDistance >= 32 && closingDistance > crossDistance) onDone();
						},
						child: menu
					)
				),
				builder: (context, child) => Stack(
					fit: StackFit.expand,
					children: [
						// Block original tap target from re-opening
						Positioned.fromRect(
							rect: widget.origin,
							child: const AbsorbPointer()
						),
						Listener(
							onPointerDown: (e) => onDone(),
							onPointerPanZoomStart: (e) => onDone(),
							behavior: HitTestBehavior.translucent
						),
						if (widget.direction == AxisDirection.up) Positioned(
							left: widget.origin.left,
							width: widget.origin.width,
							bottom: screenSize.height - widget.origin.top - (1 - _animation.value) * 15,
							child: child!
						)
						else if (widget.direction == AxisDirection.down) Positioned(
							left: widget.origin.left,
							width: widget.origin.width,
							top: widget.origin.bottom - (1 - _animation.value) * 15,
							child: child!
						)
						else if (widget.direction == AxisDirection.left) Positioned(
							right: screenSize.width - widget.origin.left - (1 - _animation.value) * 15,
							height: menuHeight,
							top: menuTop,
							child: child!
						)
						else if (widget.direction == AxisDirection.right) Positioned(
							left: widget.origin.right - (1 - _animation.value) * 15,
							height: menuHeight,
							top: menuTop,
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
		_allOpenTabMenuClosers.remove(onDone);
		super.dispose();
	}
}

Future<void> showTabMenu({
	required BuildContext context,
	required Rect origin,
	required AxisDirection direction,
	required List<TabMenuAction> actions,
	required Axis? titles
}) async {
	final completer = Completer<void>();
	final entry = OverlayEntry(
		builder: (context) => _TabMenuOverlay(
			origin: Rect.fromPoints(
				origin.topLeft / Settings.instance.interfaceScale,
				origin.bottomRight / Settings.instance.interfaceScale
			),
			direction: direction,
			actions: actions,
			titles: titles,
			onDone: completer.complete
		)
	);
	Overlay.of(context, rootOverlay: true).insert(entry);
	await completer.future;
	entry.remove();
}

void closeAllOpenTabMenus() {
	for (final closer in _allOpenTabMenuClosers) {
		try {
			closer.call();
		}
		catch (e, st) {
			// Don't stop iterating
			Future.error(e, st);
		}
	}
}

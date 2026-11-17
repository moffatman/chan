import 'dart:ui' show ImageFilter;

import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/tab_menu.dart';
import 'package:flutter/cupertino.dart';

enum _ExpandedControls { navigation, newTab }

class FloatingTabControls extends StatefulWidget {
	final List<TabMenuAction> navigationActions;
	final List<TabMenuAction> newTabActions;
	final Widget Function(bool expanded) menuIconBuilder;
	final VoidCallback onNewTab;
	final VoidCallback? onQuickAction;
	final double buttonExtent;
	final bool showLabels;
	final bool showNavigation;

	static const inset = 6.0;
	static const horizontalInset = 15.0;
	static const innerPadding = 4.0;
	static double restingExtent(double buttonExtent, int navigationButtonCount) => buttonExtent * (1 + navigationButtonCount) + innerPadding * 2;

	const FloatingTabControls({
		required this.navigationActions,
		required this.newTabActions,
		required this.menuIconBuilder,
		required this.onNewTab,
		required this.onQuickAction,
		required this.buttonExtent,
		required this.showLabels,
		required this.showNavigation,
		super.key
	});

	@override
	State<FloatingTabControls> createState() => FloatingTabControlsState();
}

class FloatingTabControlsState extends State<FloatingTabControls> {
	_ExpandedControls? _expanded;
	Offset? _swipeOrigin;

	bool collapse() {
		if (_expanded == null) return false;
		setState(() => _expanded = null);
		return true;
	}

	void _expand(_ExpandedControls controls, {bool toggle = false}) {
		lightHapticFeedback();
		setState(() => _expanded = toggle && _expanded == controls ? null : controls);
	}

	Widget _button({
		required Widget icon,
		required String title,
		required VoidCallback? onPressed,
		VoidCallback? onLongPress,
		VoidCallback? onSwipeUp,
		bool? selected,
		required double extent,
		required bool showLabel
	}) => Semantics(
		label: title,
		button: true,
		selected: selected,
		child: GestureDetector(
			onLongPress: onLongPress,
			onVerticalDragEnd: onSwipeUp == null ? null : (details) {
				if ((details.primaryVelocity ?? 0) < 0) onSwipeUp();
			},
			child: SizedBox(
				height: extent,
				width: double.infinity,
				child: AdaptiveButton(
					onPressed: onPressed,
					padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
					child: Opacity(
						opacity: selected == false ? 0.5 : 1,
						child: ExcludeSemantics(child: Column(
							mainAxisSize: MainAxisSize.min,
							mainAxisAlignment: MainAxisAlignment.center,
							children: [
								icon,
								if (showLabel) ...[
									const SizedBox(height: 4),
									Flexible(child: Text(title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)))
								]
							]
						))
					)
				)
			)
		)
	);

	@override
	Widget build(BuildContext context) {
		final color = ChanceTheme.primaryColorOf(context);
		final blur = Settings.blurEffectsSetting.watch(context);
		Widget buildActionButton(TabMenuAction action, {bool persistent = false}) => _button(
			icon: action.buildIcon(constrainBadge: true),
			title: action.title,
			onPressed: action.onPressed == null ? null : () { collapse(); action.onPressed!(); },
			onLongPress: action.onLongPress == null ? null : () { collapse(); action.onLongPress!(); },
			selected: action.isSelected,
			extent: persistent || !widget.showLabels ? widget.buttonExtent : 76,
			showLabel: widget.showLabels
		);
		Widget buildActionGroup(List<TabMenuAction> actions, bool visible) => IgnorePointer(
			ignoring: !visible,
			child: AnimatedCrossFade(
				clipBehavior: Clip.none,
				firstChild: const SizedBox(width: double.infinity),
				secondChild: Column(mainAxisSize: MainAxisSize.min, children: [
					for (final action in actions) buildActionButton(action)
				]),
				crossFadeState: visible ? CrossFadeState.showSecond : CrossFadeState.showFirst,
				duration: const Duration(milliseconds: 180),
				sizeCurve: Curves.easeInOut,
				firstCurve: Curves.easeInOut,
				secondCurve: Curves.easeInOut,
				alignment: Alignment.bottomCenter
			)
		);
		return TapRegion(
			onTapOutside: (_) => collapse(),
			child: Listener(
				onPointerDown: (event) => _swipeOrigin = event.position,
				onPointerUp: (event) {
					final origin = _swipeOrigin;
					_swipeOrigin = null;
					if (origin == null) return;
					final delta = event.position - origin;
					if (delta.dy > 32 && delta.dy > delta.dx.abs()) collapse();
				},
				onPointerCancel: (_) => _swipeOrigin = null,
				child: ClipRRect(
					borderRadius: BorderRadius.circular(28),
					clipBehavior: Clip.antiAlias,
					child: _FloatingControlsBackground(
						blur: blur,
						child: DefaultTextStyle.merge(
							style: TextStyle(color: color),
							child: IconTheme.merge(
								data: IconThemeData(color: color, size: 28),
								child: AnimatedSize(
									duration: const Duration(milliseconds: 180),
									curve: Curves.easeInOut,
									alignment: Alignment.bottomCenter,
									child: SingleChildScrollView(
										reverse: true,
										child: Padding(
											padding: const EdgeInsets.symmetric(horizontal: 2, vertical: FloatingTabControls.innerPadding),
											child: Column(mainAxisSize: MainAxisSize.min, children: [
												buildActionGroup(widget.newTabActions, _expanded == _ExpandedControls.newTab),
												_button(
													icon: const Icon(CupertinoIcons.add),
													title: 'New',
													onPressed: () { collapse(); widget.onNewTab(); },
													onLongPress: () => _expand(_ExpandedControls.newTab),
													onSwipeUp: () => _expand(_ExpandedControls.newTab),
													extent: widget.buttonExtent,
													showLabel: widget.showLabels
												),
												if (widget.showNavigation)
													for (final action in widget.navigationActions) buildActionButton(action, persistent: true)
												else ...[
													buildActionGroup(widget.navigationActions, _expanded == _ExpandedControls.navigation),
													_button(
														icon: widget.menuIconBuilder(_expanded == _ExpandedControls.navigation),
														title: 'Menu',
														onPressed: () => _expand(_ExpandedControls.navigation, toggle: true),
														onLongPress: widget.onQuickAction == null ? null : () { collapse(); widget.onQuickAction!(); },
														onSwipeUp: () => _expand(_ExpandedControls.navigation),
														extent: widget.buttonExtent,
														showLabel: widget.showLabels
													)
												]
											])
										)
									)
								)
							)
						)
					)
				)
			)
		);
	}
}

class _FloatingControlsBackground extends StatelessWidget {
	final bool blur;
	final Widget child;

	const _FloatingControlsBackground({required this.blur, required this.child});

	@override
	Widget build(BuildContext context) {
		if (!blur) return ColoredBox(color: ChanceTheme.barColorOf(context), child: child);
		return BackdropFilter(
			filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
			child: child
		);
	}
}

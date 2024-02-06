import 'dart:async';
import 'dart:math';

import 'package:chan/services/imageboard.dart';
import 'package:chan/services/notifications.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/cupertino_context_menu2.dart';
import 'package:chan/widgets/default_gesture_detector.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ContextMenuAction {
	final Widget child;
	final IconData trailingIcon;
	final FutureOr<void> Function() onPressed;
	final bool isDestructiveAction;
	final Key? key;
	ContextMenuAction({
		required this.child,
		required this.trailingIcon,
		required this.onPressed,
		this.isDestructiveAction = false,
		this.key
	});
}

class ContextMenu extends StatefulWidget {
	final List<ContextMenuAction> actions;
	final Widget child;
	final double? maxHeight;
	final Widget Function(BuildContext, Widget?)? previewBuilder;
	final Color? backgroundColor;
	/// Use LayoutBuilder if your child is going to be close to the max width
	/// of the screen to avoid text relayout visual jank
	final bool useLayoutBuilder;

	const ContextMenu({
		required this.actions,
		required this.child,
		this.maxHeight,
		this.previewBuilder,
		this.backgroundColor,
		this.useLayoutBuilder = true,
		Key? key
	}) : super(key: key);

	@override
	createState() => _ContextMenuState();
}

class _ContextMenuState extends State<ContextMenu> {
	OverlayEntry? _overlayEntry;
	Offset? lastTap;

	void _onLongPress() async {
		final l = ((lastTap?.dx ?? 0) / Persistence.settings.interfaceScale) + 5;
		final t = ((lastTap?.dy ?? 0) / Persistence.settings.interfaceScale) + 5;
		final s = context.findAncestorWidgetOfExactType<MediaQuery>()!.data.size;
		final action = await showMenu(
			useRootNavigator: true,
			items: widget.actions.map((action) => PopupMenuItem(
				value: action,
				key: action.key,
				child: Row(
					mainAxisAlignment: MainAxisAlignment.spaceBetween,
					children: [
						DefaultTextStyle.merge(
							style: action.isDestructiveAction ? const TextStyle(color: Colors.red) : const TextStyle(),
							child: action.child
						),
						Icon(action.trailingIcon, color: action.isDestructiveAction ? Colors.red : null)
					]
				)
			)).toList(),
			context: context,
			constraints: const BoxConstraints(maxHeight: 500),
			position: RelativeRect.fromLTRB(l, t, s.width - l, s.height - t)
		);
		action?.onPressed();
	}

	Widget _buildMaterial() {
		assert((widget.previewBuilder == null) || (widget.backgroundColor == null), 'backgroundColor behind previewBuilder not supported');
		return widget.previewBuilder == null ? Material(
			color: widget.backgroundColor,
			child: InkWell(
				onTapDown: (d) {
					lastTap = d.globalPosition;
				},
				onTap: () {
					context.read<DefaultOnTapCallback?>()?.onTap?.call();
				},
				onLongPress: _onLongPress,
				child: widget.child
			)
		) : GestureDetector(
			onLongPressStart: (d) {
				lastTap = d.globalPosition;
				_onLongPress();
			},
			child: widget.child
		);
	}

	Widget _buildCupertino() {
		// Using select to only rebuild when object changes, not on its updates
		final zone = context.select<PostSpanZoneData?, PostSpanZoneData?>((z) => z);
		final imageboard = context.select<Imageboard?, Imageboard?>((i) => i);
		final site = context.watch<ImageboardSite?>();
		final persistence = context.select<Persistence?, Persistence?>((p) => p);
		final threadWatcher = context.select<ThreadWatcher?, ThreadWatcher?>((w) => w);
		final notifications = context.watch<Notifications?>();
		final actions = widget.actions.map((action) => CupertinoContextMenuAction2(
			trailingIcon: action.trailingIcon,
			key: action.key,
			onPressed: () async {
				Navigator.of(context, rootNavigator: true).pop();
				try {
					await action.onPressed();
				}
				catch (e) {
					if (context.mounted) {
						alertError(context, e.toStringDio());
					}
				}
			},
			isDestructiveAction: action.isDestructiveAction,
			child: action.child
		)).toList();
		final child = widget.backgroundColor == null ? widget.child : DecoratedBox(
			decoration: BoxDecoration(
				color: widget.backgroundColor
			),
			child: widget.child
		);
		Widget previewBuilder(BuildContext context) => MultiProvider(
			providers: [
				Provider<bool>.value(value: false), // Dummy, at least one provider is required
				if (zone != null) ChangeNotifierProvider<PostSpanZoneData>.value(value: zone),
				if (imageboard != null) ChangeNotifierProvider<Imageboard>.value(value: imageboard),
				if (site != null) Provider<ImageboardSite>.value(value: site),
				if (persistence != null) ChangeNotifierProvider<Persistence>.value(value: persistence),
				if (threadWatcher != null) ChangeNotifierProvider<ThreadWatcher>.value(value: threadWatcher),
				if (notifications != null) Provider<Notifications>.value(value: notifications)
			],
			child: IgnorePointer(child: widget.previewBuilder?.call(context, null) ?? child)
		);
		if (!widget.useLayoutBuilder) {
			return CupertinoContextMenu2(
				actions: actions,
				previewBuilder: (context, animation, child) => previewBuilder(context),
				child: child
			);
		}
		return LayoutBuilder(
			builder: (context, originalConstraints) => CupertinoContextMenu2(
				actions: actions,
				previewBuilder: (context, animation, child) => LayoutBuilder(
					builder: (context, newConstraints) {
						const x = 75;
						return FittedBox(
							child: AnimatedBuilder(
								animation: animation,
								builder: (context, _) => TweenAnimationBuilder(
									tween: Tween<double>(
										begin: originalConstraints.maxHeight,
										end: newConstraints.maxHeight
									),
									curve: Curves.ease,
									duration: const Duration(milliseconds: 300),
									builder: (context, double maxHeight, _) => ConstrainedBox(
										constraints: BoxConstraints(
											minWidth: 0,
											maxWidth: min(max(originalConstraints.maxWidth, newConstraints.maxWidth - x), newConstraints.maxWidth + x),
											minHeight: 0,
											maxHeight: maxHeight.isNaN ? double.infinity : maxHeight
										),
										child: previewBuilder(context)
									)
								)
							)
						);
					}
				),
				child: child
			)
		);
	}

	@override
	Widget build(BuildContext context) {
		final iconSize = 24 * context.select<EffectiveSettings, double>((s) => s.textScale);
		final interfaceScale = context.select<EffectiveSettings, double>((s) => s.interfaceScale);
		final child = GestureDetector(
			onSecondaryTapUp: (event) {
				_overlayEntry = OverlayEntry(
					builder: (context) {
						return Stack(
							children: [
								Positioned.fill(
									child: GestureDetector(
										child: Container(color: Colors.transparent),
										onTap: () => _overlayEntry?.remove(),
										onSecondaryTap: () => _overlayEntry?.remove()
									)
								),
								CustomSingleChildLayout(
									delegate: _ContextMenuLayoutDelegate(
										rightClickPosition: event.globalPosition.scale(1 / interfaceScale, 1 / interfaceScale)
									),
									child: Container(
										decoration: BoxDecoration(
											border: Border.all(color: Colors.grey),
											borderRadius: const BorderRadius.all(Radius.circular(4)),
											color: ChanceTheme.backgroundColorOf(context)
										),
										margin: const EdgeInsets.only(bottom: 8, right: 8),
										child: IntrinsicWidth(
											child: Column(
												mainAxisSize: MainAxisSize.min,
												crossAxisAlignment: CrossAxisAlignment.start,
												children: widget.actions.map((action) {
													return CupertinoButton(
														key: action.key,
														padding: const EdgeInsets.all(16),
														onPressed: () async {
															_overlayEntry?.remove();
															try {
																await action.onPressed();
															}
															catch (e) {
																if (context.mounted) {
																	alertError(context, e.toStringDio());
																}
															}
														},
														child: Row(
															mainAxisSize: MainAxisSize.min,
															mainAxisAlignment: MainAxisAlignment.spaceBetween,
															children: [
																action.child,
																const Spacer(),
																const SizedBox(width: 8),
																Icon(action.trailingIcon, size: iconSize)
															]
														)
													);
												}).toList()
											)
										)
									)
								)
							]
						);
					}
				);
				Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
			},
			child: ChanceTheme.materialOf(context) ? _buildMaterial() : _buildCupertino()
		);
		if (widget.maxHeight != null) {
			return ConstrainedBox(
				constraints: BoxConstraints(
					maxHeight: widget.maxHeight!
				),
				child: child
			);
		}
		return child;
	}
}

class _ContextMenuLayoutDelegate extends SingleChildLayoutDelegate {
	final Offset rightClickPosition;

	const _ContextMenuLayoutDelegate({
		required this.rightClickPosition
	});

	@override
	BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
		return constraints;
	}

	@override
	Offset getPositionForChild(Size size, Size childSize) {
		final y = min(size.height - childSize.height, rightClickPosition.dy);
		if (rightClickPosition.dx > (size.width - childSize.width)) {
			// Put it to the left of mouse
			return Offset(rightClickPosition.dx - childSize.width, y);
		}
		return Offset(rightClickPosition.dx, y);
	}


	@override
	bool shouldRelayout(_ContextMenuLayoutDelegate oldDelegate) {
		return rightClickPosition != oldDelegate.rightClickPosition;
	}
}
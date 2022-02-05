import 'dart:math';

import 'package:chan/services/imageboard.dart';
import 'package:chan/services/notifications.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ContextMenuAction {
	final Widget child;
	final IconData trailingIcon;
	final VoidCallback onPressed;
	final bool isDestructiveAction;
	ContextMenuAction({
		required this.child,
		required this.trailingIcon,
		required this.onPressed,
		this.isDestructiveAction = false
	});
}

class ContextMenu extends StatefulWidget {
	final List<ContextMenuAction> actions;
	final Widget child;
	final double? maxHeight;

	const ContextMenu({
		required this.actions,
		required this.child,
		this.maxHeight,
		Key? key
	}) : super(key: key);

	@override
	createState() => _ContextMenuState();
}

class _ContextMenuState extends State<ContextMenu> {
	OverlayEntry? _overlayEntry;

	@override
	Widget build(BuildContext context) {
		// Using select to only rebuild when object changes, not on its updates
		final zone = context.select<PostSpanZoneData?, PostSpanZoneData?>((z) => z);
		final imageboard = context.select<Imageboard?, Imageboard?>((i) => i);
		final site = context.watch<ImageboardSite?>();
		final persistence = context.select<Persistence?, Persistence?>((p) => p);
		final threadWatcher = context.select<ThreadWatcher?, ThreadWatcher?>((w) => w);
		final notifications = context.watch<Notifications?>();
		final iconSize = 24 * context.select<EffectiveSettings, double>((s) => s.textScale);
		final child = GestureDetector(
			onSecondaryTapUp: (event) {
				final topOfUsableSpace = MediaQuery.of(context, MediaQueryAspect.height).size.height * 0.8;
				final showOnRight = event.globalPosition.dx > (MediaQuery.of(context, MediaQueryAspect.width).size.width - 210);
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
								Positioned(
									right: showOnRight ? MediaQuery.of(context, MediaQueryAspect.width).size.width - event.globalPosition.dx : null,
									left: showOnRight ? null : event.globalPosition.dx,
									bottom: (event.globalPosition.dy > topOfUsableSpace) ? MediaQuery.of(context, MediaQueryAspect.height).size.height - event.globalPosition.dy : null,
									top: (event.globalPosition.dy > topOfUsableSpace) ? null : event.globalPosition.dy,
									width: 200,
									child: Container(
										decoration: BoxDecoration(
											border: Border.all(color: Colors.grey),
											borderRadius: const BorderRadius.all(Radius.circular(4))
										),
										child: Column(
											mainAxisSize: MainAxisSize.min,
											crossAxisAlignment: CrossAxisAlignment.stretch,
											children: widget.actions.map((action) {
												return GestureDetector(
													child: Container(
														decoration: BoxDecoration(
															color: CupertinoTheme.of(context).scaffoldBackgroundColor,
														),
														height: 50,
														padding: const EdgeInsets.all(16),
														alignment: Alignment.center,
														child: Row(
															children: [
																action.child,
																const Spacer(),
																Icon(action.trailingIcon, size: iconSize)
															]
														)
													),
													onTap: () {
														action.onPressed();
														_overlayEntry?.remove();
													}
												);
											}).toList()
										)
									)
								)
							]
						);
					}
				);
				Overlay.of(context, rootOverlay: true)!.insert(_overlayEntry!);
			},
			child: LayoutBuilder(
				builder: (context, originalConstraints) => CupertinoContextMenu(
					actions: widget.actions.map((action) => CupertinoContextMenuAction(
						trailingIcon: action.trailingIcon,
						onPressed: () {
							Navigator.of(context, rootNavigator: true).pop();
							action.onPressed();
						},
						isDestructiveAction: action.isDestructiveAction,
						child: action.child
					)).toList(),
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
											child: IgnorePointer(child: child)
										)
									)
								)
							);
						}
					),
					child: MultiProvider(
						providers: [
							Provider<bool>.value(value: false), // Dummy, at least one provider is required
							if (zone != null) ChangeNotifierProvider<PostSpanZoneData>.value(value: zone),
							if (imageboard != null) ChangeNotifierProvider<Imageboard>.value(value: imageboard),
							if (site != null) Provider<ImageboardSite>.value(value: site),
							if (persistence != null) ChangeNotifierProvider<Persistence>.value(value: persistence),
							if (threadWatcher != null) ChangeNotifierProvider<ThreadWatcher>.value(value: threadWatcher),
							if (notifications != null) Provider<Notifications>.value(value: notifications)
						],
						child: widget.child
					)
				)
			)
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
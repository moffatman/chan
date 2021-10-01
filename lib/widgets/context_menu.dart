import 'dart:math';

import 'package:chan/services/settings.dart';
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

	ContextMenu({
		required this.actions,
		required this.child
	});

	createState() => _ContextMenuState();
}

enum _ContextMenuUseNewConstraints {
	No,
	Yes
}

class _ContextMenuState extends State<ContextMenu> {
	OverlayEntry? _overlayEntry;

	@override
	Widget build(BuildContext context) {
		if (context.watch<EffectiveSettings>().useTouchLayout) {
			final zone = context.watch<PostSpanZoneData?>();
			return LayoutBuilder(
				builder: (context, originalConstraints) {
					return CupertinoContextMenu(
						actions: widget.actions.map((action) => CupertinoContextMenuAction(
							child: action.child,
							trailingIcon: action.trailingIcon,
							onPressed: () {
								action.onPressed();
								Navigator.of(context, rootNavigator: true).pop();
							},
							isDestructiveAction: action.isDestructiveAction
						)).toList(),
						previewBuilder: (ctx, animation, child) {
							return IgnorePointer(
								child: Provider<_ContextMenuUseNewConstraints>.value(
									value: _ContextMenuUseNewConstraints.Yes,
									child: child
								)
							);
						},
						child: LayoutBuilder(
							builder: (context, newConstraints) {
								final useNewConstraints = context.read<_ContextMenuUseNewConstraints?>() == _ContextMenuUseNewConstraints.Yes;
								double newMaxWidth = originalConstraints.maxWidth;
								double newMaxHeight = originalConstraints.maxHeight;
								newMaxHeight = max(newMaxHeight, newConstraints.maxHeight - 50);
								newMaxHeight = min(newMaxHeight, newConstraints.maxHeight + 50);
								newMaxWidth = max(newMaxWidth, newConstraints.maxWidth - 50);
								newMaxWidth = min(newMaxWidth, newConstraints.maxWidth + 50);
								return FittedBox(
									child: ConstrainedBox(
										constraints: useNewConstraints ? BoxConstraints(
											maxWidth: newMaxWidth,
											maxHeight: newMaxHeight,
											minWidth: 0,
											minHeight: 0
										) : originalConstraints,
										child: (zone == null) ? widget.child : ChangeNotifierProvider.value(
											value: zone,
											child: widget.child
										)
									)
								);
							}
						)
					);
				}
			);
		}
		else {
			return GestureDetector(
				onSecondaryTapUp: (event) {
					final topOfUsableSpace = MediaQuery.of(context).size.height * 0.8;
					final showOnRight = event.globalPosition.dx > (MediaQuery.of(context).size.width - 210);
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
										right: showOnRight ? MediaQuery.of(context).size.width - event.globalPosition.dx : null,
										left: showOnRight ? null : event.globalPosition.dx,
										bottom: (event.globalPosition.dy > topOfUsableSpace) ? MediaQuery.of(context).size.height - event.globalPosition.dy : null,
										top: (event.globalPosition.dy > topOfUsableSpace) ? null : event.globalPosition.dy,
										width: 200,
										child: Container(
											decoration: BoxDecoration(
												border: Border.all(color: Colors.grey),
												borderRadius: BorderRadius.all(Radius.circular(4))
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
															padding: EdgeInsets.all(16),
															alignment: Alignment.center,
															child: Row(
																children: [
																	action.child,
																	Spacer(),
																	Icon(action.trailingIcon)
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
				child: widget.child
			);
		}
	}
}
import 'package:chan/services/settings.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
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

class _ContextMenuState extends State<ContextMenu> {
	OverlayEntry? _overlayEntry;
	@override
	Widget build(BuildContext context) {
		if (context.watch<EffectiveSettings>().useTouchLayout) {
			final zone = context.watchOrNull<PostSpanZoneData>();
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
						child: child
					);
				},
				child: (zone == null) ? widget.child : ChangeNotifierProvider.value(
					value: zone,
					child: widget.child
				)
			);
		}
		else {
			return Listener(
				onPointerDown: (event) {
					if (event.buttons & kSecondaryMouseButton > 0) {
						final topOfUsableSpace = MediaQuery.of(context).size.height * 0.8;
						final showOnRight = event.position.dx > (MediaQuery.of(context).size.width - 210);
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
											right: showOnRight ? MediaQuery.of(context).size.width - event.position.dx : null,
											left: showOnRight ? null : event.position.dx,
											bottom: (event.position.dy > topOfUsableSpace) ? MediaQuery.of(context).size.height - event.position.dy : null,
											top: (event.position.dy > topOfUsableSpace) ? null : event.position.dy,
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
					}
				},
				child: widget.child
			);
		}
	}
}
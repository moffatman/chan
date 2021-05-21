import 'package:flutter/widgets.dart';

class HoverPopup extends StatefulWidget {
	final Widget child;
	final Widget popup;
	HoverPopup({
		required this.child,
		required this.popup
	});
	createState() => _HoverPopupState();
}

class _HoverPopupState extends State<HoverPopup> {
	OverlayEntry? _entry;
	@override
	Widget build(BuildContext context) {
		return MouseRegion(
			onEnter: (event) {
				if (_entry != null) {
					return;
				}
				final RenderBox? childBox = context.findRenderObject() as RenderBox;
				if (childBox == null || !childBox.attached) {
					return;
				}
				final childTop = childBox.localToGlobal(Offset.zero).dy;
				final childBottom = childBox.localToGlobal(Offset(0, childBox.size.height)).dy;
				final childCenterHorizontal = childBox.localToGlobal(Offset(childBox.size.width / 2, 0)).dx;
				final topOfUsableSpace = MediaQuery.of(context).size.height / 2;
				final left = childBox.localToGlobal(Offset.zero).dx;
				final cblg = childBox.localToGlobal(Offset(childBox.size.width, 0)).dx;
				_entry = OverlayEntry(
					builder: (context) {
						final showOnRight = childCenterHorizontal > (MediaQuery.of(context).size.width / 2);
						return Positioned(
							right: showOnRight ? (MediaQuery.of(context).size.width - cblg) : null,
							left: showOnRight ? null : left,
							bottom: (childTop > topOfUsableSpace) ? MediaQuery.of(context).size.height - childTop : null,
							top: (childTop > topOfUsableSpace) ? null : childBottom,
							child: ConstrainedBox(
								constraints: BoxConstraints(
									maxWidth: MediaQuery.of(context).size.width / 2
								),
								child: widget.popup
							)
						);
					}
				);
				Overlay.of(context, rootOverlay: true)!.insert(_entry!);
			},
			onExit: (event) {
				_entry?.remove();
				_entry = null;
			},
			child: widget.child
		);
	}

	@override
	void dispose() {
		super.dispose();
		_entry?.remove();
	}
}
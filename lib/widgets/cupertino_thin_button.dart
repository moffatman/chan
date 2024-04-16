import 'package:chan/services/theme.dart';
import 'package:flutter/cupertino.dart';

class CupertinoThinButton extends StatefulWidget {
	final Widget child;
	final VoidCallback? onPressed;
	final EdgeInsets padding;
	final bool filled;
	final bool backgroundFilled;
	final Color? color;

	const CupertinoThinButton({
		required this.child,
		required this.onPressed,
		this.padding = const EdgeInsets.all(16),
		this.filled = false,
		this.backgroundFilled = false,
		this.color,
		Key? key
	}) : super(key: key);

	@override
	createState() => _CupertinoThinButtonState();
}

class _CupertinoThinButtonState extends State<CupertinoThinButton> {
	bool _pressed = false;

	@override
	Widget build(BuildContext context) {
		final baseOpacity = widget.onPressed == null ? 0.5 : 1.0;
		final baseColor = (widget.color ?? ChanceTheme.primaryColorOf(context)).withOpacity(baseOpacity);
		Color? color;
		if (_pressed) {
			color = baseColor.withOpacity((widget.filled ? 0.8 : 0.2) * baseColor.opacity);
		}
		else if (widget.filled) {
			color = baseColor;
		}
		return GestureDetector(
			onTapDown: (_) {
				if (widget.onPressed == null) {
					return;
				}
				setState(() {
					_pressed = true;
				});
			},
			onTapCancel: () {
				setState(() {
					_pressed = false;
				});
			},
			onTap: () {
				setState(() {
					_pressed = false;
				});
				widget.onPressed?.call();
			},
			child: Container(
				decoration: BoxDecoration(
					border: Border.all(color: baseColor),
					borderRadius: const BorderRadius.all(Radius.circular(8)),
					color: widget.backgroundFilled ? ChanceTheme.backgroundColorOf(context) : color
				),
				padding: widget.padding,
				child: DefaultTextStyle.merge(
					style: TextStyle(
						color: widget.filled ? ChanceTheme.backgroundColorOf(context) : baseColor
					),
					child: widget.child
				)
			)
		);
	}
}
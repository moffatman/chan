import 'package:chan/services/theme.dart';
import 'package:flutter/cupertino.dart';

class CupertinoThinButton extends StatefulWidget {
	final Widget child;
	final VoidCallback onPressed;
	final EdgeInsets padding;
	final bool filled;

	const CupertinoThinButton({
		required this.child,
		required this.onPressed,
		this.padding = const EdgeInsets.all(16),
		this.filled = false,
		Key? key
	}) : super(key: key);

	@override
	createState() => _CupertinoThinButtonState();
}

class _CupertinoThinButtonState extends State<CupertinoThinButton> {
	bool _pressed = false;

	@override
	Widget build(BuildContext context) {
		Color? color;
		if (_pressed) {
			color = ChanceTheme.primaryColorOf(context).withOpacity(widget.filled ? 0.8 : 0.2);
		}
		else if (widget.filled) {
			color = ChanceTheme.primaryColorOf(context);
		}
		return GestureDetector(
			onTapDown: (_) {
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
				widget.onPressed();
			},
			child: Container(
				decoration: BoxDecoration(
					border: Border.all(color: ChanceTheme.primaryColorOf(context)),
					borderRadius: const BorderRadius.all(Radius.circular(8)),
					color: color
				),
				padding: widget.padding,
				child: DefaultTextStyle.merge(
					style: TextStyle(
						color: widget.filled ? ChanceTheme.backgroundColorOf(context) : ChanceTheme.primaryColorOf(context)
					),
					child: widget.child
				)
			)
		);
	}
}
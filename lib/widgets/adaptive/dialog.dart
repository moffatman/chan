import 'package:chan/services/theme.dart';
import 'package:chan/widgets/cupertino_dialog.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/material.dart';

class AdaptiveDialogAction extends StatelessWidget {
	final Widget child;
	final VoidCallback? onPressed;
	final bool isDefaultAction;
	final bool isDestructiveAction;

	const AdaptiveDialogAction({
		required this.child,
		required this.onPressed,
		this.isDefaultAction = false,
		this.isDestructiveAction = false,
		super.key
	});

	@override
	Widget build(BuildContext context) {
		if (ChanceTheme.materialOf(context)) {
			return TextButton(
				onPressed: onPressed,
				child: DefaultTextStyle.merge(
					style: TextStyle(
						fontWeight: isDefaultAction ? FontWeight.bold : null,
						fontVariations: isDefaultAction ? CommonFontVariations.bold : null,
						color: isDestructiveAction ? Colors.red : null
					),
					child: child
				)
			);
		}
		return CupertinoDialogAction2(
			onPressed: onPressed,
			isDefaultAction: isDefaultAction,
			isDestructiveAction: isDestructiveAction,
			child: child
		);
	}
}

class AdaptiveAlertDialog extends StatelessWidget {
	final Widget? title;
	final Widget? content;
	/// Primary action first, cancel action must come last
	final List<AdaptiveDialogAction> actions;

	const AdaptiveAlertDialog({
		this.title,
		this.content,
		this.actions = const [],
		super.key
	});

	@override
	Widget build(BuildContext context) {
		if (ChanceTheme.materialOf(context)) {
			return AlertDialog(
				title: title,
				content: SingleChildScrollView(
					child: content
				),
				actions: actions.reversed.toList(),
				actionsOverflowDirection: VerticalDirection.up,
			);
		}
		return CupertinoAlertDialog2(
			title: title,
			content: content,
			actions: actions
		);
	}
}
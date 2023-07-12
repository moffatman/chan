// Needed as there is no method to change the CupertinoAlertDialog fonts

import 'package:chan/services/persistence.dart';
import 'package:flutter/cupertino.dart';

class CupertinoAlertDialog2 extends StatelessWidget {
	final Widget? title;
	final Widget? content;
	final List<Widget> actions;

	const CupertinoAlertDialog2({
		this.title,
    this.content,
    this.actions = const [],
		super.key
	});

	@override
	Widget build(BuildContext context) {
		return CupertinoAlertDialog(
			title: title == null ? null : Builder(
				builder: (context) => DefaultTextStyle(
					style: DefaultTextStyle.of(context).style.merge(Persistence.settings.textStyle),
					textAlign: TextAlign.center,
					child: title!
				)
			),
			content: content == null ? null : Builder(
				builder: (context) => DefaultTextStyle(
					style: DefaultTextStyle.of(context).style.merge(Persistence.settings.textStyle),
					textAlign: TextAlign.center,
					child: content!
				)
			),
			// Cancel button is always at end of array. But when we have 2 actions, we want it first so it displays on the left.
			actions: actions.length == 2 ? actions.reversed.toList() : actions,
		);
	}
}

class CupertinoDialogAction2 extends StatelessWidget {
	final Widget child;
	final VoidCallback? onPressed;
	final bool isDefaultAction;
	final bool isDestructiveAction;

	const CupertinoDialogAction2({
		required this.child,
		required this.onPressed,
		this.isDefaultAction = false,
		this.isDestructiveAction = false,
		super.key
	});

	@override
	Widget build(BuildContext context) {
		return CupertinoDialogAction(
			onPressed: onPressed,
			isDefaultAction: isDefaultAction,
			isDestructiveAction: isDestructiveAction,
			child: Builder(
				builder: (context) => DefaultTextStyle(
					style: DefaultTextStyle.of(context).style.merge(Persistence.settings.textStyle),
					textAlign: TextAlign.center,
					child: child
				)
			)
		);
	}
}

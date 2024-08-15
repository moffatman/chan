import 'package:chan/services/persistence.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/context_menu.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

Future<T?> showAdaptiveModalPopup<T>({
	required BuildContext context,
	required WidgetBuilder builder,
	bool useRootNavigator = true
}) {
	if (ChanceTheme.materialOf_(context)) {
		return showModalBottomSheet<T>(
			context: context,
			builder: builder,
			// Seems to be needed to be positioned above tablet keyboard
			isScrollControlled: true,
			enableDrag: false,
			useRootNavigator: useRootNavigator
		);
	}
	return showCupertinoModalPopup<T>(
		context: context,
		builder: builder,
		useRootNavigator: useRootNavigator
	);
}

class AdaptiveActionSheet extends StatelessWidget {
	final Widget? title;
	final Widget? message;
	final List<AdaptiveActionSheetAction>? actions;
	final AdaptiveActionSheetAction? cancelButton;

	const AdaptiveActionSheet({
		this.title,
		this.message,
		this.actions,
		this.cancelButton,
		super.key
	});

	@override
	Widget build(BuildContext context) {
		if (ChanceTheme.materialOf(context)) {
			return MaybeScrollbar(
				thumbVisibility: true,
				child: ListView(
					shrinkWrap: true,
					children: [
						if (title != null) Center(
							child: Padding(
								padding: const EdgeInsets.all(16),
								child: DefaultTextStyle(
									style: TextStyle(
										fontSize: 20,
										color: ChanceTheme.primaryColorOf(context)
									),
									child: title!
								)
							)
						),
						if (message != null) Padding(
							padding: const EdgeInsets.symmetric(horizontal: 40),
							child: message!
						),
						if (actions != null) ...actions!,
						if (cancelButton != null) cancelButton!
					]
				)
			);
		}
		return CupertinoActionSheet(
			title: title,
			message: message,
			actions: actions,
			cancelButton: cancelButton
		);
	}
}

class AdaptiveActionSheetAction extends StatelessWidget {
	final Widget child;
	final VoidCallback? onPressed;
	final bool isDefaultAction;
	final bool isDestructiveAction;
	final bool isSelected;
	final Widget? trailing;

	const AdaptiveActionSheetAction({
		required this.onPressed,
		required this.child,
		this.isDefaultAction = false,
		this.isDestructiveAction = false,
		this.isSelected = false,
		this.trailing,
		super.key
	});

	@override
	Widget build(BuildContext context) {
		if (ChanceTheme.materialOf(context)) {
			return ListTile(
				selected: isSelected,
				onTap: onPressed,
				title: SizedBox(width: double.infinity, child: child),
				trailing: trailing
			);
		}
		final button = CupertinoActionSheetAction(
			onPressed: onPressed ?? () {},
			isDefaultAction: isDefaultAction,
			isDestructiveAction: isDestructiveAction,
			child: Builder(
				builder: (context) => Row(
					children: [
						Expanded(
							child: DefaultTextStyle.merge(
								style: Persistence.settings.textStyle.copyWith(
									fontWeight: isSelected ? FontWeight.bold : null
								),
								textAlign: TextAlign.center,
								child: child
							)
						),
						if (trailing != null) trailing!
					]
				)
			)
		);
		if (onPressed != null) {
			return button;
		}
		return Opacity(
			opacity: 0.5,
			child: IgnorePointer(
				child: button
			)
		);
	}
}

extension ToActionSheetActions on List<ContextMenuAction> {
	List<AdaptiveActionSheetAction> toActionSheetActions(BuildContext context) => map((action) => AdaptiveActionSheetAction(
		onPressed: () async {
			Navigator.of(context).pop();
			try {
				await action.onPressed();
			}
			catch (e) {
				if (context.mounted) {
					alertError(context, e.toStringDio());
				}
			}
		},
		key: action.key,
		isDestructiveAction: action.isDestructiveAction,
		trailing: Icon(action.trailingIcon),
		child: action.child
	)).toList(growable: false);
}

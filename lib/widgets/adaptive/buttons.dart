import 'dart:async';

import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/cupertino_thin_button.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AdaptiveFilledButton<T> extends StatelessWidget {
	final Widget child;
	final FutureOr<T> Function()? onPressed;
	final EdgeInsets? padding;
	final BorderRadius? borderRadius;
	final double? minSize;
	final Alignment alignment;
	final Color? color;
	final Color? disabledColor;

	const AdaptiveFilledButton({
		required this.child,
		required this.onPressed,
		this.padding,
		this.borderRadius,
		this.minSize,
		this.alignment = Alignment.center,
		this.color,
		this.disabledColor,
		super.key
	});

	@override
	Widget build(BuildContext context) {
		final onPressed = this.onPressed == null ? null : () async {
			try {
				await this.onPressed?.call();
			}
			catch (e, st) {
				Future.error(e, st);
				if (context.mounted) {
					alertError(context, e.toStringDio());
				}
			}
		};
		if (ChanceTheme.materialOf(context)) {
			return FilledButton(
				onPressed: onPressed,
				style: ButtonStyle(
					padding: padding == null ? null : WidgetStatePropertyAll(padding),
					backgroundColor: (color == null && disabledColor == null) ? null : WidgetStateProperty.resolveWith((states) {
						if (states.contains(WidgetState.disabled)) {
							return disabledColor;
						}
						if (states.contains(WidgetState.pressed)) {
							return color?.towardsGrey(0.2);
						}
						if (states.contains(WidgetState.hovered)) {
							return color?.towardsGrey(0.4);
						}
						return color;
					}),
					alignment: alignment,
					minimumSize: WidgetStateProperty.all(minSize.asSquare),
					tapTargetSize: MaterialTapTargetSize.shrinkWrap,
					shape: WidgetStateProperty.all(RoundedRectangleBorder(
						borderRadius: borderRadius ?? const BorderRadius.all(Radius.circular(4.0))
					))
				),
				child: child
			);
		}
		return CupertinoButton(
			onPressed: onPressed,
			padding: padding,
			color: color ?? ChanceTheme.primaryColorOf(context),
			borderRadius: borderRadius ?? const BorderRadius.all(Radius.circular(8.0)),
			minSize: minSize,
			alignment: alignment,
			disabledColor: disabledColor ?? CupertinoColors.quaternarySystemFill,
			child: child
		);
	}
}

class AdaptiveThinButton<T> extends StatelessWidget {
	final Widget child;
	final FutureOr<T> Function()? onPressed;
	final EdgeInsets padding;
	final bool filled;
	final bool backgroundFilled;
	final Color? color;

	const AdaptiveThinButton({
		required this.child,
		required this.onPressed,
		this.padding = const EdgeInsets.all(16),
		this.filled = false,
		this.backgroundFilled = false,
		this.color,
		super.key
	});

	@override
	Widget build(BuildContext context) {
		final onPressed = this.onPressed == null ? null : () async {
			try {
				await this.onPressed?.call();
			}
			catch (e, st) {
				Future.error(e, st);
				if (context.mounted) {
					alertError(context, e.toStringDio());
				}
			}
		};
		if (ChanceTheme.materialOf(context)) {
			final theme = context.watch<SavedTheme>();
			return OutlinedButton(
				onPressed: onPressed,
				style: ButtonStyle(
					padding: WidgetStateProperty.all(padding),
					foregroundColor: filled ? WidgetStateProperty.all(theme.backgroundColor) : null,
					side: WidgetStateProperty.all(BorderSide(color: color ?? theme.primaryColor)),
					backgroundColor: filled ? WidgetStateProperty.resolveWith((s) {
						if (s.contains(WidgetState.pressed)) {
							return theme.primaryColorWithBrightness(0.6);
						}
						if (s.contains(WidgetState.hovered)) {
							return theme.primaryColorWithBrightness(0.8);
						}
						return theme.primaryColor;
					}) : (backgroundFilled ? WidgetStateProperty.resolveWith((s) {
						if (s.contains(WidgetState.pressed)) {
							return theme.primaryColorWithBrightness(0.3);
						}
						if (s.contains(WidgetState.hovered)) {
							return theme.primaryColorWithBrightness(0.1);
						}
						return theme.backgroundColor;
					}) : null)
				),
				child: child
			);
		}
		return CupertinoThinButton(
			onPressed: onPressed,
			padding: padding,
			filled: filled,
			backgroundFilled: backgroundFilled,
			color: color,
			child: child
		);
	}
}

extension _AsSquare on double? {
	Size? get asSquare {
		if (this == null) {
			return null;
		}
		return Size.square(this!);
	}
}

class AdaptiveIconButton<T> extends StatelessWidget {
	final Widget icon;
	final FutureOr<T> Function()? onPressed;
	final double minSize;
	final EdgeInsets padding;
	final bool dimWhenDisabled;

	const AdaptiveIconButton({
		required this.icon,
		required this.onPressed,
		this.minSize = 44,
		this.padding = EdgeInsets.zero,
		this.dimWhenDisabled = true,
		super.key
	});

	@override
	Widget build(BuildContext context) {
		final onPressed = this.onPressed == null ? null : () async {
			try {
				await this.onPressed?.call();
			}
			catch (e, st) {
				Future.error(e, st);
				if (context.mounted) {
					alertError(context, e.toStringDio());
				}
			}
		};
		if (ChanceTheme.materialOf(context)) {
			return IconButton(
				padding: padding,
				style: ButtonStyle(
					minimumSize: WidgetStateProperty.all(minSize.asSquare),
					tapTargetSize: MaterialTapTargetSize.shrinkWrap
				),
				onPressed: onPressed,
				icon: (dimWhenDisabled && onPressed == null) ? Opacity(opacity: 0.5, child: icon) : icon
			);
		}
		return CupertinoButton(
			onPressed: onPressed,
			padding: padding,
			minSize: minSize,
			child: (dimWhenDisabled || onPressed != null) ? icon : DefaultTextStyle.merge(
				style: TextStyle(color: ChanceTheme.primaryColorOf(context)),
				child: IconTheme.merge(
					data: IconThemeData(color: ChanceTheme.primaryColorOf(context)),
					child: icon
				)
			)
		);
	}
}

class AdaptiveButton<T> extends StatelessWidget {
	final Widget child;
	final FutureOr<T> Function()? onPressed;
	final EdgeInsets? padding;

	const AdaptiveButton({
		required this.child,
		required this.onPressed,
		this.padding,
		super.key
	});

	@override
	Widget build(BuildContext context) {
		final onPressed = this.onPressed == null ? null : () async {
			try {
				await this.onPressed?.call();
			}
			catch (e, st) {
				Future.error(e, st);
				if (context.mounted) {
					alertError(context, e.toStringDio());
				}
			}
		};
		if (ChanceTheme.materialOf(context)) {
			return TextButton(
				onPressed: onPressed,
				style: ButtonStyle(
					padding: WidgetStateProperty.all(padding),
					shape: WidgetStateProperty.all(RoundedRectangleBorder(
						borderRadius: BorderRadius.circular(4)
					))
				),
				child: child
			);
		}
		return CupertinoButton(
			onPressed: onPressed,
			padding: padding,
			child: child
		);
	}
}
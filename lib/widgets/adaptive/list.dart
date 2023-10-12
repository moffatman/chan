import 'dart:async';

import 'package:chan/services/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AdaptiveListTile extends StatelessWidget {
	final Widget title;
	final Widget? subtitle;
	final Widget? leading;
	final Widget? trailing;
	final Widget? after;
	final Color? backgroundColor;
	final Color? backgroundColorActivated;
	final FutureOr<void> Function()? onTap;
	final bool faded;

	const AdaptiveListTile({
		required this.title,
		this.subtitle,
		this.leading,
		this.trailing,
		this.after,
		this.backgroundColor,
		this.backgroundColorActivated,
		this.onTap,
		this.faded = false,
		super.key
	});
	
	@override
	Widget build(BuildContext context) {
		Widget child;
		if (ChanceTheme.materialOf(context)) {
			child = ListTile(
				title: title,
				subtitle: subtitle,
				leading: leading,
				trailing: trailing,
				onTap: onTap,
				selectedTileColor: backgroundColorActivated,
				tileColor: backgroundColor,
			);
		}
		else {
			child = CupertinoListTile(
				padding: const EdgeInsetsDirectional.only(start: 20, end: 14, top: 8, bottom: 8),
				title: title,
				subtitle: subtitle,
				leading: leading,
				backgroundColor: backgroundColor,
				backgroundColorActivated: backgroundColorActivated,
				trailing: trailing,
				onTap: onTap
			);
		}
		if (faded) {
			child = Opacity(
				opacity: 0.5,
				child: child
			);
		}
		final after_ = after;
		if (after_ != null) {
			child = IntrinsicHeight(
				child: Row(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						Expanded(child: child),
						after_
					]
				)
			);
		}
		return child;
	}
}

class AdaptiveListSection extends StatelessWidget {
	final List<AdaptiveListTile> children;

	const AdaptiveListSection({
		required this.children,
		super.key
	});

	@override
	Widget build(BuildContext context) {
		if (ChanceTheme.materialOf(context)) {
			return ClipRRect(
				borderRadius: BorderRadius.circular(4),
				child: Material(
					color: ChanceTheme.barColorOf(context),
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: children
					)
				)
			);
		}
		return ClipRRect(
			borderRadius: BorderRadius.circular(8),
			child: CupertinoListSection(
				topMargin: 0,
				margin: EdgeInsets.zero,
				children: children
			)
		);
	}
}
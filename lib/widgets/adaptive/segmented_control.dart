import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AdaptiveSegmentedControl<T extends Object> extends StatelessWidget {
	final Map<T, (IconData?, String)> children;
	final ValueChanged<T> onValueChanged;
	final T? groupValue;
	final EdgeInsets padding;

	const AdaptiveSegmentedControl({
		required this.children,
		required this.onValueChanged,
		this.groupValue,
		this.padding = const EdgeInsets.symmetric(horizontal: 16),
		super.key
	});

	@override
	Widget build(BuildContext context) {
		final groupValue = this.groupValue;
		final Map<T, (IconData?, String)> children;
		if (groupValue == null || this.children.containsKey(groupValue)) {
			children = this.children;
		}
		else {
			children = {
				...this.children,
				groupValue: (null, 'Invalid: "$groupValue"')
			};
		}
		if (ChanceTheme.materialOf(context)) {
			return Padding(
				padding: padding,
				child: SegmentedButton<T>(
					selected: {
						if (groupValue != null) groupValue
					},
					segments: children.entries.map((x) => ButtonSegment(
						value: x.key,
						icon: x.value.$1 == null ? null : Icon(x.value.$1),
						label: Text(x.value.$2, textAlign: TextAlign.center)
					)).toList(),
					emptySelectionAllowed: true,
					showSelectedIcon: false,
					onSelectionChanged: (s) {
						if (s.isEmpty) {
							// Don't allow deselection
							return;
						}
						onValueChanged(s.first);
					}
				)
			);
		}
		return Container(
			padding: padding,
			alignment: Alignment.center,
			child: CupertinoSlidingSegmentedControl<T>(
				children: {
					for (final child in children.entries)
						child.key: Padding(
							padding: const EdgeInsets.all(8),
							child: Wrap(
								alignment: WrapAlignment.center,
								crossAxisAlignment: WrapCrossAlignment.center,
								spacing: 8,
								children: [
									if (child.value.$1 != null) Icon(child.value.$1),
									Text(child.value.$2, textAlign: TextAlign.center)
								]
							)
						)
				},
				onValueChanged: (v) => onValueChanged(v!),
				groupValue: groupValue
			)
		);
	}
}

class AdaptiveChoiceControl<T extends Object> extends StatelessWidget {
	final Map<T, (IconData?, String)> children;
	final ValueChanged<T> onValueChanged;
	final T? groupValue;
	final double? knownWidth;

	const AdaptiveChoiceControl({
		required this.children,
		required this.onValueChanged,
		this.groupValue,
		this.knownWidth,
		super.key
	});

	Widget _build(BuildContext context, double width) {
		final textScale = Settings.textScaleSetting.watch(context);
		final isMaterial = ChanceTheme.materialOf(context);
		final expectedWidth = 16 + (children.length * 16) + ((17 * textScale) * 0.8 * (children.values.map((c) => c.$2.length + (isMaterial && c.$1 != null ? 2 : 0)).fold(0, (a, b) => a + b)));
		if (width < expectedWidth) {
			return Padding(
				padding: const EdgeInsets.symmetric(horizontal: 16),
				child: AdaptiveListSection(
					children: children.entries.map((child) => AdaptiveListTile(
						leading: child.value.$1 == null ? null : Icon(child.value.$1),
						title: Padding(
							padding: const EdgeInsets.all(8),
							child: Text(child.value.$2, textAlign: TextAlign.left, maxLines: 3)
						),
						backgroundColor: ChanceTheme.barColorOf(context),
						backgroundColorActivated: ChanceTheme.primaryColorWithBrightness50Of(context),
						trailing: groupValue == child.key ? const Icon(CupertinoIcons.check_mark) : const SizedBox.shrink(),
						onTap: () => onValueChanged(child.key)
					)).toList()
				)
			);
		}
		return AdaptiveSegmentedControl<T>(
			children: children,
			onValueChanged: onValueChanged,
			groupValue: groupValue
		);
	}

	@override
	Widget build(BuildContext context) {
		if (knownWidth != null) {
			return _build(context, knownWidth!);
		}
		return LayoutBuilder(
			builder: (context, constraints) => _build(context, constraints.maxWidth)
		);
	}
}
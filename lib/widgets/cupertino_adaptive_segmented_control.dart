import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class CupertinoAdaptiveSegmentedControl<T extends Object> extends StatelessWidget {
	final Map<T, (IconData?, String)> children;
	final ValueChanged<T> onValueChanged;
	final T? groupValue;
	final double? knownWidth;

	const CupertinoAdaptiveSegmentedControl({
		required this.children,
		required this.onValueChanged,
		this.groupValue,
		this.knownWidth,
		super.key
	});

	Widget _build(BuildContext context, double width) {
		final textScale = context.select<EffectiveSettings, double>((s) => s.textScale);
		final expectedWidth = 16 + (children.length * 16) + ((17 * textScale) * 0.8 * (children.values.map((c) => c.$2.length).fold(0, (a, b) => a + b)));
		if (width < expectedWidth) {
			return Padding(
				padding: const EdgeInsets.symmetric(horizontal: 16),
				child: ClipRRect(
					borderRadius: BorderRadius.circular(8),
					child: CupertinoListSection(
						topMargin: 0,
						margin: EdgeInsets.zero,
						children: children.entries.map((child) => CupertinoListTile(
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
				)
			);
		}
		return CupertinoSegmentedControl<T>(
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
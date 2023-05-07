import 'package:chan/services/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class CupertinoAdaptiveSegmentedControl<T extends Object> extends StatelessWidget {
	final Map<T, (IconData?, String)> children;
	final ValueChanged<T> onValueChanged;
	final T? groupValue;

	const CupertinoAdaptiveSegmentedControl({
		required this.children,
		required this.onValueChanged,
		this.groupValue,
		super.key
	});

	@override
	Widget build(BuildContext context) {
		final textScale = context.select<EffectiveSettings, double>((s) => s.textScale);
		return LayoutBuilder(
			builder: (context, constraints) {
				final expectedWidth = 16 + (children.length * 16) + ((17 * textScale) * 0.6 * (children.values.map((c) => c.$2.length).fold(0, (a, b) => a + b)));
				if (constraints.maxWidth < expectedWidth) {
					return Padding(
						padding: const EdgeInsets.symmetric(horizontal: 16),
						child: ClipRRect(
							borderRadius: BorderRadius.circular(8),
							child: CupertinoListSection(
								topMargin: 0,
								margin: EdgeInsets.zero,
								children: children.entries.map((child) => CupertinoListTile(
									title: Padding(
										padding: const EdgeInsets.all(8),
										child: Row(
											children: [
												if (child.value.$1 != null) Icon(child.value.$1),
												Flexible(
													child: Text(child.value.$2, textAlign: TextAlign.left, maxLines: 3)
												)
											]
										)
									),
									backgroundColor: context.select<EffectiveSettings, Color>((s) => s.theme.barColor),
									backgroundColorActivated: context.select<EffectiveSettings, Color>((s) => s.theme.primaryColorWithBrightness(0.5)),
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
		);
	}
}
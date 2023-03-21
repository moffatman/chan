import 'package:chan/services/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class CupertinoAdaptiveSegmentedControl<T extends Object> extends StatelessWidget {
	final Map<T, Widget> children;
	final ValueChanged<T> onValueChanged;
	final T? groupValue;
	final bool alwaysVertical;

	const CupertinoAdaptiveSegmentedControl({
		required this.children,
		required this.onValueChanged,
		this.groupValue,
		this.alwaysVertical = false,
		super.key
	});

	@override
	Widget build(BuildContext context) {
		return LayoutBuilder(
			builder: (context, constraints) {
				if (alwaysVertical || (constraints.maxWidth < (65 * children.length))) {
					return ClipRRect(
						borderRadius: BorderRadius.circular(8),
						child: CupertinoListSection(
							topMargin: 0,
							margin: EdgeInsets.zero,
							children: children.entries.map((child) => CupertinoListTile(
								title: child.value,
								backgroundColor: context.select<EffectiveSettings, Color>((s) => s.theme.barColor),
								backgroundColorActivated: context.select<EffectiveSettings, Color>((s) => s.theme.primaryColorWithBrightness(0.5)),
								trailing: groupValue == child.key ? const Icon(CupertinoIcons.check_mark) : const SizedBox.shrink(),
								onTap: () => onValueChanged(child.key)
							)).toList()
						)
					);
				}
				return CupertinoSegmentedControl<T>(
					children: children,
					onValueChanged: onValueChanged,
					groupValue: groupValue
				);
			}
		);
	}
}
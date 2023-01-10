import 'package:flutter/cupertino.dart';

class CupertinoAdaptiveSegmentedControl<T extends Object> extends StatelessWidget {
	final Map<T, Widget> children;
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
		return LayoutBuilder(
			builder: (context, constraints) {
				if (constraints.maxWidth < (65 * children.length)) {
					return ClipRRect(
						borderRadius: BorderRadius.circular(8),
						child: CupertinoListSection(
							topMargin: 0,
							margin: EdgeInsets.zero,
							children: children.entries.map((child) => CupertinoListTile(
								title: child.value,
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
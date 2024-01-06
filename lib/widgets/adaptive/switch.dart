import 'package:chan/services/theme.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AdaptiveSwitch extends StatelessWidget {
	final bool value;
	final ValueChanged<bool>? onChanged;

	const AdaptiveSwitch({
		required this.value,
		required this.onChanged,
		super.key
	});

	@override
	Widget build(BuildContext context) {
		if (ChanceTheme.materialOf(context)) {
			return Switch(
				value: value,
				onChanged: onChanged,
				inactiveThumbColor: ChanceTheme.primaryColorOf(context),
				trackOutlineColor: MaterialStatePropertyAll(ChanceTheme.primaryColorOf(context))
			);
		}
		return CupertinoSwitch(
			value: value,
			onChanged: onChanged,
			activeColor: ChanceTheme.primaryColorOf(context).withMaxValue(0.5)
		);
	}
}
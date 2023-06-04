import 'package:chan/services/theme.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';

class CupertinoSwitch2 extends StatelessWidget {
	final bool value;
	final ValueChanged<bool>? onChanged;

	const CupertinoSwitch2({
		required this.value,
		required this.onChanged,
		super.key
	});

	@override
	Widget build(BuildContext context) {
		return CupertinoSwitch(
			value: value,
			onChanged: onChanged,
			activeColor: ChanceTheme.primaryColorOf(context).withMaxValue(0.5)
		);
	}
}
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class DefaultOnTapCallback {
	final VoidCallback? onTap;
	DefaultOnTapCallback(this.onTap);

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is DefaultOnTapCallback &&
		other.onTap == onTap;
	
	@override
	int get hashCode => onTap.hashCode;
}

class DefaultGestureDetector extends StatelessWidget {
	final Widget child;
	final HitTestBehavior? behavior;
	final VoidCallback? onTap;

	const DefaultGestureDetector({
		required this.child,
		required this.onTap,
		this.behavior,
		super.key
	});

	@override
	Widget build(BuildContext context) {
		return Provider.value(
			value: DefaultOnTapCallback(onTap),
			child: GestureDetector(
				behavior: behavior,
				onTap: onTap,
				child: child
			)
		);
	}
}
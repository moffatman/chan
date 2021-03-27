import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

extension NoThrowingProvider on BuildContext {
	T? watchOrNull<T>() {
		try {
			return Provider.of<T>(this);
		}
		on ProviderNotFoundException {
			return null;
		}
	}
}

void alertError(BuildContext context, String error) {
  	showCupertinoDialog(
		context: context,
		builder: (_context) {
			return CupertinoAlertDialog(
				title: const Text('Error'),
				content: Text(error),
				actions: [
					CupertinoDialogAction(
						child: const Text('OK'),
						onPressed: () {
							Navigator.of(_context).pop();
						}
					)
				]
			);
		}
	);
}

String formatTime(DateTime time) {
	final now = DateTime.now();
	final notToday = (now.day != time.day) || (now.month != time.month) || (now.year != time.year);
	String prefix = '';
	const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
	if (notToday) {
		prefix = time.year.toString() + '-' + time.month.toString().padLeft(2, '0') + '-' + time.day.toString().padLeft(2, '0') + ' (' + days[time.weekday] + ') ';
	}
	return prefix + time.hour.toString().padLeft(2, '0') + ':' + time.minute.toString().padLeft(2, '0') + ':' + time.second.toString().padLeft(2, '0');
}

class TransparentRoute<T> extends PageRoute<T> {
	TransparentRoute({
		required this.builder,
		RouteSettings? settings,
  	}) : super(settings: settings, fullscreenDialog: false);

	final WidgetBuilder builder;

	@override
	bool get opaque => false;

	@override
	Color? get barrierColor => null;

	@override
	String? get barrierLabel => null;

	@override
	bool get maintainState => true;

	@override
	Duration get transitionDuration => Duration(milliseconds: 150);

	@override
  	Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
		final result = builder(context);
		return FadeTransition(
			opacity: Tween<double>(begin: 0, end: 1).animate(animation),
			child: Semantics(
				scopesRoute: true,
				explicitChildNodes: true,
				child: result,
			)
		);
	}
}
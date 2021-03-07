import 'package:flutter/cupertino.dart';
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

void alertError(BuildContext context, Error error) {
  	showCupertinoDialog(
		context: context,
		builder: (_context) {
			return CupertinoAlertDialog(
				title: const Text('Error'),
				content: Text(error.toString()),
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
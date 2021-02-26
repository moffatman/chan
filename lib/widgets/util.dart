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
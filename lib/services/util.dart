import 'dart:io';
import 'dart:math';

bool isDesktop() {
	return !Platform.isIOS && !Platform.isAndroid;
}

final random = Random(DateTime.now().millisecondsSinceEpoch);

String describeCount(int count, String noun) {
	if (count == 1) {
		return '$count $noun';
	}
	else {
		return '$count ${noun}s';
	}
}
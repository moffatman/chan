import 'dart:io';
import 'dart:math';

bool isDesktop() {
	return !Platform.isIOS && !Platform.isAndroid;
}

final random = Random(DateTime.now().millisecondsSinceEpoch);
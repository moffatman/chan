import 'dart:io';
import 'dart:math';

import 'package:chan/services/persistence.dart';
import 'package:flutter/services.dart';
import 'package:html_unescape/html_unescape_small.dart';

bool isDesktop() {
	return !Platform.isIOS && !Platform.isAndroid;
}

final random = Random(DateTime.now().millisecondsSinceEpoch);
final unescape = HtmlUnescape();

String describeCount(int count, String noun) {
	if (count == 1) {
		return '$count $noun';
	}
	else {
		return '$count ${noun}s';
	}
}

Future<void> lightHapticFeedback() async {
	if (Persistence.settings.useHapticFeedback) {
		HapticFeedback.lightImpact();
	}
}

Future<void> mediumHapticFeedback() async {
	if (Persistence.settings.useHapticFeedback) {
		HapticFeedback.mediumImpact();
	}
}
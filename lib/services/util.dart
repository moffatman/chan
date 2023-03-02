import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:chan/services/persistence.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:html_unescape/html_unescape_small.dart';

bool isDesktop() {
	return !Platform.isIOS && !Platform.isAndroid;
}

final random = Random(DateTime.now().millisecondsSinceEpoch);
final unescape = HtmlUnescape();

String makeRandomBase64String(int length) {
	return base64Url.encode(List.generate(length, (i) => random.nextInt(256)));
}

String makeRandomUserAgent() {
	return makeRandomBase64String(random.nextInt(30) + 10);
}

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

Future<void> _copyGzipped((String, String) param) async {
	await gzip.encoder.bind(File(param.$1).openRead()).pipe(File(param.$2).openWrite());
}

Future<void> copyGzipped(String inputPath, String outputPath) async {
	await compute(_copyGzipped, (inputPath, outputPath));
}

Future<void> _copyUngzipped((String, String) param) async {
	await gzip.decoder.bind(File(param.$1).openRead()).pipe(File(param.$2).openWrite());
}

Future<void> copyUngzipped(String inputPath, String outputPath) async {
	await compute(_copyUngzipped, (inputPath, outputPath));
}
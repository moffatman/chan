import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:chan/services/persistence.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:html_unescape/html_unescape_small.dart';

bool isDesktop() {
	return !Platform.isIOS && !Platform.isAndroid;
}

final random = Random(DateTime.now().millisecondsSinceEpoch);
final unescape = HtmlUnescape();

String makeRandomBase64String(int length) {
	// base64 grows 3 bytes -> 4 chars. So we will always have enough here to cut off at desired length.
	return base64Url.encode(List.generate(length, (i) => random.nextInt(256))).substring(length);
}

String makeRandomUserAgent() {
	return makeRandomBase64String(random.nextInt(30) + 10);
}

String describeCount(int count, String noun, {String? plural}) {
	if (count == 1) {
		return '$count $noun';
	}
	else if (plural != null) {
		return '$count $plural';
	}
	else {
		return '$count ${noun}s';
	}
}

Future<void> lightHapticFeedback() async {
	if (Persistence.settings.useHapticFeedback && WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
		await HapticFeedback.lightImpact();
	}
}

Future<void> mediumHapticFeedback() async {
	if (Persistence.settings.useHapticFeedback && WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
		await HapticFeedback.mediumImpact();
	}
}

Future<void> _copyGzipped((String, String) param) async {
	final tmpFile = File('${param.$2}.tmp');
	await gzip.encoder.bind(File(param.$1).openRead()).pipe(tmpFile.openWrite());
	await tmpFile.rename(param.$2);
}

Future<void> copyGzipped(String inputPath, String outputPath) async {
	await compute(_copyGzipped, (inputPath, outputPath));
}

Future<void> _copyUngzipped((String, String) param) async {
	final tmpFile = File('${param.$2}.tmp');
	await gzip.decoder.bind(File(param.$1).openRead()).pipe(tmpFile.openWrite());
	await tmpFile.rename(param.$2);
}

Future<void> copyUngzipped(String inputPath, String outputPath) async {
	await compute(_copyUngzipped, (inputPath, outputPath));
}

extension UnescapeHtml on String {
	String get unescapeHtml => unescape.convert(this);
}

abstract class ExtendedException implements Exception {
	const ExtendedException({this.additionalFiles = const {}});
	Map<String, FutureOr<void> Function(BuildContext)> get remedies => const {};
	bool get isReportable;
	final Map<String, Uint8List> additionalFiles;
}

extension IfMounted on BuildContext {
	BuildContext? get ifMounted {
		if (mounted) {
			return this;
		}
		return null;
	}
}

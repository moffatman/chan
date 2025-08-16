import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:chan/services/persistence.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:html_unescape/html_unescape_small.dart';

bool isDesktop() {
	return !Platform.isIOS && !Platform.isAndroid;
}

final random = Random(DateTime.now().millisecondsSinceEpoch);
final unescape = HtmlUnescape();

String makeRandomBase64String(int length) {
	// base64 grows 3 bytes -> 4 chars. So we will always have enough here to cut off at desired length.
	return base64Url.encode(List.generate(length, (i) => random.nextInt(256))).substring(0, length);
}

String makeRandomUserAgent() {
	return makeRandomBase64String(random.nextInt(30) + 10);
}

String describeCount(int? count, String noun, {String? plural}) {
	if (count == null) {
		return plural ?? '${noun}s';
	}
	else if (count == 1) {
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

extension _WithoutTrailingSlash on String {
	String get withoutTrailingSlash {
		int end = length - 1;
		while (this[end] == '/') {
			end--;
		}
		return substring(0, end + 1);
	}
}

extension FileBasename on FileSystemEntity {
	static String get(String path) {
		int inclusiveEnd = path.length - 1;
		while (inclusiveEnd > 0 && path.codeUnitAt(inclusiveEnd) == 0x2F) {
			inclusiveEnd--;
		}
		if (inclusiveEnd < 0) {
			// Give up
			return path;
		}
		if (inclusiveEnd == 0) {
			// To handle '///' etc, and not return empty string
			return path.substring(0, 1);
		}
		return path.substring(path.lastIndexOf('/', inclusiveEnd) + 1, inclusiveEnd + 1);
	}
	String get basename => get(path);
}

extension Copy on Directory {
	Future<Directory> copy(String newPath) async {
		final cleanSrc = path.withoutTrailingSlash;
		final cleanDest = newPath.withoutTrailingSlash;
		final newDir = await Directory(newPath).create(recursive: true);
		await for (final child in list(followLinks: false)) {
			await switch (child) {
				File file => file.copy(file.path.replaceFirst(cleanSrc, cleanDest)),
				Directory directory => directory.copy(directory.path.replaceFirst(cleanSrc, cleanDest)),
				Link link => Link(link.path.replaceFirst(cleanSrc, cleanDest)).create(await link.target()),
				_ => null
			};
		}
		return newDir;
	}
}

extension ChildPath on Directory {
	/// Construct path of a child
	String child(String childName) => '$path/$childName';
	/// Construct File for a child
	File file(String childName) => File(child(childName));
	/// Construct Directory for a child
	Directory dir(String childName) => Directory(child(childName));
}

extension UnescapeHtml on String {
	String get unescapeHtml => unescape.convert(this);
}

abstract class ExtendedException implements Exception {
	const ExtendedException({this.additionalFiles = const {}});
	Map<String, FutureOr<void> Function(BuildContext)> get remedies => const {};
	bool get isReportable;
	final Map<String, Uint8List> additionalFiles;

	/// May be in a DioError wrapper
	static ExtendedException? extract(dynamic error) => switch (error) {
		DioError err => extract(err.error),
		ExtendedException e => e,
		_ => null
	};
}

extension IfMounted on BuildContext {
	BuildContext? get ifMounted {
		if (mounted) {
			return this;
		}
		return null;
	}
}

class UnsafeParseException<S, T> extends ExtendedException {
	final Object error;
	final StackTrace stackTrace;
	final S object;

	UnsafeParseException({
		required this.error,
		required this.stackTrace,
		required this.object
	}) : super(
		additionalFiles: {
			'error.txt': utf8.encode('$error\n\n$stackTrace'),
			if (ExtendedException.extract(error) case ExtendedException e)
				for (final file in e.additionalFiles.entries)
					'nested_${file.key}': file.value
		}
	) {
		try {
			additionalFiles['object.json'] = utf8.encode(Hive.encodeJson(object));
		}
		catch (e, st) {
			additionalFiles['object.json.error.txt'] = utf8.encode('$e\n\n$st');
			additionalFiles['object.txt'] = utf8.encode(object.toString());
		}
	}

	@override
	bool get isReportable => true;
	@override
	String toString() => 'UnsafeParseException<$S, $T>(error: $error)';
}

class PatternException extends ExtendedException {
	final Object? object;
	final String error;

	PatternException(this.object, [this.error = 'Data in wrong shape']) {
		try {
			additionalFiles['object.json'] = utf8.encode(Hive.encodeJson(object));
		}
		catch (e, st) {
			additionalFiles['object.json.error.txt'] = utf8.encode('$e\n\n$st');
			additionalFiles['object.txt'] = utf8.encode(object.toString());
		}
	}

	@override
	bool get isReportable => true;
	@override
	String toString() => 'PatternException(error: $error)';
}

T unsafe<S, T>(S input, T Function() f) {
	try {
		return f();
	}
	on ExtendedException {
		rethrow;
	}
	catch (e, st) {
		print(e);
		print(st);
		throw UnsafeParseException<S, T>(
			error: e,
			stackTrace: st,
			object: input
		);
	}
}

Future<T> unsafeAsync<S, T>(S input, Future<T> Function() f) async {
	try {
		return await f();
	}
	on ExtendedException {
		rethrow;
	}
	catch (e, st) {
		print(e);
		print(st);
		throw UnsafeParseException<S, T>(
			error: e,
			stackTrace: st,
			object: input
		);
	}
}

T Function(S) wrapUnsafe<S, T>(T Function(S) f) => (input) {
	try {
		return f(input);
	}
	on ExtendedException {
		rethrow;
	}
	catch (e, st) {
		print(e);
		print(st);
		throw UnsafeParseException<S, T>(
			error: e,
			stackTrace: st,
			object: input
		);
	}
};

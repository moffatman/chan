
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chan/services/compress_html.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/util.dart';
import 'package:chan/util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:html/parser.dart';

const _translationApiRoot = 'https://api.chance.surf/translate';

const translationSupportedTargetLanguages = {
	'en': 'English',
	'ar': 'Arabic',
	'bg': 'Bulgarian',
	'zh': 'Chinese',
	'cs': 'Czech',
	'da': 'Danish',
	'nl': 'Dutch',
	'et': 'Estonian',
	'fi': 'Finnish',
	'fr': 'French',
	'de': 'German',
	'el': 'Greek',
	'hu': 'Hungarian',
	'id': 'Indonesian',
	'it': 'Italian',
	'ja': 'Japanese',
	'ko': 'Korean',
	'lv': 'Latvian',
	'lt': 'Lithuanian',
	'no': 'Norwegian',
	'pl': 'Polish',
	'pt': 'Portuguese',
	'ro': 'Romanian',
	'ru': 'Russian',
	'sk': 'Slovak',
	'sl': 'Slovenian',
	'es': 'Spanish',
	'sv': 'Swedish',
	'tr': 'Turkish',
	'uk': 'Ukrainian'
};

const _otherLanguages = {
	'zh-Hans': 'Chinese (Simplified)',
	'zh-Hant': 'Chinese (Traditional)',
	'hi': 'Hindi',
	'th': 'Thai',
	'vi': 'Vietnamese',
};

const _platform = MethodChannel('com.moffatman.chan/translation');

bool nativeTranslationSupported = false;
Future<void> initializeNativeTranslation() async {
	if (Platform.isIOS) {
		try {
			nativeTranslationSupported = await _platform.invokeMethod<bool>('isSupported') ?? false;
		}
		catch (e, st) {
			if (e is! MissingPluginException) {
				// Don't throw, translation will default to off
				Future.error(e, st);
			}
		}
	}
}

class NativeTranslationNeedsInteractionException implements Exception {
	final String fromLanguageCode;
	const NativeTranslationNeedsInteractionException(this.fromLanguageCode);
	String? get fromLanguageFull => translationSupportedTargetLanguages[fromLanguageCode] ?? _otherLanguages[fromLanguageCode];

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is NativeTranslationNeedsInteractionException &&
		other.fromLanguageCode == fromLanguageCode;
	
	@override
	int get hashCode => fromLanguageCode.hashCode;

	@override
	String toString() => 'Language not downloaded: ${fromLanguageFull ?? fromLanguageCode}';
}

class NativeTranslationCancelledException implements Exception {
	const NativeTranslationCancelledException();

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is NativeTranslationCancelledException;
	
	@override
	int get hashCode => 0;

	@override
	String toString() => 'NativeTranslationCancelledException()';
}

Future<String?> _nativeTranslate(String html, {required String toLanguage, required bool interactive}) async {
	if (!nativeTranslationSupported) {
		return null;
	}
	try {
		String? out = await _platform.invokeMethod<String>('translate', {
			'text': html,
			'to': toLanguage,
			'interactive': interactive
		});
		if (out != null) {
			final newlinesBefore = html.codeUnits.countOf(10);
			final newlinesAfter = out.codeUnits.countOf(10);
			if (newlinesAfter == 2 * newlinesBefore) {
				// This seems to happen on pt -> en sometimes
				out = out.replaceAll('\n\n', '\n');
			}
		}
		return out;
	} on PlatformException catch (e) {
		if (e.code == 'CANCELLED') {
			throw const NativeTranslationCancelledException();
		}
		if (e.details case String detectedLanguage when e.code == 'INTERACTION_NEEDED') {
			throw NativeTranslationNeedsInteractionException(detectedLanguage);
		}
		rethrow;
	}
}

class TranslationException implements Exception {
	final String message;
	const TranslationException(this.message);
	@override
	String toString() => 'Translation error: $message';
}

class TranslationQuotaExhaustedException extends TranslationException implements ExtendedException {
	static const _kMessage = 'Translation service quota exhausted';
	TranslationQuotaExhaustedException() : super(_kMessage);

	@override
	Map<String, Uint8List> get additionalFiles => {};

	@override
	bool get isReportable => false;

	@override
	Map<String, FutureOr<void> Function(BuildContext)> get remedies => {};

	@override
	String toString() => 'The shared free translation quota has been used up for this month';
}

Future<String> _translate(String html, {required String toLanguage, required bool interactive}) async {
	if (await _nativeTranslate(html, toLanguage: toLanguage, interactive: interactive) case final html?) {
		return html;
	}
	final response = await Settings.instance.client.get<Map>(_translationApiRoot, queryParameters: {
		'html': html,
		'to': toLanguage
	}, options: Options(
		responseType: ResponseType.json
	));
	if (response.data?['error'] case String error) {
		if (error == TranslationQuotaExhaustedException._kMessage) {
			throw TranslationQuotaExhaustedException();
		}
		throw TranslationException(error);
	}
	return response.data!['html'] as String;
}

Future<String> translateHtml(String html, {required String toLanguage, required bool interactive}) async {
	// <wbr> throws off text compression (in the middle of strings) and is useless anyway
	final compressed = compressHTML(html.replaceAll('<wbr>', ''));
	if (compressed.isCompletelyCompressed) {
		// Nothing to translate, all numbers I guess
		return html;
	}
	return compressed.decompressTranslation(await _translate(compressed.html, toLanguage: toLanguage, interactive: interactive));
}

Future<List<String>> batchTranslate(List<String> input, {required String toLanguage, required bool interactive}) async {
	const escape = HtmlEscape();
	final joined = input.asMap().entries.map((e) {
		return '<p>${escape.convert(e.value)}</p>';
	}).join('');
	final translated = await translateHtml(joined, toLanguage: toLanguage, interactive: interactive);
	final document = parseFragment(translated);
	return document.querySelectorAll('p').map((p) => p.text).toList();
}
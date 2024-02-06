
import 'dart:convert';

import 'package:chan/services/compress_html.dart';
import 'package:chan/services/settings.dart';
import 'package:html/parser.dart';

const _translationApiRoot = 'https://api.chance.surf/translate';

const translationSupportedTargetLanguages = {
	'en': 'English',
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

class TranslationException implements Exception {
	final String message;
	const TranslationException(this.message);
	@override
	String toString() => 'Translation error: $message';
}

Future<String> translateHtml(String html, {required String toLanguage}) async {
	final compressed = compressHTML(html);
	final response = await EffectiveSettings.instance.client.get(_translationApiRoot, queryParameters: {
		'html': compressed.html,
		'to': toLanguage
	});
	if (response.data['error'] != null) {
		throw TranslationException(response.data['error']);
	}
	return compressed.decompressTranslation(response.data['html']);
}

Future<List<String>> batchTranslate(List<String> input, {required String toLanguage}) async {
	const escape = HtmlEscape();
	final joined = input.asMap().entries.map((e) {
		return '<p>${escape.convert(e.value)}</p>';
	}).join('');
	final translated = await translateHtml(joined, toLanguage: toLanguage);
	final document = parseFragment(translated);
	return document.querySelectorAll('p').map((p) => p.text).toList();
}
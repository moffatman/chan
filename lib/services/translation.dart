
import 'dart:convert';

import 'package:chan/services/compress_html.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart';

const _translationApiRoot = 'https://api.chance.surf/translate';

class TranslationException implements Exception {
	final String message;
	const TranslationException(this.message);
	@override
	String toString() => 'Translation error: $message';
}

Future<String> translateHtml(String html, {String toLanguage = 'en'}) async {
	final compressed = compressHTML(html);
	final response = await Dio().get(_translationApiRoot, queryParameters: {
		'html': compressed.html,
		'to': toLanguage
	});
	if (response.data['error'] != null) {
		throw TranslationException(response.data['error']);
	}
	return compressed.decompressTranslation(response.data['html']);
}

Future<List<String>> batchTranslate(List<String> input, {String toLanguage = 'en'}) async {
	const escape = HtmlEscape();
	final joined = input.asMap().entries.map((e) {
		return '<p>${escape.convert(e.value)}</p>';
	}).join('');
	final translated = await translateHtml(joined, toLanguage: toLanguage);
	final document = parseFragment(translated);
	return document.querySelectorAll('p').map((p) => p.text).toList();
}
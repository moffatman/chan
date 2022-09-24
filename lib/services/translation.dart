
import 'package:chan/services/compress_html.dart';
import 'package:dio/dio.dart';

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
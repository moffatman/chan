
import 'package:dio/dio.dart';

const _translationApiRoot = 'https://api.chance.surf/translate';

class TranslationException implements Exception {
	final String message;
	const TranslationException(this.message);
	@override
	String toString() => 'Translation error: $message';
}

Future<String> translateHtml(String html, {String toLanguage = 'en'}) async {
	final response = await Dio().get(_translationApiRoot, queryParameters: {
		'html': html,
		'to': toLanguage
	});
	if (response.data['error'] != null) {
		throw TranslationException(response.data['error']);
	}
	return response.data['html'];
}
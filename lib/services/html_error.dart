import 'package:chan/util.dart';
import 'package:html/parser.dart';

/// Try to grab an obvious error out of the HTML
String? extractHtmlError(String html) {
	if (!html.contains('<body>')) {
		print(html);
		return null;
	}
	final document = parse(html);
	if (document.querySelector('title')?.text.trim().nonEmptyOrNull case String title) {
		return title;
	}
	for (int i = 1; i < 6; i++) {
		final headers = document.querySelectorAll('h$i');
		if (headers.trySingle?.text.trim().nonEmptyOrNull case String header) {
			return header;
		}
		if (headers.length > 1) {
			// Can't pick between multiple
			break;
		}
	}
	return null;
}

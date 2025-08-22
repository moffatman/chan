import 'package:chan/util.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart';

const _kBlockElements = {
	'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'header', 'hgroup',
	'details', 'dialog', 'dd', 'div', 'dt',
	'fieldset', 'figcaption', 'figure', 'footer', 'form',
	'table', 'td', 'tr',
	'address', 'article', 'aside', 'blockquote', 'br', 'hr', 'li', 'main', 'nav', 'ol', 'p', 'pre', 'section', 'ul'
};

class _Block {
	bool prependWhitespace = false;
	final List<String> children = [];
}

/// Based on node-html-parser
extension StructuredText on dom.Element {
	String get structuredText {
		_Block currentBlock = _Block();
		final blocks = [currentBlock];
		void dfs(dom.Node node) {
			if (node is dom.Element) {
				if (_kBlockElements.contains(node.localName?.toLowerCase())) {
					if (currentBlock.children.isNotEmpty) {
						blocks.add(currentBlock = _Block());
					}
					node.nodes.forEach(dfs);
					if (currentBlock.children.isNotEmpty) {
						blocks.add(currentBlock = _Block());
					}
				} else {
					node.nodes.forEach(dfs);
				}
			} else if (node is dom.Text) {
				final trimmedText = node.text.trim();
				if (trimmedText.isEmpty) {
					// Whitespace node, postponed output
					currentBlock.prependWhitespace = true;
				} else {
					String text = trimmedText;
					if (currentBlock.prependWhitespace) {
						text = ' $text';
						currentBlock.prependWhitespace = false;
					}
					currentBlock.children.add(text);
				}
			}
		}
		dfs(this);
		return blocks
			.map((block) => block.children.join('').replaceAll(RegExp(r'\s{2,}'), ' ')) // Normalize each line's whitespace
			.join('\n')
			.trim();
	}
}

/// Try to grab an obvious error out of the HTML
String? extractHtmlError(String html) {
	if (!html.contains('<body>')) {
		print(html);
		return null;
	}
	final document = parse(html);
	if (document.querySelector('.cf-error-details') case final cfError?) {
		return cfError.structuredText;
	}
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

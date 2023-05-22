import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';

abstract class CompressedNode {
	Node reconstruct();
}

class CompressedTag implements CompressedNode {
	final String localName;
	final LinkedHashMap<Object, String> attributes;
	const CompressedTag(this.localName, this.attributes);
	@override
	Node reconstruct() => Element.tag(localName)..attributes = attributes;
	@override
	bool operator == (Object other) => (other is CompressedTag) && (other.localName == localName) && mapEquals(other.attributes, attributes);
	@override
	int get hashCode => Object.hash(localName, attributes);
	@override
	String toString() => 'CompressedTag(<$localName${attributes.isNotEmpty ? ' ' : ''}${attributes.entries.map((a) => '${a.key}="${a.value}"').join(' ')}>)';
}

class CompressedText implements CompressedNode {
	final String text;
	const CompressedText(this.text);
	@override
	Node reconstruct() => Text(text);
	@override
	bool operator == (Object other) => (other is CompressedText) && (other.text == text);
	@override
	int get hashCode => text.hashCode;
	@override
	String toString() => 'CompressedText($text)';
}

class CompressedHTML {
	final String html;
	final Map<String, CompressedNode> codex;

	const CompressedHTML({
		required this.html,
		required this.codex
	});

	void _remapChildren(Element element) {
		for (final child in element.children) {
			if (child.localName == 'br') {
				continue;
			}
			final replacement = codex[child.localName];
			if (replacement == null) {
				throw FormatException('Unexpected translated HTML tag', child.localName);
			}
			final newChild = replacement.reconstruct();
			if (child.innerHtml.isNotEmpty && newChild is Element) {
				newChild.innerHtml = child.innerHtml;
			}
			child.replaceWith(newChild);
			if (newChild is Element) {
				_remapChildren(newChild);
			}
		}
	}

	String decompressTranslation(String translation) {
		final body = parse(translation.replaceAll('<br></br>', '<br>')).body!;
		_remapChildren(body);
		return body.innerHtml;
	}
}

final _compressiblePatterns = [
	RegExp(r'^https?:\/\/[^ ]+$'), // url
	RegExp(r'^[0-9>]+$') // entirely non-alphabetic
];

const _tagBlacklist = {
	'a', 'b', 'br', 'dd', 'dl', 'dt', 'em', 'h1', 'hr', 'i', 'li', 'ol', 'p', 'q', 'rp', 'rt', 's', 'td', 'th', 'tr', 'tt', 'u', 'ul'
};

CompressedHTML compressHTML(String html) {
	final body = parse(html).body!;
	final reverseCodex = <CompressedNode, String>{};
	String currentShortform = 'c';
	String getNextCharacter(int code) {
		if (code < 0x39) {
			// 0-8
			return String.fromCharCode(code + 1);
		}
		else if (code == 0x39) {
			// 9
			return 'a';
		}
		else if (code < 0x7A) {
			// a-y
			return String.fromCharCode(code + 1);
		}
		else {
			// z
			return 'a0'; // not so smart, eventually it will look like aaaax
		}
	}
	String incrementString(String s) {
		final c = s.codeUnits.last;
		return s.substring(0, s.length - 1) + getNextCharacter(c);
	}
	String getNextShortform() {
		final ret = currentShortform;
		do {
			currentShortform = incrementString(currentShortform);
		} while (_tagBlacklist.contains(currentShortform));
		return ret;
	}
	mapChildren(Element element) {
		if (element.localName == 'br') {
			return;
		}
		if (element.children.isEmpty) {
			final text = element.text;
			if (_compressiblePatterns.any((r) => r.hasMatch(text))) {
				final key = CompressedText(element.text);
				final shortform = reverseCodex.putIfAbsent(key, getNextShortform);
				element.innerHtml = '<$shortform></$shortform>';
			}
		}
		else {
			for (final child in element.children) {
				if (child.localName == 'br') {
					// <br> is already optimally short
					continue;
				}
				final key = CompressedTag(child.localName!, child.attributes);
				String? shortform = reverseCodex.putIfAbsent(key, getNextShortform);
				final newChild = Element.tag(shortform)..innerHtml = child.innerHtml;
				child.replaceWith(newChild);
				mapChildren(newChild);
			}
		}
	}
	mapChildren(body);
	return CompressedHTML(
		html: body.innerHtml.replaceAll('<br>', '<br></br>'),
		codex: {
			for (final entry in reverseCodex.entries) entry.value: entry.key
		}
	);
}
import 'package:chan/services/launch_url_externally.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parseFragment;

bool containsHtml(String text) => RegExp(r'<\s*[a-zA-Z][^>]*>').hasMatch(text);

Uri resolveHtmlLinkHref(String href, {String baseOrigin = 'https://owo.vg'}) {
	final trimmed = href.trim();
	if (trimmed.isEmpty) {
		return Uri.parse(baseOrigin);
	}
	final uri = Uri.tryParse(trimmed);
	if (uri != null && uri.hasScheme) {
		return uri;
	}
	if (trimmed.startsWith('//')) {
		return Uri.parse('https:$trimmed');
	}
	if (trimmed.startsWith('/')) {
		return Uri.parse('$baseOrigin$trimmed');
	}
	return Uri.parse(trimmed);
}

class HtmlRichText extends StatefulWidget {
	final String html;
	final TextStyle? style;
	final TextStyle? linkStyle;
	final String linkBaseOrigin;
	const HtmlRichText({
		required this.html,
		this.style,
		this.linkStyle,
		this.linkBaseOrigin = 'https://owo.vg',
		super.key
	});

	@override
	State<HtmlRichText> createState() => _HtmlRichTextState();
}

class _HtmlRichTextState extends State<HtmlRichText> {
	final _recognizers = <TapGestureRecognizer>[];

	@override
	void dispose() {
		for (final recognizer in _recognizers) {
			recognizer.dispose();
		}
		super.dispose();
	}

	TapGestureRecognizer _linkRecognizer(String href) {
		final recognizer = TapGestureRecognizer()
			..onTap = () => launchUrlExternally(resolveHtmlLinkHref(href, baseOrigin: widget.linkBaseOrigin));
		_recognizers.add(recognizer);
		return recognizer;
	}

	List<InlineSpan> _buildSpans(List<dom.Node> nodes, TextStyle linkStyle) {
		final spans = <InlineSpan>[];
		for (final node in nodes) {
			if (node is dom.Text) {
				final text = node.text;
				if (text.isNotEmpty) {
					spans.add(TextSpan(text: text));
				}
			}
			else if (node is dom.Element) {
				switch (node.localName) {
					case 'a':
						final href = node.attributes['href']?.trim();
						final childSpans = _buildSpans(node.nodes, linkStyle);
						if (href != null && href.isNotEmpty && childSpans.isNotEmpty) {
							spans.add(TextSpan(
								style: linkStyle,
								recognizer: _linkRecognizer(href),
								children: childSpans
							));
						}
						else {
							spans.addAll(childSpans);
						}
					case 'br':
						spans.add(const TextSpan(text: '\n'));
					case 'span':
					case 'p':
					case 'b':
					case 'strong':
					case 'i':
					case 'em':
						spans.addAll(_buildSpans(node.nodes, linkStyle));
					default:
						spans.addAll(_buildSpans(node.nodes, linkStyle));
				}
			}
		}
		return spans;
	}

	@override
	Widget build(BuildContext context) {
		final baseStyle = widget.style ?? DefaultTextStyle.of(context).style;
		final linkStyle = widget.linkStyle ?? baseStyle.copyWith(
			color: Theme.of(context).colorScheme.primary,
			decoration: TextDecoration.underline
		);
		final spans = _buildSpans(parseFragment(widget.html).nodes, linkStyle);
		if (spans.isEmpty) {
			return Text(widget.html, style: baseStyle);
		}
		return SelectableText.rich(
			TextSpan(style: baseStyle, children: spans)
		);
	}
}

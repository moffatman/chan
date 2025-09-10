import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

final _greentextRegex = RegExp(r'^>.*$', multiLine: true);
final _pinktextRegex = RegExp(r'^<.*$', multiLine: true);
final _bluetextRegex = RegExp(r'^\^.*$', multiLine: true);
final _quotelinkRegex = RegExp(r'>>(?:(>\/[a-zA-Z0-9]*\/[a-zA-Z0-9\-_]*)|(\d+))');

extension _TextRangeOverlap on TextRange {
	bool overlapsWith(TextRange other) {
		if (!isNormalized || !other.isNormalized) {
			return false;
		}
		return start <= other.end && other.start <= end;
	}
}

TextSpan buildHighlightedCommentTextSpan({
	required String text,
	required ImageboardSite site,
	PostSpanZoneData? zone,
	TextStyle? style,
	TextRange? composing,
	TextStyle misspelledTextStyle = const TextStyle(),
	SpellCheckResults? spellCheckResults
}) {
	final theme = Settings.instance.theme;
	final ranges = <(TextRange, TextStyle)>[];

	if (spellCheckResults != null) {
		List<SuggestionSpan> spellCheckResultsSpans = spellCheckResults.suggestionSpans;
		final String spellCheckResultsText = spellCheckResults.spellCheckedText;

		if (spellCheckResultsText != text) {
			spellCheckResultsSpans = correctSpellCheckResults(
					text, spellCheckResultsText, spellCheckResults.suggestionSpans);
		}

		ranges.addAll(spellCheckResultsSpans.map((span) => (span.range, misspelledTextStyle)));
	}

	if (composing != null) {
		ranges.add((composing, const TextStyle(decoration: TextDecoration.underline)));
	}

	final quotelinkStyle = TextStyle(
		color: theme.secondaryColor,
		decoration: TextDecoration.underline,
		decorationColor: theme.secondaryColor
	);
	final deadQuotelinkStyle = TextStyle(
		color: theme.secondaryColor,
		decoration: TextDecoration.lineThrough,
		decorationColor: theme.secondaryColor
	);
	for (final match in _quotelinkRegex.allMatches(text)) {
		if (match.start > 0 && text[match.start - 1] == '>') {
			// Triple '>' - not a quotelink
			continue;
		}
		final range = TextRange(start: match.start, end: match.end);
		if (
			(composing != null && range.overlapsWith(composing)) ||
			(spellCheckResults?.suggestionSpans.any((s) => s.range.overlapsWith(range)) ?? false)
		) {
			// De-prioritize quotelink
			continue;
		}
		final bool targetExists;
		if (zone == null || (match.group(1)?.isNotEmpty ?? false)) {
			// No ability to check post, or it is cross-board
			targetExists = true;
		}
		else {
			targetExists = zone.findPost(match.group(2)?.tryParseInt ?? 0) != null;
		}
		ranges.add((range, targetExists ? quotelinkStyle : deadQuotelinkStyle));
	}

	if (theme.quoteColor.isReadableOn(theme.textFieldColor)) {
		// Only if greentext color is readable
		final greentextStyle = TextStyle(
			color: theme.quoteColor,
			decorationColor: theme.quoteColor
		);
		for (final match in _greentextRegex.allMatches(text)) {
			if (ranges.any((r) => r.$1.start == match.start)) {
				continue;
			}
			ranges.add((TextRange(start: match.start, end: match.end), greentextStyle));
		}
	}
	if (site.supportsPinkQuotes) {
		final color = PostPinkQuoteSpan.getColor(theme);
		if (color.isReadableOn(theme.textFieldColor)) {
			final style = TextStyle(color: color, decorationColor: color);
			for (final match in _pinktextRegex.allMatches(text)) {
				if (ranges.any((r) => r.$1.start == match.start)) {
					continue;
				}
				ranges.add((TextRange(start: match.start, end: match.end), style));
			}
		}
	}
	if (site.supportsBlueQuotes) {
		final color = PostBlueQuoteSpan.getColor(theme);
		if (color.isReadableOn(theme.textFieldColor)) {
			final style = TextStyle(color: color, decorationColor: color);
			for (final match in _bluetextRegex.allMatches(text)) {
				if (ranges.any((r) => r.$1.start == match.start)) {
					continue;
				}
				ranges.add((TextRange(start: match.start, end: match.end), style));
			}
		}
	}

	mergeSort(ranges, compare: (a, b) {
		return a.$1.start.compareTo(b.$1.start);
	});

	final spans = <TextSpan>[];
	int start = 0;
	final stack = <(TextRange, TextStyle)>[];
	for (int i = 0; i < text.length; i++) {
		if (ranges.tryFirst?.$1.start == i || stack.any((r) => r.$1.end == i)) {
			if (start != i) {
				// Cut off previous stack
				spans.add(TextSpan(
					text: TextRange(start: start, end: i).textInside(text),
					style: stack.fold<TextStyle>(style ?? const TextStyle(), (style, range) => style.merge(range.$2))
				));
				start = i;
			}
			stack.addAll(ranges.where((r) => r.$1.start == i));
			ranges.removeWhere((r) => r.$1.start == i);
			stack.removeWhere((r) => r.$1.end == i);
		}
	}
	if (start < text.length) {
		// Add final range
		spans.add(TextSpan(
			text: TextRange(start: start, end: text.length).textInside(text),
			style: stack.fold<TextStyle>(style ?? const TextStyle(), (style, range) => style.merge(range.$2))
		));
	}

	return TextSpan(
		style: style,
		children: spans
	);
}
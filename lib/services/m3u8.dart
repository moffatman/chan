import 'dart:math' as math;

import 'package:chan/util.dart';

final _videoStreamPattern = RegExp(r'\n#EXT-X-STREAM-INF:([^\n]+)\n[^\n]+');
final _audioStreamPattern = RegExp(r'\n#EXT-X-MEDIA:([^\n]+)');

const _kDoubleQuote = 0x22;
const _kComma = 0x2C;
const _kEquals = 0x3D;

class TrimM3u8Exception implements Exception {
	final String message;
	const TrimM3u8Exception(this.message);

	@override
	String toString() => 'Trimming M3u8 failed: $message';
}

Map<String, String> _parseAttributeList(String properties) {
	final chars = properties.codeUnits;
	int i = 0;
	final out = <String, String>{};
	while (i < chars.length) {
		final attributeNameStart = i;
		while (chars[i] != _kEquals) {
			i++;
		}
		final attributeName = String.fromCharCodes(chars, attributeNameStart, i);
		i++; // Advance from =
		final String attributeValue;
		if (chars[i] == _kDoubleQuote) {
			i++; // Advance from "
			final attributeValueStart = i;
			while (chars[i] != _kDoubleQuote) {
				i++;
			}
			attributeValue = String.fromCharCodes(chars, attributeValueStart, i);
			i++; // Advance from "
		}
		else {
			final attributeValueStart = i;
			while (i < chars.length && chars[i] != _kComma) {
				i++;
			}
			attributeValue = String.fromCharCodes(chars, attributeValueStart, i);
		}
		i++; // Advance from ,
		out[attributeName] = attributeValue;
	}
	return out;
}

/// Remove all substreams except highest quality audio and video
String trimM3u8(String text) {
	int highestBandwidth = -1;
	for (final match in _videoStreamPattern.allMatches(text)) {
		final attributes = _parseAttributeList(match.group(1)!);
		if (attributes['BANDWIDTH']?.tryParseInt case final bandwidth?) {
			highestBandwidth = math.max(highestBandwidth, bandwidth);
		}
	}
	if (highestBandwidth == -1) {
		throw const TrimM3u8Exception('Failed to find any video stream with bandwidth metadata');
	}
	String? audioGroupId;
	text = text.replaceAllMapped(_videoStreamPattern, (match) {
		final attributes = _parseAttributeList(match.group(1)!);
		if (attributes['BANDWIDTH']?.tryParseInt == highestBandwidth) {
			audioGroupId = attributes['AUDIO'];
			return match.group(0)!;
		}
		// Remove it
		return '';
	});
	if (audioGroupId != null) {
		bool foundAudio = false;
		final withAudioTrimmed = text.replaceAllMapped(_audioStreamPattern, (match) {
			final attributes = _parseAttributeList(match.group(1)!);
			if (attributes['GROUP-ID'] == audioGroupId) {
				foundAudio = true;
				return match.group(0)!;
			}
			// Remove it
			return '';
		});
		if (foundAudio) {
			text = withAudioTrimmed;
		}
	}
	return text;
}
import 'package:chan/models/attachment.dart';

final _soundSourceRegex = RegExp(r'\[(audio|sound)=([^\]]+)\]');
final _encodedSoundSourceRegex = RegExp(r"^(?:[A-Za-z0-9_.!~*'()-]|%[0-9A-Fa-f]{2})+$");
final _macOsSoundSourceSchemeRegex = RegExp(r'^(https?):{3}');

extension SoundpostAttachment on Attachment {
	static Uri? extractSoundSourceFromFilename(String filename) {
		if (!filename.contains('[sound=') && !filename.contains('[audio=')) {
			// Fast path
			return null;
		}
		final match = _soundSourceRegex.firstMatch(filename);
		if (match != null) {
			try {
				Uri? source = Uri.tryParse(Uri.decodeFull(match.group(2)!));
				if (source == null) {
					return null;
				}
				if (source.hasScheme) {
					return source;
				}
				if (!source.hasAuthority) {
					source = Uri.tryParse(Uri.decodeFull(match.group(2)!.replaceAll('-', '/')));
				}
				return Uri.tryParse('https://$source');
			}
			on FormatException {
				// Bad URL encoding
				return null;
			}
			on ArgumentError {
				// Bad URL encoding
				return null;
			}
		}
		return null;
	}
	Uri? get soundSource => extractSoundSourceFromFilename(filename);

	static String encodeSoundSourceFilename(String filename) {
		return filename.replaceAllMapped(_soundSourceRegex, (match) {
			String url = match.group(2)!;
			if (_encodedSoundSourceRegex.hasMatch(url)) {
				return match.group(0)!;
			}

			if (!url.contains('/') && url.contains(':')) {
				// macOS replaces / with :
				final schemeMatch = _macOsSoundSourceSchemeRegex.firstMatch(url);
				if (schemeMatch != null) {
					url = '${schemeMatch.group(1)}://${url.substring(schemeMatch.end).replaceAll(':', '/')}';
				}
				else {
					url = url.replaceAll(':', '/');
				}
			}

			try {
				// Preserve existing escapes in partially-encoded filenames.
				url = Uri.decodeComponent(url);
			}
			on FormatException {
				// Encode malformed % sequences as literal percent characters.
			}
			on ArgumentError {
				// Encode malformed % sequences as literal percent characters.
			}
			return '[${match.group(1)}=${Uri.encodeComponent(url)}]';
		});
	}
}

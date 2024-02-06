import 'package:chan/models/attachment.dart';

final _soundSourceRegex = RegExp(r'\[sound=([^\]]+)\]');

extension SoundpostAttachment on Attachment {
	Uri? get soundSource {
		if (!filename.contains('[sound=')) {
			// Fast path
			return null;
		}
		final match = _soundSourceRegex.firstMatch(filename);
		if (match != null) {
			try {
				final source = Uri.tryParse(Uri.decodeFull(match.group(1)!));
				if (source == null) {
					return null;
				}
				if (source.hasScheme) {
					return source;
				}
				return Uri.tryParse('https://$source');
			}
			on ArgumentError {
				// Bad URL encoding
				return null;
			}
		}
		return null;
	}
}
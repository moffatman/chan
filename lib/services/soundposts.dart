import 'package:chan/models/attachment.dart';

final _soundSourceRegex = RegExp(r'\[sound=([^\]]+)\]');

extension SoundpostAttachment on Attachment {
	Uri? get soundSource {
		final match = _soundSourceRegex.firstMatch(filename);
		if (match != null) {
			try {
				final source = Uri.tryParse(Uri.decodeFull(match.group(1)!));
				if (source?.hasScheme ?? false) {
					return source;
				}
				return source?.replace(scheme: 'https');
			}
			on ArgumentError {
				// Bad URL encoding
				return null;
			}
		}
		return null;
	}
}
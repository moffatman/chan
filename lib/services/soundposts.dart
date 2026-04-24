import 'package:chan/models/attachment.dart';

final _soundSourceRegex = RegExp(r'\[(audio|sound)=([^\]]+)\]');

extension SoundpostAttachment on Attachment {
	Uri? get soundSource {
		if (!filename.contains('[sound=')) {
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
	static String encodeSoundSourceFilename(String filename) {
		return filename.replaceAllMapped(_soundSourceRegex, (match) {
			return '[${match.group(1)}=${Uri.encodeComponent(match.group(2)!)}]';
		});
	}
}
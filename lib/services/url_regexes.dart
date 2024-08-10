const _regexChars = {
	0x24, // $
	0x28, // (
	0x29, // )
	0x2A, // *
	0x2B, // +
	0x2E, // .
	0x3F, // ?
	0x5B, // [
	0x5D, // ]
	0x5E, // ^
	0x7B, // {
	0x7C, // |
	0x7D, // }
};

extension _RegexSafe on String {
	bool get _isRegexSafe {
		final codeUnits = this.codeUnits;
		for (int i = 0; i < codeUnits.length; i++) {
			if (codeUnits[i] == 0x5C) {
				// Backslash, skip next char
				i++;
				continue;
			}
			if (_regexChars.contains(codeUnits[i])) {
				return false;
			}
		}
		return true;
	}
	String get _regexUnescaped {
		final codeUnits = this.codeUnits;
		final out = StringBuffer();
		for (int i = 0; i < codeUnits.length; i++) {
			if (codeUnits[i] == 0x5C && (i < (codeUnits.length - 1))) {
				out.writeCharCode(switch (codeUnits[i + 1]) {
					0x74 => 0x09 /* \t */,
					0x6E => 0x0A /* \n */,
					0x72 => 0x0D /* \r */,
					int x => x
				});
				i++;
				continue;
			}
			out.writeCharCode(codeUnits[i]);
		}
		return out.toString();
	}
}

/// Optimization to reduce memory usage for many regexes to match URLs
class UrlRegexes {
	final Map<String, List<_UrlPathRegex>> _exactHosts = {};
	final Map<String, List<_UrlPathRegex>> _wildcardHosts = {};
	final List<RegExp> _exceptions = [];

	final Map<String, _UrlPathRegexUnoptimized> _unoptimizedPathRegexCache = {};
	_UrlPathRegex _makePathRegex(String pathRegex) {
		if (pathRegex == '/.*' || pathRegex == '/.+') {
			return const _UrlPathRegexNonEmpty();
		}
		if (pathRegex.endsWith('.*')) {
			final firstPart = pathRegex.substring(0, pathRegex.length - 2);
			if (firstPart._isRegexSafe) {
				return _UrlPathRegexStartsWith(firstPart._regexUnescaped);
			}
		}
		return _unoptimizedPathRegexCache.putIfAbsent(pathRegex, () => _UrlPathRegexUnoptimized(RegExp('^$pathRegex\$')));
	}

	UrlRegexes(List<String> patterns) {
		final basePattern = RegExp(r'^http(?:s\??)?:\/\/([^\/]*)(\/.*)$');
		for (final pattern in patterns) {
			try {
				if (pattern.endsWith(',')) {
					// Sometimes these are in noembed.com data by mistake
					continue;
				}
				final baseMatch = basePattern.firstMatch(pattern);
				if (baseMatch == null) {
					throw FormatException('Not supported URL', pattern);
				}
				final host = baseMatch.group(1)!;
				final pathRegex = _makePathRegex(baseMatch.group(2)!);
				if (host._isRegexSafe) {
					(_exactHosts[host._regexUnescaped] ??= []).add(pathRegex);
					continue;
				}
				if (host.startsWith(r'.*\.')) {
					final rest = host.substring(4);
					if (rest._isRegexSafe) {
						(_wildcardHosts[rest._regexUnescaped] ??= []).add(pathRegex);
						continue;
					}
				}
				if (host.startsWith(r'(?:www\.)?')) {
					final rest = host.substring(10);
					if (rest._isRegexSafe) {
						final unescaped = rest._regexUnescaped;
						(_exactHosts[unescaped] ??= []).add(pathRegex);
						(_exactHosts['www.$unescaped'] ??= []).add(pathRegex);
						continue;
					}
				}
			}
			on FormatException {
				// Complex host Regex or something
				_exceptions.add(RegExp(pattern));
			}
		}
	}

	bool matches(String rawUrl) {
		final url = Uri.tryParse(rawUrl);
		if (url == null) {
			return false;
		}
		final host = url.host;
		final exact = _exactHosts[host];
		if (exact != null && exact.any((r) => r.matches(url.path))) {
			return true;
		}
		final lastDot = host.lastIndexOf('.');
		if (lastDot != -1) {
			final secondLastDot = host.lastIndexOf('.', lastDot);
			if (secondLastDot != -1) {
				final hostBase = host.substring(secondLastDot + 1);
				final wildcard = _wildcardHosts[hostBase];
				if (wildcard != null && wildcard.any((r) => r.matches(url.path))) {
					return true;
				}
			}
		}
		if (_exceptions.any((r) => r.hasMatch(rawUrl))) {
			return true;
		}
		return false;
	}
}

sealed class _UrlPathRegex {
	bool matches(String path);
}

class _UrlPathRegexNonEmpty implements _UrlPathRegex {
	const _UrlPathRegexNonEmpty();
	@override
	bool matches(String path) => path.length > 2;
	@override
	String toString() => '_UrlPathRegexNonEmpty()';
}

class _UrlPathRegexStartsWith implements _UrlPathRegex {
	final String prefix;
	const _UrlPathRegexStartsWith(this.prefix);
	@override
	bool matches(String path) => path.startsWith(prefix);
	@override
	String toString() => '_UrlPathRegexStartsWith($prefix)';
}

class _UrlPathRegexUnoptimized implements _UrlPathRegex {
	final RegExp pattern;
	const _UrlPathRegexUnoptimized(this.pattern);
	@override
	bool matches(String path) => pattern.hasMatch(path);
	@override
	String toString() => '_UrlPathRegexUnoptimized($pattern)';
}
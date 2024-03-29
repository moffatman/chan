final _map = {
	0xAB: '"',
	0xBB: '"',
	0x201C: '"',
	0x201D: '"',
	0x201E: '"',
	0x2033: '"',
	0x2036: '"',
	0x275D: '"',
	0x275E: '"',
	0x276E: '"',
	0x276F: '"',
	0xFF02: '"',
	0x2018: '\'',
	0x2019: '\'',
	0x201A: '\'',
	0x201B: '\'',
	0x2032: '\'',
	0x2035: '\'',
	0x2039: '\'',
	0x203A: '\'',
	0x275B: '\'',
	0x275C: '\'',
	0xFF07: '\'',
	0x2010: '-',
	0x2011: '-',
	0x2012: '-',
	0x2013: '-',
	0x2014: '-',
	0x207B: '-',
	0x208B: '-',
	0xFF0D: '-',
	0x2045: '',
	0x2772: '',
	0xFF3B: '',
	0x2046: ']',
	0x2773: ']',
	0xFF3D: ']',
	0x207D: '(',
	0x208D: '(',
	0x2768: '(',
	0x276A: '(',
	0xFF08: '(',
	0x2E28: '((',
	0x207E: ')',
	0x208E: ')',
	0x2769: ')',
	0x276B: ')',
	0xFF09: ')',
	0x2E29: '))',
	0x276C: '<',
	0x2770: '<',
	0xFF1C: '<',
	0x276D: '>',
	0x2771: '>',
	0xFF1E: '>',
	0x2774: '{',
	0xFF5B: '{',
	0x2775: '}',
	0xFF5D: '}',
	0x207A: '+',
	0x208A: '+',
	0xFF0B: '+',
	0x207C: '=',
	0x208C: '=',
	0xFF1D: '=',
	0xFF01: '!',
	0x203C: '!!',
	0x2049: '!?',
	0xFF03: '#',
	0xFF04: '\$',
	0x2052: '%',
	0xFF05: '%',
	0xFF06: '&',
	0x204E: '*',
	0xFF0A: '*',
	0xFF0C: ',',
	0xFF0E: '.',
	0x2044: '/',
	0xFF0F: '/',
	0xFF1A: ':',
	0x204F: ';',
	0xFF1B: ';',
	0xFF1F: '?',
	0x2047: '??',
	0x2048: '?!',
	0xFF20: '@',
	0xFF3C: '\\',
	0x2038: '^',
	0xFF3E: '^',
	0xFF3F: '_',
	0x2053: '~',
	0xFF5E: '~'
};

extension NormalizeSymbols on String {
	String get normalizeSymbols {
	final buffer = StringBuffer();
		for (final code in codeUnits) {
			final mapped = _map[code];
			if (mapped != null) {
				buffer.write(mapped);
			}
			else {
				buffer.writeCharCode(code);
			}
		}
		return buffer.toString();
	}
}

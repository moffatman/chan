class OwoVgPostExtras {
	final List<String> peeFiles;
	final String? peeText;
	final String? fakeThumbnail;
	const OwoVgPostExtras({
		this.peeFiles = const [],
		this.peeText,
		this.fakeThumbnail
	});

	static const empty = OwoVgPostExtras();

	bool get isEmpty =>
		peeFiles.isEmpty &&
		(peeText == null || peeText!.trim().isEmpty) &&
		fakeThumbnail == null;

	OwoVgPostExtras copyWith({
		List<String>? peeFiles,
		String? peeText,
		String? fakeThumbnail,
		bool clearPeeText = false,
		bool clearFakeThumbnail = false
	}) => OwoVgPostExtras(
		peeFiles: peeFiles ?? this.peeFiles,
		peeText: clearPeeText ? null : peeText ?? this.peeText,
		fakeThumbnail: clearFakeThumbnail ? null : fakeThumbnail ?? this.fakeThumbnail
	);
}

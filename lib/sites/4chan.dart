// ignore_for_file: file_names
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:async/async.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/flag.dart';
import 'package:chan/models/search.dart';
import 'package:chan/services/auth_page_helper.dart';
import 'package:chan/services/cloudflare.dart';
import 'package:chan/services/linkifier.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/helpers/http_304.dart';
import 'package:chan/sites/util.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/captcha_4chan.dart';
import 'package:chan/widgets/util.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:html/parser.dart' show parse, parseFragment;
import 'package:html/dom.dart' as dom;
import 'package:linkify/linkify.dart';
import 'imageboard_site.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/widgets/post_spans.dart';

class _QuoteLinkElement extends LinkifyElement {
	final int id;
	_QuoteLinkElement(this.id) : super('>>$id');

  @override
  bool operator ==(Object other) =>
		identical(this, other) ||
		(other is _QuoteLinkElement) &&
		(other.id == id);

	@override
	int get hashCode => id.hashCode;
}

class _QuoteLinkLinkifier extends Linkifier {
  const _QuoteLinkLinkifier();

	static final _pattern = RegExp(r'(?:^|(?<= ))>>(\d+)');

  @override
  List<LinkifyElement> parse(elements, options) {
    final list = <LinkifyElement>[];

    for (final element in elements) {
      if (element is TextElement) {
				String text = element.text;
				while (text.isNotEmpty) {
        	final match = _pattern.firstMatch(text);
					if (match == null) {
						if (text == element.text) {
							list.add(element);
						}
						else {
							list.addAll(parse([TextElement(text)], options));
						}
						break;
					}
					if (match.start > 0) {
						list.addAll(parse([TextElement(text.substring(0, match.start))], options));
					}
					list.add(_QuoteLinkElement(match.group(1)?.tryParseInt ?? 0));
					text = text.substring(match.end);
				}
      } else {
        list.add(element);
      }
    }

    return list;
  }
}


class Site4Chan extends ImageboardSite with Http304CachingThreadMixin, Http304CachingCatalogMixin {
	@override
	final String name;
	@override
	final String baseUrl;
	final String? _alternateBaseUrl;
	final String staticUrl;
	final String sysUrl;
	final String apiUrl;
	final String searchUrl;
	@override
	final String imageUrl;
	final String captchaKey;
	final Map<String, String> captchaUserAgents;
	final List<String> boardsWithCountryFlags;
	final List<int> possibleCaptchaLetterCounts;
	final List<String> captchaLetters;
	final Map<String, String> captchaLettersRemap;
	final Map<String, String> postingHeaders;
	final Duration? captchaTicketLifetime;
	Timer? _captchaTicketTimer;
	Timer? _dynamicIPKeepAliveTimer;
	final Duration reportCooldown;
	@override
	final int? subjectCharacterLimit;
	final Duration spamFilterCaptchaDelayGreen;
	final Duration spamFilterCaptchaDelayYellow;
	final Duration spamFilterCaptchaDelayRed;
	final Map<String, Map<String, String>>? boardFlags;
	final bool stickyCloudflare;
	final String? hCaptchaKey;

	@override
	late final Site4ChanPassLoginSystem loginSystem = Site4ChanPassLoginSystem(this);

	void resetCaptchaTicketTimer([Duration? overrideDuration]) {
		_captchaTicketTimer?.cancel();
		final lifetime = overrideDuration ?? captchaTicketLifetime;
		if (lifetime == null) {
			return;
		}
		_captchaTicketTimer = Timer(lifetime, _onCaptchaTicketTimerFire);
	}

	bool _isAppropriateForCaptchaRequest(PersistentBrowserTab tab) {
		return tab.imageboardKey == imageboard?.key &&
		    imageboard?.persistence.getThreadStateIfExists(tab.thread)?.thread?.isArchived != true;
	}

	void _onDynamicIPKeepAliveTimerFire() async {
		final period = _lastDynamicIPKeepAlivePeriod;
		if (period == null) {
			return;
		}
		try {
			// Just try to keep TCP session alive to sysUrl, /post is 404 but should work
			await client.headUri(Uri.https(sysUrl, '/post'), options: Options(
				extra: {
					kPriority: RequestPriority.cosmetic
				},
				validateStatus: (x) => true
			));
		}
		catch (e) {
			// Ignore, hopefully it still works?
		}
		_captchaTicketTimer?.cancel(); // in case of race
		_captchaTicketTimer = Timer(period, _onDynamicIPKeepAliveTimerFire);
	}

	void _onCaptchaTicketTimerFire() async {
		final lifetime = captchaTicketLifetime;
		if (lifetime == null || !Settings.instance.useSpamFilterWorkarounds) {
			return;
		}
		final ticketTime = await Persistence.currentCookies.readPseudoCookieTime(kTicketPseudoCookieKey);
		if (ticketTime != null) {
			final elapsed = DateTime.now().difference(ticketTime);
			if (elapsed < (lifetime * 0.75)) {
				// If less than 75% passed, just resync phase
				resetCaptchaTicketTimer(lifetime - elapsed);
				return;
			}
			// Ticket will expire in less than 25%, it's ok just to reuse it
		}
		final currentTab = Persistence.tabs[Persistence.currentTabIndex];
		final PersistentBrowserTab? tab;
		if (_isAppropriateForCaptchaRequest(currentTab)) {
			tab = currentTab;
		}
		else {
			tab = Persistence.tabs.tryFirstWhere(_isAppropriateForCaptchaRequest);
		}
		final request = await getCaptchaRequest(tab?.thread?.board ?? tab?.board ?? persistence?.boards.tryFirst?.name ?? '', tab?.thread?.id);
		if (request is! Chan4CustomCaptchaRequest) {
			return;
		}
		try {
			final challenge = await requestCaptcha4ChanCustomChallenge(
				site: this,
				request: request,
				priority: RequestPriority.cosmetic // Don't pop up cloudflare
			);
			print('Ticket timer result: $challenge');
		}
		catch (e) {
			print('Ticket timer error: ${e.toStringDio()}');
		}
		resetCaptchaTicketTimer();
	}

	ConnectivityResult? _lastConnectivity;
	bool _lastUseSpamFilterWorkarounds = false;
	Duration? _lastDynamicIPKeepAlivePeriod;
	void _onSettingsUpdate() {
		if (Settings.instance.connectivity != _lastConnectivity ||
		    Settings.instance.useSpamFilterWorkarounds != _lastUseSpamFilterWorkarounds) {
			if (!Settings.instance.useSpamFilterWorkarounds && _lastUseSpamFilterWorkarounds) {
				// User disabled spam-filter workarounds
				// Add a junk "x" at beginning of past IPs to start fresh
				for (final threadState in Persistence.sharedThreadStateBox.values) {
					bool modified = false;
					for (final receipt in threadState.receipts) {
						if (receipt.spamFiltered && !(receipt.ip?.startsWith('x') ?? true)) {
							receipt.ip = 'x${receipt.ip}';
							modified = true;
						}
					}
					if (modified) {
						threadState.save();
					}
				}
			}
			_lastConnectivity = Settings.instance.connectivity;
			_lastUseSpamFilterWorkarounds = Settings.instance.useSpamFilterWorkarounds;
			_onCaptchaTicketTimerFire();
			resetCaptchaTicketTimer();
		}
		if (Settings.instance.dynamicIPKeepAlivePeriod != _lastDynamicIPKeepAlivePeriod) {
			_lastDynamicIPKeepAlivePeriod = Settings.instance.dynamicIPKeepAlivePeriod;
			_onDynamicIPKeepAliveTimerFire();
		}
	}

	@override
	void initState() {
		super.initState();
		if (captchaTicketLifetime != null) {
			// Allow initial stuff to happen
			resetCaptchaTicketTimer(const Duration(seconds: 30));
		}
		_lastConnectivity = Settings.instance.connectivity;
		_lastUseSpamFilterWorkarounds = Settings.instance.useSpamFilterWorkarounds;
		_lastDynamicIPKeepAlivePeriod = Settings.instance.dynamicIPKeepAlivePeriod;
		if (_lastDynamicIPKeepAlivePeriod != null) {
			_onDynamicIPKeepAliveTimerFire();
		}
		Settings.instance.addListener(_onSettingsUpdate);
	}

	@override
	void dispose() {
		super.dispose();
		_captchaTicketTimer?.cancel();
		_dynamicIPKeepAliveTimer?.cancel();
		Settings.instance.removeListener(_onSettingsUpdate);
	}

	static List<PostSpan> parsePlaintext(String text, {ThreadIdentifier? fromSearchThread}) {
		return linkify(text, linkifiers: fromSearchThread != null ? const [
			LooseUrlLinkifier(),
			ChanceLinkifier(),
			_QuoteLinkLinkifier()
		] : const [
			LooseUrlLinkifier(),
			ChanceLinkifier()
		], options: const LinkifyOptions(
			defaultToHttps: true,
			humanize: false
		)).map((elem) {
			if (elem is _QuoteLinkElement) {
				return PostQuoteLinkSpan(
					board: fromSearchThread!.board,
					threadId: fromSearchThread.id,
					postId: elem.id
				);
			}
			else if (elem is UrlElement) {
				return PostLinkSpan(elem.url, name: elem.text);
			}
			else {
				return PostTextSpan(elem.text);
			}
		}).toList();
	}

	static final _mathPattern = RegExp(r'\[math\](.+?)\[\/math\]');
	static final _eqnPattern = RegExp(r'\[eqn\](.+?)\[\/eqn\]');
	static final _catalogSearchPattern = RegExp(r'^catalog#s=(.+)$');

	static PostNodeSpan makeSpan(String board, int threadId, String data, {bool fromSearch = false}) {
		final fromSearchThread = fromSearch ? ThreadIdentifier(board, threadId) : null;
		final body = parseFragment((fromSearch ? data.trim() : data).replaceAll('<wbr>', '').replaceAllMapped(_mathPattern, (match) {
			return '<tex>${match.group(1)!}</tex>';
		}).replaceAllMapped(_eqnPattern, (match) {
			return '<tex>${match.group(1)!}</tex>';
		}));
		final List<PostSpan> elements = [];
		int spoilerSpanId = 0;
		for (int i = 0; i < body.nodes.length; i++) {
			final node = body.nodes[i];
			if (node is dom.Element) {
				if (node.localName == 'br') {
					elements.add(const PostLineBreakSpan());
				}
				else if (node.localName == 'tex') {
					elements.add(PostTeXSpan(node.innerHtml));
				}
				else if (node.localName == 'img' && node.attributes.containsKey('width') && node.attributes.containsKey('height')) {
					final src = node.attributes['src'];
					final width = int.tryParse(node.attributes['width']!);
					final height = int.tryParse(node.attributes['height']!);
					if (src == null || width == null || height == null) {
						continue;
					}
					elements.add(PostInlineImageSpan(
						src: src,
						width: width,
						height: height
					));
				}
				else if (node.localName == 'a' && node.classes.contains('quotelink')) {
					if (node.attributes['href']!.startsWith('#p')) {
						elements.add(PostQuoteLinkSpan(
							board: board,
							threadId: threadId,
							postId: int.parse(node.attributes['href']!.substring(2))
						));
					}
					else if (node.attributes['href']!.contains('#p')) {
						// href looks like '/tv/thread/123456#p123457'
						final parts = node.attributes['href']!.split('/');
						final threadIndex = parts.indexOf('thread');
						final ids = parts[threadIndex + 1].split('#p');
						elements.add(PostQuoteLinkSpan(
							board: parts[threadIndex - 1],
							threadId: int.parse(ids[0]),
							postId: int.parse(ids[1])
						));
					}
					else {
						// href looks like '//boards.4chan.org/pol/'
						final parts = node.attributes['href']!.split('/');
						final catalogSearchMatch = _catalogSearchPattern.firstMatch(parts.last);
						if (catalogSearchMatch != null) {
							elements.add(PostCatalogSearchSpan(board: parts[parts.length - 2], query: Uri.decodeFull(catalogSearchMatch.group(1)!)));
						}
						else {
							elements.add(PostBoardLinkSpan(parts[parts.length - 2]));
						}
					}
				}
				else if (node.localName == 'a' && node.attributes.containsKey('href')) {
					elements.add(PostLinkSpan(node.attributes['href']!, name: node.text.nonEmptyOrNull));
				}
				else if (node.localName == 'span') {
					if (node.classes.contains('deadlink')) {
						final parts = node.innerHtml.replaceAll('&gt;', '').split('/');
						elements.add(PostQuoteLinkSpan.dead(
							board: (parts.length > 2) ? parts[1] : board,
							postId: int.tryParse(parts.last) ?? -1
						));
					}
					else if (node.classes.contains('quote')) {
						elements.add(PostQuoteSpan(makeSpan(board, threadId, node.innerHtml)));
					}
					else if (node.classes.contains('fortune')) {
						final css = {
							for (final pair in (node.attributes['style']?.split(';') ?? <String>[])) pair.split(':').first: pair.split(':').last
						};
						if (css['color'] case String color) {
							elements.add(PostColorSpan(makeSpan(board, threadId, node.innerHtml), colorToHex(color)));
						}
						else {
							elements.add(makeSpan(board, threadId, node.innerHtml));
						}
					}
					else if (node.classes.contains('abbr') &&
									(i + 2 < body.nodes.length) &&
									(body.nodes[i + 1] is dom.Element) &&
									((body.nodes[i + 1] as dom.Element).localName == 'br') &&
									(body.nodes[i + 1] is dom.Element) &&
									((body.nodes[i + 2] as dom.Element).localName == 'table')) {
							final tableRows = <PostSpan>[];
							List<List<PostSpan>> subtable = [];
							for (final row in (body.nodes[i + 2] as dom.Element).firstChild!.children) {
								if (row.firstChild?.attributes['colspan'] == '2') {
									if (subtable.isNotEmpty) {
										tableRows.add(PostTableSpan(subtable));
										subtable = [];
									}
									if (tableRows.isNotEmpty) {
										tableRows.add(const PostLineBreakSpan());
									}
									tableRows.add(PostUnderlinedSpan(PostTextSpan(row.firstChild!.text!)));
								}
								else {
									subtable.add(row.children.map((c) => PostTextSpan(c.text)).toList());
								}
							}
							if (subtable.isNotEmpty) {
								tableRows.add(PostTableSpan(subtable));
							}
							i += 2;
							elements.add(PostPopupSpan(
								title: 'EXIF Data',
								popup: PostNodeSpan(tableRows)
							));
					}
					else if (node.classes.contains('sjis')) {
						elements.add(PostShiftJISSpan(node.text));
					}
					else {
						elements.add(PostTextSpan(node.text));
					}
				}
				else if (node.localName == 's') {
					elements.add(PostSpoilerSpan(makeSpan(board, threadId, node.innerHtml), spoilerSpanId++));
				}
				else if (node.localName == 'pre') {
					final buffer = StringBuffer();
					// To strip all html syntax but maintain whitespace
					void dfs(dom.Node node) {
						if (node is dom.Element) {
							if (node.localName == 'br') {
								buffer.writeln();
							}
							else {
								node.nodes.forEach(dfs);
							}
						} else if (node is dom.Text) {
							buffer.write(node.text);
						}
					}
					dfs(node);
					elements.add(PostCodeSpan(buffer.toString().trimRight()));
				}
				else if (node.localName == 'b' || node.localName == 'strong') {
					final child = PostBoldSpan(makeSpan(board, threadId, node.innerHtml));
					if (node.attributes['style']?.contains('color: red;') ?? false) {
						elements.add(PostSecondaryColorSpan(child));
					}
					else {
						elements.add(child);
					}
				}
				else {
					elements.addAll(parsePlaintext(node.text, fromSearchThread: fromSearchThread));
				}
			}
			else {
				elements.addAll(parsePlaintext(node.text ?? '', fromSearchThread: fromSearchThread));
			}
		}
		return PostNodeSpan(elements.toList(growable: false));
	}

	ImageboardFlag? _makeFlag(Map data, String board) => unsafe(data, () {
		if (data case {'country': String country, 'country_name': String countryName}) {
			return ImageboardFlag(
				name: unescape.convert(countryName),
				imageUrl: Uri.https(staticUrl, '/image/country/${country.toLowerCase()}.gif').toString(),
				imageWidth: 16,
				imageHeight: 11
			);
		}
		else if (data case {'troll_country': String trollCountry, 'country_name': String countryName}) {
			return ImageboardFlag(
				name: unescape.convert(countryName),
				imageUrl: Uri.https(staticUrl, '/image/country/troll/${trollCountry.toLowerCase()}.gif').toString(),
				imageWidth: 16,
				imageHeight: 11
			);
		}
		else if (data case {'board_flag': String boardFlag, 'flag_name': String flagName}) {
			return ImageboardFlag(
				name: unescape.convert(flagName),
				imageUrl: Uri.https(staticUrl, '/image/flags/$board/${boardFlag.toLowerCase()}.gif').toString(),
				imageWidth: 16,
				imageHeight: 11
			);
		}
		return null;
	});

	Post _makePost(String board, int threadId, Map data) => unsafe(data, () {
		final a = _makeAttachment(board, threadId, data);
		return Post(
			board: board,
			text: data['com'] as String? ?? '',
			name: unescape.convert(data['name'] as String? ?? ''),
			trip: data['trip'] as String?,
			time: DateTime.fromMillisecondsSinceEpoch((data['time'] as int) * 1000),
			id: data['no'] as int,
			threadId: threadId,
			attachments_: a == null ? const [] : [a].toList(growable: false),
			attachmentDeleted: data['filedeleted'] == 1,
			spanFormat: PostSpanFormat.chan4,
			flag: _makeFlag(data, board),
			posterId: data['id'] as String?,
			passSinceYear: data['since4pass'] as int?,
			capcode: data['capcode'] as String?
		);
	});
	static AttachmentType _getAttachmentType(String ext) => switch (ext) {
		'.webm' => AttachmentType.webm,
		'.pdf' => AttachmentType.pdf,
		'.mp4' => AttachmentType.mp4,
		'.swf' => AttachmentType.swf,
		_ => AttachmentType.image
	};
	Attachment? _makeAttachment(String board, int threadId, Map data) => unsafe(data, () {
		if (data['tim'] != null) {
			final id = data['tim'] as int;
			final ext = data['ext'] as String;
			final type = _getAttachmentType(ext);
			final filename = unescape.convert(data['filename'] as String? ?? '') + ext;
			return Attachment(
				id: id.toString(),
				type: type,
				filename: filename,
				ext: ext,
				board: board,
				url: switch (type) {
					AttachmentType.swf => Uri.https(imageUrl, '/$board/$filename').toString(),
					_ => Uri.https(imageUrl, '/$board/$id$ext').toString()
				},
				thumbnailUrl: switch (type) {
					AttachmentType.swf => '',
					_ => Uri.https(imageUrl, '/$board/${id}s.jpg').toString()
				},
				md5: data['md5'] as String,
				spoiler: data['spoiler'] == 1,
				width: data['w'] as int?,
				height: data['h'] as int?,
				threadId: threadId,
				sizeInBytes: data['fsize'] as int?
			);
		}
		return null;
	});


	@override
	Future<Thread> makeThread(ThreadIdentifier thread, Response response, {
		ThreadVariant? variant,
		required RequestPriority priority,
		CancelToken? cancelToken
	}) async {
		final data = response.data as Map;
		final op = ((data['posts'] as List)[0] as Map);
		final title = op['sub'] as String?;
		final a = _makeAttachment(thread.board, thread.id, op);
		final output = Thread(
			board: thread.board,
			isDeleted: false,
			replyCount: op['replies'] as int,
			imageCount: op['images'] as int,
			isArchived: op['archived'] == 1,
			isLocked: op['closed'] == 1,
			posts_: (data['posts'] as List? ?? []).map<Post>((postData) {
				return _makePost(thread.board, thread.id, postData as Map);
			}).toList(),
			id: op['no'] as int,
			attachments: a == null ? [] : [a],
			attachmentDeleted: op['filedeleted'] == 1,
			title: (title == null) ? null : unescape.convert(title),
			isSticky: op['sticky'] == 1,
			time: DateTime.fromMillisecondsSinceEpoch((op['time'] as int) * 1000),
			uniqueIPCount: op['unique_ips'] as int?,
			customSpoilerId: op['custom_spoiler'] as int?
		);
		if (output.posts_.length == output.uniqueIPCount) {
			for (int i = 0; i < output.posts_.length; i++) {
				output.posts_[i].ipNumber = i + 1;
			}
		}
		else if (output.uniqueIPCount == 1) {
			for (final post in output.posts_) {
				post.ipNumber = 1;
			}
		}
		return output;
	}

	@override
	RequestOptions getThreadRequest(ThreadIdentifier thread, {ThreadVariant? variant})
		=> RequestOptions(
			path: '/${thread.board}/thread/${thread.id}.json',
			baseUrl: 'https://$apiUrl',
			responseType: ResponseType.json
		);

	static const _kArchivePageSize = 100;
	Future<List<Thread>> _getArchive(String board, int? after, {required RequestPriority priority, CancelToken? cancelToken}) async {
		final response = await client.getUri(Uri.https(baseUrl, '/$board/archive'), options: Options(
			validateStatus: (x) => true,
			extra: {
				kPriority: priority
			},
			responseType: ResponseType.plain
		), cancelToken: cancelToken);
		if (response.statusCode != 200) {
			if (response.statusCode == 404) {
				return Future.error(BoardNotFoundException(board));
			}
			else {
				return Future.error(HTTPStatusException.fromResponse(response));
			}
		}
		return await _makeArchive(board, response, after, cancelToken: cancelToken);
	}

	Future<List<Thread>> _makeArchive(String board, Response response, int? after, {
		CancelToken? cancelToken
	}) async {
		final document = parse(response.data);
		final trs = document.querySelector('#arc-list tbody')!.querySelectorAll('tr').toList();
		final ids = trs.map((tr) => int.parse(tr.children.first.text)).toList();
		int startIndex;
		if (after == null) {
			startIndex = 0;
		}
		else {
			startIndex = ids.indexOf(after) + 1;
		}
		final endIndex = min(ids.length, startIndex + _kArchivePageSize);
		final selectedIds = ids.sublist(startIndex, endIndex);
		if (selectedIds.isEmpty) {
			return [];
		}
		final cache = await queryPreferredArchive(board, selectedIds, cancelToken: cancelToken).onError((e, st) {
			print('Error querying preferred archive: $e');
			return {};
		});
		return trs.sublist(startIndex, endIndex).map((tr) {
			final id = int.parse(tr.children.first.text);
			final cachedJson = cache[id];
			if (cachedJson != null) {
				return _makeThread(board, jsonDecode(cachedJson) as Map, isArchived: true);
			}
			final excerptNode = tr.children[1];
			String? subject;
			if (excerptNode.children.isNotEmpty && excerptNode.children.first.localName == 'b') {
				subject = excerptNode.children.first.text;
				excerptNode.children.first.remove();
			}
			final text = excerptNode.innerHtml;
			return Thread(
				replyCount: -1,
				imageCount: -1,
				id: id,
				board: board,
				title: subject,
				isSticky: false,
				isArchived: true,
				time: DateTime.fromMicrosecondsSinceEpoch(0),
				attachments: [],
				posts_: [
					Post(
						board: board,
						text: text,
						name: defaultUsername,
						time: DateTime.fromMicrosecondsSinceEpoch(0),
						threadId: id,
						id: id,
						spanFormat: PostSpanFormat.chan4,
						attachments_: const []
					)
				]
			);
		}).toList();
	}

	Thread _makeThread(String board, Map threadData, {int? currentPage, bool isArchived = false}) => unsafe(threadData, () {
		final title = threadData['sub'] as String?;
		final threadId = threadData['no'] as int;
		final Post threadAsPost = _makePost(board, threadId, threadData);
		final List<Post> lastReplies = ((threadData['last_replies'] ?? []) as List).map((postData) => _makePost(board, threadId, postData as Map)).toList();
		final a = _makeAttachment(board, threadId, threadData);
		return Thread(
			board: board,
			id: threadId,
			replyCount: threadData['replies'] as int,
			imageCount: threadData['images'] as int,
			attachments: a == null ? [] : [a],
			posts_: [threadAsPost, ...lastReplies],
			title: (title == null) ? null : unescape.convert(title),
			isSticky: threadData['sticky'] == 1,
			isArchived: isArchived,
			isLocked: threadData['closed'] == 1,
			time: DateTime.fromMillisecondsSinceEpoch((threadData['time'] as int) * 1000),
			currentPage: currentPage
		);
	});

	@override
	RequestOptions getCatalogRequest(String board, {CatalogVariant? variant}) {
		if (variant == CatalogVariant.chan4NativeArchive) {
			return RequestOptions(
				path: '/$board/archive',
				baseUrl: 'https://$baseUrl',
				responseType: ResponseType.plain
			);
		}
		return RequestOptions(
			path: '/$board/catalog.json',
			baseUrl: 'https://$apiUrl',
			responseType: ResponseType.json
		);
	}

	@override
	Future<List<Thread>> makeCatalog(String board, Response response, {CatalogVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) async {
		if (variant == CatalogVariant.chan4NativeArchive) {
			return _makeArchive(board, response, null, cancelToken: cancelToken);
		}
		final List<Thread> threads = [];
		for (final page in (response.data as List).cast<Map>()) {
			for (final threadData in page['threads'] as List) {
				threads.add(_makeThread(board, threadData as Map, currentPage: page['page'] as int?));
			}
		}
		return threads;
	}
	@override
	Future<List<ImageboardBoard>> getBoards({required RequestPriority priority, CancelToken? cancelToken}) async {
		final response = await client.getUri(Uri.https(apiUrl, '/boards.json'), options: Options(
			extra: {
				kPriority: priority
			},
			responseType: ResponseType.json
		), cancelToken: cancelToken);
		return ((response.data as Map)['boards'] as List).cast<Map>().map(wrapUnsafe((board) {
			final cooldowns = board['cooldowns'] as Map? ?? {};
			return ImageboardBoard(
				name: board['board'] as String,
				title: board['title'] as String,
				isWorksafe: board['ws_board'] == 1,
				webmAudioAllowed: board['webm_audio'] == 1,
				maxCommentCharacters: board['max_comment_chars'] as int?,
				maxImageSizeBytes: board['max_filesize'] as int?,
				maxWebmSizeBytes: board['max_webm_filesize'] as int?,
				maxWebmDurationSeconds: board['max_webm_duration'] as int?,
				threadCommentLimit: board['bump_limit'] as int?,
				threadImageLimit: board['image_limit'] as int?,
				pageCount: board['pages'] as int?,
				threadCooldown: cooldowns['threads'] as int?,
				replyCooldown: cooldowns['replies'] as int?,
				imageCooldown: cooldowns['images'] as int?,
				spoilers: board['spoilers'] == 1
			);
		})).toList();
	}

	@override
	Future<List<Thread>> getMoreCatalogImpl(String board, Thread after, {CatalogVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) async {
		if (variant == CatalogVariant.chan4NativeArchive) {
			return _getArchive(board, after.id, priority: priority, cancelToken: cancelToken);
		}
		return [];
	}

	@override
	Future<CaptchaRequest> getCaptchaRequest(String board, int? threadId, {CancelToken? cancelToken}) async {
		if (loginSystem.isLoggedIn(Persistence.currentCookies)) {
			return const NoCaptchaRequest();
		}
		final userAgent = captchaUserAgents[Platform.operatingSystem];
		return Chan4CustomCaptchaRequest(
			challengeUrl: Uri.https(sysUrl, '/captcha', {
				'board': board,
				if (threadId != null) 'thread_id': threadId.toString()
			}),
			challengeHeaders: {
				if (userAgent != null) 'user-agent': userAgent
			},
			possibleLetterCounts: possibleCaptchaLetterCounts,
			hCaptchaKey: hCaptchaKey,
			stickyCloudflare: stickyCloudflare,
			letters: captchaLetters,
			lettersRemap: captchaLettersRemap
		);
	}

	@override
	bool get supportsWebPostingFallback => true;
	@override
	Future<EncodedWebPost> encodePostForWeb(DraftPost post, {CaptchaSolution? captchaSolution}) async {
		final password = makeRandomBase64String(88);
		return (
			password: password,
			fields: {
				'pwd': password,
				'name': post.name ?? '',
				'email': post.options ?? '',
				if (post.subject != null) 'sub': post.subject,
				'com': post.text,
				if (captchaSolution is RecaptchaSolution) 'g-recaptcha-response': captchaSolution.response
				else if (captchaSolution is Chan4CustomCaptchaSolution) ...{
					't-challenge': captchaSolution.challenge,
					't-response': captchaSolution.response
				},
				if (post.flag case final flag?) 'flag': flag.code,
				if (post.file case final file?) 'upfile': await MultipartFile.fromFile(file, filename: post.overrideFilename),
				if (post.spoiler == true) 'spoiler': 'on',
			},
			autoClickSelector: '#togglePostFormLink a'
		);
	}
	
	@override
	Future<PostReceipt> submitPost(DraftPost post, CaptchaSolution captchaSolution, CancelToken cancelToken) async {
		final encoded = await encodePostForWeb(post, captchaSolution: captchaSolution);
		final file = post.file;
		final response = await client.postUri(
			Uri.https(sysUrl, '/${post.board}/post'),
			data: FormData.fromMap({
				'mode': 'regist',
				if (post.threadId != null) 'resto': post.threadId.toString(),
				...encoded.fields
			}),
			options: Options(
				responseType: ResponseType.plain,
				headers: {
					'referer': getWebUrlImpl(post.board, post.threadId),
					'origin': 'https://$baseUrl',
					...postingHeaders
				},
				extra: {
					if (captchaSolution.cloudflare && stickyCloudflare) kCloudflare: true,
					kPriority: RequestPriority.interactive
				}
			),
			cancelToken: cancelToken
		);
		final document = parse(response.data);
		final metaTag = document.querySelector('meta[http-equiv="refresh"]');
		if (metaTag != null) {
			final id = int.tryParse(metaTag.attributes['content']!.split(RegExp(r'\/|(#p)')).last);
			if (id == null) {
				throw PostFailedException('4chan rejected your post. ${file == null ? 'Your post might contained spam-filtered text.' : 'You may have been trying to post an image which is spam-filtered.'}');
			}
			return PostReceipt(
				post: post,
				id: id,
				password: encoded.password,
				name: post.name ?? '',
				options: post.options ?? '',
				time: DateTime.now(),
				ip: captchaSolution.ip,
				// Just use spam filter on every captcha usage
				spamFiltered: switch (captchaSolution) {
					Chan4CustomCaptchaSolution x => x.challenge != 'noop',
					_ => false
				}
			);
		}
		else {
			final errSpan = document.querySelector('#errmsg');
			if (errSpan != null) {
				if (errSpan.text.contains('Duplicate file exists')) {
					final link = errSpan.querySelectorAll('a').tryMapOnce((a) {
						final href = a.attributes['href'];
						if (href == null) {
							return null;
						}
						return Uri.tryParse(getWebUrlImpl(post.board, post.threadId))?.resolve(href);
					});
					if (link != null && (await decodeUrl(link))?.postIdentifier != null) {
						throw DuplicateFileException(link.toString());
					}
				}
				if (errSpan.text.toLowerCase().contains('ban') || errSpan.text.toLowerCase().contains('warn')) {
					throw BannedException(errSpan.text, _bannedUrl);
				}
				String message = errSpan.text;
				if (response.cloudflare && message.toLowerCase().contains('our system thinks your post is spam')) {
					message += '\n--\nNote from Chance: This occurs often when encountering Cloudflare. The post will likely be accepted if you try resubmitting it.';
				}
				final cooldown = _cooldownRegex.firstMatch(message)?.group(1)?.tryParseInt;
				if (cooldown != null) {
					throw PostCooldownException(message, DateTime.now().add(Duration(seconds: cooldown)));
				}
				throw PostFailedException(message, remedies: {
					if (message.contains('verify your e-mail address'))
						'Verify e-mail': (context) => showAuthPageHelperPopup(context, imageboard!)
				});
			}
			else {
				print(response.data);
				throw PostFailedException('Unknown error');
			}
		}
	}

	Uri get _bannedUrl => Uri.https('www.4chan.org', '/banned');

	@override
	Duration getActionCooldown(String board, ImageboardAction action, CookieJar cookies) {
		final b = persistence?.getBoard(board);
		var (Duration cooldown, bool isPassReduced) = switch (action) {
			ImageboardAction.postReply => (Duration(seconds: b?.replyCooldown ?? 0), true),
			ImageboardAction.postReplyWithImage => (Duration(seconds: b?.imageCooldown ?? 0), true),
			ImageboardAction.postThread => (Duration(seconds: b?.threadCooldown ?? 0), true),
			ImageboardAction.report => (reportCooldown, false),
			ImageboardAction.delete => (const Duration(seconds: 3), false)
		};
		if (isPassReduced &&
		    loginSystem.isLoggedIn(cookies)) {
			return cooldown ~/ 2;
		}
		return cooldown;
	}

	@override
	Future<void> deletePost(ThreadIdentifier thread, PostReceipt receipt, CaptchaSolution captchaSolution, CancelToken cancelToken, {required bool imageOnly}) async {
		final response = await client.postUri(
			Uri.https(sysUrl, '/${thread.board}/imgboard.php'),
			data: FormData.fromMap({
				receipt.id.toString(): 'delete',
				'mode': 'usrdel',
				'pwd': receipt.password,
				if (imageOnly) 'onlyimgdel': 'on'
			}),
			options: Options(
				extra: {
					kPriority: RequestPriority.interactive
				},
				responseType: ResponseType.plain
			),
			cancelToken: cancelToken
		);
		if (response.statusCode != 200) {
			throw HTTPStatusException.fromResponse(response);
		}
		final document = parse(response.data);
		final errSpan = document.querySelector('#errmsg');
		if (errSpan != null) {
			if (errSpan.text.contains('You must wait longer')) {
				// Best guess
				throw CooldownException(DateTime.now().add(const Duration(minutes: 1)));
			}
			throw DeletionFailedException(errSpan.text);
		}
	}

	@override
	String getWebUrlImpl(String board, [int? threadId, int? postId]) {
		String webUrl = 'https://$baseUrl/$board/';
		if (threadId != null) {
			webUrl += 'thread/$threadId';
			if (postId != null) {
				webUrl += '#p$postId';
			}
		}
		return webUrl;
	}

	@override
	Uri? getSpoilerImageUrl(Attachment attachment, {Thread? thread}) {
		final customSpoilerId = thread?.customSpoilerId;
		if (customSpoilerId != null) {
			return Uri.https(staticUrl, '/image/spoiler-${attachment.board}$customSpoilerId.png');
		}
		else {
			return Uri.https(staticUrl, '/image/spoiler.png');
		}
	}

	static final _cooldownRegex = RegExp(r'You must wait +(\d+) +seconds before');
	final Map<PostIdentifier, List<ChoiceReportMethodChoice>> _cachedReportForms = {};

	@override
	Future<ImageboardReportMethod> getPostReportMethod(PostIdentifier post, {CancelToken? cancelToken}) async {
		final endpoint = Uri.https(sysUrl, '/${post.board}/imgboard.php', {
			'mode': 'report',
			'no': post.postId.toString()
		});
		Future<void> onSubmit(ChoiceReportMethodChoice choice, CaptchaSolution captchaSolution, {CancelToken? cancelToken}) async {
			final response = await client.postUri(endpoint, data: {
				...choice.value,
				if (captchaSolution is RecaptchaSolution) 'g-recaptcha-response': captchaSolution.response
				else if (captchaSolution is Chan4CustomCaptchaSolution) ...{
					't-response': captchaSolution.response,
					't-challenge': captchaSolution.challenge
				},
				'board': post.board,
				'no': post.postId.toString(),
			}, options: Options(
				responseType: ResponseType.plain,
				contentType: Headers.formUrlEncodedContentType,
				headers: {
					'referer': endpoint.toString()
				},
				extra: {
					kPriority: RequestPriority.interactive,
					if (captchaSolution.cloudflare && stickyCloudflare) kCloudflare: true
				}
			), cancelToken: cancelToken);
			final responseDocument = parse(response.data);
			final message = responseDocument.querySelector('font')?.text;
			if (message == null || !message.contains('submitted')) {
				if (message != null) {
					final lower = message.toLowerCase();
					if (lower.contains('ban') || lower.contains('warn')) {
						throw BannedException(message, _bannedUrl);
					}
				}
				throw ReportFailedException(message ?? 'Could not find response text');
			}
		}
		try {
			final response = await client.getUri(
				endpoint,
				options: Options(
					responseType: ResponseType.plain,
					extra: {
						kPriority: RequestPriority.interactive
					}
				),
				cancelToken: cancelToken
			);
			final document = parse(response.data);
			final error = document.querySelector('h3 > font[color="#FF0000"]')?.text;
			if (error != null) {
				if (error.toLowerCase().contains('wait a while')) {
					// Rate-limited
					// "You have to wait a while before reporting another post"
					final cached = _cachedReportForms[post] ?? _cachedReportForms.entries.tryFirstWhere((e) {
						// Try methods in the same thread
						return e.key.thread == post.thread;
					})?.value ?? _cachedReportForms.entries.tryFirstWhere((e) {
						// Try methods in the same board
						return e.key.board == post.board;
					})?.value;
					if (cached != null) {
						return ChoiceReportMethod(
							choices: cached,
							post: post,
							question: 'Report type',
							getCaptchaRequest: ({CancelToken? cancelToken}) async {
								if (loginSystem.isLoggedIn(Persistence.currentCookies)) {
									return const NoCaptchaRequest();
								}
								return await getCaptchaRequest(post.board, 1, cancelToken: cancelToken);
							},
							onSubmit: onSubmit
						);
					}
				}
				throw ReportFailedException(error);
			}
			final choices = <ChoiceReportMethodChoice>[];
			final cats = document.querySelectorAll('[name="cat"]');
			final knownCat = cats.tryFirstWhere((cat) => cat.attributes['value']?.isEmpty != false);
			if (knownCat == null) {
				throw Exception('Report form changed');
			}
			cats.remove(knownCat);
			choices.addAll(cats.map((cat) => (
				name: document.querySelector('[for="${cat.id}"]')!.text,
				value: {
					'cat': cat.attributes['value']!,
					'cat_id': ''
				}
			)));
			choices.addAll(document.querySelectorAll('#cat-sel option').map((option) => (
				name: option.text,
				value: {
					'cat': '',
					'cat_id': option.attributes['value']!
				}
			)).where((choice) => choice.name.isNotEmpty));
			_cachedReportForms[post] = choices;
			Future.delayed(reportCooldown * 10, () {
				// Lazy cache cleaning
				if (identical(_cachedReportForms[post], choices)) {
					_cachedReportForms.remove(post);
				}
			});
			final captchaScript = document.querySelector('#pass script')?.text ?? '';
			final captchaMatch = RegExp(r"TCaptcha\.init\(document\.getElementById\('t-root'\), '([^']+)', (\d+)\)").firstMatch(captchaScript);
			return ChoiceReportMethod(
				question: 'Report type',
				getCaptchaRequest: ({CancelToken? cancelToken}) async {
					if (loginSystem.isLoggedIn(Persistence.currentCookies)) {
						return const NoCaptchaRequest();
					}
					return await getCaptchaRequest(captchaMatch?.group(1) ?? post.board, captchaMatch?.group(2)?.tryParseInt ?? 1, cancelToken: cancelToken);
				},
				post: post,
				choices: choices,
				onSubmit: onSubmit
			);
		}
		on ReportFailedException {
			// Don't fall back to web form
			rethrow;
		}
		catch (e, st) {
			Future.error(e, st); // Form has changed, report to crashlytics
		}
		// Fallback to web form
		return WebReportMethod(endpoint);
	}

	Site4Chan({
		required this.baseUrl,
		required this.staticUrl,
		required this.sysUrl,
		required this.apiUrl,
		required this.imageUrl,
		required this.name,
		required this.captchaKey,
		required this.hCaptchaKey,
		required super.overrideUserAgent,
		required super.archives,
		required super.imageHeaders,
		required super.videoHeaders,
		required this.captchaUserAgents,
		required this.searchUrl,
		required this.boardFlags,
		required this.boardsWithCountryFlags,
		required this.possibleCaptchaLetterCounts,
		required this.captchaLetters,
		required this.captchaLettersRemap,
		required this.postingHeaders,
		required this.captchaTicketLifetime,
		required this.reportCooldown,
		required this.subjectCharacterLimit,
		required this.spamFilterCaptchaDelayGreen,
		required this.spamFilterCaptchaDelayYellow,
		required this.spamFilterCaptchaDelayRed,
		required this.stickyCloudflare,
	}) : _alternateBaseUrl = baseUrl.contains('chan') ? baseUrl.replaceFirst('chan', 'channel') : null;

	@override
	String get siteType => '4chan';
	@override
	String get siteData => apiUrl;
	
	@override
	Future<BoardThreadOrPostIdentifier?> decodeUrl(Uri url) async {
		if (url.host == baseUrl || url.host == _alternateBaseUrl) {
			switch (url.pathSegments) {
				case [String board, 'thread', String threadId, ...]:
					return BoardThreadOrPostIdentifier(board, threadId.tryParseInt, const ['p', 'q'].tryMapOnce(url.fragment.extractPrefixedInt));
				case [String board, ...]:
					return BoardThreadOrPostIdentifier(board);
			}
		}
		return null;
	}
	
	final Map<String, AsyncMemoizer<List<ImageboardBoardFlag>>> _boardFlags = {};
	@override
	Future<List<ImageboardBoardFlag>> getBoardFlags(String board) {
		return _boardFlags.putIfAbsent(board, () => AsyncMemoizer<List<ImageboardBoardFlag>>()).runOnce(() async {
			Map<String, String> flagMap = boardFlags?[board] ?? {};
			if (boardFlags == null) {
				// Only fetch flags if 'boardFlags' is missing in sites.json
				try {
					final response = await client.getUri(Uri.https(baseUrl, '/$board/'), options: Options(
						responseType: ResponseType.plain
					)).timeout(const Duration(seconds: 5));
					final doc = parse(response.data);
					flagMap = {
						for (final e in doc.querySelector('select[name="flag"]')?.querySelectorAll('option') ?? <dom.Element>[])
							(e.attributes['value'] ?? '0'): e.text
					};
				}
				catch (e, st) {
					print('Failed to fetch flags for $name ${formatBoardName(board)}: ${e.toStringDio()}');
					Future.error(e, st); // crashlytics
				}
			}
			return flagMap.entries.map((entry) => ImageboardBoardFlag(
				code: entry.key,
				name: entry.value,
				imageUrl: Uri.https(staticUrl, '/image/flags/$board/${entry.key.toLowerCase()}.gif').toString()
			)).toList();
		});
	}

	@override
	bool operator ==(Object other) =>
		identical(this, other) ||
		(other is Site4Chan) &&
		(other.name == name) &&
		(other.imageUrl == imageUrl) &&
		(other.captchaKey == captchaKey) &&
		(other.hCaptchaKey == hCaptchaKey) &&
		(other.apiUrl == apiUrl) &&
		(other.sysUrl == sysUrl) &&
		(other.baseUrl == baseUrl) &&
		(other.staticUrl == staticUrl) &&
		(other.boardsWithCountryFlags == boardsWithCountryFlags) &&
		mapEquals(other.captchaUserAgents, captchaUserAgents) &&
		(other.searchUrl == searchUrl) &&
		listEquals(other.possibleCaptchaLetterCounts, possibleCaptchaLetterCounts) &&
		listEquals(other.captchaLetters, captchaLetters) &&
		mapEquals(other.captchaLettersRemap, captchaLettersRemap) &&
		mapEquals(other.postingHeaders, postingHeaders) &&
		(other.captchaTicketLifetime == captchaTicketLifetime) &&
		(other.reportCooldown == reportCooldown) &&
		(other.subjectCharacterLimit == subjectCharacterLimit) &&
		(other.spamFilterCaptchaDelayGreen == spamFilterCaptchaDelayGreen) &&
		(other.spamFilterCaptchaDelayYellow == spamFilterCaptchaDelayYellow) &&
		(other.spamFilterCaptchaDelayRed == spamFilterCaptchaDelayRed) &&
		(other.stickyCloudflare == stickyCloudflare) &&
		super==(other);

	@override
	int get hashCode => baseUrl.hashCode;
	
	@override
	Uri? get iconUrl => Uri.https(baseUrl, '/favicon.ico');

	@override
	String get defaultUsername => 'Anonymous';
	
	@override
	List<ImageboardSnippet> getBoardSnippets(String board) => [
		greentextSnippet,
		if (board == 'g') const ImageboardSnippet.simple(
			icon: CupertinoIcons.chevron_left_slash_chevron_right,
			name: 'Code',
			start: '[code]',
			end: '[/code]',
			previewBuilder: PostCodeSpan.new
		)
		else if (board == 'jp') const ImageboardSnippet.simple(
			icon: CupertinoIcons.text_justify,
			name: 'Shift-JIS',
			start: '[sjis]',
			end: '[/sjis]',
			previewBuilder: PostShiftJISSpan.new
		)
		else if (board == 'sci') const ImageboardSnippet.simple(
			icon: CupertinoIcons.function,
			name: 'Math',
			start: '[math]',
			end: '[/math]',
			previewBuilder: PostTeXSpan.new
		),
		if (persistence?.getBoard(board).spoilers ?? false) const ImageboardSnippet.simple(
			icon: CupertinoIcons.eye_slash,
			name: 'Spoiler',
			start: '[spoiler]',
			end: '[/spoiler]'
		)
	];

	@override
	bool get supportsPushNotifications => true;

	@override
	List<CatalogVariantGroup> get catalogVariantGroups => [
		...super.catalogVariantGroups,
		const CatalogVariantGroup(
			name: 'Archive',
			variants: [CatalogVariant.chan4NativeArchive]
		)
	];

	@override
	ImageboardSearchMetadata supportsSearch(String? board) {
		if (board == null) {
			return ImageboardSearchMetadata(
				name: searchUrl,
				options: const ImageboardSearchOptions(text: true)
			);
		}
		return super.supportsSearch(board);
	}

	@override
	Future<ImageboardArchiveSearchResultPage> search(ImageboardArchiveSearchQuery query, {required int page, ImageboardArchiveSearchResultPage? lastResult, required RequestPriority priority, CancelToken? cancelToken}) async {
		if (query.boards.isNotEmpty) {
			return searchArchives(query, page: page, lastResult: lastResult, priority: priority, cancelToken: cancelToken);
		}
		final userAgent = captchaUserAgents[Platform.operatingSystem];
		final response = await client.getUri(Uri.https(searchUrl, '/', {
			'q': query.query,
			if (page > 1) 'o': ((page - 1) * 10).toString()
		}), options: Options(
			headers: {
				if (userAgent != null) 'user-agent': userAgent
			},
			extra: {
				kPriority: priority
			},
			responseType: ResponseType.plain
		), cancelToken: cancelToken);
		final document = parse(response.data);
		final threads = document.querySelectorAll('.thread').expand((thread) {
			if (thread.querySelector('.post.op') == null) {
				return thread.querySelectorAll('.post.reply').map((post) {
					final linkMatch = RegExp(r'([^\/]+)\/thread\/(\d+)#p(\d+)').firstMatch(post.querySelector('.postNum.desktop a')!.attributes['href']!)!;
					return ImageboardArchiveSearchResult.post(Post(
						board: linkMatch.group(1)!,
						text: post.querySelector('.postMessage')!.innerHtml,
						name: post.querySelector('.name')!.text.trim(),
						time: DateTime.fromMillisecondsSinceEpoch(1000 * int.parse(post.querySelector('.dateTime')!.attributes['data-utc']!)),
						threadId: int.parse(linkMatch.group(2)!),
						id: int.parse(linkMatch.group(3)!),
						spanFormat: PostSpanFormat.chan4Search,
						attachments_: const []
					));
				});
			}
			final threadIdentifierMatch = thread.querySelectorAll('.fileText a').map((e) {
				return RegExp(r'([^\/]+)\/thread\/(\d+)').firstMatch(e.attributes['href'] ?? '');
			}).firstWhere((m) => m != null)!;
			final board = threadIdentifierMatch.group(1)!;
			final threadId = int.parse(threadIdentifierMatch.group(2)!);
			Attachment? attachment;
			final file = thread.querySelector('.file');
			if (file != null) {
				final thumb = file.querySelector('.fileThumb')!;
				final fullUrl = 'https:${thumb.attributes['href']!}'
					// is2.4chan.org seems to have broken SSL
					.replaceFirst('is2.4chan.org', imageUrl);
				final ext = '.${fullUrl.afterLast('.')}';
				final metadata = RegExp(r'\(\s+([\d\.]+)(Mi|Ki)?B,\s+(\d+)x(\d+)\s+\)').firstMatch(file.querySelector('.fileText')!.text)!;
				int multiplier = 1;
				final fileSizePrefix = metadata.group(2)!.toLowerCase();
				if (fileSizePrefix.startsWith('m')) {
					multiplier = 1000 * 1000;
				} else if (fileSizePrefix.startsWith('k')) {
					multiplier = 1000;
				}
				attachment = Attachment(
					board: board,
					id: fullUrl.afterLast('/').beforeFirst('.'),
					type: _getAttachmentType(ext),
					ext: ext,
					filename: file.querySelectorAll('.fileText a').last.text.trim(),
					url: fullUrl,
					thumbnailUrl: 'https:${thumb.querySelector('img')!.attributes['src']!}',
					md5: thumb.querySelector('img')!.attributes['data-md5']!,
					width: int.parse(metadata.group(3)!),
					height: int.parse(metadata.group(4)!),
					threadId: threadId,
					sizeInBytes: (double.parse(metadata.group(1)!) * multiplier).round()
				);
			}
			final posts = thread.querySelectorAll('.post').map((post) {
				final postId = int.parse(RegExp(r'\d+').firstMatch(post.id)!.group(0)!);
				return Post(
					board: board,
					text: post.querySelector('.postMessage')!.innerHtml,
					name: post.querySelector('.name')!.text.trim(),
					time: DateTime.fromMillisecondsSinceEpoch(1000 * int.parse(post.querySelector('.dateTime')!.attributes['data-utc']!)),
					threadId: threadId,
					id: postId,
					spanFormat: PostSpanFormat.chan4Search,
					attachments_: (postId != threadId || attachment == null) ? const [] : [attachment]
				);
			}).toList();
			return [ImageboardArchiveSearchResult.thread(Thread(
				posts_: posts,
				replyCount: 0,
				imageCount: 0,
				id: threadId,
				board: board,
				title: thread.querySelector('.subject')?.text.trim(),
				isSticky: false,
				time: posts.first.time,
				attachments: posts.first.attachments_
			))];
		}).toList();
		return ImageboardArchiveSearchResultPage(
			posts: threads,
			replyCountsUnreliable: true,
			imageCountsUnreliable: true,
			page: page,
			canJumpToArbitraryPage: true,
			count: switch (document.querySelector('.boardBanner .boardTitle')?.text) {
				String text => RegExp(r'(\d+) comments\W*$').firstMatch(text)?.group(1)?.tryParseInt,
				_ => null
			},
			maxPage: int.parse(document.querySelectorAll('.pages a').last.text.trim()),
			archive: this
		);
	}

	@override
	Future<void> clearPseudoCookies() async {
		await Persistence.currentCookies.deletePseudoCookie(kTicketPseudoCookieKey);
	}

	static const kTicketPseudoCookieKey = '4chan_ticket';

	@override
	DateTime getCaptchaUsableTime(CaptchaSolution captcha) {
		if (captcha is Chan4CustomCaptchaSolution && Settings.instance.useSpamFilterWorkarounds) {
			if (captcha.challenge == 'noop') {
				return super.getCaptchaUsableTime(captcha);
			}
			Duration delay = switch (persistence?.getSpamFilterStatus(captcha.ip)) {
				SpamFilterStatus.currently => spamFilterCaptchaDelayRed,
				SpamFilterStatus.recently => spamFilterCaptchaDelayYellow,
				SpamFilterStatus.never || null => spamFilterCaptchaDelayGreen
			};
			if (delay > const Duration(seconds: 4)) {
				// +[0-4]s
				delay += Duration(milliseconds: random.nextInt(4000));
			}
			else {
				// +[0-100]%
				delay *= (1 + random.nextDouble());
			}
			return captcha.acquiredAt.add(delay);
		}
		return super.getCaptchaUsableTime(captcha);
	}

	@override
	Uri? get authPage => Uri.https(sysUrl, '/signin');

	@override
	Set<String> get authPageFormFields => const {'email'};

	@override
	bool get hasLinkCookieAuth => true;

	@override
	bool doesBoardHaveCountryFlags(String board) => boardsWithCountryFlags.contains(board);

	@override
	Future<ImageboardRedirectGateway?> getRedirectGateway(Uri uri, String? Function() title, Future<String?> Function() html) async {
		if (uri.host == sysUrl && uri.path == '/captcha') {
			final h = await html();
			if (h != null && h.contains('https://mcl.spur.us/d/mcl.js') && !h.contains("window.parent.postMessage")) {
				return const ImageboardRedirectGateway(
					name: '4chan firewall',
					alwaysNeedsManualSolving: false
				);
			}
		}
		return null;
	}

	@override
	void migrateFromPrevious(Site4Chan oldSite) {
		super.migrateFromPrevious(oldSite);
		_boardFlags.addAll(oldSite._boardFlags);
	}
}

class Site4ChanPassLoginSystem extends ImageboardSiteLoginSystem {
	@override
	final Site4Chan parent;

	Site4ChanPassLoginSystem(this.parent);

  @override
  List<ImageboardSiteLoginField> getLoginFields() {
    return const [
			ImageboardSiteLoginField(
				displayName: 'Token',
				formKey: 'id',
				autofillHints: [AutofillHints.username]
			),
			ImageboardSiteLoginField(
				displayName: 'PIN',
				formKey: 'pin',
				inputType: TextInputType.number,
				autofillHints: [AutofillHints.password]
			)
		];
  }

  @override
  Future<void> logoutImpl(bool fromBothWifiAndCellular, CancelToken cancelToken) async {
		await parent.client.postUri(
			Uri.https(parent.sysUrl, '/auth'),
			data: FormData.fromMap({
				'logout': '1'
			}),
			options: Options(
				extra: {
					kPriority: RequestPriority.interactive
				}
			),
			cancelToken: cancelToken
		);
		loggedIn[Persistence.currentCookies] = false;
		if (fromBothWifiAndCellular) {
			// No way to log out from non active connection. got to clear the cookies.
			await CookieManager.instance().deleteCookies(
				url: WebUri(parent.sysUrl)
			);
			await Persistence.nonCurrentCookies.deletePreservingCloudflare(Uri.https(parent.sysUrl, '/'), true);
			loggedIn[Persistence.nonCurrentCookies] = false;
		}
  }

  @override
  Future<void> login(Map<ImageboardSiteLoginField, String> fields, CancelToken cancelToken) async {
		final response = await parent.client.postUri(
			Uri.https(parent.sysUrl, '/auth'),
			data: FormData.fromMap({
				for (final field in fields.entries) field.key.formKey: field.value
			}),
			options: Options(
				responseType: ResponseType.plain,
				extra: {
					kPriority: RequestPriority.interactive
				}
			),
			cancelToken: cancelToken
		);
		final document = parse(response.data);
		final message = document.querySelector('h2')?.text;
		if (message == null) {
			loggedIn[Persistence.currentCookies] = false;
			await logout(false, cancelToken);
			throw const ImageboardSiteLoginException('Unexpected response, contact developer');
		}
		if (!message.contains('Success!')) {
			loggedIn[Persistence.currentCookies] = false;
			await logout(false, cancelToken);
			throw ImageboardSiteLoginException(message);
		}
		loggedIn[Persistence.currentCookies] = true;
  }

  @override
  String get name => '4chan Pass';

	@override
	Uri? get iconUrl => Uri.https(parent.staticUrl, '/image/minileaf.gif');

	@override
	bool get hidden => false;
}
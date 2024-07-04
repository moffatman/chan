// ignore_for_file: file_names
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:async/async.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/flag.dart';
import 'package:chan/models/search.dart';
import 'package:chan/services/cloudflare.dart';
import 'package:chan/services/linkifier.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/util.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/captcha_4chan.dart';
import 'package:chan/widgets/util.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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

class _ThreadCacheEntry {
	final Thread thread;
	final String lastModified;
	_ThreadCacheEntry({
		required this.thread,
		required this.lastModified
	});
}

const _catalogCacheLifetime = Duration(seconds: 10);

class _CatalogCacheEntry {
	final int page;
	final DateTime lastModified;
	final int replyCount;

	_CatalogCacheEntry({
		required this.page,
		required this.lastModified,
		required this.replyCount
	});

	@override
	String toString() => '_CatalogCacheEntry(page: $page, lastModified: $lastModified, replyCount: $replyCount)';
}

class _CatalogCache {
	final DateTime lastUpdated;
	final Map<int, _CatalogCacheEntry> entries;

	_CatalogCache({
		required this.lastUpdated,
		required this.entries
	});
}

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
					list.add(_QuoteLinkElement(int.tryParse(match.group(1) ?? '') ?? 0));
					text = text.substring(match.end);
				}
      } else {
        list.add(element);
      }
    }

    return list;
  }
}


class Site4Chan extends ImageboardSite {
	@override
	final String name;
	@override
	final String baseUrl;
	final String staticUrl;
	final String sysUrl;
	final String apiUrl;
	final String searchUrl;
	final String imageUrl;
	final String captchaKey;
	final Map<String, String> captchaUserAgents;
	final List<int> possibleCaptchaLetterCounts;
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
	final Map<String, Map<String, String>> boardFlags;
	Map<String, _ThreadCacheEntry> _threadCache = {};
	Map<String, _CatalogCache> _catalogCaches = {};
	final bool stickyCloudflare;

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
			print(challenge);
		}
		catch (e, st) {
			print(e);
			print(st);
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
			_onCaptchaTicketTimerFire();
			resetCaptchaTicketTimer();
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
	void migrateFromPrevious(Site4Chan oldSite) {
		super.migrateFromPrevious(oldSite);
		_threadCache = oldSite._threadCache;
		_catalogCaches = oldSite._catalogCaches;
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
		]).map((elem) {
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
	static final _trailingBrPattern = RegExp(r'<br>$');

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
							for (final pair in (node.attributes['style']?.split(';') ?? [])) pair.split(':').first: pair.split(':').last
						};
						if (css['color'] != null) {
							elements.add(PostColorSpan(makeSpan(board, threadId, node.innerHtml), colorToHex(css['color'])));
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
						elements.add(PostShiftJISSpan(makeSpan(board, threadId, node.innerHtml).buildText()));
					}
					else {
						elements.add(PostTextSpan(node.text));
					}
				}
				else if (node.localName == 's') {
					elements.add(PostSpoilerSpan(makeSpan(board, threadId, node.innerHtml), spoilerSpanId++));
				}
				else if (node.localName == 'pre') {
					elements.add(PostCodeSpan(unescape.convert(node.innerHtml.replaceFirst(_trailingBrPattern, '').replaceAll('<br>', '\n'))));
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

	ImageboardFlag? _makeFlag(dynamic data, String board) {
		if (data['country'] != null) {
			return ImageboardFlag(
				name: unescape.convert(data['country_name']),
				imageUrl: Uri.https(staticUrl, '/image/country/${data['country'].toLowerCase()}.gif').toString(),
				imageWidth: 16,
				imageHeight: 11
			);
		}
		else if (data['troll_country'] != null) {
			return ImageboardFlag(
				name: unescape.convert(data['country_name']),
				imageUrl: Uri.https(staticUrl, '/image/country/troll/${data['troll_country'].toLowerCase()}.gif').toString(),
				imageWidth: 16,
				imageHeight: 11
			);
		}
		else if (data['board_flag'] != null) {
			return ImageboardFlag(
				name: unescape.convert(data['flag_name']),
				imageUrl: Uri.https(staticUrl, '/image/flags/$board/${data['board_flag'].toLowerCase()}.gif').toString(),
				imageWidth: 16,
				imageHeight: 11
			);
		}
		return null;
	}

	Post _makePost(String board, int threadId, dynamic data) {
		final a = _makeAttachment(board, threadId, data);
		return Post(
			board: board,
			text: data['com'] ?? '',
			name: unescape.convert(data['name'] ?? ''),
			trip: data['trip'],
			time: DateTime.fromMillisecondsSinceEpoch(data['time'] * 1000),
			id: data['no'],
			threadId: threadId,
			attachments_: a == null ? const [] : [a].toList(growable: false),
			attachmentDeleted: data['filedeleted'] == 1,
			spanFormat: PostSpanFormat.chan4,
			flag: _makeFlag(data, board),
			posterId: data['id'],
			passSinceYear: data['since4pass'],
			capcode: data['capcode']
		);
	}
	Attachment? _makeAttachment(String board, int threadId, dynamic data) {
		if (data['tim'] != null) {
			final int id = data['tim'];
			final String ext = data['ext'];
			return Attachment(
				id: id.toString(),
				type: data['ext'] == '.webm' ? AttachmentType.webm : (data['ext'] == '.pdf' ? AttachmentType.pdf : AttachmentType.image),
				filename: unescape.convert(data['filename'] ?? '') + (data['ext'] ?? ''),
				ext: ext,
				board: board,
				url: Uri.https(imageUrl, '/$board/$id$ext').toString(),
				thumbnailUrl: Uri.https(imageUrl, '/$board/${id}s.jpg').toString(),
				md5: data['md5'],
				spoiler: data['spoiler'] == 1,
				width: data['w'],
				height: data['h'],
				threadId: threadId,
				sizeInBytes: data['fsize']
			);
		}
		return null;
	}

	Future<int?> _getThreadPage(ThreadIdentifier thread, {required RequestPriority priority}) async {
		final now = DateTime.now();
		if (_catalogCaches[thread.board] == null || now.difference(_catalogCaches[thread.board]!.lastUpdated).compareTo(_catalogCacheLifetime) > 0) {
			final response = await client.getUri(Uri.https(apiUrl, '/${thread.board}/catalog.json'), options: Options(
				validateStatus: (x) => true,
				extra: {
					kPriority: priority
				}
			));
			if (response.statusCode != 200) {
				if (response.statusCode == 404) {
					return Future.error(BoardNotFoundException(thread.board));
				}
				else {
					return Future.error(HTTPStatusException(response.statusCode!));
				}
			}
			final Map<int, _CatalogCacheEntry> entries = {};
			for (final page in response.data) {
				for (final threadData in page['threads']) {
					entries[threadData['no']] = _CatalogCacheEntry(
						page: page['page'],
						replyCount: threadData['replies'],
						lastModified: DateTime.fromMillisecondsSinceEpoch(threadData['last_modified'] * 1000)
					);
				}
			}
			_catalogCaches[thread.board] = _CatalogCache(
				lastUpdated: now,
				entries: entries
			);
		}
		return _catalogCaches[thread.board]!.entries[thread.id]?.page;
	}

	@override
	Future<Thread> getThreadImpl(ThreadIdentifier thread, {ThreadVariant? variant, required RequestPriority priority}) async {
		Map<String, String>? headers;
		if (_threadCache['${thread.board}/${thread.id}'] != null) {
			headers = {
				'If-Modified-Since': _threadCache['${thread.board}/${thread.id}']!.lastModified
			};
		}
		final response = await client.getUri(
			Uri.https(apiUrl,'/${thread.board}/thread/${thread.id}.json'),
			options: Options(
				headers: headers,
				validateStatus: (x) => true,
				extra: {
					kPriority: priority
				}
			)
		);
		if (response.statusCode == 200) {
			final data = response.data;
			final String? title = data['posts']?[0]?['sub'];
			final a = _makeAttachment(thread.board, thread.id, data['posts'][0]);
			final output = Thread(
				board: thread.board,
				isDeleted: false,
				replyCount: data['posts'][0]['replies'],
				imageCount: data['posts'][0]['images'],
				isArchived: (data['posts'][0]['archived'] ?? 0) == 1,
				posts_: (data['posts'] ?? []).map<Post>((postData) {
					return _makePost(thread.board, thread.id, postData);
				}).toList(),
				id: data['posts'][0]['no'],
				attachments: a == null ? [] : [a],
				attachmentDeleted: data['posts'][0]['filedeleted'] == 1,
				title: (title == null) ? null : unescape.convert(title),
				isSticky: data['posts'][0]['sticky'] == 1,
				time: DateTime.fromMillisecondsSinceEpoch(data['posts'][0]['time'] * 1000),
				currentPage: await _getThreadPage(thread, priority: priority),
				uniqueIPCount: data['posts'][0]['unique_ips'],
				customSpoilerId: data['posts'][0]['custom_spoiler']
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
			_threadCache['${thread.board}/${thread.id}'] = _ThreadCacheEntry(
				thread: output,
				lastModified: response.headers.value('last-modified')!
			);
		}
		else if (!(response.statusCode == 304 && headers != null)) {
			if (response.statusCode == 404) {
				throw const ThreadNotFoundException();
			}
			throw HTTPStatusException(response.statusCode!);
		}
		_threadCache['${thread.board}/${thread.id}']!.thread.currentPage = await _getThreadPage(thread, priority: priority);
		return _threadCache['${thread.board}/${thread.id}']!.thread;
	}

	@override
	Future<Post> getPost(String board, int id, {required RequestPriority priority}) async {
		throw Exception('Not implemented');
	}

	static const _kArchivePageSize = 100;
	Future<List<Thread>> _getArchive(String board, int? after, {required RequestPriority priority}) async {
		final response = await client.getUri(Uri.https(baseUrl, '/$board/archive'), options: Options(
			validateStatus: (x) => true,
			extra: {
				kPriority: priority
			}
		));
		if (response.statusCode != 200) {
			if (response.statusCode == 404) {
				return Future.error(BoardNotFoundException(board));
			}
			else {
				return Future.error(HTTPStatusException(response.statusCode!));
			}
		}
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
		final cache = await queryPreferredArchive(board, selectedIds).onError((e, st) {
			print('Error querying preferred archive: $e');
			return {};
		});
		return trs.sublist(startIndex, endIndex).map((tr) {
			final id = int.parse(tr.children.first.text);
			final cachedJson = cache[id];
			if (cachedJson != null) {
				return _makeThread(board, jsonDecode(cachedJson), isArchived: true);
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

	Thread _makeThread(String board, dynamic threadData, {int? currentPage, bool isArchived = false}) {
		final String? title = threadData['sub'];
		final int threadId = threadData['no'];
		final Post threadAsPost = _makePost(board, threadId, threadData);
		final List<Post> lastReplies = ((threadData['last_replies'] ?? []) as List<dynamic>).map((postData) => _makePost(board, threadId, postData)).toList();
		final a = _makeAttachment(board, threadId, threadData);
		return Thread(
			board: board,
			id: threadId,
			replyCount: threadData['replies'],
			imageCount: threadData['images'],
			attachments: a == null ? [] : [a],
			posts_: [threadAsPost, ...lastReplies],
			title: (title == null) ? null : unescape.convert(title),
			isSticky: threadData['sticky'] == 1,
			isArchived: isArchived,
			time: DateTime.fromMillisecondsSinceEpoch(threadData['time'] * 1000),
			currentPage: currentPage
		);
	}

	@override
	Future<List<Thread>> getCatalogImpl(String board, {CatalogVariant? variant, required RequestPriority priority}) async {
		if (variant == CatalogVariant.chan4NativeArchive) {
			return _getArchive(board, null, priority: priority);
		}
		final response = await client.getUri(Uri.https(apiUrl, '/$board/catalog.json'), options: Options(
			validateStatus: (x) => true,
			extra: {
				kPriority: priority
			}
		));
		if (response.statusCode != 200) {
			if (response.statusCode == 404) {
				return Future.error(BoardNotFoundException(board));
			}
			else {
				return Future.error(HTTPStatusException(response.statusCode!));
			}
		}
		final List<Thread> threads = [];
		for (final page in response.data) {
			for (final threadData in page['threads']) {
				threads.add(_makeThread(board, threadData, currentPage: page['page']));
			}
		}
		return threads;
	}
	@override
	Future<List<ImageboardBoard>> getBoards({required RequestPriority priority}) async {
		final response = await client.getUri(Uri.https(apiUrl, '/boards.json'), options: Options(
			extra: {
				kPriority: priority
			}
		));
		return (response.data['boards'] as List<dynamic>).map((board) {
			return ImageboardBoard(
				name: board['board'],
				title: board['title'],
				isWorksafe: board['ws_board'] == 1,
				webmAudioAllowed: board['webm_audio'] == 1,
				maxCommentCharacters: board['max_comment_chars'],
				maxImageSizeBytes: board['max_filesize'],
				maxWebmSizeBytes: board['max_webm_filesize'],
				maxWebmDurationSeconds: board['max_webm_duration'],
				threadCommentLimit: board['bump_limit'],
				threadImageLimit: board['image_limit'],
				pageCount: board['pages'],
				threadCooldown: board['cooldowns']?['threads'],
				replyCooldown: board['cooldowns']?['replies'],
				imageCooldown: board['cooldowns']?['images'],
				spoilers: board['spoilers'] == 1
			);
		}).toList();
	}

	@override
	Future<List<Thread>> getMoreCatalogImpl(String board, Thread after, {CatalogVariant? variant, required RequestPriority priority}) async {
		if (variant == CatalogVariant.chan4NativeArchive) {
			return _getArchive(board, after.id, priority: priority);
		}
		return [];
	}

	@override
	Future<CaptchaRequest> getCaptchaRequest(String board, [int? threadId]) async {
		if (loginSystem.isLoggedIn(Persistence.currentCookies)) {
			return const NoCaptchaRequest();
		}
		final userAgent = captchaUserAgents[Platform.operatingSystem];
		return Chan4CustomCaptchaRequest(
			challengeUrl: Uri.https(sysUrl, '/captcha', {
				'framed': '1',
				'board': board,
				if (threadId != null) 'thread_id': threadId.toString()
			}),
			challengeHeaders: {
				if (userAgent != null) 'user-agent': userAgent
			},
			possibleLetterCounts: possibleCaptchaLetterCounts,
			stickyCloudflare: stickyCloudflare
		);
	}

	
	@override
	Future<PostReceipt> submitPost(DraftPost post, CaptchaSolution captchaSolution, CancelToken cancelToken) async {
		final password = makeRandomBase64String(88);
		final file = post.file;
		final flag = post.flag;
		final response = await client.postUri(
			Uri.https(sysUrl, '/${post.board}/post'),
			data: FormData.fromMap({
				if (post.threadId != null) 'resto': post.threadId.toString(),
				if (post.subject != null) 'sub': post.subject,
				'com': post.text,
				'mode': 'regist',
				'pwd': password,
				'name': post.name ?? '',
				'email': post.options ?? '',
				if (captchaSolution is RecaptchaSolution) 'g-recaptcha-response': captchaSolution.response
				else if (captchaSolution is Chan4CustomCaptchaSolution) ...{
					't-challenge': captchaSolution.challenge,
					't-response': captchaSolution.response
				},
				if (file != null) 'upfile': await MultipartFile.fromFile(file, filename: post.overrideFilename),
				if (post.spoiler == true) 'spoiler': 'on',
				if (flag != null) 'flag': flag.code
			}),
			options: Options(
				responseType: ResponseType.plain,
				headers: {
					'referer': getWebUrlImpl(post.board, post.threadId),
					'origin': 'https://$baseUrl',
					...postingHeaders
				},
				extra: {
					if (captchaSolution.cloudflare && stickyCloudflare) 'cloudflare': true
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
				password: password,
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
				if (errSpan.text.toLowerCase().contains('ban') || errSpan.text.toLowerCase().contains('warn')) {
					throw BannedException(errSpan.text, _bannedUrl);
				}
				String message = errSpan.text;
				if (response.cloudflare && message.toLowerCase().contains('our system thinks your post is spam')) {
					message += '\n--\nNote from Chance: This occurs often when encountering Cloudflare. The post will likely be accepted if you try resubmitting it.';
				}
				final cooldown = int.tryParse(_cooldownRegex.firstMatch(message)?.group(1) ?? '');
				if (cooldown != null) {
					throw PostCooldownException(message, DateTime.now().add(Duration(seconds: cooldown)));
				}
				throw PostFailedException(message);
			}
			else {
				print(response.data);
				throw PostFailedException('Unknown error');
			}
		}
	}

	Uri get _bannedUrl => Uri.https('www.4chan.org', '/banned');

	@override
	Duration getActionCooldown(String board, ImageboardAction action, bool cellular) {
		final b = persistence?.getBoard(board);
		var (Duration cooldown, bool isPassReduced) = switch (action) {
			ImageboardAction.postReply => (Duration(seconds: b?.replyCooldown ?? 0), true),
			ImageboardAction.postReplyWithImage => (Duration(seconds: b?.imageCooldown ?? 0), true),
			ImageboardAction.postThread => (Duration(seconds: b?.threadCooldown ?? 0), true),
			ImageboardAction.report => (reportCooldown, false),
			ImageboardAction.delete => (const Duration(seconds: 3), false)
		};
		if (isPassReduced &&
		    loginSystem.isLoggedIn(cellular ? Persistence.cellularCookies : Persistence.wifiCookies)) {
			return cooldown ~/ 2;
		}
		return cooldown;
	}

	@override
	Future<void> deletePost(ThreadIdentifier thread, PostReceipt receipt, CaptchaSolution captchaSolution) async {
		final response = await client.postUri(
			Uri.https(sysUrl, '/${thread.board}/imgboard.php'),
			data: FormData.fromMap({
				receipt.id.toString(): 'delete',
				'mode': 'usrdel',
				'pwd': receipt.password
			})
		);
		if (response.statusCode != 200) {
			throw HTTPStatusException(response.statusCode!);
		}
		final document = parse(response.data);
		final errSpan = document.querySelector('#errmsg');
		if (errSpan != null) {
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
	Uri? getSpoilerImageUrl(Attachment attachment, {ThreadIdentifier? thread}) {
		final customSpoilerId = (thread == null) ? null : _threadCache['${thread.board}/${thread.id}']?.thread.customSpoilerId;
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
	Future<ImageboardReportMethod> getPostReportMethod(PostIdentifier post) async {
		final endpoint = Uri.https(sysUrl, '/${post.board}/imgboard.php', {
			'mode': 'report',
			'no': post.postId.toString()
		});
		Future<void> onSubmit(ChoiceReportMethodChoice choice, CaptchaSolution captchaSolution) async {
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
					if (captchaSolution.cloudflare && stickyCloudflare) 'cloudflare': true
				}
			));
			final responseDocument = parse(response.data);
			final message = responseDocument.querySelector('font')?.text;
			if (message == null || !message.contains('submitted')) {
				throw ReportFailedException(message ?? 'Could not find response text');
			}
		}
		try {
			final response = await client.getUri(endpoint);
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
							getCaptchaRequest: () async {
								if (loginSystem.isLoggedIn(Persistence.currentCookies)) {
									return const NoCaptchaRequest();
								}
								return await getCaptchaRequest(post.board, 1);
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
			Future.delayed(reportCooldown * 2, () {
				// Lazy cache cleaning
				if (identical(_cachedReportForms[post], choices)) {
					_cachedReportForms.remove(post);
				}
			});
			final captchaScript = document.querySelector('#pass script')?.text ?? '';
			final captchaMatch = RegExp(r"TCaptcha\.init\(document\.getElementById\('t-root'\), '([^']+)', (\d+)\)").firstMatch(captchaScript);
			return ChoiceReportMethod(
				question: 'Report type',
				getCaptchaRequest: () async {
					if (loginSystem.isLoggedIn(Persistence.currentCookies)) {
						return const NoCaptchaRequest();
					}
					return await getCaptchaRequest(captchaMatch?.group(1) ?? post.board, int.tryParse(captchaMatch?.group(2) ?? '') ?? 1);
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
		super.platformUserAgents,
		super.archives,
		required this.captchaUserAgents,
		required this.searchUrl,
		required this.boardFlags,
		required this.possibleCaptchaLetterCounts,
		required this.postingHeaders,
		required this.captchaTicketLifetime,
		required this.reportCooldown,
		required this.subjectCharacterLimit,
		required this.spamFilterCaptchaDelayGreen,
		required this.spamFilterCaptchaDelayYellow,
		required this.spamFilterCaptchaDelayRed,
		required this.stickyCloudflare,
	});



	@override
	Uri get passIconUrl => Uri.https(staticUrl, '/image/minileaf.gif');

	@override
	String get siteType => '4chan';
	@override
	String get siteData => apiUrl;

	BoardThreadOrPostIdentifier? _decodeUrl(String base, String url) {
		final pattern = RegExp(r'https?:\/\/' + base.replaceAll('.', r'\.') + r'\/([^\/]+)\/(thread\/(\d+)(\/?#[pq](\d+))?)?');
		final match = pattern.firstMatch(url);
		if (match != null) {
			return BoardThreadOrPostIdentifier(match.group(1)!, int.tryParse(match.group(3) ?? ''), int.tryParse(match.group(5) ?? ''));
		}
		return null;
	}
	
	@override
	Future<BoardThreadOrPostIdentifier?> decodeUrl(String url) async {
		if (baseUrl.contains('chan')) {
			return _decodeUrl(baseUrl, url) ?? _decodeUrl(baseUrl.replaceFirst('chan', 'channel'), url);
		}
		return _decodeUrl(baseUrl, url);
	}
	
	final Map<String, AsyncMemoizer<List<ImageboardBoardFlag>>> _boardFlags = {};
	@override
	Future<List<ImageboardBoardFlag>> getBoardFlags(String board) {
		return _boardFlags.putIfAbsent(board, () => AsyncMemoizer<List<ImageboardBoardFlag>>()).runOnce(() async {
			Map<String, String> flagMap = boardFlags[board] ?? {};
			try {
				final response = await client.getUri(Uri.https(baseUrl, '/$board/')).timeout(const Duration(seconds: 5));
				final doc = parse(response.data);
				flagMap = {
					for (final e in doc.querySelector('select[name="flag"]')?.querySelectorAll('option') ?? [])
						(e.attributes['value'] ?? 0): e.text
				};
			}
			catch (e, st) {
				print('Failed to fetch flags for $name ${formatBoardName(board)}: ${e.toStringDio()}');
				Future.error(e, st); // crashlytics
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
		(other.apiUrl == apiUrl) &&
		(other.sysUrl == sysUrl) &&
		(other.baseUrl == baseUrl) &&
		(other.staticUrl == staticUrl) &&
		listEquals(other.archives, archives) &&
		mapEquals(other.captchaUserAgents, captchaUserAgents) &&
		mapEquals(other.platformUserAgents, platformUserAgents) &&
		(other.searchUrl == searchUrl) &&
		listEquals(other.possibleCaptchaLetterCounts, possibleCaptchaLetterCounts) &&
		mapEquals(other.postingHeaders, postingHeaders) &&
		(other.captchaTicketLifetime == captchaTicketLifetime) &&
		(other.reportCooldown == reportCooldown) &&
		(other.subjectCharacterLimit == subjectCharacterLimit) &&
		(other.spamFilterCaptchaDelayGreen == spamFilterCaptchaDelayGreen) &&
		(other.spamFilterCaptchaDelayYellow == spamFilterCaptchaDelayYellow) &&
		(other.spamFilterCaptchaDelayRed == spamFilterCaptchaDelayRed) &&
		(other.stickyCloudflare == stickyCloudflare);

	@override
	int get hashCode => Object.hash(name, imageUrl, captchaKey, apiUrl, sysUrl, baseUrl, staticUrl, archives, captchaUserAgents, platformUserAgents, searchUrl, possibleCaptchaLetterCounts, postingHeaders, captchaTicketLifetime, reportCooldown, subjectCharacterLimit, spamFilterCaptchaDelayGreen, spamFilterCaptchaDelayYellow, spamFilterCaptchaDelayRed, stickyCloudflare);
	
	@override
	Uri get iconUrl => Uri.https(baseUrl, '/favicon.ico');

	@override
	String get defaultUsername => 'Anonymous';
	
	@override
	Iterable<ImageboardSnippet> getBoardSnippets(String board) sync* {
		yield greentextSnippet;
		if (board == 'g') {
			yield const ImageboardSnippet.simple(
				icon: CupertinoIcons.chevron_left_slash_chevron_right,
				name: 'Code',
				start: '[code]',
				end: '[/code]',
				previewBuilder: PostCodeSpan.new
			);
		}
		else if (board == 'jp') {
			yield const ImageboardSnippet.simple(
				icon: CupertinoIcons.text_justify,
				name: 'Shift-JIS',
				start: '[sjis]',
				end: '[/sjis]',
				previewBuilder: PostShiftJISSpan.new
			);
		}
		else if (board == 'sci') {
			yield const ImageboardSnippet.simple(
				icon: CupertinoIcons.function,
				name: 'Math',
				start: '[math]',
				end: '[/math]',
				previewBuilder: PostTeXSpan.new
			);
		}
		if (persistence?.getBoard(board).spoilers == true) {
			yield const ImageboardSnippet.simple(
				icon: CupertinoIcons.eye_slash,
				name: 'Spoiler',
				start: '[spoiler]',
				end: '[/spoiler]'
			);
		}
	}

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
	Future<ImageboardArchiveSearchResultPage> search(ImageboardArchiveSearchQuery query, {required int page, ImageboardArchiveSearchResultPage? lastResult}) async {
		if (query.boards.isNotEmpty) {
			return searchArchives(query, page: page, lastResult: lastResult);
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
				kPriority: RequestPriority.interactive
			}
		));
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
				final ext = '.${fullUrl.split('.').last}';
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
					id: fullUrl.split('/').last.split('.').first,
					type: ext == '.webm' ? AttachmentType.webm : (ext == '.pdf' ? AttachmentType.pdf : AttachmentType.image),
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
			countsUnreliable: true,
			page: page,
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
			final receipts = Persistence.sharedThreadStateBox.values.expand<PostReceipt>((state) {
				if (state.imageboardKey != persistence?.imageboardKey) {
					return const Iterable.empty();
				}
				return state.receipts.where((r) => r.ip == captcha.ip);
			}).toList();
			final nullTime = DateTime(2000);
			receipts.sort((a, b) {
				return (a.time ?? nullTime).compareTo(b.time ?? nullTime);
			});
			// Sorted so newest receipt is last
			Duration delay;
			if (receipts.isEmpty) {
				// Fresh IP
				delay = spamFilterCaptchaDelayGreen;
			}
			else if (receipts.last.spamFiltered) {
				// Last post was spam-filtered
				delay = spamFilterCaptchaDelayRed;
			}
			else if (receipts.any((r) => r.spamFiltered) && captcha.ip != null) {
				// Some previous post was spam-filtered
				delay = spamFilterCaptchaDelayYellow;
			}
			else {
				// Never spam-filtered
				delay = spamFilterCaptchaDelayGreen;
			}
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
	bool get hasEmailLinkCookieAuth => true;
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
  Future<void> logout(bool fromBothWifiAndCellular) async {
		if (!fromBothWifiAndCellular && loggedIn[Persistence.currentCookies] == false) {
			// No need to clear
			return;
		}
		// loggedIn may be null here. Logout is still appropriate because we could be logged in from previous session.
		final jars = fromBothWifiAndCellular ? [
			Persistence.wifiCookies,
			Persistence.cellularCookies
		] : [
			Persistence.currentCookies
		];
		for (final jar in jars) {
			final toSave = (await jar.loadForRequest(Uri.https(parent.sysUrl, '/'))).where((cookie) {
				return cookie.name == 'cf_clearance';
			}).toList();
			await jar.delete(Uri.https(parent.sysUrl, '/'), true);
			await jar.delete(Uri.https(parent.sysUrl, '/'), true);
			await jar.saveFromResponse(Uri.https(parent.sysUrl, '/'), toSave);
			await CookieManager.instance().deleteCookies(
				url: WebUri(parent.sysUrl)
			);
			loggedIn[jar] = false;
		}
  }

  @override
  Future<void> login(Map<ImageboardSiteLoginField, String> fields) async {
		final response = await parent.client.postUri(
			Uri.https(parent.sysUrl, '/auth'),
			data: FormData.fromMap({
				for (final field in fields.entries) field.key.formKey: field.value
			})
		);
		final document = parse(response.data);
		final message = document.querySelector('h2')?.text;
		if (message == null) {
			loggedIn[Persistence.currentCookies] = false;
			await logout(false);
			throw const ImageboardSiteLoginException('Unexpected response, contact developer');
		}
		if (!message.contains('Success!')) {
			loggedIn[Persistence.currentCookies] = false;
			await logout(false);
			throw ImageboardSiteLoginException(message);
		}
		loggedIn[Persistence.currentCookies] = true;
  }

  @override
  String get name => '4chan Pass';
}
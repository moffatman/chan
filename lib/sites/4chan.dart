// ignore_for_file: file_names
import 'dart:io';

import 'package:async/async.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/flag.dart';
import 'package:chan/services/cloudflare.dart';
import 'package:chan/services/linkifier.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/util.dart';
import 'package:chan/widgets/util.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
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

class Site4Chan extends ImageboardSite {
	@override
	final String name;
	@override
	final String baseUrl;
	final String staticUrl;
	final String sysRedUrl;
	final String sysBlueUrl;
	final String apiUrl;
	@override
	final String imageUrl;
	final String captchaKey;
	final Map<String, _ThreadCacheEntry> _threadCache = {};
	final Map<String, _CatalogCache> _catalogCaches = {};
	final Map<PersistCookieJar, bool> _passEnabled = {};
	final _lastActionTime = {
		ImageboardAction.postReply: <String, DateTime>{},
		ImageboardAction.postReplyWithImage: <String, DateTime>{},
		ImageboardAction.postThread: <String, DateTime>{},
	};

	String _sysUrl(String board) => persistence.getBoard(board).isWorksafe ? sysBlueUrl : sysRedUrl;

	static List<PostSpan> parsePlaintext(String text) {
		return linkify(text, linkifiers: const [LooseUrlLinkifier(), ChanceLinkifier()]).map((elem) {
			if (elem is UrlElement) {
				return PostLinkSpan(elem.url, name: elem.text);
			}
			else {
				return PostTextSpan(elem.text);
			}
		}).toList();
	}

	static PostNodeSpan makeSpan(String board, int threadId, String data) {
		final body = parseFragment(data.replaceAll('<wbr>', '').replaceAllMapped(RegExp(r'\[math\](.+?)\[\/math\]'), (match) {
			return '<tex>${match.group(1)!}</tex>';
		}).replaceAllMapped(RegExp(r'\[eqn\](.+?)\[\/eqn\]'), (match) {
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
							postId: int.parse(node.attributes['href']!.substring(2)),
							dead: false
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
							postId: int.parse(ids[1]),
							dead: false
						));
					}
					else {
						// href looks like '//boards.4chan.org/pol/'
						final parts = node.attributes['href']!.split('/');
						final catalogSearchMatch = RegExp(r'^catalog#s=(.+)$').firstMatch(parts.last);
						if (catalogSearchMatch != null) {
							elements.add(PostCatalogSearchSpan(board: parts[parts.length - 2], query: catalogSearchMatch.group(1)!));
						}
						else {
							elements.add(PostBoardLink(parts[parts.length - 2]));
						}
					}
				}
				else if (node.localName == 'span') {
					if (node.classes.contains('deadlink')) {
						final parts = node.innerHtml.replaceAll('&gt;', '').split('/');
						elements.add(PostQuoteLinkSpan(
							board: (parts.length > 2) ? parts[1] : board,
							postId: int.tryParse(parts.last) ?? -1,
							dead: true
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
									tableRows.add(PostTextSpan(row.firstChild!.text!, underlined: true));
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
					else {
						elements.add(PostTextSpan(node.text));
					}
				}
				else if (node.localName == 's') {
					elements.add(PostSpoilerSpan(makeSpan(board, threadId, node.innerHtml), spoilerSpanId++));
				}
				else if (node.localName == 'pre') {
					elements.add(PostCodeSpan(unescape.convert(node.innerHtml.replaceFirst(RegExp(r'<br>$'), '').replaceAll('<br>', '\n'))));
				}
				else if (node.localName == 'b' || node.localName == 'strong') {
					elements.add(PostBoldSpan(makeSpan(board, threadId, node.innerHtml)));
				}
				else {
					elements.addAll(parsePlaintext(node.text));
				}
			}
			else {
				elements.addAll(parsePlaintext(node.text ?? ''));
			}
		}
		return PostNodeSpan(elements);
	}

	ImageboardFlag? _makeFlag(dynamic data, String board) {
		if (data['country'] != null) {
			return ImageboardFlag(
				name: data['country_name'],
				imageUrl: Uri.https(staticUrl, '/image/country/${data['country'].toLowerCase()}.gif').toString(),
				imageWidth: 16,
				imageHeight: 11
			);
		}
		else if (data['troll_country'] != null) {
			return ImageboardFlag(
				name: data['country_name'],
				imageUrl: Uri.https(staticUrl, '/image/country/troll/${data['troll_country'].toLowerCase()}.gif').toString(),
				imageWidth: 16,
				imageHeight: 11
			);
		}
		else if (data['board_flag'] != null) {
			return ImageboardFlag(
				name: data['flag_name'],
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
			attachments: a == null ? [] : [a],
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
				url: Uri.https(imageUrl, '/$board/$id$ext'),
				thumbnailUrl: Uri.https(imageUrl, '/$board/${id}s.jpg'),
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

	Future<int?> _getThreadPage(ThreadIdentifier thread) async {
		final now = DateTime.now();
		if (_catalogCaches[thread.board] == null || now.difference(_catalogCaches[thread.board]!.lastUpdated).compareTo(_catalogCacheLifetime) > 0) {
			final response = await client.get(Uri.https(apiUrl, '/${thread.board}/catalog.json').toString(), options: Options(
				validateStatus: (x) => true
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
	Future<Thread> getThread(ThreadIdentifier thread, {ThreadVariant? variant}) async {
		Map<String, String>? headers;
		if (_threadCache['${thread.board}/${thread.id}'] != null) {
			headers = {
				'If-Modified-Since': _threadCache['${thread.board}/${thread.id}']!.lastModified
			};
		}
		final response = await client.get(
			Uri.https(apiUrl,'/${thread.board}/thread/${thread.id}.json').toString(),
			options: Options(
				headers: headers,
				validateStatus: (x) => true
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
				flag: _makeFlag(data['posts'][0], thread.board),
				currentPage: await _getThreadPage(thread),
				uniqueIPCount: data['posts'][0]['unique_ips'],
				customSpoilerId: data['posts'][0]['custom_spoiler']
			);
			_threadCache['${thread.board}/${thread.id}'] = _ThreadCacheEntry(
				thread: output,
				lastModified: response.headers.value('last-modified')!
			);
			for (final attachment in output.attachments) {
				await ensureCookiesMemoized(attachment.url);
				await ensureCookiesMemoized(attachment.thumbnailUrl);
			}
		}
		else if (!(response.statusCode == 304 && headers != null)) {
			if (response.statusCode == 404) {
				return Future.error(ThreadNotFoundException(thread));
			}
			return Future.error(HTTPStatusException(response.statusCode!));
		}
		_threadCache['${thread.board}/${thread.id}']!.thread.currentPage = await _getThreadPage(thread);
		return _threadCache['${thread.board}/${thread.id}']!.thread;
	}

	@override
	Future<Post> getPost(String board, int id) async {
		throw Exception('Not implemented');
	}

	Future<List<Thread>> _getArchive(String board) async {
		final response = await client.get(Uri.https(baseUrl, '/$board/archive').toString(), options: Options(
			validateStatus: (x) => true
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
		return document.querySelector('#arc-list tbody')!.querySelectorAll('tr').map((tr) {
			final id = int.parse(tr.children.first.text);
			final excerptNode = tr.children[1];
			String? subject;
			if (excerptNode.children.isNotEmpty && excerptNode.children.first.localName == 'b') {
				subject = excerptNode.children.first.text;
				excerptNode.children.first.remove();
			}
			final text = excerptNode.innerHtml;
			return Thread(
				replyCount: 0,
				imageCount: 0,
				id: id,
				board: board,
				title: subject,
				isSticky: false,
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
						attachments: []
					)
				]
			);
		}).toList();
	}

	@override
	Future<List<Thread>> getCatalog(String board, {CatalogVariant? variant}) async {
		if (variant == CatalogVariant.chan4NativeArchive) {
			return _getArchive(board);
		}
		final response = await client.get(Uri.https(apiUrl, '/$board/catalog.json').toString(), options: Options(
			validateStatus: (x) => true
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
				final String? title = threadData['sub'];
				final int threadId = threadData['no'];
				final Post threadAsPost = _makePost(board, threadId, threadData);
				final List<Post> lastReplies = ((threadData['last_replies'] ?? []) as List<dynamic>).map((postData) => _makePost(board, threadId, postData)).toList();
				final a = _makeAttachment(board, threadId, threadData);
				Thread thread = Thread(
					board: board,
					id: threadId,
					replyCount: threadData['replies'],
					imageCount: threadData['images'],
					attachments: a == null ? [] : [a],
					posts_: [threadAsPost, ...lastReplies],
					title: (title == null) ? null : unescape.convert(title),
					isSticky: threadData['sticky'] == 1,
					time: DateTime.fromMillisecondsSinceEpoch(threadData['time'] * 1000),
					flag: _makeFlag(threadData, board),
					currentPage: page['page']
				);
				threads.add(thread);
			}
		}
		return threads;
	}
	@override
	Future<List<ImageboardBoard>> getBoards() async {
		final response = await client.get(Uri.https(apiUrl, '/boards.json').toString());
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
	Future<CaptchaRequest> getCaptchaRequest(String board, [int? threadId]) async {
		if (_passEnabled.putIfAbsent(Persistence.currentCookies, () => false)) {
			return NoCaptchaRequest();
		}
		return Chan4CustomCaptchaRequest(
			challengeUrl: Uri.https(_sysUrl(board), '/captcha', {
				'framed': '1',
				'board': board,
				if (threadId != null) 'thread_id': threadId.toString()
			})
		);
	}

	
	Future<PostReceipt> _post({
		required String board,
		int? threadId,
		String name = '',
		String? subject,
		String options = '',
		required String text,
		required CaptchaSolution captchaSolution,
		File? file,
		bool? spoiler,
		String? overrideFilename,
		ImageboardBoardFlag? flag
	}) async {
		final password = makeRandomBase64String(66);
		final response = await client.post(
			Uri.https(_sysUrl(board), '/$board/post').toString(),
			data: FormData.fromMap({
				if (threadId != null) 'resto': threadId.toString(),
				if (subject != null) 'sub': subject,
				'com': text,
				'mode': 'regist',
				'pwd': password,
				'name': name,
				'email': options,
				if (captchaSolution is RecaptchaSolution) 'g-recaptcha-response': captchaSolution.response
				else if (captchaSolution is Chan4CustomCaptchaSolution) ...{
					't-challenge': captchaSolution.challenge,
					't-response': captchaSolution.response
				},
				if (file != null) 'upfile': await MultipartFile.fromFile(file.path, filename: overrideFilename),
				if (spoiler == true) 'spoiler': 'on',
				if (flag != null) 'flag': flag.code
			}),
			options: Options(
				responseType: ResponseType.plain,
				headers: {
					'referer': getWebUrl(board, threadId)
				},
				extra: {
					if (captchaSolution.cloudflare) 'cloudflare': true
				}
			)
		);
		final document = parse(response.data);
		final metaTag = document.querySelector('meta[http-equiv="refresh"]');
		if (metaTag != null) {
			if (!response.cloudflare) {
				if (threadId == null) {
					_lastActionTime[ImageboardAction.postThread]![board] = DateTime.now();
				}
				else {
					_lastActionTime[ImageboardAction.postReply]![board] = DateTime.now();
					if (file != null) {
						_lastActionTime[ImageboardAction.postReplyWithImage]![board] = DateTime.now();
					}
				}
			}
			return PostReceipt(
				id: int.parse(metaTag.attributes['content']!.split(RegExp(r'\/|(#p)')).last),
				password: password
			);
		}
		else {
			final errSpan = document.querySelector('#errmsg');
			if (errSpan != null) {
				if (errSpan.text.toLowerCase().contains('ban') || errSpan.text.toLowerCase().contains('warn')) {
					throw BannedException(errSpan.text);
				}
				throw PostFailedException(errSpan.text);
			}
			else {
				print(response.data);
				throw PostFailedException('Unknown error');
			}
		}
	}

	Uri get _bannedUrl => Uri.https('www.4chan.org', '/banned');

	@override
	CaptchaRequest? getBannedCaptchaRequest(bool cloudflare) => RecaptchaRequest(
		key: captchaKey,
		sourceUrl: _bannedUrl.toString(),
		cloudflare: cloudflare
	);

	@override
	Future<String> getBannedReason(CaptchaSolution captchaSolution) async {
		final response = await client.postUri(_bannedUrl, data: {
			if (captchaSolution is RecaptchaSolution) 'g-recaptcha-response': captchaSolution.response
		}, options: Options(
			contentType: Headers.formUrlEncodedContentType,
			extra: {
				if (captchaSolution.cloudflare) 'cloudflare': true
			}
		));
		final document = parse(response.data);
		return document.querySelector('.boxcontent')?.text ?? 'Unknown: The banned page doesn\'t match expectations';
	}

	@override
	Future<PostReceipt> createThread({
		required String board,
		String name = '',
		String options = '',
		String subject = '',
		required String text,
		required CaptchaSolution captchaSolution,
		File? file,
		bool? spoiler,
		String? overrideFilename,
		ImageboardBoardFlag? flag
	}) => _post(
		board: board,
		name: name,
		options: options,
		subject: subject,
		text: text,
		captchaSolution: captchaSolution,
		file: file,
		spoiler: spoiler,
		overrideFilename: overrideFilename,
		flag: flag
	);

	@override
	Future<PostReceipt> postReply({
		required ThreadIdentifier thread,
		String name = '',
		String options = '',
		required String text,
		required CaptchaSolution captchaSolution,
		File? file,
		bool? spoiler,
		String? overrideFilename,
		ImageboardBoardFlag? flag
	}) => _post(
		board: thread.board,
		threadId: thread.id,
		name: name,
		options: options,
		text: text,
		captchaSolution: captchaSolution,
		file: file,
		spoiler: spoiler,
		overrideFilename: overrideFilename,
		flag: flag
	);

	@override
	DateTime? getActionAllowedTime(String board, ImageboardAction action) {
		final lastActionTime = _lastActionTime[action]![board];
		final b = persistence.getBoard(board);
		int cooldownSeconds = 0;
		switch (action) {
			case ImageboardAction.postReply:
				cooldownSeconds = b.replyCooldown ?? 0;
				break;
			case ImageboardAction.postReplyWithImage:
				cooldownSeconds = b.imageCooldown ?? 0;
				break;
			case ImageboardAction.postThread:
				cooldownSeconds = b.threadCooldown ?? 0;
				break;
		}
		if (_passEnabled.putIfAbsent(Persistence.cellularCookies, () => false)) {
			cooldownSeconds ~/= 2;
		}
		return lastActionTime?.add(Duration(seconds: cooldownSeconds));
	}

	@override
	Future<void> deletePost(String board, PostReceipt receipt) async {
		final response = await client.post(
			Uri.https(_sysUrl(board), '/$board/imgboard.php').toString(),
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
	String getWebUrl(String board, [int? threadId, int? postId]) {
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
	Uri getSpoilerImageUrl(Attachment attachment, {ThreadIdentifier? thread}) {
		final customSpoilerId = (thread == null) ? null : _threadCache['${thread.board}/${thread.id}']?.thread.customSpoilerId;
		if (customSpoilerId != null) {
			return Uri.https(staticUrl, '/image/spoiler-${attachment.board}$customSpoilerId.png');
		}
		else {
			return Uri.https(staticUrl, '/image/spoiler.png');
		}
	}

	@override
	Uri getPostReportUrl(String board, int id) {
		return Uri.https(_sysUrl(board), '/$board/imgboard.php', {
			'mode': 'report',
			'no': id.toString()
		});
	}

	Site4Chan({
		required this.baseUrl,
		required this.staticUrl,
		required String sysUrl,
		required this.apiUrl,
		required this.imageUrl,
		required this.name,
		required this.captchaKey,
		List<ImageboardSiteArchive> archives = const []
	}) : sysRedUrl = sysUrl, sysBlueUrl = sysUrl.replaceAll('chan.', 'channel.'), super(archives);

  @override
  List<ImageboardSiteLoginField> getLoginFields() {
    return const [
			ImageboardSiteLoginField(
				displayName: 'Token',
				formKey: 'id'
			),
			ImageboardSiteLoginField(
				displayName: 'PIN',
				formKey: 'pin',
				inputType: TextInputType.number
			)
		];
  }

  @override
  Future<void> clearLoginCookies(bool fromBothWifiAndCellular) async {
		if (!fromBothWifiAndCellular && _passEnabled[Persistence.currentCookies] == false) {
			// No need to clear
			return;
		}
		final jars = fromBothWifiAndCellular ? [
			Persistence.wifiCookies,
			Persistence.cellularCookies
		] : [
			Persistence.currentCookies
		];
		for (final jar in jars) {
			for (final sysUrl in [sysRedUrl, sysBlueUrl]) {
				final toSave = (await jar.loadForRequest(Uri.https(sysUrl, '/'))).where((cookie) {
					return cookie.name == 'cf_clearance';
				}).toList();
				await jar.delete(Uri.https(sysUrl, '/'), true);
				await jar.delete(Uri.https(sysUrl, '/'), true);
				await jar.saveFromResponse(Uri.https(sysUrl, '/'), toSave);
			}
			_passEnabled[jar] = false;
		}
  }

  @override
  Future<void> login(Map<ImageboardSiteLoginField, String> fields) async {
		for (final sysUrl in [sysRedUrl, sysBlueUrl]) {
			final response = await client.post(
				Uri.https(sysUrl, '/auth').toString(),
				data: FormData.fromMap({
					for (final field in fields.entries) field.key.formKey: field.value
				})
			);
			final document = parse(response.data);
			final message = document.querySelector('h2')?.text;
			if (message == null) {
				_passEnabled[Persistence.currentCookies] = false;
				await clearLoginCookies(false);
				throw const ImageboardSiteLoginException('Unexpected response, contact developer');
			}
			if (!message.contains('Success!')) {
				_passEnabled[Persistence.currentCookies] = false;
				await clearLoginCookies(false);
				throw ImageboardSiteLoginException(message);
			}
		}
		_passEnabled[Persistence.currentCookies] = true;
  }

  @override
  String? getLoginSystemName() {
    return '4chan Pass';
  }

	@override
	Uri get passIconUrl => Uri.https(staticUrl, '/image/minileaf.gif');

	@override
	String get siteType => '4chan';
	@override
	String get siteData => apiUrl;

	BoardThreadOrPostIdentifier? _decodeUrl(String base, String url) {
		final pattern = RegExp(r'https?:\/\/' + base.replaceAll('.', r'\.') + r'\/([^\/]+)\/(thread\/(\d+)(#p(\d+))?)?');
		final match = pattern.firstMatch(url);
		if (match != null) {
			return BoardThreadOrPostIdentifier(match.group(1)!, int.tryParse(match.group(3) ?? ''), int.tryParse(match.group(5) ?? ''));
		}
		return null;
	}
	
	@override
	BoardThreadOrPostIdentifier? decodeUrl(String url) {
		if (baseUrl.contains('chan')) {
			return _decodeUrl(baseUrl, url) ?? _decodeUrl(baseUrl.replaceFirst('chan', 'channel'), url);
		}
		return _decodeUrl(baseUrl, url);
	}
	
	final Map<String, AsyncMemoizer<List<ImageboardBoardFlag>>> _boardFlags = {};
	@override
	Future<List<ImageboardBoardFlag>> getBoardFlags(String board) {
		return _boardFlags.putIfAbsent(board, () => AsyncMemoizer<List<ImageboardBoardFlag>>()).runOnce(() async {
			final response = await client.get(Uri.https(baseUrl, '/$board/').toString());
			final doc = parse(response.data);
			return doc.querySelector('select[name="flag"]')?.querySelectorAll('option').map((e) => ImageboardBoardFlag(
				code: e.attributes['value'] ?? '0',
				name: e.text,
				image: Uri.https(staticUrl, '/image/flags/$board/${e.attributes['value']?.toLowerCase()}.gif')
			)).toList() ?? [];
		});
	}

	@override
	bool operator ==(Object other) => (other is Site4Chan) && (other.name == name) && (other.imageUrl == imageUrl) && (other.captchaKey == captchaKey) && (other.apiUrl == apiUrl) && (other.sysRedUrl == sysRedUrl) && (other.baseUrl == baseUrl) && (other.staticUrl == staticUrl) && listEquals(other.archives, archives);

	@override
	int get hashCode => Object.hash(name, imageUrl, captchaKey, apiUrl, sysRedUrl, baseUrl, staticUrl, archives);
	
	@override
	Uri get iconUrl => Uri.https(baseUrl, '/favicon.ico');

	@override
	String get defaultUsername => 'Anonymous';
	
	@override
	List<ImageboardSnippet> getBoardSnippets(String board) {
		if (board == 'g') {
			return const [
				ImageboardSnippet(
					icon: CupertinoIcons.chevron_left_slash_chevron_right,
					name: 'Code',
					start: '[code]',
					end: '[/code]',
					previewBuilder: PostCodeSpan.new
				)
			];
		}
		else if (board == 'sci') {
			return const [
				ImageboardSnippet(
					icon: CupertinoIcons.function,
					name: 'Math',
					start: '[math]',
					end: '[/math]',
					previewBuilder: PostTeXSpan.new
				)
			];
		}
		else if (persistence.getBoard(board).spoilers == true) {
			return const [
				ImageboardSnippet(
					icon: CupertinoIcons.eye_slash,
					name: 'Spoiler',
					start: '[spoiler]',
					end: '[/spoiler]'
				)
			];
		}
		return [];
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
}
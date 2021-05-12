import 'dart:io';
import 'dart:math';

import 'package:chan/models/board.dart';
import 'package:chan/models/flag.dart';
import 'package:chan/models/search.dart';
import 'package:chan/services/persistence.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;
import 'package:html_unescape/html_unescape_small.dart';
import 'package:http/io_client.dart';
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

const _CATALOG_CACHE_LIFETIME = const Duration(seconds: 10);

class _CatalogCacheEntry {
	final int page;
	final DateTime lastModified;
	final int replyCount;

	_CatalogCacheEntry({
		required this.page,
		required this.lastModified,
		required this.replyCount
	});
}

class _CatalogCache {
	final DateTime lastUpdated;
	final Map<int, _CatalogCacheEntry> entries;

	_CatalogCache({
		required this.lastUpdated,
		required this.entries
	});
}

class Site4Chan implements ImageboardSite {
	final String name;
	final String baseUrl;
	final String staticUrl;
	final String sysUrl;
	final String apiUrl;
	final String imageUrl;
	final String captchaKey;
	final http.Client client;
	final List<ImageboardSiteArchive> archives;
	List<ImageboardBoard>? _boards;
	final unescape = HtmlUnescape();
	final Map<String, _ThreadCacheEntry> _threadCache = Map();
	final Map<String, _CatalogCache> _catalogCaches = Map();

	static List<PostSpan> parsePlaintext(String text) {
		return linkify(text, linkifiers: [UrlLinkifier()]).map((elem) {
			if (elem is UrlElement) {
				return PostLinkSpan(elem.url);
			}
			else {
				return PostTextSpan(elem.text);
			}
		}).toList();
	}

	static PostSpan makeSpan(String board, int threadId, String data) {
		final doc = parse(data.replaceAll('<wbr>', ''));
		final List<PostSpan> elements = [];
		int spoilerSpanId = 0;
		for (final node in doc.body!.nodes) {
			if (node is dom.Element) {
				if (node.localName == 'br') {
					elements.add(PostTextSpan('\n'));
				}
				else {
					if (node.localName == 'a' && node.classes.contains('quotelink')) {
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
							elements.add(PostBoardLink(parts[parts.length - 2]));
						}
					}
					else if (node.localName == 'span') {
						if (node.attributes['class']?.contains('deadlink') ?? false) {
							final parts = node.innerHtml.replaceAll('&gt;', '').split('/');
							elements.add(PostQuoteLinkSpan(
								board: (parts.length > 2) ? parts[1] : board,
								postId: int.parse(parts.last),
								dead: true
							));
						}
						else if (node.attributes['class']?.contains('quote') ?? false) {
							elements.add(PostQuoteSpan(makeSpan(board, threadId, node.innerHtml)));
						}
						else {
							elements.add(PostTextSpan(node.text));
						}
					}
					else if (node.localName == 's') {
						elements.add(PostSpoilerSpan(makeSpan(board, threadId, node.innerHtml), spoilerSpanId++));
					}
					else {
						elements.addAll(parsePlaintext(node.text));
					}
				}
			}
			else {
				elements.addAll(parsePlaintext(node.text ?? ''));
			}
		}
		return PostNodeSpan(elements);
	}

	ImageboardFlag? _makeFlag(dynamic data) {
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
	}

	Post _makePost(String board, int threadId, dynamic data) {
		return Post(
			board: board,
			text: data['com'] ?? '',
			name: data['name'] ?? '',
			time: DateTime.fromMillisecondsSinceEpoch(data['time'] * 1000),
			id: data['no'],
			threadId: threadId,
			attachment: _makeAttachment(board, data),
			spanFormat: PostSpanFormat.Chan4,
			flag: _makeFlag(data),
			posterId: data['id']
		);
	}
	Attachment? _makeAttachment(String board, dynamic data) {
		if (data['tim'] != null) {
			final int id = data['tim'];
			final String ext = data['ext'];
			return Attachment(
				id: id,
				type: data['ext'] == '.webm' ? AttachmentType.WEBM : AttachmentType.Image,
				filename: unescape.convert(data['filename'] ?? '') + (data['ext'] ?? ''),
				ext: ext,
				board: board,
				url: Uri.https(imageUrl, '/$board/$id$ext'),
				thumbnailUrl: Uri.https(imageUrl, '/$board/${id}s.jpg'),
				md5: data['md5'],
				spoiler: data['spoiler'] == 1,
				width: data['w'],
				height: data['h']
			);
		}
	}

	Future<int?> _getThreadPage(ThreadIdentifier thread) async {
		final now = DateTime.now();
		if (_catalogCaches[thread.board] == null || now.difference(_catalogCaches[thread.board]!.lastUpdated).compareTo(_CATALOG_CACHE_LIFETIME) > 0) {
			final response = await client.get(Uri.https(apiUrl, '/${thread.board}/catalog.json'));
			if (response.statusCode != 200) {
				if (response.statusCode == 404) {
					return Future.error(BoardNotFoundException(thread.board));
				}
				else {
					return Future.error(HTTPStatusException(response.statusCode));
				}
			}
			final entries = Map<int, _CatalogCacheEntry>();
			final data = json.decode(response.body);
			for (final page in data) {
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

	Future<Thread> getThread(ThreadIdentifier thread) async {
		Map<String, String>? headers;
		if (_threadCache['${thread.board}/${thread.id}'] != null) {
			headers = {
				'If-Modified-Since': _threadCache['${thread.board}/${thread.id}']!.lastModified
			};
		}
		final response = await client.get(Uri.https(apiUrl,'/${thread.board}/thread/${thread.id}.json'), headers: headers);
		if (response.statusCode == 200) {
			final data = json.decode(response.body);
			final String? title = data['posts']?[0]?['sub'];
			final output = Thread(
				board: thread.board,
				isDeleted: false,
				replyCount: data['posts'][0]['replies'],
				imageCount: data['posts'][0]['images'],
				isArchived: (data['posts'][0]['archived'] ?? 0) == 1,
				posts: (data['posts'] ?? []).map<Post>((postData) {
					return _makePost(thread.board, thread.id, postData);
				}).toList(),
				id: data['posts'][0]['no'],
				attachment: _makeAttachment(thread.board, data['posts'][0]),
				title: (title == null) ? null : unescape.convert(title),
				isSticky: data['posts'][0]['sticky'] == 1,
				time: DateTime.fromMillisecondsSinceEpoch(data['posts'][0]['time'] * 1000),
				flag: _makeFlag(data['posts'][0]),
				currentPage: await _getThreadPage(thread),
				uniqueIPCount: data['posts'][0]['unique_ips'],
				customSpoilerId: data['posts'][0]['custom_spoiler']
			);
			_threadCache['${thread.board}/${thread.id}'] = _ThreadCacheEntry(
				thread: output,
				lastModified: response.headers['last-modified']!
			);
		}
		else if (!(response.statusCode == 304 && headers != null)) {
			if (response.statusCode == 404) {
				return Future.error(ThreadNotFoundException(thread));
			}
			return Future.error(HTTPStatusException(response.statusCode));
		}
		_threadCache['${thread.board}/${thread.id}']!.thread.currentPage = await _getThreadPage(thread);
		return _threadCache['${thread.board}/${thread.id}']!.thread;
	}
	Future<Thread> getThreadFromArchive(ThreadIdentifier thread) async {
		final errorMessages = Map<String, String>();
		for (final archive in archives) {
			try {
				return await archive.getThread(thread);
			}
			catch(e, st) {
				if (!(e is BoardNotFoundException)) {
					print('Error from ${archive.name}');
					print(e);
					print(st);
					errorMessages[archive.name] = e.toString();
				}
			}
		}
		if (errorMessages.isNotEmpty) {
			throw ImageboardArchiveException(errorMessages);
		}
		else {
			throw BoardNotFoundException(thread.board);
		}
	}

	Future<Post> getPost(String board, int id) async {
		throw Exception('Not implemented');
	}
	Future<Post> getPostFromArchive(String board, int id) async {
		final errorMessages = Map<String, String>();
		for (final archive in archives) {
			try {
				return await archive.getPost(board, id);
			}
			catch(e) {
				if (!(e is BoardNotFoundException)) {
					errorMessages[archive.name] = e.toString();
				}
			}
		}
		if (errorMessages.isNotEmpty) {
			throw ImageboardArchiveException(errorMessages);
		}
		else {
			throw BoardNotFoundException(board);
		}
	}

	Future<List<Thread>> getCatalog(String board) async {
		final response = await client.get(Uri.https(apiUrl, '/$board/catalog.json'));
		if (response.statusCode != 200) {
			if (response.statusCode == 404) {
				return Future.error(BoardNotFoundException(board));
			}
			else {
				return Future.error(HTTPStatusException(response.statusCode));
			}
		}
		final data = json.decode(response.body);
		final List<Thread> threads = [];
		for (final page in data) {
			for (final threadData in page['threads']) {
				final String? title = threadData['sub'];
				final int threadId = threadData['no'];
				final Post threadAsPost = _makePost(board, threadId, threadData);
				Thread thread = Thread(
					board: board,
					id: threadId,
					replyCount: threadData['replies'],
					imageCount: threadData['images'],
					isArchived: false,
					isDeleted: false,
					attachment: _makeAttachment(board, threadData),
					posts: [threadAsPost],
					title: (title == null) ? null : unescape.convert(title),
					isSticky: threadData['sticky'] == 1,
					time: DateTime.fromMillisecondsSinceEpoch(threadData['time'] * 1000),
					flag: _makeFlag(threadData),
					currentPage: page['page']
				);
				threads.add(thread);
			}
		}
		return threads;
	}
	Future<List<ImageboardBoard>> _getBoards() async {
		final response = await client.get(Uri.https(apiUrl, '/boards.json'));
		final data = json.decode(response.body);
		return (data['boards'] as List<dynamic>).map((board) {
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
				pageCount: board['pages']
			);
		}).toList();
	}
	Future<List<ImageboardBoard>> getBoards() async {
		if (_boards == null) {
			_boards = await _getBoards();
		}
		return _boards!;
	}

	CaptchaRequest getCaptchaRequest() {
		return CaptchaRequest(key: captchaKey, sourceUrl: 'https://' + baseUrl);
	}

	Future<PostReceipt> postReply({
		required ThreadIdentifier thread,
		String name = '',
		String options = '',
		required String text,
		required String captchaKey,
		File? file
	}) async {
		final random = Random();
		final password = List.generate(64, (i) => random.nextInt(16).toRadixString(16)).join();
		final request = http.MultipartRequest('POST', Uri.https(sysUrl, '/${thread.board}/post'));
		request.fields.addAll({
			'resto': thread.id.toString(),
			'com': text,
			'mode': 'regist',
			'pwd': password,
			'g-recaptcha-response': captchaKey
		});
		final response = await client.send(request);
		final body = await response.stream.bytesToString();
		final document = parse(body);
		final metaTag = document.querySelector('meta[http-equiv="refresh"]');
		if (metaTag != null) {
			return PostReceipt(
				id: int.parse(metaTag.attributes['content']!.split('#p').last),
				password: password
			);
		}
		else {
			final errSpan = document.querySelector('#errmsg');
			if (errSpan != null) {
				throw PostFailedException(errSpan.text);
			}
			else {
				print(body);
				throw PostFailedException('Unknown error');
			}
		}
	}

	Future<void> deletePost(String board, PostReceipt receipt) async {
		final request = http.MultipartRequest('POST', Uri.https(sysUrl, '/$board/imgboard.php'));
		request.fields.addAll({
			receipt.id.toString(): 'delete',
			'mode': 'usrdel',
			'pwd': receipt.password
		});
		final response = await client.send(request);
		if (response.statusCode != 200) {
			throw HTTPStatusException(response.statusCode);
		}
	}

	Future<ImageboardArchiveSearchResult> search(ImageboardArchiveSearchQuery query, {required int page}) async {
		for (final archive in archives) {
			try {
				return await archive.search(query, page: page);
			}
			catch(e, st) {
				if (!(e is BoardNotFoundException)) {
					print(e);
					print(st);
				}
			}
		}
		throw Exception('Search failed - exhausted all archives');
	}

	String getWebUrl(ThreadIdentifier thread, [int? postId]) {
		return 'https://$baseUrl/${thread.board}/thread/${thread.id}' + (postId != null ? '#p$postId' : '');
	}

	Uri getSpoilerImageUrl(Attachment attachment, {ThreadIdentifier? thread}) {
		final customSpoilerId = (thread == null) ? null : _threadCache['${thread.board}/${thread.id}']?.thread.customSpoilerId;
		if (customSpoilerId != null) {
			return Uri.https(staticUrl, '/image/spoiler-${attachment.board}$customSpoilerId.png');
		}
		else {
			return Uri.https(staticUrl, '/image/spoiler.png');
		}
	}

	Site4Chan({
		required this.baseUrl,
		required this.staticUrl,
		required this.sysUrl,
		required this.apiUrl,
		required this.imageUrl,
		required this.name,
		http.Client? client,
		required this.captchaKey,
		this.archives = const []
	}) : this.client = client ?? IOClient();
}
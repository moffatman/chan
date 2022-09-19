import 'dart:convert';

import 'package:chan/models/attachment.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/flag.dart';
import 'package:chan/models/post.dart';
import 'package:chan/services/http_429_backoff.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/models/search.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/sites/4chan.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;
import 'package:html_unescape/html_unescape_small.dart';

class FoolFuukaException implements Exception {
	String error;
	FoolFuukaException(this.error);
	@override
	String toString() => 'FoolFuuka Error: $error';
}

class FoolFuukaArchive extends ImageboardSiteArchive {
	List<ImageboardBoard>? boards;
	final unescape = HtmlUnescape();
	final String baseUrl;
	final String staticUrl;
	@override
	final String name;
	ImageboardFlag? _makeFlag(dynamic data) {
		if (data['poster_country'] != null && data['poster_country'].isNotEmpty) {
			return ImageboardFlag(
				name: data['poster_country_name'],
				imageUrl: Uri.https(staticUrl, '/image/country/${data['poster_country'].toLowerCase()}.gif').toString(),
				imageWidth: 16,
				imageHeight: 11
			);
		}
		else if (data['troll_country_name'] != null && data['troll_country_name'].isNotEmpty) {
			return ImageboardFlag(
				name: data['troll_country_name'],
				imageUrl: Uri.https(staticUrl, '/image/country/troll/${data['troll_country_code'].toLowerCase()}.gif').toString(),
				imageWidth: 16,
				imageHeight: 11
			);
		}
		return null;
	}
	static PostNodeSpan makeSpan(String board, int threadId, Map<String, int> linkedPostThreadIds, String data) {
		final doc = parse(data.replaceAll('<wbr>', '').replaceAll('\n', ''));
		final List<PostSpan> elements = [];
		int spoilerSpanId = 0;
		processQuotelink(dom.Element quoteLink) {
			final parts = quoteLink.attributes['href']!.split('/');
			final linkedBoard = parts[3];
			if (parts.length > 4) {
				final linkType = parts[4];
				final linkedId = int.tryParse(parts[5]);
				if (linkedId == null) {
					elements.add(PostCatalogSearchSpan(
						board: linkedBoard,
						query: parts[5]
					));
				}
				else if (linkType == 'post') {
					int linkedPostThreadId = linkedPostThreadIds['$linkedBoard/$linkedId'] ?? -1;
					if (linkedId == threadId) {
						// Easy fix so that uncached linkedPostThreadIds will correctly have (OP) in almost all cases
						linkedPostThreadId = threadId;
					}
					elements.add(PostQuoteLinkSpan(
						board: linkedBoard,
						threadId: linkedPostThreadId,
						postId: linkedId,
						dead: false
					));
				}
				else if (linkType == 'thread') {
					final linkedPostId = int.parse(parts[6].substring(1));
					elements.add(PostQuoteLinkSpan(
						board: linkedBoard,
						threadId: linkedId,
						postId: linkedPostId,
						dead: false
					));
				}
			}
			else {
				elements.add(PostBoardLink(linkedBoard));
			}
		}
		for (final node in doc.body!.nodes) {
			if (node is dom.Element) {
				if (node.localName == 'br') {
					elements.add(PostLineBreakSpan());
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
				else if (node.localName == 'span') {
					if (node.classes.contains('greentext')) {
						final quoteLink = node.querySelector('a.backlink');
						if (quoteLink != null) {
							processQuotelink(quoteLink);
						}
						else {
							elements.add(PostQuoteSpan(makeSpan(board, threadId, linkedPostThreadIds, node.innerHtml)));
						}
					}
					else if (node.classes.contains('spoiler')) {
						elements.add(PostSpoilerSpan(makeSpan(board, threadId, linkedPostThreadIds, node.innerHtml), spoilerSpanId++));
					}
					else if (node.classes.contains('fortune')) {
						final css = {
							for (final pair in (node.attributes['style']?.split(';') ?? [])) pair.split(':').first.trim(): pair.split(':').last.trim()
						};
						if (css['color'] != null) {
							elements.add(PostColorSpan(makeSpan(board, threadId, linkedPostThreadIds, node.innerHtml), colorToHex(css['color'])));
						}
						else {
							elements.add(makeSpan(board, threadId, linkedPostThreadIds, node.innerHtml));
						}
					}
					else {
						elements.addAll(Site4Chan.parsePlaintext(node.text));
					}
				}
				else if (node.localName == 'a' && node.classes.contains('backlink')) {
					processQuotelink(node);
				}
				else if (node.localName == 'strong') {
					elements.add(PostBoldSpan(makeSpan(board, threadId, linkedPostThreadIds, node.innerHtml)));
				}
				else {
					elements.addAll(Site4Chan.parsePlaintext(node.text));
				}
			}
			else {
				elements.addAll(Site4Chan.parsePlaintext(node.text ?? ''));
			}
		}
		return PostNodeSpan(elements);
	}
	Attachment? _makeAttachment(dynamic data) {
		if (data['media'] != null) {
			final List<String> serverFilenameParts =  data['media']['media_orig'].split('.');
			Uri url = Uri.parse(data['media']['media_link'] ?? data['media']['remote_media_link']);
			Uri thumbnailUrl = Uri.parse(data['media']['thumb_link']);
			if (url.host.isEmpty) {
				url = Uri.https(baseUrl, url.toString());
			}
			if (thumbnailUrl.host.isEmpty) {
				thumbnailUrl = Uri.https(baseUrl, thumbnailUrl.toString());
			}
			return Attachment(
				board: data['board']['shortname'],
				id: serverFilenameParts.first,
				filename: data['media']['media_filename'],
				ext: '.${serverFilenameParts.last}',
				type: serverFilenameParts.last == 'webm' ? AttachmentType.webm : AttachmentType.image,
				url: url,
				thumbnailUrl: thumbnailUrl,
				md5: data['media']['safe_media_hash'],
				spoiler: data['media']['spoiler'] == '1',
				width: int.parse(data['media']['media_w']),
				height: int.parse(data['media']['media_h']),
				threadId: int.tryParse(data['thread_num']),
				sizeInBytes: int.tryParse(data['media']['media_size'])
			);
		}
		return null;
	}
	Future<Post> _makePost(dynamic data, {bool resolveIds = true}) async {
		final String board = data['board']['shortname'];
		final int threadId = int.parse(data['thread_num']);
		final int id = int.parse(data['num']);
		_precachePostThreadId(board, id, threadId);
		final postLinkMatcher = RegExp('https?://[^ ]+/([^/]+)/post/([0-9]+)/');
		final Map<String, int> linkedPostThreadIds = {};
		if (resolveIds) {
			for (final match in postLinkMatcher.allMatches(data['comment_processed'] ?? '')) {
				final board = match.group(1)!;
				final postId = int.parse(match.group(2)!);
				final threadId = await _getPostThreadId(board, postId);
				if (threadId != null) {
					linkedPostThreadIds['$board/$postId'] = threadId;
				}
			}
		}
		int? passSinceYear;
		if (data['exif'] != null) {
			try {
				final exifData = jsonDecode(data['exif']);
				passSinceYear = int.tryParse(exifData['since4pass']);
			}
			catch (e) {
				// Malformed EXIF JSON
			}
		}
		final a = _makeAttachment(data);
		return Post(
			board: board,
			text: data['comment_processed'] ?? '',
			name: data['name'] ?? '',
			trip: data['trip'],
			time: DateTime.fromMillisecondsSinceEpoch(data['timestamp'] * 1000),
			id: id,
			threadId: threadId,
			attachments: a == null ? [] : [a],
			spanFormat: PostSpanFormat.foolFuuka,
			flag: _makeFlag(data),
			posterId: data['poster_hash'],
			foolfuukaLinkedPostThreadIds: linkedPostThreadIds,
			passSinceYear: passSinceYear
		);
	}
	Future<dynamic> _getPostJson(String board, int id) async {
		if (!(await getBoards()).any((b) => b.name == board)) {
			throw BoardNotFoundException(board);
		}
		final response = await client.get(
			Uri.https(baseUrl, '/_/api/chan/post').toString(),
			queryParameters: {
				'board': board,
				'num': id.toString()
			}
		);
		if (response.statusCode != 200) {
			if (response.statusCode == 404) {
				throw PostNotFoundException(board, id);
			}
			throw HTTPStatusException(response.statusCode!);
		}
		if (response.data['error'] != null) {
			if (response.data['error'] == 'Post not found.') {
				throw PostNotFoundException(board, id);
			}
			throw FoolFuukaException(response.data['error']);
		}
		return response.data;
	}
	final _postThreadIdCache = <String, Map<int, int?>>{};
	Future<int?> __getPostThreadId(String board, int postId) async {
		try {
			return int.parse((await _getPostJson(board, postId))['thread_num']);
		}
		on PostNotFoundException {
			return null;
		}
	}
	Future<int?> _getPostThreadId(String board, int postId) async {
		_postThreadIdCache[board] ??= {};
		if (!_postThreadIdCache[board]!.containsKey(postId)) {
			_postThreadIdCache[board]?[postId] = await __getPostThreadId(board, postId);
		}
		return _postThreadIdCache[board]?[postId];
	}
	void _precachePostThreadId(String board, int postId, int threadId) async {
		_postThreadIdCache.putIfAbsent(board, () => {}).putIfAbsent(postId, () => threadId);
	}
	@override
	Future<Post> getPost(String board, int id) async {		
		return _makePost(await _getPostJson(board, id));
	}
	Future<Thread> getThreadContainingPost(String board, int id) async {
		throw Exception('Unimplemented');
	}
	Future<Thread> _makeThread(ThreadIdentifier thread, dynamic data) async {
		final op = data[thread.id.toString()]['op'];
		var replies = data[thread.id.toString()]['posts'] ?? [];
		if (replies is Map) {
			replies = replies.entries.where((e) => int.tryParse(e.key) != null).map((e) => e.value);
		}
		final posts = (await Future.wait([op, ...replies].map(_makePost))).toList();
		final String? title = op['title'];
		final a = _makeAttachment(op);
		return Thread(
			board: thread.board,
			isDeleted: false,
			replyCount: posts.length - 1,
			imageCount: posts.skip(1).expand((post) => post.attachments).length,
			isArchived: true,
			posts_: posts,
			id: thread.id,
			attachments: a == null ? [] : [a],
			title: (title == null) ? null : unescape.convert(title),
			isSticky: op['sticky'] == 1,
			time: posts.first.time,
			flag: _makeFlag(op),
			uniqueIPCount: int.tryParse(op['unique_ips'] ?? '')
		);
	}
	@override
	Future<Thread> getThread(ThreadIdentifier thread) async {
		if (!(await getBoards()).any((b) => b.name == thread.board)) {
			throw BoardNotFoundException(thread.board);
		}
		final response = await client.get(
			Uri.https(baseUrl, '/_/api/chan/thread').toString(),
			queryParameters: {
				'board': thread.board,
				'num': thread.id.toString()
			},
			options: Options(
				validateStatus: (x) => true
			)
		);
		if (response.statusCode != 200) {
			if (response.statusCode == 404) {
				return Future.error(ThreadNotFoundException(thread));
			}
			return Future.error(HTTPStatusException(response.statusCode!));
		}
		final data = response.data;
		if (data['error'] != null) {
			throw Exception(data['error']);
		}
		return _makeThread(thread, data);
	}
	@override
	Future<List<Thread>> getCatalog(String board) async {
		final response = await client.get(Uri.https(baseUrl, '/_/api/chan/index').toString(), queryParameters: {
			'board': board,
			'page': '1'
		});
		return Future.wait((response.data as Map<dynamic, dynamic>).keys.where((threadIdStr) {
			return response.data[threadIdStr]['op'] != null;
		}).map((threadIdStr) => _makeThread(ThreadIdentifier(
			board,
			int.parse(threadIdStr)
		), response.data)).toList());
	}
	Future<List<ImageboardBoard>> _getBoards() async {
		final response = await client.get(Uri.https(baseUrl, '/_/api/chan/archives').toString(), options: Options(
			validateStatus: (x) => true
		));
		if (response.statusCode != 200) {
			throw HTTPStatusException(response.statusCode!);
		}
		final Iterable<dynamic> boardData = response.data['archives'].values;
		return boardData.map((archive) {
			return ImageboardBoard(
				name: archive['shortname'],
				title: archive['name'],
				isWorksafe: !archive['is_nsfw'],
				webmAudioAllowed: false
			);
		}).toList();
	}
	@override
	Future<List<ImageboardBoard>> getBoards() async {
		boards ??= await _getBoards();
		return boards!;
	}

	Future<ImageboardArchiveSearchResult> _makeResult(dynamic data) async {
		if (data['op'] == '1') {
			return ImageboardArchiveSearchResult(
				thread: await _makeThread(ThreadIdentifier(
					data['board']['shortname'],
					int.parse(data['num'])
				), {
					data['num']: {
						'op': data
					}
				})
			);
		}
		else {
			return ImageboardArchiveSearchResult(
				post: await _makePost(data, resolveIds: false)
			);
		}
	}

	@override
	Future<ImageboardArchiveSearchResultPage> search(ImageboardArchiveSearchQuery query, {required int page}) async {
		final knownBoards = await getBoards();
		final unknownBoards = query.boards.where((b) => !knownBoards.any((kb) => kb.name == b));
		if (unknownBoards.isNotEmpty) {
			throw BoardNotFoundException(unknownBoards.first);
		}
		final response = await client.get(
			Uri.https(baseUrl, '/_/api/chan/search').toString(),
			queryParameters: {
				'text': query.query,
				'page': page.toString(),
				if (query.boards.isNotEmpty) 'boards': query.boards.join('.'),
				if (query.mediaFilter != MediaFilter.none) 'filter': query.mediaFilter == MediaFilter.onlyWithMedia ? 'text' : 'image',
				if (query.postTypeFilter != PostTypeFilter.none) 'type': query.postTypeFilter == PostTypeFilter.onlyOPs ? 'op' : 'posts',
				if (query.startDate != null) 'start': '${query.startDate!.year}-${query.startDate!.month}-${query.startDate!.day}',
				if (query.endDate != null) 'end': '${query.endDate!.year}-${query.endDate!.month}-${query.endDate!.day}',
				if (query.md5 != null) 'image': query.md5,
				if (query.deletionStatusFilter == PostDeletionStatusFilter.onlyDeleted) 'deleted': 'deleted'
				else if (query.deletionStatusFilter == PostDeletionStatusFilter.onlyNonDeleted) 'deleted': 'not-deleted'
			},
			options: Options(
				validateStatus: (x) => true
		));
		if (response.statusCode != 200) {
			throw HTTPStatusException(response.statusCode!);
		}
		final data = response.data;
		if (data['error'] != null) {
			throw FoolFuukaException(data['error']);
		}
		return ImageboardArchiveSearchResultPage(
			posts: (await Future.wait((data['0']['posts'] as Iterable<dynamic>).map(_makeResult))).toList(),
			page: page,
			maxPage: (data['meta']['total_found'] / 25).ceil(),
			archive: this
		);
	}

	@override
	String getWebUrl(String board, [int? threadId, int? postId]) {
		String webUrl = 'https://$baseUrl/$board/';
		if (threadId != null) {
			webUrl += 'thread/$threadId';
			if (postId != null) {
				webUrl += '#$postId';
			}
		 }
		 return webUrl;
	}

	@override
	BoardThreadOrPostIdentifier? decodeUrl(String url) {
		final pattern = RegExp(r'https?:\/\/' + baseUrl + r'\/([^\/]+)\/thread\/(\d+)(#p(\d+))?');
		final match = pattern.firstMatch(url);
		if (match != null) {
			return BoardThreadOrPostIdentifier(match.group(1)!, int.parse(match.group(2)!), int.tryParse(match.group(4) ?? ''));
		}
		return null;
	}

	FoolFuukaArchive({
		required this.baseUrl,
		required this.staticUrl,
		required this.name,
		this.boards
	}) : super() {
		client.interceptors.add(HTTP429BackoffInterceptor(
			client: client
		));
	}

	@override
	bool operator == (Object other) => (other is FoolFuukaArchive) && (other.name == name) && (other.baseUrl == baseUrl) && (other.staticUrl == staticUrl);

	@override
	int get hashCode => Object.hash(name, baseUrl, staticUrl);
}
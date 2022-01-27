import 'package:chan/models/attachment.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/flag.dart';
import 'package:chan/models/post.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/models/search.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/sites/4chan.dart';
import 'package:chan/sites/imageboard_site.dart';
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
	static PostSpan makeSpan(String board, int threadId, Map<String, int> linkedPostThreadIds, String data) {
		final doc = parse(data.replaceAll('<wbr>', ''));
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
					final linkedPostThreadId = linkedPostThreadIds['$linkedBoard/$linkedId'] ?? -1;
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
				if (node.localName == 'span') {
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
					else {
						elements.addAll(Site4Chan.parsePlaintext(node.text));
					}
				}
				else if (node.localName == 'a' && node.classes.contains('backlink')) {
					processQuotelink(node);
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
			return Attachment(
				board: data['board']['shortname'],
				id: int.parse(serverFilenameParts.first),
				filename: data['media']['media_filename'],
				ext: '.' + serverFilenameParts.last,
				type: serverFilenameParts.last == 'webm' ? AttachmentType.webm : AttachmentType.image,
				url: Uri.parse(data['media']['media_link'] ?? data['media']['remote_media_link']),
				thumbnailUrl: Uri.parse(data['media']['thumb_link']),
				md5: data['media']['safe_media_hash'],
				spoiler: data['media']['spoiler'] == '1',
				width: int.parse(data['media']['media_w']),
				height: int.parse(data['media']['media_h']),
				threadId: int.tryParse(data['thread_num'])
			);
		}
		return null;
	}
	Future<Post> _makePost(dynamic data) async {
		final String board = data['board']['shortname'];
		final int threadId = int.parse(data['thread_num']);
		final postLinkMatcher = RegExp('https?://[^ ]+/([^/]+)/post/([0-9]+)/');
		final Map<String, int> linkedPostThreadIds = {};
		for (final match in postLinkMatcher.allMatches(data['comment_processed'] ?? '')) {
			final board = match.group(1)!;
			final postId = int.parse(match.group(2)!);
			linkedPostThreadIds['$board/$postId'] = await _getPostThreadId(board, postId);
		}
		return Post(
			board: board,
			text: data['comment_processed'] ?? '',
			name: data['name'] ?? '',
			trip: data['trip'],
			time: DateTime.fromMillisecondsSinceEpoch(data['timestamp'] * 1000),
			id: int.parse(data['num']),
			threadId: threadId,
			attachment: _makeAttachment(data),
			spanFormat: PostSpanFormat.foolFuuka,
			flag: _makeFlag(data),
			posterId: data['id'],
			foolfuukaLinkedPostThreadIds: linkedPostThreadIds
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
				return Future.error(PostNotFoundException(board, id));
			}
			return Future.error(HTTPStatusException(response.statusCode!));
		}
		return response.data;
	}
	Future<int> _getPostThreadId(String board, int postId) async {
		return int.parse((await _getPostJson(board, postId))['thread_num']);
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
		if (replies is! Iterable) {
			replies = replies.values;
		}
		final posts = (await Future.wait([op, ...replies].map(_makePost))).toList();
		final String? title = op['title'];
		return Thread(
			board: thread.board,
			isDeleted: false,
			replyCount: posts.length - 1,
			imageCount: posts.skip(1).where((post) => post.attachment != null).length,
			isArchived: true,
			posts: posts,
			id: thread.id,
			attachment: _makeAttachment(op),
			title: (title == null) ? null : unescape.convert(title),
			isSticky: op['sticky'] == 1,
			time: posts.first.time,
			flag: _makeFlag(op),
			uniqueIPCount: int.tryParse(op['unique_ips'] ?? '')
		);
	}
	Future<Thread> _getThread(ThreadIdentifier thread, int attempt) async {
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
			if (response.statusCode == 429) {
				if (attempt < 3) {
					final seconds = int.parse(response.headers.value('retry-after')!);
					print('Waiting $seconds seconds due to server-side rate-limiting');
					await Future.delayed(Duration(seconds: seconds));
					return _getThread(thread, attempt + 1);
				}
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
	Future<Thread> getThread(ThreadIdentifier thread) async {
		return _getThread(thread, 0);
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
			board: board,
			id: int.parse(threadIdStr)
		), response.data)).toList());
	}
	Future<List<ImageboardBoard>> _getBoards() async {
		final response = await client.get(Uri.https(baseUrl, '/_/api/chan/archives').toString());
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

	@override
	Future<ImageboardArchiveSearchResult> search(ImageboardArchiveSearchQuery query, {required int page}) async {
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
				if (query.md5 != null) 'image': query.md5
		});
		if (response.statusCode != 200) {
			throw HTTPStatusException(response.statusCode!);
		}
		final data = response.data;
		if (data['error'] != null) {
			throw FoolFuukaException(data['error']);
		}
		return ImageboardArchiveSearchResult(
			posts: (await Future.wait((data['0']['posts'] as Iterable<dynamic>).map(_makePost))).toList(),
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

	FoolFuukaArchive({
		required this.baseUrl,
		required this.staticUrl,
		required this.name,
		this.boards
	});
}
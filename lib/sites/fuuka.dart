import 'package:chan/models/attachment.dart';
import 'package:chan/models/board.dart';
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

class FuukaException implements Exception {
	String error;
	FuukaException(this.error);
	@override
	String toString() => 'Fuuka Error: $error';
}

final _threadLinkMatcher = RegExp(r'\/([a-zA-Z]+)\/thread\/S?(\d+)(#p(\d+))?$');
final _postLinkMatcher = RegExp(r'\/([a-zA-Z]+)\/post\/S?(\d+)$');
final _crossBoardLinkMatcher = RegExp(r'^>>>\/([A-Za-z]+)\/(\d+)$');

class FuukaArchive extends ImageboardSiteArchive {
	List<ImageboardBoard>? boards;
	final unescape = HtmlUnescape();
	final String baseUrl;
	@override
	final String name;
	static PostNodeSpan makeSpan(String board, int threadId, Map<String, int> linkedPostThreadIds, String data) {
		final doc = parse(data);
		final List<PostSpan> elements = [];
		for (final node in doc.body!.nodes) {
			if (node is dom.Element) {
				if (node.localName == 'br') {
					elements.add(PostLineBreakSpan());
				}
				else if (node.localName == 'span') {
					if (node.classes.contains('unkfunc')) {
						final match = _crossBoardLinkMatcher.firstMatch(node.innerHtml);
						if (match != null) {
							elements.add(PostQuoteLinkSpan(board: match.group(1)!, postId: int.parse(match.group(2)!), dead: true));
						}
						else {
							elements.add(PostQuoteSpan(makeSpan(board, threadId, linkedPostThreadIds, node.innerHtml)));
						}
					}
					else {
						elements.addAll(Site4Chan.parsePlaintext(node.text));
					}
				}
				else if (node.localName == 'a') {
					final match = _postLinkMatcher.firstMatch(node.attributes['href']!);
					if (match != null) {
						final board = match.group(1)!;
						final postId = int.parse(match.group(2)!);
						elements.add(PostQuoteLinkSpan(
							board: board,
							postId: postId,
							threadId: linkedPostThreadIds['$board/$postId'],
							dead: false
						));
					}
					else {
						final match = RegExp(r'^#p(\d+)$').firstMatch(node.attributes['href']!);
						if (match != null) {
							elements.add(PostQuoteLinkSpan(
								board: board,
								postId: int.parse(match.group(1)!),
								threadId: threadId,
								dead: false
							));
						}
						else {
							elements.addAll(Site4Chan.parsePlaintext(node.text));
						}
					}
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
	Attachment? _makeAttachment(dom.Element? element, int threadId) {
		if (element != null) {
			final String url = element.attributes['href']!;
			final urlMatch = RegExp(r'\/data\/([A-Za-z]+)\/img\/\d+\/\d+\/(\d+)(\..+)$').firstMatch(url)!;
			final ext = urlMatch.group(3)!;
			RegExpMatch? fileDetailsMatch;
			for (final span in element.parent!.querySelectorAll('span')) {
				fileDetailsMatch = RegExp(r'[^ ]+ [^ ]+ [^ ]+ (\d+)x(\d+), (.+)').firstMatch(span.text);
				if (fileDetailsMatch != null) {
					break;
				}
			}
			if (fileDetailsMatch == null) {
				throw FuukaException('Could not find atttachment details');
			}
			return Attachment(
				board: urlMatch.group(1)!,
				id: int.parse(urlMatch.group(2)!),
				filename: fileDetailsMatch.group(3)!,
				ext: ext,
				type: ext == '.webm' ? AttachmentType.webm : AttachmentType.image,
				url: Uri.parse('https:$url'),
				thumbnailUrl: Uri.parse('https:${element.querySelector('.thumb')!.attributes['src']!}'),
				md5: element.parent!.querySelectorAll('a').firstWhere((x) => x.text == 'View same').attributes['href']!.split('/').last,
				spoiler: false,
				width: int.parse(fileDetailsMatch.group(1)!),
				height: int.parse(fileDetailsMatch.group(2)!),
				threadId: threadId
			);
		}
		return null;
	}
	Future<Post> _makePost(dom.Element element) async {
		final thisLinkMatches = _threadLinkMatcher.firstMatch(element.querySelector('.js')!.attributes['href']!)!;
		final board = thisLinkMatches.group(1)!;
		final threadId = int.parse(thisLinkMatches.group(2)!);
		final postId = int.tryParse(thisLinkMatches.group(4) ?? '');
		final textNode = element.querySelector('p')!;
		final Map<String, int> linkedPostThreadIds = {};
		for (final link in textNode.querySelectorAll('a')) {
			final linkMatches = _postLinkMatcher.firstMatch(link.attributes['href']!);
			if (linkMatches != null) {
				final response = await client.head(Uri.https(baseUrl, link.attributes['href']!).toString(), options: Options(
					validateStatus: (x) => true
				));
				linkedPostThreadIds['${linkMatches.group(1)!}/${linkMatches.group(2)!}'] = int.parse(_threadLinkMatcher.firstMatch(response.redirects.last.location.path)!.group(2)!);
			}
		}
		return Post(
			board: board,
			text: textNode.innerHtml,
			name: element.querySelector('span[itemprop="name"]')!.text,
			time: DateTime.fromMillisecondsSinceEpoch(int.parse(element.querySelector('.posttime')!.attributes['title']!)),
			id: postId ?? threadId,
			threadId: threadId,
			attachment: _makeAttachment(element.querySelector('.thumb')?.parent, threadId),
			spanFormat: PostSpanFormat.fuuka,
			foolfuukaLinkedPostThreadIds: linkedPostThreadIds
		);
	}
	@override
	Future<Post> getPost(String board, int id) async {		
		final response = await client.get(Uri.https(baseUrl, '/$board/post/$id').toString());
		final thread = await _makeThread(response.data, board, int.parse(_threadLinkMatcher.firstMatch(response.redirects.last.location.path)!.group(2)!));
		return thread.posts.firstWhere((t) => t.id == id);
	}
	Future<Thread> _makeThread(dom.Element document, String board, int id) async {
		final op = document.querySelector('#p$id');
		if (op == null) {
			throw FuukaException('OP was not archived');
		}
		final replies = document.querySelectorAll('.reply:not(.subreply)');
		final posts = (await Future.wait([op, ...replies].map(_makePost))).toList();
		final title = document.querySelector('.filetitle')?.text;
		return Thread(
			posts_: posts,
			id: id,
			time: posts[0].time,
			isSticky: false,
			title: title == 'post' ? null : title,
			board: board,
			attachment: posts[0].attachment,
			replyCount: posts.length - 1,
			imageCount: posts.skip(1).where((post) => post.attachment != null).length
		);
	}
	Future<Thread> getThreadContainingPost(String board, int id) async {
		throw Exception('Unimplemented');
	}
	@override
	Future<Thread> getThread(ThreadIdentifier thread) async {
		if (!(await getBoards()).any((b) => b.name == thread.board)) {
			throw BoardNotFoundException(thread.board);
		}
		final response = await client.get(
			Uri.https(baseUrl, '/${thread.board}/thread/${thread.id}').toString(),
			queryParameters: {
				'board': thread.board,
				'num': thread.id.toString()
			}
		);
		return _makeThread(parse(response.data).body!, thread.board, thread.id);
	}
	@override
	Future<List<Thread>> getCatalog(String board) async {
		final response = await client.get(Uri.https(baseUrl, '/$board/').toString(), options: Options(validateStatus: (x) => true));
		final document = parse(response.data);
		int? threadId;
		dom.Element e = dom.Element.tag('div');
		final List<Thread> threads = [];
		for (final child in document.querySelector('.content')!.children) {
			if (child.localName == 'hr') {
				threads.add(await _makeThread(e, board, threadId!));
				e = dom.Element.tag('div');
			}
			else {
				if (child.localName == 'div') {
					final match = RegExp(r'^p(\d+)$').firstMatch(child.id);
					if (match != null) {
						threadId = int.parse(match.group(1)!);
					}
				}
				e.append(child);
			}
		}
		return threads;
	}

	@override
	Future<List<ImageboardBoard>> getBoards() async {
		return boards!;
	}

	String _formatDateForSearch(DateTime d) {
		return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
	}

	@override
	Future<ImageboardArchiveSearchResultPage> search(ImageboardArchiveSearchQuery query, {required int page}) async {
		final knownBoards = await getBoards();
		final unknownBoards = query.boards.where((b) => !knownBoards.any((kb) => kb.name == b));
		if (unknownBoards.isNotEmpty) {
			throw BoardNotFoundException(unknownBoards.first);
		}
		final response = await client.get(
			Uri.https(baseUrl, '/${query.boards.first}/').toString(),
			queryParameters: {
				'task': 'search2',
				'ghost': 'yes',
				'search_text': query.query,
				if (query.postTypeFilter == PostTypeFilter.onlyOPs) 'search_op': 'op',
				if (query.startDate != null) 'search_datefrom': _formatDateForSearch(query.startDate!),
				if (query.endDate != null) 'search_dateto': _formatDateForSearch(query.endDate!),
				'offset': (page * 24).toString(),
				if (query.deletionStatusFilter == PostDeletionStatusFilter.onlyDeleted) 'search_del': 'yes'
				else if (query.deletionStatusFilter == PostDeletionStatusFilter.onlyNonDeleted) 'search_del': 'no'
		}, options: Options(
			responseType: ResponseType.plain
		));
		if (response.statusCode != 200) {
			throw HTTPStatusException(response.statusCode!);
		}
		final document = parse(response.data);
		return ImageboardArchiveSearchResultPage(
			posts: (await Future.wait(document.querySelectorAll('.reply:not(.subreply)').map(_makePost))).map((p) => ImageboardArchiveSearchResult(post: p)).toList(),
			page: page,
			maxPage: 100,
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

	FuukaArchive({
		required this.baseUrl,
		required this.name,
		this.boards
	});

	@override
	bool operator == (Object other) => (other is FuukaArchive) && (other.name == name) && (other.baseUrl == baseUrl);

	@override
	int get hashCode => Object.hash(name, baseUrl);
}
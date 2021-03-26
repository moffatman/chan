import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;
import 'package:html_unescape/html_unescape_small.dart';
import 'package:linkify/linkify.dart';

import 'imageboard_site.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/models/post_element.dart';

class Site4Chan implements ImageboardSite {
	final String name;
	final String apiUrl;
	final String imageUrl;
	final http.Client client;
	final Map<String, ImageboardSite> archives;
	List<ImageboardBoard>? _boards;
	final unescape = HtmlUnescape();

	List<PostSpan> _parsePlaintext(String text) {
		return linkify(text, linkifiers: [UrlLinkifier()]).map((elem) {
			if (elem is UrlElement) {
				return PostLinkSpan(elem.url);
			}
			else {
				return PostTextSpan(elem.text);
			}
		}).toList();
	}

	List<PostSpan> _makeSpans(String data) {
		final doc = parse(data.replaceAll('<wbr>', ''));
		final List<PostSpan> elements = [];
		int spoilerSpanId = 0;
		for (final node in doc.body!.nodes) {
			if (node is dom.Element) {
				if (node.localName == 'br') {
					elements.add(PostTextSpan('\n'));
				}
				else {
					if (node.localName == 'a') {
						if (node.attributes['href']!.startsWith('#p')) {
							elements.add(PostExpandingQuoteLinkSpan(int.parse(node.attributes['href']!.substring(2))));
						}
						else if (node.attributes['href']!.contains('#p')) {
							// href looks like "/tv/thread/123456#p123457"
							final parts = node.attributes['href']!.split('/');
							final threadIndex = parts.indexOf('thread');
							final ids = parts[threadIndex + 1].split('#p');
							elements.add(PostCrossThreadQuoteLinkSpan(parts[threadIndex - 1], int.parse(ids[0]), int.parse(ids[1])));
						}
						else {
							elements.add(PostTextSpan("LINK: " + node.attributes['href']!));
						}
					}
					else if (node.localName == 'span') {
						if (node.attributes['class']?.contains('deadlink') ?? false) {
							elements.add(PostDeadQuoteLinkSpan(int.parse(node.innerHtml.substring(8))));
						}
						else if (node.attributes['class']?.contains('quote') ?? false) {
							elements.add(PostQuoteSpan(PostNodeSpan(_makeSpans(node.innerHtml))));
						}
						else {
							elements.add(PostTextSpan(node.text));
						}
					}
					else if (node.localName == 's') {
						elements.add(PostSpoilerSpan(PostNodeSpan(_makeSpans(node.innerHtml)), spoilerSpanId++));
					}
					else {
						elements.addAll(_parsePlaintext(node.text));
					}
				}
			}
			else {
				elements.addAll(_parsePlaintext(node.text ?? ''));
			}
		}
		return elements;
	}

	Post _makePost(String board, dynamic data) {
		Post p = Post(
			board: board,
			text: data['com'] ?? '',
			name: data['name'] ?? '',
			time: DateTime.fromMillisecondsSinceEpoch(data['time'] * 1000),
			id: data['no'],
			attachment: (data['filename'] != null) ? _makeAttachment(board, data) : null,
			span: PostNodeSpan(_makeSpans(data['com'] ?? ''))
		);

		return p;
	}
	Attachment _makeAttachment(String board, dynamic data) {
		return Attachment(
			id: data['tim'],
			type: data['ext'] == '.webm' ? AttachmentType.WEBM : AttachmentType.Image,
			filename: (data['filename'] ?? '') + (data['ext'] ?? ''),
			ext: data['ext'],
			board: board
		);
	}
	Uri getAttachmentUrl(Attachment attachment) {
		if (attachment.providerId == null) {
			return Uri.parse('https://i.4cdn.org/${attachment.board}/${attachment.id}${attachment.ext}');
		}
		else {
			return archives[attachment.providerId]!.getAttachmentUrl(attachment);
		}
	}
	List<Uri> getArchiveAttachmentUrls(Attachment attachment) {
		return [];
	}
	Uri getAttachmentThumbnailUrl(Attachment attachment) {
		if (attachment.providerId == null) {
			return Uri.parse('https://i.4cdn.org/${attachment.board}/${attachment.id}s.jpg');
		}
		else {
			return archives[attachment.providerId]!.getAttachmentThumbnailUrl(attachment);
		}
	}
	Future<Thread> getThread(String board, int id) async {
		final response = await client.get(Uri.parse(apiUrl + '/' + board + '/thread/' + id.toString() + '.json'));
		if (response.statusCode != 200) {
			if (response.statusCode == 404) {
				return Future.error(ThreadNotFoundException(board, id));
			}
			return Future.error(HTTPStatusException(response.statusCode));
		}
		final data = json.decode(response.body);
		final String? title = data['posts']?[0]?['sub'];
		return Thread(
			board: board,
			isDeleted: false,
			replyCount: data['posts'][0]['replies'],
			imageCount: data['posts'][0]['images'],
			isArchived: (data['posts'][0]['archived'] ?? 0) == 1,
			posts: (data['posts'] ?? []).map<Post>((postData) {
				return _makePost(board, postData);
			}).toList(),
			id: data['posts'][0]['no'],
			attachment: _makeAttachment(board, data['posts'][0]),
			title: (title == null) ? null : unescape.convert(title),
			isSticky: data['posts'][0]['sticky'] == 1
		);
	}

	Future<Thread> getThreadContainingPost(String board, int id) async {
		throw Exception("Not implemented");
	}

	Future<List<Thread>> getCatalog(String board) async {
		final response = await client.get(Uri.parse(apiUrl + '/' + board + '/catalog.json'));
		final data = json.decode(response.body);
		final List<Thread> threads = [];
		for (final page in data) {
			for (final threadData in page['threads']) {
				final String? title = threadData['sub'];
				List<Post> lastReplies = [];
				lastReplies.insert(0, _makePost(board, threadData));
				Thread thread = Thread(
					board: board,
					id: threadData['no'],
					replyCount: threadData['replies'],
					imageCount: threadData['images'],
					isArchived: false,
					isDeleted: false,
					attachment: _makeAttachment(board, threadData),
					posts: lastReplies,
					title: (title == null) ? null : unescape.convert(title),
					isSticky: threadData['sticky'] == 1
				);
				threads.add(thread);
			}
		}
		return threads;
	}
	Future<List<ImageboardBoard>> _getBoards() async {
		final response = await client.get(Uri.parse(apiUrl + '/boards.json'));
		final data = json.decode(response.body);
		return (data['boards'] as List<dynamic>).map((board) {
			return ImageboardBoard(
				name: board['board'],
				title: board['title'],
				isWorksafe: board['ws_board'] == 1
			);
		}).toList();
	}
	Future<List<ImageboardBoard>> getBoards() async {
		if (_boards == null) {
			_boards = await _getBoards();
		}
		return _boards!;
	}

	Site4Chan({
		required this.apiUrl,
		required this.imageUrl,
		required this.name,
		required this.client,
		this.archives = const {}
	});
}
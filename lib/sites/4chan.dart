import 'dart:io';
import 'dart:math';

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
import 'package:chan/models/post_element.dart';

class Site4Chan implements ImageboardSite {
	final String name;
	final String baseUrl;
	final String sysUrl;
	final String apiUrl;
	final String imageUrl;
	final String captchaKey;
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
					if (node.localName == 'a' && node.classes.contains('quotelink')) {
						if (node.attributes['href']!.startsWith('#p')) {
							elements.add(PostExpandingQuoteLinkSpan(int.parse(node.attributes['href']!.substring(2))));
						}
						else if (node.attributes['href']!.contains('#p')) {
							// href looks like '/tv/thread/123456#p123457'
							final parts = node.attributes['href']!.split('/');
							final threadIndex = parts.indexOf('thread');
							final ids = parts[threadIndex + 1].split('#p');
							elements.add(PostCrossThreadQuoteLinkSpan(parts[threadIndex - 1], int.parse(ids[0]), int.parse(ids[1])));
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
							elements.add(PostDeadQuoteLinkSpan(int.parse(parts.last), board: (parts.length > 2) ? parts[1] : null));
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
			attachment: _makeAttachment(board, data),
			span: PostNodeSpan(_makeSpans(data['com'] ?? ''))
		);

		return p;
	}
	Attachment? _makeAttachment(String board, dynamic data) {
		if (data['tim'] != null) {
			return Attachment(
				id: data['tim'],
				type: data['ext'] == '.webm' ? AttachmentType.WEBM : AttachmentType.Image,
				filename: (data['filename'] ?? '') + (data['ext'] ?? ''),
				ext: data['ext'],
				board: board
			);
		}
	}
	Uri getAttachmentUrl(Attachment attachment) {
		if (attachment.providerId == null) {
			return Uri.https(imageUrl, '/${attachment.board}/${attachment.id}${attachment.ext}');
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
			return Uri.https(imageUrl, '/${attachment.board}/${attachment.id}s.jpg');
		}
		else {
			return archives[attachment.providerId]!.getAttachmentThumbnailUrl(attachment);
		}
	}
	Future<Thread> getThread(String board, int id) async {
		final response = await client.get(Uri.https(apiUrl,'/$board/thread/$id.json'));
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
		throw Exception('Not implemented');
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
				maxWebmDurationSeconds: board['max_webm_duration']
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
		required String board,
		required int threadId,
		String name = '',
		String options = '',
		required String text,
		required String captchaKey,
		File? file
	}) async {
		final random = Random();
		final password = List.generate(64, (i) => random.nextInt(16).toRadixString(16)).join();
		final request = http.MultipartRequest('POST', Uri.https(sysUrl, '/$board/post'));
		request.fields.addAll({
			'resto': threadId.toString(),
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
				password: password,
				id: int.parse(metaTag.attributes['content']!.split('#p').last)
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

	Site4Chan({
		required this.baseUrl,
		required this.sysUrl,
		required this.apiUrl,
		required this.imageUrl,
		required this.name,
		http.Client? client,
		required this.captchaKey,
		this.archives = const {}
	}) : this.client = client ?? IOClient();
}
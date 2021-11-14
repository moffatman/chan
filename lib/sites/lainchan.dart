import 'dart:io';
import 'dart:math';

import 'package:chan/models/attachment.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/models/search.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:dio/dio.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;
import 'package:linkify/linkify.dart';

import 'package:chan/models/board.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/sites/imageboard_site.dart';

class SiteLainchan extends ImageboardSite {
	final String baseUrl;
	final String name;
	List<ImageboardBoard>? _boards;

	final _unescape = HtmlUnescape();

	SiteLainchan({
		required this.baseUrl,
		required this.name
	});

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
		for (final node in doc.body!.nodes) {
			if (node is dom.Element) {
				if (node.localName == 'br') {
					elements.add(PostTextSpan('\n'));
				}
				else if (node.localName == 'a' && node.attributes['href'] != null) {
					final match = RegExp(r'^\/(\w+)\/res\/(\d+).html#(\d+)').firstMatch(node.attributes['href']!);
					if (match != null) {
						elements.add(PostQuoteLinkSpan(
							board: match.group(1)!,
							threadId: int.parse(match.group(2)!),
							postId: int.parse(match.group(3)!),
							dead: false
						));
					}
					else {
						elements.add(PostLinkSpan(node.attributes['href']!));
					}
				}
				else if (node.localName == 'span') {
					if (node.attributes['class']?.contains('quote') ?? false) {
						elements.add(PostQuoteSpan(makeSpan(board, threadId, node.innerHtml)));
					}
					else {
						elements.add(PostTextSpan(node.text));
					}
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

	Attachment? _makeAttachment(String board, int threadId, dynamic data) {
		if (data['tim'] != null) {
			final id = int.parse(data['tim']);
			final String ext = data['ext'];
			return Attachment(
				id: id,
				type: data['ext'] == '.webm' ? AttachmentType.WEBM : AttachmentType.Image,
				filename: _unescape.convert(data['filename'] ?? '') + (data['ext'] ?? ''),
				ext: ext,
				board: board,
				url: Uri.https(baseUrl, '/$board/src/$id$ext'),
				thumbnailUrl: Uri.https(baseUrl, '/$board/thumb/$id.png'),
				md5: data['md5'],
				spoiler: data['spoiler'] == 1,
				width: data['w'],
				height: data['h'],
				threadId: threadId
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
			attachment: _makeAttachment(board, threadId, data),
			attachmentDeleted: data['filedeleted'] == 1,
			spanFormat: PostSpanFormat.Lainchan,
			posterId: data['id']
		);
	}

	@override
	Future<Post> getPost(String board, int id) {
		throw Exception('Not implemented');
	}
	@override
	Future<Thread> getThread(ThreadIdentifier thread) async {
		final response = await client.get(Uri.https(baseUrl, '/${thread.board}/res/${thread.id}.json').toString());
		final firstPost = response.data['posts'][0];
		final List<Post> posts = (response.data['posts'] ?? []).map<Post>((postData) => _makePost(thread.board, thread.id, postData)).toList();
		return Thread(
			board: thread.board,
			id: thread.id,
			isSticky: firstPost['sticky'] == 1,
			title: firstPost['sub'],
			attachment: posts[0].attachment,
			time: DateTime.fromMillisecondsSinceEpoch(firstPost['time'] * 1000),
			replyCount: posts.length - 1,
			imageCount: posts.where((p) => p.attachment != null).length - 1,
			posts: posts
		);
	}
	@override
	Future<List<Thread>> getCatalog(String board) async {
		final response = await client.get(Uri.https(baseUrl, '/$board/catalog.json').toString(), options: Options(
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
				final threadAsPost = _makePost(board, threadData['no'], threadData);
				final thread = Thread(
					board: board,
					id: threadData['no'],
					title: threadData['sub'],
					posts: [threadAsPost],
					attachment: threadAsPost.attachment,
					replyCount: threadData['replies'],
					imageCount: threadData['images'],
					isSticky: threadData['sticky'] == 1,
					time: DateTime.fromMillisecondsSinceEpoch(threadData['time'] * 1000),
					currentPage: page['page']
				);
				threads.add(thread);
			}
		}
		return threads;
	}

	Future<List<ImageboardBoard>> _getBoards() async {
		final response = await client.get(Uri.https(baseUrl, '/boards.json').toString(), options: Options(
			responseType: ResponseType.json
		));
		return (response.data['boards'] as List<dynamic>).map((board) => ImageboardBoard(
			name: board['board'],
			title: board['title'],
			isWorksafe: board['ws_board'] == 1,
			webmAudioAllowed: board['webm_audio'] == 1
		)).toList();
	}
	@override
	Future<List<ImageboardBoard>> getBoards() async {
		if (_boards == null) {
			_boards = await _getBoards();
		}
		return _boards!;
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
		String? overrideFilename
	}) async {
		final now = DateTime.now();
		final random = Random();
		final password = List.generate(64, (i) => random.nextInt(16).toRadixString(16)).join();
		final response = await client.post(
			Uri.https(baseUrl, '/post.php').toString(),
			data: FormData.fromMap({
				if (threadId != null) 'thread': threadId.toString(),
				if (subject != null) 'subject': subject,
				'body': text,
				'password': password,
				if (file != null) 'file': await MultipartFile.fromFile(file.path, filename: overrideFilename)
			}),
			options: Options(
				responseType: ResponseType.plain
			)
		);
		if (response.isRedirect ?? false) {
			int? newPostId;
			while (newPostId == null) {
				await Future.delayed(const Duration(seconds: 2));
				if (threadId == null) {
					(await getCatalog(board)).reversed.forEach((thread) {
						if (thread.title == subject && thread.posts[0].text == text && (thread.time.compareTo(now) >= 0)) {
							newPostId = thread.id;
						}
					});
				}
				else {
					(await getThread(ThreadIdentifier(board: board, id: threadId))).posts.forEach((post) {
						if (post.text == text && (post.time.compareTo(now) >= 0)) {
							newPostId = post.id;
						}
					});
				}
			}
			return PostReceipt(
				id: newPostId!,
				password: password
			);
		}
		else {
			final document = parse(response.data);
			final errSpan = document.querySelector('h2');
			if (errSpan != null) {
				throw PostFailedException(errSpan.text);
			}
			else {
				print(response.data);
				throw PostFailedException('Unknown error');
			}
		}
	}

	Future<PostReceipt> createThread({
		required String board,
		String name = '',
		String options = '',
		String subject = '',
		required String text,
		required CaptchaSolution captchaSolution,
		File? file,
		String? overrideFilename
	}) => _post(
		board: board,
		name: name,
		options: options,
		subject: subject,
		text: text,
		captchaSolution: captchaSolution,
		file: file,
		overrideFilename: overrideFilename
	);

	Future<PostReceipt> postReply({
		required ThreadIdentifier thread,
		String name = '',
		String options = '',
		required String text,
		required CaptchaSolution captchaSolution,
		File? file,
		String? overrideFilename
	}) => _post(
		board: thread.board,
		threadId: thread.id,
		name: name,
		options: options,
		text: text,
		captchaSolution: captchaSolution,
		file: file,
		overrideFilename: overrideFilename
	);

	@override
	Future<void> deletePost(String board, PostReceipt receipt) async {
		final response = await client.post(
			Uri.https(baseUrl, '/post.php').toString(),
			data: FormData.fromMap({
				'board': board,
				'delete_$receipt.id': 'on',
				'delete': 'Delete',
				'password': receipt.password
			})
		);
		if (response.statusCode != 200) {
			throw HTTPStatusException(response.statusCode!);
		}
	}

	@override
	DateTime? getActionAllowedTime(String board, ImageboardAction action) {
		return DateTime.now();
	}

	@override
	CaptchaRequest getCaptchaRequest(String board, [int? threadId]) {
		return NoCaptchaRequest();
	}

	@override
	Future<Post> getPostFromArchive(String board, int id) {
		throw UnimplementedError();
	}

	@override
	Uri getPostReportUrl(String board, int id) {
		return Uri.https(baseUrl, '/report.php?post=delete_$id&board=$board');
	}

	@override
	Uri getSpoilerImageUrl(Attachment attachment, {ThreadIdentifier? thread}) {
		throw UnimplementedError();
	}

	@override
	Future<Thread> getThreadFromArchive(ThreadIdentifier thread) {
		throw UnimplementedError();
	}

	@override
	String getWebUrl(ThreadIdentifier thread, [int? postId]) {
		final threadUrl = Uri.https(baseUrl, '/${thread.board}/res/${thread.id}.html').toString();
		if (postId == null) {
			return threadUrl;
		}
		else {
			return threadUrl + '#q$postId';
		}
	}

	@override
	String get imageUrl => baseUrl;

	@override
	Future<ImageboardArchiveSearchResult> search(ImageboardArchiveSearchQuery query, {required int page}) {
		throw UnimplementedError();
	}
}
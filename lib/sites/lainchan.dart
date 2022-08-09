import 'dart:io';

import 'package:chan/models/attachment.dart';
import 'package:chan/models/flag.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/util.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;
import 'package:linkify/linkify.dart';

import 'package:chan/models/board.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/sites/imageboard_site.dart';

class SiteLainchan extends ImageboardSite {
	@override
	final String baseUrl;
	@override
	final String name;
	List<ImageboardBoard>? _boards;

	final _unescape = HtmlUnescape();

	bool _adminEnabled = false;

	SiteLainchan({
		required this.baseUrl,
		required this.name,
		List<ImageboardSiteArchive> archives = const []
	}) : super(archives);

	static List<PostSpan> parsePlaintext(String text) {
		return linkify(text, linkifiers: const [UrlLinkifier(), ChanceLinkifier()]).map((elem) {
			if (elem is UrlElement) {
				return PostLinkSpan(elem.url);
			}
			else {
				return PostTextSpan(elem.text);
			}
		}).toList();
	}

	static PostNodeSpan makeSpan(String board, int threadId, String data) {
		final doc = parse(data.replaceAll('<wbr>', ''));
		final List<PostSpan> elements = [];
		for (final node in doc.body!.nodes) {
			if (node is dom.Element) {
				if (node.localName == 'br') {
					elements.add(PostLineBreakSpan());
				}
				else if (node.localName == 'a' && node.attributes['href'] != null) {
					final match = RegExp(r'^\/([^\/]+)\/\/?res\/(\d+).html#(\d+)').firstMatch(node.attributes['href']!);
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
					if (node.classes.contains('quote')) {
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

	@protected
	Uri getAttachmentUrl(String board, String filename) => Uri.https(baseUrl, '/$board/src/$filename');

	@protected
	Uri getThumbnailUrl(String board, String filename) => Uri.https(baseUrl, '/$board/thumb/$filename');

	@protected
	String? get imageThumbnailExtension => '.png';

	Attachment? _makeAttachment(String board, int threadId, dynamic data) {
		if (data['tim'] != null) {
			final id = int.tryParse(data['tim']) ?? int.tryParse(data['tim'].split('-').first) ?? data['time'];
			final String ext = data['ext'];
			AttachmentType type = AttachmentType.image;
			if (ext == '.webm') {
				type = AttachmentType.webm;
			}
			else if (ext == '.mp4') {
				type = AttachmentType.mp4;
			}
			return Attachment(
				id: id,
				type: type,
				filename: _unescape.convert(data['filename'] ?? '') + (data['ext'] ?? ''),
				ext: ext,
				board: board,
				url: getAttachmentUrl(board, '${data['tim']}$ext'),
				thumbnailUrl: getThumbnailUrl(board, '${data['tim']}${type == AttachmentType.image ? (imageThumbnailExtension ?? ext) : '.jpg'}'),
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

	ImageboardFlag? _makeFlag(dynamic data) {
		if (data['country'] != null && data['country_name'] != null) {
			return ImageboardFlag(
				name: data['country_name'],
				imageUrl: Uri.https(baseUrl, '/static/flags/${data['country'].toLowerCase()}.png').toString(),
				imageWidth: 16,
				imageHeight: 11
			);
		}
		return null;
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
			spanFormat: PostSpanFormat.lainchan,
			posterId: data['id'],
			flag: _makeFlag(data),
			capcode: data['capcode']
		);
	}

	@override
	Future<Post> getPost(String board, int id) {
		throw Exception('Not implemented');
	}
	@override
	Future<Thread> getThread(ThreadIdentifier thread) async {
		final response = await client.get(Uri.https(baseUrl, '/${thread.board}/res/${thread.id}.json').toString(), options: Options(
			validateStatus: (x) => true
		));
		if (response.statusCode == 404) {
			throw ThreadNotFoundException(thread);
		}
		else if (response.statusCode != 200) {
			throw HTTPStatusException(response.statusCode ?? 0);
		}
		final firstPost = response.data['posts'][0];
		final List<Post> posts = (response.data['posts'] ?? []).map<Post>((postData) => _makePost(thread.board, thread.id, postData)).toList();
		if (posts.first.attachment != null) {
			await ensureCookiesMemoized(posts.first.attachment!.url);
			await ensureCookiesMemoized(posts.first.attachment!.thumbnailUrl);
		}
		return Thread(
			board: thread.board,
			id: thread.id,
			isSticky: firstPost['sticky'] == 1,
			title: firstPost['sub'],
			attachment: posts[0].attachment,
			time: DateTime.fromMillisecondsSinceEpoch(firstPost['time'] * 1000),
			replyCount: posts.length - 1,
			imageCount: posts.where((p) => p.attachment != null).length - 1,
			posts_: posts,
			flag: posts.first.flag
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
			for (final threadData in (page['threads'] ?? [])) {
				final threadAsPost = _makePost(board, threadData['no'], threadData);
				final thread = Thread(
					board: board,
					id: threadData['no'],
					title: threadData['sub'],
					posts_: [threadAsPost],
					attachment: threadAsPost.attachment,
					replyCount: threadData['replies'],
					imageCount: threadData['images'],
					isSticky: threadData['sticky'] == 1,
					time: DateTime.fromMillisecondsSinceEpoch(threadData['time'] * 1000),
					currentPage: page['page'],
					flag: _makeFlag(threadData)
				);
				threads.add(thread);
			}
		}
		return threads;
	}

	@protected
	Future<List<ImageboardBoard>> getBoardsOnce() async {
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
		_boards ??= await getBoardsOnce();
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
		bool? spoiler,
		String? overrideFilename,
		ImageboardBoardFlag? flag
	}) async {
		final now = DateTime.now().subtract(const Duration(seconds: 5));
		final password = List.generate(12, (i) => random.nextInt(16).toRadixString(16)).join();
		final referer = _getWebUrl(board, threadId: threadId, mod: _adminEnabled);
		final page = await client.get(referer, options: Options(validateStatus: (x) => true));
		final Map<String, dynamic> fields = {
			for (final field in parse(page.data).querySelector('form[name="post"]')!.querySelectorAll('input[type="text"], input[type="submit"], input[type="hidden"], textarea'))
				field.attributes['name']!: field.attributes['value'] ?? field.text
		};
		fields['body'] = text;
		fields['password'] = password;
		if (threadId != null) {
			fields['thread'] = threadId.toString();
		}
		if (subject != null) {
			fields['subject'] = subject;
		}
		if (file != null) {
			fields['attachment'] = await MultipartFile.fromFile(file.path, filename: overrideFilename);
		}
		if (spoiler == true) {
			fields['spoiler'] = 'on';
		}
		if (name.isNotEmpty) {
			fields['name'] = name;
		}
		if (options.isNotEmpty) {
			fields['email'] = options;
		}
		if (captchaSolution is SecurimageCaptchaSolution) {
			fields['captcha_cookie'] = captchaSolution.cookie;
			fields['captcha_text'] = captchaSolution.response;
		}
		final response = await client.post(
			Uri.https(baseUrl, '/post.php').toString(),
			data: FormData.fromMap(fields),
			options: Options(
				responseType: ResponseType.plain,
				validateStatus: (x) => true,
				headers: {
					'Referer': referer
				}
			)
		);
		if (response.statusCode == 500 || response.statusCode == 400) {
			throw PostFailedException(parse(response.data).querySelector('h2')?.text ?? 'Unknown error');
		}
		if (response.isRedirect ?? false) {
			return PostReceipt(
				id: int.parse(RegExp(r'\d+').allMatches(response.redirects.last.location.toString()).last.group(0)!),
				password: password
			);
		}
		else {
			// This doesn't work if user has quoted someone, but it shouldn't be needed
			int? newPostId;
			while (newPostId == null) {
				await Future.delayed(const Duration(seconds: 2));
				if (threadId == null) {
					for (final thread in (await getCatalog(board)).reversed) {
						if (thread.title == subject && thread.posts[0].text == text && (thread.time.compareTo(now) >= 0)) {
							newPostId = thread.id;
						}
					}
				}
				else {
					for (final post in (await getThread(ThreadIdentifier(board, threadId))).posts) {
						if (post.text == text && (post.time.compareTo(now) >= 0)) {
							newPostId = post.id;
						}
					}
				}
			}
			return PostReceipt(
				id: newPostId,
				password: password
			);
		}
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
	Future<void> deletePost(String board, PostReceipt receipt) async {
		final response = await client.post(
			Uri.https(baseUrl, '/post.php').toString(),
			data: FormData.fromMap({
				'board': board,
				'delete_${receipt.id}': 'on',
				'delete': 'Delete',
				'password': receipt.password
			}),
			options: Options(
				validateStatus: (x) => true
			)
		);
		if (response.statusCode != 200) {
			if (response.statusCode == 500) {
				throw DeletionFailedException(parse(response.data).querySelector('h2')?.text ?? 'Unknown error');
			}
			throw HTTPStatusException(response.statusCode!);
		}
	}

	@override
	DateTime? getActionAllowedTime(String board, ImageboardAction action) {
		return DateTime.now().subtract(const Duration(days: 1));
	}

	@override
	CaptchaRequest getCaptchaRequest(String board, [int? threadId]) {
		return NoCaptchaRequest();
	}

	@override
	Uri getPostReportUrl(String board, int id) {
		return Uri.https(baseUrl, '/report.php?post=delete_$id&board=$board');
	}

	@override
	Uri getSpoilerImageUrl(Attachment attachment, {ThreadIdentifier? thread}) {
		throw UnimplementedError();
	}

	String _getWebUrl(String board, {int? threadId, int? postId, bool mod = false}) {
		String threadUrl = 'https://$baseUrl/${mod ? 'mod.php?/' : ''}$board/';
		if (threadId != null) {
			threadUrl += 'res/$threadId.html';
			if (postId != null) {
				threadUrl += '#q$postId';
			}
		}
		return threadUrl;
	}

	@override
	String getWebUrl(String board, [int? threadId, int? postId]) {
		return _getWebUrl(board, threadId: threadId, postId: postId);
	}

	@override
	String get imageUrl => baseUrl;

	@override
	Uri get passIconUrl => Uri.https('callum.crabdance.com', '/minileaf.gif');

  @override
  List<ImageboardSiteLoginField> getLoginFields() {
    return const [
			ImageboardSiteLoginField(
				displayName: 'Username',
				formKey: 'username'
			),
			ImageboardSiteLoginField(
				displayName: 'Password',
				formKey: 'password'
			)
		];
  }

  @override
  Future<void> clearLoginCookies() async {
		await Persistence.cookies.delete(Uri.https(baseUrl, '/'), true);
		await Persistence.cookies.delete(Uri.https(baseUrl, '/mod.php'), true);
		_adminEnabled = false;
  }

  @override
  Future<void> login(Map<ImageboardSiteLoginField, String> fields) async {
    final response = await client.post(
			'https://$baseUrl/mod.php?/',
			data: {
				for (final field in fields.entries) field.key.formKey: field.value,
				'login': 'Continue'
			},
			options: Options(
				contentType: Headers.formUrlEncodedContentType,
				followRedirects: false,
				validateStatus: (x) => true
			),
		);
		final document = parse(response.data);
		if (document.querySelector('h2') != null) {
			await clearLoginCookies();
			throw ImageboardSiteLoginException(document.querySelector('h2')!.text);
		}
		_adminEnabled = true;
  }

  @override
  String? getLoginSystemName() {
    return 'Administrator';
  }
	
	@override
	List<ImageboardEmote> getEmotes() {
		return [];
	}

	@override
	String get siteType => 'lainchan';
	@override
	String get siteData => baseUrl;
	
	@override
	ThreadOrPostIdentifier? decodeUrl(String url) {
		final pattern = RegExp(r'https?:\/\/' + baseUrl.replaceAll('.', r'\.') + r'\/([^\/]+)\/res\/(\d+)\.html(#q(\d+))?');
		final match = pattern.firstMatch(url);
		if (match != null) {
			return ThreadOrPostIdentifier(match.group(1)!, int.parse(match.group(2)!), int.tryParse(match.group(4) ?? ''));
		}
		return null;
	}

	@override
	Future<List<ImageboardBoardFlag>> getBoardFlags(String board) async {
		return [];
	}

	@override
	bool operator ==(Object other) => (other is SiteLainchan) && (other.name == name) && (other.baseUrl == baseUrl);

	@override
	int get hashCode => Object.hash(name, baseUrl);
	
	@override
	Uri get iconUrl => Uri.https(baseUrl, '/favicon.ico');

	@override
	String get defaultUsername => 'Anonymous';

	@override
	List<ImageboardSnippet> getBoardSnippets(String board) => [];
}
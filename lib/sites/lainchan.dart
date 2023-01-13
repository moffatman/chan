import 'dart:io';

import 'package:chan/models/attachment.dart';
import 'package:chan/models/flag.dart';
import 'package:chan/services/linkifier.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/util.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' show parse, parseFragment;
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
	final int? maxUploadSizeBytes;

	final Map<PersistCookieJar, bool> _adminEnabled = {};

	SiteLainchan({
		required this.baseUrl,
		required this.name,
		this.maxUploadSizeBytes,
		List<ImageboardSiteArchive> archives = const []
	}) : super(archives);

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
		final body = parseFragment(data.replaceAll('<wbr>', ''));
		final List<PostSpan> elements = [];
		for (final node in body.nodes) {
			if (node is dom.Element) {
				if (node.localName == 'br') {
					elements.add(const PostLineBreakSpan());
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
					if (node.classes.contains('quote') || node.classes.contains('unkfunc')) {
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

	List<Attachment> _makeAttachments(String board, int threadId, dynamic postData) {
		final ret = <Attachment>[];
		Attachment makeAttachment(dynamic data) {
			final id = data['tim'];
			final String ext = data['ext'];
			AttachmentType type = AttachmentType.image;
			if (ext == '.webm') {
				type = AttachmentType.webm;
			}
			else if (ext == '.mp4') {
				type = AttachmentType.mp4;
			}
			else if (ext == '.mp3') {
				type = AttachmentType.mp3;
			}
			return Attachment(
				id: id,
				type: type,
				filename: unescape.convert(data['filename'] ?? '') + (data['ext'] ?? ''),
				ext: ext,
				board: board,
				url: getAttachmentUrl(board, '$id$ext'),
				thumbnailUrl: type == AttachmentType.mp3 ? Uri.https(baseUrl, '/static/mp3.png') : getThumbnailUrl(board, '$id${type == AttachmentType.image ? (imageThumbnailExtension ?? ext) : '.jpg'}'),
				md5: data['md5'],
				spoiler: data['spoiler'] == 1,
				width: data['w'],
				height: data['h'],
				threadId: threadId,
				sizeInBytes: data['fsize']
			);
		}
		if (postData['tim'] != null) {
			ret.add(makeAttachment(postData));
			if (postData['extra_files'] != null) {
				for (final extraFile in (postData['extra_files'] as List<dynamic>).cast<Map<String, dynamic>>()) {
					ret.add(makeAttachment(extraFile));
				}
			}
		}
		return ret;
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
			attachments: _makeAttachments(board, threadId, data),
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
	Future<Thread> getThread(ThreadIdentifier thread, {ThreadVariant? variant}) async {
		final response = await client.get(Uri.https(baseUrl, '/${thread.board}/res/${thread.id}.json').toString(), options: Options(
			validateStatus: (x) => true
		));
		if (response.statusCode == 404 || response.redirects.tryLast?.location.pathSegments.tryLast == '404.html') {
			throw ThreadNotFoundException(thread);
		}
		else if (response.statusCode != 200) {
			throw HTTPStatusException(response.statusCode ?? 0);
		}
		final firstPost = response.data['posts'][0];
		final List<Post> posts = (response.data['posts'] ?? []).map<Post>((postData) => _makePost(thread.board, thread.id, postData)).toList();
		for (final attachment in posts.first.attachments) {
			await ensureCookiesMemoized(attachment.url);
			await ensureCookiesMemoized(attachment.thumbnailUrl);
		}
		return Thread(
			board: thread.board,
			id: thread.id,
			isSticky: firstPost['sticky'] == 1,
			title: firstPost['sub'],
			attachments: posts[0].attachments,
			time: DateTime.fromMillisecondsSinceEpoch(firstPost['time'] * 1000),
			replyCount: posts.length - 1,
			imageCount: posts.skip(1).expand((p) => p.attachments).length,
			posts_: posts,
			flag: posts.first.flag
		);
	}
	@override
	Future<List<Thread>> getCatalogImpl(String board, {CatalogVariant? variant}) async {
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
					attachments: threadAsPost.attachments,
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

	@override
	Future<List<ImageboardBoard>> getBoards() async {
		final response = await client.get(Uri.https(baseUrl, '/boards.json').toString(), options: Options(
			responseType: ResponseType.json
		));
		return (response.data['boards'] as List<dynamic>).map((board) => ImageboardBoard(
			name: board['board'],
			title: board['title'],
			isWorksafe: board['ws_board'] == 1,
			webmAudioAllowed: board['webm_audio'] == 1,
			maxImageSizeBytes: maxUploadSizeBytes,
			maxWebmSizeBytes: maxUploadSizeBytes
		)).toList();
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
		final referer = _getWebUrl(board, threadId: threadId, mod: _adminEnabled.putIfAbsent(Persistence.currentCookies, () => false));
		final page = await client.get(referer, options: Options(validateStatus: (x) => true));
		final Map<String, dynamic> fields = {
			for (final field in parse(page.data).querySelector('form[name="post"]')?.querySelectorAll('input[type="text"], input[type="submit"], input[type="hidden"], textarea') ?? [])
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
		if ((response.statusCode ?? 0) >= 400) {
			throw PostFailedException(parse(response.data).querySelector('h2')?.text ?? 'HTTP Error ${response.statusCode}');
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
	Future<CaptchaRequest> getCaptchaRequest(String board, [int? threadId]) async {
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
  Future<void> clearLoginCookies(bool fromBothWifiAndCellular) async {
		final jars = fromBothWifiAndCellular ? [
			Persistence.wifiCookies,
			Persistence.cellularCookies
		] : [
			Persistence.currentCookies
		];
		for (final jar in jars) {
			await jar.delete(Uri.https(baseUrl, '/'), true);
			await jar.delete(Uri.https(baseUrl, '/mod.php'), true);
			_adminEnabled[jar] = false;
		}
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
			await clearLoginCookies(false);
			throw ImageboardSiteLoginException(document.querySelector('h2')!.text);
		}
		_adminEnabled[Persistence.currentCookies] = true;
  }

  @override
  String? getLoginSystemName() {
    return 'Administrator';
  }

	@override
	String get siteType => 'lainchan';
	@override
	String get siteData => baseUrl;

	static BoardThreadOrPostIdentifier? decodeGenericUrl(String baseUrl, String url) {
		final pattern = RegExp(r'https?:\/\/' + baseUrl.replaceAll('.', r'\.') + r'\/([^\/]+)\/((res\/(\d+)\.html(#q(\d+))?.*)|(index\.html))?$');
		final match = pattern.firstMatch(url);
		if (match != null) {
			return BoardThreadOrPostIdentifier(match.group(1)!, int.tryParse(match.group(4) ?? ''), int.tryParse(match.group(6) ?? ''));
		}
		return null;
	}
	
	@override
	Future<BoardThreadOrPostIdentifier?> decodeUrl(String url) async => decodeGenericUrl(baseUrl, url);

	@override
	bool operator ==(Object other) => (other is SiteLainchan) && (other.baseUrl == baseUrl) && (other.name == name) && (other.maxUploadSizeBytes == maxUploadSizeBytes) && listEquals(other.archives, archives);

	@override
	int get hashCode => Object.hash(baseUrl, name, maxUploadSizeBytes, archives);
	
	@override
	Uri get iconUrl => Uri.https(baseUrl, '/favicon.ico');

	@override
	String get defaultUsername => 'Anonymous';

	@override
	bool get supportsPushNotifications => true;
}
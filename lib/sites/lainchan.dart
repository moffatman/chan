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
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:html/parser.dart' show parse, parseFragment;
import 'package:html/dom.dart' as dom;
import 'package:linkify/linkify.dart';

import 'package:chan/models/board.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:string_similarity/string_similarity.dart';

class SiteLainchan extends ImageboardSite {
	@override
	final String baseUrl;
	@override
	final String name;
	final int? maxUploadSizeBytes;
	final String faviconPath;
	@override
	final String defaultUsername;

	@override
	late final SiteLainchanLoginSystem loginSystem = SiteLainchanLoginSystem(this);

	SiteLainchan({
		required this.baseUrl,
		required this.name,
		this.maxUploadSizeBytes,
		List<ImageboardSiteArchive> archives = const [],
		this.faviconPath = '/favicon.ico',
		this.defaultUsername = 'Anonymous'
	}) : super(archives);

	static List<PostSpan> parsePlaintext(String text) {
		return linkify(text, linkifiers: const [ChanceLinkifier(), LooseUrlLinkifier()]).map((elem) {
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
					final match = RegExp(r'^\/([^\/]+)\/\/?(?:(?:res)|(?:thread))\/(\d+).html#(\d+)').firstMatch(node.attributes['href']!);
					if (match != null) {
						elements.add(PostQuoteLinkSpan(
							board: match.group(1)!,
							threadId: int.parse(match.group(2)!),
							postId: int.parse(match.group(3)!)
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
		return PostNodeSpan(elements.toList(growable: false));
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
				url: getAttachmentUrl(board, '$id$ext').toString(),
				thumbnailUrl: (type == AttachmentType.mp3 ? Uri.https(baseUrl, '/static/mp3.png') : getThumbnailUrl(board, '$id${type == AttachmentType.image ? (imageThumbnailExtension ?? ext) : '.jpg'}')).toString(),
				md5: data['md5'],
				spoiler: data['spoiler'] == 1,
				width: data['w'],
				height: data['h'],
				threadId: threadId,
				sizeInBytes: data['fsize']
			);
		}
		if ((postData['tim'] as String?)?.isNotEmpty ?? false) {
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
			attachmentDeleted: data['filedeleted'] == 1 || data['ext'] == 'deleted',
			spanFormat: PostSpanFormat.lainchan,
			posterId: data['id'],
			flag: _makeFlag(data),
			capcode: data['capcode']
		);
	}

	@override
	Future<Post> getPost(String board, int id, {required bool interactive}) {
		throw Exception('Not implemented');
	}

	@protected
	String get res => 'res';

	@override
	Future<Thread> getThreadImpl(ThreadIdentifier thread, {ThreadVariant? variant, required bool interactive}) async {
		final response = await client.getUri(Uri.https(baseUrl, '/${thread.board}/$res/${thread.id}.json'), options: Options(
			validateStatus: (x) => true,
			extra: {
				kInteractive: interactive
			}
		));
		if (response.statusCode == 404 || (response.redirects.tryLast?.location.pathSegments.tryLast?.startsWith('404.') ?? false)) {
			throw ThreadNotFoundException(thread);
		}
		else if (response.statusCode != 200) {
			throw HTTPStatusException(response.statusCode ?? 0);
		}
		final firstPost = response.data['posts'][0];
		final List<Post> posts = (response.data['posts'] ?? []).map<Post>((postData) => _makePost(thread.board, thread.id, postData)).toList();
		return Thread(
			board: thread.board,
			id: thread.id,
			isSticky: firstPost['sticky'] == 1,
			title: (firstPost['sub'] as String?)?.unescapeHtml,
			attachmentDeleted: posts[0].attachmentDeleted,
			attachments: posts[0].attachments,
			time: DateTime.fromMillisecondsSinceEpoch(firstPost['time'] * 1000),
			replyCount: posts.length - 1,
			imageCount: posts.skip(1).expand((p) => p.attachments).length,
			posts_: posts
		);
	}
	@override
	Future<List<Thread>> getCatalogImpl(String board, {CatalogVariant? variant, required bool interactive}) async {
		final response = await client.getUri(Uri.https(baseUrl, '/$board/catalog.json'), options: Options(
			validateStatus: (x) => true,
			extra: {
				kInteractive: interactive
			}
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
				final int? currentPage = page['page'];
				final thread = Thread(
					board: board,
					id: threadData['no'],
					title: (threadData['sub'] as String?)?.unescapeHtml,
					posts_: [threadAsPost],
					attachmentDeleted: threadAsPost.attachmentDeleted,
					attachments: threadAsPost.attachments,
					replyCount: threadData['replies'],
					imageCount: threadData['images'],
					isSticky: threadData['sticky'] == 1,
					time: DateTime.fromMillisecondsSinceEpoch(threadData['time'] * 1000),
					currentPage: currentPage == null ? null : currentPage + 1
				);
				threads.add(thread);
			}
		}
		return threads;
	}

	@override
	Future<List<ImageboardBoard>> getBoards({required bool interactive}) async {
		final response = await client.getUri(Uri.https(baseUrl, '/boards.json'), options: Options(
			responseType: ResponseType.json,
			extra: {
				kInteractive: interactive
			}
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
		final referer = _getWebUrl(board, threadId: threadId, mod: loginSystem._adminEnabled.putIfAbsent(Persistence.currentCookies, () => false));
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
		else if (captchaSolution is SecucapCaptchaSolution) {
			fields['captcha'] = captchaSolution.response;
		}
		final response = await client.postUri(
			Uri.https(baseUrl, '/post.php'),
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
			final digitMatches = RegExp(r'\d+').allMatches(response.redirects.last.location.toString());
			if (digitMatches.isNotEmpty) {
				return PostReceipt(
					id: int.parse(digitMatches.last.group(0)!),
					password: password,
					name: name,
					options: options,
					time: DateTime.now()
				);
			}
		}
		final doc = parse(response.data);
		final ban = doc.querySelector('.ban');
		if (ban != null) {
			throw PostFailedException(ban.text);
		}
		// This doesn't work if user has quoted someone, but it shouldn't be needed
		int? newPostId;
		while (newPostId == null) {
			await Future.delayed(const Duration(seconds: 2));
			if (threadId == null) {
				for (final thread in (await getCatalog(board, interactive: true)).reversed) {
					if (thread.title == subject && (thread.posts[0].span.buildText().similarityTo(text) > 0.9) && (thread.time.compareTo(now) >= 0)) {
						newPostId = thread.id;
					}
				}
			}
			else {
				for (final post in (await getThread(ThreadIdentifier(board, threadId), interactive: true)).posts) {
					if ((post.span.buildText().similarityTo(text) > 0.9) && (post.time.compareTo(now) >= 0)) {
						newPostId = post.id;
					}
				}
			}
		}
		return PostReceipt(
			id: newPostId,
			password: password,
			name: name,
			options: options,
			time: DateTime.now()
		);
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
	Future<void> deletePost(String board, int threadId, PostReceipt receipt) async {
		final response = await client.postUri(
			Uri.https(baseUrl, '/post.php'),
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
	Future<CaptchaRequest> getCaptchaRequest(String board, [int? threadId]) async {
		return const NoCaptchaRequest();
	}

	@override
	Future<ImageboardReportMethod> getPostReportMethod(String board, int threadId, int postId) async {
		return WebReportMethod(Uri.https(baseUrl, '/report.php?post=delete_$postId&board=$board'));
	}

	@override
	Uri getSpoilerImageUrl(Attachment attachment, {ThreadIdentifier? thread}) {
		throw UnimplementedError();
	}

	String _getWebUrl(String board, {int? threadId, int? postId, bool mod = false}) {
		String threadUrl = 'https://$baseUrl/${mod ? 'mod.php?/' : ''}$board/';
		if (threadId != null) {
			threadUrl += '$res/$threadId.html';
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
	Iterable<ImageboardSnippet> getBoardSnippets(String board) => const [
		greentextSnippet
	];

	@override
	String get imageUrl => baseUrl;

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
	bool operator ==(Object other) => (other is SiteLainchan) && (other.baseUrl == baseUrl) && (other.name == name) && (other.maxUploadSizeBytes == maxUploadSizeBytes) && listEquals(other.archives, archives) && (other.faviconPath == faviconPath) && (other.defaultUsername == defaultUsername);

	@override
	int get hashCode => Object.hash(baseUrl, name, maxUploadSizeBytes, archives, faviconPath, defaultUsername);
	
	@override
	Uri get iconUrl {
		if (faviconPath.startsWith('/')) {
			return Uri.https(baseUrl, faviconPath);
		}
		return Uri.parse(faviconPath);
	}

	@override
	bool get supportsPushNotifications => true;
}

class SiteLainchanLoginSystem extends ImageboardSiteLoginSystem {
	@override
	final SiteLainchan parent;

	final Map<PersistCookieJar, bool> _adminEnabled = {};

	SiteLainchanLoginSystem(this.parent);

  @override
  List<ImageboardSiteLoginField> getLoginFields() {
    return const [
			ImageboardSiteLoginField(
				displayName: 'Username',
				formKey: 'username',
				autofillHints: [AutofillHints.username]
			),
			ImageboardSiteLoginField(
				displayName: 'Password',
				formKey: 'password',
				autofillHints: [AutofillHints.password]
			)
		];
  }

  @override
  Future<void> clearLoginCookies(String? board, bool fromBothWifiAndCellular) async {
		final jars = fromBothWifiAndCellular ? [
			Persistence.wifiCookies,
			Persistence.cellularCookies
		] : [
			Persistence.currentCookies
		];
		for (final jar in jars) {
			await jar.delete(Uri.https(parent.baseUrl, '/'), true);
			await jar.delete(Uri.https(parent.baseUrl, '/mod.php'), true);
			_adminEnabled[jar] = false;
		}
		await CookieManager.instance().deleteCookies(
			url: WebUri(parent.baseUrl)
		);
  }

  @override
  Future<void> login(String? board, Map<ImageboardSiteLoginField, String> fields) async {
    final response = await parent.client.postUri(
			Uri.https(parent.baseUrl, '/mod.php'),
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
			await clearLoginCookies(board, false);
			throw ImageboardSiteLoginException(document.querySelector('h2')!.text);
		}
		_adminEnabled[Persistence.currentCookies] = true;
  }

  @override
  String get name => 'Administrator';
}
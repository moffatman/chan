import 'dart:async';
import 'dart:convert';

import 'package:chan/models/attachment.dart';
import 'package:chan/models/flag.dart';
import 'package:chan/services/linkifier.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/util.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/util.dart';
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
		super.platformUserAgents,
		super.archives,
		this.faviconPath = '/favicon.ico',
		this.defaultUsername = 'Anonymous'
	});

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

	static final _quoteLinkPattern = RegExp(r'^\/([^\/]+)\/\/?(?:(?:res)|(?:thread))\/(\d+)(?:\.html)?#(\d+)');

	static PostNodeSpan makeSpan(String board, int threadId, String data) {
		final body = parseFragment(data.replaceAll('<wbr>', ''));
		final List<PostSpan> elements = [];
		for (final node in body.nodes) {
			if (node is dom.Element) {
				if (node.localName == 'br') {
					elements.add(const PostLineBreakSpan());
				}
				else if (node.localName == 'a' && node.attributes['href'] != null) {
					final match = _quoteLinkPattern.firstMatch(node.attributes['href']!);
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
				md5: data['md5'] ?? '',
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

	Future<ImageboardPoll?> _getPoll(ThreadIdentifier thread) async {
		try {
			final response = await client.postUri(Uri.https(baseUrl, '/poll.php'), data: {
				'query_poll': '1',
				'id': thread.id.toString(),
				'board': thread.board
			}, options: Options(
				contentType: Headers.formUrlEncodedContentType,
				responseType: ResponseType.plain
			));
			final data = jsonDecode((response.data as String).trim());
			final colors = (data['colors'] as List?)?.cast<String>();
			final question = (data['question'] as List).cast<Map>();
			final rows = <ImageboardPollRow>[];
			for (int i = 0; i < question.length; i++) {
				final entry = question[i].entries.trySingle;
				if (entry != null) {
					rows.add(ImageboardPollRow(
						name: entry.key,
						votes: entry.value,
						color: switch (colors?[i]) {
							String hex => colorToHex(hex),
							null => null
						}
					));
				}
				// Else some in-band metadata
			}
			return ImageboardPoll(
				title: null,
				rows: rows
			);
		}
		catch (e, st) {
			// Not fatal
			Future.error(e, st);
			return null;
		}
	}

	static final _pollFormPattern = RegExp('<div [^>]+class=\'pollform\'>.*<\\/div>(?:<br\\/>)?');

	Post _makePost(String board, int threadId, dynamic data) {
		final int id = data['no'];
		final String text;
		if (id == threadId) {
			// Only OP can have inline poll metadata
			text = (data['com'] as String? ?? '').replaceFirst(_pollFormPattern, '');
		}
		else {
			text = data['com'] as String? ?? '';
		}
		return Post(
			board: board,
			text: text,
			name: data['name'] ?? '',
			time: DateTime.fromMillisecondsSinceEpoch(data['time'] * 1000),
			id: id,
			threadId: threadId,
			attachments_: _makeAttachments(board, threadId, data),
			attachmentDeleted: data['filedeleted'] == 1 || data['ext'] == 'deleted',
			spanFormat: PostSpanFormat.lainchan,
			posterId: data['id'],
			flag: _makeFlag(data),
			capcode: data['capcode']
		);
	}

	@override
	Future<Post> getPost(String board, int id, {required RequestPriority priority}) {
		throw Exception('Not implemented');
	}

	@protected
	String get res => 'res';

	@override
	Future<Thread> getThreadImpl(ThreadIdentifier thread, {ThreadVariant? variant, required RequestPriority priority}) async {
		final response = await client.getUri(Uri.https(baseUrl, '/${thread.board}/$res/${thread.id}.json'), options: Options(
			validateStatus: (x) => true,
			extra: {
				kPriority: priority
			}
		));
		if (response.statusCode == 404 || (response.redirects.tryLast?.location.pathSegments.tryLast?.startsWith('404.') ?? false)) {
			throw ThreadNotFoundException(thread);
		}
		else if (response.statusCode != 200) {
			throw HTTPStatusException(response.statusCode ?? 0);
		}
		final firstPost = response.data['posts'][0];
		final hasPoll = _pollFormPattern.hasMatch(firstPost['com'] as String? ?? '');
		final List<Post> posts = (response.data['posts'] ?? []).map<Post>((postData) => _makePost(thread.board, thread.id, postData)).toList();
		return Thread(
			board: thread.board,
			id: thread.id,
			isSticky: firstPost['sticky'] == 1,
			title: (firstPost['sub'] as String?)?.unescapeHtml,
			attachmentDeleted: posts[0].attachmentDeleted,
			attachments: posts[0].attachments_,
			time: DateTime.fromMillisecondsSinceEpoch(firstPost['time'] * 1000),
			replyCount: posts.length - 1,
			imageCount: posts.skip(1).expand((p) => p.attachments).length,
			posts_: posts,
			poll: hasPoll ? await _getPoll(thread) : null
		);
	}
	@override
	Future<List<Thread>> getCatalogImpl(String board, {CatalogVariant? variant, required RequestPriority priority}) async {
		final response = await client.getUri(Uri.https(baseUrl, '/$board/catalog.json'), options: Options(
			validateStatus: (x) => true,
			extra: {
				kPriority: priority
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
					attachments: threadAsPost.attachments_,
					replyCount: threadData['replies'],
					imageCount: threadData['images'],
					isSticky: threadData['sticky'] == 1,
					time: DateTime.fromMillisecondsSinceEpoch(threadData['time'] * 1000),
					currentPage: currentPage == null ? null : currentPage + 1
					// Not fetching poll here, it will take too long. Just get it when the thread is opened
				);
				threads.add(thread);
			}
		}
		return threads;
	}

	@override
	Future<List<ImageboardBoard>> getBoards({required RequestPriority priority}) async {
		final response = await client.getUri(Uri.https(baseUrl, '/boards.json'), options: Options(
			responseType: ResponseType.json,
			extra: {
				kPriority: priority
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

	@override
	Future<PostReceipt> submitPost(DraftPost post, CaptchaSolution captchaSolution, CancelToken cancelToken) async {
		final now = DateTime.now().subtract(const Duration(seconds: 5));
		final password = List.generate(12, (i) => random.nextInt(16).toRadixString(16)).join();
		final referer = _getWebUrl(post.board, threadId: post.threadId, mod: loginSystem.isLoggedIn(Persistence.currentCookies));
		final page = await client.get(referer, options: Options(validateStatus: (x) => true), cancelToken: cancelToken);
		final Map<String, dynamic> fields = {
			for (final field in parse(page.data).querySelector('form[name="post"]')?.querySelectorAll('input[type="text"], input[type="submit"], input[type="hidden"], textarea') ?? [])
				field.attributes['name']!: field.attributes['value'] ?? field.text
		};
		fields['body'] = post.text;
		fields['password'] = password;
		if (post.threadId != null) {
			fields['thread'] = post.threadId.toString();
		}
		if (post.subject != null) {
			fields['subject'] = post.subject;
		}
		final file = post.file;
		if (file != null) {
			fields['attachment'] = await MultipartFile.fromFile(file, filename: post.overrideFilename);
		}
		if (post.spoiler == true) {
			fields['spoiler'] = 'on';
		}
		if (post.name?.isNotEmpty ?? false) {
			fields['name'] = post.name;
		}
		if (post.options?.isNotEmpty ?? false) {
			fields['email'] = post.options;
		}
		if (captchaSolution is SecurimageCaptchaSolution) {
			fields['captcha_cookie'] = captchaSolution.cookie;
			fields['captcha_text'] = captchaSolution.response;
		}
		else if (captchaSolution is SecucapCaptchaSolution) {
			fields['captcha'] = captchaSolution.response;
		}
		else if (captchaSolution is McCaptchaSolution) {
			fields['guid'] = captchaSolution.guid;
			fields['x'] = captchaSolution.x.toString();
			fields['y'] = captchaSolution.y.toString();
			if (captchaSolution.answer.isNotEmpty) {
				fields['captcha_text'] = captchaSolution.answer;
			}
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
			),
			cancelToken: cancelToken
		);
		if ((response.statusCode ?? 0) >= 400) {
			throw PostFailedException(parse(response.data).querySelector('h2')?.text ?? 'HTTP Error ${response.statusCode}');
		}
		if (response.isRedirect ?? false) {
			final digitMatches = RegExp(r'\d+').allMatches(response.redirects.last.location.toString());
			if (digitMatches.isNotEmpty) {
				return PostReceipt(
					post: post,
					id: int.parse(digitMatches.last.group(0)!),
					password: password,
					name: post.name ?? '',
					options: post.options ?? '',
					time: DateTime.now(),
					ip: captchaSolution.ip
				);
			}
		}
		final doc = parse(response.data);
		final ban = doc.querySelector('.ban');
		if (ban != null) {
			throw PostFailedException(ban.text);
		}
		final captchaKeyElement = doc.querySelector('form [data-sitekey]');
		if (captchaKeyElement != null) {
			// The captcha here is not automatable
			throw const WebAuthenticationRequiredException();
		}
		// This doesn't work if user has quoted someone, but it shouldn't be needed
		int? newPostId;
		final threadId = post.threadId;
		await Future.delayed(const Duration(milliseconds: 500));
		for (int i = 0; newPostId == null && i < 10; i++) {
			if (threadId == null) {
				for (final thread in (await getCatalog(post.board, priority: RequestPriority.interactive)).reversed) {
					if (thread.title == post.subject && (thread.posts[0].span.buildText().similarityTo(post.text) > 0.9) && (thread.time.compareTo(now) >= 0)) {
						newPostId = thread.id;
					}
				}
			}
			else {
				for (final post in (await getThread(ThreadIdentifier(post.board, threadId), priority: RequestPriority.interactive)).posts) {
					if ((post.span.buildText().similarityTo(post.text) > 0.9) && (post.time.compareTo(now) >= 0)) {
						newPostId = post.id;
					}
				}
			}
			await Future.delayed(const Duration(seconds: 2));
		}
		if (newPostId == null) {
			throw TimeoutException('Could not find post ID after submission', const Duration(seconds: 20));
		}
		return PostReceipt(
			post: post,
			id: newPostId,
			password: password,
			name: post.name ?? '',
			options: post.options ?? '',
			time: DateTime.now(),
			ip: captchaSolution.ip
		);
	}

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
	Future<ImageboardReportMethod> getPostReportMethod(PostIdentifier post) async {
		return WebReportMethod(Uri.https(baseUrl, '/report.php?post=delete_${post.postId}&board=${post.board}'));
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
	String getWebUrlImpl(String board, [int? threadId, int? postId]) {
		return _getWebUrl(board, threadId: threadId, postId: postId);
	}

	@override
	Iterable<ImageboardSnippet> getBoardSnippets(String board) => const [
		greentextSnippet
	];

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
	bool operator ==(Object other) =>
		identical(this, other) ||
		(other is SiteLainchan) &&
		(other.baseUrl == baseUrl) &&
		(other.name == name) &&
		(other.maxUploadSizeBytes == maxUploadSizeBytes) &&
		listEquals(other.archives, archives) &&
		(other.faviconPath == faviconPath) &&
		(other.defaultUsername == defaultUsername);

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
  Future<void> logout(bool fromBothWifiAndCellular) async {
		final jars = fromBothWifiAndCellular ? [
			Persistence.wifiCookies,
			Persistence.cellularCookies
		] : [
			Persistence.currentCookies
		];
		for (final jar in jars) {
			await jar.delete(Uri.https(parent.baseUrl, '/'), true);
			await jar.delete(Uri.https(parent.baseUrl, '/mod.php'), true);
			loggedIn[jar] = false;
		}
		await CookieManager.instance().deleteCookies(
			url: WebUri(parent.baseUrl)
		);
  }

  @override
  Future<void> login(Map<ImageboardSiteLoginField, String> fields) async {
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
			await logout(false);
			throw ImageboardSiteLoginException(document.querySelector('h2')!.text);
		}
		loggedIn[Persistence.currentCookies] = true;
  }

  @override
  String get name => 'Administrator';
}
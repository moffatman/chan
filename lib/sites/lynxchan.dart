import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:chan/models/flag.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/helpers/http_304.dart';

import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/lainchan.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart';
import 'package:html/dom.dart' as dom;
import 'package:mime/mime.dart';

class SiteLynxchan extends ImageboardSite with Http304CachingThreadMixin, DecodeGenericUrlMixin {
	@override
	final String name;
	@override
	final String baseUrl;
	@override
	final String defaultUsername;
	final List<ImageboardBoard>? boards;
	@override
	final bool hasLinkCookieAuth;

	static final _quoteLinkPattern = RegExp(r'^\/([^\/]+)\/\/?res\/(\d+).html#(\d+)');

	static PostNodeSpan makeSpan(String board, int threadId, String data) {
		final body = parseFragment(data.trimRight());
		final List<PostSpan> elements = [];
		int spoilerSpanId = 0;
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
						elements.add(PostLinkSpan(node.attributes['href']!, name: node.text.nonEmptyOrNull));
					}
				}
				else if (node.localName == 'span') {
					if (node.classes.contains('greenText')) {
						elements.add(PostQuoteSpan(makeSpan(board, threadId, node.innerHtml)));
					}
					else if (node.classes.contains('redText')) {
						elements.add(PostColorSpan(PostBoldSpan(makeSpan(board, threadId, node.innerHtml)), const Color(0xFFAF0A0F)));
					}
					else if (node.classes.contains('spoiler')) {
						elements.add(PostSpoilerSpan(PostTextSpan(node.text), spoilerSpanId++));
					}
					else {
						elements.add(PostTextSpan(node.text));
					}
				}
				else if (node.localName == 'strong') {
					elements.add(PostBoldSpan(makeSpan(board, threadId, node.innerHtml)));
				}
				else {
					elements.addAll(SiteLainchan.parsePlaintext(node.text));
				}
			}
			else {
				elements.addAll(SiteLainchan.parsePlaintext(node.text ?? ''));
			}
		}
		return PostNodeSpan(elements.toList(growable: false));
	}

	SiteLynxchan({
		required this.name,
		required this.baseUrl,
		required this.boards,
		required this.defaultUsername,
		required super.overrideUserAgent,
		required super.archives,
		required super.imageHeaders,
		required super.videoHeaders,
		required this.hasLinkCookieAuth,
		required this.hasPagedCatalog
	});

	ImageboardFlag? _makeFlag(Map data) {
		if (data case {'flag': String flag, 'flagName': String flagName}) {
			return ImageboardFlag(
				name: flagName,
				imageUrl: Uri.https(baseUrl, flag).toString(),
				imageWidth: 16,
				imageHeight: 11
			);
		}
		else if (data['flagCode'] case String flagCode) {
			if (flagCode.startsWith('-')) {
				return ImageboardFlag(
					name: '',
					imageUrl: Uri.https(baseUrl, '/.static/flags/${flagCode.split('-')[1]}.png').toString(),
					imageWidth: 16,
					imageHeight: 11
				);
			}
		}
		return null;
	}

	@override
	Future<PostReceipt> submitPost(DraftPost post, CaptchaSolution captchaSolution, CancelToken cancelToken) async {
		final password = makeRandomBase64String(8);
		String? fileSha256;
		final file = post.file;
		if (file != null) {
			fileSha256 = sha256.convert(await File(file).readAsBytes()).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
		}
		final flag = post.flag;
		final response = await client.postUri(Uri.https(baseUrl, post.threadId == null ? '/newThread.js' : '/replyThread.js', {
			'json': '1'
		}), data: FormData.fromMap({
			if (post.name?.isNotEmpty ?? false) 'name': post.name,
			if (post.options?.isNotEmpty ?? false)'email': post.options,
			'message': post.text,
			'subject': post.subject,
			'password': password,
			'boardUri': post.board,
			if (post.threadId != null) 'threadId': post.threadId.toString(),
			if (captchaSolution is LynxchanCaptchaSolution) ...{
				'captchaId': captchaSolution.id,
				'captcha': captchaSolution.answer
			},
			if (post.spoiler ?? false) 'spoiler': 'spoiler',
			if (flag != null) 'flag': flag.code,
			if (file != null) ...{
				'fileSha256': fileSha256,
				'fileMime': lookupMimeType(file),
				'fileSpoiler': (post.spoiler ?? false) ? 'spoiler': '',
				'fileName': post.overrideFilename ?? file.afterLast('/'),
				'files': await MultipartFile.fromFile(file, filename: post.overrideFilename)
			}
		}), options: Options(
			validateStatus: (x) => true,
			extra: {
				kPriority: RequestPriority.interactive
			},
			responseType: null
		), cancelToken: cancelToken);
		if (response.data is String) {
			final document = parse(response.data);
			if (response.statusCode != 200) {
				throw PostFailedException(document.querySelector('#errorLabel')?.text ?? 'HTTP Error ${response.statusCode}');
			}
			final match = RegExp(r'(\d+)\.html#(\d+)?').firstMatch(document.querySelector('#linkRedirect')?.attributes['href'] ?? '');
			if (match != null) {
				return PostReceipt(
					post: post,
					id: match.group(2) != null ? int.parse(match.group(2)!) : int.parse(match.group(1)!),
					password: password,
					name: post.name ?? '',
					options: post.options ?? '',
					time: DateTime.now(),
					ip: captchaSolution.ip
				);
			}
			throw PostFailedException(document.querySelector('title')?.text ?? 'Unknown error');
		}
		final data = response.data as Map;
		if (data['status'] != 'ok') {
			final error = data['error'] as String? ?? data.toString();
			if (RegExp(r'Flood detected, wait (\d+) more seconds.').firstMatch(error)?.group(1)?.tryParseInt case int seconds) {
				throw PostCooldownException(error, DateTime.now().add(Duration(seconds: seconds)));
			}
			throw PostFailedException(error);
		}
		return PostReceipt(
			id: data['data'] as int,
			password: password,
			name: post.name ?? '',
			options: post.options ?? '',
			time: DateTime.now(),
			post: post,
			ip: captchaSolution.ip
		);
	}

	@override
	@protected
	String get res => 'res';

	@override
	Future<void> deletePost(ThreadIdentifier thread, PostReceipt receipt, CaptchaSolution captchaSolution, CancelToken cancelToken, {required bool imageOnly}) async {
		final response = await client.postUri<Map>(Uri.https(baseUrl, '/contentActions.js', {
			'json': '1'
		}), data: {
			'action': 'delete',
			'password': receipt.password,
			'confirmation': 'true',
			'meta-${thread.id}-${receipt.id}': 'true',
			if (imageOnly) 'deleteUploads': 'true'
		}, options: Options(
			extra: {
				kPriority: RequestPriority.interactive
			},
			responseType: ResponseType.json
		), cancelToken: cancelToken);
		if (response.data?['status'] != 'ok') {
			throw DeletionFailedException(response.data?['data'] as String? ?? response.data.toString());
		}
	}

	@override
	Future<List<ImageboardBoard>> getBoards({required RequestPriority priority, CancelToken? cancelToken}) async {
		if (boards != null) {
			return boards!;
		}
		final response = await client.getUri(Uri.https(baseUrl, '/boards.js'), options: Options(
			responseType: ResponseType.plain,
			extra: {
				kPriority: priority
			}
		), cancelToken: cancelToken);
		return _getBoardsFromResponse(response);
	}

	List<ImageboardBoard> _getBoardsFromResponse(Response response) {
		final document = parse(response.data);
		final list = <ImageboardBoard>[];
		final linkPattern = RegExp(r'^\/([^/]+)\/ - (.*)$');
		for (final cell in document.querySelectorAll('#divBoards .boardsCell')) {
			final col1 = cell.querySelector('span');
			final match = linkPattern.firstMatch(col1?.querySelector('.linkBoard')?.text ?? '');
			if (col1 == null || match == null) {
				continue;
			}
			list.add(ImageboardBoard(
				name: match.group(1)!,
				title: match.group(2)!,
				isWorksafe: col1.querySelector('.indicatorSfw') != null,
				webmAudioAllowed: true,
				popularity: int.tryParse(cell.querySelector('.labelPostCount')?.text ?? '')
			));
		}
		if (list.isEmpty) {
			for (final cell in document.querySelectorAll('#divBoards tr')) {
				final col1 = cell.querySelector('td');
				final match = linkPattern.firstMatch(col1?.querySelector('.linkBoard')?.text ?? '');
				if (col1 == null || match == null) {
					continue;
				}
				list.add(ImageboardBoard(
					name: match.group(1)!,
					title: match.group(2)!,
					isWorksafe: col1.querySelector('.indicatorSfw') != null,
					webmAudioAllowed: true,
					popularity: int.tryParse(cell.querySelector('.labelPostCount')?.text ?? '')
				));
			}
		}
		return list;
	}

	@override
	ImageboardBoardPopularityType? get boardPopularityType => ImageboardBoardPopularityType.postsCount;

	@override
	Future<List<ImageboardBoard>> getBoardsForQuery(String query) async {
		final response = await client.getUri(Uri.https(baseUrl, '/boards.js', {
			'boardUri': query
		}), options: Options(
			responseType: ResponseType.plain,
			extra: {
				kPriority: RequestPriority.functional
			}
		));
		return _getBoardsFromResponse(response);
	}

	@override
	Future<CaptchaRequest> getCaptchaRequest(String board, int? threadId, {CancelToken? cancelToken}) async {
		final captchaMode = persistence?.maybeGetBoard(board)?.captchaMode ?? 0;
		if (captchaMode == 0 ||
				(captchaMode == 1 && threadId != null)) {
			return const NoCaptchaRequest();
		}
		return LynxchanCaptchaRequest(
			board: board
		);
	}

	void _updateBoardInformation(String boardName, Map data) {
		try {
			final board = (persistence?.maybeGetBoard(boardName))!;
			board.maxCommentCharacters = data['maxMessageLength'] as int?;
			final fileSizeParts = (data['maxFileSize'] as String).split(' ');
			double maxFileSize = double.parse(fileSizeParts.first);
			if (fileSizeParts[1].toLowerCase().startsWith('m')) {
				maxFileSize *= 1024 * 1024;
			}
			else if (fileSizeParts[1].toLowerCase().startsWith('k')) {
				maxFileSize *= 1024;
			}
			else {
				throw Exception('Unexpected file-size unit: ${fileSizeParts[1]}');
			}
			board.captchaMode = data['captchaMode'] as int?;
			board.maxImageSizeBytes = maxFileSize.round();
			board.maxWebmSizeBytes = maxFileSize.round();
			board.pageCount = data['pageCount'] as int?;
			board.additionalDataTime = DateTime.now();
		}
		catch (e, st) {
			print(e);
			print(st);
		}
	}

	Future<void> _maybeUpdateBoardInformation(String boardName) async {
		final board = persistence?.maybeGetBoard(boardName);
		if (board?.popularity != null && DateTime.now().difference(board?.additionalDataTime ?? DateTime(2000)) > const Duration(days: 3)) {
			// Not updated recently
			return;
		}
		final response = await client.getUri<Map>(Uri.https(baseUrl, '/$boardName/1.json'));
		_updateBoardInformation(boardName, response.data!);
	}

	Future<List<Thread>> _getCatalogPage(String board, int page, {required RequestPriority priority, CancelToken? cancelToken}) async {
		final response = await client.getUri(Uri.https(baseUrl, '/$board/$page.json'), options: Options(
			validateStatus: (status) => status == 200 || status == 404,
			extra: {
				kPriority: priority
			},
			responseType: ResponseType.json
		), cancelToken: cancelToken);
		if (response.statusCode == 404) {
			throw BoardNotFoundException(board);
		}
		final data = response.data as Map;
		_updateBoardInformation(board, data);
		return (data['threads'] as List).cast<Map>().map(wrapUnsafe((o) => _makeThreadFromCatalog(board, o)..currentPage = page)).toList();
	}

	static int? _tryParseInt(dynamic s) => switch (s) {
		int x => x,
		String x => int.tryParse(x),
		_ => null
	};

	Thread _makeThreadFromCatalog(String board, Map obj) {
		final op = Post(
			board: board,
			text: obj['markdown'] as String,
			name: obj['name'] as String? ?? defaultUsername,
			flag: wrapUnsafe(_makeFlag)(obj),
			capcode: obj['signedRole'] as String?,
			time: DateTime.parse(obj['creation'] as String),
			threadId: obj['threadId'] as int,
			id: obj['threadId'] as int,
			spanFormat: PostSpanFormat.lynxchan,
			attachments_: (obj['files'] as List?)?.cast<Map>().map((f) {
				final path = f['path'] as String;
				return Attachment(
					type: AttachmentType.fromFilename(path),
					board: board,
					id: path,
					ext: '.${path.afterLast('.')}',
					filename: f['originalName'] as String? ?? path.afterLast('/'),
					url: Uri.https(imageUrl, path).toString(),
					thumbnailUrl: Uri.https(imageUrl, f['thumb'] as String).toString(),
					md5: '',
					width: _tryParseInt(f['width']),
					height: _tryParseInt(f['height']),
					threadId: obj['threadId'] as int?,
					sizeInBytes: f['size'] as int?
				);
			}).toList() ?? const []
		);
		final replies = (obj['posts'] as List?)?.cast<Map>().map((obj) => _makePost(board, op.id, obj['postId'] as int, obj)).toList() ?? [];
		return Thread(
			posts_: [op, ...replies],
			replyCount: obj['postCount'] as int? ?? ((obj['omittedPosts'] as int? ?? obj['ommitedPosts'] as int? ?? 0) + replies.length),
			imageCount: obj['fileCount'] as int? ?? ((obj['omittedFiles'] as int? ?? 0) + (replies.fold<int>(0, (c, p) => c + p.attachments_.length))),
			id: op.id,
			board: board,
			title: (obj['subject'] as String?)?.unescapeHtml,
			isSticky: obj['pinned'] as bool,
			time: DateTime.parse(obj['creation'] as String),
			attachments: op.attachments_,
			currentPage: obj['page'] as int?
		);
	}


	@override
	Future<List<Thread>> getCatalogImpl(String board, {CatalogVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) async {
		if (hasPagedCatalog) {
			return await _getCatalogPage(board, 1, priority: priority, cancelToken: cancelToken);
		}
		final response = await client.getUri(Uri.https(baseUrl, '/$board/catalog.json'), options: Options(
			validateStatus: (status) => status == 200 || status == 404,
			extra: {
				kPriority: priority
			}
		), cancelToken: cancelToken);
		if (response.statusCode == 404) {
			throw BoardNotFoundException(board);
		}
		_maybeUpdateBoardInformation(board); // Don't await
		return (response.data as List).cast<Map>().map((o) => _makeThreadFromCatalog(board, o)).toList();
	}

	/// catalog.json may be missing important details, but always has threadId + page
	@override
	Future<Map<int, int>> getCatalogPageMapImpl(String board, {CatalogVariant? variant, required RequestPriority priority, DateTime? acceptCachedAfter, CancelToken? cancelToken}) async {
		final response = await client.getUri(Uri.https(baseUrl, '/$board/catalog.json'), options: Options(
			validateStatus: (status) => status == 200 || status == 404,
			extra: {
				kPriority: priority
			}
		), cancelToken: cancelToken);
		if (response.statusCode == 404) {
			throw BoardNotFoundException(board);
		}
		return {
			for (final obj in (response.data as List).cast<Map>())
				obj['threadId'] as int: obj['page'] as int
		};
	}

	@override
	Future<List<Thread>> getMoreCatalogImpl(String board, Thread after, {CatalogVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) async {
		try {
			return _getCatalogPage(board, (after.currentPage ?? 0) + 1, priority: priority, cancelToken: cancelToken);
		}
		on BoardNotFoundException {
			return [];
		}
	}

	Post _makePost(String board, int threadId, int id, Map obj) => unsafe(obj, () {
		return Post(
			board: board,
			text: obj['markdown'] as String,
			name: obj['name'] as String,
			flag: wrapUnsafe(_makeFlag)(obj),
			capcode: obj['signedRole'] as String?,
			time: DateTime.parse(obj['creation'] as String),
			threadId: threadId,
			posterId: obj['id'] as String?,
			id: id,
			spanFormat: PostSpanFormat.lynxchan,
			attachments_: (obj['files'] as List).cast<Map>().asMap().entries.map(wrapUnsafe((e) {
				final path = e.value['path'] as String;
				return Attachment(
					type: AttachmentType.fromFilename(path),
					board: board,
					// Lynxchan dedupes images. Prepend some uniqueness here to avoid Hero problems later.
					id: '$id-${e.key}-$path',
					ext: '.${path.afterLast('.')}',
					filename: e.value['originalName'] as String,
					url: Uri.https(imageUrl, path).toString(),
					thumbnailUrl: Uri.https(imageUrl, e.value['thumb'] as String).toString(),
					md5: '',
					width: _tryParseInt(e.value['width']),
					height: _tryParseInt(e.value['height']),
					threadId: obj['threadId'] as int?,
					sizeInBytes: e.value['size'] as int?
				);
			})).toList()
		);
	});

	@override
	Future<Thread> makeThread(ThreadIdentifier thread, Response response, {
		required RequestPriority priority,
		CancelToken? cancelToken
	}) async {
		final data = response.data as Map;
		_maybeUpdateBoardInformation(thread.board); // Don't await
		final op = _makePost(thread.board, thread.id, thread.id, data);
		final posts = [
			op,
			...(data['posts'] as List).cast<Map>().map((obj) => _makePost(thread.board, thread.id, obj['postId'] as int, obj))
		];
		return Thread(
			posts_: posts,
			replyCount: posts.length - 1,
			imageCount: posts.fold<int>(0, (c, p) => c + p.attachments.length) - op.attachments.length,
			id: thread.id,
			board: thread.board,
			title: (data['subject'] as String?)?.unescapeHtml,
			isSticky: data['pinned'] as bool,
			time: op.time,
			attachments: op.attachments_,
			isArchived: data['archived'] as bool? ?? false
		);
	}

	@override
	RequestOptions getThreadRequest(ThreadIdentifier thread, {ThreadVariant? variant})
		=> RequestOptions(
			path: '/${thread.board}/res/${thread.id}.json',
			baseUrl: 'https://$baseUrl',
			responseType: ResponseType.json
		);

	@override
	String getWebUrlImpl(String board, [int? threadId, int? postId]) {
		String url = 'https://$baseUrl/$board/';
		if (threadId != null) {
			url += 'res/$threadId.html';
			if (postId != null) {
				url += '#$postId';
			}
		}
		return url;
	}

	@override
	Uri? get iconUrl => Uri.https(baseUrl, '/favicon.ico');

	@override
	List<ImageboardSnippet> getBoardSnippets(String board) => const [
		greentextSnippet
	];

	@override
	String get siteData => baseUrl;

	@override
	String get siteType => 'lynxchan';

	@override
	final bool hasPagedCatalog;

	@override
	Future<void> clearPseudoCookies() async {
		persistence?.browserState.loginFields.remove(kLoginFieldLastSolvedCaptchaKey);
	}

	static const kLoginFieldLastSolvedCaptchaKey = 'lc';

	@override
	/// All images hosted in baseUrl anyway
	String get imageUrl => baseUrl;

	@override
	bool operator == (Object other) =>
		identical(other, this) ||
		other is SiteLynxchan &&
		other.name == name &&
		other.baseUrl == baseUrl &&
		listEquals(other.boards, boards) &&
		other.defaultUsername == defaultUsername &&
		other.hasLinkCookieAuth == hasLinkCookieAuth &&
		other.hasPagedCatalog == hasPagedCatalog &&
		super==(other);
	
	@override
	int get hashCode => baseUrl.hashCode;
}
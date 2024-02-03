import 'dart:async';
import 'dart:ui';

import 'package:chan/models/flag.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/services/util.dart';
import 'dart:io';

import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/lainchan.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart';
import 'package:html/dom.dart' as dom;
import 'package:mime/mime.dart';

class SiteLynxchan extends ImageboardSite {
	@override
	final String name;
	@override
	final String baseUrl;
	final List<ImageboardBoard>? boards;

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
					final match = RegExp(r'^\/([^\/]+)\/\/?res\/(\d+).html#(\d+)').firstMatch(node.attributes['href']!);
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
		super.platformUserAgents,
		super.archives
	});

	ImageboardFlag? _makeFlag(Map<String, dynamic> data) {
		if (data['flag'] != null) {
			return ImageboardFlag(
				name: data['flagName'],
				imageUrl: Uri.https(baseUrl, data['flag']).toString(),
				imageWidth: 16,
				imageHeight: 11
			);
		}
		else if ((data['flagCode'] as String?)?.startsWith('-') ?? false) {
			return ImageboardFlag(
				name: '',
				imageUrl: Uri.https(baseUrl, '/.static/flags/${data['flagCode'].split('-')[1]}.png').toString(),
				imageWidth: 16,
				imageHeight: 11
			);
		}
		return null;
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
		final password = makeRandomBase64String(16).substring(0, 8);
		String? fileSha256;
		bool fileAlreadyUploaded = false;
		if (file != null) {
			fileSha256 = sha256.convert(await file.readAsBytes()).bytes.map((b) => b.toRadixString(16)).join();
			final filePresentResponse = await client.getUri(Uri.https(baseUrl, '/checkFileIdentifier.js', {
				'json': '1',
				'identifier': fileSha256
			}));
			if (filePresentResponse.data is bool) {
				fileAlreadyUploaded = filePresentResponse.data;
			}
			else {
				if (filePresentResponse.data['status'] != 'ok') {
					throw PostFailedException('Error checking if file was already uploaded: ${filePresentResponse.data['error'] ?? filePresentResponse.data}');
				}
				fileAlreadyUploaded = filePresentResponse.data['data'];
			}
		}
		final response = await client.postUri(Uri.https(baseUrl, threadId == null ? '/newThread.js' : '/replyThread.js', {
			'json': '1'
		}), data: FormData.fromMap({
			if (name.isNotEmpty) 'name': name,
			if (options.isNotEmpty )'email': options,
			'message': text,
			'subject': subject,
			'password': password,
			'boardUri': board,
			if (threadId != null) 'threadId': threadId.toString(),
			if (captchaSolution is LynxchanCaptchaSolution) ...{
				'captchaId': captchaSolution.id,
				'captcha': captchaSolution.answer
			},
			if (spoiler ?? false) 'spoiler': 'spoiler',
			if (flag != null) 'flag': flag.code,
			if (file != null) ...{
				'fileSha256': fileSha256,
				'fileMime': lookupMimeType(file.path),
				'fileSpoiler': (spoiler ?? false) ? 'spoiler': '',
				'fileName': overrideFilename ?? file.path.split('/').last,
				if (!fileAlreadyUploaded) 'files': await MultipartFile.fromFile(file.path, filename: overrideFilename)
			}
		}), options: Options(
			validateStatus: (x) => true
		));
		if (response.data is String) {
			final document = parse(response.data);
			if (response.statusCode != 200) {
				throw PostFailedException(document.querySelector('#errorLabel')?.text ?? 'HTTP Error ${response.statusCode}');
			}
			final match = RegExp(r'(\d+)\.html#(\d+)?').firstMatch(document.querySelector('#linkRedirect')?.attributes['href'] ?? '');
			if (match != null) {
				return PostReceipt(
					id: match.group(2) != null ? int.parse(match.group(2)!) : int.parse(match.group(1)!),
					password: password,
					name: name,
					options: options,
					time: DateTime.now(),
					ip: captchaSolution.ip
				);
			}
			throw PostFailedException(document.querySelector('title')?.text ?? 'Unknown error');
		}
		if (response.data['status'] != 'ok') {
			throw PostFailedException(response.data['error'] ?? response.data.toString());
		}
		return PostReceipt(
			id: response.data['data'],
			password: password,
			name: name,
			options: options,
			time: DateTime.now(),
			ip: captchaSolution.ip
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
	Future<BoardThreadOrPostIdentifier?> decodeUrl(String url) async {
		return SiteLainchan.decodeGenericUrl(baseUrl, url);
	}

	@override
	String get defaultUsername => 'Anon';

	@override
	Future<void> deletePost(String board, int threadId, PostReceipt receipt) async {
		final response = await client.postUri(Uri.https(baseUrl, '/contentActions.js', {
			'json': '1'
		}), data: {
			'action': 'delete',
			'password': receipt.password,
			'confirmation': 'true',
			'meta-$threadId-${receipt.id}': 'true'
		});
		if (response.data['status'] != 'ok') {
			throw DeletionFailedException(response.data['data'] ?? response.data);
		}
	}

	@override
	Future<List<ImageboardBoard>> getBoards({required RequestPriority priority}) async {
		if (boards != null) {
			return boards!;
		}
		final response = await client.getUri(Uri.https(baseUrl, '/boards.js'), options: Options(
			extra: {
				kPriority: priority
			}
		));
		final document = parse(response.data);
		final list = <ImageboardBoard>[];
		final linkPattern = RegExp(r'^\/([^/]+)\/ - (.*)$');
		for (final col1 in document.querySelectorAll('#divBoards .col1')) {
			final match = linkPattern.firstMatch(col1.querySelector('.linkBoard')?.text ?? '');
			if (match == null) {
				continue;
			}
			list.add(ImageboardBoard(
				name: match.group(1)!,
				title: match.group(2)!,
				isWorksafe: col1.querySelector('.indicatorSfw') != null,
				webmAudioAllowed: true
			));
		}
		return list;
	}

	@override
	Future<CaptchaRequest> getCaptchaRequest(String board, [int? threadId]) async {
		final captchaMode = persistence.maybeGetBoard(board)?.captchaMode ?? 0;
		if (captchaMode == 0 ||
				(captchaMode == 1 && threadId != null)) {
			return const NoCaptchaRequest();
		}
		return LynxchanCaptchaRequest(
			board: board
		);
	}

	void _updateBoardInformation(String boardName, Map<String, dynamic> data) async {
		try {
			final board = persistence.maybeGetBoard(boardName)!;
			board.maxCommentCharacters = data['maxMessageLength'];
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
			board.captchaMode = data['captchaMode'];
			board.maxImageSizeBytes = maxFileSize.round();
			board.maxWebmSizeBytes = maxFileSize.round();
			board.pageCount = data['pageCount'];
			board.additionalDataTime = DateTime.now();
		}
		catch (e, st) {
			print(e);
			print(st);
		}
	}

	Future<List<Thread>> _getCatalogPage(String board, int page, {required RequestPriority priority}) async {
		final response = await client.getUri(Uri.https(baseUrl, '/$board/$page.json'), options: Options(
			validateStatus: (status) => status == 200 || status == 404,
			extra: {
				kPriority: priority
			}
		));
		if (response.statusCode == 404) {
			throw BoardNotFoundException(board);
		}
		_updateBoardInformation(board, response.data);
		return (response.data['threads'] as List).map((obj) {
			final op = Post(
				board: board,
				text: obj['markdown'],
				name: obj['name'],
				flag: _makeFlag(obj),
				capcode: obj['signedRole'],
				time: DateTime.parse(obj['creation']),
				threadId: obj['threadId'],
				id: obj['threadId'],
				spanFormat: PostSpanFormat.lynxchan,
				attachments: (obj['files'] as List).map((f) => Attachment(
					type: AttachmentType.fromFilename(f['path']),
					board: board,
					id: f['path'],
					ext: '.${(f['path'] as String).split('.').last}',
					filename: f['originalName'],
					url: Uri.https(baseUrl, f['path']).toString(),
					thumbnailUrl: Uri.https(baseUrl, f['thumb']).toString(),
					md5: '',
					width: f['width'],
					height: f['height'],
					threadId: obj['threadId'],
					sizeInBytes: f['size']
				)).toList()
			);
			return Thread(
				posts_: [op],
				replyCount: (obj['omittedPosts'] ?? obj['ommitedPosts'] ?? 0) + (obj['posts'] as List).length,
				imageCount: (obj['omittedFiles'] ?? 0) + (obj['posts'] as List).fold<int>(0, (c, p) => c + (p['files'] as List).length),
				id: op.id,
				board: board,
				title: (obj['subject'] as String?)?.unescapeHtml,
				isSticky: obj['pinned'],
				time: DateTime.parse(obj['creation']),
				attachments: op.attachments,
				currentPage: page
			);
		}).toList();
	}


	@override
	Future<List<Thread>> getCatalogImpl(String board, {CatalogVariant? variant, required RequestPriority priority}) async {
		return _getCatalogPage(board, 1, priority: priority);
	}

	@override
	Future<List<Thread>> getMoreCatalogImpl(String board, Thread after, {CatalogVariant? variant, required RequestPriority priority}) async {
		try {
			return _getCatalogPage(board, (after.currentPage ?? 0) + 1, priority: priority);
		}
		on BoardNotFoundException {
			return [];
		}
	}

	@override
	Future<Post> getPost(String board, int id, {required RequestPriority priority}) {
		throw UnimplementedError();
	}

	@override
	Uri getSpoilerImageUrl(Attachment attachment, {ThreadIdentifier? thread}) {
		throw UnimplementedError();
	}

	Post _makePost(String board, int threadId, int id, Map<String, dynamic> obj) {
		return Post(
			board: board,
			text: obj['markdown'],
			name: obj['name'],
			flag: _makeFlag(obj),
			capcode: obj['signedRole'],
			time: DateTime.parse(obj['creation']),
			threadId: threadId,
			posterId: obj['id'],
			id: id,
			spanFormat: PostSpanFormat.lynxchan,
			attachments: (obj['files'] as List).asMap().entries.map((e) => Attachment(
				type: AttachmentType.fromFilename(e.value['path']),
				board: board,
				// Lynxchan dedupes images. Prepend some uniqueness here to avoid Hero problems later.
				id: '$id-${e.key}-${e.value['path']}',
				ext: '.${(e.value['path'] as String).split('.').last}',
				filename: e.value['originalName'],
				url: Uri.https(baseUrl, e.value['path']).toString(),
				thumbnailUrl: Uri.https(baseUrl, e.value['thumb']).toString(),
				md5: '',
				width: e.value['width'],
				height: e.value['height'],
				threadId: obj['threadId'],
				sizeInBytes: e.value['size']
			)).toList()
		);
	}

	@override
	Future<Thread> getThreadImpl(ThreadIdentifier thread, {ThreadVariant? variant, required RequestPriority priority}) async {
		final response = await client.getUri(Uri.https(baseUrl, '/${thread.board}/res/${thread.id}.json'), options: Options(
			validateStatus: (status) => status == 200 || status == 404,
			extra: {
				kPriority: priority
			}
		));
		if (response.statusCode == 404) {
			throw ThreadNotFoundException(thread);
		}
		final op = _makePost(thread.board, thread.id, thread.id, response.data);
		final posts = [
			op,
			...(response.data['posts'] as List).map((obj) => _makePost(thread.board, thread.id, obj['postId'], obj))
		];
		return Thread(
			posts_: posts,
			replyCount: posts.length - 1,
			imageCount: posts.fold<int>(0, (c, p) => c + p.attachments.length) - op.attachments.length,
			id: thread.id,
			board: thread.board,
			title: (response.data['subject'] as String?)?.unescapeHtml,
			isSticky: response.data['pinned'],
			time: op.time,
			attachments: op.attachments,
			isArchived: response.data['archived'] ?? false
		);
	}

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
	Uri get iconUrl => Uri.https(baseUrl, '/favicon.ico');

	@override
	String get imageUrl => baseUrl;

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
	Iterable<ImageboardSnippet> getBoardSnippets(String board) => const [
		greentextSnippet
	];

	@override
	String get siteData => baseUrl;

	@override
	String get siteType => 'lynxchan';

	@override
	bool get hasPagedCatalog => true;

	@override
	Future<void> clearPseudoCookies() async {
		persistence.browserState.loginFields.remove(kLoginFieldLastSolvedCaptchaKey);
	}

	static const kLoginFieldLastSolvedCaptchaKey = 'lc';
}
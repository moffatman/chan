import 'dart:convert';
import 'dart:io';

import 'package:chan/models/attachment.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/thumbnailer.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/4chan.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/lainchan.dart';
import 'package:chan/sites/util.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart';

class SiteKarachan extends ImageboardSite {
	@override
	final String baseUrl;
	@override
	final String name;
	@override
	final String defaultUsername;
	final String captchaKey;

	static const _kCookie = 'regulamin=accepted';

	@override
	Map<String, String> getHeaders(Uri url) {
		final headers = super.getHeaders(url);
		if (url.host == baseUrl) {
			headers.update(
				'cookie',
				(cookies) => '$cookies; $_kCookie',
				ifAbsent: () => _kCookie
			);
		}
		return headers;
	}

	SiteKarachan({
		required this.baseUrl,
		required this.name,
		required this.captchaKey,
		this.defaultUsername = 'Anonymous',
		required super.overrideUserAgent,
		required super.archives,
		required super.imageHeaders,
		required super.videoHeaders
	}) {
		client.interceptors.add(InterceptorsWrapper(
			onRequest: (options, handler) {
				options.headers.update(HttpHeaders.cookieHeader, (existing) {
					return '$existing; $_kCookie';
				}, ifAbsent: () => _kCookie);
				handler.next(options);
			}
		));
	}

	static final _quoteLinkHrefPattern = RegExp(r'/([^/]+)/res/(\d+)\.html(?:#p(\d+))?$');
	static final _quoteLinkTextPattern = RegExp(r'>>(?:/([a-zA-Z0-9]+)/)?(\d+)');

	static PostNodeSpan makeSpan(String board, int threadId, String text) {
		final body = parseFragment(text);
		int spoilerSpanId = 0;
		Iterable<PostSpan> visit(Iterable<dom.Node> nodes) sync* {
			bool addLinebreakBefore = false;
			for (final node in nodes) {
				bool addedLinebreakBefore = addLinebreakBefore;
				if (addLinebreakBefore) {
					yield const PostLineBreakSpan();
					addLinebreakBefore = false;
				}
				if (node is dom.Element) {
					if (node.localName == 'p') {
						if (addedLinebreakBefore) {
							yield const PostLineBreakSpan();
						}
						yield* visit(node.nodes);
						addLinebreakBefore = true;
					}
					else if (node.localName == 'br') {
						addLinebreakBefore = true;
					}
					else if (node.localName == 'a' && node.classes.contains('quotelink')) {
						final match = _quoteLinkHrefPattern.firstMatch(node.attributes['href'] ?? '');
						if (match != null) {
							final threadId = int.parse(match.group(2)!);
							yield PostQuoteLinkSpan(
								board: match.group(1)!,
								threadId: threadId,
								postId: int.tryParse(match.group(3) ?? '') ?? threadId
							);
						}
						else if (node.classes.contains('unexisting-quotelink')) {
							final match = _quoteLinkTextPattern.firstMatch(node.text);
							if (match != null) {
								yield PostQuoteLinkSpan.dead(
									board: match.group(1) ?? board,
									postId: int.parse(match.group(2)!)
								);
							}
							else {
								// Something went wrong
								yield PostTextSpan(node.outerHtml);
							}
						}
						else {
							// Something went wrong
							yield PostTextSpan(node.outerHtml);
						}
					}
					else if (node.localName == 'a' && node.classes.contains('postlink') && node.attributes.containsKey('href')) {
						yield PostLinkSpan(node.attributes['href']!, name: node.text.nonEmptyOrNull);
					}
					else if (node.localName == 'span' && node.classes.contains('quote')) {
						yield PostQuoteSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)));
					}
					else if (node.localName == 'b') {
						yield PostBoldSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)));
					}
					else if (node.localName == 'i') {
						yield PostItalicSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)));
					}
					else if (node.localName == 'u') {
						yield PostUnderlinedSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)));
					}
					else if (node.localName == 's') {
						yield PostSpoilerSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)), spoilerSpanId++);
					}
					else if (node.localName == 'ol' || node.localName == 'ul') {
						int i = 1;
						for (final li in node.nodes) {
							if (li is dom.Element && li.localName == 'li') {
								if (addLinebreakBefore) {
									yield const PostLineBreakSpan();
									addLinebreakBefore = false;
								}
								if (node.localName == 'ol') {
									yield PostTextSpan('$i. ');
								}
								else {
									yield const PostTextSpan('• ');
								}
								yield PostNodeSpan(visit(li.nodes).toList(growable: false));
								addLinebreakBefore = true;
								i++;
							}
						}
					}
					else if (node.localName == 'img' && node.attributes.containsKey('src')) {
						final src = node.attributes['src']!;
						yield PostInlineImageSpan(src: src, width: 32, height: 32);
					}
					else if (node.localName == 'div' && node.classes.contains('backlink')) {
						// Junk, don't show
					}
					else if (node.localName == 'span' && node.attributes.keys.trySingle == 'style') {
						yield PostCssSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)), node.attributes['style'] ?? '');
					}
					else if (node.localName == 'style') {
						// Ignore
					}
					else {
						yield* Site4Chan.parsePlaintext(node.outerHtml);
					}
				}
				else {
					yield* Site4Chan.parsePlaintext(node.text ?? '');
				}
			}
		}
		return PostNodeSpan(visit(body.nodes).toList(growable: false));
	}

	@override
	Future<BoardThreadOrPostIdentifier?> decodeUrl(String url) async {
		return SiteLainchan.decodeGenericUrl(baseUrl, 'res', url);
	}

	@override
	Future<void> deletePost(ThreadIdentifier thread, PostReceipt receipt, CaptchaSolution captchaSolution, CancelToken cancelToken, {required bool imageOnly}) async {
		final response = await client.postUri(
			Uri.https(baseUrl, '/imgboard.php'),
			data: FormData.fromMap({
				'delete': 'Usuń',
				'format': 'json',
				'pwd': receipt.password,
				'board': thread.board,
				'reason': '',
				'mode': 'usrform',
				'del%${thread.board}%${receipt.id}': 'delete',
				if (imageOnly) 'onlyimgdel': 'on'
			}),
			options: Options(
				headers: {
					'accept': 'application/json, text/javascript, */*; q=0.01',
					'referer': getWebUrlImpl(thread.board, thread.id),
					'x-requested-with': 'XMLHttpRequest'
				},
				responseType: ResponseType.plain,
				extra: {
					kPriority: RequestPriority.interactive
				}
			),
			cancelToken: cancelToken
		);
		if (response.data is! String) {
			throw Exception('Bad response: ${response.data}');
		}
		final data = jsonDecode(response.data as String);
		if ((data['realDeleted'] ?? '[]') == '[]') {
			// Didn't delete
			final msg = parseFragment(data['msg']).text ?? 'unknown';
			if (msg.toLowerCase().contains('poczekać')) {
				// that means "wait" in polish. delay the deletion.
				throw CooldownException(DateTime.now().add(const Duration(minutes: 2)));
			}
			throw Exception('${data['title']}: $msg');
		}
	}

	@override
	Future<List<ImageboardBoard>> getBoards({required RequestPriority priority, CancelToken? cancelToken}) async {
		final response = await client.getUri(Uri.https(baseUrl, '/search.php'), options: Options(
			extra: {
				kPriority: priority
			},
			responseType: ResponseType.plain
		), cancelToken: cancelToken);
		final document = parse(response.data);
		return document.querySelectorAll('#menu a[data-linktype="imageboard"]').map((e) => ImageboardBoard(
			name: e.attributes['data-short']!,
			title: e.attributes['title']!,
			isWorksafe: false,
			webmAudioAllowed: true,
			maxImageSizeBytes: 6000000,
			maxWebmSizeBytes: 6000000
		)).toList();
	}

	@override
	Future<CaptchaRequest> getCaptchaRequest(String board, int? threadId, {CancelToken? cancelToken}) async {
		return Recaptcha3Request(
			sourceUrl: getWebUrlImpl(board, threadId),
			key: captchaKey,
			action: 'add_post'
		);
	}

	static final _relativeSrcPattern = RegExp(r' src="/');
	String _fixRelativeUrls(String html) {
		return html.replaceAllMapped(_relativeSrcPattern, (match) {
			return ' src="https://$baseUrl/';
		});
	}

	Thread _makeThread(String board, Uri uri, dom.Element element, {int? page}) {
		final threadId = int.parse(element.id.substring(1)); // Like "t12345"
		final posts = element.querySelectorAll('.post').map((e) {
			bool attachmentDeleted = false;
			final attachments = <Attachment>[];
			for (final f in e.querySelectorAll('.file')) {
				final fileThumb = f.querySelector('a.fileThumb')!;
				final relativeThumbSrc = fileThumb.querySelector('img')?.attributes['src'];
				final fileInfoText = f.querySelector('.fileText')?.text.trim();
				final fileMatch = _fileInfoPattern.firstMatch(fileInfoText ?? '');
				if (relativeThumbSrc != null && fileMatch != null) {
					final imageUri = uri.resolve(fileThumb.attributes['href']!);
					final ext = imageUri.pathSegments.last.split('.').last;
					attachments.add(Attachment(
						type: switch (ext) {
							'webm' => AttachmentType.webm,
							'mp4' => AttachmentType.mp4,
							_ => AttachmentType.image
						},
						board: board,
						threadId: threadId,
						id: relativeThumbSrc,
						ext: '.$ext',
						width: int.parse(fileMatch.group(3)!),
						height: int.parse(fileMatch.group(4)!),
						sizeInBytes: (double.parse(fileMatch.group(1)!) * switch (fileMatch.group(2)) {
							'K' => 1000,
							'M' => 1000000,
							'B' || _ => 1
						}).round(),
						filename: fileMatch.group(5)!,
						md5: '',
						url: imageUri.toString(),
						thumbnailUrl: uri.resolve(relativeThumbSrc).toString()
					));
				}
				else {
					final iframeUrl = f.querySelector('iframe')?.attributes['src'];
					if (iframeUrl != null) {
						attachments.add(Attachment(
						type: AttachmentType.url,
						board: board,
						threadId: threadId,
						id: iframeUrl,
						ext: '',
						width: null,
						height: null,
						sizeInBytes: null,
						filename: '',
						md5: '',
						url: iframeUrl,
						thumbnailUrl: generateThumbnailerForUrl(Uri.parse(iframeUrl)).toString()
					));
					}
					else {
						attachmentDeleted = true;
					}
				}
			}
			String? posterId = e.querySelector('.postInfo .posteruid')?.text;
			if (posterId != null && posterId.startsWith('(ID:') && posterId.endsWith(')')) {
				posterId = posterId.substring(4, posterId.length - 1).trim();
			}
			return Post(
				board: board,
				threadId: threadId,
				id: int.parse(e.id.substring(1)), // Like "p12345"
				text: _fixRelativeUrls(e.querySelector('.postMessage')!.innerHtml),
				name: e.querySelector('.postInfo .name')!.text,
				posterId: posterId,
				time: DateTime.fromMillisecondsSinceEpoch(1000 * int.parse(e.querySelector('.postInfo .dateTime')!.attributes['data-raw']!)),
				spanFormat: PostSpanFormat.karachan,
				attachmentDeleted: attachmentDeleted,
				attachments_: attachments
			);
		}).toList();
		return Thread(
			board: board,
			id: threadId,
			posts_: posts,
			replyCount: switch (element.querySelector('span.summary')) {
				null => posts.length - 1, // on thread page or no omitted in catalog
				dom.Element e => (posts.length - 1) + int.parse(e.text.trim().split(' ').first) // Text like "250 omitted replies"
			},
			imageCount: 0,
			title: element.querySelector('.postInfo .subject')?.text.nonEmptyOrNull,
			time: posts.first.time,
			attachments: posts.first.attachments_,
			currentPage: page,
			isSticky: element.classes.contains('sticky')
		);
	}

	Future<List<Thread>> _getCatalogPage(String board, int page, {required RequestPriority priority, CancelToken? cancelToken}) async {
		final uri = Uri.https(baseUrl, page == 1 ? '/$board/' : '/$board/${page - 1}.html');
		final response = await client.getUri(
			uri,
			options: Options(
				extra: {
					kPriority: priority
				},
				responseType: ResponseType.plain
			),
			cancelToken: cancelToken
		);
		final document = parse(response.data);
		return document.querySelectorAll('.thread').map((e) {
			return _makeThread(board, uri, e, page: page);
		}).toList();
	}

	@override
	Future<List<Thread>> getCatalogImpl(String board, {CatalogVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) async {
		return await _getCatalogPage(board, 1, priority: priority, cancelToken: cancelToken);
	}

	@override
	Future<List<Thread>> getMoreCatalogImpl(String board, Thread after, {CatalogVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) async {
		return await _getCatalogPage(board, (after.currentPage ?? 0) + 1, priority: priority, cancelToken: cancelToken);
	}

	@override
	Future<Map<int, int>> getCatalogPageMapImpl(String board, {CatalogVariant? variant, required RequestPriority priority, DateTime? acceptCachedAfter, CancelToken? cancelToken}) async {
		final response = await client.getUri(
			Uri.https(baseUrl, '/$board/catalog.html'),
			options: Options(
				extra: {
					kPriority: priority
				},
				responseType: ResponseType.plain,
				validateStatus: (status) => status == 200 || status == 404
 			),
			cancelToken: cancelToken
		);
		if (response.statusCode == 404) {
			throw BoardNotFoundException(board);
		}
		final document = parse(response.data);
		const kThreadsPage = 10;
		return {
			for (final (i, e) in document.querySelectorAll('.thread').indexed)
				if (e.id.split('-').last.tryParseInt case int id)
					id: (i ~/ kThreadsPage) + 1
		};
	}

	static final _fileInfoPattern = RegExp(r'\((\d+(?:\.\d+)?)([KMB]), (\d+)x(\d+)(?: [^ ]+)?, (.+?)(?: \[i] \[g\])?\)');

	@override
	Future<Thread> getThreadImpl(ThreadIdentifier thread, {ThreadVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) async {
		final uri = Uri.https(baseUrl,'/${thread.board}/res/${thread.id}.html');
		final response = await client.getThreadUri(
			uri,
			priority: priority,
			responseType: ResponseType.plain,
			cancelToken: cancelToken
		);
		final document = parse(response.data);
		return _makeThread(thread.board, uri, document.querySelector('.thread')!);
	}

	@override
	String getWebUrlImpl(String board, [int? threadId, int? postId]) {
		if (postId != null) {
			return 'https://$baseUrl/$board/res/$threadId.html#p$postId';
		}
		if (threadId != null) {
			return 'https://$baseUrl/$board/res/$threadId.html';
		}
		return 'https://$baseUrl/$board/';
	}

	@override
	Uri? get iconUrl => Uri.https(baseUrl, '/favicon.ico');

	@override
	String get siteData => baseUrl;

	@override
	String get siteType => 'karachan';

	@override
	bool get hasPagedCatalog => true;

	@override
	bool get supportsPosting => true;

	@override
	Future<PostReceipt> submitPost(DraftPost post, CaptchaSolution captchaSolution, CancelToken cancelToken) async {
		final file = post.file;
		final password = makeRandomBase64String(8);
		final response = await client.postUri(
			Uri.https(baseUrl, '/imgboard.php'),
			data: FormData.fromMap({
				'mode': 'regist',
				'email': post.options ?? '',
				'sub': post.subject ?? '',
				'board': post.board,
				'resto': post.threadId?.toString() ?? '',
				'com': post.text,
				if (file != null) 'upfile': await MultipartFile.fromFile(file, filename: post.overrideFilename),
				'embed': '',
				'pwd': password,
				'format': 'json',
				if (captchaSolution is Recaptcha3Solution) 'captcha': captchaSolution.response
			}),
			options: Options(
				headers: {
					'accept': 'application/json, text/javascript, */*; q=0.01',
					'referer': getWebUrlImpl(post.board, post.threadId),
					'x-requested-with': 'XMLHttpRequest'
				},
				responseType: ResponseType.plain,
				extra: {
					kPriority: RequestPriority.interactive
				}
			),
			cancelToken: cancelToken
		);
		if (response.data is! String) {
			throw Exception('Bad response: ${response.data}');
		}
		final data = jsonDecode(response.data as String);
		final postid = data['postid'] as int?;
		if (postid == null) {
			throw Exception('${data['title']}: ${parseFragment(data['msg']).text}');
		}
		return PostReceipt(
			id: postid,
			password: password,
			name: post.name ?? '',
			options: post.options ?? '',
			time: DateTime.now(),
			post: post
		);
	}

	@override
	List<ImageboardSnippet> getBoardSnippets(String board) => const [
		greentextSnippet,
		ImageboardSnippet.simple(
			icon: CupertinoIcons.bold,
			name: 'Bold',
			start: '[b]',
			end: '[/b]',
			previewBuilder: SnippetPreviewBuilders.bold
		),
		ImageboardSnippet.simple(
			icon: CupertinoIcons.italic,
			name: 'Italic',
			start: '[i]',
			end: '[/i]',
			previewBuilder: SnippetPreviewBuilders.italic
		),
		ImageboardSnippet.simple(
			icon: CupertinoIcons.underline,
			name: 'Underline',
			start: '[u]',
			end: '[/u]',
			previewBuilder: SnippetPreviewBuilders.underline
		),
		ImageboardSnippet.simple(
			icon: CupertinoIcons.chevron_left_slash_chevron_right,
			name: 'Code',
			start: '[code]',
			end: '[/code]',
			previewBuilder: PostCodeSpan.new
		),
		ImageboardSnippet.simple(
			icon: CupertinoIcons.eye_slash,
			name: 'Spoiler',
			start: '[s]',
			end: '[/s]'
		)
	];

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is SiteKarachan &&
		other.baseUrl == baseUrl &&
		other.name == name &&
		other.captchaKey == captchaKey &&
		other.defaultUsername == defaultUsername &&
		super==(other);
	
	@override
	int get hashCode => baseUrl.hashCode;
}

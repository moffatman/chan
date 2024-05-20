import 'dart:io';

import 'package:chan/models/attachment.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/thumbnailer.dart';
import 'package:chan/sites/4chan.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/lainchan.dart';
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

	static const _kCookie = 'regulamin=accepted';

	@override
	Map<String, String> getHeaders(Uri url) {
		return super.getHeaders(url)..update(
			'cookie',
			(cookies) => '$cookies; $_kCookie',
			ifAbsent: () => _kCookie
		);
	}

	SiteKarachan({
		required this.baseUrl,
		required this.name,
		this.defaultUsername = 'Anonymous'
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
					else if (node.localName == 'div' && node.classes.contains('backlink')) {
						// Junk, don't show
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
	Future<void> deletePost(String board, int threadId, PostReceipt receipt) {
		// TODO: implement deletePost
		throw UnimplementedError();
	}

	@override
	Future<List<ImageboardBoard>> getBoards({required RequestPriority priority}) async {
		final response = await client.getUri(Uri.https(baseUrl, '/search.php'), options: Options(
			extra: {
				kPriority: priority
			}
		));
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
	Future<CaptchaRequest> getCaptchaRequest(String board, [int? threadId]) async {
		return const NoCaptchaRequest();
	}

	Thread _makeThread(String board, Uri uri, dom.Element element, {int? page}) {
		final threadId = int.parse(element.id.substring(1)); // Like "t12345"
		final posts = element.querySelectorAll('.post').map((e) {
			bool attachmentDeleted = false;
			final attachments = <Attachment>[];
			for (final f in e.querySelectorAll('.file')) {
				final fileThumb = f.querySelector('a.fileThumb')!;
				final relativeThumbSrc = fileThumb.querySelector('img')!.attributes['src']!;
				final ext = uri.pathSegments.last.split('.').last;
				final fileInfoText = f.querySelector('.fileText')!.text.trim();
				final fileMatch = _fileInfoPattern.firstMatch(fileInfoText);
				if (fileMatch != null) {
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
						url: uri.resolve(fileThumb.attributes['href']!).toString(),
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
			return Post(
				board: board,
				threadId: threadId,
				id: int.parse(e.id.substring(1)), // Like "p12345"
				text: e.querySelector('.postMessage')!.innerHtml,
				name: e.querySelector('.postInfo .name')!.text,
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
			title: element.querySelector('.postInfo .subject')?.text,
			time: posts.first.time,
			attachments: posts.first.attachments_,
			currentPage: page,
			isSticky: element.classes.contains('sticky')
		);
	}

	Future<List<Thread>> _getCatalogPage(String board, int page, {required RequestPriority priority}) async {
		final uri = Uri.https(baseUrl, page == 1 ? '/$board/' : '/$board/${page - 1}.html');
		final response = await client.getUri(
			uri,
			options: Options(
				extra: {
					kPriority: priority
				}
			)
		);
		final document = parse(response.data);
		return document.querySelectorAll('.thread').map((e) {
			return _makeThread(board, uri, e, page: page);
		}).toList();
	}

	@override
	Future<List<Thread>> getCatalogImpl(String board, {CatalogVariant? variant, required RequestPriority priority}) async {
		return await _getCatalogPage(board, 1, priority: priority);
	}

	@override
	Future<List<Thread>> getMoreCatalogImpl(String board, Thread after, {CatalogVariant? variant, required RequestPriority priority}) async {
		return await _getCatalogPage(board, (after.currentPage ?? 0) + 1, priority: priority);
	}

	@override
	Future<Post> getPost(String board, int id, {required RequestPriority priority}) {
		throw UnimplementedError();
	}

	static final _fileInfoPattern = RegExp(r'\((\d+(?:\.\d+)?)([KMB]), (\d+)x(\d+)(?: [^ ]+)?, (.+?)(?: \[i] \[g\])?\)');

	@override
	Future<Thread> getThreadImpl(ThreadIdentifier thread, {ThreadVariant? variant, required RequestPriority priority}) async {
		final uri = Uri.https(baseUrl,'/${thread.board}/res/${thread.id}.html');
		final response = await client.getUri(
			uri,
			options: Options(
				extra: {
					kPriority: priority
				}
			)
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
	Uri get iconUrl => Uri.https(baseUrl, '/favicon.ico');

	@override
	String get siteData => baseUrl;

	@override
	String get siteType => 'karachan';

	@override
	bool get hasPagedCatalog => true;

	@override
	bool get supportsPosting => false;

	@override
	Future<PostReceipt> submitPost(DraftPost post, CaptchaSolution captchaSolution, CancelToken cancelToken) async {
		throw UnimplementedError();
		/*final file = post.file;
		final password = makeRandomBase64String(6); // todo: Verify this is 8 chars long
		final response = await client.postUri(Uri.https(baseUrl, '/imgboard.php'), data: FormData.fromMap({
			'board': post.board,
			if (post.threadId != null) 'resto': post.threadId.toString(),
			'email': post.options ?? '',
			if (post.subject != null) 'sub': post.subject,
			'com': post.text,
			if (file != null) 'upfile': await MultipartFile.fromFile(file, filename: post.overrideFilename),
			'pwd': password
		}));*/
	}

	static PostSpan _boldPreviewBuilder(String input) => PostBoldSpan(PostTextSpan(input));
	static PostSpan _italicPreviewBuilder(String input) => PostItalicSpan(PostTextSpan(input));
	static PostSpan _underlinePreviewBuilder(String input) => PostUnderlinedSpan(PostTextSpan(input));

	@override
	Iterable<ImageboardSnippet> getBoardSnippets(String board) sync* {
		yield greentextSnippet;
		yield const ImageboardSnippet.simple(
			icon: CupertinoIcons.bold,
			name: 'Bold',
			start: '[b]',
			end: '[/b]',
			previewBuilder: _boldPreviewBuilder
		);
		yield const ImageboardSnippet.simple(
			icon: CupertinoIcons.italic,
			name: 'Italic',
			start: '[i]',
			end: '[/i]',
			previewBuilder: _italicPreviewBuilder
		);
		yield const ImageboardSnippet.simple(
			icon: CupertinoIcons.underline,
			name: 'Underline',
			start: '[u]',
			end: '[/u]',
			previewBuilder: _underlinePreviewBuilder
		);
		yield const ImageboardSnippet.simple(
			icon: CupertinoIcons.chevron_left_slash_chevron_right,
			name: 'Code',
			start: '[code]',
			end: '[/code]',
			previewBuilder: PostCodeSpan.new
		);
		yield const ImageboardSnippet.simple(
			icon: CupertinoIcons.eye_slash,
			name: 'Spoiler',
			start: '[s]',
			end: '[/s]'
		);
	}
}

import 'dart:convert';

import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/sites/4chan.dart';
import 'dart:io';

import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/util.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/util.dart';
import 'package:charset_converter/charset_converter.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;

final _timePattern = RegExp(r'^(\d+)\/(\d+)\/(\d+)\([^)]+\)(\d+):(\d+):(\d+)');
final _idPattern = RegExp(r'^No\.(\d+)$');
final _idRemapPattern = RegExp(r'^(>*)No\.(\d+)$');
final _filesizePattern = RegExp(r'^-\((\d+) B\) *$');

Future<dom.Document> parse(Uint8List html, {bool workaroundApplied = false}) async {
	String converted;
	try {
		converted = await CharsetConverter.decode(
			Platform.isAndroid ? 'Shift_JIS' : 'cp932',
			html
		);
	}
	on CharsetConversionError {
		if (!workaroundApplied) {
			for (int i = 0; i < html.length - 1; i++) {
				if (html[i] > 0x7F) {
					if (html[i] == 0xFC && html[i + 1] == 0xFC) {
						// Replace invalid sequence with question marks
						html[i] = 0x3F;
						html[i + 1] = 0x3F;
					}
					i++;
				}
			}
			return parse(html, workaroundApplied: true);
		}
		final context = ImageboardRegistry.instance.context;
		if (context != null && context.mounted) {
			showToast(
				context: context,
				message: 'Corrupt Shift-JIS text encoding',
				icon: CupertinoIcons.burst
			);
		}
		converted = utf8.decode(html, allowMalformed: true);
	}
	return parser.parse(converted);
}

class SiteFutaba extends ImageboardSite {
	@override
	final String name;
	@override
	final String baseUrl;

	final int maxUploadSizeBytes;

	SiteFutaba({
		required this.baseUrl,
		required this.name,
		required this.maxUploadSizeBytes,
		required super.overrideUserAgent,
		required super.archives,
		required super.imageHeaders,
		required super.videoHeaders
	});

	String boardDomain(String board) => persistence?.maybeGetBoard(board)?.subdomain ?? baseUrl;

	static PostNodeSpan makeSpan(String board, int threadId, String data) {
		final body = parser.parseFragment(data);
		final List<PostSpan> elements = [];
		int previousQuoteDestination = -1;
		bool skipNextLineBreak = false;
		for (final node in body.nodes) {
			if (node is dom.Element) {
				if (node.localName == 'font') {
					if (node.attributes['target'] != null) {
						final thisQuoteDestination = int.parse(node.attributes['target']!);
						if (thisQuoteDestination != previousQuoteDestination) {
							elements.add(PostQuoteLinkSpan(
								board: board,
								threadId: threadId,
								postId: thisQuoteDestination
							));
							elements.add(const PostLineBreakSpan());
						}
						if (node.attributes['d'] == 'true') {
							skipNextLineBreak = true;
						}
						else {
							elements.add(PostQuoteSpan(makeSpan(board, threadId, node.innerHtml)));
						}
						previousQuoteDestination = thisQuoteDestination;
					}
					else if (node.attributes['color'] == '#789922') {
						elements.add(PostQuoteSpan(makeSpan(board, threadId, node.innerHtml)));
					}
					else {
						elements.add(PostBoldSpan(PostColorSpan(makeSpan(board, threadId, node.innerHtml), const Color.fromARGB(255, 255, 0, 0))));
					}
				}
				else if (node.localName == 'br') {
					if (skipNextLineBreak) {
						skipNextLineBreak = false;
					}
					else {
						elements.add(const PostLineBreakSpan());
					}
				}
				else if (node.localName == 'a') {
					elements.add(PostLinkSpan(node.attributes['href']!.replaceFirst(RegExp(r'^\/bin\/jump\.php\?'), ''), name: node.text.nonEmptyOrNull));
				}
				else {
					elements.add(PostTextSpan(node.outerHtml));
				}
			}
			else {
				elements.addAll(Site4Chan.parsePlaintext((node.text ?? '').replaceAllMapped(_idRemapPattern, (m) => '${m.group(1) ?? ''}>${m.group(2)!}')));
			}
		}
		return PostNodeSpan(elements.toList(growable: false));
	}

	@override
	Future<BoardThreadOrPostIdentifier?> decodeUrl(String url) async {
		final baseBaseUrl = RegExp(r'[^.]+\.[^.]+$').firstMatch(baseUrl)?.group(0);
		final pattern = RegExp(r'https?:\/\/(.*\.)?' + (baseBaseUrl ?? baseUrl).replaceAll('.', r'\.') + r'\/([^\/]+)\/((res\/(\d+)\.html?(#sd(\d+))?.*)|(index\.html?))?$');
		final match = pattern.firstMatch(url);
		if (match != null) {
			return BoardThreadOrPostIdentifier(Uri.decodeComponent(match.group(2)!), int.tryParse(match.group(5) ?? ''), int.tryParse(match.group(7) ?? ''));
		}
		return null;
	}

	@override
	String get defaultUsername => '名無し';

	@override
	Future<List<ImageboardBoard>> getBoards({required RequestPriority priority, CancelToken? cancelToken}) async {
		final response = await client.getUri(Uri.https(baseUrl, '/index2.html'), options: Options(
			responseType: ResponseType.bytes,
			extra: {
				kPriority: priority
			}
		), cancelToken: cancelToken);
		final document = await parse(Uint8List.fromList(response.data as List<int>));
		return document.querySelectorAll('td a').where((e) {
			return e.attributes['href']?.endsWith('futaba.htm') ?? false;
		}).map((e) {
			final urlParts = e.attributes['href']!.split('/');
			return ImageboardBoard(
				name: urlParts[urlParts.length - 2],
				title: e.text,
				isWorksafe: false,
				webmAudioAllowed: true,
				maxImageSizeBytes: maxUploadSizeBytes,
				maxWebmSizeBytes: maxUploadSizeBytes,
				subdomain: urlParts[urlParts.length - 3]
			);
		}).toList();
	}

	@override
	Future<CaptchaRequest> getCaptchaRequest(String board, int? threadId, {CancelToken? cancelToken}) async {
		return const NoCaptchaRequest();
	}

	Future<dom.Document> _getCatalogPage(String board, String page, {required RequestPriority priority, CancelToken? cancelToken}) async {
		final response = await client.getUri(Uri.https(boardDomain(board), '/$board/$page.htm'), options: Options(
			responseType: ResponseType.bytes,
			validateStatus: (status) => status == 200 || status == 404,
			extra: {
				kPriority: priority
			}
		), cancelToken: cancelToken);
		if (response.statusCode == 404) {
			throw BoardNotFoundException(board);
		}
		return await parse(Uint8List.fromList(response.data as List<int>));
	}

	@override
	Future<List<Thread>> getCatalogImpl(String board, {CatalogVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) async {
		final doc0 = await _getCatalogPage(board, 'futaba', priority: priority, cancelToken: cancelToken);
		return doc0.querySelectorAll('.thre').map((e) => _makeThread(e, board)..currentPage = 0).toList();
	}

	@override
	Future<List<Thread>> getMoreCatalogImpl(String board, Thread after, {CatalogVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) async {
		try {
			final pageNumber = (after.currentPage ?? 0) + 1;
			final doc = await _getCatalogPage(board, pageNumber.toString(), priority: priority, cancelToken: cancelToken);
			return doc.querySelectorAll('.thre').map((e) => _makeThread(e, board)..currentPage = pageNumber).toList();
		}
		on BoardNotFoundException {
			return [];
		}
	}

	Post _makePost(dom.Element element, String board, int threadId, List<Post> precedingPosts) {
		// Futaba has implicit quotes, need to find the text in previous posts in thread.
		final blockquote = element.querySelector('blockquote')!;
		for (final child in blockquote.children) {
			if (child.localName == 'font' && child.attributes['color'] == '#789922') {
				String withoutArrow = child.innerHtml;
				do {
					withoutArrow = withoutArrow.substring(4).trim();
					final idMatch = _idPattern.firstMatch(withoutArrow);
					if (idMatch != null) {
						child.attributes['target'] = idMatch.group(1)!;
						child.attributes['d'] = 'true';
						continue;
					}
					for (final post in precedingPosts) {
						if (post.text.contains(withoutArrow) || post.attachments.any((a) => a.filename == withoutArrow)) {
							child.attributes['target'] = post.id.toString();
							break;
						}
					}
				} while(child.attributes['target'] == null && withoutArrow.startsWith('&gt;'));
			}
		}
		final timeString = element.querySelector('.cnw')?.text;
		final timeMatch = _timePattern.firstMatch(timeString ?? '');
		if (timeMatch == null) {
			throw FormatException('Bad time format', timeString);
		}
		String? filename;
		int? filesize;
		String? fileUrl;
		String? fileThumbnailUrl;
		Attachment? attachment;
		for (final child in element.nodes) {
			if (child is dom.Text) {
				final filesizeMatch = _filesizePattern.firstMatch(child.text);
				if (filesizeMatch != null) {
					filesize = int.parse(filesizeMatch.group(1)!);
				}
			}
			else if (child is dom.Element && child.localName == 'a' && (child.attributes['href']?.startsWith('/$board/') ?? false)) {
				if (child.firstChild is dom.Text) {
					filename = child.firstChild!.text;
				}
				else if (child.firstChild is dom.Element && (child.firstChild as dom.Element).localName == 'img') {
					fileUrl = child.attributes['href'];
					fileThumbnailUrl = child.firstChild!.attributes['src'];
				}
			}
		}
		if (filename != null && filesize != null && fileUrl != null && fileThumbnailUrl != null) {
			final ext = fileUrl.split('.').last;
			final type = ext == 'webm' ? AttachmentType.webm : (ext == 'mp4' ? AttachmentType.mp4 : AttachmentType.image);
			attachment = Attachment(
				type: type,
				board: board,
				threadId: threadId,
				id: fileUrl.split('/').last.split('.').first,
				ext: '.$ext',
				filename: filename,
				url: Uri.https(boardDomain(board), fileUrl).toString(),
				thumbnailUrl: Uri.https(boardDomain(board), fileThumbnailUrl).toString(),
				md5: '', // no md5 provided by fuutaba
				width: null,
				height: null,
				sizeInBytes: filesize
			);
		}
		return Post(
			board: board,
			threadId: threadId,
			id: int.parse(_idPattern.firstMatch(element.querySelector('.cno')!.text)!.group(1)!),
			spanFormat: PostSpanFormat.futaba,
			text: blockquote.innerHtml,
			name: element.querySelector('.cnm')!.text,
			time: DateTime(
				2000 + int.parse(timeMatch.group(1)!),
				int.parse(timeMatch.group(2)!),
				int.parse(timeMatch.group(3)!),
				int.parse(timeMatch.group(4)!),
				int.parse(timeMatch.group(5)!),
				int.parse(timeMatch.group(6)!)
			),
			attachments_: attachment == null ? [] : [attachment]
		);
	}

	Thread _makeThread(dom.Element element, String board) {
		final threadId = int.parse(element.attributes['data-res']!);
		final posts = <Post>[_makePost(element, board, threadId, [])];
		for (final e in element.querySelectorAll('.rtd')) {
			posts.add(_makePost(e, board, threadId, posts));
		}
		return Thread(
			board: board,
			id: threadId,
			posts_: posts,
			replyCount: posts.length - 1,
			imageCount: posts.skip(1).expand((r) => r.attachments).length,
			title: element.querySelector('.csb')?.text,
			isSticky: false,
			time: posts.first.time,
			attachments: posts.first.attachments_,
		);
	}

	@override
	Future<Thread> getThreadImpl(ThreadIdentifier thread, {ThreadVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) async {
		final response = await client.getThreadUri(Uri.parse(getWebUrlImpl(thread.board, thread.id)), responseType: ResponseType.bytes, priority: priority, cancelToken: cancelToken);
		final document = await parse(Uint8List.fromList(response.data as List<int>));
		return _makeThread(document.querySelector('.thre')!, thread.board);

	}

	@override
	String getWebUrlImpl(String board, [int? threadId, int? postId]) {
		String webUrl = 'https://${boardDomain(board)}/$board/';
		if (threadId != null) {
			webUrl += 'res/$threadId.htm';
			if (postId != null) {
				webUrl += '#sd$postId';
			}
		}
		return webUrl;
	}

	@override
	Uri? get iconUrl => Uri.https(baseUrl, '/favicon.ico');

	@override
	Future<PostReceipt> submitPost(DraftPost post, CaptchaSolution captchaSolution, CancelToken cancelToken) async {
		throw UnimplementedError('2chan posting is not implemented');
	}

	@override
	String get siteData => baseUrl;

	@override
	String get siteType => 'futaba';

	@override
	bool get supportsPosting => false;

	@override
	bool get hasPagedCatalog => true;

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		(other is SiteFutaba) &&
		(other.baseUrl == baseUrl) &&
		(other.name == name) &&
		(other.maxUploadSizeBytes == maxUploadSizeBytes) &&
		super==(other);

	@override
	int get hashCode => baseUrl.hashCode;
}
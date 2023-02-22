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
import 'package:dio/dio.dart';
import 'package:html/parser.dart';
import 'package:html/dom.dart' as dom;

extension _Unescape on String? {
	String? get _unescaped => this == null ? null : unescape.convert(this!);
}

class SiteLynxchan extends ImageboardSite {
	@override
	final String name;
	@override
	final String baseUrl;
	final List<ImageboardBoard> boards;

	static PostNodeSpan makeSpan(String board, int threadId, String data) {
		final body = parseFragment(data);
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
							postId: int.parse(match.group(3)!),
							dead: false
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
		return PostNodeSpan(elements);
	}

	SiteLynxchan({
		required this.name,
		required this.baseUrl,
		required this.boards,
		List<ImageboardSiteArchive> archives = const []
	}) : super(archives);

	ImageboardFlag? _makeFlag(Map<String, dynamic> data) {
		if (data['flag'] != null) {
			return ImageboardFlag(
				name: data['flagName'],
				imageUrl: Uri.https(baseUrl, data['flag']).toString(),
				imageWidth: 16,
				imageHeight: 11
			);
		}
		return null;
	}

	@override
	Future<PostReceipt> createThread({required String board, String name = '', String options = '', String subject = '', required String text, required CaptchaSolution captchaSolution, File? file, bool? spoiler, String? overrideFilename, ImageboardBoardFlag? flag}) {
		// TODO: implement createThread
		throw UnimplementedError();
	}

	@override
	Future<BoardThreadOrPostIdentifier?> decodeUrl(String url) async {
		return SiteLainchan.decodeGenericUrl(baseUrl, url);
	}

	@override
	String get defaultUsername => 'Anon';

	@override
	Future<void> deletePost(String board, PostReceipt receipt) {
		// TODO: implement deletePost
		throw UnimplementedError();
	}

	@override
	Future<List<ImageboardBoard>> getBoards() async {
		return boards;
	}

	@override
	Future<CaptchaRequest> getCaptchaRequest(String board, [int? threadId]) async {
		// TODO: implement getCaptchaRequest
		return NoCaptchaRequest();
	}

	void _updateBoardInformation(Map<String, dynamic> data) async {
		try {
			final board = persistence.boards[data['boardName']]!;
			board.maxCommentCharacters = data['maxMessageLength'];
			final fileSizeParts = (data['maxFileSize'] as String).split(' ');
			double maxFileSize = double.parse(fileSizeParts.first);
			if (fileSizeParts[1].toLowerCase().startsWith('M')) {
				maxFileSize *= 1024 * 1024;
			}
			else if (fileSizeParts[1].toLowerCase().startsWith('K')) {
				maxFileSize *= 1024;
			}
			else {
				throw Exception('Unexpected file-size unit: ${fileSizeParts[1]}');
			}
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

	Future<List<Thread>> _getCatalogPage(String board, int page) async {
		final response = await client.getUri(Uri.https(baseUrl, '/$board/$page.json'), options: Options(
			validateStatus: (status) => status == 200 || status == 404
		));
		if (response.statusCode == 404) {
			throw BoardNotFoundException(board);
		}
		_updateBoardInformation(response.data);
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
					url: Uri.https(baseUrl, f['path']),
					thumbnailUrl: Uri.https(baseUrl, f['thumb']),
					md5: '',
					width: f['width'],
					height: f['height'],
					threadId: obj['threadId'],
					sizeInBytes: f['size']
				)).toList()
			);
			return Thread(
				posts_: [op],
				replyCount: (obj['omittedPosts'] ?? 0) + (obj['posts'] as List).length,
				imageCount: (obj['omittedFiles'] ?? 0) + (obj['posts'] as List).fold<int>(0, (c, p) => c + (p['files'] as List).length),
				id: op.id,
				board: board,
				title: (obj['subject'] as String?)?._unescaped,
				isSticky: obj['pinned'],
				time: DateTime.parse(obj['creation']),
				attachments: op.attachments,
				currentPage: page
			);
		}).toList();
	}


	@override
	Future<List<Thread>> getCatalogImpl(String board, {CatalogVariant? variant}) async {
		return _getCatalogPage(board, 1);
	}

	@override
	Future<List<Thread>> getMoreCatalog(Thread after, {CatalogVariant? variant}) async {
		try {
			return _getCatalogPage(after.board, (after.currentPage ?? 0) + 1);
		}
		on BoardNotFoundException {
			return [];
		}
	}

	@override
	Future<Post> getPost(String board, int id) {
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
			id: id,
			spanFormat: PostSpanFormat.lynxchan,
			attachments: (obj['files'] as List).map((f) => Attachment(
				type: AttachmentType.fromFilename(f['path']),
				board: board,
				id: f['path'],
				ext: '.${(f['path'] as String).split('.').last}',
				filename: f['originalName'],
				url: Uri.https(baseUrl, f['path']),
				thumbnailUrl: Uri.https(baseUrl, f['thumb']),
				md5: '',
				width: f['width'],
				height: f['height'],
				threadId: obj['threadId'],
				sizeInBytes: f['size']
			)).toList()
		);
	}

	@override
	Future<Thread> getThread(ThreadIdentifier thread, {ThreadVariant? variant}) async {
		final response = await client.getUri(Uri.https(baseUrl, '/${thread.board}/res/${thread.id}.json'), options: Options(
			validateStatus: (status) => status == 200 || status == 404
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
			title: (response.data['subject'] as String?)?._unescaped,
			isSticky: response.data['pinned'],
			time: op.time,
			attachments: op.attachments,
			isArchived: response.data['archived'],
			flag: op.flag
		);
	}

	@override
	String getWebUrl(String board, [int? threadId, int? postId]) {
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
	Future<PostReceipt> postReply({required ThreadIdentifier thread, String name = '', String options = '', required String text, required CaptchaSolution captchaSolution, File? file, bool? spoiler, String? overrideFilename, ImageboardBoardFlag? flag}) {
		// TODO: implement postReply
		throw UnimplementedError();
	}

	@override
	String get siteData => baseUrl;

	@override
	String get siteType => 'lynxchan';

	@override
	bool get hasPagedCatalog => true;

	@override
	bool get supportsPosting => false;
}
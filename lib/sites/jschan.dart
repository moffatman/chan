import 'package:chan/models/attachment.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/media.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/4chan.dart';
import 'package:chan/sites/helpers/http_304.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/lainchan.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart';

class SiteJsChan extends ImageboardSite with Http304CachingThreadMixin, Http304CachingCatalogMixin, DecodeGenericUrlMixin {
	@override
	final String baseUrl;
	@override
	final String? imageUrl;
	@override
	final String name;
	@override
	final String defaultUsername;
	final String faviconPath;
	final String postingCaptcha;
	final String deletingCaptcha;
	final String bypassCaptcha;
	final String? gridCaptchaQuestion;
	final String? textCaptchaQuestion;

	SiteJsChan({
		required this.baseUrl,
		required this.name,
		required this.imageUrl,
		this.defaultUsername = 'Anonymous',
		required this.faviconPath,
		required super.overrideUserAgent,
		required super.archives,
		required super.imageHeaders,
		required super.videoHeaders,
		required this.postingCaptcha,
		required this.deletingCaptcha,
		required this.bypassCaptcha,
		required this.gridCaptchaQuestion,
		required this.textCaptchaQuestion
	});

	static final _quoteLinkHrefPattern = RegExp(r'/([^/]+)/thread/(\d+)\.html(?:#(\d+))?$');

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
					else if (node.localName == 'a' && node.classes.contains('quote')) {
						final match = _quoteLinkHrefPattern.firstMatch(node.attributes['href'] ?? '');
						if (match != null) {
							final threadId = match.group(2)!.parseInt;
							yield PostQuoteLinkSpan(
								board: match.group(1)!,
								threadId: threadId,
								postId: match.group(3)?.tryParseInt ?? threadId
							);
						}
						else {
							// Something went wrong
							yield PostTextSpan(node.outerHtml);
						}
					}
					else if (node.localName == 'a') {
						yield PostLinkSpan(node.attributes['href']!, name: node.text.nonEmptyOrNull);
					}
					else if (node.localName == 'small' && node.text == '(OP)') {
						// Do nothing, Chance handles adding "(OP)"
					}
					else if (node.localName == 'span' && node.classes.contains('greentext')) {
						yield PostQuoteSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)));
					}
					else if (node.localName == 'span' && node.classes.contains('pinktext') || node.classes.contains('dice')) {
						yield PostPinkQuoteSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)));
					}
					else if (node.localName == 'span' && node.classes.contains('detected')) {
						yield PostSpoilerSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)), spoilerSpanId++, forceReveal: true);
					}
					else if (node.localName == 'span' && node.classes.contains('strike')) {
						yield PostStrikethroughSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)));
					}
					else if (node.localName == 'span' && node.classes.contains('bold')) {
						yield PostBoldSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)));
					}
					else if (node.localName == 'span' && node.classes.contains('em')) {
						yield PostItalicSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)));
					}
					else if (node.localName == 'span' && node.classes.contains('underline')) {
						yield PostUnderlinedSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)));
					}
					else if (node.localName == 'span' && node.classes.contains('spoiler')) {
						yield PostSpoilerSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)), spoilerSpanId++);
					}
					else if (node.localName == 'span' && node.classes.contains('title')) {
						yield PostSecondaryColorSpan(PostBoldSpan(PostNodeSpan(visit(node.nodes).toList(growable: false))));
					}
					else if (node.localName == 'span' && node.classes.contains('mono') || node.classes.contains('code')) {
						yield PostCodeSpan(node.text.trimRight());
					}
					else if (node.localName == 'span' && node.classes.contains('big')) {
						yield PostBigTextSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)));
					}
					else if (node.attributes['style'] case String style when node.localName == 'span' && style.isNotEmpty) {
						yield PostCssSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)), style);
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
					else if (node.attributes['src'] case String src when node.localName == 'img') {
						yield PostInlineImageSpan(
							src: src,
							width: node.attributes['width']?.parseInt ?? 16,
							height: node.attributes['height']?.parseInt ?? 16
						);
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
	@protected
	String get res => 'thread';

	Exception _makeException(Map data) {
		return Exception('${data['title']}: ${[
			data['error'] as String?,
			...(data['errors'] as List? ?? []),
			data['message'] as String?,
			...(data['messages'] as List? ?? []),
		].tryMap((m) => m?.toString()).join(', ')}');
	}

	@override
	Future<void> deletePost(ThreadIdentifier thread, PostReceipt receipt, CaptchaSolution captchaSolution, CancelToken cancelToken, {required bool imageOnly}) async {
		final response = await client.postUri(
			Uri.https(baseUrl, '/forms/board/${thread.board}/actions'),
			data: {
				'checkedposts': receipt.id.toString(),
				'hide_name': '1',
				if (imageOnly) 'unlink_file': '1'
				else 'delete': '1',
				'report_reason': '',
				'postpassword': receipt.password,
				if (captchaSolution is JsChanGridCaptchaSolution) 'captcha': captchaSolution.selected.toList()..sort()
				else if (captchaSolution is JsChanTextCaptchaSolution) 'captcha': captchaSolution.text
				else if (captchaSolution is HCaptchaSolution) 'captcha': captchaSolution.token
			},
			options: Options(
				headers: {
					'accept': '*/*',
					'referer': getWebUrlImpl(thread.board, thread.id),
					if (captchaSolution is JsChanCaptchaSolution) 'cookie': 'captchaid=${captchaSolution.id}'
				},
				extra: {
					kPriority: RequestPriority.interactive
				},
				contentType: Headers.formUrlEncodedContentType,
				validateStatus: (_) => true,
				responseType: null
			),
			cancelToken: cancelToken
		);
		String? title;
		if (response.data case Map map) {
			title = map['title'] as String?;
		}
		else if (response.data is String) {
			title = parse(response.data).querySelector('title')?.text;
		}
		if (title == null) {
			print(response.data);
			throw HTTPStatusException.fromResponse(response);
		}
		if (title != 'Success' && title != 'Sucesso') {
			if (response.data case Map map) {
				throw _makeException(map);
			}
			// HTML <title>
			throw DeletionFailedException(title);
		}
	}

	@override
	ImageboardBoardPopularityType? get boardPopularityType => ImageboardBoardPopularityType.postsCount;

	@override
	Future<List<ImageboardBoard>> getBoards({required RequestPriority priority, CancelToken? cancelToken}) async {
		final list = <ImageboardBoard>[];
		int page = 1;
		int maxPage = 1;
		while (page <= maxPage) {
			final response = await client.getUri<Map>(Uri.https(baseUrl, '/boards.json', {'page': page.toString()}), options: Options(
				responseType: ResponseType.json,
				headers: {
					'accept': '*/*',
					'cache-control': 'no-cache',
					'pragma': 'no-cache'
				},
				extra: {
					kPriority: priority
				}
			), cancelToken: cancelToken);
			page++;
			maxPage = response.data!['maxPage'] as int;
			list.addAll((response.data!['boards'] as List).cast<Map>().where((board) => board['webring'] != true).map((board) => ImageboardBoard(
				name: board['_id'] as String,
				title: (board['settings'] as Map)['name'] as String,
				isWorksafe: (board['settings'] as Map)['sfw'] as bool,
				webmAudioAllowed: true,
				maxImageSizeBytes: 16000000,
				maxWebmSizeBytes: 16000000,
				popularity: board['sequence_value'] as int?
			)));
			// The server has some bad caching, you will keep getting the same page if you don't wait
			if (cancelToken != null) {
				await cancelToken.sleep(const Duration(seconds: 2));
			}
			else {
				await Future.delayed(const Duration(seconds: 2));
			}
		}
		return list;
	}

	CaptchaRequest _getCaptcha(String type) {
		if (type == 'none') {
			return const NoCaptchaRequest();
		}
		if (type.startsWith('hcaptcha:')) {
			final parts = type.split(':');
			return HCaptchaRequest(hostPage: Uri.https(baseUrl, '/robots.txt'), siteKey: parts[1]);
		}
		return JsChanCaptchaRequest(challengeUrl: Uri.https(baseUrl, '/captcha'), type: type, question: switch (type) {
			'grid' => gridCaptchaQuestion ?? 'Select the solid/filled icons',
			'text' => textCaptchaQuestion ?? 'Enter the text in the image below',
			'none' => 'Verification not required',
			String other => 'Error: Unknown captcha type $other'
		});
	}

	@override
	Future<CaptchaRequest> getCaptchaRequest(String board, int? threadId, {CancelToken? cancelToken}) async => _getCaptcha(postingCaptcha);

	@override
	Future<CaptchaRequest> getDeleteCaptchaRequest(ThreadIdentifier thread, {CancelToken? cancelToken}) async => _getCaptcha(deletingCaptcha);

	Post _makePost(Map post) {
		final postId = post['postId'] as int;
		final threadId = post['thread'] as int? ?? postId /* op */;
		return Post(
			id: postId,
			threadId: threadId,
			capcode: (post['capcode'] as String?)?.replaceFirst('## ', ''),
			board: post['board'] as String,
			text: post['message'] as String? ?? '',
			name: post['name'] as String,
			posterId: post['userId'] as String?,
			time: DateTime.fromMillisecondsSinceEpoch(post['u'] as int),
			spanFormat: PostSpanFormat.jsChan,
			attachments_: (post['files'] as List).cast<Map>().map((file) {
				final sizeParts = (file['geometryString'] as String?)?.split('x');
				final width = sizeParts?[0].tryParseInt;
				final height = sizeParts?[1].tryParseInt;
				return Attachment(
					type: switch (file['extension']) {
						'.webm' => AttachmentType.webm,
						'.mp4' => AttachmentType.mp4,
						'.mp3' => AttachmentType.mp3,
						_ => AttachmentType.image
					},
					md5: file['hash'] as String,
					ext: file['extension'] as String,
					board: post['board'] as String,
					id: file['filename'] as String,
					filename: file['originalFilename'] as String,
					url: Uri.https(baseUrl, '/file/${file['hash']}${file['extension']}').toString(),
					thumbnailUrl: Uri.https(baseUrl, '/file/thumb/${file['hash']}${file['thumbextension']}').toString(),
					width: width,
					height: height,
					threadId: threadId,
					sizeInBytes: file['size'] as int?
				);
			}).toList()
		);
	}

	Thread _makeThread(Map thread) {
		final op = _makePost(thread);
		return Thread(
			board: op.board,
			id: op.threadId,
			replyCount: thread['replyposts'] as int,
			imageCount: thread['replyfiles'] as int,
			title: (thread['subject'] as String?)?.nonEmptyOrNull,
			isSticky: thread['sticky'] != 0,
			time: op.time,
			attachments: op.attachments_,
			posts_: [
				op,
				...(thread['replies'] as List? ?? []).cast<Map>().map(_makePost)
			]
		);
	}

	@override
	RequestOptions getCatalogRequest(String board, {CatalogVariant? variant})
		=> RequestOptions(
			baseUrl: 'https://$baseUrl',
			path: '/$board/catalog.json',
			responseType: ResponseType.json
		);

	@override
	Future<List<Thread>> makeCatalog(String board, Response response, {CatalogVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) async {
		return (response.data as List).cast<Map>().map(_makeThread).toList();
	}

	@override
	RequestOptions getThreadRequest(ThreadIdentifier thread, {ThreadVariant? variant})
		=> RequestOptions(
			path: '/${thread.board}/thread/${thread.id}.json',
			baseUrl: 'https://$baseUrl',
			responseType: ResponseType.json
		);

	@override
	Future<Thread> makeThread(ThreadIdentifier thread, Response response, {
		ThreadVariant? variant,
		required RequestPriority priority,
		CancelToken? cancelToken
	}) async => _makeThread(response.data as Map);

	@override
	String getWebUrlImpl(String board, [int? threadId, int? postId]) {
		if (postId != null) {
			return 'https://$baseUrl/$board/thread/$threadId.html#$postId';
		}
		if (threadId != null) {
			return 'https://$baseUrl/$board/thread/$threadId.html';
		}
		return 'https://$baseUrl/$board/';
	}

	@override
	Uri? get iconUrl => Uri.https(baseUrl, faviconPath);

	@override
	String get siteData => baseUrl;

	@override
	String get siteType => 'jschan';

	@override
	bool get supportsPosting => true;

	@override
	Future<PostReceipt> submitPost(DraftPost post, CaptchaSolution captchaSolution, CancelToken cancelToken) async {
		final password = makeRandomBase64String(28);
		final file = post.file;
		final response = await client.postUri<Map>(
			Uri.https(baseUrl, '/forms/board/${post.board}/post'),
			data: FormData.fromMap({
				'thread': post.threadId?.toString(),
				'name': post.name ?? '',
				'email': post.options ?? '',
				if (post.subject != null) 'subject': post.subject,
				'message': post.text,
				'postpassword': password,
				if (file != null) 'file': await MultipartFile.fromFile(
					file,
					filename: post.overrideFilename,
					contentType: MediaScan.guessMimeTypeFromPath(file)
				),
				if (captchaSolution is JsChanGridCaptchaSolution) 'captcha': captchaSolution.selected.toList()..sort()
				else if (captchaSolution is JsChanTextCaptchaSolution) 'captcha': captchaSolution.text
			}),
			options: Options(
				headers: {
					'accept': '*/*',
					'referer': getWebUrlImpl(post.board, post.threadId),
					if (captchaSolution is JsChanCaptchaSolution) 'cookie': 'captchaid=${captchaSolution.id}',
					'x-using-xhr': true
				},
				extra: {
					kPriority: RequestPriority.interactive
				},
				responseType: ResponseType.json,
				validateStatus: (_) => true
			),
			cancelToken: cancelToken
		);
		if (response.data is! Map) {
			throw HTTPStatusException.fromResponse(response);
		}
		final postId = response.data?['postId'] as int?;
		if (postId != null) {
			return PostReceipt(
				id: postId,
				password: password,
				name: post.name ?? '',
				options: post.options ?? '',
				time: DateTime.now(),
				post: post
			);
		}
		if (response.data case {'message': String message, 'link': {'href': String href}} when message.contains('bypass')) {
			throw AdditionalCaptchaRequiredException(captchaRequest: _getCaptcha(bypassCaptcha), onSolved: (captchaSolution2, cancelToken) async {
				await client.postUri(Uri.https(baseUrl, '/forms/blockbypass'), data: {
					if (captchaSolution2 is JsChanGridCaptchaSolution) 'captcha': captchaSolution2.selected.toList()..sort()
					else if (captchaSolution2 is JsChanTextCaptchaSolution) 'captcha': captchaSolution2.text
				}, options: Options(
					followRedirects: false, // To catch the 302 cookie
					contentType: Headers.formUrlEncodedContentType,
					headers: {
						'origin': 'https://$baseUrl',
						'referer': Uri.parse(getWebUrlImpl(post.board, post.threadId)).resolve(href).toString(),
						if (captchaSolution2 is JsChanCaptchaSolution) 'cookie': 'captchaid=${captchaSolution2.id}'
					}
				), cancelToken: cancelToken);
			});
		}
		throw _makeException(response.data!);
	}

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is SiteJsChan &&
		other.baseUrl == baseUrl &&
		other.name == name &&
		other.imageUrl == imageUrl &&
		other.defaultUsername == defaultUsername &&
		other.faviconPath == faviconPath &&
		postingCaptcha == other.postingCaptcha &&
		deletingCaptcha == other.deletingCaptcha &&
		bypassCaptcha == other.bypassCaptcha &&
		gridCaptchaQuestion == other.gridCaptchaQuestion &&
		textCaptchaQuestion == other.textCaptchaQuestion &&
		super==(other);
	
	@override
	int get hashCode => baseUrl.hashCode;
}
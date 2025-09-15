import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:chan/models/attachment.dart';
import 'package:chan/models/flag.dart';
import 'package:chan/services/captcha.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/linkifier.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/thumbnailer.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/helpers/http_304.dart';
import 'package:chan/sites/util.dart';
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

mixin DecodeGenericUrlMixin {
	String get baseUrl;
	@protected
	String get res;
	@protected
	String get basePath => '';
	Future<BoardThreadOrPostIdentifier?> decodeUrl(Uri url) async {
		if (url.host != baseUrl) {
			return null;
		}
		final p = url.pathSegments.where((s) => s.isNotEmpty).toList();
		if (basePath.isNotEmpty) {
			for (final part in basePath.split('/').where((s) => s.isNotEmpty)) {
				if (p.tryFirst != part) {
					return null;
				}
				p.removeAt(0);
			}
		}
		if (p.length == 3 && p[1] == res) {
			// "See last X replies" will have p[2] like 1234+50.html
			final plusDelimeter = p[2].indexOfOrLength('+');
			final dotDelimeter = p[2].indexOfOrLength('.htm');
			final threadId = int.tryParse(p[2].substring(0, min(plusDelimeter, dotDelimeter)));
			if (threadId != null) {
				return BoardThreadOrPostIdentifier(p[0], threadId, const ['', 'q', 'p'].tryMapOnce(url.fragment.extractPrefixedInt));
			}
		}
		if (p.length == 2 && (p[1] == 'index.html' || p[1] == 'catalog.html')) {
			return BoardThreadOrPostIdentifier(p[0]);
		}
		if (p.length == 1) {
			return BoardThreadOrPostIdentifier(p[0]);
		}
		return null;
	}
}

class SiteLainchan extends ImageboardSite with Http304CachingThreadMixin, Http304CachingCatalogMixin, DecodeGenericUrlMixin {
	@override
	final String baseUrl;
	String get sysUrl => baseUrl;
	@override
	final String? imageUrl;
	@override
	final String basePath;
	@override
	final String name;
	final int? maxUploadSizeBytes;
	final String? faviconPath;
	@override
	final String defaultUsername;
	final String? turnstileSiteKey;

	@override
	late final SiteLainchanLoginSystem loginSystem = SiteLainchanLoginSystem(this);

	SiteLainchan({
		required this.baseUrl,
		required this.name,
		required this.imageUrl,
		this.maxUploadSizeBytes,
		required super.overrideUserAgent,
		required super.archives,
		required super.imageHeaders,
		required super.videoHeaders,
		required this.turnstileSiteKey,
		this.faviconPath = '/favicon.ico',
		this.basePath = '',
		this.defaultUsername = 'Anonymous'
	});

	static List<PostSpan> parsePlaintext(String text) {
		return linkify(text, linkifiers: const [ChanceLinkifier(), LooseUrlLinkifier()], options: const LinkifyOptions(
			defaultToHttps: true
		)).map((elem) {
			if (elem is UrlElement) {
				return PostLinkSpan(elem.url, name: elem.text);
			}
			else {
				return PostTextSpan(elem.text);
			}
		}).toList();
	}

	static final _quoteLinkPattern = RegExp(r'\/([^\/]+)\/\/?(?:(?:res)|(?:thread))\/(\d+)(?:\.html)?#(\d+)');
	static final _inlineImageWithDimensionsInNamePattern = RegExp(r'(\d+)x(\d+)\.\w{1,5}$');

	static PostNodeSpan makeSpan(String board, int threadId, String data) {
		final body = parseFragment(
			data.replaceAll('<wbr>', '')
			.replaceAll('<em>//</em>', '//')
			.replaceAll('</a> <small>(OP)</small>', '</a>')
		);
		int spoilerSpanId = 0;
		Iterable<PostSpan> visit(Iterable<dom.Node> nodes) sync* {
			bool addLinebreakBefore = false;
			for (final node in nodes) {
				if (addLinebreakBefore) {
					yield const PostLineBreakSpan();
					addLinebreakBefore = false;
				}
				if (node is dom.Element) {
					if (node.localName == 'br') {
						yield const PostLineBreakSpan();
					}
					else if (node.localName == 'a' && node.attributes['href'] != null) {
						final match = _quoteLinkPattern.firstMatch(node.attributes['href']!);
						// Make sure this isn't just a link to another imageboard
						if (match != null && (Uri.tryParse(node.attributes['href']!)?.host.isEmpty ?? true)) {
							yield PostQuoteLinkSpan(
								board: match.group(1)!,
								threadId: int.parse(match.group(2)!),
								postId: int.parse(match.group(3)!)
							);
						}
						else {
							yield PostLinkSpan(node.attributes['href']!, name: node.text.nonEmptyOrNull);
						}
					}
					else if (node.localName == 'strong' || node.localName == 'b') {
						yield PostBoldSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)));
					}
					else if (node.localName == 'em') {
						yield PostItalicSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)));
					}
					else if (node.localName == 'u') {
						yield PostUnderlinedSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)));
					}
					else if (node.localName == 'span') {
						if (node.classes.contains('quote') || node.classes.contains('unkfunc')) {
							yield PostQuoteSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)));
						}
						else if (node.classes.contains('quote2') || node.classes.contains('rquote')) {
							yield PostPinkQuoteSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)));
						}
						else if (node.classes.contains('quote3')) {
							yield PostBlueQuoteSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)));
						}
						else if (node.classes.contains('u')) {
							yield PostUnderlinedSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)));
						}
						else if (node.classes.contains('o')) {
							yield PostOverlinedSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)));
						}
						else if (node.classes.contains('spoiler')) {
							yield PostSpoilerSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)), spoilerSpanId++);
						}
						else if (node.classes.contains('s')) {
							yield PostStrikethroughSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)));
						}
						else if (node.classes.contains('heading')) {
							yield PostBoldSpan(PostSecondaryColorSpan(PostNodeSpan(visit(node.nodes).toList(growable: false))));
						}
						else if (node.attributes['style'] case String style) {
							yield PostCssSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)), style);
						}
						else if (node.classes.contains('glow')) {
							yield PostCssSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)), 'text-shadow: 0px 0px 40px #00fe20, 0px 0px 2px #00fe20');
						}
						else {
							yield PostTextSpan(node.text);
						}
					}
					else if (node.localName == 'font' && node.attributes.containsKey('color')) {
						yield PostColorSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)), colorToHex(node.attributes['color']!));
					}
					else if (node.localName == 'p') {
						if (node.classes.contains('quote')) {
							yield PostQuoteSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)));
						}
						else {
							yield* visit(node.nodes);
						}
						yield const PostLineBreakSpan();
					}
					else if (node.localName == 'sup') {
						yield PostSuperscriptSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)));
					}
					else if (node.localName == 'sub') {
						yield PostSubscriptSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)));
					}
					else if (node.localName == 'pre') {
						yield PostCodeSpan(node.text.trim());
						yield const PostLineBreakSpan();
					}
					else if (node.localName == 'img' && node.attributes.containsKey('src')) {
						final src = node.attributes['src']!;
						// We may be able to extract the proper dimensions from URL
						final dimensionMatch = _inlineImageWithDimensionsInNamePattern.firstMatch(src);
						yield PostInlineImageSpan(
							src: src,
							width: dimensionMatch?.group(1)?.tryParseInt ?? 16,
							height: dimensionMatch?.group(2)?.tryParseInt ?? 16
						);
					}
					else if (node.localName == 'small') {
						yield PostSmallTextSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)));
					}
					else if (node.localName == 'big') {
						yield PostBigTextSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)));
					}
					else if (node.localName == 's') {
						int? deadId;
						if (node.classes.contains('dead-cite')) {
							final text = node.text;
							if (node.text.startsWith('>>')) {
								deadId = int.tryParse(text.substring(2));
							}
						}
						if (deadId != null) {
							yield PostQuoteLinkSpan.dead(board: board, postId: deadId);
						}
						else {
							yield PostStrikethroughSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)));
						}
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
								yield PostTextSpan(li.text);
								addLinebreakBefore = true;
								i++;
							}
						}
					}
					else if (node.localName == 'code') {
						yield PostMonospaceSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)));
					}
					else {
						yield PostTextSpan(node.outerHtml);
					}
				}
				else {
					yield* parsePlaintext(node.text ?? '');
				}
			}
		}
		return PostNodeSpan(visit(body.nodes).toList(growable: false));
	}

	@protected
	Uri getAttachmentUrl(String board, String filename) => Uri.https(baseUrl, '$basePath/$board/src/$filename');

	@protected
	Uri getThumbnailUrl(String board, String filename) => Uri.https(baseUrl, '$basePath/$board/thumb/$filename');

	@protected
	String getAttachmentId(int postId, String imageId, String source) => imageId;

	/// [null] means use same as full quality image
	/// [''] means it needs to be fetched from .html
	/// else, it is the extension, including the '.'
	@protected
	String? get imageThumbnailExtension => '.png';

	List<Attachment> _makeAttachments(String board, int threadId, Map postData) {
		final ret = <Attachment>[];
		Attachment? makeAttachment(Map data, String source) {
			final id = data['tim'] as String;
			final ext = data['ext'] as String;
			AttachmentType type = AttachmentType.image;
			if (ext == 'deleted') {
				return null;
			}
			else if (ext == '.webm') {
				type = AttachmentType.webm;
			}
			else if (ext == '.mp4' || ext == '.mov') {
				type = AttachmentType.mp4;
			}
			else if (ext == '.mp3' || ext == '.wav') {
				type = AttachmentType.mp3;
			}
			else if (ext == '.pdf') {
				type = AttachmentType.pdf;
			}
			return Attachment(
				id: getAttachmentId(postData['no'] as int, id, source),
				type: type,
				filename: unescape.convert(data['filename'] as String? ?? '') + ext,
				ext: ext,
				board: board,
				url: getAttachmentUrl(board, '$id$ext').toString(),
				thumbnailUrl: switch(data['thumb_path']) {
					String path => 'https://$baseUrl$path',
					_ => switch (data['thumb'] as String?) {
						'file' || null => (type == AttachmentType.mp3 || ext == '.mov' ? '' : getThumbnailUrl(board, '$id${type == AttachmentType.image ? (imageThumbnailExtension ?? ext) : '.jpg'}')).toString(),
						'spoiler' => '',
						String thumb => 'https://$baseUrl$basePath/$board/thumb/$thumb',
					}
				},
				md5: data['md5'] as String? ?? '',
				spoiler: data['spoiler'] == 1,
				width: data['w'] as int?,
				height: data['h'] as int?,
				threadId: threadId,
				sizeInBytes: data['fsize'] as int?
			);
		}
		if ((postData['tim'] as String?)?.isNotEmpty ?? false) {
			ret.maybeAdd(makeAttachment(postData, 'postData'));
			if (postData['extra_files'] != null) {
				for (final (i, extraFile) in (postData['extra_files'] as List).cast<Map>().indexed) {
					ret.maybeAdd(makeAttachment(extraFile, 'extraFile$i'));
				}
			}
		}
		final embed = postData['embed'] as String?;
		if (embed != null && embed.isNotEmpty) {
			final elem = parseFragment(embed);
			final href = elem.querySelector('a')?.attributes['href'] ?? elem.querySelector('iframe')?.attributes['src'];
			if (href != null) {
				ret.add(Attachment(
					type: AttachmentType.url,
					board: board,
					id: href,
					ext: '',
					filename: '',
					md5: '',
					width: null,
					height: null,
					threadId: threadId,
					sizeInBytes: null,
					url: href,
					thumbnailUrl: switch (elem.querySelector('img')?.attributes['src']) {
						null => generateThumbnailerForUrl(Uri.parse(href)).toString(),
						String t => Uri.parse(getWebUrlImpl(board, threadId)).resolve(t).toString()
					}
				));
			}
		}
		if (postData['files'] case List files) {
			ret.addAll(files.cast<Map>().indexed.tryMap((f) => makeAttachment(f.$2, 'file${f.$1}')));
		}
		return ret;
	}

	@protected
	ImageboardFlag? makeFlag(Map data) {
		if (data case {'country': String country, 'country_name': String countryName}) {
			return ImageboardFlag(
				name: countryName,
				imageUrl: Uri.https(baseUrl, '$basePath/static/flags/${country.toLowerCase()}.png').toString(),
				imageWidth: 16,
				imageHeight: 11
			);
		}
		return null;
	}

	Future<ImageboardPoll?> _getPoll1(ThreadIdentifier thread, {required RequestPriority priority, CancelToken? cancelToken}) async {
		try {
			final response = await client.postUri<String>(Uri.https(sysUrl, '$basePath/poll.php'), data: {
				'query_poll': '1',
				'id': thread.id.toString(),
				'board': thread.board
			}, options: Options(
				contentType: Headers.formUrlEncodedContentType,
				responseType: ResponseType.plain,
				extra: {
					kPriority: priority
				}
			), cancelToken: cancelToken);
			final data = jsonDecode(response.data!.trim()) as Map;
			final colors = (data['colors'] as List?)?.cast<String>();
			final question = (data['question'] as List).cast<Map>();
			final rows = <ImageboardPollRow>[];
			for (int i = 0; i < question.length; i++) {
				final entry = question[i].entries.trySingle;
				if (entry != null) {
					rows.add(ImageboardPollRow(
						name: entry.key as String,
						votes: entry.value as int,
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

	Future<ImageboardPoll?> _getPoll2(int id, {required RequestPriority priority, CancelToken? cancelToken}) async {
		try {
			final response = await client.postUri(Uri.https(sysUrl, '$basePath/poll.php', {
				'id': id.toString(),
				'results': ''
			}), options: Options(
				responseType: ResponseType.plain,
				extra: {
					kPriority: priority
				}
			), cancelToken: cancelToken);
			final document = parse(response.data);
			return ImageboardPoll(
				title: null,
				rows: document.querySelectorAll('ol li').map((e) => ImageboardPollRow(
					name: e.querySelector('span')!.text,
					votes: int.parse(e.querySelector('label')!.text.substring(1).beforeFirst(' '))
				)).toList()
			);
		}
		catch (e, st) {
			// Not fatal
			Future.error(e, st);
			return null;
		}
	}

	static final _pollFormPattern1 = RegExp(r'<div [^>]+class="pollform">.*<\\/div>(?:<br\\/>)?');
	static final _pollFormPattern2 = RegExp('<iframe [^>]+class="poll" src="/poll.php\\?id=(\\d+).*</iframe>(?:<br\\/>)?');

	Post _makePost(String board, int threadId, Map data) {
		final id = data['no'] as int;
		final String text;
		if (id == threadId) {
			// Only OP can have inline poll metadata
			text = (data['com'] as String? ?? '').replaceFirst(_pollFormPattern1, '').replaceFirst(_pollFormPattern2, '');
		}
		else {
			text = data['com'] as String? ?? '';
		}
		return Post(
			board: board,
			text: text,
			name: data['name'] as String? ?? '',
			time: DateTime.fromMillisecondsSinceEpoch((data['time'] as int) * 1000),
			id: id,
			threadId: threadId,
			attachments_: _makeAttachments(board, threadId, data),
			attachmentDeleted: data['filedeleted'] == 1 || data['ext'] == 'deleted',
			spanFormat: PostSpanFormat.lainchan,
			posterId: data['id'] as String?,
			flag: makeFlag(data),
			capcode: data['capcode'] as String?,
			email: data['email'] as String?
		);
	}

	@override
	@protected
	String get res => 'res';

	@override
	Future<Thread> makeThread(ThreadIdentifier thread, Response response, {
		ThreadVariant? variant,
		required RequestPriority priority,
		CancelToken? cancelToken
	}) async {
		if (response.redirects.tryLast?.location.pathSegments.tryLast?.startsWith('404.') ?? false) {
			throw const ThreadNotFoundException();
		}
		final data = response.data as Map;
		final firstPost = (data['posts'] as List)[0] as Map;
		final firstPostText = firstPost['com'] as String? ?? '';
		final ImageboardPoll? poll;
		if (_pollFormPattern2.firstMatch(firstPostText)?.group(1)?.tryParseInt case int id) {
			poll = await _getPoll2(id, priority: priority, cancelToken: cancelToken);
		}
		else if (_pollFormPattern1.hasMatch(firstPostText)) {
			poll = await _getPoll1(thread, priority: priority, cancelToken: cancelToken);
		}
		else {
			poll = null;
		}
		final List<Post> posts = (data['posts'] as List? ?? []).cast<Map>().map<Post>((postData) => _makePost(thread.board, thread.id, postData)).toList();
		return Thread(
			board: thread.board,
			id: thread.id,
			isSticky: firstPost['sticky'] == 1,
			title: (firstPost['sub'] as String?)?.unescapeHtml,
			attachmentDeleted: posts[0].attachmentDeleted,
			attachments: posts[0].attachments_,
			time: DateTime.fromMillisecondsSinceEpoch((firstPost['time'] as int) * 1000),
			replyCount: posts.length - 1,
			imageCount: posts.skip(1).expand((p) => p.attachments).length,
			posts_: posts,
			poll: poll
		);
	}

	@override
	RequestOptions getThreadRequest(ThreadIdentifier thread, {ThreadVariant? variant})
		=> RequestOptions(
			path: '$basePath/${thread.board}/$res/${thread.id}.json',
			baseUrl: 'https://$baseUrl',
			responseType: ResponseType.json
		);

	@override
	RequestOptions getCatalogRequest(String board, {CatalogVariant? variant})
		=> RequestOptions(
			baseUrl: 'https://$baseUrl',
			path: '$basePath/$board/catalog.json',
			responseType: ResponseType.json
		);

	@override
	Future<List<Thread>> makeCatalog(String board, Response response, {CatalogVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) async {
		final List<Thread> threads = [];
		for (final page in (response.data as List).cast<Map>()) {
			for (final threadData in (page['threads'] as List? ?? []).cast<Map>()) {
				final threadAsPost = _makePost(board, threadData['no'] as int, threadData);
				final currentPage = page['page'] as int?;
				final thread = Thread(
					board: board,
					id: threadAsPost.threadId,
					title: (threadData['sub'] as String?)?.unescapeHtml,
					posts_: [threadAsPost],
					attachmentDeleted: threadAsPost.attachmentDeleted,
					attachments: threadAsPost.attachments_,
					replyCount: threadData['replies'] as int,
					imageCount: ((threadData['images'] as int) + (threadData['omitted_images'] as int? ?? 0)),
					isSticky: threadData['sticky'] == 1,
					time: DateTime.fromMillisecondsSinceEpoch((threadData['time'] as int) * 1000),
					currentPage: currentPage == null ? null : currentPage + 1
					// Not fetching poll here, it will take too long. Just get it when the thread is opened
				);
				threads.add(thread);
			}
		}
		return threads;
	}

	@override
	Future<List<ImageboardBoard>> getBoards({required RequestPriority priority, CancelToken? cancelToken}) async {
		final response = await client.getUri<Map>(Uri.https(baseUrl, '$basePath/boards.json'), options: Options(
			responseType: ResponseType.json,
			extra: {
				kPriority: priority
			}
		), cancelToken: cancelToken);
		return (response.data!['boards'] as List).cast<Map>().map((board) => ImageboardBoard(
			name: board['board'] as String,
			title: board['title'] as String,
			isWorksafe: board['ws_board'] == 1,
			webmAudioAllowed: board['webm_audio'] == 1,
			maxImageSizeBytes: maxUploadSizeBytes,
			maxWebmSizeBytes: maxUploadSizeBytes
		)).toList();
	}

	@protected
	Future<void> updatePostingFields(DraftPost post, Map<String, dynamic> fields, CancelToken? cancelToken) async {
		// Hook for subclasses
	}

	@override
	Future<PostReceipt> submitPost(DraftPost post, CaptchaSolution captchaSolution, CancelToken cancelToken) async {
		final now = DateTime.now().subtract(const Duration(seconds: 5));
		final password = List.generate(12, (i) => random.nextInt(16).toRadixString(16)).join();
		final referer = _getWebUrl(post.board, threadId: post.threadId, mod: loginSystem.isLoggedIn(Persistence.currentCookies));
		final page = await client.get(
			referer,
			options: Options(
				validateStatus: (x) => true,
				extra: {
					kPriority: RequestPriority.interactive
				}
			),
			cancelToken: cancelToken
		);
		final pageDoc = parse(page.data);
		final inputs =
				pageDoc.querySelector('form[name="post"]')
				?.querySelectorAll('input[type="text"], input[type="submit"], input[type="hidden"], textarea')
				?? [];
		final Map<String, dynamic> fields = {
			for (final field in inputs)
				field.attributes['name'] as String: field.attributes['value'] ?? field.text
		};
		if (pageDoc.querySelector('input[name="simple_spam"]')?.parentNode?.parentNode?.firstChild?.text?.nonEmptyOrNull case String simpleSpamQuestion) {
			final solution = await solveCaptcha(
				context: ImageboardRegistry.instance.context,
				site: this,
				request: SimpleTextCaptchaRequest(
					question: simpleSpamQuestion,
					acquiredAt: DateTime.now()
				),
				cancelToken: cancelToken
			);
			if (solution is! SimpleTextCaptchaSolution) {
				throw Exception('You didn\'t answer the captcha');
			}
			fields['simple_spam'] = solution.answer;
		}
		int? lastKnownId;
		if (post.threadId != null) {
			for (final post in pageDoc.querySelectorAll('.post').reversed) {
				if (int.tryParse(post.id.split('_').last) case int id) {
					lastKnownId = id;
					break;
				}
			}
		}
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
			fields['file'] = await MultipartFile.fromFile(file, filename: post.overrideFilename);
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
		if (post.flag case ImageboardBoardFlag flag) {
			fields['user_flag'] = flag.code;
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
		else if (captchaSolution is CloudflareTurnstileCaptchaSolution) {
			fields['cf-turnstile-response'] = captchaSolution.token;
		}
		await updatePostingFields(post, fields, cancelToken);
		final response = await client.postUri(
			Uri.https(sysUrl, '$basePath/post.php'),
			data: FormData.fromMap(fields),
			options: Options(
				responseType: ResponseType.plain,
				validateStatus: (x) => true,
				headers: {
					'Origin': 'https://$baseUrl',
					// lainchan has some greek letter boards
					'Referer': Uri.encodeFull(referer)
				},
				extra: {
					kPriority: RequestPriority.interactive
				}
			),
			cancelToken: cancelToken
		);
		if (response.redirects.tryLast case RedirectRecord redirect) {
			// Don't match numbers in the hostname
			final digitMatches = RegExp(r'\d+').allMatches(redirect.location.replace(host: 'host.com').toString());
			if (digitMatches.isNotEmpty) {
				final id = int.parse(digitMatches.last.group(0)!);
				final threadId = post.threadId;
				// Sanity check in case it matched other number in the path
				if (threadId == null || id > threadId) {
					return PostReceipt(
						post: post,
						id: id,
						password: password,
						name: post.name ?? '',
						options: post.options ?? '',
						time: DateTime.now(),
						ip: captchaSolution.ip
					);
				}
			}
		}
		if ((response.statusCode ?? 0) >= 400) {
			final message = parse(response.data).querySelector('h2')?.text;
			if (message != null) {
				throw PostFailedException(message);
			}
			else {
				throw HTTPStatusException.fromResponse(response);
			}
		}
		final doc = parse(response.data);
		final ban = doc.querySelector('.ban');
		if (ban != null) {
			throw PostFailedException(ban.text);
		}
		if ((doc.querySelector('title')?.text, doc.querySelector('h2')?.text) case ('Error', String error)) {
			throw PostFailedException(error);
		}
		final captchaKey = doc.querySelector('form [data-sitekey]')?.attributes['data-sitekey'];
		if (captchaKey != null) {
			// Mainly for Wizchan
			throw AdditionalCaptchaRequiredException(
				captchaRequest: RecaptchaRequest(
					key: captchaKey,
					cloudflare: true,
					sourceUrl: Uri.https(baseUrl, '/robots.txt').toString()
				),
				onSolved: (solution, cancelToken) async {
					final response = await client.postUri<Map>(Uri.https(baseUrl, '/post.php'), data: FormData.fromMap({
						'g-recaptcha-response': (solution as RecaptchaSolution).response,
						'json_response': '1',
						'whitelist': '1'
					}), cancelToken: cancelToken);
					if (response.data?['error'] case String error) {
						if (!error.contains('Success')) {
							throw Exception(error);
						}
					}
				}
			);
		}
		// This doesn't work if user has quoted someone, but it shouldn't be needed
		int? newPostId;
		final threadId = post.threadId;
		await Future.delayed(const Duration(milliseconds: 500));
		for (int i = 0; newPostId == null && i < 20; i++) {
			if (threadId == null) {
				for (final thread in (await getCatalog(post.board, priority: RequestPriority.interactive)).threads.reversed) {
					if (thread.title == post.subject && (thread.posts[0].buildText().similarityTo(post.text) > 0.9) && (thread.time.compareTo(now) >= 0)) {
						newPostId = thread.id;
					}
				}
			}
			else {
				for (final p in (await getThread(ThreadIdentifier(post.board, threadId), priority: RequestPriority.interactive)).posts) {
					if (switch (lastKnownId) {
						int id => p.id > id,
						null => p.time.compareTo(now) >= 0
					} && (p.buildText().similarityTo(post.text) > 0.9)) {
						newPostId = p.id;
					}
				}
			}
			await Future.delayed(const Duration(seconds: 2));
		}
		if (newPostId == null) {
			throw TimeoutException('Could not find post ID after submission', const Duration(seconds: 40));
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
	Future<void> deletePost(ThreadIdentifier thread, PostReceipt receipt, CaptchaSolution captchaSolution, CancelToken cancelToken, {required bool imageOnly}) async {
		final response = await client.postUri(
			Uri.https(sysUrl, '$basePath/post.php'),
			data: FormData.fromMap({
				'board': thread.board,
				'delete_${receipt.id}': 'on',
				'delete': 'Delete',
				'password': receipt.password,
				if (imageOnly) 'file': 'on'
			}),
			options: Options(
				responseType: ResponseType.plain,
				validateStatus: (x) => true,
				extra: {
					kPriority: RequestPriority.interactive
				}
			),
			cancelToken: cancelToken
		);
		if (response.statusCode != 200) {
			if (response.statusCode == 500) {
				final error = parse(response.data).querySelector('h2')?.text ?? 'Unknown error';
				final match = RegExp(r'another (\d+) second').firstMatch(error);
				if (match != null) {
					throw CooldownException(DateTime.now().add(Duration(seconds: int.parse(match.group(1)!))));
				}
				throw DeletionFailedException(error);
			}
			throw HTTPStatusException.fromResponse(response);
		}
	}

	@override
	Future<CaptchaRequest> getCaptchaRequest(String board, int? threadId, {CancelToken? cancelToken}) async {
		if (turnstileSiteKey case String siteKey) {
			return CloudflareTurnstileCaptchaRequest(
				siteKey: siteKey,
				hostPage: Uri.parse(getWebUrlImpl(board, threadId))
			);
		}
		return const NoCaptchaRequest();
	}

	@override
	Future<ImageboardReportMethod> getPostReportMethod(PostIdentifier post, {CancelToken? cancelToken}) async {
		return WebReportMethod(Uri.https(sysUrl, '$basePath/report.php?post=delete_${post.postId}&board=${post.board}'));
	}

	String _getWebUrl(String board, {int? threadId, int? postId, bool mod = false}) {
		// This maybeGetBoard trick is for lainchan greek letter boards
		// We need to use the non-normalized name
		String threadUrl = 'https://$baseUrl$basePath/${mod ? 'mod.php?/' : ''}${persistence?.maybeGetBoard(board)?.name ?? board}/';
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
	List<ImageboardSnippet> getBoardSnippets(String board) => const [
		greentextSnippet
	];

	@override
	String get siteType => 'lainchan';
	@override
	String get siteData => baseUrl;

	@override
	bool operator ==(Object other) =>
		identical(this, other) ||
		(other is SiteLainchan) &&
		(other.baseUrl == baseUrl) &&
		(other.basePath == basePath) &&
		(other.name == name) &&
		(other.imageUrl == imageUrl) &&
		(other.maxUploadSizeBytes == maxUploadSizeBytes) &&
		(other.faviconPath == faviconPath) &&
		(other.defaultUsername == defaultUsername) &&
		(other.turnstileSiteKey == turnstileSiteKey) &&
		super==(other);

	@override
	int get hashCode => baseUrl.hashCode;
	
	@override
	Uri? get iconUrl {
		final faviconPath = this.faviconPath;
		if (faviconPath == null) {
			return null;
		}
		if (faviconPath.startsWith('/')) {
			return Uri.https(baseUrl, faviconPath);
		}
		return Uri.parse(faviconPath);
	}

	@override
	bool get supportsPushNotifications => true;

	@override
	String formatBoardName(String name) => '/${persistence?.maybeGetBoard(name)?.name ?? name}/';
	@override
	String formatBoardNameWithoutTrailingSlash(String name) => '/${persistence?.maybeGetBoard(name)?.name ?? name}';
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
  Future<void> logoutImpl(bool fromBothWifiAndCellular, CancelToken cancelToken) async {
		final sysUrl = Uri.https(parent.sysUrl, '${parent.basePath}/');
		final modUrl = Uri.https(parent.sysUrl, '${parent.basePath}/mod.php');
		final response = await parent.client.getUri(modUrl, options: Options(
			responseType: ResponseType.plain,
			extra: {
				kPriority: RequestPriority.interactive
			}
		), cancelToken: cancelToken);
		final document = parse(response.data);
		if (document.querySelector('title')?.text != 'Login') {
			// Actually logged in
			final logoutLink = document.querySelectorAll('a').tryFirstWhere((e) => e.text.toLowerCase() == 'logout')?.attributes['href'];
			if (logoutLink == null) {
				return;
			}
			await parent.client.getUri(modUrl.resolve(logoutLink), options: Options(
				followRedirects: false, // dio loses the cookies in the first 303 response
				validateStatus: (status) => (status ?? 0) < 400,
				extra: {
					kPriority: RequestPriority.interactive
				}
			), cancelToken: cancelToken);
		}
		loggedIn[Persistence.currentCookies] = false;
		if (fromBothWifiAndCellular) {
			// No way to log out from non active connection. got to clear the cookies.
			await Persistence.nonCurrentCookies.deletePreservingCloudflare(sysUrl, true);
			await Persistence.nonCurrentCookies.deletePreservingCloudflare(modUrl, true);
			await CookieManager.instance().deleteCookies(
				url: WebUri.uri(sysUrl)
			);
			await CookieManager.instance().deleteCookies(
				url: WebUri.uri(modUrl)
			);
			loggedIn[Persistence.nonCurrentCookies] = false;
		}
  }

  @override
  Future<void> login(Map<ImageboardSiteLoginField, String> fields, CancelToken cancelToken) async {
    final response = await parent.client.postUri(
			Uri.https(parent.sysUrl, '${parent.basePath}/mod.php'),
			data: {
				for (final field in fields.entries) field.key.formKey: field.value,
				'login': 'Continue'
			},
			options: Options(
				responseType: ResponseType.plain,
				contentType: Headers.formUrlEncodedContentType,
				followRedirects: false,
				validateStatus: (x) => true,
				extra: {
					kPriority: RequestPriority.interactive
				}
			),
			cancelToken: cancelToken
		);
		final document = parse(response.data);
		if (document.querySelector('h2') != null) {
			await logout(false, cancelToken);
			throw ImageboardSiteLoginException(document.querySelector('h2')!.text);
		}
		loggedIn[Persistence.currentCookies] = true;
  }

  @override
  String get name => 'Administrator';

	@override
	bool get hidden => true;
}
import 'dart:math' as math;

import 'package:chan/models/attachment.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/flag.dart';
import 'package:chan/models/parent_and_child.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/search.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/embed.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/thumbnailer.dart';
import 'package:chan/sites/4chan.dart';
import 'package:chan/sites/helpers/forum.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/util.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart';
import 'package:html/dom.dart' as dom;

extension _NonEmptyOrNullOrDataUri on String {
	String? get nonEmptyOrNullOrDataUri {
		if (isEmpty || startsWith('data:image/')) {
			return null;
		}
		return this;
	}
}

class SiteXenforo extends ImageboardSite with ForumSite {
	@override
  final String baseUrl;
	@override
	final String name;
	final String basePath;
	final String faviconPath;
	@override
	final int postsPerPage;

	SiteXenforo({
		required this.baseUrl,
		required this.name,
		required this.basePath,
		required this.faviconPath,
		required this.postsPerPage,
		required super.overrideUserAgent,
		required super.archives,
		required super.imageHeaders,
		required super.videoHeaders
	});

	static final _trimNewlinePattern = RegExp(r'\n*(.*)\n*');
	static final _attachmentLinkIdPattern = RegExp(r'\.(\d+)\/?$');
	static final _instagramEmbedPattern = RegExp(r'instagram\.min\.html#([^"]+)"');
	static final _twitterEmbedPattern = RegExp(r'twitter\.min\.html#([^"]+)"');
	static final _youtubeEmbedPattern = RegExp(r'www\.youtube\.com\\/embed\\/([^"]+)"');

	static PostNodeSpan makeSpan(String board, int threadId, int postId, String text) {
		final body = parseFragment(text);
		List<Attachment> attachments = [];
		int spoilerSpanId = 0;
		Iterable<PostSpan> visit(Iterable<dom.Node> nodes, {int listDepth = 0}) sync* {
			bool addLinebreakBefore = false;
			for (final node in nodes) {
				if (addLinebreakBefore) {
					yield const PostLineBreakSpan();
					addLinebreakBefore = false;
				}
				if (node is dom.Element) {
					if (node.localName == 'div' && node.classes.contains('bbImageWrapper')) {
						final img = node.querySelector('img');
						if (img == null) {
							// Something is wrong
							yield PostTextSpan(node.outerHtml);
							continue;
						}
						String src =
							img.attributes['src']?.nonEmptyOrNullOrDataUri ??
							img.attributes['data-url']?.nonEmptyOrNullOrDataUri ??
							img.attributes['data-src']?.nonEmptyOrNullOrDataUri ?? '';
						if (src.isEmpty) {
							// Something is wrong
							yield PostTextSpan(node.outerHtml);
							continue;
						} 
						if (!src.startsWith('http://') && !src.startsWith('https://')) {
							src = 'https://$src';
						}
						final alt = img.attributes['alt']!;
						attachments.add(Attachment(
							type: AttachmentType.image,
							board: board,
							threadId: threadId,
							id: _attachmentLinkIdPattern.firstMatch(src)?.group(1) ?? src,
							ext: '.${alt.afterLast('.')}',
							filename: alt,
							url: src,
							thumbnailUrl: generateThumbnailerForUrl(Uri.parse(src)).toString(),
							md5: '',
							width: img.attributes['width']?.tryParseInt,
							height: img.attributes['height']?.tryParseInt,
							inlineWithinPostId: postId, // to avoid duplicate Heros when quoted
							sizeInBytes: null
						));
						continue;
					}
					if (attachments.isNotEmpty) {
						yield PostAttachmentsSpan(attachments);
						attachments = [];
					}
					if (node.localName == 'script') {
						// Do nothing on purpose
					}
					else if (node.localName == 'br') {
						yield const PostLineBreakSpan();
					}
					else if (node.localName == 'strong' || node.localName == 'b') {
						yield PostBoldSpan(PostNodeSpan(visit(node.nodes).toList()));
					}
					else if (node.localName == 'h1' || node.localName == 'h2' || node.localName == 'h3') {
						yield PostBoldSpan(PostNodeSpan(visit(node.nodes).toList()));
						yield const PostLineBreakSpan();
					}
					else if (node.localName == 'em' || node.localName == 'i') {
						yield PostItalicSpan(PostNodeSpan(visit(node.nodes).toList()));
					}
					else if (node.localName == 'a' && node.classes.contains('username') && (node.text.length > 1) && node.attributes.containsKey('data-user-id')) {
						// Looks like "@username"
						yield PostUserLinkSpan('${node.text.substring(1)}.${node.attributes['data-user-id']}');
					}
					else if (node.localName == 'a' && node.classes.contains('u-anchorTarget') || node.classes.contains('hoverLink')) {
						// Ignore this within-page anchor stuff
					}
					else if (node.localName == 'a' && node.attributes.containsKey('href')) {
						// Note for future:
						// These links can be target="_blank", path=".../attachments/1000022703-png.539627/".
						// So the fakeAttachment viewer won't recognize them.
						yield PostLinkSpan(Uri.encodeFull(node.attributes['href']!), name: node.text.trim().nonEmptyOrNull);
					}
					else if (node.localName == 'p') {
						yield* visit(node.nodes);
					}
					else if (node.localName == 'ol' || node.localName == 'ul') {
						int i = 1;
						for (final li in node.nodes) {
							if (li is dom.Element && li.localName == 'li') {
								if (addLinebreakBefore) {
									yield const PostLineBreakSpan();
									addLinebreakBefore = false;
								}
								if (listDepth > 0) {
									yield PostTextSpan('\n${'    ' * listDepth}');
								}
								if (node.localName == 'ol') {
									yield PostTextSpan('$i. ');
								}
								else {
									yield const PostTextSpan('• ');
								}
								yield* visit(li.nodes.trim(), listDepth: listDepth + 1);
								addLinebreakBefore = true;
								i++;
							}
						}
					}
					else if (node.localName == 'div' && node.classes.contains('bbTable')) {
						dom.Element? table = node.querySelector('table');
						if (table?.children.tryFirst?.localName == 'tbody') {
							// Go into <tbody>
							table = table!.children.first;
						}
						if (table != null) {
							final grid = table.children.tryMap((tr) {
								if (tr.localName == 'tr') {
									return tr.children.tryMap((td) {
										if (td.localName == 'td' || td.localName == 'th') {
											return PostNodeSpan(visit(td.nodes).toList());
										}
									}).toList();
								}
								return null;
							}).toList();
							int cols = 0;
							for (final row in grid) {
								cols = math.max(cols, row.length);
							}
							for (final row in grid) {
								row.addAll(Iterable.generate(cols - row.length, (_) => const PostNodeSpan([PostTextSpan('<generated cell>')])));
							}
							final single = grid.trySingle?.trySingle;
							if (single != null) {
								// Some dumb singleton table
								yield single;
								yield const PostLineBreakSpan();
							}
							else {
								// Actual table
								yield PostTableSpan(grid);
							}
						}
						else {
							yield PostTextSpan(node.outerHtml);
						}
					}
					else if (node.localName == 'hr') {
						yield const PostDividerSpan();
					}
					else if (node.localName == 'sup') {
						yield PostSuperscriptSpan(PostNodeSpan(visit(node.nodes).toList()));
					}
					else if (node.localName == 'strikethrough' || node.localName == 's') {
						yield PostStrikethroughSpan(PostNodeSpan(visit(node.nodes).toList()));
					}
					else if (node.localName == 'u') {
						yield PostUnderlinedSpan(PostNodeSpan(visit(node.nodes).toList()));
					}
					else if (node.localName == 'blockquote') {
						final quoteContent = node.querySelector('.bbCodeBlock-expandContent');
						if (quoteContent != null) {
							final quote = PostQuoteSpan(PostNodeSpan(visit(parseFragment(quoteContent.innerHtml.trim()).nodes).toList()));
							final source = node.attributes['data-source']?.split(':').last.tryParseInt;
							if (source != null) {
								yield PostQuoteLinkWithContextSpan(
									quoteLink: PostQuoteLinkSpan(
										board: board,
										threadId: threadId,
										postId: source
									),
									context: quote
								);
							}
							else {
								yield quote;
								yield const PostLineBreakSpan();
							}
						}
						else {
							final instagramLink = node.attributes['data-instgrm-permalink'];
							if (instagramLink != null) {
								yield PostLinkSpan(instagramLink);
								yield const PostLineBreakSpan();
							}
							else {
								// Idk
								yield PostTextSpan(node.outerHtml);
								yield const PostLineBreakSpan();
							}
						}
					}
					else if (node.localName == 'div' && node.classes.contains('fauxBlockLink') && node.attributes.containsKey('data-embed-content-url')) {
						// Too much work to really parse this rich tree, just bail to embed system
						yield PostLinkSpan(node.attributes['data-embed-content-url']!);
						yield const PostLineBreakSpan();
					}
					else if (node.localName == 'pre') {
						yield PostCodeSpan(node.text.trimRight());
					}
					else if (node.localName == 'code') {
						yield PostCodeSpan(node.text);
					}
					else if (node.localName == 'img' && node.classes.contains('smilie')) {
						final src = node.attributes['src']?.nonEmptyOrNull;
						if (src != null && !src.startsWith('data:')) {
							yield PostInlineImageSpan(src: src, width: 60, height: 60);
						}
						else {
							yield PostTextSpan(node.attributes['alt'] ?? ':null:');
						}
					}
					else if (node.localName == 'div' && node.classes.contains('bbMediaWrapper') && node.attributes['data-media-site-id'] == 'youtube') {
						yield PostLinkSpan('https://www.youtube.com/watch?v=${node.attributes['data-media-key']}');
					}
					else if (node.localName == 'div' && node.classes.contains('bbMediaWrapper') && node.querySelector('video source')?.attributes['src'] != null) {
						final video = node.querySelector('video')!;
						final src = node.querySelector('source')!.attributes['src']!;
						attachments.add(Attachment(
							type: AttachmentType.mp4,
							board: board,
							threadId: threadId,
							id: src,
							ext: '.${src.afterLast('.')}',
							filename: src.afterLast('/'),
							url: src,
							thumbnailUrl: generateThumbnailerForUrl(Uri.parse(src)).toString(),
							md5: '',
							width: video.attributes['width']?.tryParseInt,
							height: video.attributes['height']?.tryParseInt,
							inlineWithinPostId: postId, // to avoid duplicate Heros when quoted
							sizeInBytes: null
						));
					}
					else if (node.localName == 'div' && node.classes.contains('bbCodeBlock--unfurl') && node.attributes.containsKey('data-url')) {
						final url = node.attributes['data-url']!;
						final imageSrc = node.querySelector('.contentRow-figure img')?.attributes['src'];
						final title = node.querySelector('.contentRow-header')?.text.trim();
						final provider = node.querySelector('.contentRow-minor')?.text.trim();
						yield PostLinkSpan(url, name: title, embedData: EmbedData(
							title: title,
							thumbnailUrl: imageSrc,
							provider: provider,
							author: null
						));
					}
					else if (node.localName == 'div' && node.children.tryFirst?.localName == 'a') {
						yield PostLinkSpan(node.children.first.attributes['href'] ?? '', name: node.text.trim());
					}
					else if (node.localName == 'div' && node.classes.contains('bbCodeSpoiler')) {
						final spoilerContent = node.querySelector('.bbCodeBlock-content');
						if (spoilerContent == null) {
							// Something went wrong
							yield PostTextSpan(node.outerHtml);
							continue;
						}
						yield PostSpoilerSpan(PostNodeSpan(visit(spoilerContent.nodes).toList()), spoilerSpanId++);
					}
					else if (node.localName == 'div') {
						yield PostNodeSpan(visit(node.nodes).toList());
					}
					else if (node.localName == 'h4') {
						yield PostNodeSpan(visit(node.nodes).toList());
						yield const PostLineBreakSpan();
					}
					else if (node.localName == 'span' && node.attributes.entries.trySingle?.key == 'style') {
						// Style-only wrapper, just ignore it
						yield* visit(node.nodes);
					}
					else if (node.localName == 'iframe' && node.attributes.containsKey('src')) {
						yield PostLinkSpan(node.attributes['src']!);
					}
					else if (node.localName == 'video') {
						final src = node.querySelector('source')?.attributes['src'];
						if (src != null) {
							yield PostLinkSpan(src);
						}
						else {
							// Something is not as expected
							yield PostTextSpan(node.outerHtml);
						}
					}
					else if (node.localName == 'span') {
						final iframeJsonStr = node.attributes['data-s9e-mediaembed-iframe'];
						if (iframeJsonStr != null) {
							final instagramMatch = _instagramEmbedPattern.firstMatch(iframeJsonStr);
							if (instagramMatch != null) {
								yield PostLinkSpan('https://www.instagram.com/p/${instagramMatch.group(1)}');
								continue;
							}
							final twitterMatch = _twitterEmbedPattern.firstMatch(iframeJsonStr);
							if (twitterMatch != null) {
								yield PostLinkSpan('https://www.twitter.com/_/status/${twitterMatch.group(1)}');
								continue;
							}
							final youtubeMatch = _youtubeEmbedPattern.firstMatch(iframeJsonStr);
							if (youtubeMatch != null) {
								yield PostLinkSpan('https://www.youtube.com/watch?v=${youtubeMatch.group(1)}');
								continue;
							}
						}
						// Something else, just recurse into the span
						yield* visit(node.nodes);
					}
					else {
						yield PostTextSpan(node.outerHtml);
					}
				}
				else {
					if (attachments.isNotEmpty) {
						yield PostAttachmentsSpan(attachments);
						attachments = [];
						yield const PostLineBreakSpan();
					}
					final trimmedText = _trimNewlinePattern.firstMatch(node.text ?? '')?.group(1) ?? '';
					if (trimmedText.isNotEmpty) {
						yield* Site4Chan.parsePlaintext(trimmedText);
					}
				}
			}
			if (attachments.isNotEmpty) {
				yield PostAttachmentsSpan(attachments);
				attachments = [];
			}
		}
		return PostNodeSpan(visit(body.nodes).toList(growable: false));
	}

	late final _relativeBoardPattern  = RegExp(RegExp.escape(basePath) + r'/forums/([^/]+)');

	/// Board is a weak concept in Xenforo. Sometimes we need to find it.
	Future<String?> _lookupBoard(int threadId) async {
		// See if we know the board from loading it before
		final imageboardKey = persistence?.imageboardKey;
		if (imageboardKey != null) {
			final prefix = '$imageboardKey/';
			final suffix = '/$threadId';
			for (final key in Persistence.sharedThreadStateBox.keys.followedBy(Persistence.sharedThreadsBox.keys)) {
				// key looks like '$imageboardKey/$board/$threadId'
				if (key is! String) {
					continue;
				}
				if (key.startsWith(prefix) && key.endsWith(suffix)) {
					return key.split('/')[1];
				}
			}
		}
		// We don't know the board, need to get it from the page
		final response = await client.get(getWebUrlImpl('', threadId), options: Options(responseType: ResponseType.plain));
		final document = parse(response.data);
		final boardLink = document.querySelector('.p-breadcrumbs')?.querySelectorAll('a').tryLast?.attributes['href'] ?? '';
		if (boardLink.startsWith('/')) {
			final boardMatch = _relativeBoardPattern.firstMatch(boardLink);
			if (boardMatch != null) {
				return boardMatch.group(1)!;
			}
		}
		else {
			// Full URL
			final boardUrl = Uri.parse(boardLink);
			if (boardUrl.host == baseUrl) {
				final boardMatch = _relativeBoardPattern.firstMatch(boardUrl.path);
				if (boardMatch != null) {
					return boardMatch.group(1)!;
				}
			}
		}
		return null;
	}

  @override
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
		if (p.length >= 2 && p[0] == 'forums') {
			return BoardThreadOrPostIdentifier(p[1]);
		}

		if (p.length >= 2 && p[0] == 'threads') {
			if (p[1].afterLast('.').tryParseInt case int threadId) {
				int? pageNumber;
				int? postNumber;
				if (p.length == 2) {
					postNumber = url.fragment.extractPrefixedInt('post-');
				}
				else {
					pageNumber = switch (p[2].extractPrefixedInt('page-')) {
						// Pages have negative IDs
						int p => -p,
						null => null
					};
					postNumber = p[2].extractPrefixedInt('post-') ?? url.fragment.extractPrefixedInt('post-');
				}
				final board = await _lookupBoard(threadId);
				if (board != null) {
					return BoardThreadOrPostIdentifier(board, threadId, postNumber ?? pageNumber);
				}
			}
		}
		return null;
  }

  @override
  String get defaultUsername => '';

	@override
	ImageboardBoardPopularityType? get boardPopularityType => ImageboardBoardPopularityType.postsCount;

  @override
  Future<List<ImageboardBoard>> getBoards({required RequestPriority priority, CancelToken? cancelToken}) async {
    final response = await client.getUri(
			Uri.https(baseUrl, '$basePath/forums/-/list'),
			options: Options(
				responseType: ResponseType.plain,
				extra: {
					kPriority: priority
				}
			),
			cancelToken: cancelToken
		);
		final document = parse(response.data);
		return document.querySelectorAll('.node--forum').tryMap((forum) {
			final e = forum.querySelector('.node-title a');
			final parts = e?.attributes['href']?.split('/') ?? [];
			parts.removeWhere((e) => e.isEmpty);
			if (e == null || parts.isEmpty) {
				return null;
			}
			return ImageboardBoard(
				name: parts.last,
				title: e.text,
				isWorksafe: true,
				webmAudioAllowed: true,
				popularity: forum.querySelectorAll('.node-stats dl').tryMapOnce((dl) {
					final children = dl.children;
					if (children.length == 2 && children.first.text == 'Messages' || children.first.text == 'Posts') {
						String text = children[1].text.replaceAll(',', '').toLowerCase();
						int multiplier = 1;
						if (text.endsWith('k')) {
							multiplier = 1000;
							text = text.substring(0, text.length - 1);
						}
						else if (text.endsWith('m')) {
							multiplier = 1000000;
							text = text.substring(0, text.length - 1);
						}
						final value = text.tryParseDouble;
						if (value == null) {
							return null;
						}
						return (value * multiplier).round();
					}
					return null;
				})
			);
		}).toList();
  }

  @override
  Future<CaptchaRequest> getCaptchaRequest(String board, int? threadId, {CancelToken? cancelToken}) async {
    return const NoCaptchaRequest();
  }

	static DateTime _parseTime(dom.Element time) {
		return DateTime.fromMillisecondsSinceEpoch(int.parse(time.attributes['data-timestamp'] ?? time.attributes['data-time']!) * 1000);
	}

	static final _catalogReplyCountPattern = RegExp(r'^(\d+)(K?)$');

	Future<List<Thread>> _getCatalogPage(String board, int page, {required RequestPriority priority, CancelToken? cancelToken}) async {
		final response = await client.getUri(
			Uri.https(baseUrl, '$basePath/forums/$board/page-$page'),
			options: Options(
				responseType: ResponseType.plain,
				extra: {
					kPriority: priority
				}
			),
			cancelToken: cancelToken
		);
		final document = parse(response.data);
		return document.querySelectorAll('.structItem--thread').map((e) {
			// Like "6K" "400"
			final replyCountStr = e.querySelectorAll('.structItem-cell--meta dl').tryFirstWhere((ee) {
				return ee.querySelector('dt')?.text == 'Replies';
			})?.querySelector('dd')?.text;
			final replyCountMatch = _catalogReplyCountPattern.firstMatch(replyCountStr ?? '');
			final int replyCount;
			if (replyCountMatch != null) {
				replyCount = int.parse(replyCountMatch.group(1)!) * switch(replyCountMatch.group(2)) {
					'K' => 1000,
					_ => 1
				};
			}
			else {
				replyCount = 0;
			}
			final label = e.querySelector('.label--primary')?.text;
			final id = int.parse(e.classes.firstWhere((c) => c.startsWith('js-threadListItem-')).split('-')[2]);
			final time = _parseTime(e.querySelector('time')!);
			final lastPostTime = e.querySelector('.structItem-cell--latest time');
			return Thread(
				attachments: const [],
				posts_: [
					Post(
						board: board,
						id: -1,
						text: '',
						name: _parseUsernameFromLink(e.querySelector('.username')),
						time: time,
						threadId: id,
						spanFormat: PostSpanFormat.pageStub,
						hasOmittedReplies: true,
						attachments_: const []
					),
					// Placeholder entry for last new post. Then we can tell if the thread is modified or not.
					if (replyCount > 0 && lastPostTime != null) Post(
						board: board,
						id: -(e.querySelectorAll('.structItem-pageJump a').tryLast?.text.tryParseInt ?? 1),
						text: '',
						name: _parseUsernameFromLink(e.querySelector('.structItem-cell--latest a.username')),
						time: _parseTime(lastPostTime),
						threadId: id,
						spanFormat: PostSpanFormat.pageStub,
						hasOmittedReplies: true,
						attachments_: const []
					),
				],
				replyCount: replyCount,
				imageCount: 0,
				flair: label == null ? null : ImageboardFlag.text(label),
				id: id,
				board: board,
				title: e.querySelector('.structItem-title a[data-tp-primary="on"]')?.text.trim(),
				isSticky: e.querySelector('.structItem-status--sticky') != null,
				time: time,
				currentPage: page
			);
		}).toList();
	}

  @override
  Future<Catalog> getCatalogImpl(String board, {CatalogVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) async {
    return Catalog(
			threads: await _getCatalogPage(board, 1, priority: priority, cancelToken: cancelToken),
			lastModified: null // No 304 handling
		);
  }

	@override
	Future<List<Thread>> getMoreCatalogImpl(String board, Thread after, {CatalogVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) {
		return _getCatalogPage(board, (after.currentPage ?? 1) + 1, priority: priority, cancelToken: cancelToken);
	}

  @override
  Future<Post> getPostFromArchive(String board, int id, {required RequestPriority priority, CancelToken? cancelToken}) {
    throw UnimplementedError();
  }

	static final _absoluteSrcPattern = RegExp(r' src="//');
	static final _relativeSrcPattern = RegExp(r' src="/');
	String _fixRelativeUrls(String html) {
		return html.replaceAllMapped(_absoluteSrcPattern, (match) {
			return ' src="https://';
		}).replaceAllMapped(_relativeSrcPattern, (match) {
			return ' src="https://$baseUrl/';
		});
	}

	String _fixRelativeUrl(String url) {
		if (url.startsWith('//')) {
			return 'https:$url';
		}
		if (url.startsWith('/')) {
			return 'https://$baseUrl$url';
		}
		return url;
	}

	static String _parseUsernameFromLink(dom.Element? e) {
		if (e != null) {
			if (e.attributes['href']?.split('/').tryLastWhere((p) => p.isNotEmpty) case String x) {
				return x;
			}
			if (e.attributes['data-user-id'] case String userId) {
				return '${e.text.trim()}.$userId';
			}
		}
		return '<unknown user>';
	}

	List<Post> _getPostsFromThreadPage(String board, int threadId, dom.Document document) {
		final pageNavPages = document.querySelector('.pageNav-main')?.querySelectorAll('.pageNav-page') ?? [];
		final currentPageNumber = pageNavPages.tryFirstWhere((e) => e.classes.contains('pageNav-page--current'))?.text.tryParseInt ?? 1;
		final lastPageNumber = pageNavPages.tryLast?.text.tryParseInt ?? 1;
		final opName = _parseUsernameFromLink(document.querySelector('.p-description .username'));
		Post generateStub(int pageNumber) => Post(
			board: board,
			threadId: threadId,
			text: '',
			// To avoid wasted memory, we only need thread.posts.first to have correct OP name
			name: pageNumber == 1 ? opName : '',
			time: DateTime.now(), // arbitrary
			id: -pageNumber,
			spanFormat: PostSpanFormat.pageStub,
			attachments_: const [],
			hasOmittedReplies: pageNumber != currentPageNumber || pageNumber == lastPageNumber
		);
		final pagesBefore = Iterable.generate(currentPageNumber, (i) => generateStub(i + 1));
		final pagesAfter = Iterable.generate(lastPageNumber - currentPageNumber, (i) => generateStub(i + 1 + currentPageNumber));
		final realPosts = document.querySelectorAll('article.message--post').map((e) {
			return Post(
				board: board,
				threadId: threadId,
				id: int.parse(e.id.split('-')[2]),
				text: _fixRelativeUrls(e.querySelector('.message-body .bbWrapper')!.innerHtml),
				parentId: -currentPageNumber,
				name: _parseUsernameFromLink(e.querySelector('.message-name a') ?? e.querySelector('.message-name .username')),
				time: _parseTime(e.querySelector('.message-attribution-main time')!),
				spanFormat: PostSpanFormat.xenforo,
				attachments_: e.querySelectorAll('.message-attachments .file-preview img').map((img) {
					final url = _fixRelativeUrl(img.attributes['src']!);
					final parentHref = switch (img.parent?.attributes['href']) {
						String href => _fixRelativeUrl(href),
						null => null
					};
					return Attachment(
						board: board,
						threadId: threadId,
						type: AttachmentType.image,
						id: img.attributes['src']!,
						ext: '.${img.attributes['src']!.afterLast('.')}',
						filename: img.attributes['alt'] ?? img.attributes['src']!.afterLast('/'),
						url: parentHref ?? url,
						thumbnailUrl: generateThumbnailerForUrl(Uri.parse(url)).toString(),
						md5: '',
						width: img.attributes['width']?.tryParseInt,
						height: img.attributes['height']?.tryParseInt,
						sizeInBytes: null
					);
				}).toList(growable: false)
			);
		});
		return pagesBefore.followedBy(realPosts).followedBy(pagesAfter).toList();
	}

	static final _postNumberPattern = RegExp(r'#([\d,]+)');
	static final _pollVotesPattern = RegExp(r'Votes: (\d+)');

  @override
  Future<Thread> getThreadImpl(ThreadIdentifier thread, {ThreadVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) async {
		// Little trick to always start loading on last page
    final response = await client.getThreadUri(Uri.https(baseUrl, '$basePath/threads/${thread.id}/page-9999999'), priority: priority, responseType: ResponseType.plain, cancelToken: cancelToken);
		final document = parse(response.data);
		final lastPostNumber = int.parse(_postNumberPattern.firstMatch(document.querySelectorAll('article.message--post').last.querySelectorAll('header.message-attribution li').last.text)!.group(1)!.replaceAll(',', ''));
		final label = document.querySelector('.p-title-value .label')?.text;
		return Thread(
			replyCount: lastPostNumber - 1, // By convention we don't count OP as a reply
			imageCount: 0,
			id: thread.id,
			board: thread.board,
			title: document.querySelector('.p-title-value')!.nodes.map((e) {
				if (e is dom.Element && (e.classes.contains('label') || e.classes.contains('label-append'))) {
					// Skip flair
					return '';
				}
				return e.text;
			}).join('').trim(),
			flair: label == null ? null : ImageboardFlag.text(label),
			isSticky: false,
			time: _parseTime(document.querySelector('.p-description time')!),
			attachments: [],
			posts_: _getPostsFromThreadPage(thread.board, thread.id, document),
			poll: switch (document.querySelectorAll('form').tryFirstWhere((e) => e.classes.any((c) => c.startsWith('js-pollContainer-')))) {
				null => null,
				dom.Element poll => ImageboardPoll(
					title: poll.querySelector('.block-header')!.text.trim(),
					rows: poll.querySelectorAll('.pollResult').map((e) => ImageboardPollRow(
						name: e.querySelector('.pollResult-response')!.text,
						votes: int.parse(_pollVotesPattern.firstMatch(e.text)!.group(1)!)
					)).toList()
				)
			}
		);
  }

	@override
	Future<List<Post>> getStubPosts(ThreadIdentifier thread, List<ParentAndChildIdentifier> postIds, {required RequestPriority priority, CancelToken? cancelToken}) async {
		// Just do one at a time
		final postId = postIds.first;
		if (postId.childId.isNegative) {
			// Request for page
			final response = await client.getUri(
				Uri.https(baseUrl, '$basePath/threads/${thread.id}/page-${-postId.childId}'),
				options: Options(
					responseType: ResponseType.plain,
					extra: {
						kPriority: priority
					}
				),
				cancelToken: cancelToken
			);
			final document = parse(response.data);
			return _getPostsFromThreadPage(thread.board, thread.id, document);
		}
		// Request for post
		final response = await client.getUri(
			Uri.https(baseUrl, '$basePath/goto/post', {'id': postId.childId.toString()}),
			options: Options(
				responseType: ResponseType.plain,
				extra: {
					kPriority: priority
				}
			),
			cancelToken: cancelToken
		);
		final resolved = (await decodeUrl(response.realUri))?.threadIdentifier ?? thread;
		final document = parse(response.data);
		return _getPostsFromThreadPage(resolved.board, resolved.id, document);
	}

  @override
  String getWebUrlImpl(String board, [int? threadId, int? postId]) {
    if (threadId == null) {
			return Uri.https(baseUrl, '$basePath/forums/$board').toString();
		}
		if (postId == null) {
			return Uri.https(baseUrl, '$basePath/threads/$threadId').toString();
		}
		if (postId.isNegative) {
			return Uri.https(baseUrl, '$basePath/threads/$threadId/page-${-postId}').toString();
		}
		return Uri.https(baseUrl, '$basePath/threads/$threadId/post-$postId').toString();
  }

  @override
  Uri? get iconUrl => Uri.https(baseUrl, faviconPath);

	@override
	ImageboardSearchMetadata supportsSearch(String? board) {
		return ImageboardSearchMetadata(
			name: name,
			options: const ImageboardSearchOptions(
				text: true,
				name: true,
				supportedPostTypeFilters: {
					PostTypeFilter.none,
					PostTypeFilter.onlyOPs
				},
				date: true
			)
		);
	}

	static const _kXenforoSearchIdMemoKey = 'xenforoSearch';

	late final _searchIdPattern = RegExp(r'https?://' + RegExp.escape(baseUrl + basePath) + r'/search/(\d+)');
	static final _searchReplyCountPattern = RegExp(r'Replies: (\d+)');
	static final _searchLinkPattern = RegExp(r'/threads/[^/]*\.(\d+)(?:/post-(\d+))?');

	@override
	Future<ImageboardArchiveSearchResultPage> search(ImageboardArchiveSearchQuery query, {required int page, ImageboardArchiveSearchResultPage? lastResult, required RequestPriority priority, CancelToken? cancelToken}) async {
		final commonFields = {
			if (query.name != null) 'c[users]': query.name,
			if (query.postTypeFilter == PostTypeFilter.onlyOPs) 'c[title_only]': '1',
			if (query.startDate != null) 'c[newer_than]': '${query.startDate?.year}-${query.startDate?.dMM}-${query.startDate?.dDD}',
			if (query.endDate != null) 'c[older_than]': '${query.endDate?.year}-${query.endDate?.dMM}-${query.endDate?.dDD}'
		};
		final int searchId;
		final Response? pageOneResponse;
		final oldId = lastResult?.memo[_kXenforoSearchIdMemoKey] as int?;
		if (oldId != null) {
			searchId = oldId;
			pageOneResponse = null;
		}
		else {
			final homepageResponse = await client.getUri(
				Uri.https(baseUrl, '$basePath/search/'),
				options: Options(
					responseType: ResponseType.plain,
					extra: {
						kPriority: priority
					}
				),
				cancelToken: cancelToken
			);
			final homepageDocument = parse(homepageResponse.data);
			final form = homepageDocument.querySelector('.p-body-pageContent form')!;
			final Map<String, dynamic> fields = {
				for (final field in form.querySelectorAll('input[type="text"], input[type="submit"], input[type="hidden"], textarea'))
					field.attributes['name']!: field.attributes['value'] ?? field.text
			};
			fields['keywords'] = query.query;
			if (query.boards.isNotEmpty) {
				fields['constraints'] = '{"search_type":"post","c":{"nodes":[${query.boards.first.afterLast('.')}],"child_nodes":1}}';
			}
			fields.addAll(commonFields);
			pageOneResponse = await client.postUri(
				Uri.https(baseUrl, form.attributes['action']!),
				data: fields,
				options: Options(
					contentType: Headers.formUrlEncodedContentType,
					responseType: ResponseType.plain,
					extra: {
						kPriority: priority
					}
				),
				cancelToken: cancelToken
			);
			final match = _searchIdPattern.firstMatch(pageOneResponse.redirects.tryLast?.location.toString() ?? '');
			if (match != null) {
				searchId = int.parse(match.group(1)!);
			}
			else {
				// No redirect, something went wrong
				final document = parse(pageOneResponse.data);
				throw Exception(document.querySelector('.p-body-pageContent .blockMessage')?.text.trim() ?? 'Unknown Error');
			}
		}
		final Response response;
		if (page == 1 && pageOneResponse != null) {
			response = pageOneResponse;
		}
		else {
			response = await client.getUri(Uri.https(baseUrl, '$basePath/search/$searchId', {
				'q': query.query,
				'o': 'date',
				'page': page.toString(),
				if (query.boards.isNotEmpty) ...{
					'c[child_nodes]': '1',
					'c[nodes][0]': query.boards.first.afterLast('.')
				},
				...commonFields
			}), options: Options(
				responseType: ResponseType.plain,
				extra: {
					kPriority: priority
				}
			), cancelToken: cancelToken);
		}
		final document = parse(response.data);
		return ImageboardArchiveSearchResultPage(
			posts: document.querySelectorAll('.block-row--separated').map((e) {
				final cells = e.querySelectorAll('.contentRow-minor li');
				final name = cells[0].text.trim();
				final isThread = cells[1].text.trim().toLowerCase() == 'thread';
				final time = _parseTime(cells[2].querySelector('time')!);
				final board = _relativeBoardPattern.firstMatch(cells.last.querySelector('a')!.attributes['href']!)!.group(1)!;
				final linkMatch = _searchLinkPattern.firstMatch(e.querySelector('.contentRow-title a')!.attributes['href']!)!;
				final threadId = int.parse(linkMatch.group(1)!);
				final replyCount = _searchReplyCountPattern.firstMatch(cells[3].text.trim())?.group(1)?.tryParseInt ?? 0;
				if (isThread) {
					return ImageboardArchiveSearchResult.thread(Thread(
						board: board,
						id: threadId,
						replyCount: replyCount,
						imageCount: 0,
						title: e.querySelector('.contentRow-title')!.nodes.map((e) {
							if (e is dom.Element && (e.classes.contains('label') || e.classes.contains('label-append'))) {
								// Skip flair
								return '';
							}
							return e.text;
						}).join('').trim(),
						isSticky: false, // No way to tell
						time: time,
						attachments: [],
						posts_: [
							// This isn't quite right. it won't be able to be merged properly
							// But we don't merge from search results, so no big deal
							Post(
								board: board,
								threadId: threadId,
								id: threadId,
								text: _fixRelativeUrls(e.querySelector('.contentRow-snippet')!.text.trim()),
								name: name,
								time: time,
								spanFormat: PostSpanFormat.xenforo,
								attachments_: const []
							),
							Post(
								board: board,
								threadId: threadId,
								id: -((replyCount ~/ postsPerPage) + 1),
								text: '',
								name: name,
								time: time,
								spanFormat: PostSpanFormat.pageStub,
								hasOmittedReplies: true,
								attachments_: const []
							)
						]
					));
				}
				return ImageboardArchiveSearchResult.post(Post(
					board: board,
					threadId: threadId,
					id: int.parse(linkMatch.group(2)!),
					text: _fixRelativeUrls(e.querySelector('.contentRow-snippet')!.text.trim()),
					name: name,
					time: time,
					spanFormat: PostSpanFormat.xenforo,
					attachments_: const []
				));
			}).toList(),
			replyCountsUnreliable: false,
			imageCountsUnreliable: false,
			page: page,
			canJumpToArbitraryPage: true,
			maxPage: document.querySelectorAll('.pageNav-page').tryLast?.text.trim().tryParseInt ?? 1,
			count: null,
			archive: this,
			memo: {
				_kXenforoSearchIdMemoKey: searchId
			}
		);
	}

  @override
  String get siteData => '$baseUrl,$basePath';

  @override
  String get siteType => 'xenforo';

	@override
	bool get supportsPosting => false;

  @override
  Future<PostReceipt> submitPost(DraftPost post, CaptchaSolution captchaSolution, CancelToken cancelToken) {
    // TODO: implement submitPost
    throw UnimplementedError();
  }

	@override
	String formatBoardName(String name) => '/${name.beforeFirst('.')}/';
	@override
	String formatBoardNameWithoutTrailingSlash(String name) => '/${name.beforeFirst('.')}';

	@override
	String formatUsername(String name) {
		final int lastDotPos = name.lastIndexOf('.');
		if (lastDotPos == -1) {
			return name;
		}
		return name.substring(0, lastDotPos);
	}

	@override
	bool get supportsUserInfo => true;
	@override
	bool get supportsUserAvatars => true;

	@override
	Future<ImageboardUserInfo> getUserInfo(String username) async {
		final url = Uri.https(baseUrl, '$basePath/members/$username');
		final response = await client.getUri(url, options: Options(responseType: ResponseType.plain));
		final document = parse(response.data);
		return ImageboardUserInfo(
			username: username,
			webUrl: url,
			avatar: switch (document.querySelector('.memberHeader-avatar img')?.attributes['src']) {
				String rawSrc => Uri.tryParse('https:$rawSrc'),
				null => null
			},
			createdAt: switch (document.querySelectorAll('.memberHeader-blurb').tryMapOnce((e) {
				if (e.querySelector('dt')?.text.toLowerCase() == 'joined') {
					return e.querySelector('time');
				}
				return null;
			})) {
				dom.Element e => _parseTime(e),
				null => null
			},
			totalKarma: document.querySelectorAll('.memberHeader-stats dl').tryMapOnce((e) {
				if (e.querySelector('dt')?.text.toLowerCase() == 'reaction score') {
					return e.querySelector('dd')?.text.trim().tryParseInt;
				}
				return null;
			}) ?? 0
		);
	}

	@override
	bool get showImageCount => false;

	@override
	bool get classicCatalogStyle => false;

	@override
	bool get hasPagedCatalog => true;

	@override
	bool get hasExpiringThreads => false;

	/// On the website these are huge (full-width)
	@override
	bool get hasLargeInlineAttachments => true;

	@override
	bool get hasSharedIdSpace => true;

	@override
	bool operator == (Object other) =>
		identical(other, this) ||
		other is SiteXenforo &&
		other.name == name &&
		other.baseUrl == baseUrl &&
		other.basePath == basePath &&
		other.faviconPath == faviconPath &&
		other.postsPerPage == postsPerPage &&
		super==(other);
	
	@override
	int get hashCode => baseUrl.hashCode;
}
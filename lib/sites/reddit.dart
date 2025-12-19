import 'dart:convert';
import 'dart:math';

import 'package:chan/models/flag.dart';
import 'package:chan/models/parent_and_child.dart';
import 'package:chan/models/search.dart';
import 'package:chan/services/linkifier.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/thumbnailer.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/4chan.dart';

import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/util.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:linkify/linkify.dart';
import 'package:markdown/markdown.dart' as markdown;
import 'package:html/dom.dart' as dom;

class _SuperscriptSyntax extends markdown.InlineSyntax {
  static const _pattern = r'\^([^ ]+)';

  _SuperscriptSyntax() : super(_pattern,
		startCharacter: 0x5E // ^
	);

  @override
  bool onMatch(markdown.InlineParser parser, Match match) {
		parser.addNode(markdown.Element.text('sup', match.group(1)!));
    return true;
  }
}

class _SpoilerSyntax extends markdown.InlineSyntax {
  static const _pattern = r'>!([^!]+)!<';

  _SpoilerSyntax() : super(_pattern,
		startCharacter: 0x3E // >
	);

  @override
  bool onMatch(markdown.InlineParser parser, Match match) {
		parser.addNode(markdown.Element.text('spoiler', match.group(1)!));
    return true;
  }
}

class _StrikethroughSyntax extends markdown.InlineSyntax {
  static const _pattern = r'~~(.+)~~';

  _StrikethroughSyntax() : super(_pattern,
		startCharacter: 0x7E // ~
	);

  @override
  bool onMatch(markdown.InlineParser parser, Match match) {
		parser.addNode(markdown.Element.text('strikethrough', match.group(1)!));
    return true;
  }
}

class _RedditSimplifiedLinkSyntax extends markdown.InlineSyntax {
	final String localName;
	_RedditSimplifiedLinkSyntax({
		required String leading,
		required this.localName
	}) : super('(\\s|^)$leading/([A-Za-z0-9_\\-]+)');

	@override
	bool onMatch(markdown.InlineParser parser, Match match) {
		final before = match.group(1) ?? '';
		if (before.isNotEmpty) {
			parser.addNode(markdown.Text(before));
		}
		parser.addNode(markdown.Element.text(localName, match.group(2)!));
    return true;
	}
}

const _kSubredditLinkLocalName = 'rslash';

class _SubredditWithoutLeadingSlashSyntax extends _RedditSimplifiedLinkSyntax {
  _SubredditWithoutLeadingSlashSyntax() : super(
		leading: 'r',
		localName: _kSubredditLinkLocalName
	);
}

class _SubredditWithLeadingSlashSyntax extends _RedditSimplifiedLinkSyntax {
  _SubredditWithLeadingSlashSyntax() : super(
		leading: '/r',
		localName: _kSubredditLinkLocalName
	);
}

const _kUserLinkLocalName = 'uslash';

class _UserWithoutLeadingSlashSyntax extends _RedditSimplifiedLinkSyntax {
  _UserWithoutLeadingSlashSyntax() : super(
		leading: 'u',
		localName: _kUserLinkLocalName
	);
}

class _UserWithLeadingSlashSyntax extends _RedditSimplifiedLinkSyntax {
  _UserWithLeadingSlashSyntax() : super(
		leading: '/u',
		localName: _kUserLinkLocalName
	);
}

extension _RedditApiName on ThreadVariant {
	String? get redditApiName {
		switch (this) {
			case ThreadVariant.redditTop:
				return 'top';
			case ThreadVariant.redditBest:
				return 'confidence';
			case ThreadVariant.redditNew:
				return 'new';
			case ThreadVariant.redditControversial:
				return 'controversial';
			case ThreadVariant.redditOld:
				return 'old';
			case ThreadVariant.redditQandA:
				return 'qa';
		}
	}
	static ThreadVariant? toVariant(String redditApiName) {
		switch (redditApiName) {
			case 'top':
				return ThreadVariant.redditTop;
			case 'confidence':
				return ThreadVariant.redditBest;
			case 'new':
				return ThreadVariant.redditNew;
			case 'controversial':
				return ThreadVariant.redditControversial;
			case 'old':
				return ThreadVariant.redditOld;
			case 'qa':
				return ThreadVariant.redditQandA;
		}
		return null;
	}
}

extension _RedditApiId on ImageboardArchiveSearchResult {
	String get redditApiId {
		if (thread == null) {
			return 't1_${SiteReddit.toRedditId(post!.id)}';
		}
		else {
			return 't3_${SiteReddit.toRedditId(thread!.id)}';
		}
	}
}

// Accept #Header without space
class _LooseHeaderSyntax extends markdown.BlockSyntax {
	static final headerPattern = RegExp(r'^ {0,3}(#{1,6})(?:[^ \x09\x0b\x0c].*?)?(?:\s(#*)\s*)?$');
  @override
  RegExp get pattern => headerPattern;

  const _LooseHeaderSyntax();

  @override
  markdown.Node parse(markdown.BlockParser parser) {
    final match = pattern.firstMatch(parser.current.content)!;
    final matchedText = match[0]!;
    final openMarker = match[1]!;
    final closeMarker = match[2];
    final level = openMarker.length;
    final openMarkerStart = matchedText.indexOf(openMarker);
    final openMarkerEnd = openMarkerStart + level;

    String? content;
    if (closeMarker == null) {
      content = parser.current.content.substring(openMarkerEnd);
    } else {
      final closeMarkerStart = matchedText.lastIndexOf(closeMarker);
      content = parser.current.content.substring(
        openMarkerEnd,
        closeMarkerStart,
      );
    }
    content = content.trim();

    // https://spec.commonmark.org/0.30/#example-79
    if (closeMarker == null && RegExp(r'^#+$').hasMatch(content)) {
      content = null;
    }

    parser.advance();
    return markdown.Element('h$level', [if (content != null) markdown.UnparsedContent(content)]);
  }
}

const _loginFieldRedGifsTokenKey = '_rgt';

class SiteReddit extends ImageboardSite {
	(int, DateTime)? _earliestKnown;
	(int, DateTime)? _latestKnown;

	@override
	void migrateFromPrevious(SiteReddit oldSite) {
		super.migrateFromPrevious(oldSite);
		_earliestKnown = oldSite._earliestKnown;
		_latestKnown = oldSite._latestKnown;
	}

	void _updateTimeEstimateData(int id, DateTime time) {
		if (_earliestKnown == null || id < _earliestKnown!.$1) {
			_earliestKnown = (id, time);
		}
		if (_latestKnown == null || id > _latestKnown!.$1) {
			_latestKnown = (id, time);
		}
	}
	DateTime _estimateTime(int id) {
		if (_earliestKnown == null || _latestKnown == null) {
			return DateTime(2000);
		}
		final slope = (_latestKnown!.$2.millisecondsSinceEpoch - _earliestKnown!.$2.millisecondsSinceEpoch) / (_latestKnown!.$1 - _earliestKnown!.$1);
		return DateTime.fromMillisecondsSinceEpoch((slope * (id - _earliestKnown!.$1)).round() + _earliestKnown!.$2.millisecondsSinceEpoch);
	}

	SiteReddit({
		required super.overrideUserAgent,
		required super.archives,
		required super.imageHeaders,
		required super.videoHeaders
	});
	@override
	String get baseUrl => 'reddit.com';

	static const _kDeleted = '[deleted]';
	static const _kRemoved = '[removed]';

	static String toRedditId(int id) {
		if (id < 0) {
			throw FormatException('id cannot be negative', id);
		}
		return id.toRadixString(36);
	}

	static int? fromRedditId(String id) {
		return int.parse(id, radix: 36);
	}

	static final _inlineImagePattern = RegExp(r'https:\/\/(?:preview|i)\.redd\.it\/[^\r\n\t\f\v\) ]+');

	static final _inlineSyntaxes = [
		_SuperscriptSyntax(),
		_SpoilerSyntax(),
		_StrikethroughSyntax(),
		_SubredditWithoutLeadingSlashSyntax(),
		_SubredditWithLeadingSlashSyntax(),
		_UserWithoutLeadingSlashSyntax(),
		_UserWithLeadingSlashSyntax()
	];

	static PostNodeSpan makeSpan(String board, int threadId, String text, {List<Attachment> attachments = const []}) {
		text = unescape.convert(text);
		final body = parseFragment(
			markdown.markdownToHtml(
				const LooseUrlLinkifier(unescapeBackslashes: true, redditSafeMode: true).parse(
					[TextElement(text)],
					const LinkifyOptions(defaultToHttps: true, humanize: false)
				).map((e) => switch(e) {
					UrlElement() => '<a href="${const HtmlEscape(HtmlEscapeMode.attribute).convert(e.url)}">${const HtmlEscape(HtmlEscapeMode.element).convert(e.text)}</a>',
					_ => e.text
				}).join(''),
				inlineSyntaxes: _inlineSyntaxes,
				blockSyntaxes: const [
					markdown.TableSyntax(),
					markdown.BlockquoteSyntax(),
					_LooseHeaderSyntax()
				]
			).trim().replaceAll('<br />', '')
		);
		int spoilerSpanId = 0;
		Iterable<PostSpan> visit(Iterable<dom.Node> nodes, {int listDepth = 0}) sync* {
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
					else if (node.localName == 'strong') {
						yield PostBoldSpan(PostTextSpan(node.text));
					}
					else if (node.localName == 'em') {
						yield PostItalicSpan(PostTextSpan(node.text));
					}
					else if (node.localName == 'h1' || node.localName == 'h2' || node.localName == 'h3') {
						yield PostBoldSpan(PostTextSpan(node.text));
					}
					else if (node.localName == 'a') {
						final href = node.attributes['href'];
						if (href != null) {
							if (!attachments.any((a) => a.url == href) && _inlineImagePattern.hasMatch(href)) {
								yield PostAttachmentsSpan([
									Attachment(
										type: AttachmentType.image,
										board: board,
										id: href,
										ext: href.substring(href.lastIndexOf('.')).split('?').first,
										filename: href.substring(href.lastIndexOf('/') + 1).split('?').first,
										url: href,
										thumbnailUrl: generateThumbnailerForUrl(Uri.parse(href)).toString(),
										md5: '',
										width: null,
										height: null,
										threadId: threadId,
										sizeInBytes: null
									)
								]);
							}
							else {
								yield PostLinkSpan(href, name: node.text.nonEmptyOrNull);
							}
						}
						else {
							// Some edge case
							yield PostTextSpan(node.outerHtml);
						}
					}
					else if (node.localName == 'p') {
						yield* visit(node.nodes);
						addLinebreakBefore = true;
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
					else if (node.localName == 'table') {
						yield PostTableSpan(node.querySelectorAll('tr').map((tr) => tr.querySelectorAll('td,th').map((td) => PostNodeSpan(visit(td.nodes).toList())).toList()).toList());
					}
					else if (node.localName == 'hr') {
						yield const PostDividerSpan();
					}
					else if (node.localName == 'sup') {
						yield PostSuperscriptSpan(PostTextSpan(node.text));
					}
					else if (node.localName == 'spoiler') {
						yield PostSpoilerSpan(PostTextSpan(node.text), spoilerSpanId++);
					}
					else if (node.localName == 'strikethrough') {
						yield PostStrikethroughSpan(PostTextSpan(node.text));
					}
					else if (node.localName == 'blockquote') {
						final text = node.text.trim();
						if (text.startsWith('!') && text.endsWith('!<') && text.length > 3) {
							// Mis-parsed spoiler (at beginning of line, it also starts with ">")
							yield PostSpoilerSpan(PostNodeSpan(Site4Chan.parsePlaintext(text.substring(1, text.length - 2))), spoilerSpanId++);
						}
						else {
							yield PostQuoteSpan(PostNodeSpan(visit(node.nodes.trim()).toList()));
						}
					}
					else if (node.localName == 'pre') {
						yield PostCodeSpan(node.text.trimRight());
						addLinebreakBefore = true;
					}
					else if (node.localName == 'code') {
						yield PostCodeSpan(node.text);
					}
					else if (node.localName == 'crosspostparent') {
						yield PostQuoteLinkSpan(
							board: node.attributes['board']!,
							threadId: fromRedditId(node.attributes['id']!)!,
							postId: fromRedditId(node.attributes['id']!)!
						);
					}
					else if (node.localName == _kSubredditLinkLocalName) {
						yield PostBoardLinkSpan(node.text);
					}
					else if (node.localName == _kUserLinkLocalName) {
						yield PostUserLinkSpan(node.text);
					}
					else if (node.localName == 'img' && (node.attributes['src']?.startsWith('emote|') ?? false)) {
						final parts = node.attributes['src']?.split('|') ?? [];
						if (parts.length == 3) {
							yield PostInlineImageSpan(
								src: Uri.https('www.redditstatic.com', '/marketplace-assets/v1/core/emotes/snoomoji_emotes/${parts[1]}/${parts[2]}.gif').toString(),
								width: 16,
								height: 16
							);
						}
						else {
							// Give up
							yield PostTextSpan(node.outerHtml);
						}
					}
					else if (node.localName == 'img' && (node.attributes['src']?.startsWith('giphy%7C') ?? false)) {
						final giphyId = Uri.decodeComponent(node.attributes['src']!).split('|')[1];
						yield PostAttachmentsSpan([
							Attachment(
								board: board,
								type: AttachmentType.image,
								ext: '.gif',
								id: giphyId,
								filename: 'giphy.gif',
								url: 'https://media.giphy.com/media/$giphyId/giphy.gif',
								thumbnailUrl: 'https://media.giphy.com/media/$giphyId/200w_s.gif',
								md5: '',
								width: null,
								height: null,
								threadId: threadId,
								sizeInBytes: null
							)
						]);
					}
					else if (node.localName == 'img' && node.attributes.containsKey('src')) {
						String src = node.attributes['src']!;
						if (!attachments.any((a) => a.url == src) && _inlineImagePattern.hasMatch(src)) {
							yield PostAttachmentsSpan([
								Attachment(
										type: AttachmentType.image,
										board: board,
										id: src,
										ext: src.substring(src.lastIndexOf('.')).split('?').first,
										filename: src.substring(src.lastIndexOf('/') + 1).split('?').first,
										url: src,
										thumbnailUrl: generateThumbnailerForUrl(Uri.parse(src)).toString(),
										md5: '',
										width: null,
										height: null,
										threadId: threadId,
										sizeInBytes: null
									)
							]);
						}
						else if (!src.contains('.')) {
							final url = Uri.https('i.redd.it', '/$src.gif');
							yield PostAttachmentsSpan([
								Attachment(
									board: board,
									type: AttachmentType.image,
									ext: '.gif',
									id: src,
									filename: '$src.gif',
									url: url.toString(),
									thumbnailUrl: generateThumbnailerForUrl(url).toString(),
									md5: '',
									width: null,
									height: null,
									threadId: threadId,
									sizeInBytes: null
								)
							]);
						}
						else {
							yield PostInlineImageSpan(
								src: src,
								width: node.attributes['height']?.tryParseInt ?? 16,
								height: node.attributes['width']?.tryParseInt ?? 16
							);
						}
					}
					else if (node.attributes.values.every((v) => v.isEmpty)) {
						// Some joker made up their own span
						yield PostTextSpan('<${[node.localName, ...node.attributes.keys].join(' ')}>');
						yield const PostLineBreakSpan();
						yield* visit(node.children);
					}
					else {
						yield PostTextSpan(node.outerHtml);
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
	Future<PostReceipt> submitPost(DraftPost post, CaptchaSolution captchaSolution, CancelToken cancelToken) {
		// TODO: implement submitPost
		throw UnimplementedError();
	}

	bool _isShareLink(Uri url) {
		if (url.host == 'reddit.app.link') {
			return true;
		}
		if (
			url.host.endsWith(baseUrl)
			&& url.pathSegments.length >= 3
			&& url.pathSegments[0] == 'r'
			&& url.pathSegments[2] == 's'
		) {
			return true;
		}
		return false;
	}

	bool _isCommentsLink(Uri url) {
		return
			url.host.endsWith(baseUrl)
			&& url.pathSegments.length >= 4
			&& url.pathSegments[0] == 'comments'
			&& url.pathSegments[2] == 'comment';
	}

	static final _linkPattern = RegExp(r'^\/r\/([^\/\n]+)(?:\/comments\/([^\/\n]+)(?:\/[^\/\n]+\/([^?\/\n]+))?)?');
	static final _redditProtocolPattern = RegExp(r'reddit:\/\/([^ ]+)');

	@override
	Future<BoardThreadOrPostIdentifier?> decodeUrl(Uri url) async {
		if (_isShareLink(url) || _isCommentsLink(url)) {
			final response = await client.getUri<String>(url, options: Options(
				responseType: ResponseType.plain
			));
			Uri? redirected = response.redirects.tryLast?.location;
			if (redirected != null && !_isShareLink(redirected) && !_isCommentsLink(redirected)) {
				return await decodeUrl(Uri.https(baseUrl).resolve(redirected.toString()));
			}
			// Look for "reddit:///r/subreddit/..." in the JavaScript redirect page
			final redditProtocolMatch = _redditProtocolPattern.firstMatch(response.data ?? '');
			if (redditProtocolMatch != null) {
				return await decodeUrl(Uri.https(baseUrl, redditProtocolMatch.group(1)!));
			}
		}
		if (url.host.endsWith(baseUrl)) {
			final match = _linkPattern.firstMatch(url.path);
			if (match != null) {
				int? threadId;
				int? postId;
				if (match.group(2) case String threadIdStr) {
					threadId = fromRedditId(threadIdStr);
					if (match.group(3) case String postIdStr) {
						postId = fromRedditId(postIdStr.split('?').first);
					}
				}
				return BoardThreadOrPostIdentifier(Uri.decodeComponent(match.group(1)!), threadId, postId);
			}
		}
		return null;
	}

	ImageboardBoard _makeBoard(Map data) => ImageboardBoard(
		name: data['display_name'] as String,
		title: data['public_description'] as String,
		isWorksafe: data['over18'] == false,
		webmAudioAllowed: true,
		icon: switch (data['icon_img']) {
			'' => null,
			String x => Uri.parse(x),
			_ => null
		},
		popularity: data['subscribers'] as int?
	);

	Future<String> _getRedgifsToken() async {
		final response = await client.getUri<Map>(Uri.https('api.redgifs.com', '/v2/auth/temporary'), options: Options(
			extra: {
				kPriority: RequestPriority.cosmetic
			},
			responseType: ResponseType.json
		));
		return response.data!['token'] as String;
	}

	/// Resolve image hosting sites to hotlinks
	Future<List<({String url, String? thumbnailUrl, AttachmentType type, String ext})>?> _resolveUrl0(Uri uri, {CancelToken? cancelToken}) async {
		try {
			if ((uri.host == 'imgur.com' || uri.host == 'imgur.io' || uri.host == 'i.imgur.com' || uri.host == 'i.imgur.io') && (uri.pathSegments.trySingle?.length ?? 0) > 2) {
				final hash = uri.pathSegments.single.beforeFirst('.');
				final response = await client.getUri<Map>(Uri.https('api.imgur.com', '/3/image/$hash'), options: Options(
					headers: {
						'Authorization': 'Client-ID 714791ea4513f83'
					},
					extra: {
						kPriority: RequestPriority.cosmetic
					},
					responseType: ResponseType.json
				), cancelToken: cancelToken);
				if (response.data case {'data': {'link': String link}}) {
					return [(
						url: link,
						thumbnailUrl: link.replaceFirstMapped(RegExp(r'\.([^.]+)$'), (m) {
							return 'm.${m.group(1)}';
						}),
						type: AttachmentType.image,
						ext: '.${link.afterLast('.')}'
					)];
				}
			}
			if ((uri.host == 'imgur.com' || uri.host == 'imgur.io') && (uri.pathSegments.length == 2) && (uri.pathSegments.first == 'a')) {
				final hash = uri.pathSegments[1];
				final response = await client.getUri<Map>(Uri.https('api.imgur.com', '/3/album/$hash/images'), options: Options(
					headers: {
						'Authorization': 'Client-ID 714791ea4513f83'
					},
					extra: {
						kPriority: RequestPriority.cosmetic
					},
					responseType: ResponseType.json
				), cancelToken: cancelToken);
				if (response.data!['data'] case List imageData when imageData.isNotEmpty) {
					return imageData.cast<Map>().expand((image) {
						final link = image['link'] as String;
						return [(
							url: link,
							thumbnailUrl: link.replaceFirstMapped(RegExp(r'\.([^.]+)$'), (m) {
								return 'm.${m.group(1)}';
							}),
							type: AttachmentType.image,
							ext: '.${link.afterLast('.')}'
						)];
					}).toList();
				}
			}
			else if (uri.host == 'gfycat.com' && (uri.pathSegments.trySingle?.length ?? 0) > 2) {
				final hash = uri.pathSegments.single.split('-').first;
				final response = await client.getUri(Uri.https('api.gfycat.com', '/v1/gfycats/$hash'), options: Options(
					headers: {
						'Authorization': '2_YQH1hg'
					},
					extra: {
						kPriority: RequestPriority.cosmetic
					},
					validateStatus: (status) => (status != null) && ((status >= 200 && status < 300) || (status == 404))
				), cancelToken: cancelToken);
				if (response.statusCode == 404) {
					// Sometimes gfycat redirects to redgifs
					final redirectResponse = await client.headUri(uri, options: Options(
						extra: {
							kPriority: RequestPriority.cosmetic
						},
						responseType: ResponseType.json
					), cancelToken: cancelToken);
					if (!redirectResponse.realUri.host.contains('gfycat')) {
						return _resolveUrl0(redirectResponse.realUri);
					}
				}
				else if (response.data case {'gfyItem': Map gfyItem && {'mp4Url': String link}}) {
					return [(
						url: link,
						thumbnailUrl: gfyItem['miniPosterUrl'] as String?,
						type: AttachmentType.mp4,
						ext: '.mp4'
					)];
				}
			}
			else if (uri.host == 'i.reddituploads.com') {
				return [(
					url: uri.toString(),
					thumbnailUrl: null,
					type: AttachmentType.image,
					ext: '.jpeg'
				)];
			}
			else if (uri.host.endsWith('redgifs.com') && uri.pathSegments.length == 2 && uri.pathSegments[0] == 'watch' && persistence != null) {
				final id = uri.pathSegments[1];
				String redGifsToken = '';
				Response<Map>? response;
				try {
					redGifsToken = await persistence!.browserState.loginFields.putIfAbsentAsync(_loginFieldRedGifsTokenKey, _getRedgifsToken);
					response = await client.getUri(Uri.https('api.redgifs.com', '/v2/gifs/$id'), options: Options(
						headers: {
							'Authorization': 'Bearer $redGifsToken'
						},
						extra: {
							kPriority: RequestPriority.cosmetic
						},
						responseType: ResponseType.json
					), cancelToken: cancelToken);
				}
				catch (e) {
					if (e is DioError && e.response?.statusCode == 401 && redGifsToken.isNotEmpty) {
						// Token expired?
						redGifsToken = persistence!.browserState.loginFields[_loginFieldRedGifsTokenKey] = await _getRedgifsToken();
						response = await client.getUri(Uri.https('api.redgifs.com', '/v2/gifs/$id'), options: Options(
							headers: {
								'Authorization': 'Bearer $redGifsToken'
							},
							extra: {
								kPriority: RequestPriority.cosmetic
							},
							responseType: ResponseType.json
						), cancelToken: cancelToken);
					}
					else {
						rethrow;
					}
				}
				if (response.data case {'gif': {'urls': Map urls && ({'hd': String url} || {'sd': String url})}}) {
					return [(
						url: url,
						thumbnailUrl: urls['thumbnailUrl'] as String?,
						type: AttachmentType.mp4,
						ext: '.mp4'
					)];
				}
			}
		}
		catch (e, st) {
			Future.error(e, st);
		}
		return null;
	}

	Future<List<({String url, String? thumbnailUrl, AttachmentType type, String ext})>> _resolveUrl1(Uri uri, {CancelToken? cancelToken}) async {
		final results = await _resolveUrl0(uri, cancelToken: cancelToken);
		if (results != null) {
			return results;
		}
		// fallback to direct link
		bool isDirectLink = ['.png', '.jpg', '.jpeg', '.gif'].any((e) => uri.path.endsWith(e));
		return [(
			url: uri.toString(),
			thumbnailUrl: null,
			type: isDirectLink ? AttachmentType.image : AttachmentType.url,
			ext: isDirectLink ? '.${uri.path.afterLast('.')}' : ''
		)];
	}

	@override
	bool embedPossible(Uri url) {
		if ((url.host == 'imgur.com' || url.host == 'imgur.io' || url.host == 'i.imgur.com' || url.host == 'i.imgur.io') && (url.pathSegments.trySingle?.length ?? 0) > 2) {
			return true;
		}
		if ((url.host == 'imgur.com' || url.host == 'imgur.io') && (url.pathSegments.length == 2) && (url.pathSegments.first == 'a')) {
			return true;
		}
		if (url.host == 'gfycat.com' && (url.pathSegments.trySingle?.length ?? 0) > 2) {
			return true;
		}
		if (url.host == 'i.reddituploads.com') {
			return true;
		}
		if (url.host.endsWith('redgifs.com') && url.pathSegments.length == 2 && url.pathSegments[0] == 'watch' && persistence != null) {
			return true;
		}
		return false;
	}

	@override
	Future<List<Attachment>> loadEmbedData(Uri url, {CancelToken? cancelToken}) async {
		final datas = await _resolveUrl0(url, cancelToken: cancelToken);
		return datas?.map((data) => Attachment(
			type: data.type,
			board: '',
			id: data.url,
			ext: data.ext,
			filename: FileBasename.get(data.url),
			url: data.url,
			thumbnailUrl: data.thumbnailUrl ?? '',
			md5: '',
			width: null,
			height: null,
			threadId: null,
			sizeInBytes: null
		)).toList() ?? [];
	}

	Future<Thread> _makeThread(Map data, {CancelToken? cancelToken}) async {
		final id = fromRedditId(data['id'] as String)!;
		final attachments = <Attachment>[];
		Future<void> dumpAttachments(Map data) async {
			if (data['media_metadata'] case Map mediaMetadata) {
				for (final item in mediaMetadata.values.cast<Map>()) {
					if (item['m'] == null && item['e'] == 'RedditVideo') {
						attachments.add(Attachment(
							type: AttachmentType.mp4,
							board: data['subreddit'] as String,
							threadId: id,
							id: item['id'] as String,
							ext: '.mp4',
							filename: '${item['id']}.mp4',
							url: unescape.convert(item['hlsUrl'] as String),
							thumbnailUrl: '',
							md5: '',
							width: item['x'] as int?,
							height: item['y'] as int?,
							sizeInBytes: null
						));
					}
					else if (item case {
						'id': String itemId,
						'm': String m,
						's': Map s && ({'u': String url} || {'gif': String url}),
						'p': List p
					}) {
						final ext = '.${m.afterLast('/')}';
						attachments.add(Attachment(
							type: AttachmentType.image,
							board: data['subreddit'] as String,
							threadId: id,
							id: itemId,
							ext: ext,
							filename: itemId + ext,
							url: unescape.convert(url),
							thumbnailUrl: switch (p) {
								[{'u': String u}, ...] => unescape.convert(u),
								_ => ''
							},
							md5: '',
							width: s['x'] as int?,
							height: s['y'] as int?,
							sizeInBytes: null
						));
					}
				}
			}
			else if (data case {
				'subreddit': String subreddit,
				'name': String name,
				'secure_media': {'reddit_video': Map redditVideo && {'hls_url': String hlsUrl}}
			}) {
				attachments.add(Attachment(
					type: AttachmentType.mp4,
					board: subreddit,
					threadId: id,
					id: name,
					ext: '.mp4',
					filename: 'video.mp4',
					url: unescape.convert(hlsUrl),
					thumbnailUrl: switch (data['preview']) {
						{'images': [{'resolutions': [{'url': String url}, ...]}, ...]} => unescape.convert(url),
						_ => ''
					},
					md5: '',
					width: redditVideo['width'] as int?,
					height: redditVideo['height'] as int?,
					sizeInBytes: null
				));
			}
			else if (data case {
				'subreddit': String subreddit,
				'name': String name,
				'preview': Map preview
			}) {
				if (preview case {
					'reddit_video_preview': Map redditVideoPreview && {'hls_url': String hlsUrl}
				}) {
					attachments.add(Attachment(
						type: AttachmentType.mp4,
						board: subreddit,
						threadId: id,
						id: name,
						ext: '.mp4',
						filename: 'video.mp4',
						url: unescape.convert(hlsUrl),
						thumbnailUrl: switch (preview) {
							{'images': [{'resolutions': [{'url': String url}, ...]}, ...]} => unescape.convert(url),
							_ => ''
						},
						md5: '',
						width: redditVideoPreview['width'] as int?,
						height: redditVideoPreview['height'] as int?,
						sizeInBytes: null
					));
				}
				else if (data case {'url': String url}) {
					final urls = await _resolveUrl1(Uri.parse(url), cancelToken: cancelToken);
					final image0 = (preview['images'] as List?)?.tryFirst as Map?;
					attachments.addAll(urls.indexed.map((url) => Attachment(
						type: url.$2.type,
						board: subreddit,
						threadId: id,
						id: '${name}_${url.$1}',
						ext: url.$2.ext,
						filename: Uri.tryParse(url.$2.url)?.pathSegments.tryLast ?? '',
						url: url.$2.url,
						width: (image0?['source'] as Map?)?['width'] as int?,
						height: (image0?['source'] as Map?)?['height'] as int?,
						md5: '',
						sizeInBytes: null,
						thumbnailUrl: url.$2.thumbnailUrl ?? switch (image0) {
							{'resolutions': [{'url': String url}, ...]} => unescape.convert(url),
							_ => generateThumbnailerForUrl(Uri.parse(url.$2.url)).toString()
						}
					)));
				}
			}
			else if (data['is_self'] != true && data['url'] != null) {
				final urls = await _resolveUrl1(Uri.parse(data['url'] as String), cancelToken: cancelToken);
				attachments.addAll(urls.indexed.map((url) => Attachment(
					type: url.$2.type,
					board: data['subreddit'] as String,
					threadId: id,
					id: '${data['name']}_${url.$1}',
					ext: url.$2.ext,
					filename: Uri.tryParse(url.$2.url)?.pathSegments.tryLast ?? '',
					url: url.$2.url,
					thumbnailUrl: url.$2.thumbnailUrl ?? generateThumbnailerForUrl(Uri.parse(url.$2.url)).toString(),
					md5: '',
					width: null,
					height: null,
					sizeInBytes: null
				)));
			}
			final galleryMap = switch (data) {
				{'gallery_data': {'items': List galleryItems}} => {
					for (final (i, item) in galleryItems.cast<Map>().indexed)
						item['media_id'] as String: (i, item['caption'] as String?)
				},
				_ => <String, (int, String?)>{}
			};
			const infiniteIndex = 1 << 50;
			mergeSort(attachments, compare: (a, b) {
				final idxA = galleryMap[a.id]?.$1 ?? infiniteIndex;
				final idxB = galleryMap[b.id]?.$1 ?? infiniteIndex;
				return idxA.compareTo(idxB);
			});
			for (final attachment in attachments) {
				final caption = galleryMap[attachment.id]?.$2;
				if (caption != null) {
					attachment.filename = caption + attachment.ext;
				}
			}
		}
		final url = data['url'] as String;
		String text = '';
		if (data['is_self'] as bool? ?? false) {
			text = data['selftext'] as String? ?? '';
		}
		else {
			String title = url;
			if (title.startsWith('https://')) {
				title = title.substring(8);
			}
			// The max(30) is to be more lenient on short URLs
			// Likely the query param holds the link entropy there
			final anchorPosition = title.indexOf('#');
			if (anchorPosition != -1 && max(30, anchorPosition) < title.length * 0.65) {
				title = title.substring(0, anchorPosition);
			}
			final queryPosition = title.indexOf('?');
			if (queryPosition != -1 && max(30, queryPosition) < title.length * 0.65) {
				title = title.substring(0, queryPosition);
			}
			text = '[$title]($url)';
			if ((data['selftext'] as String? ?? '').isNotEmpty) {
				text += '\n\n${data['selftext']}';
			}
		}
		final crosspostParent = (data['crosspost_parent_list'] as List?)?.cast<Map>().tryFirstWhere((xp) => xp['name'] == data['crosspost_parent']);
		if (crosspostParent != null) {
			await dumpAttachments(crosspostParent);
			text = '<crosspostparent board="${crosspostParent['subreddit']}" id="${crosspostParent['id']}"></crosspostparent>\n$text';
		}
		if (attachments.isEmpty) {
			await dumpAttachments(data);
		}
		final author = data['author'] as String;
		final authorIsDeleted = author == _kDeleted;
		final textIsDeleted = text == _kRemoved || text == _kDeleted;
		final asPost = Post(
			board: data['subreddit'] as String,
			name: authorIsDeleted ? '' : author,
			flag: _makeFlag(data['author_flair_richtext'] as List?, data),
			time: DateTime.fromMillisecondsSinceEpoch((data['created'] as num).toInt() * 1000),
			threadId: id,
			id: id,
			text: textIsDeleted ? '' : text,
			spanFormat: PostSpanFormat.reddit,
			isDeleted: authorIsDeleted || textIsDeleted,
			attachments_: data['is_self'] == true ? [] : attachments,
			upvotes: (data['score_hidden'] == true || data['hide_score'] == true) ? null : data['score'] as int?,
			capcode: data['distinguished'] as String?
		);
		_updateTimeEstimateData(asPost.id, asPost.time);
		return Thread(
			board: data['subreddit'] as String,
			title: unescape.convert(data['title'] as String).trim().nonEmptyOrNull,
			isSticky: data['stickied'] as bool,
			time: asPost.time,
			posts_: [asPost],
			attachments: asPost.attachments_,
			replyCount: data['num_comments'] as int,
			imageCount: 0,
			isDeleted: asPost.isDeleted,
			isNsfw: data['over_18'] == true,
			flair: _makeFlag(data['link_flair_richtext'] as List?, data) ?? (
				data['link_flair_text'] == null ? null : ImageboardFlag.text((data['link_flair_text'] as String).unescapeHtml)
			),
			id: id,
			suggestedVariant: switch (data['suggested_sort']) {
				'' => null,
				String x => _RedditApiName.toVariant(x),
				_ => null
			},
			poll: switch (data['poll_data']) {
				Map m => ImageboardPoll(
					title: null,
					rows: (m['options'] as List).cast<Map>().map((o) => ImageboardPollRow(
						name: o['text'] as String,
						votes: o['vote_count'] as int? ?? 0 // Just show the choices if the poll isn't done yet
					)).toList(growable: false)
				),
				_ => null
			}
		);
	}

	@override
	String get defaultUsername => '';

	@override
	Map<String, String> getHeaders(Uri url) {
		if (url.host == 'v.redd.it') {
			return {
				...super.getHeaders(url),
				'Origin': 'https://www.reddit.com',
				'Sec-Fetch-Site': 'cross-site',
				'Sec-Fetch-Mode': 'cors',
				'Sec-Fetch-Dest': 'empty',
				'Sec-Ch-Ua-Mobile': '?0',
				'Sec-Ch-Ua': '"Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"',
				'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
			};
		}
		return super.getHeaders(url);
	}

	@override
	Future<List<ImageboardBoard>> getBoards({required RequestPriority priority, CancelToken? cancelToken}) async {
		final response = await client.getUri<Map>(Uri.https(baseUrl, '/subreddits/popular.json'), options: Options(
			extra: {
				kPriority: priority
			},
			responseType: ResponseType.json
		), cancelToken: cancelToken);
		return ((response.data!['data'] as Map)['children'] as List).cast<Map>().map((c) => _makeBoard(c['data'] as Map)).toList();
	}

	@override
	ImageboardBoardPopularityType? get boardPopularityType => ImageboardBoardPopularityType.subscriberCount;

	@override
	Future<List<ImageboardBoard>> getBoardsForQuery(String query) async {
		final response = await client.getUri<Map>(Uri.https('api.$baseUrl', '/subreddits/search', {
			'q': query,
			'typeahead_active': 'true'
		}), options: Options(responseType: ResponseType.json));
		return ((response.data!['data'] as Map)['children'] as List).cast<Map>().map((c) => _makeBoard(c['data'] as Map)).toList();
	}

	@override
	Future<CaptchaRequest> getCaptchaRequest(String board, int? threadId, {CancelToken? cancelToken}) async {
		return const NoCaptchaRequest();
	}

	Future<void> _updateBoardIfNeeded(String board, {required RequestPriority priority, CancelToken? cancelToken}) async {
		final old = persistence?.maybeGetBoard(board);
		final boardAge = DateTime.now().difference(old?.additionalDataTime ?? DateTime(2000));
		if (boardAge > const Duration(days: 3) || old?.popularity == null) {
			final ImageboardBoard newBoard;
			if (board == 'popular' || board == 'all') {
				newBoard = ImageboardBoard(
					name: board,
					title: 'Top posts across $board subreddits',
					isWorksafe: true,
					webmAudioAllowed: true,
					additionalDataTime: DateTime.now()
				);
			}
			else {
				final response = await client.getUri<Map>(Uri.https(baseUrl, '/r/$board/about.json'), options: Options(
					extra: {
						kPriority: priority
					},
					responseType: ResponseType.json
				), cancelToken: cancelToken);
				newBoard = _makeBoard(response.data!['data'] as Map)..additionalDataTime = DateTime.now();
			}
			await persistence?.setBoard(board, newBoard);
			persistence?.didUpdateBrowserState();
		}
	}

	static (String, Map<String, String>) _getCatalogSuffix(CatalogVariant? variant) => const {
			CatalogVariant.redditHot: ('/hot.json', <String, String>{}),
			CatalogVariant.redditNew: ('/new.json', <String, String>{}),
			CatalogVariant.redditRising: ('/rising.json', <String, String>{}),
			CatalogVariant.redditControversialPastHour: ('/controversial.json', {'t': 'hour'}),
			CatalogVariant.redditControversialPast24Hours: ('/controversial.json', {'t': 'day'}),
			CatalogVariant.redditControversialPastWeek: ('/controversial.json', {'t': 'week'}),
			CatalogVariant.redditControversialPastMonth: ('/controversial.json', {'t': 'month'}),
			CatalogVariant.redditControversialPastYear: ('/controversial.json', {'t': 'year'}),
			CatalogVariant.redditControversialAllTime: ('/controversial.json', {'t': 'all'}),
			CatalogVariant.redditTopPastHour: ('/top.json', {'t': 'hour'}),
			CatalogVariant.redditTopPast24Hours: ('/top.json', {'t': 'day'}),
			CatalogVariant.redditTopPastWeek: ('/top.json', {'t': 'week'}),
			CatalogVariant.redditTopPastMonth: ('/top.json', {'t': 'month'}),
			CatalogVariant.redditTopPastYear: ('/top.json', {'t': 'year'}),
			CatalogVariant.redditTopAllTime: ('/top.json', {'t': 'all'}),
		}[variant] ?? ('.json', <String, String>{});

	@override
	Future<Catalog> getCatalogImpl(String board, {CatalogVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) async {
		try {
			await _updateBoardIfNeeded(board, priority: priority, cancelToken: cancelToken);
		}
		catch (e, st) {
			Future.error(e, st);
		}
		final suffix = _getCatalogSuffix(variant);
		final response = await client.getUri<Map>(Uri.https(baseUrl, '/r/$board${suffix.$1}', suffix.$2), options: Options(
			extra: {
				kPriority: priority
			},
			responseType: ResponseType.json
		), cancelToken: cancelToken);
		final threads = await Future.wait(((response.data!['data'] as Map)['children'] as List).cast<Map>().map((d) async {
			final t = await _makeThread(d['data'] as Map, cancelToken: cancelToken);
			t.currentPage = 1;
			return t;
		}));
		return Catalog(
			threads: threads,
			lastModified: null // No 304 handling
		);
	}

	@override
	Future<List<Post>> getStubPosts(ThreadIdentifier thread, List<ParentAndChildIdentifier> postIds, {required RequestPriority priority, CancelToken? cancelToken}) async {
		final ret = <Post>[];
		final childIdsToGet = postIds.take(20).toList();
		final newPosts = <int, Post>{};
		final Set<int> newPostsWithReplies = {};
		if (childIdsToGet.isNotEmpty) {
			final response = await client.getUri<Map>(Uri.https(baseUrl, '/api/morechildren', {
				'link_id': 't3_${toRedditId(thread.id)}',
				'children': 'c1:${childIdsToGet.map((cid) => 't1_${toRedditId(cid.childId)}').join(',')}',
				'api_type': 'json',
				'renderstyle': 'html',
				'r': thread.board
			}), options: Options(
				extra: {
					kPriority: priority
				},
				responseType: ResponseType.json
			), cancelToken: cancelToken);
			final things = switch(response.data) {
				{'json': {'data': {'things': List things}}} => things.cast<Map>(),
				_ => throw PatternException(response.data, 'Bad morechildren resp')
			};
			for (final thing in things) {
				final data = thing['data'] as Map;
				final parentId = fromRedditId((data['parent'] as String).split('_')[1]);
				if (thing['kind'] == 'more' || data['id'] == 't1__') {
					newPosts[parentId]?.hasOmittedReplies = true;
				}
				else {
					final id = fromRedditId((data['id'] as String).split('_')[1])!;
					final doc = parseFragment(HtmlUnescape().convert(data['content'] as String));
					ImageboardMultiFlag? flag;
					final flair = doc.querySelector('.flairrichtext');
					if (flair != null) {
						flag = ImageboardMultiFlag(
							parts: flair.children.map((c) {
								final imageUrl = RegExp(r'background-image: *url\((.*)\)').firstMatch(c.attributes['style'] ?? '')?.group(1);
								return ImageboardFlag(
									imageHeight: imageUrl == null ? 0 : 16,
									imageWidth: imageUrl == null ? 0 : 16,
									name: c.text,
									imageUrl: imageUrl ?? ''
								);
							}).toList()
						);
					}
					final html = unescape.convert(data['contentHTML'] as String);
					final text = (data['contentText'] as String).replaceAllMapped(RegExp(r'!\[img\]\(([^)]+)\)'), (match) {
						final regex = r'href="([^"]+' + match.group(1)! + r'[^"]+)"';
						final matchInHtml = RegExp(regex).firstMatch(html)?.group(1);
						if (matchInHtml != null) {
							return '![img]($matchInHtml)';
						}
						return match.group(0)!;
					});
					final author = doc.querySelector('.author')?.text ?? '';
					final authorIsDeleted = author == _kDeleted;
					final textIsDeleted = text == _kRemoved || text == _kDeleted;
					final post = Post(
						board: thread.board,
						text: textIsDeleted ? '' : text,
						name: authorIsDeleted ? '' : author,
						isDeleted: authorIsDeleted || textIsDeleted,
						flag: flag,
						time: DateTime.tryParse(doc.querySelector('.live-timestamp')?.attributes['datetime'] ?? '') ?? _estimateTime(id),
						threadId: thread.id,
						parentId: parentId,
						id: id,
						spanFormat: PostSpanFormat.reddit,
						attachments_: const [],
						upvotes: doc.querySelector('.score.unvoted')?.attributes['title']?.tryParseInt
					);
					_updateTimeEstimateData(post.id, post.time);
					newPosts[id] = post;
					if (!(doc.querySelector('.numchildren')?.text.contains('(0 children)') ?? true)) {
						newPostsWithReplies.add(id);
					}
				}
			}
		}
		final newPostsMatched = newPosts.values.toList();
		for (final id in childIdsToGet) {
			final newPost = newPosts[id.childId];
			if (newPost != null) {
				newPosts[newPost.parentId]?.maybeAddReplyId(id.childId);
				ret.add(newPost);
				newPostsMatched.remove(newPost);
			}
			else {
				ret.add(Post(
					board: thread.board,
					text: '[shadowbanned]',
					name: '[shadowbanned]',
					time: _estimateTime(id.childId),
					threadId: thread.id,
					id: id.childId,
					spanFormat: PostSpanFormat.reddit,
					attachments_: [],
					parentId: id.parentId
				));
			}
		}
		for (final unmatchedPost in newPostsMatched) {
			newPosts[unmatchedPost.parentId]?.maybeAddReplyId(unmatchedPost.id);
			ret.add(unmatchedPost);
		}
		for (final id in newPostsWithReplies) {
			if (newPosts[id]?.replyIds.isEmpty ?? false) {
				newPosts[id]?.hasOmittedReplies = true;
			}
		}
		return ret;
	}

	@override
	Future<List<Thread>> getMoreCatalogImpl(String board, Thread after, {CatalogVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) async {
		final suffix = _getCatalogSuffix(variant);
		final response = await client.getUri<Map>(Uri.https(baseUrl, '/r/$board${suffix.$1}', {
			'after': 't3_${toRedditId(after.id)}',
			...suffix.$2
		}), options: Options(
			extra: {
				kPriority: priority
			},
			responseType: ResponseType.json
		), cancelToken: cancelToken);
		final newPage = (after.currentPage ?? 1) + 1;
		final children = switch (response.data) {
			{'data': {'children': List children}} => children,
			_ => throw PatternException(response.data)
		};
		return await Future.wait(children.cast<Map>().map((d) async {
			final t = await _makeThread(d['data'] as Map, cancelToken: cancelToken);
			t.currentPage = newPage;
			return t;
		}));
	}

	@override
	Future<Post> getPostFromArchive(String board, int id, {required RequestPriority priority, CancelToken? cancelToken}) {
		// TODO: implement getPostFromArchive
		throw UnimplementedError();
	}

	Flag? _makeFlag(List? data, Map parentData) {
		if (data == null || data.isEmpty) {
			return null;
		}
		final parts = <ImageboardFlag>[];
		for (final part in data.cast<Map>()) {
			if (part['e'] == 'text') {
				final emoteMatch = _emotePattern.firstMatch(part['t'] as String? ?? '');
				if (emoteMatch != null) {
					final emote = (parentData['media_metadata'] as Map?)?[emoteMatch.group(1)];
					// Tbh this usually doesn't work because Reddit only returns emote
					// metadata that was also used in the text. But best effort...
					if (emote is Map) {
						parts.add(ImageboardFlag(
							name: '',
							imageUrl: emote['u'] as String,
							imageWidth: (emote['x'] as int? ?? 16).toDouble(),
							imageHeight: (emote['y'] as int? ?? 16).toDouble()
						));
						continue;
					}
				}
				final text = (part['t'] as String?)?.trim().unescapeHtml;
				if (text != null && !parts.any((t) => t.name == text)) {
					parts.add(ImageboardFlag.text(text));
				}
			}
			else {
				final text = ((part['a'] as String?) ?? '').replaceAll(':', '').trim().unescapeHtml;
				parts.removeWhere((p) => p.name == text);
				parts.add(ImageboardFlag(
					imageHeight: 16,
					imageWidth: 16,
					imageUrl: part['u'] as String,
					name: text
				));
			}
		}
		return ImageboardMultiFlag(parts: parts);
	}

	static final _emotePattern = RegExp(r'!\[img\]\((emote|[^)]+)\)');

	Post _makePost(Map child, {int? parentId, required ThreadIdentifier thread}) {
		final id = fromRedditId(child['id'] as String)!;
		final text = unescape.convert(child['body'] as String).replaceAllMapped(_emotePattern, (match) {
			final metadata = (child['media_metadata'] as Map?)?[match.group(1)] as Map?;
			if (metadata == null) {
				return match.group(0)!;
			}
			final s = metadata['s'] as Map;
			return '<img src="${s['u']}" width="${s['x']}" height="${s['y']}">';
		});
		final author = child['author'] as String;
		final authorIsDeleted = author == _kDeleted;
		final textIsDeleted = text == _kRemoved || text == _kDeleted;
		return Post(
			board: thread.board,
			text: textIsDeleted ? '' : text,
			name: authorIsDeleted ? '' : author,
			isDeleted: authorIsDeleted || textIsDeleted,
			flag: _makeFlag(child['author_flair_richtext'] as List?, child),
			time: DateTime.fromMillisecondsSinceEpoch((child['created'] as num).toInt() * 1000),
			threadId: thread.id,
			id: id,
			spanFormat: PostSpanFormat.reddit,
			attachments_: const [],
			parentId: parentId,
			upvotes: (child['score_hidden'] == true || child['hide_score'] == true) ? null : child['score'] as int?,
			capcode: child['distinguished'] as String?
		);
	}

	@override
	Future<Thread> getThreadImpl(ThreadIdentifier thread, {ThreadVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) async {
		final response = await client.getThreadUri(Uri.https(baseUrl, '/r/${thread.board}/comments/${toRedditId(thread.id)}.json', {
			if (variant?.redditApiName != null) 'sort': variant!.redditApiName!
		}), priority: priority, responseType: ResponseType.json, cancelToken: cancelToken);
		final (opData, repliesData) = switch(response.data) {
			[
				{'data': {'children': [{'data': Map data}, ...]}},
				{'data': {'children': List children}},
				...
			] => (data, children),
			_ => throw PatternException(response.data)
		};
		final ret = await _makeThread(opData, cancelToken: cancelToken);
		addChildren(int parentId, List<dynamic> childData, Post? parent) {
			for (final childContainer in childData.cast<Map>()) {
				final child = childContainer['data'] as Map;
				if (childContainer['kind'] == 't1') {
					final post = _makePost(child, parentId: parentId, thread: thread);
					ret.posts_.add(post);
					_updateTimeEstimateData(post.id, post.time);
					if (child['replies'] case {'data': {'children': List children}}) {
						addChildren(post.id, children, post);
					}
				}
				else if (childContainer['kind'] == 'more') {
					if (child['id'] == '_') {
						parent?.hasOmittedReplies = true;
					}
					for (final childId in child['children'] as List) {
						final id = fromRedditId(childId as String)!;
						ret.posts_.add(Post(
							board: thread.board,
							text: '',
							name: '',
							time: _estimateTime(id),
							threadId: thread.id,
							id: id,
							spanFormat: PostSpanFormat.stub,
							parentId: parentId,
							attachments_: []
						));
					}
				}
				else {
					print('Ignoring child with kind ${child['kind']}');
					print(child);
				}
			}
		}
		addChildren(thread.id, repliesData, null);
		return ret;
	}

	@override
	String getWebUrlImpl(String board, [int? threadId, int? postId]) {
		String s = 'https://reddit.com/r/$board/';
		if (threadId != null) {
			s += 'comments/${toRedditId(threadId)}/';
			if (postId != null) {
				s += '_/${toRedditId(postId)}/';
			}
		}
		return s;
	}

	@override
	Uri? get iconUrl => Uri.https(baseUrl, '/favicon.ico');

	@override
	String get name => 'Reddit';

	@override
	Future<ImageboardArchiveSearchResultPage> search(ImageboardArchiveSearchQuery query, {required int page, ImageboardArchiveSearchResultPage? lastResult, required RequestPriority priority, CancelToken? cancelToken}) async {
		final Response<Map> response;
		if (query.name != null && query.query.isEmpty && query.boards.isEmpty) {
			response = await client.getUri<Map>(Uri.https(baseUrl, '/user/${query.name}.json', {
				if (lastResult != null)
					if (page > lastResult.page)
						'after': lastResult.posts.last.redditApiId
					else if (page < lastResult.page)
						'before': lastResult.posts.first.redditApiId
			}), options: Options(
				extra: {
					kPriority: priority
				},
				responseType: ResponseType.json
			), cancelToken: cancelToken);
		}
		else {
			response = await client.getUri<Map>(Uri.https(baseUrl, '/search.json', {
				'q': [
					query.query,
					if (query.name != null) 'author:${query.name}',
					...query.boards.map((b) => 'subreddit:$b')
				].join(' '),
				'restrict_sr': 'true',
				if (lastResult != null)
					if (page > lastResult.page)
						'after': lastResult.posts.last.redditApiId
					else if (page < lastResult.page)
						'before': lastResult.posts.first.redditApiId
			}), options: Options(
				extra: {
					kPriority: priority
				},
				responseType: ResponseType.json
			), cancelToken: cancelToken);
		}
		final data = response.data!['data'] as Map;
		return ImageboardArchiveSearchResultPage(
			replyCountsUnreliable: false,
			imageCountsUnreliable: false,
			page: page,
			canJumpToArbitraryPage: false,
			count: null,
			maxPage: // No next-page hint AND
			         data['after'] == null &&
							 // We arrived at this page going forward
							 (page > (lastResult?.page ?? 0)) ? page : null,
			posts: await Future.wait((data['children'] as List).cast<Map>().map((c) async {
				if (c case {'kind': 't3', 'data': Map data}) {
					return ImageboardArchiveSearchResult.thread(await _makeThread(data, cancelToken: cancelToken));
				}
				else if (c case {'kind': 't1', 'data': Map data && {'subreddit': String subreddit, 'link_id': String linkId}}) {
					return ImageboardArchiveSearchResult.post(_makePost(data, thread: ThreadIdentifier(subreddit, fromRedditId(linkId.split('_').last)!)));
				}
				else {
					throw FormatException('Unrecognized search result [kind]', c['kind']);
				}
			})),
			archive: this
		);
	}


	@override
	String get siteData => '';
	@override
	String get siteType => 'reddit';

	@override
	bool get useTree => true;
	@override
	bool get allowsArbitraryBoards => true;
	@override
	bool get classicCatalogStyle => false;
	@override
	bool get explicitIds => false;
	@override
	bool get showImageCount => false;
	@override
	ImageboardSearchMetadata supportsSearch(String? board) {
		return ImageboardSearchMetadata(
			options: const ImageboardSearchOptions(
				name: true,
				text: true
			),
			name: name
		);
	}
	@override
	bool get supportsPosting => false;
	@override
	bool get supportsThreadUpvotes => true;
	@override
	bool get supportsPostUpvotes => true;
	@override
	bool get hasPagedCatalog => true;

	@override
	Future<Thread> getThreadFromArchive(ThreadIdentifier thread, {Future<void> Function(Thread)? customValidator, required RequestPriority priority, CancelToken? cancelToken, String? archiveName}) => getThread(thread, priority: priority, cancelToken: cancelToken);

	@override
	List<CatalogVariantGroup> get catalogVariantGroups => const [
		CatalogVariantGroup(
			name: 'Hot',
			variants: [CatalogVariant.redditHot]
		),
		CatalogVariantGroup(
			name: 'Top',
			variants: [
				CatalogVariant.redditTopPastHour,
				CatalogVariant.redditTopPast24Hours,
				CatalogVariant.redditTopPastWeek,
				CatalogVariant.redditTopPastMonth,
				CatalogVariant.redditTopPastYear,
				CatalogVariant.redditTopAllTime
			]
		),
		CatalogVariantGroup(
			name: 'New',
			variants: [
				CatalogVariant.redditNew
			]
		),
		CatalogVariantGroup(
			name: 'Rising',
			variants: [
				CatalogVariant.redditRising
			]
		),
		CatalogVariantGroup(
			name: 'Controversial',
			variants: [
				CatalogVariant.redditControversialPastHour,
				CatalogVariant.redditControversialPast24Hours,
				CatalogVariant.redditControversialPastWeek,
				CatalogVariant.redditControversialPastMonth,
				CatalogVariant.redditControversialPastYear,
				CatalogVariant.redditControversialAllTime
			]
		),
	];

	@override
	List<ThreadVariant> get threadVariants => const [
		ThreadVariant.redditTop,
		ThreadVariant.redditBest,
		ThreadVariant.redditNew,
		ThreadVariant.redditControversial,
		ThreadVariant.redditOld,
		ThreadVariant.redditQandA
	];

	@override
	String formatBoardName(String name) => '/r/$name';

	@override
	String formatBoardNameWithoutTrailingSlash(String name) => '/r/$name';

	@override
	String formatBoardLink(String name) => '/r/$name';
	
	@override
	String formatBoardSearchLink(String name, String query) => '/r/$name/$query';

	@override
	int placeOrphanPost(List<Post> posts, Post post) {
		// No idea where to put it
		posts.add(post);
		return posts.length - 1;
	}

	@override
	bool get supportsUserInfo => true;
	@override
	bool get supportsUserAvatars => true;

	@override
	Future<ImageboardUserInfo> getUserInfo(String username) async {
		final aboutResponse = await client.getUri<Map>(Uri.https(baseUrl, '/user/$username/about.json'), options: Options(responseType: ResponseType.json));
		final data = aboutResponse.data!['data'] as Map;
		return ImageboardUserInfo(
			username: username,
			avatar: Uri.parse(unescape.convert(data['icon_img'] as String)),
			webUrl: Uri.https(baseUrl, '/user/$username'),
			createdAt: DateTime.fromMillisecondsSinceEpoch((data['created'] as num).toInt() * 1000),
			totalKarma: data['total_karma'] as int,
			commentKarma: data['comment_karma'] as int?,
			linkKarma: data['link_karma'] as int?
		);
	}

	@override
	CatalogVariant get defaultCatalogVariant => Settings.instance.redditCatalogVariant;
	@override
	set defaultCatalogVariant(CatalogVariant value) => Settings.redditCatalogVariantSetting.set(Settings.instance, value);

	@override
	bool get hasExpiringThreads => false;

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		(other is SiteReddit) &&
		super==(other);

	@override
	int get hashCode => baseUrl.hashCode;
}

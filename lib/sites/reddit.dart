// ignore_for_file: argument_type_not_assignable
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
import 'package:flutter/cupertino.dart';
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

	static const _base36Enc = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'];

	static const _base36Dec = {
		'0': 0,
		'1': 1,
		'2': 2,
		'3': 3,
		'4': 4,
		'5': 5,
		'6': 6,
		'7': 7,
		'8': 8,
		'9': 9,
		'a': 10,
		'b': 11,
		'c': 12,
		'd': 13,
		'e': 14,
		'f': 15,
		'g': 16,
		'h': 17,
		'i': 18,
		'j': 19,
		'k': 20,
		'l': 21,
		'm': 22,
		'n': 23,
		'o': 24,
		'p': 25,
		'q': 26,
		'r': 27,
		's': 28,
		't': 29,
		'u': 30,
		'v': 31,
		'w': 32,
		'x': 33,
		'y': 34,
		'z': 35
	};

	static String toRedditId(int id) {
		if (id < 0) {
			throw FormatException('id cannot be negative', id);
		}
		else if (id == 0) {
			return '0';
		}
		final s = <String>[];
		while (id != 0) {
			s.add(_base36Enc[id % 36]);
			id ~/= 36;
		}
		return s.reversed.join('');
	}

	static int? fromRedditId(String id) {
		int ret = 0;
		int multiplier = 1;
		final chars = id.characters.toList();
		for (int i = chars.length - 1; i >= 0; i--) {
			final val = _base36Dec[chars[i]];
			if (val == null) {
				// Invalid character
				return null;
			}
			ret += val * multiplier;
			multiplier *= 36;
		}
		return ret;
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
					const LinkifyOptions(defaultToHttps: true)
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
								width: int.tryParse(node.attributes['height'] ?? '') ?? 16,
								height: int.tryParse(node.attributes['width'] ?? '') ?? 16
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

	static final _shareLinkPattern = RegExp(r'^https?:\/\/(.*\.)?reddit\.(?:(?:com\/r\/[^\/\n]+\/s\/[^\/\n?]+)|(?:app\.link\/[^\/\n]+))');
	static final _linkPattern = RegExp(r'^https?:\/\/(.*\.)?reddit\.com\/r\/([^\/\n]+)(\/comments\/([^\/\n]+)(\/[^\/\n]+\/([^?\/\n]+))?)?');
	static final _redditProtocolPattern = RegExp(r'reddit:\/\/([^ ]+)');

	@override
	Future<BoardThreadOrPostIdentifier?> decodeUrl(String url) async {
		if (_shareLinkPattern.hasMatch(url)) {
			final response = await client.get(url);
			String? redirected = response.redirects.tryLast?.location.toString();
			if (redirected != null && !_shareLinkPattern.hasMatch(redirected)) {
				if (redirected.startsWith('/')) {
					redirected = 'https://$baseUrl$redirected';
				}
				return await decodeUrl(redirected);
			}
			if (response.data is String) {
				// Look for "reddit:///r/subreddit/..." in the JavaScript redirect page
				final redditProtocolMatch = _redditProtocolPattern.firstMatch(response.data);
				if (redditProtocolMatch != null) {
					return await decodeUrl('https://$baseUrl${redditProtocolMatch.group(1)}');
				}
			}
		}
		final match = _linkPattern.firstMatch(url);
		if (match != null) {
			int? threadId;
			int? postId;
			if (match.group(4) != null) {
				threadId = fromRedditId(match.group(4)!);
				if (match.group(6) != null) {
					postId = fromRedditId(match.group(6)!.split('?').first);
				}
			}
			return BoardThreadOrPostIdentifier(Uri.decodeComponent(match.group(2)!), threadId, postId);
		}
		return null;
	}

	ImageboardBoard _makeBoard(Map<String, dynamic> data) => ImageboardBoard(
		name: data['display_name'],
		title: data['public_description'],
		isWorksafe: data['over18'] == false,
		webmAudioAllowed: true,
		icon: switch (data['icon_img']) {
			'' => null,
			String x => Uri.parse(x),
			_ => null
		},
		popularity: data['subscribers']
	);

	Future<String> _getRedgifsToken() async {
		final response = await client.getUri(Uri.https('api.redgifs.com', '/v2/auth/temporary'), options: Options(
			extra: {
				kPriority: RequestPriority.cosmetic
			},
			responseType: ResponseType.json
		));
		return response.data['token'] as String;
	}

	/// Resolve image hosting sites to hotlinks
	Future<List<({String url, String? thumbnailUrl, AttachmentType type, String ext})>> _resolveUrl(String url, {CancelToken? cancelToken}) async {
		final uri = Uri.parse(url);
		try {
			if ((uri.host == 'imgur.com' || uri.host == 'imgur.io' || uri.host == 'i.imgur.com' || uri.host == 'i.imgur.io') && (uri.pathSegments.trySingle?.length ?? 0) > 2) {
				final hash = uri.pathSegments.single.split('.').first;
				final response = await client.getUri(Uri.https('api.imgur.com', '/3/image/$hash'), options: Options(
					headers: {
						'Authorization': 'Client-ID 714791ea4513f83'
					},
					extra: {
						kPriority: RequestPriority.cosmetic
					},
					responseType: ResponseType.json
				), cancelToken: cancelToken);
				final link = response.data['data']?['link'] as String?;
				if (link != null) {
					return [(
						url: link,
						thumbnailUrl: link.replaceFirstMapped(RegExp(r'\.([^.]+)$'), (m) {
							return 'm.${m.group(1)}';
						}),
						type: AttachmentType.image,
						ext: '.${link.split('.').last}'
					)];
				}
			}
			if ((uri.host == 'imgur.com' || uri.host == 'imgur.io') && (uri.pathSegments.length == 2) && (uri.pathSegments.first == 'a')) {
				final hash = uri.pathSegments[1];
				final response = await client.getUri(Uri.https('api.imgur.com', '/3/album/$hash/images'), options: Options(
					headers: {
						'Authorization': 'Client-ID 714791ea4513f83'
					},
					extra: {
						kPriority: RequestPriority.cosmetic
					},
					responseType: ResponseType.json
				), cancelToken: cancelToken);
				final imageData = response.data['data'] as List<dynamic>?;
				if (imageData != null && imageData.isNotEmpty) {
					return imageData.expand((image) {
						final link = image['link'] as String;
						return [(
							url: link,
							thumbnailUrl: link.replaceFirstMapped(RegExp(r'\.([^.]+)$'), (m) {
								return 'm.${m.group(1)}';
							}),
							type: AttachmentType.image,
							ext: '.${link.split('.').last}'
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
					final redirectResponse = await client.head(url, options: Options(
						extra: {
							kPriority: RequestPriority.cosmetic
						},
						responseType: ResponseType.json
					), cancelToken: cancelToken);
					if (!redirectResponse.realUri.host.contains('gfycat')) {
						return _resolveUrl(redirectResponse.realUri.toString());
					}
				}
				else {
					final link = response.data['gfyItem']?['mp4Url'] as String?;
					if (link != null) {
						return [(
							url: link,
							thumbnailUrl: response.data['gfyItem']?['miniPosterUrl'] as String?,
							type: AttachmentType.mp4,
							ext: '.mp4'
						)];
					}
				}
			}
			else if (uri.host == 'i.reddituploads.com') {
				return [(
					url: url,
					thumbnailUrl: null,
					type: AttachmentType.image,
					ext: '.jpeg'
				)];
			}
			else if (uri.host.endsWith('redgifs.com') && uri.pathSegments.length == 2 && uri.pathSegments[0] == 'watch' && persistence != null) {
				final id = uri.pathSegments[1];
				String redGifsToken = '';
				Response? response;
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
					if (e is DioError) {
						if (e.response?.statusCode == 401 && redGifsToken.isNotEmpty) {
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
					}
					else {
						rethrow;
					}
				}
				if (response != null) {
					final url = response.data['gif']?['urls']?['hd'] ?? response.data['gif']?['urls']?['sd'];
					if (url != null) {
						return [(
							url: url as String,
							thumbnailUrl: response.data['gif']?['urls']?['thumbnail'] as String?,
							type: AttachmentType.mp4,
							ext: '.mp4'
						)];
					}
				}
			}
		}
		catch (e, st) {
			Future.error(e, st);
		}
		bool isDirectLink = ['.png', '.jpg', '.jpeg', '.gif'].any((e) => url.endsWith(e));
		return [(
			url: url,
			thumbnailUrl: null,
			type: isDirectLink ? AttachmentType.image : AttachmentType.url,
			ext: isDirectLink ? '.${url.split('.').last}' : ''
		)];
	}

	Future<Thread> _makeThread(dynamic data, {CancelToken? cancelToken}) async {
		final id = fromRedditId(data['id'])!;
		final attachments = <Attachment>[];
		Future<void> dumpAttachments(dynamic data) async {
			if (data['media_metadata'] != null) {
				for (final item in (data['media_metadata'] as Map).values) {
					if (item['m'] == null && item['e'] == 'RedditVideo') {
						attachments.add(Attachment(
							type: AttachmentType.mp4,
							board: data['subreddit'],
							threadId: id,
							id: item['id'],
							ext: '.mp4',
							filename: '${item['id']}.mp4',
							url: unescape.convert(item['hlsUrl']),
							thumbnailUrl: '',
							md5: '',
							width: item['x'],
							height: item['y'],
							sizeInBytes: null
						));
					}
					else if (item['m'] != null) {
						final ext = '.${item['m'].split('/').last}';
						attachments.add(Attachment(
							type: AttachmentType.image,
							board: data['subreddit'],
							threadId: id,
							id: item['id'],
							ext: ext,
							filename: item['id'] + ext,
							url: unescape.convert(item['s']['u'] ?? item['s']['gif']),
							thumbnailUrl: unescape.convert((item['p'] as List).cast<Map>().tryFirst?['u'] ?? item['s']['u']),
							md5: '',
							width: item['s']['x'],
							height: item['s']['y'],
							sizeInBytes: null
						));
					}
				}
			}
			else if (data['secure_media']?['reddit_video'] != null) {
				attachments.add(Attachment(
					type: AttachmentType.mp4,
					board: data['subreddit'],
					threadId: id,
					id: data['name'],
					ext: '.mp4',
					filename: 'video.mp4',
					url: unescape.convert(data['secure_media']['reddit_video']['hls_url']),
					thumbnailUrl: unescape.convert(data['preview']?['images']?[0]?['resolutions']?[0]?['url'] ?? ''),
					md5: '',
					width: data['secure_media']['reddit_video']['width'],
					height: data['secure_media']['reddit_video']['height'],
					sizeInBytes: null
				));
			}
			else if (data['preview'] != null) {
				if (data['preview']?['reddit_video_preview']?['hls_url'] != null) {
					attachments.add(Attachment(
						type: AttachmentType.mp4,
						board: data['subreddit'],
						threadId: id,
						id: data['name'],
						ext: '.mp4',
						filename: 'video.mp4',
						url: unescape.convert(data['preview']['reddit_video_preview']['hls_url']),
						thumbnailUrl: unescape.convert(data['preview']['images'][0]['resolutions'][0]['url']),
						md5: '',
						width: data['preview']['reddit_video_preview']['width'],
						height: data['preview']['reddit_video_preview']['height'],
						sizeInBytes: null
					));
				}
				else {
					final urls = await _resolveUrl(data['url'], cancelToken: cancelToken);
					attachments.addAll(urls.indexed.map((url) => Attachment(
						type: url.$2.type,
						board: data['subreddit'],
						threadId: id,
						id: '${data['name']}_${url.$1}',
						ext: url.$2.ext,
						filename: Uri.tryParse(url.$2.url)?.pathSegments.tryLast ?? '',
						url: url.$2.url,
						width: data['preview']['images'][0]['source']?['width'],
						height: data['preview']['images'][0]['source']?['height'],
						md5: '',
						sizeInBytes: null,
						thumbnailUrl: url.$2.thumbnailUrl ?? ((data['preview']['images'][0]['resolutions'] as List).isNotEmpty ? unescape.convert(data['preview']['images'][0]['resolutions'][0]['url']) : generateThumbnailerForUrl(Uri.parse(url.$2.url)).toString())
					)));
				}
			}
			else if (!(data['is_self'] as bool? ?? false) && data['url'] != null) {
				final urls = await _resolveUrl(data['url'], cancelToken: cancelToken);
				attachments.addAll(urls.indexed.map((url) => Attachment(
					type: url.$2.type,
					board: data['subreddit'],
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
			final galleryItems = (data['gallery_data'] as Map?)?['items'] as List?;
			final Map<String, (int, String?)> galleryMap;
			if (galleryItems != null) {
				galleryMap = {
					for (final (i, item) in galleryItems.indexed)
						item['media_id'] as String: (i, item['caption'] as String?)
				};
			}
			else {
				galleryMap = {};
			}
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
		final crosspostParent = (data['crosspost_parent_list'] as List?)?.tryFirstWhere((xp) => xp['name'] == data['crosspost_parent']) as Map?;
		if (crosspostParent != null) {
			await dumpAttachments(crosspostParent);
			text = '<crosspostparent board="${crosspostParent['subreddit']}" id="${crosspostParent['id']}"></crosspostparent>\n$text';
		}
		if (attachments.isEmpty) {
			await dumpAttachments(data);
		}
		final author = data['author'];
		final authorIsDeleted = author == _kDeleted;
		final textIsDeleted = text == _kRemoved || text == _kDeleted;
		final asPost = Post(
			board: data['subreddit'],
			name: authorIsDeleted ? '' : author,
			flag: _makeFlag(data['author_flair_richtext'], data),
			time: DateTime.fromMillisecondsSinceEpoch(data['created'].toInt() * 1000),
			threadId: id,
			id: id,
			text: textIsDeleted ? '' : text,
			spanFormat: PostSpanFormat.reddit,
			isDeleted: authorIsDeleted || textIsDeleted,
			attachments_: data['is_self'] == true ? [] : attachments,
			upvotes: (data['score_hidden'] == true || data['hide_score'] == true) ? null : data['score'],
			capcode: data['distinguished']
		);
		_updateTimeEstimateData(asPost.id, asPost.time);
		return Thread(
			board: data['subreddit'],
			title: unescape.convert(data['title']).trim(),
			isSticky: data['stickied'],
			time: asPost.time,
			posts_: [asPost],
			attachments: asPost.attachments_,
			replyCount: data['num_comments'],
			imageCount: 0,
			isDeleted: asPost.isDeleted,
			flair: _makeFlag(data['link_flair_richtext'], data) ?? (
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
						name: o['text'],
						votes: o['vote_count'] ?? 0 // Just show the choices if the poll isn't done yet
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
		final response = await client.getUri(Uri.https(baseUrl, '/subreddits/popular.json'), options: Options(
			extra: {
				kPriority: priority
			},
			responseType: ResponseType.json
		), cancelToken: cancelToken);
		return (response.data['data']['children'] as List<dynamic>).map((c) => _makeBoard(c['data'])).toList();
	}

	@override
	ImageboardBoardPopularityType? get boardPopularityType => ImageboardBoardPopularityType.subscriberCount;

	@override
	Future<List<ImageboardBoard>> getBoardsForQuery(String query) async {
		final response = await client.getUri(Uri.https('api.$baseUrl', '/subreddits/search', {
			'q': query,
			'typeahead_active': 'true'
		}), options: Options(responseType: ResponseType.json));
		return (response.data['data']['children'] as List<dynamic>).map((c) => _makeBoard(c['data'])).toList();
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
				final response = await client.getUri(Uri.https(baseUrl, '/r/$board/about.json'), options: Options(
					extra: {
						kPriority: priority
					},
					responseType: ResponseType.json
				), cancelToken: cancelToken);
				newBoard = _makeBoard(response.data['data'])..additionalDataTime = DateTime.now();
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
	Future<List<Thread>> getCatalogImpl(String board, {CatalogVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) async {
		try {
			await _updateBoardIfNeeded(board, priority: priority, cancelToken: cancelToken);
		}
		catch (e, st) {
			Future.error(e, st);
		}
		final suffix = _getCatalogSuffix(variant);
		final response = await client.getUri(Uri.https(baseUrl, '/r/$board${suffix.$1}', suffix.$2), options: Options(
			extra: {
				kPriority: priority
			},
			responseType: ResponseType.json
		), cancelToken: cancelToken);
		return await Future.wait((response.data['data']['children'] as List<dynamic>).map((d) async {
			final t = await _makeThread(d['data'], cancelToken: cancelToken);
			t.currentPage = 1;
			return t;
	}));
	}

	@override
	Future<List<Post>> getStubPosts(ThreadIdentifier thread, List<ParentAndChildIdentifier> postIds, {required RequestPriority priority, CancelToken? cancelToken}) async {
		final ret = <Post>[];
		final childIdsToGet = postIds.take(20).toList();
		final newPosts = <int, Post>{};
		final Set<int> newPostsWithReplies = {};
		if (childIdsToGet.isNotEmpty) {
			final response = await client.getUri(Uri.https(baseUrl, '/api/morechildren', {
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
			final things = response.data['json']['data']['things'] as List;
			for (final thing in things) {
				final parentId = fromRedditId(thing['data']['parent'].split('_')[1]);
				if (thing['kind'] == 'more' || thing['data']['id'] == 't1__') {
					newPosts[parentId]?.hasOmittedReplies = true;
				}
				else {
					final id = fromRedditId(thing['data']['id'].split('_')[1])!;
					final doc = parseFragment(HtmlUnescape().convert(thing['data']['content']));
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
					final html = unescape.convert(thing['data']['contentHTML']);
					final text = (thing['data']['contentText'] as String).replaceAllMapped(RegExp(r'!\[img\]\(([^)]+)\)'), (match) {
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
						upvotes: int.tryParse(doc.querySelector('.score.unvoted')?.attributes['title'] ?? '')
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
		final response = await client.getUri(Uri.https(baseUrl, '/r/$board${suffix.$1}', {
			'after': 't3_${toRedditId(after.id)}',
			...suffix.$2
		}), options: Options(
			extra: {
				kPriority: priority
			},
			responseType: ResponseType.json
		), cancelToken: cancelToken);
		final newPage = (after.currentPage ?? 1) + 1;
		return await Future.wait((response.data['data']['children'] as List<dynamic>).map((d) async {
			final t = await _makeThread(d['data'], cancelToken: cancelToken);
			t.currentPage = newPage;
			return t;
		}));
	}

	@override
	Future<Post> getPostFromArchive(String board, int id, {required RequestPriority priority, CancelToken? cancelToken}) {
		// TODO: implement getPostFromArchive
		throw UnimplementedError();
	}

	Flag? _makeFlag(List<dynamic>? data, Map<String, dynamic> parentData) {
		if (data == null || data.isEmpty) {
			return null;
		}
		final parts = <ImageboardFlag>[];
		for (final part in data) {
			if (part['e'] == 'text') {
				final emoteMatch = _emotePattern.firstMatch(part['t'] ?? '');
				if (emoteMatch != null) {
					final emote = parentData['media_metadata']?[emoteMatch.group(1)];
					// Tbh this usually doesn't work because Reddit only returns emote
					// metadata that was also used in the text. But best effort...
					if (emote is Map) {
						parts.add(ImageboardFlag(
							name: '',
							imageUrl: emote['u'],
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
					imageUrl: part['u'],
					name: text
				));
			}
		}
		return ImageboardMultiFlag(parts: parts);
	}

	static final _emotePattern = RegExp(r'!\[img\]\((emote|[^)]+)\)');

	Post _makePost(Map<String, dynamic> child, {int? parentId, required ThreadIdentifier thread}) {
		final id = fromRedditId(child['id'])!;
		final text = unescape.convert(child['body']).replaceAllMapped(_emotePattern, (match) {
			final metadata = child['media_metadata']?[match.group(1)];
			if (metadata == null) {
				return match.group(0)!;
			}
			return '<img src="${metadata['s']['u']}" width="${metadata['s']['x']}" height="${metadata['s']['y']}">';
		});
		final author = child['author'];
		final authorIsDeleted = author == _kDeleted;
		final textIsDeleted = text == _kRemoved || text == _kDeleted;
		return Post(
			board: thread.board,
			text: textIsDeleted ? '' : text,
			name: authorIsDeleted ? '' : author,
			isDeleted: authorIsDeleted || textIsDeleted,
			flag: _makeFlag(child['author_flair_richtext'], child),
			time: DateTime.fromMillisecondsSinceEpoch(child['created'].toInt() * 1000),
			threadId: thread.id,
			id: id,
			spanFormat: PostSpanFormat.reddit,
			attachments_: const [],
			parentId: parentId,
			upvotes: (child['score_hidden'] == true || child['hide_score'] == true) ? null : child['score'],
			capcode: child['distinguished']
		);
	}

	@override
	Future<Thread> getThreadImpl(ThreadIdentifier thread, {ThreadVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) async {
		final response = await client.getThreadUri(Uri.https(baseUrl, '/r/${thread.board}/comments/${toRedditId(thread.id)}.json', {
			if (variant?.redditApiName != null) 'sort': variant!.redditApiName!
		}), priority: priority, responseType: ResponseType.json, cancelToken: cancelToken);
		final ret = await _makeThread(response.data[0]['data']['children'][0]['data'], cancelToken: cancelToken);
		addChildren(int parentId, List<dynamic> childData, Post? parent) {
			for (final childContainer in childData) {
				final child = childContainer['data'];
				if (childContainer['kind'] == 't1') {
					final post = _makePost(child, parentId: parentId, thread: thread);
					ret.posts_.add(post);
					_updateTimeEstimateData(post.id, post.time);
					if (child['replies'] != '') {
						addChildren(post.id, child['replies']['data']['children'], post);
					}
				}
				else if (childContainer['kind'] == 'more') {
					if (child['id'] == '_') {
						parent?.hasOmittedReplies = true;
					}
					for (final childId in child['children'] as List) {
						final id = fromRedditId(childId)!;
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
		addChildren(thread.id, response.data[1]['data']['children'], null);
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
		final Response response;
		if (query.name != null) {
			response = await client.getUri(Uri.https(baseUrl, '/user/${query.name}.json', {
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
			response = await client.getUri(Uri.https(baseUrl, query.boards.isEmpty ? '/search.json' : '/r/${query.boards.first}/search.json', {
				'q': [
					query.query
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
		return ImageboardArchiveSearchResultPage(
			replyCountsUnreliable: false,
			imageCountsUnreliable: false,
			page: page,
			canJumpToArbitraryPage: false,
			count: null,
			maxPage: // No next-page hint AND
			         response.data['data']['after'] == null &&
							 // We arrived at this page going forward
							 (page > (lastResult?.page ?? 0)) ? page : null,
			posts: await Future.wait((response.data['data']['children'] as List<dynamic>).map((c) async {
				if (c['kind'] == 't3') {
					return ImageboardArchiveSearchResult.thread(await _makeThread(c['data'], cancelToken: cancelToken));
				}
				else if (c['kind'] == 't1') {
					return ImageboardArchiveSearchResult.post(_makePost(c['data'], thread: ThreadIdentifier(c['data']['subreddit'], fromRedditId((c['data']['link_id'] as String).split('_').last)!)));
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
		final aboutResponse = await client.getUri(Uri.https(baseUrl, '/user/$username/about.json'), options: Options(responseType: ResponseType.json));
		return ImageboardUserInfo(
			username: username,
			avatar: Uri.parse(unescape.convert(aboutResponse.data['data']['icon_img'])),
			webUrl: Uri.https(baseUrl, '/user/$username'),
			createdAt: DateTime.fromMillisecondsSinceEpoch((aboutResponse.data['data']['created'] as num).toInt() * 1000),
			totalKarma: aboutResponse.data['data']['total_karma'],
			commentKarma: aboutResponse.data['data']['comment_karma'],
			linkKarma: aboutResponse.data['data']['link_karma']
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

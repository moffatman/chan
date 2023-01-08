import 'package:chan/models/search.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/4chan.dart';
import 'dart:io';

import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:flutter/cupertino.dart';
import 'package:html/parser.dart';
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

class SiteReddit extends ImageboardSite {
	SiteReddit() : super([]);
	@override
	String get baseUrl => 'reddit.com';

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

	static int fromRedditId(String id) {
		int ret = 0;
		int multiplier = 1;
		final chars = id.characters.toList();
		for (int i = chars.length - 1; i >= 0; i--) {
			ret += _base36Dec[chars[i]]! * multiplier;
			multiplier *= 36;
		}
		return ret;
	}

	static PostNodeSpan makeSpan(String board, int threadId, String text) {
		final body = parseFragment(markdown.markdownToHtml(text,
			inlineSyntaxes: [
				_SuperscriptSyntax(),
				_SpoilerSyntax(),
				_StrikethroughSyntax()
			],
			blockSyntaxes: [
				const markdown.TableSyntax(),
				const markdown.BlockquoteSyntax()
			]
		).trim().replaceAll('<br />', ''));
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
					else if (node.localName == 'strong') {
						yield PostBoldSpan(PostTextSpan(node.text));
					}
					else if (node.localName == 'em') {
						yield PostItalicSpan(PostTextSpan(node.text));
					}
					else if (node.localName == 'h1') {
						yield PostBoldSpan(PostTextSpan(node.text));
					}
					else if (node.localName == 'a') {
						yield PostLinkSpan(node.attributes['href']!, name: node.text);
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
								if (node.localName == 'ol') {
									yield PostTextSpan('$i. ');
								}
								else {
									yield const PostTextSpan('• ');
								}
								if (li.children.isNotEmpty) {
									yield* visit(li.children);
								}
								else {
									yield* visit(li.nodes);
								}
								addLinebreakBefore = true;
								i++;
							}
						}
					}
					else if (node.localName == 'table') {
						yield PostTableSpan(node.querySelectorAll('tr').map((tr) => tr.querySelectorAll('td,th').map((td) => PostNodeSpan(td.children.isNotEmpty ? visit(td.children).toList() : visit(td.nodes).toList())).toList()).toList());
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
						yield PostQuoteSpan(PostNodeSpan(node.children.isNotEmpty ? visit(node.children).toList() : visit(node.nodes).toList()));
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
		return PostNodeSpan(visit(body.nodes).toList());
	}

	@override
	Future<void> clearLoginCookies(bool fromBothWifiAndCellular) async {

	}

	@override
	Future<PostReceipt> createThread({required String board, String name = '', String options = '', String subject = '', required String text, required CaptchaSolution captchaSolution, File? file, bool? spoiler, String? overrideFilename, ImageboardBoardFlag? flag}) {
		// TODO: implement createThread
		throw UnimplementedError();
	}

	@override
	Future<BoardThreadOrPostIdentifier?> decodeUrl(String url) async {
		final pattern = RegExp(r'^https?:\/\/(.*\.)?reddit\.com\/r\/([^\/\n]+)(\/comments\/([^\/\n]+)(\/[^\/\n]+\/([^\/\n]+))?)?');
		final match = pattern.firstMatch(url);
		if (match != null) {
			int? threadId;
			int? postId;
			if (match.group(4) != null) {
				threadId = fromRedditId(match.group(4)!);
				if (match.group(6) != null) {
					postId = fromRedditId(match.group(6)!);
				}
			}
			return BoardThreadOrPostIdentifier(match.group(2)!, threadId, postId);
		}
		return null;
	}

	ImageboardBoard _makeBoard(Map<String, dynamic> data) => ImageboardBoard(
		name: data['display_name'],
		title: data['public_description'],
		isWorksafe: data['over18'] == false,
		webmAudioAllowed: true,
		icon: (data['icon_img']?.isEmpty ?? true) ? null : Uri.parse(data['icon_img'])
	);

	Thread _makeThread(dynamic data) {
		final id = fromRedditId(data['id']);
		final attachments = <Attachment>[];
		if (data['media_metadata'] != null) {
			for (final item in data['media_metadata'].values) {
				if (item['m'] == null && item['e'] == 'RedditVideo') {
					attachments.add(Attachment(
						type: AttachmentType.mp4,
						board: data['subreddit'],
						threadId: id,
						id: item['id'],
						ext: '.mp4',
						filename: '${item['id']}.mp4',
						url: Uri.parse(unescape.convert(item['hlsUrl'])),
						thumbnailUrl: Uri.https(''),
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
						url: Uri.parse(unescape.convert(item['s']['u'] ?? item['s']['gif'])),
						thumbnailUrl: Uri.parse(unescape.convert(item['p'][0]['u'])),
						md5: '',
						width: item['s']['x'],
						height: item['s']['y'],
						sizeInBytes: null
					));
				}
			}
		}
		else if (data['preview'] != null) {
			if (data['secure_media']?['reddit_video'] != null) {
				attachments.add(Attachment(
					type: AttachmentType.mp4,
					board: data['subreddit'],
					threadId: id,
					id: data['name'],
					ext: '.mp4',
					filename: 'video',
					url: Uri.parse(unescape.convert(data['secure_media']['reddit_video']['hls_url'])),
					thumbnailUrl: Uri.parse(unescape.convert(data['preview']['images'][0]['resolutions'][0]['url'])),
					md5: '',
					width: data['secure_media']['reddit_video']['width'],
					height: data['secure_media']['reddit_video']['height'],
					sizeInBytes: null
				));
			}
			else {
				final imageUrl = Uri.parse(unescape.convert(data['preview']['images'][0]['source']['url']));
				bool isDirectLink = ['.png', '.jpg', '.jpeg', '.gif'].any((e) => data['url'].endsWith(e));
				attachments.add(Attachment(
					type: isDirectLink ? AttachmentType.image : AttachmentType.url,
					board: data['subreddit'],
					threadId: id,
					id: data['name'],
					ext: isDirectLink ? '.png' : '',
					filename: isDirectLink ? 'preview' : '',
					url: Uri.parse(data['url']),
					width: data['preview']['images'][0]['source']['width'],
					height: data['preview']['images'][0]['source']['height'],
					md5: '',
					sizeInBytes: null,
					thumbnailUrl: data['preview']['images'][0]['resolutions'].isNotEmpty ? Uri.parse(unescape.convert(data['preview']['images'][0]['resolutions'][0]['url'])) : imageUrl
				));
			}
		}
		else if (data['url'] != null) {
			final url = Uri.parse(data['url']);
			attachments.add(Attachment(
				type: AttachmentType.url,
				board: data['subreddit'],
				threadId: id,
				id: data['name'],
				ext: '',
				filename: '',
				url: url,
				thumbnailUrl: Uri.https('thumbs.chance.surf', '/', {
					'url': url.toString()
				}),
				md5: '',
				width: null,
				height: null,
				sizeInBytes: null
			));
		}
		final asPost = Post(
			board: data['subreddit'],
			name: data['author'],
			time: DateTime.fromMillisecondsSinceEpoch(data['created'].toInt() * 1000),
			threadId: id,
			id: id,
			text: data['is_self'] ? unescape.convert(data['selftext']) : data['url'],
			spanFormat: PostSpanFormat.reddit,
			attachments: attachments,
			upvotes: (data['score_hidden'] == true || data['hide_score'] == true) ? null : data['score'],
			capcode: data['distinguished']
		);
		return Thread(
			board: data['subreddit'],
			title: unescape.convert(data['title']),
			isSticky: data['stickied'],
			time: asPost.time,
			posts_: [asPost],
			attachments: data['is_self'] == true ? [] : attachments,
			replyCount: data['num_comments'],
			imageCount: 0,
			id: id,
			suggestedVariant: (data['suggested_sort']?.isNotEmpty ?? false) ? _RedditApiName.toVariant(data['suggested_sort']) : null
		);
	}

	@override
	String get defaultUsername => '';

	@override
	Future<void> deletePost(String board, PostReceipt receipt) {
		// TODO: implement deletePost
		throw UnimplementedError();
	}

	@override
	DateTime? getActionAllowedTime(String board, ImageboardAction action) {
		return null;
	}

	@override
	Future<List<ImageboardBoard>> getBoards() async {
		final response = await client.get(Uri.https(baseUrl, '/subreddits/popular.json').toString());
		return (response.data['data']['children'] as List<dynamic>).map((c) => _makeBoard(c['data'])).toList();
	}

	@override
	Future<List<ImageboardBoard>> getBoardsForQuery(String query) async {
		final response = await client.get(Uri.https('api.$baseUrl', '/subreddits/search').toString(), queryParameters: {
			'q': query,
			'typeahead_active': true
		});
		return (response.data['data']['children'] as List<dynamic>).map((c) => _makeBoard(c['data'])).toList();
	}

	@override
	Future<CaptchaRequest> getCaptchaRequest(String board, [int? threadId]) async {
		return NoCaptchaRequest();
	}

	Future<void> _updateBoardIfNeeded(String board) async {
		if (persistence.boards[board]?.additionalDataTime?.isBefore(DateTime.now().subtract(const Duration(days: 3))) ?? true) {
			final response = await client.get(Uri.https(baseUrl, '/r/$board/about.json').toString());
			persistence.boards[board] = _makeBoard(response.data['data'])..additionalDataTime = DateTime.now();
			persistence.didUpdateBrowserState();
		}
	}

	@override
	Future<List<Thread>> getCatalog(String board, {CatalogVariant? variant}) async {
		try {
			await _updateBoardIfNeeded(board);
		}
		catch (e, st) {
			if (board != 'popular') {
				Future.error(e, st);
			}
		}
		final suffix = {
			CatalogVariant.redditHot: '/hot.json',
			CatalogVariant.redditNew: '/new.json',
			CatalogVariant.redditRising: '/rising.json',
			CatalogVariant.redditControversialPastHour: '/controversial.json?t=hour',
			CatalogVariant.redditControversialPast24Hours: '/controversial.json?t=day',
			CatalogVariant.redditControversialPastWeek: '/controversial.json?t=week',
			CatalogVariant.redditControversialPastMonth: '/controversial.json?t=month',
			CatalogVariant.redditControversialPastYear: '/controversial.json?t=year',
			CatalogVariant.redditControversialAllTime: '/controversial.json?t=all',
			CatalogVariant.redditTopPastHour: '/top.json?t=hour',
			CatalogVariant.redditTopPast24Hours: '/top.json?t=day',
			CatalogVariant.redditTopPastWeek: '/top.json?t=week',
			CatalogVariant.redditTopPastMonth: '/top.json?t=month',
			CatalogVariant.redditTopPastYear: '/top.json?t=year',
			CatalogVariant.redditTopAllTime: '/top.json?t=all',
		}[variant] ?? '.json';
		final response = await client.get('https://$baseUrl/r/$board$suffix');
		return (response.data['data']['children'] as List<dynamic>).map((d) => _makeThread(d['data'])..currentPage = 1).toList();
	}

	@override
	List<ImageboardSiteLoginField> getLoginFields() => [];

	@override
	String? getLoginSystemName() => null;

	@override
	Future<List<Post>> getMoreThread(Post after) async {
		final response = await client.get(Uri.https(baseUrl, '/r/${after.board}/comments/${toRedditId(after.threadId)}/_/${toRedditId(after.id)}.json').toString());
		final ret = <Post>[];
		addChildren(int? parentId, List<dynamic> childData) {
			for (final childContainer in childData) {
				final child = childContainer['data'];
				if (childContainer['kind'] == 't1') {
					final id = fromRedditId(child['id']);
					ret.add(Post(
						board: after.board,
						text: unescape.convert(child['body']),
						name: child['author'],
						time: DateTime.fromMillisecondsSinceEpoch(child['created'].toInt() * 1000),
						threadId: after.threadId,
						id: id,
						spanFormat: PostSpanFormat.reddit,
						attachments: [],
						parentId: parentId ?? fromRedditId(child['parent_id'].split('_')[1]),
						upvotes: (child['score_hidden'] == true || child['hide_score'] == true) ? null : child['score'],
						capcode: child['distinguished']
					));
					if (child['replies'] != '') {
						addChildren(id, child['replies']['data']['children']);
					}
				}
				else if (child['count'] != null) {
					final parent = ret.reversed.tryFirstWhere((p) => p.id == parentId);
					parent?.omittedChildrenCount = (parent.omittedChildrenCount + child['count']).toInt();
				}
				else {
					print('Ignoring child with kind ${child['kind']}');
					print(child);
				}
			}
		}
		addChildren(null, response.data[1]['data']['children']);
		return ret;
	}

	@override
	Future<List<Thread>> getMoreCatalog(Thread after) async {
		final response = await client.getUri(Uri.https(baseUrl, '/r/${after.board}.json', {
			'after': 't3_${toRedditId(after.id)}'
		}));
		final newPage = (after.currentPage ?? 1) + 1;
		return (response.data['data']['children'] as List<dynamic>).map((d) => _makeThread(d['data'])..currentPage = newPage).toList();
	}

	@override
	Future<Post> getPost(String board, int id) {
		// TODO: implement getPost
		throw UnimplementedError();
	}

	@override
	Uri getPostReportUrl(String board, int id) {
		// TODO: implement getPostReportUrl
		throw UnimplementedError();
	}

	@override
	Uri getSpoilerImageUrl(Attachment attachment, {ThreadIdentifier? thread}) {
		// TODO: implement getSpoilerImageUrl
		throw UnimplementedError();
	}

	@override
	Future<Thread> getThread(ThreadIdentifier thread, {ThreadVariant? variant}) async {
		final response = await client.getUri(Uri.https(baseUrl, '/r/${thread.board}/comments/${toRedditId(thread.id)}.json', {
			if (variant?.redditApiName != null) 'sort': variant!.redditApiName!
		}));
		final ret = _makeThread(response.data[0]['data']['children'][0]['data']);
		addChildren(int? parentId, List<dynamic> childData) {
			for (final childContainer in childData) {
				final child = childContainer['data'];
				if (childContainer['kind'] == 't1') {
					final id = fromRedditId(child['id']);
					ret.posts_.add(Post(
						board: thread.board,
						text: unescape.convert(child['body']),
						name: child['author'],
						time: DateTime.fromMillisecondsSinceEpoch(child['created'].toInt() * 1000),
						threadId: thread.id,
						id: id,
						spanFormat: PostSpanFormat.reddit,
						attachments: [],
						parentId: parentId,
						upvotes: (child['score_hidden'] == true || child['hide_score'] == true) ? null : child['score'],
						capcode: child['distinguished']
					));
					if (child['replies'] != '') {
						addChildren(id, child['replies']['data']['children']);
					}
				}
				else if (child['count'] != null) {
					final parent = ret.posts_.reversed.tryFirstWhere((p) => p.id == parentId);
					parent?.omittedChildrenCount = (parent.omittedChildrenCount + child['count']).toInt();
				}
				else {
					print('Ignoring child with kind ${child['kind']}');
					print(child);
				}
			}
		}
		addChildren(null, response.data[1]['data']['children']);
		return ret;
	}

	@override
	String getWebUrl(String board, [int? threadId, int? postId]) {
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
	Uri get iconUrl => Uri.https(baseUrl, '/favicon.ico');

	@override
	String get imageUrl => 'i.redd.it';

	@override
	Future<void> login(Map<ImageboardSiteLoginField, String> fields) {
		// TODO: implement login
		throw UnimplementedError();
	}

	@override
	String get name => 'Reddit';

	@override
	Future<PostReceipt> postReply({required ThreadIdentifier thread, String name = '', String options = '', required String text, required CaptchaSolution captchaSolution, File? file, bool? spoiler, String? overrideFilename, ImageboardBoardFlag? flag}) {
		// TODO: implement postReply
		throw UnimplementedError();
	}

	@override
	Future<ImageboardArchiveSearchResultPage> search(ImageboardArchiveSearchQuery query, {required int page, ImageboardArchiveSearchResultPage? lastResult}) async {
		final response = await client.getUri(Uri.https(baseUrl, '/r/${query.boards.first}/search.json', {
			'q': query.query,
			'restrict_sr': 'true',
			if (lastResult != null)
				if (page > lastResult.page)
					'after': 't3_${toRedditId(lastResult.posts.last.thread!.id)}'
				else if (page < lastResult.page)
					'before': 't3_${toRedditId(lastResult.posts.first.thread!.id)}'
		}));
		return ImageboardArchiveSearchResultPage(
			page: page,
			maxPage: response.data['data']['after'] == null ? page : null,
			posts: (response.data['data']['children'] as List<dynamic>).map((c) => ImageboardArchiveSearchResult.thread(_makeThread(c['data']))).toList(),
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
	bool get supportsSearch => true;
	@override
	bool get supportsPosting => false;
	@override
	bool get hasOmittedReplies => true;
	@override
	bool get isReddit => true;
	@override
	bool get supportsSearchOptions => false;

	@override
	Future<Thread> getThreadFromArchive(ThreadIdentifier thread, {Future<void> Function(Thread)? validate}) => getThread(thread);

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
	bool operator == (Object other) => (other is SiteReddit);

	@override
	int get hashCode => 0;
}

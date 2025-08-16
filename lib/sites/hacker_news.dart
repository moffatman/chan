import 'dart:math';

import 'package:chan/models/search.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/thumbnailer.dart';
import 'package:chan/sites/4chan.dart';

import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/util.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart';

abstract class _HNObject {
	final String by;
	final List<_HNObject> children;
	final bool dead;
	final bool deleted;
	final int id;
	final int? score;
	final DateTime time;

	const _HNObject({
		required this.by,
		required this.children,
		this.dead = false,
		this.deleted = false,
		required this.id,
		required this.score,
		required this.time
	});
}

enum _HNStoryType {
	normal,
	job,
	poll
}

class _HNPollOption {
	final String text;
	final int votes;
	const _HNPollOption({
		required this.text,
		required this.votes
	});
}

class _HNStory extends _HNObject {
	final int descendants;
	final String? text;
	final String? title;
	final Uri? url;
	final _HNStoryType type;
	final List<_HNPollOption> pollOptions;
	const _HNStory({
		required super.by,
		required this.descendants,
		required super.id,
		required super.children,
		required this.pollOptions,
		required super.score,
		required this.text,
		required super.time,
		required this.title,
		required this.type,
		required this.url,
		super.dead,
		super.deleted
	});
}

class _HNComment extends _HNObject {
	final int parent;
	final int story;
	final String text;
	const _HNComment({
		required super.by,
		required super.id,
		required super.children,
		required this.parent,
		required super.score,
		required this.story,
		required this.text,
		required super.time,
		super.dead,
		super.deleted
	});
}

class SiteHackerNews extends ImageboardSite {
	final int catalogThreadsPerPage;
	SiteHackerNews({
		this.catalogThreadsPerPage = 30,
		required super.overrideUserAgent,
		required super.archives,
		required super.imageHeaders,
		required super.videoHeaders
	});
	@override
	String get baseUrl => 'news.ycombinator.com';

	Map<CatalogVariant?, List<int>> _lastCatalogIds = {};
	Map<int, int> _cachedOpIds = {};

	@override
	void migrateFromPrevious(SiteHackerNews oldSite) {
		super.migrateFromPrevious(oldSite);
		_lastCatalogIds = oldSite._lastCatalogIds;
		_cachedOpIds = oldSite._cachedOpIds;
	}

	static final _trailingNewlinePattern = RegExp(r'\n$');

	static PostNodeSpan makeSpan(String text) {
		final body = parseFragment(text);
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
						if (!addedLinebreakBefore) {
							yield const PostLineBreakSpan();
						}
						if (node.text.startsWith('>')) {
							yield PostQuoteSpan(PostNodeSpan(visit(node.nodes).toList()));
						}
						else {
							yield* visit(node.nodes);
						}
						addLinebreakBefore = true;
					}
					else if (node.localName == 'br') {
						yield const PostLineBreakSpan();
					}
					else if (node.localName == 'a') {
						yield PostLinkSpan(node.attributes['href']!, name: node.text.nonEmptyOrNull);
					}
					else if (node.localName == 'b') {
						yield PostBoldSpan(PostTextSpan(node.text));
					}
					else if (node.localName == 'i') {
						yield PostItalicSpan(PostTextSpan(node.text));
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
					else if (node.localName == 'pre') {
						yield PostCodeSpan(node.text.replaceFirst(_trailingNewlinePattern, ''));
						if (node.text.endsWith('\n')) {
							yield const PostLineBreakSpan();
						}
					}
					else {
						yield* Site4Chan.parsePlaintext(node.text);
					}
				}
				else {
					final text = node.text ?? '';
					final children = Site4Chan.parsePlaintext(text);
					if (text.startsWith('>')) {
						yield PostQuoteSpan(PostNodeSpan(children));
					}
					else {
						yield* children;
					}
				}
			}
		}
		return PostNodeSpan(visit(body.nodes).toList(growable: false));
	}

	static Attachment _makeAttachment(int threadId, Uri url) => Attachment(
		type: AttachmentType.url,
		board: '',
		id: url.toString(),
		ext: '',
		filename: '',
		url: url.toString(),
		thumbnailUrl: generateThumbnailerForUrl(url).toString(),
		md5: '',
		width: null,
		height: null,
		threadId: threadId,
		sizeInBytes: null
	);

	static int _countDescendants(_HNObject o) {
		int out = 1;
		for (final child in o.children) {
			out += _countDescendants(child);
		}
		return out;
	}

	Future<_HNObject?> _makeHNObjectAlgolia(Map d, {CancelToken? cancelToken}) async {
		final children0 = await Future.wait(((d['children'] as List?)?.cast<Map>() ?? []).tryMap((o) => _makeHNObjectAlgolia(o, cancelToken: cancelToken)));
		final children = children0.tryMap((a) => a).toList();
		switch (d['type']) {
			case 'story':
			case 'job':
			case 'poll':
				return _HNStory(
					by: d['author'] as String? ?? '',
					descendants: children.fold<int>(0, (count, child) => count + _countDescendants(child)), 
					id: d['id'] as int,
					children: children,
					pollOptions: (d['options'] as List?)?.cast<Map>().map((option) => _HNPollOption(
						text: option['text'] as String,
						votes: option['points'] as int
					)).toList() ?? [],
					score: d['points'] as int?,
					text: d['text'] as String?,
					time: DateTime.fromMillisecondsSinceEpoch((d['created_at_i'] as int) * 1000),
					title: d['title'] as String?,
					type: {
						'story': _HNStoryType.normal,
						'job': _HNStoryType.job,
						'poll': _HNStoryType.poll
					}[d['type']]!,
					url: switch (d['url']) {
						String u => Uri.parse(u),
						_ => null
					},
					dead: d['dead'] as bool? ?? false,
					deleted: d['deleted'] as bool? ?? false
				);
			case 'comment':
				if (d['story_id'] == null) {
					// Sometimes happens during fast-moving threads, just skip this comment
					return null;
				}
				return _HNComment(
					by: d['author'] as String? ?? '',
					id: d['id'] as int,
					children: children,
					parent: d['parent_id'] as int,
					score: d['points'] as int?,
					story: d['story_id'] as int,
					text: d['text'] as String? ?? '',
					time: DateTime.fromMillisecondsSinceEpoch((d['created_at_i'] as int) * 1000),
					dead: d['dead'] as bool? ?? false,
					deleted: d['deleted'] as bool? ?? false
				);
			default:
				throw Exception('Unknown HN object type "${d['type']}?"');
		}
	}

	Future<_HNObject> _getAlgolia(int id, {required RequestPriority priority, CancelToken? cancelToken}) async {
		final response = await client.getThreadUri(Uri.https('hn.algolia.com', '/api/v1/items/$id'), priority: priority, responseType: ResponseType.json, cancelToken: cancelToken);
		return (await _makeHNObjectAlgolia(response.data as Map, cancelToken: cancelToken))!;
	}

	Future<Thread?> _getThreadForCatalog(int id, {required RequestPriority priority, CancelToken? cancelToken}) async {
		final response = await client.get<Map>('https://hacker-news.firebaseio.com/v0/item/$id.json', options: Options(
			extra: {
				kPriority: priority
			}
		), cancelToken: cancelToken);
		if (response.data == null) {
			// Missing for some reason
			return null;
		}
		final d = response.data!;
		String text;
		switch (d['type']) {
			case 'story':
				text = d['text'] as String? ?? d['url'] as String? ?? '';
				break;
			case 'job':
				text = d['text'] as String? ?? d['url'] as String? ?? '';
				break;
			case 'poll':
				final responses = await Future.wait<Map>((d['parts'] as List).cast<int>().map((part) async {
					return (await client.get<Map>('https://hacker-news.firebaseio.com/v0/item/$part.json', options: Options(
						extra: {
							kPriority: priority
						}
					))).data!;
				}));
				text = '${d['text']}<ul>${responses.map((r) => '<li>${r['text']} - ${r['score']}</li>').join('\n')}</ul>';
				break;
			default:
				throw Exception('Unexpected HN item type "${d['type']}"');
		}
		final Uri? url = switch (d['url']) {
			String u => Uri.parse(u),
			_ => null
		};
		final op = Post(
			board: '',
			text: text,
			name: d['by'] as String,
			time: DateTime.fromMillisecondsSinceEpoch((d['time'] as int) * 1000),
			threadId: id,
			id: id,
			spanFormat: PostSpanFormat.hackerNews,
			attachments_: [
				if (url != null) _makeAttachment(id, url)
			],
			upvotes: d['score'] as int?
		);
		return Thread(
			posts_: [op],
			imageCount: 0,
			id: id,
			board: '',
			title: d['title'] as String?,
			isSticky: false,
			time: op.time,
			attachments: op.attachments_,
			replyCount: d['descendants'] as int? ?? 0,
			isArchived: DateTime.now().difference(op.time) > const Duration(days: 14)
		);
	}

	Post _makePost(_HNObject item) {
		if (item is _HNComment) {
			return Post(
				board: '',
				text: item.text,
				name: item.by,
				time: item.time,
				threadId: item.story,
				id: item.id,
				spanFormat: PostSpanFormat.hackerNews,
				attachments_: [],
				upvotes: item.score,
				parentId: item.parent
			);
		}
		else if (item is _HNStory) {
			String text;
			switch (item.type) {
				case _HNStoryType.normal:
				case _HNStoryType.job:
					text = item.text ?? item.url?.toString() ?? '';
					break;
				case _HNStoryType.poll:
					text = '${item.text}<ul>${item.pollOptions.map((r) => '<li>${parseFragment(r.text).text} - ${r.votes} votes</li>').join('\n')}</ul>';
					break;
			}
			return Post(
				board: '',
				text: text,
				name: item.by,
				time: item.time,
				threadId: item.id,
				id: item.id,
				spanFormat: PostSpanFormat.hackerNews,
				attachments_: [
					if (item.url != null) _makeAttachment(item.id, item.url!)
				],
				upvotes: item.score
			);
		}
		throw UnimplementedError('Converting a ${item.runtimeType} into a Post');
	}

	@override
	Future<PostReceipt> submitPost(DraftPost post, CaptchaSolution captchaSolution, CancelToken cancelToken) {
		// TODO: implement submitPost
		throw UnimplementedError();
	}

	@override
	Future<BoardThreadOrPostIdentifier?> decodeUrl(Uri url) async {
		if (url.host == baseUrl && url.path == '/item') {
			final id = url.queryParameters['id']?.tryParseInt;
			if (id != null) {
				final threadId = await _cachedOpIds.putIfAbsentAsync(id, () async {
					// Try to avoid network request by checking disk
					if (persistence?.getThreadStateIfExists(ThreadIdentifier('', id)) != null) {
						// Must be OP
						return id;
					}
					final object = await _getAlgolia(id, priority: RequestPriority.interactive);
					return object is _HNComment ? object.story : id;
				});
				return BoardThreadOrPostIdentifier('', threadId, id == threadId ? null : id);
			}
		}
		return null;
	}

	@override
	String get defaultUsername => '';

	@override
	Future<List<ImageboardBoard>> getBoards({required RequestPriority priority, CancelToken? cancelToken}) async {
		return [ImageboardBoard(
			name: '',
			title: 'Hacker News',
			isWorksafe: true,
			webmAudioAllowed: true
		)];
	}

	@override
	Future<CaptchaRequest> getCaptchaRequest(String board, int? threadId, {CancelToken? cancelToken}) async {
		return const NoCaptchaRequest();
	}

	Future<List<int>> _getSecondChancePoolIds(int? after, {required RequestPriority priority, CancelToken? cancelToken}) async {
		final response = await client.getUri(Uri.https(baseUrl, '/pool', {
			if (after != null) 'next': after.toString()
		}), options: Options(
			extra: {
				kPriority: priority
			},
			responseType: ResponseType.plain
		), cancelToken: cancelToken);
		final doc = parse(response.data);
		final ids = doc.querySelectorAll('.athing').map((e) => int.parse(e.id));
		if (after != null) {
			// Avoid duplicating the "after" id
			return ids.skip(1).toList();
		}
		return ids.toList();
	}

	@override
	Future<List<Thread>> getCatalogImpl(String board, {CatalogVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) async {
		final List<int> data;
		if (variant == CatalogVariant.hackerNewsSecondChancePool) {
			data = await _getSecondChancePoolIds(null, priority: priority, cancelToken: cancelToken);
		}
		else {
			final name = {
				CatalogVariant.hackerNewsTop: 'topstories',
				CatalogVariant.hackerNewsNew: 'newstories',
				CatalogVariant.hackerNewsBest: 'beststories',
				CatalogVariant.hackerNewsAsk: 'askstories',
				CatalogVariant.hackerNewsShow: 'showstories',
				CatalogVariant.hackerNewsJobs: 'jobstories',
			}[variant]!;
			final response = await client.get<List<int>>('https://hacker-news.firebaseio.com/v0/$name.json', options: Options(
				extra: {
					kPriority: priority
				}
			), cancelToken: cancelToken);
			data = response.data!;
		}
		_lastCatalogIds[variant] = data;
		return (await Future.wait(data.take(catalogThreadsPerPage).map((d) => _getThreadForCatalog(d, priority: priority, cancelToken: cancelToken)))).tryMap((e) => e).toList();
	}

	List<Post> _getMoreThread(_HNObject item) {
		final posts = <Post>[];
		void dumpNode(_HNObject item2) {
			if (item2.by.isNotEmpty) {
				posts.add(_makePost(item2));
			}
			for (final child in item2.children) {
				dumpNode(child);
			}
		}
		dumpNode(item);
		return posts;
	}

	@override
	Future<List<Thread>> getMoreCatalogImpl(String board, Thread after, {CatalogVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) async {
		if (variant == CatalogVariant.hackerNewsSecondChancePool) {
			final ids = await _getSecondChancePoolIds(after.id, priority: priority, cancelToken: cancelToken);
			return (await Future.wait(ids.map((id) => _getThreadForCatalog(id, priority: priority, cancelToken: cancelToken)))).tryMap((e) => e).toList();
		}
		else {
			final lastCatalogIds = _lastCatalogIds[variant];
			final index = lastCatalogIds?.indexOf(after.id) ?? -1;
			if (index == -1) {
				return [];
			}
			return (await Future.wait(lastCatalogIds!.skip(index + 1).take(catalogThreadsPerPage).map((id) => _getThreadForCatalog(id, priority: priority, cancelToken: cancelToken)))).tryMap((e) => e).toList();
		}
	}

	@override
	Future<Post> getPostFromArchive(String board, int id, {required RequestPriority priority, CancelToken? cancelToken}) async {
		final item = await _getAlgolia(id, priority: priority, cancelToken: cancelToken);
		return _makePost(item);
	}

	@override
	Future<Thread> getThreadImpl(ThreadIdentifier thread, {ThreadVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) async {
		final item = await _getAlgolia(thread.id, priority: priority, cancelToken: cancelToken);
		if (item is! _HNStory) {
			throw Exception('HN item ${thread.id} is not a thread');
		}
		final posts = _getMoreThread(item);
		return Thread(
			posts_: posts,
			replyCount: item.descendants,
			imageCount: 0,
			id: item.id,
			board: '',
			title: item.title,
			isSticky: false,
			time: item.time,
			attachments: posts.first.attachments_,
			isArchived: DateTime.now().difference(item.time) > const Duration(days: 14)
		);
	}

	@override
	String getWebUrlImpl(String board, [int? threadId, int? postId]) {
		return 'https://$baseUrl/item?id=${postId ?? threadId}';
	}

	@override
	Uri? get iconUrl => Uri.https(baseUrl, '/favicon.ico');

	@override
	String get name => 'Hacker News';

	@override
	String get siteData => '';
	@override
	String get siteType => 'reddit';

	@override
	bool get useTree => true;
	@override
	bool get allowsArbitraryBoards => false;
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
	bool get supportsMultipleBoards => false;
	@override
	bool get hasPagedCatalog => true;
	@override
	bool get hasExpiringThreads => false;
	@override
	bool get hasSharedIdSpace => true;

	@override
	Future<Thread> getThreadFromArchive(ThreadIdentifier thread, {Future<void> Function(Thread)? customValidator, required RequestPriority priority, CancelToken? cancelToken, String? archiveName}) => getThread(thread, priority: priority, cancelToken: cancelToken);

	@override
	List<CatalogVariantGroup> get catalogVariantGroups => const [
		CatalogVariantGroup(
			name: 'Top',
			variants: [CatalogVariant.hackerNewsTop]
		),
		CatalogVariantGroup(
			name: 'New',
			variants: [CatalogVariant.hackerNewsNew]
		),
		CatalogVariantGroup(
			name: 'Best',
			variants: [CatalogVariant.hackerNewsBest]
		),
		CatalogVariantGroup(
			name: 'Ask HN',
			variants: [CatalogVariant.hackerNewsAsk]
		),
		CatalogVariantGroup(
			name: 'Show HN',
			variants: [CatalogVariant.hackerNewsShow]
		),
		CatalogVariantGroup(
			name: 'Jobs',
			variants: [CatalogVariant.hackerNewsJobs]
		),
		CatalogVariantGroup(
			name: 'Second Chance',
			variants: [CatalogVariant.hackerNewsSecondChancePool]
		)
	];

	@override
	Future<ImageboardArchiveSearchResultPage> search(ImageboardArchiveSearchQuery query, {required int page, ImageboardArchiveSearchResultPage? lastResult, required RequestPriority priority, CancelToken? cancelToken}) async {
		final response = await client.get<Map>('https://hn.algolia.com/api/v1/search', queryParameters: {
			'query': query.query,
			'page': page - 1,
			if (query.name != null) 'tags': 'author_${query.name}'
		}, options: Options(
			extra: {
				kPriority: priority
			},
			responseType: ResponseType.json
		), cancelToken: cancelToken);
		final data = response.data!;
		return ImageboardArchiveSearchResultPage(
			page: (data['page'] as int) + 1,
			maxPage: data['nbPages'] as int?,
			count: switch ((data['nbHits'], data['hitsPerPage'], data['nbPages'])) {
				(int nbHits, int hitsPerPage, int nbPages) => min(nbHits, hitsPerPage * nbPages),
				(_, int hitsPerPage, int nbPages) => hitsPerPage * nbPages,
				(int nbHits, _, _) => nbHits,
				_ => null
			},
			canJumpToArbitraryPage: true,
			replyCountsUnreliable: false,
			imageCountsUnreliable: false,
			archive: this,
			posts: (data['hits'] as List).cast<Map>().map((hit) {
				final id = int.parse(hit['objectID'] as String);
				if (hit['comment_text'] != null) {
					return ImageboardArchiveSearchResult.post(Post(
						board: '',
						text: hit['comment_text'] as String,
						name: hit['author'] as String,
						time: DateTime.fromMillisecondsSinceEpoch((hit['created_at_i'] as int) * 1000),
						threadId: hit['story_id'] as int,
						id: id,
						spanFormat: PostSpanFormat.hackerNews,
						attachments_: []
					));
				}
				final op = Post(
					board: '',
					text: hit['story_text'] as String? ?? '',
					name: hit['author'] as String,
					time: DateTime.fromMillisecondsSinceEpoch((hit['created_at_i'] as int) * 1000),
					threadId: id,
					id: id,
					spanFormat: PostSpanFormat.hackerNews,
					attachments_: [
						if (hit['url'] case String u) _makeAttachment(id, Uri.parse(u))
					]
				);
				return ImageboardArchiveSearchResult.thread(Thread(
					posts_: [op],
					replyCount: hit['num_comments'] as int,
					imageCount: 0,
					id: op.id,
					board: '',
					title: hit['title'] as String?,
					isSticky: false,
					time: op.time,
					attachments: op.attachments_,
					isArchived: DateTime.now().difference(op.time) > const Duration(days: 14)
				));
			}).toList()
		);
	}

	@override
	String formatBoardName(String name) => this.name;

	@override
	String formatBoardNameWithoutTrailingSlash(String name) => this.name;

	@override
	int placeOrphanPost(List<Post> posts, Post post) {
		// No idea where to put it
		posts.add(post);
		return posts.length - 1;
	}

	@override
	bool get supportsUserInfo => true;

	@override
	Future<ImageboardUserInfo> getUserInfo(String username) async {
		final response = await client.get<Map>('https://hn.algolia.com/api/v1/users/$username', options: Options(responseType: ResponseType.json));
		if (response.data?['error'] case String error) {
			throw Exception(error);
		}
		return ImageboardUserInfo(
			username: username,
			webUrl: Uri.https('news.ycombinator.com', '/user', {
				'id': username
			}),
			createdAt: DateTime.tryParse(response.data!['created_at'] as String? ?? ''),
			totalKarma: response.data!['karma'] as int
		);
	}

	@override
	CatalogVariant get defaultCatalogVariant => Settings.instance.hackerNewsCatalogVariant;
	@override
	set defaultCatalogVariant(CatalogVariant value) => Settings.hackerNewsCatalogVariantSetting.set(Settings.instance, value);

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		(other is SiteHackerNews) &&
		(other.catalogThreadsPerPage == catalogThreadsPerPage) &&
		super==(other);

	@override
	int get hashCode => baseUrl.hashCode;
}

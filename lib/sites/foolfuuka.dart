import 'dart:convert';
import 'dart:math';

import 'package:chan/models/attachment.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/flag.dart';
import 'package:chan/models/post.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/util.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/models/search.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/sites/4chan.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:html/dom.dart' as dom;

extension _FoolFuukaApiName on PostTypeFilter {
	String? get apiName => switch (this) {
		PostTypeFilter.none => null,
		PostTypeFilter.onlyOPs => 'op',
		PostTypeFilter.onlyReplies => 'posts',
		PostTypeFilter.onlyStickies => 'sticky'
	};
}

class FoolFuukaException implements Exception {
	String error;
	FoolFuukaException(this.error);
	@override
	String toString() => 'FoolFuuka Error: $error';
}

class FoolFuukaArchive extends ImageboardSiteArchive {
	List<ImageboardBoard>? boards;
	@override
	final String baseUrl;
	final String staticUrl;
	@override
	final String name;
	final bool useRandomUseragent;
	final bool hasAttachmentRateLimit;
	ImageboardFlag? _makeFlag(Map data) {
		if (data['poster_country'] case String posterCountry when posterCountry.isNotEmpty) {
			return ImageboardFlag(
				name: (data['poster_country_name'] as String?) ?? const {
					'XE': 'England',
					'XS': 'Scotland',
					'XW': 'Wales'
				}[posterCountry] ?? 'Unknown',
				imageUrl: Uri.https(staticUrl, '/image/country/${posterCountry.toLowerCase()}.gif').toString(),
				imageWidth: 16,
				imageHeight: 11
			);
		}
		else if (data case {
			'troll_country_name': String trollCountryName,
			'troll_country_code': String trollCountryCode,
			'board': {'shortname': String board}
		} when trollCountryName.isNotEmpty) {
			return ImageboardFlag(
				name: trollCountryName,
				imageUrl: Uri.https(staticUrl, '/image/flags/$board/${trollCountryCode.toLowerCase()}.gif').toString(),
				imageWidth: 16,
				imageHeight: 11
			);
		}
		return null;
	}
	static PostNodeSpan makeSpan(String board, int threadId, Map<String, int> linkedPostThreadIds, String data) {
		const kShiftJISStart = '&lt;span class=&quot;sjis&quot;&gt;';
		if (data.contains(kShiftJISStart)) {
			data = data.replaceAll(kShiftJISStart, '<span class="sjis">').replaceAll('[/spoiler]', '</span>');
		}
		final body = parseFragment(data.replaceAll('<wbr>', '').replaceAll('\n', ''));
		final List<PostSpan> elements = [];
		int spoilerSpanId = 0;
		processQuotelink(dom.Element quoteLink) {
			final parts = quoteLink.attributes['href']!.split('/');
			final linkedBoard = parts[3];
			if (parts.length > 4) {
				final linkType = parts[4];
				final linkedId = parts.length > 5 ? parts[5].tryParseInt : null;
				if (linkedId == null) {
					elements.add(PostCatalogSearchSpan(
						board: linkedBoard,
						query: parts[5]
					));
				}
				else if (linkType == 'post') {
					int linkedPostThreadId = linkedPostThreadIds['$linkedBoard/$linkedId'] ?? -1;
					if (linkedId == threadId) {
						// Easy fix so that uncached linkedPostThreadIds will correctly have (OP) in almost all cases
						linkedPostThreadId = threadId;
					}
					elements.add(PostQuoteLinkSpan(
						board: linkedBoard,
						threadId: linkedPostThreadId,
						postId: linkedId
					));
				}
				else if (linkType == 'thread') {
					final linkedPostId = int.parse(parts[6].substring(1));
					elements.add(PostQuoteLinkSpan(
						board: linkedBoard,
						threadId: linkedId,
						postId: linkedPostId
					));
				}
			}
			else {
				elements.add(PostBoardLinkSpan(linkedBoard));
			}
		}
		for (final node in body.nodes) {
			if (node is dom.Element) {
				if (node.localName == 'br') {
					elements.add(const PostLineBreakSpan());
				}
				else if (node.localName == 'img' && node.attributes.containsKey('width') && node.attributes.containsKey('height')) {
					final src = node.attributes['src'];
					final width = int.tryParse(node.attributes['width']!);
					final height = int.tryParse(node.attributes['height']!);
					if (src == null || width == null || height == null) {
						continue;
					}
					elements.add(PostInlineImageSpan(
						src: src,
						width: width,
						height: height
					));
				}
				else if (node.localName == 'span') {
					if (node.classes.contains('greentext')) {
						final quoteLink = node.querySelector('a.backlink');
						if (quoteLink != null) {
							processQuotelink(quoteLink);
						}
						else {
							elements.add(PostQuoteSpan(makeSpan(board, threadId, linkedPostThreadIds, node.innerHtml)));
						}
					}
					else if (node.classes.contains('spoiler')) {
						elements.add(PostSpoilerSpan(makeSpan(board, threadId, linkedPostThreadIds, node.innerHtml), spoilerSpanId++));
					}
					else if (node.classes.contains('fortune')) {
						final css = {
							for (final pair in (node.attributes['style']?.split(';') ?? <String>[])) pair.split(':').first.trim(): pair.split(':').last.trim()
						};
						if (css['color'] case String color) {
							elements.add(PostColorSpan(makeSpan(board, threadId, linkedPostThreadIds, node.innerHtml), colorToHex(color)));
						}
						else {
							elements.add(makeSpan(board, threadId, linkedPostThreadIds, node.innerHtml));
						}
					}
					else if (node.classes.contains('sjis')) {
						elements.add(PostShiftJISSpan(node.text));
					}
					else {
						elements.addAll(Site4Chan.parsePlaintext(node.text));
					}
				}
				else if (node.localName == 'a' && node.classes.contains('backlink')) {
					processQuotelink(node);
				}
				else if (node.localName == 'strong') {
					elements.add(PostBoldSpan(makeSpan(board, threadId, linkedPostThreadIds, node.innerHtml)));
				}
				else if (node.localName == 'a' && node.attributes.containsKey('href')) {
					elements.add(PostLinkSpan(node.attributes['href']!, name: node.text.nonEmptyOrNull));
				}
				else {
					elements.addAll(Site4Chan.parsePlaintext(node.text));
				}
			}
			else {
				elements.addAll(Site4Chan.parsePlaintext(node.text ?? ''));
			}
		}
		return PostNodeSpan(elements.toList(growable: false));
	}
	Attachment? _makeAttachment(Map data) {
		if (data case {
			'board': {'shortname': String board},
			'thread_num': String threadNum,
			'media': Map media && {
				'media_orig': String mediaOrig,
				'thumb_link': String thumbLink,
				'media_filename': String filename,
				'safe_media_hash': String md5,
				'media_w': String width,
				'media_h': String height,
				'media_size': String size,
			} && ({
				'media_link': String link
			} || {
				'remote_media_link': String link
			})
		}) {
			final serverFilenameParts = mediaOrig.split('.');
			Uri url = Uri.parse(link);
			Uri thumbnailUrl = Uri.parse(thumbLink);
			if (url.host.isEmpty) {
				url = Uri.https(baseUrl, url.toString());
			}
			if (url.host == 'arch.b4k.co') {
				// They forgot to rewrite their urls
				url = url.replace(host: 'arch.b4k.dev');
			}
			if (thumbnailUrl.host.isEmpty) {
				thumbnailUrl = Uri.https(baseUrl, thumbnailUrl.toString());
			}
			return Attachment(
				board: board,
				id: serverFilenameParts.first,
				filename: filename,
				ext: '.${serverFilenameParts.last}',
				type: switch (serverFilenameParts.last) {
					'webm' || 'web' => AttachmentType.webm,
					'mp4' => AttachmentType.mp4,
					_ => AttachmentType.image
				},
				url: url.toString(),
				thumbnailUrl: thumbnailUrl.toString(),
				md5: md5,
				spoiler: media['spoiler'] == '1',
				width: width.parseInt,
				height: height.parseInt,
				threadId: threadNum.tryParseInt,
				sizeInBytes: size.tryParseInt,
				useRandomUseragent: useRandomUseragent,
				isRateLimited: hasAttachmentRateLimit
			);
		}
		return null;
	}

	static final _postLinkMatcher = RegExp('https?://[^ ]+/([^/]+)/post/([0-9]{1,18})/');

	Future<Post> _makePost(Map data, {bool resolveIds = true, required RequestPriority priority, CancelToken? cancelToken}) async {
		final board = (data['board'] as Map)['shortname'] as String;
		final int threadId = int.parse(data['thread_num'] as String);
		final int id = int.parse(data['num'] as String);
		_precachePostThreadId(board, id, threadId);
		final Map<String, int> linkedPostThreadIds = {};
		if (resolveIds) {
			for (final match in _postLinkMatcher.allMatches((data['comment_processed'] as String?) ?? '')) {
				final board = match.group(1)!;
				final postId = int.parse(match.group(2)!);
				final threadId = await _getPostThreadId(board, postId, priority: priority, cancelToken: cancelToken);
				if (threadId != null) {
					linkedPostThreadIds['$board/$postId'] = threadId;
				}
			}
		}
		int? passSinceYear;
		if (data['exif'] case String exifStr) {
			try {
				final exifData = jsonDecode(exifStr) as Map;
				passSinceYear = (exifData['since4pass'] as String?)?.tryParseInt;
			}
			catch (e) {
				// Malformed EXIF JSON
			}
		}
		final a = _makeAttachment(data);
		return Post(
			board: board,
			text: (data['comment_processed'] as String?) ?? '',
			name: (data['name'] as String?) ?? '',
			trip: data['trip'] as String?,
			time: DateTime.fromMillisecondsSinceEpoch((data['timestamp'] as int) * 1000),
			id: id,
			threadId: threadId,
			attachments_: a == null ? [] : [a],
			spanFormat: PostSpanFormat.foolFuuka,
			flag: _makeFlag(data),
			posterId: data['poster_hash'] as String?,
			extraMetadata: linkedPostThreadIds,
			passSinceYear: passSinceYear,
			isDeleted: data['deleted'] == '1'
		);
	}
	Future<Map> _getPostJson(String board, int id, {required RequestPriority priority, CancelToken? cancelToken}) async {
		if (!(await getBoards(priority: priority, cancelToken: cancelToken)).any((b) => b.name == board)) {
			throw BoardNotFoundException(board);
		}
		final response = await client.getUri(
			Uri.https(baseUrl, '/_/api/chan/post', {
				'board': board,
				'num': id.toString()
			}),
			options: Options(
				extra: {
					kPriority: priority
				},
				responseType: ResponseType.json
			),
			cancelToken: cancelToken
		);
		if (response.statusCode != 200) {
			if (response.statusCode == 404) {
				throw PostNotFoundException(board, id);
			}
			throw HTTPStatusException.fromResponse(response);
		}
		if (response.data case {'error': String error}) {
			if (error == 'Post not found.') {
				throw PostNotFoundException(board, id);
			}
			throw FoolFuukaException(error);
		}
		return response.data as Map;
	}
	final _postThreadIdCache = <String, Map<int, int?>>{};
	Future<int?> __getPostThreadId(String board, int postId, {required RequestPriority priority, CancelToken? cancelToken}) async {
		try {
			return ((await _getPostJson(board, postId, priority: priority, cancelToken: cancelToken))['thread_num'] as String?)?.tryParseInt;
		}
		on PostNotFoundException {
			return null;
		}
	}
	Future<int?> _getPostThreadId(String board, int postId, {required RequestPriority priority, CancelToken? cancelToken}) async {
		_postThreadIdCache[board] ??= {};
		if (!_postThreadIdCache[board]!.containsKey(postId)) {
			_postThreadIdCache[board]?[postId] = await __getPostThreadId(board, postId, priority: priority, cancelToken: cancelToken);
		}
		return _postThreadIdCache[board]?[postId];
	}
	void _precachePostThreadId(String board, int postId, int threadId) async {
		_postThreadIdCache.putIfAbsent(board, () => {}).putIfAbsent(postId, () => threadId);
	}
	@override
	Future<Post> getPostFromArchive(String board, int id, {required RequestPriority priority, CancelToken? cancelToken}) async {		
		return await _makePost(await _getPostJson(board, id, priority: priority, cancelToken: cancelToken), priority: priority, cancelToken: cancelToken);
	}
	Future<Thread> getThreadContainingPost(String board, int id) async {
		throw Exception('Unimplemented');
	}
	Future<Thread> _makeThread(ThreadIdentifier thread, Map data, {int? currentPage, required RequestPriority priority, CancelToken? cancelToken}) async {
		final threadData = data[thread.id.toString()] as Map;
		final op = threadData['op'] as Map;
		final replies = switch (threadData['posts']) {
			List x => x.cast<Map>(),
			Map m => m.entries.where((e) => (e.key as String?)?.tryParseInt != null).map((e) => e.value).cast<Map>(),
			_ => <Map>[]
		};
		final posts = (await Future.wait([op, ...replies].map((d) => _makePost(d, priority: priority, cancelToken: cancelToken)))).toList();
		final title = op['title'] as String?;
		final a = _makeAttachment(op);
		return Thread(
			board: thread.board,
			isDeleted: op['deleted'] == '1',
			replyCount: (op['nreplies'] as int?) ?? (posts.length - 1),
			imageCount: posts.skip(1).expand((post) => post.attachments).length,
			isArchived: false,
			posts_: posts,
			id: thread.id,
			attachments: a == null ? [] : [a],
			title: (title == null) ? null : unescape.convert(title),
			isSticky: op['sticky'] == 1,
			isLocked: op['locked'] == 1,
			time: posts.first.time,
			uniqueIPCount: (op['unique_ips'] as String?)?.tryParseInt,
			currentPage: currentPage
		);
	}
	@override
	Future<Thread> getThread(ThreadIdentifier thread, {ThreadVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) async {
		if (!(await getBoards(priority: priority, cancelToken: cancelToken)).any((b) => b.name == thread.board)) {
			throw BoardNotFoundException(thread.board);
		}
		final response = await client.getThreadUri(
			Uri.https(baseUrl, '/_/api/chan/thread', {
				'board': thread.board,
				'num': thread.id.toString()
			}),
			responseType: ResponseType.json,
			priority: priority,
			cancelToken: cancelToken
		);
		final data = response.data as Map;
		if (data['error'] case String error) {
			throw Exception(error);
		}
		return await _makeThread(thread, data, priority: priority, cancelToken: cancelToken);
	}

	Future<List<Thread>> _getCatalog(String board, int pageNumber, {required RequestPriority priority, CancelToken? cancelToken}) async {
		final response = await client.getUri<Map>(Uri.https(baseUrl, '/_/api/chan/index', {
			'board': board,
			'page': pageNumber.toString()
		}), options: Options(
				extra: {
					kPriority: priority
				},
				responseType: ResponseType.json
			),
			cancelToken: cancelToken
		);
		return Future.wait(response.data!.keys.where((threadIdStr) {
			return (response.data![threadIdStr] as Map?)?['op'] != null;
		}).map((threadIdStr) => _makeThread(ThreadIdentifier(
			board,
			int.parse(threadIdStr as String)
		), response.data!, currentPage: pageNumber, priority: priority, cancelToken: cancelToken)).toList());
	}

	@override
	Future<Catalog> getCatalogImpl(String board, {CatalogVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) async {
		final fetchedTime = DateTime.now();
		return Catalog.fromList(
			threads: await _getCatalog(board, 1, priority: priority, cancelToken: cancelToken),
			lastModified: null, // Doesn't matter for archive
			fetchedTime: fetchedTime
		);
	}

	@override
	Future<List<Thread>> getMoreCatalogImpl(String board, Thread after, {CatalogVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) => _getCatalog(board, (after.currentPage ?? 0) + 1, priority: priority, cancelToken: cancelToken);

	Future<List<ImageboardBoard>> _getBoards({required RequestPriority priority, CancelToken? cancelToken}) async {
		final response = await client.getUri(Uri.https(baseUrl, '/_/api/chan/archives'), options: Options(
			validateStatus: (x) => true,
			extra: {
				kPriority: priority
			},
			responseType: ResponseType.json
		), cancelToken: cancelToken);
		if (response.statusCode != 200) {
			throw HTTPStatusException.fromResponse(response);
		}
		final boardData = ((response.data as Map)['archives'] as Map).values.cast<Map>();
		return boardData.map((archive) {
			return ImageboardBoard(
				name: archive['shortname'] as String,
				title: archive['name'] as String,
				isWorksafe: !(archive['is_nsfw'] as bool),
				webmAudioAllowed: false
			);
		}).toList();
	}
	@override
	Future<List<ImageboardBoard>> getBoards({required RequestPriority priority, CancelToken? cancelToken}) async {
		return boards ??= await _getBoards(priority: priority, cancelToken: cancelToken);
	}

	@override
	Future<ImageboardArchiveSearchResultPage> search(ImageboardArchiveSearchQuery query, {required int page, ImageboardArchiveSearchResultPage? lastResult, required RequestPriority priority, CancelToken? cancelToken}) async {
		final knownBoards = await getBoards(priority: RequestPriority.interactive);
		final unknownBoards = query.boards.where((b) => !knownBoards.any((kb) => kb.name == b));
		if (unknownBoards.isNotEmpty) {
			throw BoardNotFoundException(unknownBoards.first);
		}
		// Don't put <Map> here. We will fail in DioMixin.assureResponse if the page gives us HTML error
		final response = await client.getUri(
			Uri.https(baseUrl, '/_/api/chan/search', {
				'text': query.query,
				'page': page.toString(),
				if (query.boards.isNotEmpty) 'boards': query.boards.join('.'),
				if (query.mediaFilter != MediaFilter.none) 'filter': query.mediaFilter == MediaFilter.onlyWithMedia ? 'text' : 'image',
				if (query.postTypeFilter.apiName != null) 'type': query.postTypeFilter.apiName,
				if (query.startDate != null) 'start': '${query.startDate!.year}-${query.startDate!.month}-${query.startDate!.day}',
				if (query.endDate != null) 'end': '${query.endDate!.year}-${query.endDate!.month}-${query.endDate!.day}',
				if (query.md5 != null) 'image': query.md5,
				if (query.deletionStatusFilter == PostDeletionStatusFilter.onlyDeleted) 'deleted': 'deleted'
				else if (query.deletionStatusFilter == PostDeletionStatusFilter.onlyNonDeleted) 'deleted': 'not-deleted',
				if (query.subject != null) 'subject': query.subject,
				if (query.name != null) 'username': query.name,
				if (query.trip != null) 'tripcode': query.trip,
				if (query.filename != null) 'filename': query.filename,
				if (query.countryCode != null) 'country': query.countryCode,
				if (query.oldestFirst) 'order': 'asc'
 			}),
			options: Options(
				validateStatus: (x) => true,
				responseType: ResponseType.json,
				extra: {
					kPriority: priority
				}
			),
			cancelToken: cancelToken
		);
		if (response.statusCode != 200) {
			throw HTTPStatusException.fromResponse(response);
		}
		final data = response.data! as Map;
		if (data['error'] case String error) {
			throw FoolFuukaException(error);
		}
		final posts = ((data['0'] as Map?)?['posts'] as Iterable).cast<Map>();
		if (posts.isEmpty) {
			throw FoolFuukaException('No results');
		}
		/// Actual number of matched results
		final totalFound = (data['meta'] as Map)['total_found'] as int;
		/// Maximum number the API will page through
		final maxResults = ((data['meta'] as Map)['max_results'] as String?)?.tryParseInt ?? totalFound;
		return ImageboardArchiveSearchResultPage(
			posts: (await Future.wait(posts.map((Map data) async {
				if (data case {
					'op': '1',
					'board': {'shortname': String board},
					'num': String id
				}) {
					return ImageboardArchiveSearchResult.thread(
						await _makeThread(ThreadIdentifier(
							board,
							id.parseInt
						), {
							data['num']: {
								'op': data
							}
						}, priority: priority, cancelToken: cancelToken)
					);
				}
				else {
					return ImageboardArchiveSearchResult.post(
						await _makePost(data, resolveIds: false, priority: priority, cancelToken: cancelToken)
					);
				}
			}))).toList(),
			page: page,
			maxPage: (min(totalFound, maxResults) / 25).ceil(),
			count: min(totalFound, maxResults),
			replyCountsUnreliable: false,
			imageCountsUnreliable: true,
			canJumpToArbitraryPage: true,
			archive: this
		);
	}

	@override
	String getWebUrlImpl(String board, [int? threadId, int? postId]) {
		String webUrl = 'https://$baseUrl/$board/';
		if (threadId != null) {
			webUrl += 'thread/$threadId';
			if (postId != null) {
				webUrl += '#$postId';
			}
		 }
		 return webUrl;
	}

	@override
	Future<BoardThreadOrPostIdentifier?> decodeUrl(Uri url) async {
		if (url.host != baseUrl) {
			return null;
		}
		final p = url.pathSegments.where((s) => s.isNotEmpty).toList();
		switch (p) {
			case [String board]:
				return BoardThreadOrPostIdentifier(board);
			case [String board, 'thread', String threadIdStr]:
				if (threadIdStr.tryParseInt case int threadId) {
					return BoardThreadOrPostIdentifier(board, threadId, const ['', 'p', 'q'].tryMapOnce(url.fragment.extractPrefixedInt));
				}
		}
		return null;
	}

	FoolFuukaArchive({
		required this.baseUrl,
		required this.staticUrl,
		required this.name,
		this.useRandomUseragent = false,
		this.hasAttachmentRateLimit = false,
		this.boards,
		required super.overrideUserAgent,
		required super.addIntrospectedHeaders
	});

	@override
	String get userAgent {
		if (useRandomUseragent) {
			return makeRandomUserAgent();
		}
		return super.userAgent;
	}

	@override
	bool get hasPagedCatalog => true;

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		(other is FoolFuukaArchive) &&
		(other.name == name) &&
		(other.baseUrl == baseUrl) &&
		(other.staticUrl == staticUrl) &&
		(other.useRandomUseragent == useRandomUseragent) &&
		listEquals(other.boards, boards) &&
		(other.hasAttachmentRateLimit == hasAttachmentRateLimit) &&
		super==(other);

	@override
	int get hashCode => baseUrl.hashCode;
}
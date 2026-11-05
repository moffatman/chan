import 'dart:convert';

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
import 'package:html/parser.dart' show parse, parseFragment;
import 'package:html/dom.dart' as dom;

int _parseInt(dynamic x) => switch (x) {
	num number => number.toInt(),
	String str => str.parseInt,
	dynamic other => throw PatternException('Cannot parse ${other.runtimeType} to int: $other')
};

int? _tryParseInt(dynamic x) => switch (x) {
	num number => number.toInt(),
	String str => str.tryParseInt,
	null => null,
	dynamic other => throw PatternException('Cannot parse ${other.runtimeType} to int: $other')
};

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
		int spoilerSpanId = 0;
		PostNodeSpan process(List<dom.Node> nodes) {
			final List<PostSpan> elements = [];
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
			for (final node in nodes) {
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
								elements.add(PostQuoteSpan(process(node.nodes)));
							}
						}
						else if (node.classes.contains('spoiler')) {
							elements.add(PostSpoilerSpan(process(node.nodes), spoilerSpanId++));
						}
						else if (node.classes.contains('fortune')) {
							final css = {
								for (final pair in (node.attributes['style']?.split(';') ?? <String>[])) pair.split(':').first.trim(): pair.split(':').last.trim()
							};
							if (css['color'] case String color) {
								elements.add(PostColorSpan(process(node.nodes), colorToHex(color)));
							}
							else {
								elements.add(process(node.nodes));
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
						elements.add(PostBoldSpan(process(node.nodes)));
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
		return process(body.nodes);
	}
	Attachment? _makeAttachment(Map data) {
		if (data case {
			'board': {'shortname': String board},
			'thread_num': Object threadNum,
			'media': Map media && {
				'media_orig': String mediaOrig,
				'thumb_link': String thumbLink,
				'media_filename': String filename,
				'safe_media_hash': String md5,
				'media_w': Object width,
				'media_h': Object height,
				'media_size': Object size,
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
				width: _parseInt(width),
				height: _parseInt(height),
				threadId: _tryParseInt(threadNum),
				sizeInBytes: _tryParseInt(size),
				useRandomUseragent: useRandomUseragent,
				isRateLimited: hasAttachmentRateLimit
			);
		}
		return null;
	}

	static final _postLinkMatcher = RegExp('https?://[^ ]+/([^/]+)/post/([0-9]{1,18})/');

	Future<Post> _makePost(Map data, {bool resolveIds = true, required RequestPriority priority, CancelToken? cancelToken}) async {
		final board = (data['board'] as Map)['shortname'] as String;
		final int threadId = _parseInt(data['thread_num']);
		final int id = _parseInt(data['num']);
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
				passSinceYear = _tryParseInt(exifData['since4pass']);
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
			time: DateTimeConversion.fromSecondsSinceEpoch(data['timestamp'] as int),
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
			throw BoardNotFoundException(this, board);
		}
		if (id == 0) {
			// FoolFuuka engine doesn't handle this properly
			throw PostNotFoundException(this, board, id);
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
				throw PostNotFoundException(this, board, id);
			}
			throw HTTPStatusException.fromResponse(response);
		}
		if (response.data case {'error': String error}) {
			if (error == 'Post not found.') {
				throw PostNotFoundException(this, board, id);
			}
			throw FoolFuukaException(error);
		}
		return response.data as Map;
	}
	final _postThreadIdCache = <String, Map<int, int?>>{};
	Future<int?> __getPostThreadId(String board, int postId, {required RequestPriority priority, CancelToken? cancelToken}) async {
		try {
			return _tryParseInt((await _getPostJson(board, postId, priority: priority, cancelToken: cancelToken))['thread_num']);
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
			uniqueIPCount: _tryParseInt(op['unique_ips']),
			currentPage: currentPage
		);
	}
	@override
	Future<Thread> getThread(ThreadIdentifier thread, {ThreadVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) async {
		if (!(await getBoards(priority: priority, cancelToken: cancelToken)).any((b) => b.name == thread.board)) {
			throw BoardNotFoundException(this, thread.board);
		}
		final response = await getThreadUri(
			thread,
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
				webmAudioAllowed: false,
				filesPerPost: 1
			);
		}).toList();
	}
	@override
	Future<List<ImageboardBoard>> getBoards({required RequestPriority priority, CancelToken? cancelToken}) async {
		return boards ??= await _getBoards(priority: priority, cancelToken: cancelToken);
	}

	static final _fileMetadataPattern = RegExp(r'(\d+(?:\.\d+)?)(B|KiB|MiB), (\d+)x(\d+)');
	static final _threadRepliesPattern = RegExp(r'Replies: (\d+)');

	@override
	Future<ImageboardArchiveSearchResultPage> search(ImageboardArchiveSearchQuery query, {required int page, ImageboardArchiveSearchResultPage? lastResult, required RequestPriority priority, CancelToken? cancelToken}) async {
		final knownBoards = await getBoards(priority: RequestPriority.interactive);
		final unknownBoards = query.boards.where((b) => !knownBoards.any((kb) => kb.name == b));
		if (unknownBoards.isNotEmpty) {
			throw BoardNotFoundException(this, unknownBoards.first);
		}
		final response = await client.getUri(
			Uri.https(baseUrl, '/_/search/${{
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
			}.entries.map((e) => '${e.key}/${e.value}').join('/')}/'),
			options: Options(
				validateStatus: (x) => true,
				responseType: ResponseType.plain,
				extra: {
					kPriority: priority
				}
			),
			cancelToken: cancelToken
		);
		if (response.statusCode != 200) {
			throw HTTPStatusException.fromResponse(response);
		}
		final document = parse(response.data);
		if (document.querySelector('.alert') case dom.Element alert) {
			throw FoolFuukaException(alert.nodes.last.text?.trim() ?? alert.innerHtml);
		}
		final posts = document.querySelectorAll('.post');
		if (posts.isEmpty) {
			throw FoolFuukaException('No results');
		}
		/// Maximum number the API will page through
		final maxResults = RegExp(r'(\d+) results found').firstMatch(document.querySelector('small')!.text)!.group(1)!.parseInt;
		return ImageboardArchiveSearchResultPage(
			posts: posts.map((dom.Element data) => unsafe(data.outerHtml, () {
				final board = data.attributes['data-board']!;
				final id = data.id.parseInt;
				final asLink = _decodeUrl(Uri.parse(data.querySelector('.post_controls a.parent')!.attributes['href']!))!;
				Attachment? attachment;
				final img = data.querySelector('img.post_image');
				final filename = data.querySelector('.post_file_filename')?.text;
				final fileMetadata = data.querySelector('.post_file_metadata')?.text.trim();
				if (img != null && filename != null && fileMetadata != null) {
					final href = img.parent!.attributes['href']!;
					final url = Uri.parse(href);
					final metadata = _fileMetadataPattern.firstMatch(fileMetadata)!;
					int multiplier = 1;
					final fileSizePrefix = metadata.group(2)!.toLowerCase();
					if (fileSizePrefix.startsWith('m')) {
						multiplier = kMB;
					} else if (fileSizePrefix.startsWith('k')) {
						multiplier = kKB;
					}
					final serverFilename = url.pathSegments.last;
					attachment = Attachment(
						board: board,
						type: AttachmentType.fromFilename(serverFilename),
						id: serverFilename.beforeFirst('.'),
						ext: '.${serverFilename.afterLast('.')}',
						filename: filename,
						url: href,
						thumbnailUrl: img.attributes['src']!,
						md5: img.attributes['data-md5'] ?? '',
						width: metadata.group(3)?.parseInt,
						height: metadata.group(4)?.parseInt,
						threadId: asLink.threadId,
						sizeInBytes: (metadata.group(1)!.parseDouble * multiplier).round(),
						useRandomUseragent: useRandomUseragent,
						isRateLimited: hasAttachmentRateLimit,
						spoiler: img.classes.contains('is_spoiler_image')
					);
				}
				ImageboardFlag? flag;
				if (data.querySelector('.flag') case final flagElement?) {
					final pathParts = Uri.parse(flagElement.parent!.attributes['href']!).pathSegments;
					final String imagePath;
					if (pathParts[1] == 'troll_country') {
						// /$board/troll_country/$code
						imagePath = '/image/flags/${pathParts[0]}/${pathParts[2].toLowerCase()}.gif';
					}
					else {
						// /$board/country/$code
						imagePath = '/image/country/${pathParts[2].toLowerCase()}.gif';
					}
					flag = ImageboardFlag(
						imageHeight: 11,
						imageWidth: 16,
						name: flagElement.attributes['title']!.beforeFirst('.'),
						imageUrl: Uri.https(staticUrl, imagePath).toString()
					);
				}
				final asPost = Post(
					board: board,
					text: data.querySelector('.text')!.innerHtml,
					name: data.querySelector('.post_author')!.text,
					time: DateTime.parse(data.querySelector('time')!.attributes['datetime']!),
					threadId: asLink.threadId!,
					id: id,
					spanFormat: PostSpanFormat.foolFuuka,
					attachments_: attachment == null ? [] : [attachment],
					flag: flag,
					trip: data.querySelector('.post_tripcode')?.text.trim().nonEmptyOrNull,
					posterId: data.querySelector('.poster_hash')?.text.trim().afterLast(':'),
					// 'Pass user since 2026.'
					passSinceYear: data.querySelector('i.icon-tag')?.attributes['title']?.afterLast(' ').beforeFirst('.').tryParseInt,
					isDeleted: data.querySelector('i.icon-trash') != null
				);
				if (!data.classes.contains('post_is_op')) {
					return ImageboardArchiveSearchResult.post(asPost);
				}
				return ImageboardArchiveSearchResult.thread(Thread(
					posts_: [asPost],
					replyCount: data.querySelector('.post_data')!.nodes.tryMapOnce((node) {
						if (node is dom.Text) {
							return _threadRepliesPattern.firstMatch(node.text)?.group(1)?.tryParseInt;
						}
						return null;
					})!,
					imageCount: 1, // unreliable
					id: id,
					board: board,
					title: data.querySelector('.post_title')?.text,
					isSticky: data.querySelector('i.icon-pushpin') != null,
					time: asPost.time,
					attachments: asPost.attachments_
				));
			})).toList(),
			page: page,
			maxPage: (maxResults / 25).ceil(),
			count: maxResults,
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

	BoardThreadOrPostIdentifier? _decodeUrl(Uri url) {
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

	@override
	bool decodeUrlPossible(Uri url) {
		return _decodeUrl(url) != null;
	}

	@override
	Future<BoardThreadOrPostIdentifier?> decodeUrl(Uri url, {CancelToken? cancelToken}) async {
		return _decodeUrl(url);
	}

	FoolFuukaArchive({
		required this.baseUrl,
		required this.staticUrl,
		required this.name,
		this.useRandomUseragent = false,
		this.hasAttachmentRateLimit = false,
		this.boards,
		required super.overrideUserAgent,
		required super.addIntrospectedHeaders,
		required super.preferHttp3WithoutAltSvc
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
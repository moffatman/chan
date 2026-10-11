import 'dart:convert';

import 'package:chan/models/attachment.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/search.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/util.dart';
import 'package:chan/util.dart';
import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart';

class AyaseQuartArchive extends ImageboardSiteArchive {
	@override
	final String baseUrl;
	@override
	final String name;
	List<ImageboardBoard>? boards;

	AyaseQuartArchive({
		required this.baseUrl,
		required this.name,
		this.boards,
		required super.overrideUserAgent,
		required super.addIntrospectedHeaders,
		required super.preferHttp3WithoutAltSvc
	});

	BoardThreadOrPostIdentifier? _decodeUrl(Uri url) {
		if (!url.host.endsWith(baseUrl)) {
			return null;
		}
		final p = url.pathSegments.where((s) => s.isNotEmpty).toList();
		switch (p) {
			case [String board, 'catalog']:
				return BoardThreadOrPostIdentifier(board);
			case [String board, 'thread', String threadIdStr]:
				if (threadIdStr.tryParseInt case int threadId) {
					return BoardThreadOrPostIdentifier(board, threadId, url.fragment.extractPrefixedInt('p'));
				}
		}
		return null;
	}

	@override
	Future<BoardThreadOrPostIdentifier?> decodeUrl(Uri url, {CancelToken? cancelToken}) async {
		return _decodeUrl(url);
	}

	@override
	bool decodeUrlPossible(Uri url) {
		return _decodeUrl(url) != null;
	}

	Future<List<ImageboardBoard>> _getBoards({required RequestPriority priority, CancelToken? cancelToken}) async {
		final response = await client.getUri(Uri.https(baseUrl, '/'), options: Options(
			validateStatus: (x) => true,
			extra: {
				kPriority: priority
			},
			responseType: ResponseType.plain
		), cancelToken: cancelToken);
		final document = parse(response.data);
		final pattern = RegExp(r'/([^/]+)/ - (.*)');
		return document.querySelector('ul.ul3col')!.querySelectorAll('a').tryMap((a) {
			final match = pattern.firstMatch(a.text);
			if (match == null) {
				return null;
			}
			return ImageboardBoard(
				name: match.group(1)!,
				title: match.group(2)!,
				isWorksafe: false,
				webmAudioAllowed: false,
				filesPerPost: 1
			);
		}).toList();
	}

	@override
	Future<List<ImageboardBoard>> getBoards({required RequestPriority priority, CancelToken? cancelToken}) async {
		return boards ??= await _getBoards(priority: priority, cancelToken: cancelToken);
	}

	static final _metaPattern = RegExp(r'R: (\d+) \/ F: (\d+)');
	static final _fileDetailsPattern = RegExp(r'^\(([\d\.]+) ([KMG]?B)\, (\d+)x(\d+)\)$');

	@override
	Future<Catalog> getCatalogImpl(String board, {CatalogVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) async {
		final fetchedTime = DateTime.now();
		// There are more pages but this is for debugging only
		final response = await client.getUri(Uri.https(baseUrl, '/$board/catalog'), options: Options(
			extra: {
				kPriority: priority
			}
		), cancelToken: cancelToken);
		final document = parse(response.data);
		return Catalog.fromList(
			fetchedTime: fetchedTime,
			lastModified: null, // No 304 handling
			threads: document.querySelectorAll('.thread').map((element) {
				final metaMatch = _metaPattern.firstMatch(element.querySelector('.meta')!.text)!;
				final id = element.id.parseInt;
				final op = Post(
					board: board,
					text: element.querySelector('.teaser')?.innerHtml ?? '',
					name: 'Anonymous', // Missing
					time: DateTimeConversion.fromSecondsSinceEpoch(element.querySelector('.dateTime')!.attributes['data-utc']!.parseInt),
					threadId: id,
					id: id,
					spanFormat: PostSpanFormat.chan4,
					attachments_: element.querySelectorAll('.fileThumb > img').map((attachment) {
						final url = 'https://$baseUrl${attachment.attributes['data-full_media_src']!}';
						return Attachment(
							type: AttachmentType.fromFilename(url),
							board: board,
							id: attachment.id,
							ext: url.afterLast('.'),
							filename: FileBasename.get(url),
							url: url,
							thumbnailUrl: 'https://$baseUrl${attachment.attributes['data-thumb_src']!}',
							md5: '',
							width: null,
							height: null,
							threadId: id,
							sizeInBytes: null
						);
					}).toList()
				);
				return Thread(
					posts_: [op],
					id: op.id,
					board: board,
					replyCount: metaMatch.group(1)!.parseInt,
					imageCount: metaMatch.group(2)!.parseInt,
					title: element.querySelector('.post_title')?.text,
					isSticky: false, // Seem not to be included
					time: op.time,
					attachments: op.attachments_
				);
			}).toList()
		);
	}

	Post _makePost(dom.Element element) {
		final board = element.parent!.attributes['data-board']!;
		final threadId = element.parent!.attributes['data-thread-num']!.parseInt;
		final id = element.parent!.attributes['data-num']!.parseInt;
		return Post(
			board: board,
			text: element.querySelector('.postMessage')!.innerHtml,
			name: switch (element.querySelector('.name')?.text) {
				null || 'Anon' => 'Anonymous',
				String name => name
			},
			capcode: element.querySelector('.capcode')?.text.replaceFirst('## ', ''),
			time: DateTimeConversion.fromSecondsSinceEpoch(element.querySelector('.dateTime')!.attributes['data-utc']!.parseInt),
			threadId: threadId,
			id: id,
			spanFormat: PostSpanFormat.chan4,
			attachments_: element.querySelectorAll('.file').map((file) {
				final img = file.querySelector('.fileThumb > img')!;
				final url = 'https://$baseUrl${img.attributes['data-full_media_src']!}';
				final fileDetailsMatch = _fileDetailsPattern.firstMatch(file.querySelector('.fileText > span')!.text)!;
				return Attachment(
					type: AttachmentType.fromFilename(url),
					board: board,
					id: img.id,
					ext: url.afterLast('.'),
					filename: file.querySelector('.fileText > a')!.text,
					url: url,
					thumbnailUrl: 'https://$baseUrl${img.attributes['data-thumb_src']!}',
					md5: file.attributes['data-media-hash'] ?? '',
					width: fileDetailsMatch.group(3)!.parseInt,
					height: fileDetailsMatch.group(4)!.parseInt,
					threadId: threadId,
					sizeInBytes: (fileDetailsMatch.group(1)!.parseDouble * switch (fileDetailsMatch.group(2)) {
						'KB' => kKB,
						'MB' => kMB,
						'GB' => kGB,
						_ => 1
					}).round()
				);
			}).toList()
		);
	}

	@override
	Future<Thread> getThread(ThreadIdentifier thread, {ThreadVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) async {
		final response = await client.getUri<String>(Uri.https(baseUrl, '/${thread.board}/thread/${thread.id}'), options: Options(
			responseType: ResponseType.plain,
			extra: {
				kPriority: priority
			}
		), cancelToken: cancelToken);
		final document = parse(response.data);
		final posts = document.querySelectorAll('.post.reply').map(_makePost).toList();
		final (int replyCount, int imageCount) = switch (document.querySelector('.board')?.nodes) {
			[dom.Text(), dom.Element(localName: 'b', text: String replyCountStr), dom.Text(), dom.Element(localName: 'b', text: String imageCountStr), ...] => (replyCountStr.parseInt, imageCountStr.parseInt),
			_ => throw UnexpectedFormatException('Could not parse thread metadata', additionalFiles: {
				'page.html': utf8.encode(response.data!)
			})
		};
		return Thread(
			posts_: posts,
			replyCount: replyCount,
			imageCount: imageCount,
			id: thread.id,
			board: thread.board,
			title: document.querySelector('subject')?.text,
			isSticky: document.querySelector('.stickyIcon') != null,
			time: posts.first.time,
			attachments: posts.first.attachments_,
			isLocked: document.querySelector('.closedIcon') != null
		);
	}

	@override
	String getWebUrlImpl(String board, [int? threadId, int? postId]) {
		if (threadId != null) {
			if (postId != null) {
				return 'https://$baseUrl/$board/thread/$threadId#p$postId';
			}
			return 'https://$baseUrl/$board/thread/$threadId';
		}
		return 'https://$baseUrl/$board/catalog';
	}

	Future<ImageboardArchiveSearchResultPage> _search(Map<String, String> args, {
		int page = 1,
		required RequestPriority priority,
		CancelToken? cancelToken
	}) async {
		final response = await client.getUri(Uri.https(baseUrl, '/fts', {
			'page': page.toString(),
			...args
		}), options: Options(
			extra: {
				kPriority: priority
			}
		), cancelToken: cancelToken);
		final document = parse(response.data);
		final searchHits = RegExp(r'search hits: ([\d,]+)').firstMatch(document.querySelector('#resulttop')!.nodes.first.text!)!.group(1)!.replaceAll(',', '').parseInt;
		return ImageboardArchiveSearchResultPage(
			posts: document.querySelectorAll('.post.reply').map((element) {
				final post = _makePost(element);
				if (!post.isThread) {
					return ImageboardArchiveSearchResult.post(post);
				}
				return ImageboardArchiveSearchResult.thread(Thread(
					posts_: [post],
					replyCount: 0,
					imageCount: 0,
					id: post.id,
					board: post.board,
					title: element.querySelector('.subject')?.text,
					isSticky: element.querySelector('.stickyIcon') != null,
					time: post.time,
					attachments: post.attachments_,
					isLocked: document.querySelector('.closedIcon') != null
				));
			}).toList(),
			replyCountsUnreliable: true,
			imageCountsUnreliable: true,
			count: searchHits,
			page: page,
			maxPage: (searchHits / 50).ceil(),
			archive: this,
			canJumpToArbitraryPage: true
		);
	}

	@override
	Future<Post> getPostFromArchive(String board, int id, {required RequestPriority priority, CancelToken? cancelToken}) async {
		final results = await _search({
			'boards': board,
			'num': id.toString()
		}, priority: priority, cancelToken: cancelToken);
		return results.posts.first.post!;
	}

	@override
	Future<ImageboardArchiveSearchResultPage> search(ImageboardArchiveSearchQuery query, {required int page, ImageboardArchiveSearchResultPage? lastResult, required RequestPriority priority, CancelToken? cancelToken}) async {
		if (query.name != null) {
			throw UnsupportedError('AyaseQuart does not support searching by name');
		}
		if (query.countryCode != null) {
			throw UnsupportedError('AyaseQuart does not support searching by country');
		}
		final knownBoards = await getBoards(priority: RequestPriority.interactive);
		final unknownBoards = query.boards.where((b) => !knownBoards.any((kb) => kb.name == b));
		if (unknownBoards.isNotEmpty) {
			throw BoardNotFoundException(this, unknownBoards.first);
		}
		return _search({
			'boards': query.boards.join(','),
			'hits_per_page': '50',
			'comment': query.query,
			if (query.mediaFilter == MediaFilter.onlyWithMedia) 'has_file': 'y'
			else if (query.mediaFilter == MediaFilter.onlyWithNoMedia) 'has_no_file': 'y',
			if (query.postTypeFilter == PostTypeFilter.onlyOPs) 'is_op': 'y'
			else if (query.postTypeFilter == PostTypeFilter.onlyReplies) 'is_not_op': 'y'
			else if (query.postTypeFilter == PostTypeFilter.onlyStickies) 'is_sticky': 'y',
			if (query.startDate case final startDate?) 'date_after': '${startDate.year}-${startDate.dMM}-${startDate.dDD}',
			if (query.endDate case final endDate?) 'date_before': '${endDate.year}-${endDate.dMM}-${endDate.dDD}',
			if (query.md5 case final md5?) 'media_hash': md5,
			if (query.deletionStatusFilter == PostDeletionStatusFilter.onlyNonDeleted) 'is_not_deleted': 'y'
			else if (query.deletionStatusFilter == PostDeletionStatusFilter.onlyDeleted) 'is_deleted': 'y',
			if (query.trip case final trip?) 'trip': trip,
			if (query.subject case final subject?) 'title': subject,
			if (query.filename case final filename?) 'media_filename': filename,
			if (query.oldestFirst) 'order_by': 'asc',
		}, page: page, priority: priority, cancelToken: cancelToken);
	}

	@override
	Future<ImageboardRedirectGateway?> getRedirectGateway(Uri uri, String? Function() title, Future<String?> Function() html) async {
		if (uri.host == baseUrl) {
			if (['Confirming legitimate browser session', 'Verifying request...'].contains(title())) {
				return const ImageboardRedirectGateway(name: 'Anubis', alwaysNeedsManualSolving: false);
			}
		}
		return null;
	}
}

import 'package:chan/models/board.dart';
import 'package:chan/models/parent_and_child.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/search.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/sites/4chan.dart';
import 'package:chan/sites/helpers/forum.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/util.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart';

class SiteJForum extends ImageboardSite with ForumSite {
	@override
	final String baseUrl;
	final String basePath;
	@override
	final String name;
	@override
	final String defaultUsername;
	final String faviconPath;
	@override
	Uri? get iconUrl => Uri.https(baseUrl, faviconPath);
	final int threadsPerPage;
	@override
	final int postsPerPage;
	final int searchResultsPerPage;

	SiteJForum({
		required this.baseUrl,
		required this.basePath,
		required this.name,
		required this.defaultUsername,
		required this.faviconPath,
		required this.threadsPerPage,
		required this.postsPerPage,
		required this.searchResultsPerPage,
		required super.archives,
		required super.imageHeaders,
		required super.videoHeaders,
		required super.overrideUserAgent
	});

	static void _trim(dom.NodeList nodes) {
		// Remove leading and trailing whitespace
		while (switch (nodes.tryFirst) {
			dom.Element e => e.localName == 'br',
			dom.Text t => t.data.trim().isEmpty,
			_ => false
		}) {
			nodes.first.remove();
		}
		if (nodes.tryFirst case dom.Text text) {
			text.data = text.data.trimLeft();
		}
		while (switch (nodes.tryLast) {
			dom.Element e => e.localName == 'br',
			dom.Text t => t.data.trim().isEmpty,
			_ => false
		}) {
			nodes.last.remove();
		}
		if (nodes.tryLast case dom.Text text) {
			text.data = text.data.trimRight();
		}
		// Trim interior space around <br>
		for (int i = 1; i < nodes.length - 1; i++) {
			if (nodes[i] case dom.Element elem) {
				if (elem.localName == 'br') {
					if (nodes[i - 1] case dom.Text text) {
						text.data = text.data.trimRight();
					}
					if (nodes[i + 1] case dom.Text text) {
						text.data = text.data.trimLeft();
					}
				}
			}
		}
	}

	static PostNodeSpan makeSpan(String text) {
		final body = parseFragment(text, container: 'td');
		int quoteSpanId = 0;
		Iterable<PostSpan> visit(dom.NodeList nodes, {int listDepth = 0}) sync* {
			_trim(nodes);
			bool addLinebreakBefore = false;
			for (final node in nodes) {
				if (node is dom.Element) {
					if (node.localName == 'br') {
						yield const PostLineBreakSpan();
						addLinebreakBefore = false;
						continue;
					}
					if (node.localName == 'strong' || node.localName == 'b') {
						yield PostBoldSpan(PostNodeSpan(visit(node.nodes).toList()));
					}
					else if (node.localName == 'a') {
						yield PostLinkSpan(Uri.encodeFull(node.attributes['href']!), name: node.text.trim().nonEmptyOrNull);
					}
					else if (node.localName == 'font' && node.attributes.containsKey('color')) {
						yield PostColorSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)), colorToHex(node.attributes['color']!));
					}
					else if (node.localName == 'p') {
						yield* visit(node.nodes);
					}
					else if (node.localName == 'blockquote') {
						if (node.attributes['style']?.contains('display: none;') ?? false) {
							// Nested blockquote, don't try these
							continue;
						}
						final quoteContent = node.children.first;
						final cite = quoteContent.children.tryFirstWhere((c) => c.localName == 'cite');
						final citeText = cite?.text;
						cite?.remove();
						final String? author;
						if (citeText != null && citeText.endsWith(' wrote:')) {
							author = citeText.substring(0, citeText.length - 7);
						}
						else {
							author = null;
						}
						final quote = PostQuoteSpan(PostNodeSpan(visit(quoteContent.nodes).toList()));
						yield PostWeakQuoteLinkSpan(
							id: quoteSpanId++,
							quote: quote,
							author: author
						);
						addLinebreakBefore = true;
					}
					else if (node.localName == 'input' && node.classes.contains('quote-expand')) {
						// Skip. This should have been filtered out in the getThread() though
					}
					else {
						yield PostTextSpan(node.outerHtml);
					}
				}
				else if (node.text?.nonEmptyOrNull case String text) {
					if (addLinebreakBefore) {
						yield const PostLineBreakSpan();
						addLinebreakBefore = false;
					}
					yield* Site4Chan.parsePlaintext(text);
				}
			}
		}
		return PostNodeSpan(visit(body.nodes).toList(growable: false));
	}

	/// Board is a weak concept in JForum. Sometimes we need to find it.
	Future<String> _lookupBoard(int threadId) async {
		// Maybe we already have the thread
		if (persistence?.imageboardKey case String imageboardKey) {
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
		// May need to fetch the thread to fill in the board
		return (await getThread(ThreadIdentifier('', threadId), priority: RequestPriority.functional)).board;
	}

	@override
	Future<BoardThreadOrPostIdentifier?> decodeUrl(Uri url) async {
		if (url.host != baseUrl) {
			return null;
		}
		if (!url.path.startsWith(basePath)) {
			return null;
		}
		final path = url.path.substring(basePath.length);
		if (RegExp(r'^/forums/show/(\d+)\.page').firstMatch(path) case Match match) {
			final prefix = '${match.group(1)}.';
			final board = persistence?.boards.tryFirstWhere((b) => b.name.startsWith(prefix));
			if (board != null) {
				return BoardThreadOrPostIdentifier(board.name);
			}
		}
		if (RegExp(r'^/posts/list/(?:(\d+)\/)?(\d+)\.page').firstMatch(path) case Match match) {
			final threadId = int.parse(match.group(2)!);
			final board = await _lookupBoard(threadId);
			if (url.fragment.tryParseInt case int postId) {
				return BoardThreadOrPostIdentifier(board, threadId, postId);
			}
			if (match.group(1)?.tryParseInt case int postOffset) {
				final page = (postOffset ~/ postsPerPage) + 1;
				return BoardThreadOrPostIdentifier(board, threadId, -page);
			}
			return BoardThreadOrPostIdentifier(board, threadId);
		}
		if (RegExp(r'^/posts/preList/(\d+)/(\d+)\.page').firstMatch(path) case Match match) {
			final threadId = int.parse(match.group(1)!);
			final postId = int.parse(match.group(2)!);
			final board = await _lookupBoard(threadId);
			return BoardThreadOrPostIdentifier(board, threadId, postId);
		}
		return null;
	}

	@override
	ImageboardBoardPopularityType? get boardPopularityType => ImageboardBoardPopularityType.postsCount;

	@override
	Future<List<ImageboardBoard>> getBoards({required RequestPriority priority, CancelToken? cancelToken}) async {
		final response = await client.getUri(Uri.https(baseUrl, '$basePath/forums/list.page'), options: Options(
			responseType: ResponseType.plain,
			extra: {
				kPriority: priority
			}
		), cancelToken: cancelToken);
		final document = parse(response.data);
		return document.querySelectorAll('.forum-list').tryMap((forum) {
			final link = forum.querySelector('.forumlink a');
			final boardCode = link?.attributes['href']?.afterLast('/').beforeFirst('.');
			final description = forum.querySelector('.genmed')?.text.trim();
			final postCount = forum.querySelectorAll('.gensmall').tryLast?.text.trim().tryParseInt;
			if (link == null || boardCode == null || description == null || postCount == null) {
				return null;
			}
			return ImageboardBoard(
				name: '$boardCode.${link.text.trim()}',
				title: description,
				isWorksafe: true,
				webmAudioAllowed: true,
				popularity: postCount
			);
		}).toList();
	}

	@override
	Future<CaptchaRequest> getCaptchaRequest(String board, int? threadId, {CancelToken? cancelToken}) async {
		return const NoCaptchaRequest();
	}

	static final _timePattern = RegExp(r'(\d\d)/(\d\d)/(\d+) (\d\d):(\d\d)');

	static DateTime? _parseTime(String time) {
		final match = _timePattern.firstMatch(time);
		if (match == null) {
			return null;
		}
		final month = match.group(1)?.tryParseInt;
		final day = match.group(2)?.tryParseInt;
		final year = match.group(3)?.tryParseInt;
		final hour = match.group(4)?.tryParseInt;
		final minute = match.group(5)?.tryParseInt;
		if (month == null || day == null || year == null || hour == null || minute == null) {
			return null;
		}
		return DateTime(year, month, day, hour, minute);
	}

	static final _catalogReplyCountPattern = RegExp(r'Replies: (\d+)');

	Future<List<Thread>> _getCatalogPage(String board, int page, {required RequestPriority priority, CancelToken? cancelToken}) async {
		final boardCode = board.beforeFirst('.');
		final response = await client.getUri(Uri.https(baseUrl, '$basePath/forums/show/${page == 1 ? '' : '${(page - 1) * threadsPerPage}/'}$boardCode.page'), options: Options(
			responseType: ResponseType.plain,
			extra: {
				kPriority: priority
			}
		), cancelToken: cancelToken);
		final document = parse(response.data);
		return document.querySelectorAll('.topic-list').map((e) {
			final replyCountStr = e.querySelector('.answers')?.children.tryFirst?.text;
			final int replyCount = _catalogReplyCountPattern.firstMatch(replyCountStr ?? '')?.group(1)?.tryParseInt ?? 0;
			final subject = e.querySelector('span.subject-line a')!;
			final firstPost = e.querySelector('.first-post')!;
			final id = int.parse(subject.attributes['href']!.afterLast('/').beforeFirst('.'));
			final time = _parseTime(firstPost.text)!;
			final lastPostTime = e.querySelector('.last-message')?.nodes.first.text;
			return Thread(
				attachments: const [],
				posts_: [
					Post(
						board: board,
						id: id,
						text: '',
						name: firstPost.querySelector('a')!.text,
						time: time,
						threadId: id,
						spanFormat: PostSpanFormat.jForum,
						attachments_: const []
					),
					// Placeholder entry for last new post. Then we can tell if the thread is modified or not.
					if (replyCount > 0 && lastPostTime != null) Post(
						board: board,
						id: -(firstPost.querySelectorAll('span').tryLast?.querySelectorAll('a').tryLast?.text.tryParseInt ?? 1),
						text: '',
						name: e.querySelector('.last-message a')!.text,
						time: _parseTime(lastPostTime)!,
						threadId: id,
						spanFormat: PostSpanFormat.pageStub,
						attachments_: const []
					),
				],
				replyCount: replyCount,
				imageCount: 0,
				id: id,
				board: board,
				title: subject.text.trim().nonEmptyOrNull,
				isSticky: e.classes.contains('row1announce'),
				isLocked: e.querySelector('.icon_folder_lock') != null,
				time: time,
				currentPage: page
			);
		}).toList();
	}

	@override
	Future<List<Thread>> getCatalogImpl(String board, {CatalogVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) {
		return _getCatalogPage(board, 1, priority: priority);
	}

	@override
	Future<List<Thread>> getMoreCatalogImpl(String board, Thread after, {CatalogVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) {
		return _getCatalogPage(board, (after.currentPage ?? 1) + 1, priority: priority, cancelToken: cancelToken);
	}

	@override
	Future<Post> getPostFromArchive(String board, int id, {required RequestPriority priority, CancelToken? cancelToken}) {
		throw UnimplementedError();
	}

	List<Post> _getPostsFromThreadPage(int threadId, dom.Document document) {
		final board = document.querySelectorAll('.maintitleDiv1 a.maintitle').tryMapOnce((a) {
			final href = a.attributes['href'];
			if (href == null || !href.startsWith('$basePath/forums/show/')) {
				return null;
			}
			return '${href.afterLast('/').beforeFirst('.')}.${a.text}';
		})!;
		int currentPageNumber = 1;
		int lastPageNumber = 1;
		for (final e in document.querySelector('.pagination')?.children ?? <dom.Element>[]) {
			if (e.text.tryParseInt case int pageNumber) {
				lastPageNumber = pageNumber;
				if (e.classes.contains('current')) {
					currentPageNumber = pageNumber;
				}
			}
		}
		Post generateStub(int pageNumber) => Post(
			board: board,
			threadId: threadId,
			text: '',
			// Not actually sure what will happen here now that OP name is unknown
			name: '',
			time: DateTime.now(), // arbitrary
			id: -pageNumber,
			spanFormat: PostSpanFormat.pageStub,
			attachments_: const [],
			hasOmittedReplies: pageNumber != currentPageNumber || pageNumber == lastPageNumber
		);
		final pagesBefore = Iterable.generate(currentPageNumber, (i) => generateStub(i + 1));
		final pagesAfter = Iterable.generate(lastPageNumber - currentPageNumber, (i) => generateStub(i + 1 + currentPageNumber));
		final postinfos = document.querySelectorAll('.postinfo');
		final postrows = document.querySelectorAll('.postrow');
		if (postrows.length != postinfos.length) {
			throw Exception('Metadata mismatch, postrows.length=${postrows.length}, postinfos.length=${postinfos.length}');
		}
		final realPosts = List.generate(postrows.length, (i) {
			final postinfo = postinfos[i];
			final postrow = postrows[i];
			final dateLink = postinfo.querySelector('.date')!.children[1];
			final text = postrow.querySelector('.postbody td')!;
			// Remove the "Click to show earlier quotes" button
			for (final child in text.nodes.toList()) {
				if (child is dom.Element && child.localName == 'input') {
					child.remove();
				}
			}
			return Post(
				board: board,
				threadId: threadId,
				id: int.parse(dateLink.attributes['name']!),
				text: text.innerHtml.trim(),
				parentId: -currentPageNumber,
				name: postrow.querySelector('.postShowUserDiv .genmed')?.text ?? '',
				time: _parseTime(dateLink.text)!,
				spanFormat: PostSpanFormat.jForum,
				attachments_: const []
			);
		});
		return pagesBefore.followedBy(realPosts).followedBy(pagesAfter).toList();
	}

  @override
  Future<Thread> getThreadImpl(ThreadIdentifier thread, {ThreadVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) async {
    final response = await client.getThreadUri(Uri.https(baseUrl, '$basePath/posts/list/${thread.id}.page'), priority: priority, responseType: ResponseType.plain, cancelToken: cancelToken);
		final document = parse(response.data);
		final lastPageNumber = document.querySelector('.pagination')?.querySelectorAll('a').tryMap((a) => a.text.tryParseInt).last;
		final posts = _getPostsFromThreadPage(thread.id, document);
		return Thread(
			replyCount: switch (lastPageNumber) {
				int page => page * postsPerPage, // Estimate
				null => posts.length - 1, // By convention we don't count OP as a reply
			},
			imageCount: 0,
			// Interestingly, posts.first.id is not the same as threadId. Hope that doesn't break anything....
			id: thread.id,
			// thread.board might be arbitrary
			board: posts.first.board,
			title: document.querySelector('.category-heading-topic')!.text.trim().nonEmptyOrNull,
			isSticky: false,
			time: posts.first.time,
			attachments: [],
			posts_: posts
		);
  }

	@override
	Future<List<Post>> getStubPosts(ThreadIdentifier thread, List<ParentAndChildIdentifier> postIds, {required RequestPriority priority, CancelToken? cancelToken}) async {
		// Just do one at a time
		final postId = postIds.first;
		if (postId.childId.isNegative) {
			// Request for page
			final pageNumber = -postId.childId;
			final response = await client.getUri(
				Uri.https(baseUrl, '$basePath/posts/list/${postsPerPage * (pageNumber - 1)}/${thread.id}.page'),
				options: Options(
					responseType: ResponseType.plain,
					extra: {
						kPriority: priority
					}
				),
				cancelToken: cancelToken
			);
			final document = parse(response.data);
			return _getPostsFromThreadPage(thread.id, document);
		}
		// Request for post
		final response = await client.get(
			getWebUrlImpl(thread.board, thread.id, postId.childId),
			options: Options(
				responseType: ResponseType.plain,
				extra: {
					kPriority: priority
				}
			),
			cancelToken: cancelToken
		);
		final document = parse(response.data);
		return _getPostsFromThreadPage(thread.id, document);
	}

	@override
	String getWebUrlImpl(String board, [int? threadId, int? postId]) {
		final boardCode = board.beforeFirst('.');
		if (threadId == null) {
			return 'https://$baseUrl$basePath/forums/show/$boardCode.page';
		}
		if (postId == null) {
			return 'https://$baseUrl$basePath/posts/list/$threadId.page';
		}
		if (postId.isNegative) {
			return 'https://$baseUrl$basePath/posts/list/${postsPerPage * ((-postId) - 1)}/$threadId.page';
		}
		return 'https://$baseUrl$basePath/posts/preList/$threadId/$postId.page';
	}


	@override
	ImageboardSearchMetadata supportsSearch(String? board) {
		return ImageboardSearchMetadata(
			options: const ImageboardSearchOptions(text: true),
			name: name
		);
	}
	@override
	Future<ImageboardArchiveSearchResultPage> search(ImageboardArchiveSearchQuery query, {required int page, ImageboardArchiveSearchResultPage? lastResult, required RequestPriority priority, CancelToken? cancelToken}) async {
		final response = await client.getUri(Uri.https(baseUrl, '$basePath/jforum.page', {
			'module': 'search',
			'action': 'search',
			'search_keywords': query.query,
			'match_type': 'all',
			'search_forum': switch (query.boards) {
				[String board] => board.beforeFirst('.'),
				_ => ''
			},
			'sort_by': 'relevance',
			if (page != 1) 'start': ((page - 1) * searchResultsPerPage).toString()
		}), options: Options(
			extra: {
				kPriority: priority
			},
			responseType: ResponseType.plain
		), cancelToken: cancelToken);
		final document = parse(response.data);
		final postrows = document.querySelector('.postinfo')!.parent!.parent!.children;
		for (int i = 0; i < postrows.length; i += 3) {

		}
		return ImageboardArchiveSearchResultPage(
			replyCountsUnreliable: true,
			imageCountsUnreliable: true,
			page: page,
			count: document.querySelectorAll('.maintitle').tryMapOnce((e) {
				final text = e.text;
				if (!text.contains('Search Results:')) {
					return null;
				}
				return RegExp(r'(\d+)').firstMatch(text)?.group(1)?.tryParseInt;
			}),
			canJumpToArbitraryPage: true,
			maxPage: document.querySelector('.pagination')?.querySelectorAll('a').tryMap((a) => a.text.tryParseInt).last ?? 1,
			posts: List.generate(postrows.length ~/ 3, (i) {
				final postinfoRow = postrows[i * 3];
				final postContent = postrows[(i * 3) + 1].querySelector('td')!;
				String? board;
				int? id;
				int? threadId;
				String? name;
				for (final a in postinfoRow.querySelectorAll('a')) {
					final href = a.attributes['href'];
					if (href == null) {
						continue;
					}
					if (href.startsWith('$basePath/forums/show/')) {
						board = '${href.afterLast('/').beforeFirst('.')}.${a.text}';
					}
					if (href.startsWith('$basePath/posts/preList/')) {
						final parts = href.split('/');
						threadId = int.parse(parts[parts.length - 2]);
						id = int.parse(parts.last.beforeFirst('.'));
					}
					if (href.startsWith('$basePath/user/profile/')) {
						name = a.text;
					}
				}
				return ImageboardArchiveSearchResult.post(Post(
					board: board!,
					id: id!,
					threadId: threadId!,
					name: name!,
					text: postContent.innerHtml,
					time: _parseTime(postinfoRow.text)!,
					spanFormat: PostSpanFormat.jForum,
					attachments_: const []
				));
			}),
			archive: this
		);
	}

	@override
	String formatBoardName(String name) => name.afterLast('.');
	@override
	String formatBoardNameWithoutTrailingSlash(String name) => name.afterLast('.');

	@override
	bool get showImageCount => false;

	@override
	bool get classicCatalogStyle => false;

	@override
	bool get hasPagedCatalog => true;

	@override
	bool get hasExpiringThreads => false;

	@override
	bool get hasSharedIdSpace => true;

	@override
	bool get hasWeakQuoteLinks => true;

	@override
	bool get hasSecondsPrecision => false;

	@override
	bool get supportsPosting => false;

	@override
	String get siteType => 'jforum';
	@override
	String get siteData => '$baseUrl,$basePath';

	@override
	Future<PostReceipt> submitPost(DraftPost post, CaptchaSolution captchaSolution, CancelToken cancelToken) async {
		if (post.file != null) {
			throw Exception('Media posting not supported on JForum');
		}
		// TODO: implement submitPost
		// This is actually doable, they have anonymous posting
		throw UnimplementedError();
	}

	@override
	bool operator == (Object other) =>
		identical(other, this) ||
		other is SiteJForum &&
		other.name == name &&
		other.baseUrl == baseUrl &&
		other.basePath == basePath &&
		other.defaultUsername == defaultUsername &&
		other.faviconPath == faviconPath &&
		other.threadsPerPage == threadsPerPage &&
		other.postsPerPage == postsPerPage &&
		super==(other);
	@override
	int get hashCode => baseUrl.hashCode;
}

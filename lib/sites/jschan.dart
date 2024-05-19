import 'package:chan/models/attachment.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/sites/4chan.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/lainchan.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart';

class SiteJsChan extends ImageboardSite {
	@override
	final String baseUrl;
	@override
	final String name;
	@override
	final String defaultUsername;
	final String faviconPath;

	SiteJsChan({
		required this.baseUrl,
		required this.name,
		this.defaultUsername = 'Anonymous',
		required this.faviconPath
	});

	static final _quoteLinkHrefPattern = RegExp(r'/([^/]+)/thread/(\d+)\.html(?:#(\d+))?$');

	static PostNodeSpan makeSpan(String board, int threadId, String text) {
		final body = parseFragment(text);
		int spoilerSpanId = 0;
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
						if (addedLinebreakBefore) {
							yield const PostLineBreakSpan();
						}
						yield* visit(node.nodes);
						addLinebreakBefore = true;
					}
					else if (node.localName == 'br') {
						addLinebreakBefore = true;
					}
					else if (node.localName == 'a' && node.classes.contains('quote')) {
						final match = _quoteLinkHrefPattern.firstMatch(node.attributes['href'] ?? '');
						if (match != null) {
							final threadId = int.parse(match.group(2)!);
							yield PostQuoteLinkSpan(
								board: match.group(1)!,
								threadId: threadId,
								postId: int.tryParse(match.group(3) ?? '') ?? threadId
							);
						}
						else {
							// Something went wrong
							yield PostTextSpan(node.outerHtml);
						}
					}
					else if (node.localName == 'a') {
						yield PostLinkSpan(node.attributes['href']!, name: node.text);
					}
					else if (node.localName == 'small' && node.text == '(OP)') {
						// Do nothing, Chance handles adding "(OP)"
					}
					else if (node.localName == 'span' && node.classes.contains('greentext')) {
						yield PostQuoteSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)));
					}
					else if (node.localName == 'span' && node.classes.contains('pinktext')) {
						yield PostPinkQuoteSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)));
					}
					else if (node.localName == 'span' && node.classes.contains('detected')) {
						yield PostSpoilerSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)), spoilerSpanId++, forceReveal: true);
					}
					else if (node.localName == 'span' && node.classes.contains('strike')) {
						yield PostStrikethroughSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)));
					}
					else if (node.localName == 'span' && node.classes.contains('bold')) {
						yield PostBoldSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)));
					}
					else if (node.localName == 'span' && node.classes.contains('em')) {
						yield PostItalicSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)));
					}
					else if (node.localName == 'span' && node.classes.contains('underline')) {
						yield PostUnderlinedSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)));
					}
					else if (node.localName == 'span' && node.classes.contains('spoiler')) {
						yield PostSpoilerSpan(PostNodeSpan(visit(node.nodes).toList(growable: false)), spoilerSpanId++);
					}
					else if (node.localName == 'span' && node.classes.contains('mono')) {
						yield PostCodeSpan(node.text);
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
								yield PostNodeSpan(visit(li.nodes).toList(growable: false));
								addLinebreakBefore = true;
								i++;
							}
						}
					}
					else {
						yield* Site4Chan.parsePlaintext(node.outerHtml);
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
	Future<BoardThreadOrPostIdentifier?> decodeUrl(String url) async {
		return SiteLainchan.decodeGenericUrl(baseUrl, 'thread', url);
	}

	@override
	Future<void> deletePost(String board, int threadId, PostReceipt receipt) {
		// TODO: implement deletePost
		throw UnimplementedError();
	}

	@override
	Future<List<ImageboardBoard>> getBoards({required RequestPriority priority}) async {
		final list = <ImageboardBoard>[];
		int page = 1;
		int maxPage = 1;
		while (page <= maxPage) {
			final response = await client.getUri(Uri.https(baseUrl, '/boards.json', {'page': page.toString()}), options: Options(
				responseType: ResponseType.json,
				extra: {
					kPriority: priority
				}
			));
			page++;
			maxPage = response.data['maxPage'];
			list.addAll((response.data['boards'] as List).where((board) => board['webring'] != true).map((board) => ImageboardBoard(
				name: board['_id'],
				title: board['settings']['name'],
				isWorksafe: board['settings']['sfw'],
				webmAudioAllowed: true,
				maxImageSizeBytes: 16000000,
				maxWebmSizeBytes: 16000000
			)));
		}
		return list;
	}

	@override
	Future<CaptchaRequest> getCaptchaRequest(String board, [int? threadId]) async {
		// TODO: implement getCaptchaRequest
		throw UnimplementedError();
	}

	Post _makePost(Map post) {
		final threadId = post['thread'] ?? post['postId'] /* op */;
		return Post(
			id: post['postId'],
			threadId: threadId,
			board: post['board'],
			text: post['message'] ?? '',
			name: post['name'],
			time: DateTime.fromMillisecondsSinceEpoch(post['u']),
			spanFormat: PostSpanFormat.jsChan,
			attachments_: (post['files'] as List).cast<Map>().map((file) {
				final sizeParts = (file['geometryString'] as String?)?.split('x');
				final width = int.tryParse(sizeParts?[0] ?? '');
				final height = int.tryParse(sizeParts?[1] ?? '');
				return Attachment(
					type: switch (file['extension']) {
						'.webm' => AttachmentType.webm,
						'.mp4' => AttachmentType.mp4,
						'.mp3' => AttachmentType.mp3,
						_ => AttachmentType.image
					},
					md5: file['hash'],
					ext: file['extension'],
					board: post['board'],
					id: file['filename'],
					filename: file['originalFilename'],
					url: Uri.https(baseUrl, '/file/${file['hash']}${file['extension']}').toString(),
					thumbnailUrl: Uri.https(baseUrl, '/file/thumb/${file['hash']}${file['thumbextension']}').toString(),
					width: width,
					height: height,
					threadId: threadId,
					sizeInBytes: file['size']
				);
			}).toList()
		);
	}

	Thread _makeThread(Map thread) {
		final op = _makePost(thread);
		return Thread(
			board: op.board,
			id: op.threadId,
			replyCount: thread['replyposts'],
			imageCount: thread['replyfiles'],
			title: thread['subject'],
			isSticky: thread['sticky'] != 0,
			time: op.time,
			attachments: op.attachments_,
			posts_: [
				op,
				...(thread['replies'] as List? ?? []).cast<Map>().map(_makePost)
			]
		);
	}

	@override
	Future<List<Thread>> getCatalogImpl(String board, {CatalogVariant? variant, required RequestPriority priority}) async {
		final response = await client.getUri(Uri.https(baseUrl, '/$board/catalog.json'), options: Options(
			extra: {
				kPriority: priority
			}
		));
		return (response.data as List).cast<Map>().map(_makeThread).toList();
	}

	@override
	Future<Post> getPost(String board, int id, {required RequestPriority priority}) async {
		throw UnimplementedError();
	}

	@override
	Future<Thread> getThreadImpl(ThreadIdentifier thread, {ThreadVariant? variant, required RequestPriority priority}) async {
		final response = await client.getUri(Uri.https(baseUrl, '/${thread.board}/thread/${thread.id}.json'), options: Options(
			extra: {
				kPriority: priority
			}
		));
		return _makeThread(response.data);
	}

	@override
	String getWebUrlImpl(String board, [int? threadId, int? postId]) {
		if (postId != null) {
			return 'https://$baseUrl/$board/thread/$threadId.html#$postId';
		}
		if (threadId != null) {
			return 'https://$baseUrl/$board/thread/$threadId.html';
		}
		return 'https://$baseUrl/$board/';
	}

	@override
	Uri get iconUrl => Uri.https(baseUrl, faviconPath);

	@override
	String get siteData => baseUrl;

	@override
	String get siteType => 'jschan';

	@override
	bool get supportsPosting => false;

	@override
	Future<PostReceipt> submitPost(DraftPost post, CaptchaSolution captchaSolution, CancelToken cancelToken) {
		// TODO: implement submitPost
		throw UnimplementedError();
	}
}
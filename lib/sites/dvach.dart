import 'package:chan/models/attachment.dart';

import 'package:chan/models/board.dart';
import 'package:chan/models/flag.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/models/post.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/lainchan.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart';
import 'package:html/dom.dart' as dom;

class DvachException implements Exception {
	final int code;
	final String message;
	DvachException(this.code, this.message);
	@override
	String toString() => 'Dvach error ($code): $message';
}

class SiteDvach extends ImageboardSite {
	@override
	final String baseUrl;
	@override
	final String name;

	SiteDvach({
		required this.baseUrl,
		required this.name,
		super.platformUserAgents,
		super.archives
	});

	@override
	Future<List<ImageboardBoard>> getBoards({required RequestPriority priority}) async {
		final response = await client.getUri(Uri.https(baseUrl, '/index.json'), options: Options(
			responseType: ResponseType.json,
			extra: {
				kPriority: priority
			}
		));
		return (response.data['boards'] as List).map((board) => ImageboardBoard(
			name: board['id'],
			title: board['name'],
			isWorksafe: board['category'] != 'Взрослым',
			webmAudioAllowed: true,
			threadCommentLimit: board['bump_limit'],
			maxCommentCharacters: board['max_comment'],
			maxImageSizeBytes: board['max_files_size'],
			maxWebmSizeBytes: board['max_files_size'],
			pageCount: board['max_pages']
		)).toList();
	}


	@override
	Future<Post> getPost(String board, int id, {required RequestPriority priority}) {
		throw UnimplementedError();
	}

	List<Attachment> _makeAttachments(String board, int threadId, Map<String, dynamic> data) {
		return ((data['files'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? []).map((file) {
			final url = Uri.https(baseUrl, file['path']);
			AttachmentType type = AttachmentType.image;
			if (url.path.endsWith('.webm')) {
				type = AttachmentType.webm;
			}
			else if (url.path.endsWith('.mp4')) {
				type = AttachmentType.mp4;
			}
			else if (url.path.endsWith('.mp3')) {
				type = AttachmentType.mp3;
			}
			return Attachment(
				type: type,
				board: board,
				threadId: threadId,
				id: url.pathSegments.last.split('.').first,
				ext: '.${url.pathSegments.last.split('.').last}',
				filename: file['fullname'],
				url: url.toString(),
				thumbnailUrl: Uri.https(baseUrl, file['thumbnail']).toString(),
				md5: file['md5'],
				width: file['width'],
				height: file['height'],
				sizeInBytes: file['size'] * 1024
			);
		}).toList();
	}

	static final _iconFlagPattern = RegExp(r'<img.*src="(.*\/([^.]+)\.[^."]+)"');

	Post _makePost(String board, int threadId, Map<String, dynamic> data) {
		String? posterId = data['op'] == 1 ? 'OP' : null;
		final name = StringBuffer();
		final nameDoc = parseFragment(data['name'] ?? '');
		for (final node in nameDoc.nodes) {
			if (node is dom.Element && node.localName == 'span' && node.id.startsWith('id_tag_')) {
				posterId = node.text;
			}
			else {
				name.write(node.text);
			}
		}
		return Post(
			board: board,
			threadId: threadId,
			id: data['num'],
			text: data['comment'],
			name: name.toString().trim(),
			posterId: posterId,
			time: DateTime.fromMillisecondsSinceEpoch(data['timestamp'] * 1000),
			spanFormat: PostSpanFormat.lainchan,
			attachments_: _makeAttachments(board, threadId, data),
			flag: switch (_iconFlagPattern.firstMatch(data['icon'] ?? '')) {
				null => null,
				RegExpMatch flagMatch => ImageboardFlag(
					imageHeight: 12,
					imageWidth: 18,
					name: flagMatch.group(2) ?? 'Unknown',
					imageUrl: 'https://$baseUrl${flagMatch.group(1)}'
				)
			}
		);
	}

	@override
	Future<List<Thread>> getCatalogImpl(String board, {CatalogVariant? variant, required RequestPriority priority}) async {
		final response = await client.getUri(Uri.https(baseUrl, '/$board/catalog.json'), options: Options(
			validateStatus: (s) => true,
			extra: {
				kPriority: priority
			}
		));
		if (response.statusCode == 404) {
			throw BoardNotFoundException(board);
		}
		else if (response.statusCode != 200) {
			throw HTTPStatusException(response.statusCode!);
		}
		final int? threadsPerPage = response.data['board']['threads_per_page'];
		return (response.data['threads'] as List<dynamic>).cast<Map<String, dynamic>>().asMap().entries.map((e) {
			final op = _makePost(board, e.value['num'], e.value);
			return Thread(
				posts_: [op],
				id: op.id,
				board: board,
				title: e.value['subject'],
				isSticky: e.value['sticky'] != 0,
				time: op.time,
				attachments: op.attachments_,
				currentPage: threadsPerPage == null ? null : ((e.key ~/ threadsPerPage) + 1),
				replyCount: e.value['posts_count'] - 1,
				imageCount: e.value['files_count'] - op.attachments.length,
			);
		}).toList();
	}

	@override
	Future<Thread> getThreadImpl(ThreadIdentifier thread, {ThreadVariant? variant, required RequestPriority priority}) async {
		final response = await client.getUri(Uri.https(baseUrl, '/${thread.board}/res/${thread.id}.json'), options: Options(
			extra: {
				kPriority: priority
			}
		));
		final posts = (response.data['threads'].first['posts'] as List<dynamic>).map((data) => _makePost(thread.board, thread.id, data)).toList();
		return Thread(
			board: thread.board,
			id: thread.id,
			title: response.data['threads'].first['posts'].first['subject'],
			isSticky: response.data['threads'].first['posts'].first['sticky'] != 0,
			time: posts.first.time,
			attachments: posts.first.attachments_,
			posts_: posts,
			replyCount: response.data['posts_count'] - 1,
			imageCount: response.data['files_count'] - posts.first.attachments.length
		);
	}

	@override
	Future<CaptchaRequest> getCaptchaRequest(String board, [int? threadId]) async {
		final response = await client.getUri(Uri.https(baseUrl, '/api/captcha/settings/$board'), options: Options(
			responseType: ResponseType.json
		));
		if (response.data['result'] == 0) {
			throw DvachException(response.data['error']['code'], response.data['error']['message']);
		}
		if (response.data['enabled'] == 0) {
			return const NoCaptchaRequest();
		}
		for (final type in response.data['types']) {
			if (type['id'] == '2chcaptcha') {
				return DvachCaptchaRequest(challengeLifetime: Duration(seconds: type['expires']));
			}
		}
		throw DvachException(0, 'No supported captcha (unsupported: ${response.data['types'].map((t) => t['id']).toList()})');
	}

	@override
	Future<PostReceipt> submitPost(DraftPost post, CaptchaSolution captchaSolution, CancelToken cancelToken) async {
		final file = post.file;
		final Map<String, dynamic> fields = {
			'task': 'post',
			'board': post.board,
			'name': post.name ?? '',
			'email': post.options ?? '',
			if (captchaSolution is DvachCaptchaSolution) ...{
				'captcha_type': '2chcaptcha',
				'2chcaptcha_id': captchaSolution.id,
				'2chcaptcha_value': captchaSolution.response
			},
			'comment': post.text,
			if (file != null) 'formimages[]': await MultipartFile.fromFile(file, filename: post.overrideFilename),
			if (post.threadId != null) 'thread': post.threadId.toString()
		};
		final response = await client.postUri(
			Uri.https(baseUrl, '/user/posting'),
			data: FormData.fromMap(fields),
			options: Options(
				responseType: ResponseType.json,
				validateStatus: (x) => true,
				headers: {
					'Referer': getWebUrlImpl(post.board, post.threadId)
				}
			),
			cancelToken: cancelToken
		);
		print(response.statusCode);
		if (response.data['error'] != null) {
			throw DvachException(response.data['error']['code'], response.data['error']['message']);
		}
		return PostReceipt(
			post: post,
			password: '',
			id: response.data['num'],
			name: post.name ?? '',
			options: post.options ?? '',
			time: DateTime.now(),
			ip: captchaSolution.ip
		);
	}

	@override
	Future<void> deletePost(ThreadIdentifier thread, PostReceipt receipt, CaptchaSolution captchaSolution) async {
		throw UnimplementedError();
	}

	@override
	String getWebUrlImpl(String board, [int? threadId, int? postId]) {
		String threadUrl = Uri.https(baseUrl, '/$board/').toString();
		if (threadId != null) {
			threadUrl += 'res/$threadId.html';
			if (postId != null) {
				threadUrl += '#q$postId';
			}
		}
		return threadUrl;
	}

	@override
	Future<BoardThreadOrPostIdentifier?> decodeUrl(String url) async => SiteLainchan.decodeGenericUrl(baseUrl, 'res', url);

	@override
	Iterable<ImageboardSnippet> getBoardSnippets(String board) => const [
		greentextSnippet
	];

	@override
	String get siteType => 'dvach';
	@override
	String get siteData => baseUrl;
	@override
	Uri get iconUrl => Uri.https(baseUrl, '/favicon.ico');
	@override
	String get defaultUsername => 'Аноним';

	@override
	bool operator ==(Object other) =>
		identical(this, other) ||
		(other is SiteDvach) &&
		(other.name == name) &&
		(other.baseUrl == baseUrl) &&
		mapEquals(other.platformUserAgents, platformUserAgents) &&
		listEquals(other.archives, archives);

	@override
	int get hashCode => Object.hash(name, baseUrl, platformUserAgents, archives);
}
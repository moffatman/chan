import 'package:chan/models/attachment.dart';
import 'dart:io';

import 'package:chan/models/board.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/models/post.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/lainchan.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart';

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
		List<ImageboardSiteArchive> archives = const []
	}) : super(archives);

	@override
	Future<List<ImageboardBoard>> getBoards() async {
		final response = await client.get(Uri.https(baseUrl, '/').toString(), options: Options(
			responseType: ResponseType.plain
		));
		final document = parse(response.data);
		final boards = <ImageboardBoard>[];
		bool nsfw = false;
		for (final element in document.querySelectorAll('.boards li')) {
			if (element.classes.isEmpty) {
				final link = element.querySelector('a');
				final href = link?.attributes['href'];
				if (href != null && href.startsWith('/') && href.endsWith('/')) {
					boards.add(ImageboardBoard(
						name: href.substring(1, href.length - 1),
						title: link!.text,
						isWorksafe: !nsfw,
						webmAudioAllowed: true
					));
				}
			}
			else if (element.classes.contains('boards__title')) {
				nsfw = element.text.contains('18+');
			}
		}
		return boards;
	}


	@override
	Future<Post> getPost(String board, int id) {
		throw UnimplementedError();
	}

	void _updateBoardInformation(Map<String, dynamic> data) async {
		try {
			final board = persistence.boards[data['id']]!;
			board.threadCommentLimit = data['bump_limit'];
			board.maxCommentCharacters = data['max_comment'];
			board.maxImageSizeBytes = data['max_files_size'];
			board.maxWebmSizeBytes = data['max_files_size'];
			board.pageCount = data['max_pages'];
			board.additionalDataTime = DateTime.now();
		}
		catch (e, st) {
			print(e);
			print(st);
		}
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
				url: url,
				thumbnailUrl: Uri.https(baseUrl, file['thumbnail']),
				md5: file['md5'],
				width: file['width'],
				height: file['height'],
				sizeInBytes: file['size'] * 1024
			);
		}).toList();
	}

	Post _makePost(String board, int threadId, Map<String, dynamic> data) {
		return Post(
			board: board,
			threadId: threadId,
			id: data['num'],
			text: data['comment'],
			name: data['name'],
			time: DateTime.fromMillisecondsSinceEpoch(data['timestamp'] * 1000),
			spanFormat: PostSpanFormat.lainchan,
			attachments: _makeAttachments(board, threadId, data)
		);
	}

	@override
	Future<List<Thread>> getCatalogImpl(String board, {CatalogVariant? variant}) async {
		final response = await client.get(Uri.https(baseUrl, '/$board/catalog.json').toString(), options: Options(
			validateStatus: (s) => true
		));
		if (response.statusCode == 404) {
			throw BoardNotFoundException(board);
		}
		else if (response.statusCode != 200) {
			throw HTTPStatusException(response.statusCode!);
		}
		if (response.data['board'] != null) {
			_updateBoardInformation(response.data['board']);
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
				attachments: op.attachments,
				currentPage: threadsPerPage == null ? null : ((e.key ~/ threadsPerPage) + 1),
				replyCount: e.value['posts_count'] - 1,
				imageCount: e.value['files_count'] - op.attachments.length,
			);
		}).toList();
	}

	@override
	Future<Thread> getThread(ThreadIdentifier thread, {ThreadVariant? variant}) async {
		final response = await client.get(Uri.https(baseUrl, '/${thread.board}/res/${thread.id}.json').toString());
		if (response.data['board'] != null) {
			_updateBoardInformation(response.data['board']);
		}
		final posts = (response.data['threads'].first['posts'] as List<dynamic>).map((data) => _makePost(thread.board, thread.id, data)).toList();
		return Thread(
			board: thread.board,
			id: thread.id,
			title: response.data['threads'].first['posts'].first['subject'],
			isSticky: response.data['threads'].first['posts'].first['sticky'] != 0,
			time: posts.first.time,
			attachments: posts.first.attachments,
			posts_: posts,
			replyCount: response.data['posts_count'] - 1,
			imageCount: response.data['files_count'] - posts.first.attachments.length
		);
	}

	@override
	Future<CaptchaRequest> getCaptchaRequest(String board, [int? threadId]) async {
		final response = await client.get(Uri.https(baseUrl, '/api/captcha/settings/$board').toString(), options: Options(
			responseType: ResponseType.json
		));
		if (response.data['result'] == 0) {
			throw DvachException(response.data['error']['code'], response.data['error']['message']);
		}
		if (response.data['enabled'] == 0) {
			return NoCaptchaRequest();
		}
		for (final type in response.data['types']) {
			if (type['id'] == '2chcaptcha') {
				return DvachCaptchaRequest(challengeLifetime: Duration(seconds: type['expires']));
			}
		}
		throw DvachException(0, 'No supported captcha (unsupported: ${response.data['types'].map((t) => t['id']).toList()})');
	}

	Future<PostReceipt> _post({
		required String board,
		int? threadId,
		String name = '',
		String? subject,
		String options = '',
		required String text,
		required CaptchaSolution captchaSolution,
		File? file,
		bool? spoiler,
		String? overrideFilename,
		ImageboardBoardFlag? flag
	}) async {
		final Map<String, dynamic> fields = {
			'task': 'post',
			'board': board,
			'name': name,
			'email': options,
			if (captchaSolution is DvachCaptchaSolution) ...{
				'captcha_type': '2chcaptcha',
				'2chcaptcha_id': captchaSolution.id,
				'2chcaptcha_value': captchaSolution.response
			},
			'comment': text,
			if (file != null) 'formimages[]': await MultipartFile.fromFile(file.path, filename: overrideFilename),
			if (threadId != null) 'thread': threadId.toString()
		};
		final response = await client.post(
			Uri.https(baseUrl, '/user/posting').toString(),
			data: FormData.fromMap(fields),
			options: Options(
				responseType: ResponseType.json,
				validateStatus: (x) => true,
				headers: {
					'Referer': getWebUrl(board, threadId)
				}
			)
		);
		print(response.statusCode);
		if (response.data['error'] != null) {
			throw DvachException(response.data['error']['code'], response.data['error']['message']);
		}
		return PostReceipt(
			password: '',
			id: response.data['num']
		);
	}

	@override
	Future<PostReceipt> createThread({
		required String board,
		String name = '',
		String options = '',
		String subject = '',
		required String text,
		required CaptchaSolution captchaSolution,
		File? file,
		bool? spoiler,
		String? overrideFilename,
		ImageboardBoardFlag? flag
	}) => _post(
		board: board,
		name: name,
		options: options,
		subject: subject,
		text: text,
		captchaSolution: captchaSolution,
		file: file,
		spoiler: spoiler,
		overrideFilename: overrideFilename,
		flag: flag
	);

	@override
	Future<PostReceipt> postReply({
		required ThreadIdentifier thread,
		String name = '',
		String options = '',
		required String text,
		required CaptchaSolution captchaSolution,
		File? file,
		bool? spoiler,
		String? overrideFilename,
		ImageboardBoardFlag? flag
	}) => _post(
		board: thread.board,
		threadId: thread.id,
		name: name,
		options: options,
		text: text,
		captchaSolution: captchaSolution,
		file: file,
		spoiler: spoiler,
		overrideFilename: overrideFilename,
		flag: flag
	);

	@override
	Future<void> deletePost(String board, PostReceipt receipt) async {
		throw UnimplementedError();
	}

	@override
	DateTime? getActionAllowedTime(String board, ImageboardAction action) {
		return null;
	}

	@override
	String getWebUrl(String board, [int? threadId, int? postId]) {
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
	Future<BoardThreadOrPostIdentifier?> decodeUrl(String url) async => SiteLainchan.decodeGenericUrl(baseUrl, url);

	@override
	Uri getPostReportUrl(String board, int id) {
		throw UnimplementedError();
	}

	@override
	Uri getSpoilerImageUrl(Attachment attachment, {ThreadIdentifier? thread}) {
		throw UnimplementedError();
	}

	@override
	List<ImageboardSiteLoginField> getLoginFields() {
		return [];
	}

	@override
	String? getLoginSystemName() {
		return null;
	}

	@override
	Future<void> login(Map<ImageboardSiteLoginField, String> fields) {
		throw UnimplementedError();
	}

	@override
	Future<void> clearLoginCookies(bool fromBothWifiAndCellular) async {

	}

	@override
	String get siteType => 'dvach';
	@override
	String get siteData => baseUrl;
	@override
	Uri get iconUrl => Uri.https(baseUrl, '/favicon.ico');
	@override
	String get imageUrl => baseUrl;
	@override
	String get defaultUsername => 'Аноним';

	@override
	bool operator ==(Object other) => (other is SiteDvach) && (other.name == name) && (other.baseUrl == baseUrl) && listEquals(other.archives, archives);

	@override
	int get hashCode => Object.hash(name, baseUrl, archives);
}
import 'dart:io';

import 'package:chan/models/attachment.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/search.dart';
import 'package:chan/services/cloudflare.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/sites/4chan.dart';
import 'package:chan/sites/foolfuuka.dart';
import 'package:chan/sites/fuuka.dart';
import 'package:chan/sites/lainchan.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/widgets.dart';

import '../models/thread.dart';

import 'package:dio/dio.dart';
const userAgent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) AppleWebKit/605.1.15 (KHTML, like Gecko)';

class PostNotFoundException implements Exception {
	String board;
	int id;
	PostNotFoundException(this.board, this.id);
	@override
	String toString() => 'Post not found: /$board/$id';
}

class ThreadNotFoundException implements Exception {
	ThreadIdentifier thread;
	ThreadNotFoundException(this.thread);
	@override
	String toString() => 'Thread not found: /${thread.board}/${thread.id}';
}

class BoardNotFoundException implements Exception {
	String board;
	BoardNotFoundException(this.board);
	@override
	String toString() => 'Board not found: /$board/';
}

class HTTPStatusException implements Exception {
	int code;
	HTTPStatusException(this.code);
	@override
	String toString() => 'HTTP Error $code';
}

class PostFailedException implements Exception {
	String reason;
	PostFailedException(this.reason);
	@override
	String toString() => 'Posting failed: $reason';
}

class ImageboardArchiveException implements Exception {
	Map<String, String> archiveErrors;
	ImageboardArchiveException(this.archiveErrors);
	@override
	String toString() => archiveErrors.entries.map((e) => '${e.key}: ${e.value}').join(', ');
}

enum ImageboardAction {
	postThread,
	postReply,
	postReplyWithImage
}

class CaptchaRequest {

}

class NoCaptchaRequest extends CaptchaRequest {
  
}

class RecaptchaRequest extends CaptchaRequest {
	final String key;
	final String sourceUrl;
	RecaptchaRequest({
		required this.key,
		required this.sourceUrl
	});
	@override
	String toString() => 'RecaptchaRequest(sourceUrl: $sourceUrl, key: $key)';
}

class Chan4CustomCaptchaRequest extends CaptchaRequest {
	final Uri challengeUrl;
	Chan4CustomCaptchaRequest({
		required this.challengeUrl
	});
	@override
	String toString() => 'Chan4CustomCaptchaRequest(challengeUrl: $challengeUrl)';
}

class CaptchaSolution {

}

class NoCaptchaSolution extends CaptchaSolution {
  
}

class RecaptchaSolution extends CaptchaSolution {
	final String response;
	RecaptchaSolution({
		required this.response
	});
	@override
	String toString() => 'RecaptchaSolution(response: $response)';
}

class Chan4CustomCaptchaSolution extends CaptchaSolution {
	final String challenge;
	final String response;
	Chan4CustomCaptchaSolution({
		required this.challenge,
		required this.response
	});
	@override
	String toString() => 'Chan4CustomCaptchaSolution(challenge: $challenge, response: $response)';
}

class ImageboardArchiveSearchResult {
	final List<Post> posts;
	final int page;
	final int maxPage;
	final ImageboardSiteArchive archive;
	ImageboardArchiveSearchResult({
		required this.posts,
		required this.page,
		required this.maxPage,
		required this.archive
	});
}

abstract class ImageboardSiteArchive {
	final Dio client = Dio(BaseOptions(
		receiveTimeout: 5000,
		connectTimeout: 5000
	));
	BuildContext? _context;
	BuildContext get context => _context!;
	set context(BuildContext value) {
		_context = value;
	}
	ImageboardSiteArchive() {
		client.interceptors.add(CookieManager(Persistence.cookies));
		client.interceptors.add(InterceptorsWrapper(
			onRequest: (options, handler) {
				options.headers['user-agent'] = userAgent;
				handler.next(options);
			}
		));
		client.interceptors.add(CloudflareInterceptor(this));
	}
	String get name;
	Future<Post> getPost(String board, int id);
	Future<Thread> getThread(ThreadIdentifier thread);
	Future<List<Thread>> getCatalog(String board);
	Future<List<ImageboardBoard>> getBoards();
	Future<ImageboardArchiveSearchResult> search(ImageboardArchiveSearchQuery query, {required int page});
	String getWebUrl(String board, [int? threadId, int? postId]);
}

abstract class ImageboardSite extends ImageboardSiteArchive {
	final List<ImageboardSiteArchive> archives;
	ImageboardSite(this.archives);
	@override
	set context(BuildContext value) {
		super.context = value;
		for (final archive in archives) {
			archive.context = value;
		}
	}
	String get imageUrl;
	CaptchaRequest getCaptchaRequest(String board, [int? threadId]);
	Future<PostReceipt> createThread({
		required String board,
		String name = '',
		String options = '',
		String subject = '',
		required String text,
		required CaptchaSolution captchaSolution,
		File? file,
		String? overrideFilename
	});
	Future<PostReceipt> postReply({
		required ThreadIdentifier thread,
		String name = '',
		String options = '',
		required String text,
		required CaptchaSolution captchaSolution,
		File? file,
		String? overrideFilename
	});
	DateTime? getActionAllowedTime(String board, ImageboardAction action);
	Future<void> deletePost(String board, PostReceipt receipt);
	Future<Post> getPostFromArchive(String board, int id) async {
		final Map<String, String> errorMessages = {};
		for (final archive in archives) {
			try {
				return await archive.getPost(board, id);
			}
			catch(e) {
				if (e is! BoardNotFoundException) {
					errorMessages[archive.name] = e.toString();
				}
			}
		}
		if (errorMessages.isNotEmpty) {
			throw ImageboardArchiveException(errorMessages);
		}
		else {
			throw BoardNotFoundException(board);
		}
	}
	Future<Thread> getThreadFromArchive(ThreadIdentifier thread) async {
		final Map<String, String> errorMessages = {};
		for (final archive in archives) {
			print('Trying archive.name');
			try {
				return await archive.getThread(thread);
			}
			catch(e, st) {
				if (e is! BoardNotFoundException) {
					print('Error from ${archive.name}');
					print(e);
					print(st);
					errorMessages[archive.name] = e.toString();
				}
			}
		}
		if (errorMessages.isNotEmpty) {
			throw ImageboardArchiveException(errorMessages);
		}
		else {
			throw BoardNotFoundException(thread.board);
		}
	}
	Uri getSpoilerImageUrl(Attachment attachment, {ThreadIdentifier? thread});
	Uri getPostReportUrl(String board, int id);
	Persistence? persistence;
}

ImageboardSite makeSite(BuildContext context, dynamic data) {
		if (data['type'] == 'lainchan') {
			return SiteLainchan(
				name: data['name'],
				baseUrl: data['baseUrl']
			);
		}
		else if (data['type'] == '4chan') {
			return Site4Chan(
				name: data['name'],
				imageUrl: data['imageUrl'],
				captchaKey: data['captchaKey'],
				apiUrl: data['apiUrl'],
				sysUrl: data['sysUrl'],
				baseUrl: data['baseUrl'],
				staticUrl: data['staticUrl'],
				archives: (data['archives'] ?? []).map<ImageboardSiteArchive>((archive) {
					final boards = (archive['boards'] as List<dynamic>?)?.map((b) => ImageboardBoard(
						title: b['title'],
						name: b['name'],
						isWorksafe: b['isWorksafe'],
						webmAudioAllowed: false
					)).toList();
					if (archive['type'] == 'foolfuuka') {
						return FoolFuukaArchive(
							name: archive['name'],
							baseUrl: archive['baseUrl'],
							staticUrl: archive['staticUrl'],
							boards: boards
						);
					}
					else if (archive['type'] == 'fuuka') {
						return FuukaArchive(
							name: archive['name'],
							baseUrl: archive['baseUrl'],
							boards: boards
						);
					}
					else {
						print(archive);
						throw UnsupportedError('Unknown archive type "${archive['type']}"');
					}
				}).toList()
			);
		}
		else {
			print(data);
			throw UnsupportedError('Unknown site type "${data['type']}"');
		}
	}
import 'dart:io';

import 'package:chan/models/attachment.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/search.dart';
import 'package:chan/services/persistence.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import '../models/thread.dart';

import 'package:dio/dio.dart';

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
	PostThread,
	PostReply,
	PostReplyWithImage
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
	ImageboardArchiveSearchResult({
		required this.posts,
		required this.page,
		required this.maxPage
	});
}

abstract class ImageboardSiteArchive {
	final Dio client = Dio();
	ImageboardSiteArchive() {
		client.interceptors.add(CookieManager(Persistence.cookies));
	}
	String get name;
	Future<Post> getPost(String board, int id);
	Future<Thread> getThread(ThreadIdentifier thread);
	Future<List<Thread>> getCatalog(String board);
	Future<List<ImageboardBoard>> getBoards();
	Future<ImageboardArchiveSearchResult> search(ImageboardArchiveSearchQuery query, {required int page});
	String getWebUrl(String board, [int? thread, int? postId]);
}

abstract class ImageboardSite extends ImageboardSiteArchive {
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
	Future<Post> getPostFromArchive(String board, int id);
	Future<Thread> getThreadFromArchive(ThreadIdentifier thread);
	Uri getSpoilerImageUrl(Attachment attachment, {ThreadIdentifier? thread});
	Uri getPostReportUrl(String board, int id);
	Persistence? persistence;
}
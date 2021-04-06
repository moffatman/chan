import 'dart:io';

import 'package:chan/models/board.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/search.dart';
import 'package:chan/services/persistence.dart';

import '../models/thread.dart';

import 'package:http/http.dart' as http;

class PostNotFoundException implements Exception {
	String board;
	int id;
	PostNotFoundException(this.board, this.id);
	@override
	String toString() => 'Post not found: /$board/$id';
}

class ThreadNotFoundException implements Exception {
	String board;
	int id;
	ThreadNotFoundException(this.board, this.id);
	@override
	String toString() => 'Thread not found: /$board/$id';
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

class CaptchaRequest {
	final String key;
	final String sourceUrl;
	CaptchaRequest({
		required this.key,
		required this.sourceUrl
	});
	@override
	String toString() => 'CaptchaRequest(sourceUrl: $sourceUrl, key: $key)';
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
	final http.Client client = http.Client();
	String get name;
	Future<Post> getPost(String board, int id);
	Future<Thread> getThread(String board, int id);
	Future<List<Thread>> getCatalog(String board);
	Future<List<ImageboardBoard>> getBoards();
	Future<ImageboardArchiveSearchResult> search(ImageboardArchiveSearchQuery query, {required int page});
	String getWebUrl(String board, int threadId, [int? postId]);
}

abstract class ImageboardSite extends ImageboardSiteArchive {
	CaptchaRequest getCaptchaRequest();
	Future<PostReceipt> postReply({
		required String board,
		required int threadId,
		String name = '',
		String options = '',
		required String text,
		required String captchaKey,
		File? file
	});
	Future<Post> getPostFromArchive(String board, int id);
	Future<Thread> getThreadFromArchive(String board, int id);
}
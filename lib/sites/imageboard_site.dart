import 'dart:io';

import 'package:chan/models/attachment.dart';
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
	Future<Thread> getThread(ThreadIdentifier thread);
	Future<List<Thread>> getCatalog(String board);
	Future<List<ImageboardBoard>> getBoards();
	Future<ImageboardArchiveSearchResult> search(ImageboardArchiveSearchQuery query, {required int page});
	String getWebUrl(ThreadIdentifier thread, [int? postId]);
}

abstract class ImageboardSite extends ImageboardSiteArchive {
	String get imageUrl;
	CaptchaRequest getCaptchaRequest();
	Future<PostReceipt> postReply({
		required ThreadIdentifier thread,
		String name = '',
		String options = '',
		required String text,
		required String captchaKey,
		File? file,
		String? overrideFilename
	});
	Future<void> deletePost(String board, PostReceipt receipt);
	Future<Post> getPostFromArchive(String board, int id);
	Future<Thread> getThreadFromArchive(ThreadIdentifier thread);
	Uri getSpoilerImageUrl(Attachment attachment, {ThreadIdentifier? thread});
}
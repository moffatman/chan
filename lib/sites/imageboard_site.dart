import 'dart:io';

import '../models/attachment.dart';
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

class ImageboardBoard {
	final String name;
	final String title;
	final bool isWorksafe;
	final bool webmAudioAllowed;
	final int? maxImageSizeBytes;
	final int? maxWebmSizeBytes;
	final int? maxWebmDurationSeconds;
	final int? maxCommentCharacters;

	ImageboardBoard({
		required this.name,
		required this.title,
		required this.isWorksafe,
		required this.webmAudioAllowed,
		this.maxImageSizeBytes,
		this.maxWebmSizeBytes,
		this.maxWebmDurationSeconds,
		this.maxCommentCharacters
	});
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

class PostReceipt {
	final String password;
	final int id;
	PostReceipt({
		required this.password,
		required this.id
	});
	@override
	String toString() => 'PostReceipt(id: $id, password: $password)';
}

abstract class ImageboardSite {
	final http.Client client = http.Client();
	String get name;
	Future<Thread> getThreadContainingPost(String board, int id);
	Future<Thread> getThread(String board, int id);
	Future<List<Thread>> getCatalog(String board);
	Uri getAttachmentUrl(Attachment attachment);
	Uri getAttachmentThumbnailUrl(Attachment attachment);
	List<Uri> getArchiveAttachmentUrls(Attachment attachment);
	Future<List<ImageboardBoard>> getBoards();
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
}
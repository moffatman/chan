import '../models/attachment.dart';
import '../models/thread.dart';

import 'package:http/http.dart' as http;

class PostNotFoundException implements Exception {
	String board;
	int id;
	PostNotFoundException(this.board, this.id);
}

class ThreadNotFoundException implements Exception {
	String board;
	int id;
	ThreadNotFoundException(this.board, this.id);
}

class BoardNotFoundException implements Exception {
	String board;
	BoardNotFoundException(this.board);
}

class HTTPStatusException implements Exception {
	int code;
	HTTPStatusException(this.code);
}

class ImageboardBoard {
	final String name;
	final String title;
	final bool isWorksafe;

	ImageboardBoard({
		required this.name,
		required this.title,
		required this.isWorksafe
	});
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
}
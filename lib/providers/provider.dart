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

abstract class ImageboardProvider {
	final http.Client client = http.Client();
	final String name = 'Unknownchan';
	Future<Thread> getThreadContainingPost(String board, int id);
	Future<Thread> getThread(String board, int id);
	Future<List<Thread>> getCatalog(String board);
	Uri getAttachmentUrl(Attachment attachment);
	Uri getAttachmentThumbnailUrl(Attachment attachment);
}
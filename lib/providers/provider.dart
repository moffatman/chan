import '../models/post.dart';
import '../models/attachment.dart';
import '../models/thread.dart';
import 'package:meta/meta.dart';

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
	final String name = 'Unknownchan';
	Future<Thread> getThreadContainingPost(String board, int id);
	Future<Thread> getThread(String board, int id);
	Future<List<Thread>> getCatalog(String board);
}


class GroupedImageboardProvider implements ImageboardProvider {
	final String name;
	List<ImageboardProvider> providers;
	Future<Thread> getThreadContainingPost(String board, int id) async {
		for (ImageboardProvider provider in providers) {
			try {
				return await provider.getThreadContainingPost(board, id);
			}
			catch (error) {
				
			}
		}
		throw PostNotFoundException(board, id);
	}
	Future<Thread> getThread(String board, int id) async {
		for (ImageboardProvider provider in providers) {
			try {
				return await provider.getThread(board, id);
			}
			catch (error) {
				
			}
		}
		throw ThreadNotFoundException(board, id);
	}
	Future<List<Thread>> getCatalog(String board) async {
		for (ImageboardProvider provider in providers) {
			try {
				return await provider.getCatalog(board);
			}
			catch (error) {
				
			}
		}
		throw BoardNotFoundException(board);
	}
	GroupedImageboardProvider({
		@required this.providers,
		@required this.name
	});
}
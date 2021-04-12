import 'package:chan/models/flag.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:hive/hive.dart';

part 'thread.g.dart';

@HiveType(typeId: 15)
class Thread implements Filterable {
	@HiveField(0)
	final List<Post> posts;
	@HiveField(1)
	final bool isArchived;
	@HiveField(2)
	final bool isDeleted;
	@HiveField(3)
	final int replyCount;
	@HiveField(4)
	final int imageCount;
	@HiveField(5)
	final int id;
	@HiveField(6)
	final String board;
	@HiveField(7)
	final Attachment? attachment;
	@HiveField(8)
	final String? title;
	@HiveField(9)
	final bool isSticky;
	@HiveField(10)
	final DateTime time;
	@HiveField(11)
	final ImageboardFlag? flag;
	Thread({
		required this.posts,
		required this.isArchived,
		required this.isDeleted,
		required this.replyCount,
		required this.imageCount,
		required this.id,
		this.attachment,
		required this.board,
		required this.title,
		required this.isSticky,
		required this.time,
		this.flag
	}) {
		Map<int, Post> postsById = Map();
		for (final post in this.posts) {
			postsById[post.id] = post;
			post.replyIds = [];
		}
		for (final post in this.posts) {
			for (final referencedPostId in post.span.referencedPostIds(board)) {
				postsById[referencedPostId]?.replyIds = [...?postsById[referencedPostId]?.replyIds, post.id];
			}
		}
	}

	bool operator == (dynamic d) => (d is Thread) && (d.id == id);
	int get hashCode => id;

	String toString() {
		return 'Thread /$board/$id';
	}

	List<String> getSearchableText() {
		if (title != null) {
			return [title!, posts[0].text];
		}
		else {
			return [posts[0].text];
		}
	}

	ThreadIdentifier get identifier => ThreadIdentifier(board: board, id: id);
}

class ThreadIdentifier {
	final String board;
	final int id;
	ThreadIdentifier({
		required this.board,
		required this.id
	});

	String toString() => 'ThreadIdentifier: /$board/$id';

	bool operator == (dynamic d) => (d is ThreadIdentifier) && (d.board == board) && (d.id == id);
	int get hashCode => board.hashCode * 31 + id.hashCode;
}
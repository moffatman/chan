import 'package:chan/models/flag.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/services/filtering.dart';
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
	@override
	@HiveField(5)
	final int id;
	@override
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
	@HiveField(12)
	int? currentPage;
	@HiveField(13)
	int? uniqueIPCount;
	@HiveField(14)
	int? customSpoilerId;
	@HiveField(15, defaultValue: false)
	bool attachmentDeleted;
	Thread({
		required this.posts,
		this.isArchived = false,
		this.isDeleted = false,
		required this.replyCount,
		required this.imageCount,
		required this.id,
		this.attachment,
		this.attachmentDeleted = false,
		required this.board,
		required this.title,
		required this.isSticky,
		required this.time,
		this.flag,
		this.currentPage,
		this.uniqueIPCount,
		this.customSpoilerId
	}) {
		Map<int, Post> postsById = {};
		for (final post in posts) {
			postsById[post.id] = post;
			post.replyIds = [];
		}
		for (final post in posts) {
			for (final referencedPostId in post.span.referencedPostIds(board)) {
				if (!(postsById[referencedPostId]?.replyIds.contains(post.id) ?? true)) {
					postsById[referencedPostId]?.replyIds.add(post.id);
				}
			}
		}
	}

	@override
	bool operator == (dynamic other) {
		return (other is Thread)
			&& (other.id == id)
			&& (other.posts.length == posts.length)
			&& other.currentPage == currentPage
			&& other.isArchived == isArchived
			&& other.isDeleted == isDeleted
			&& other.isSticky == isSticky
			&& other.attachment?.thumbnailUrl == attachment?.thumbnailUrl;
	}
	@override
	int get hashCode => id;

	@override
	String toString() {
		return 'Thread /$board/$id';
	}

	@override
	String? getFilterFieldText(String fieldName) {
		switch (fieldName) {
			case 'subject':
				return title;
			case 'name':
				return posts.first.name;
			case 'filename':
				return attachment?.filename;
			case 'text':
				return posts.first.span.buildText();
			case 'postID':
				return id.toString();
			case 'posterID':
				return posts.first.posterId;
			case 'flag':
				return posts.first.flag?.name;
			default:
				return null;
		}
	}
	@override
	bool get hasFile => attachment != null;
	@override
	bool get isThread => true;

	ThreadIdentifier get identifier => ThreadIdentifier(board: board, id: id);
}

@HiveType(typeId: 23)
class ThreadIdentifier {
	@HiveField(0)
	final String board;
	@HiveField(1)
	final int id;
	ThreadIdentifier({
		required this.board,
		required this.id
	});

	@override
	String toString() => 'ThreadIdentifier: /$board/$id';

	@override
	bool operator == (dynamic other) => (other is ThreadIdentifier) && (other.board == board) && (other.id == id);
	@override
	int get hashCode => board.hashCode * 31 + id.hashCode;
}
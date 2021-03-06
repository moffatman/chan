import 'package:chan/models/post.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/widgets/provider_list.dart';

class Thread implements Filterable {
	final List<Post> posts;
	final bool isArchived;
	final bool isDeleted;
	final int replyCount;
	final int imageCount;
	final int id;
	final String board;
	final Attachment? attachment;
	final String? title;
	final bool isSticky;
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
		required this.isSticky
	}) {
		Map<int, Post> postsById = Map();
		for (final post in this.posts) {
			postsById[post.id] = post;
		}
		for (final post in this.posts) {
			for (final referencedPostId in post.span.referencedPostIds) {
				postsById[referencedPostId]?.replyIds.add(post.id);
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
}
import 'package:meta/meta.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/attachment.dart';

class Thread {
	final List<Post> posts;
	final bool isArchived;
	final bool isDeleted;
	final int replyCount;
	final int imageCount;
	final int id;
	final String board;
	final Attachment attachment;
	final String title;
	const Thread({
		@required this.posts,
		@required this.isArchived,
		@required this.isDeleted,
		@required this.replyCount,
		@required this.imageCount,
		@required this.id,
		this.attachment,
		@required this.board,
		@required this.title
	});

	bool operator == (dynamic d) => (d is Thread) && (d.id == id);
	int get hashCode => id;
}
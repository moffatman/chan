import 'post_element.dart';

import 'attachment.dart';
class Post {
	final String board;
	final String text;
	final String name;
	final DateTime time;
	final int id;
	final Attachment? attachment;
	PostSpan span;
	List<int> replyIds = [];
	Post({
		required this.board,
		required this.text,
		required this.name,
		required this.time,
		required this.id,
		required this.span,
		this.attachment
	});

	@override
	String toString() {
		return "Post $id";
	}
}
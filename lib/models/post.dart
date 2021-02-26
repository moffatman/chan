import 'post_element.dart';

import 'attachment.dart';
class Post {
	final String board;
	final String text;
	final String name;
	final DateTime time;
	final int id;
	final Attachment? attachment;
	List<PostElement> elements;
	final List<Post> replies = [];
	Post({
		required this.board,
		required this.text,
		required this.name,
		required this.time,
		required this.id,
		required this.elements,
		this.attachment
	});

	@override
	String toString() {
		return "Post $id";
	}
}
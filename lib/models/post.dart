import 'package:chan/widgets/provider_list.dart';

import 'post_element.dart';

import 'attachment.dart';
class Post implements Filterable {
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

	List<String> getSearchableText() {
		return [text];
	}
}
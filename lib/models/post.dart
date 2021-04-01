import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/refreshable_list.dart';

import 'post_element.dart';

import 'attachment.dart';
class Post implements Filterable {
	final String board;
	final String text;
	final String name;
	final DateTime time;
	final int id;
	final Attachment? attachment;
	final ImageboardFlag? flag;
	final String? posterId;
	PostSpan span;
	List<int> replyIds = [];
	Post({
		required this.board,
		required this.text,
		required this.name,
		required this.time,
		required this.id,
		required this.span,
		this.flag,
		this.attachment,
		this.posterId
	});

	@override
	String toString() {
		return 'Post $id';
	}

	List<String> getSearchableText() {
		return [text];
	}
}
import 'package:meta/meta.dart';
import 'post_element.dart';

import 'attachment.dart';
class Post {
	final String text;
	final String name;
	final DateTime time;
	final int id;
	final Attachment attachment;
	final List<PostElement> elements;
	const Post({
		@required this.text,
		@required this.name,
		@required this.time,
		@required this.id,
		@required this.elements,
		this.attachment
	});
}
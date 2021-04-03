import 'package:chan/models/post.dart';

enum AttachmentType {
	Image,
	WEBM
}

class Attachment {
	final String board;
	final int id;
	final String ext;
	final String filename;
	final AttachmentType type;
	final Uri url;
	final Uri thumbnailUrl;
	late Post post;
	Attachment({
		required this.type,
		required this.board,
		required this.id,
		required this.ext,
		required this.filename,
		required this.url,
		required this.thumbnailUrl
	});
}
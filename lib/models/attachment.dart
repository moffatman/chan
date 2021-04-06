import 'package:chan/models/post.dart';
import 'package:hive/hive.dart';

part 'attachment.g.dart';

@HiveType(typeId: 10)
enum AttachmentType {
	@HiveField(0)
	Image,
	@HiveField(1)
	WEBM
}

@HiveType(typeId: 9)
class Attachment {
	@HiveField(0)
	final String board;
	@HiveField(1)
	final int id;
	@HiveField(2)
	final String ext;
	@HiveField(3)
	final String filename;
	@HiveField(4)
	final AttachmentType type;
	@HiveField(5)
	final Uri url;
	@HiveField(6)
	final Uri thumbnailUrl;
	late Post post;
	@HiveField(7)
	final String md5;
	Attachment({
		required this.type,
		required this.board,
		required this.id,
		required this.ext,
		required this.filename,
		required this.url,
		required this.thumbnailUrl,
		required this.md5
	});
}
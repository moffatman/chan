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
	@HiveField(7)
	final String md5;
	@HiveField(8)
	final bool spoiler;
	@HiveField(9)
	final int? width;
	@HiveField(10)
	final int? height;
	Attachment({
		required this.type,
		required this.board,
		required this.id,
		required this.ext,
		required this.filename,
		required this.url,
		required this.thumbnailUrl,
		required this.md5,
		bool? spoiler,
		this.width,
		this.height
	}) : this.spoiler = spoiler ?? false;

	bool? get isLandscape => (width == null || height == null) ? null : width! > height!;
}
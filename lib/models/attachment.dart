import 'package:hive/hive.dart';

part 'attachment.g.dart';

@HiveType(typeId: 10)
enum AttachmentType {
	@HiveField(0)
	image,
	@HiveField(1)
	webm,
	@HiveField(2)
	mp4,
	@HiveField(3)
	mp3,
	@HiveField(4)
	pdf
}

@HiveType(typeId: 9)
class Attachment {
	@HiveField(0)
	final String board;
	@HiveField(1)
	final int deprecatedId;
	@HiveField(2)
	final String ext;
	@HiveField(3)
	final String filename;
	@HiveField(4)
	final AttachmentType type;
	@HiveField(5)
	final Uri url;
	@HiveField(6)
	Uri thumbnailUrl;
	@HiveField(7)
	final String md5;
	@HiveField(8)
	final bool spoiler;
	@HiveField(9)
	final int? width;
	@HiveField(10)
	final int? height;
	@HiveField(11)
	final int? threadId;
	@HiveField(12)
	final int? sizeInBytes;
	@HiveField(13, defaultValue: '')
	String id;
	Attachment({
		required this.type,
		required this.board,
		required this.id,
		this.deprecatedId = 0,
		required this.ext,
		required this.filename,
		required this.url,
		required this.thumbnailUrl,
		required this.md5,
		bool? spoiler,
		required this.width,
		required this.height,
		required this.threadId,
		required this.sizeInBytes
	}) : spoiler = spoiler ?? false {
		if (id == '') {
			id = deprecatedId.toString();
		}
	}

	bool? get isLandscape => (width == null || height == null) ? null : width! > height!;

	String get globalId => '${board}_$id';

	@override
	String toString() => 'Attachment(board: $board, id: $id, ext: $ext, filename: $filename, type: $type, url: $url, thumbnailUrl: $thumbnailUrl, md5: $md5, spoiler: $spoiler, width: $width, height: $height, threadId: $threadId)';
}
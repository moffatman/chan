import 'package:chan/models/intern.dart';
import 'package:chan/services/soundposts.dart';
import 'package:flutter/cupertino.dart';
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
	pdf,
	@HiveField(5)
	url;
	static AttachmentType fromFilename(String filename) {
		final ext = filename.split('.').last.toLowerCase();
		switch (ext) {
			case 'webm':
				return AttachmentType.webm;
			case 'mp4':
				return AttachmentType.mp4;
			case 'pdf':
				return AttachmentType.pdf;
			case 'mp3':
				return AttachmentType.mp3;
			default:
				return AttachmentType.image;
		}
	}
	bool get isVideo => this == AttachmentType.webm || this == AttachmentType.mp4;
	bool get isImageSearchable => isVideo || this == AttachmentType.image;
}

void _readHookAttachmentFields(Map<int, dynamic> fields) {
	fields.update(AttachmentFields.url.fieldNumber, (url) {
		if (url is Uri) {
			return url.toString();
		}
		return url;
	});
	fields.update(AttachmentFields.thumbnailUrl.fieldNumber, (url) {
		if (url is Uri) {
			return url.toString();
		}
		return url;
	});
}

@HiveType(typeId: 9, isOptimized: true, readHook: _readHookAttachmentFields)
class Attachment {
	@HiveField(0)
	final String board;
	@HiveField(2)
	final String ext;
	@HiveField(3)
	String filename;
	@HiveField(4)
	final AttachmentType type;
	@HiveField(5)
	final String url;
	@HiveField(6)
	String thumbnailUrl;
	@HiveField(7)
	final String md5;
	@HiveField(8, isOptimized: true, defaultValue: false)
	final bool spoiler;
	@HiveField(9, isOptimized: true)
	int? width;
	@HiveField(10, isOptimized: true)
	int? height;
	@HiveField(11, isOptimized: true)
	final int? threadId;
	@HiveField(12, isOptimized: true)
	int? sizeInBytes;
	@HiveField(13)
	String id;
	@HiveField(14, isOptimized: true, defaultValue: false)
	final bool useRandomUseragent;
	@HiveField(15, isOptimized: true, defaultValue: false)
	final bool isRateLimited;
	Attachment({
		required this.type,
		required String board,
		required this.id,
		required String ext,
		required this.filename,
		required this.url,
		required this.thumbnailUrl,
		required this.md5,
		this.spoiler = false,
		required this.width,
		required this.height,
		required this.threadId,
		required this.sizeInBytes,
		this.useRandomUseragent = false,
		this.isRateLimited = false
	}) : board = intern(board), ext = intern(ext);

	double get aspectRatio {
		if (width == null || height == null) {
			return 1;
		}
		return width! / height!;
	}

	Size estimateFittedSize({
		required Size size,
		BoxFit fit = BoxFit.contain,
	}) {
		if (width == null || height == null) {
			return size;
		}
		return applyBoxFit(
			fit,
			Size(width!.toDouble(), height!.toDouble()),
			size
		).destination;
	}

	bool get isGif => ext.toLowerCase().endsWith('gif');

	IconData? get icon {
		if (soundSource != null || type == AttachmentType.mp3) {
			return CupertinoIcons.volume_up;
		}
		if (type.isVideo) {
			return CupertinoIcons.play_arrow_solid;
		}
		if (isGif) {
			return CupertinoIcons.play_arrow;
		}
		if (type == AttachmentType.url || type == AttachmentType.pdf) {
			return CupertinoIcons.link;
		}
		return null;
	}

	String? get ellipsizedFilename {
		if (filename.length <= 53) {
			return null;
		}
		return '${filename.substring(0, 25)}...${filename.substring(filename.length - 25)}';
	}

	String get globalId => '${board}_$id';

	@override
	String toString() => 'Attachment(board: $board, id: $id, ext: $ext, filename: $filename, type: $type, url: $url, thumbnailUrl: $thumbnailUrl, md5: $md5, spoiler: $spoiler, width: $width, height: $height, threadId: $threadId)';

	@override
	bool operator==(Object other) => (other is Attachment) && (other.url == url) && (other.thumbnailUrl == thumbnailUrl) && (other.type == type);

	@override
	int get hashCode => Object.hash(url, thumbnailUrl);

	static const unmodifiableListMerger = MapLikeListMerger<Attachment, String>(
		childMerger: AdaptedMerger<Attachment>(AttachmentAdapter.kTypeId),
		keyer: AttachmentFields.getId,
		unmodifiable: true,
		maintainOrder: true
	);
}

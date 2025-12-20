import 'package:chan/models/intern.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/soundposts.dart';
import 'package:chan/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
	url,
	@HiveField(6)
	swf;
	static AttachmentType fromFilename(String filename) {
		final ext = filename.afterLast('.').toLowerCase();
		switch (ext) {
			case 'webm':
				return AttachmentType.webm;
			case 'mp4':
			case 'mov':
				return AttachmentType.mp4;
			case 'pdf':
				return AttachmentType.pdf;
			case 'mp3':
				return AttachmentType.mp3;
			case 'swf':
				return AttachmentType.swf;
			default:
				return AttachmentType.image;
		}
	}
	bool get isVideo => this == AttachmentType.webm || this == AttachmentType.mp4;
	bool get usesVideoPlayer => this == AttachmentType.webm || this == AttachmentType.mp4 || this == AttachmentType.mp3;
	bool get isZoomable => isVideo || this == AttachmentType.image;
	bool get isImageSearchable => isVideo || this == AttachmentType.image;
	bool get isNonMedia => this == AttachmentType.url || this == AttachmentType.pdf || this == AttachmentType.swf;
	String get noun => switch (this) {
		webm || mp4 => 'video',
		image => 'image',
		mp3 => 'mp3',
		url => 'web',
		pdf => 'pdf',
		swf => 'swf'
	};
}

void _readHookAttachmentFields(Map<int, dynamic> fields) {
	fields.update(AttachmentFields.url.fieldNumber, (url) {
		if (url is Uri) {
			return url.toString();
		}
		return url;
	}, ifAbsent: () => '');
	fields.update(AttachmentFields.thumbnailUrl.fieldNumber, (url) {
		if (url is Uri) {
			return url.toString();
		}
		return url;
	}, ifAbsent: () => '');
	fields.putIfAbsent(AttachmentFields.id.fieldNumber, () {
		// This attachment was written a very long time ago
		// fields[1] is probably "int deprecatedId"
		// Or I guess it could be null, in that case it still works to fix launching
		return '${fields[1]}';
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
	final String id;
	@HiveField(14, isOptimized: true, defaultValue: false)
	final bool useRandomUseragent;
	@HiveField(15, isOptimized: true, defaultValue: false)
	final bool isRateLimited;
	// Do not persist, for avoiding Hero conflict when posts quote others so image shows up twice
	final int? inlineWithinPostId;
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
		this.isRateLimited = false,
		this.inlineWithinPostId
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

	bool get shouldOpenExternally {
		if (type != AttachmentType.url) {
			return false;
		}
		final host = Uri.tryParse(url)?.host;
		if (host == null) {
			return false;
		}
		return Settings.instance.hostsToOpenExternally.any((h) => host.endsWith(h));
	}

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
		if (shouldOpenExternally) {
			return Icons.launch_rounded;
		}
		if (type.isNonMedia) {
			return CupertinoIcons.link;
		}
		return null;
	}

	String? get ellipsizedFilename {
		return filename.ellipsizeIfLonger(50, ellipsis: '...');
	}

	String get globalId => '${board}_$id';

	@override
	String toString() => 'Attachment(board: $board, id: $id, ext: $ext, filename: $filename, type: $type, url: $url, thumbnailUrl: $thumbnailUrl, md5: $md5, spoiler: $spoiler, width: $width, height: $height, threadId: $threadId, sizeInBytes: $sizeInBytes)';

	@override
	bool operator==(Object other) => identical(this, other) || (other is Attachment) && (other.url == url) && (other.thumbnailUrl == thumbnailUrl) && (other.type == type) && (other.id == id) && (other.spoiler == spoiler);

	@override
	int get hashCode => Object.hash(url, thumbnailUrl, type, id);

	static const unmodifiableListMerger = MapLikeListMerger<Attachment, String>(
		childMerger: AdaptedMerger<Attachment>(AttachmentAdapter.kTypeId),
		keyer: AttachmentFields.getId,
		unmodifiable: true,
		maintainOrder: true
	);
}

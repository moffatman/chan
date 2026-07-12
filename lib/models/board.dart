import 'package:chan/models/intern.dart';
import 'package:hive/hive.dart';
import 'package:chan/services/persistence.dart';

part 'board.g.dart';

extension type BoardKey(String s) {
	
}

@HiveType(typeId: 16, isOptimized: true)
class ImageboardBoard extends HiveObject {
	@HiveField(0)
	final String name;
	@HiveField(1)
	final String title;
	@HiveField(2)
	final bool isWorksafe;
	@HiveField(3)
	final bool webmAudioAllowed;
	@HiveField(4, isOptimized: true)
	int? maxImageSizeBytes;
	@HiveField(5, isOptimized: true)
	int? maxWebmSizeBytes;
	@HiveField(6, isOptimized: true)
	final int? maxWebmDurationSeconds;
	@HiveField(7, isOptimized: true)
	int? maxCommentCharacters;
	@HiveField(8, isOptimized: true)
	int? threadCommentLimit;
	@HiveField(9, isOptimized: true)
	final int? threadImageLimit;
	@HiveField(10, isOptimized: true)
	int? pageCount;
	@HiveField(11, isOptimized: true)
	final int? threadCooldown;
	@HiveField(12, isOptimized: true)
	final int? replyCooldown;
	@HiveField(13, isOptimized: true)
	final int? imageCooldown;
	@HiveField(14, isOptimized: true)
	final bool? spoilers;
	@HiveField(15, isOptimized: true)
	DateTime? additionalDataTime;
	@HiveField(16, isOptimized: true)
	final String? subdomain;
	@HiveField(17, isOptimized: true)
	final Uri? icon;
	@HiveField(18, isOptimized: true)
	int? captchaMode;
	final BoardKey boardKey;
	@HiveField(19, isOptimized: true)
	final int? popularity;
	@HiveField(20, defaultValue: 1)
	final int filesPerPost;

	ImageboardBoard({
		required String name,
		required this.title,
		required this.isWorksafe,
		required this.webmAudioAllowed,
		required this.filesPerPost,
		this.maxImageSizeBytes,
		this.maxWebmSizeBytes,
		this.maxWebmDurationSeconds,
		this.maxCommentCharacters,
		this.threadCommentLimit,
		this.threadImageLimit,
		this.pageCount,
		this.threadCooldown,
		this.replyCooldown,
		this.imageCooldown,
		this.spoilers,
		this.additionalDataTime,
		this.subdomain,
		this.icon,
		this.captchaMode,
		this.popularity
	}) : name = intern(name), boardKey = getKey(name);

	@override
	String toString() => 'ImageboardBoard(${{
		'name': name,
		'title': title,
		'isWorksafe': '$isWorksafe',
		'webmAudioAllowed': '$webmAudioAllowed',
		'filesPerPost': '$filesPerPost',
		if (maxImageSizeBytes != null) 'maxImageSizeBytes': '$maxImageSizeBytes',
		if (maxWebmSizeBytes != null) 'maxWebmSizeBytes': '$maxWebmSizeBytes',
		if (maxWebmDurationSeconds != null) 'maxWebmDurationSeconds': '$maxWebmDurationSeconds',
		if (maxCommentCharacters != null) 'maxCommentCharacters': '$maxCommentCharacters',
		if (threadCommentLimit != null) 'threadCommentLimit': '$threadCommentLimit',
		if (threadImageLimit != null) 'threadImageLimit': '$threadImageLimit',
		if (pageCount != null) 'pageCount': '$pageCount',
		if (threadCooldown != null) 'threadCooldown': '$threadCooldown',
		if (replyCooldown != null) 'replyCooldown': '$replyCooldown',
		if (imageCooldown != null) 'imageCooldown': '$imageCooldown',
		if (spoilers != null) 'spoilers': '$spoilers',
		if (additionalDataTime != null) 'additionalDataTime': '$additionalDataTime',
		if (subdomain != null) 'subdomain': '$subdomain',
		if (icon != null) 'icon': '$icon',
		if (captchaMode != null) 'captchaMode': '$captchaMode',
		if (popularity != null) 'popularity': '$popularity',
	}})';

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		(other is ImageboardBoard) &&
		(other.name == name) &&
		(other.title == title) &&
		(other.isWorksafe == isWorksafe) &&
		(other.webmAudioAllowed == webmAudioAllowed) &&
		(other.maxImageSizeBytes == maxImageSizeBytes) &&
		(other.maxWebmSizeBytes == maxWebmSizeBytes) &&
		(other.maxWebmDurationSeconds == maxWebmDurationSeconds) &&
		(other.maxCommentCharacters == maxCommentCharacters) &&
		(other.threadCommentLimit == threadCommentLimit) &&
		(other.threadImageLimit == threadImageLimit) &&
		(other.pageCount == pageCount) &&
		(other.threadCooldown == threadCooldown) &&
		(other.replyCooldown == replyCooldown) &&
		(other.imageCooldown == imageCooldown) &&
		(other.spoilers == spoilers) &&
		(other.additionalDataTime == additionalDataTime) &&
		(other.subdomain == subdomain) &&
		(other.icon == icon) &&
		(other.captchaMode == captchaMode) &&
		(other.popularity == popularity) &&
		(other.filesPerPost == filesPerPost);

	@override
	int get hashCode => Object.hash(name, title);

	static final _keys = Map<String, BoardKey>.identity();
	static BoardKey getKey(String board) {
		return _keys[intern(board)] ??= BoardKey(intern(board.toLowerCase()));
	}
}

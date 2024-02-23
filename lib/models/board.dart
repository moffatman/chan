import 'package:hive/hive.dart';
import 'package:chan/services/persistence.dart';

part 'board.g.dart';

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

	ImageboardBoard({
		required this.name,
		required this.title,
		required this.isWorksafe,
		required this.webmAudioAllowed,
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
		this.captchaMode
	});

	@override
	String toString() => '/$name/';

	@override
	bool operator == (Object other) => (other is ImageboardBoard) &&
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
		(other.captchaMode == captchaMode);

	@override
	int get hashCode => Object.hash(name, title, isWorksafe, webmAudioAllowed, maxImageSizeBytes, maxWebmSizeBytes, maxWebmDurationSeconds, maxCommentCharacters, threadCommentLimit, threadImageLimit, pageCount, threadCooldown, replyCooldown, imageCooldown, spoilers, additionalDataTime, subdomain, icon, captchaMode);
}

import 'package:hive/hive.dart';

part 'board.g.dart';

@HiveType(typeId: 16)
class ImageboardBoard {
	@HiveField(0)
	final String name;
	@HiveField(1)
	final String title;
	@HiveField(2)
	final bool isWorksafe;
	@HiveField(3)
	final bool webmAudioAllowed;
	@HiveField(4)
	final int? maxImageSizeBytes;
	@HiveField(5)
	final int? maxWebmSizeBytes;
	@HiveField(6)
	final int? maxWebmDurationSeconds;
	@HiveField(7)
	final int? maxCommentCharacters;
	@HiveField(8)
	final int? threadCommentLimit;
	@HiveField(9)
	final int? threadImageLimit;
	@HiveField(10)
	final int? pageCount;
	@HiveField(11)
	final int? threadCooldown;
	@HiveField(12)
	final int? replyCooldown;
	@HiveField(13)
	final int? imageCooldown;
	@HiveField(14)
	final bool? spoilers;

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
		this.spoilers
	});

	@override
	String toString() => '/$name/';
}
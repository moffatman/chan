import 'package:hive/hive.dart';

class ImageboardBoard {
	final String name;
	final String title;
	final bool isWorksafe;
	final bool webmAudioAllowed;
	int? maxImageSizeBytes;
	int? maxWebmSizeBytes;
	final int? maxWebmDurationSeconds;
	int? maxCommentCharacters;
	int? threadCommentLimit;
	final int? threadImageLimit;
	int? pageCount;
	final int? threadCooldown;
	final int? replyCooldown;
	final int? imageCooldown;
	final bool? spoilers;
	DateTime? additionalDataTime;
	String? subdomain;
	Uri? icon;

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
		this.icon
	});

	@override
	String toString() => '/$name/';
}

class ImageboardBoardAdapter extends TypeAdapter<ImageboardBoard> {
  @override
  final int typeId = 16;

  @override
  ImageboardBoard read(BinaryReader reader) {
    final numOfFields = reader.readByte();
		final Map<int, dynamic> fields;
		if (numOfFields == 255) {
			// Dynamic number of fields
			fields = {};
			while (true) {
				final int fieldId = reader.readByte();
				fields[fieldId] = reader.read();
				if (fieldId == 0) {
					break;
				}
			}
		}
		else {
			fields = <int, dynamic>{
				for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
			};
		}
    return ImageboardBoard(
      name: fields[0] as String,
      title: fields[1] as String,
      isWorksafe: fields[2] as bool,
      webmAudioAllowed: fields[3] as bool,
      maxImageSizeBytes: fields[4] as int?,
      maxWebmSizeBytes: fields[5] as int?,
      maxWebmDurationSeconds: fields[6] as int?,
      maxCommentCharacters: fields[7] as int?,
      threadCommentLimit: fields[8] as int?,
      threadImageLimit: fields[9] as int?,
      pageCount: fields[10] as int?,
      threadCooldown: fields[11] as int?,
      replyCooldown: fields[12] as int?,
      imageCooldown: fields[13] as int?,
      spoilers: fields[14] as bool?,
      additionalDataTime: fields[15] as DateTime?,
      subdomain: fields[16] as String?,
			icon: fields[17] as Uri?,
    );
  }

  @override
  void write(BinaryWriter writer, ImageboardBoard obj) {
    writer
      ..writeByte(255)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.isWorksafe)
      ..writeByte(3)
      ..write(obj.webmAudioAllowed);
		if (obj.maxImageSizeBytes != null) {
      writer..writeByte(4)..write(obj.maxImageSizeBytes);
		}
		if (obj.maxWebmSizeBytes != null) {
      writer..writeByte(5)..write(obj.maxWebmSizeBytes);
		}
		if (obj.maxWebmDurationSeconds != null) {
      writer..writeByte(6)..write(obj.maxWebmDurationSeconds);
		}
		if (obj.maxCommentCharacters != null) {
      writer..writeByte(7)..write(obj.maxCommentCharacters);
		}
		if (obj.threadCommentLimit != null) {
      writer..writeByte(8)..write(obj.threadCommentLimit);
		}
		if (obj.threadImageLimit != null) {
      writer..writeByte(9)..write(obj.threadImageLimit);
		}
		if (obj.pageCount != null) {
      writer..writeByte(10)..write(obj.pageCount);
		}
		if (obj.threadCooldown != null) {
      writer..writeByte(11)..write(obj.threadCooldown);
		}
		if (obj.replyCooldown != null) {
      writer..writeByte(12)..write(obj.replyCooldown);
		}
		if (obj.imageCooldown != null) {
      writer..writeByte(13)..write(obj.imageCooldown);
		}
		if (obj.spoilers != null) {
      writer..writeByte(14)..write(obj.spoilers);
		}
		if (obj.additionalDataTime != null) {
      writer..writeByte(15)..write(obj.additionalDataTime);
		}
		if (obj.subdomain != null) {
      writer..writeByte(16)..write(obj.subdomain);
		}
		if (obj.icon != null) {
			writer..writeByte(17)..write(obj.icon);
		}
		writer
			..writeByte(0)
      ..write(obj.name);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageboardBoardAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

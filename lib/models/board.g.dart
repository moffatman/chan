// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'board.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ImageboardBoardAdapter extends TypeAdapter<ImageboardBoard> {
  @override
  final int typeId = 16;

  @override
  ImageboardBoard read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
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
    );
  }

  @override
  void write(BinaryWriter writer, ImageboardBoard obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.isWorksafe)
      ..writeByte(3)
      ..write(obj.webmAudioAllowed)
      ..writeByte(4)
      ..write(obj.maxImageSizeBytes)
      ..writeByte(5)
      ..write(obj.maxWebmSizeBytes)
      ..writeByte(6)
      ..write(obj.maxWebmDurationSeconds)
      ..writeByte(7)
      ..write(obj.maxCommentCharacters)
      ..writeByte(8)
      ..write(obj.threadCommentLimit)
      ..writeByte(9)
      ..write(obj.threadImageLimit)
      ..writeByte(10)
      ..write(obj.pageCount)
      ..writeByte(11)
      ..write(obj.threadCooldown)
      ..writeByte(12)
      ..write(obj.replyCooldown)
      ..writeByte(13)
      ..write(obj.imageCooldown)
      ..writeByte(14)
      ..write(obj.spoilers)
      ..writeByte(15)
      ..write(obj.additionalDataTime)
      ..writeByte(16)
      ..write(obj.subdomain);
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

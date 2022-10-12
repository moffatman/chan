// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AttachmentAdapter extends TypeAdapter<Attachment> {
  @override
  final int typeId = 9;

  @override
  Attachment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Attachment(
      type: fields[4] as AttachmentType,
      board: fields[0] as String,
      id: fields[13] == null ? '' : fields[13] as String,
      deprecatedId: fields[1] as int,
      ext: fields[2] as String,
      filename: fields[3] as String,
      url: fields[5] as Uri,
      thumbnailUrl: fields[6] as Uri,
      md5: fields[7] as String,
      spoiler: fields[8] as bool?,
      width: fields[9] as int?,
      height: fields[10] as int?,
      threadId: fields[11] as int?,
      sizeInBytes: fields[12] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Attachment obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.board)
      ..writeByte(1)
      ..write(obj.deprecatedId)
      ..writeByte(2)
      ..write(obj.ext)
      ..writeByte(3)
      ..write(obj.filename)
      ..writeByte(4)
      ..write(obj.type)
      ..writeByte(5)
      ..write(obj.url)
      ..writeByte(6)
      ..write(obj.thumbnailUrl)
      ..writeByte(7)
      ..write(obj.md5)
      ..writeByte(8)
      ..write(obj.spoiler)
      ..writeByte(9)
      ..write(obj.width)
      ..writeByte(10)
      ..write(obj.height)
      ..writeByte(11)
      ..write(obj.threadId)
      ..writeByte(12)
      ..write(obj.sizeInBytes)
      ..writeByte(13)
      ..write(obj.id);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttachmentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AttachmentTypeAdapter extends TypeAdapter<AttachmentType> {
  @override
  final int typeId = 10;

  @override
  AttachmentType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AttachmentType.image;
      case 1:
        return AttachmentType.webm;
      case 2:
        return AttachmentType.mp4;
      case 3:
        return AttachmentType.mp3;
      case 4:
        return AttachmentType.pdf;
      default:
        return AttachmentType.image;
    }
  }

  @override
  void write(BinaryWriter writer, AttachmentType obj) {
    switch (obj) {
      case AttachmentType.image:
        writer.writeByte(0);
        break;
      case AttachmentType.webm:
        writer.writeByte(1);
        break;
      case AttachmentType.mp4:
        writer.writeByte(2);
        break;
      case AttachmentType.mp3:
        writer.writeByte(3);
        break;
      case AttachmentType.pdf:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttachmentTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

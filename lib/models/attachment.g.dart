// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

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
      case 5:
        return AttachmentType.url;
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
      case AttachmentType.url:
        writer.writeByte(5);
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

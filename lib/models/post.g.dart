// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PostSpanFormatAdapter extends TypeAdapter<PostSpanFormat> {
  @override
  final int typeId = 13;

  @override
  PostSpanFormat read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PostSpanFormat.chan4;
      case 1:
        return PostSpanFormat.foolFuuka;
      case 2:
        return PostSpanFormat.lainchan;
      case 3:
        return PostSpanFormat.fuuka;
      case 4:
        return PostSpanFormat.futaba;
      default:
        return PostSpanFormat.chan4;
    }
  }

  @override
  void write(BinaryWriter writer, PostSpanFormat obj) {
    switch (obj) {
      case PostSpanFormat.chan4:
        writer.writeByte(0);
        break;
      case PostSpanFormat.foolFuuka:
        writer.writeByte(1);
        break;
      case PostSpanFormat.lainchan:
        writer.writeByte(2);
        break;
      case PostSpanFormat.fuuka:
        writer.writeByte(3);
        break;
      case PostSpanFormat.futaba:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostSpanFormatAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

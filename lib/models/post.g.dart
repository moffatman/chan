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
      case 5:
        return PostSpanFormat.reddit;
      case 6:
        return PostSpanFormat.hackerNews;
      case 7:
        return PostSpanFormat.stub;
      case 8:
        return PostSpanFormat.lynxchan;
      case 9:
        return PostSpanFormat.chan4Search;
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
      case PostSpanFormat.reddit:
        writer.writeByte(5);
        break;
      case PostSpanFormat.hackerNews:
        writer.writeByte(6);
        break;
      case PostSpanFormat.stub:
        writer.writeByte(7);
        break;
      case PostSpanFormat.lynxchan:
        writer.writeByte(8);
        break;
      case PostSpanFormat.chan4Search:
        writer.writeByte(9);
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

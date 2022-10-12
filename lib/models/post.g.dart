// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PostAdapter extends TypeAdapter<Post> {
  @override
  final int typeId = 11;

  @override
  Post read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Post(
      board: fields[0] as String,
      text: fields[1] as String,
      name: fields[2] as String,
      time: fields[3] as DateTime,
      trip: fields[13] as String?,
      threadId: fields[4] as int,
      id: fields[5] as int,
      spanFormat: fields[9] as PostSpanFormat,
      flag: fields[7] as ImageboardFlag?,
      deprecatedAttachment: fields[6] as Attachment?,
      attachmentDeleted: fields[11] == null ? false : fields[11] as bool,
      posterId: fields[8] as String?,
      foolfuukaLinkedPostThreadIds: (fields[12] as Map?)?.cast<String, int>(),
      passSinceYear: fields[14] as int?,
      capcode: fields[15] as String?,
      attachments:
          fields[16] == null ? [] : (fields[16] as List).cast<Attachment>(),
    );
  }

  @override
  void write(BinaryWriter writer, Post obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.board)
      ..writeByte(1)
      ..write(obj.text)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.time)
      ..writeByte(4)
      ..write(obj.threadId)
      ..writeByte(5)
      ..write(obj.id)
      ..writeByte(6)
      ..write(obj.deprecatedAttachment)
      ..writeByte(7)
      ..write(obj.flag)
      ..writeByte(8)
      ..write(obj.posterId)
      ..writeByte(9)
      ..write(obj.spanFormat)
      ..writeByte(12)
      ..write(obj.foolfuukaLinkedPostThreadIds)
      ..writeByte(11)
      ..write(obj.attachmentDeleted)
      ..writeByte(13)
      ..write(obj.trip)
      ..writeByte(14)
      ..write(obj.passSinceYear)
      ..writeByte(15)
      ..write(obj.capcode)
      ..writeByte(16)
      ..write(obj.attachments);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

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

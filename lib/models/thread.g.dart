// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'thread.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ThreadAdapter extends TypeAdapter<Thread> {
  @override
  final int typeId = 15;

  @override
  Thread read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Thread(
      posts_: (fields[0] as List).cast<Post>(),
      isArchived: fields[1] as bool,
      isDeleted: fields[2] as bool,
      replyCount: fields[3] as int,
      imageCount: fields[4] as int,
      id: fields[5] as int,
      deprecatedAttachment: fields[7] as Attachment?,
      attachmentDeleted: fields[15] == null ? false : fields[15] as bool,
      board: fields[6] as String,
      title: fields[8] as String?,
      isSticky: fields[9] as bool,
      time: fields[10] as DateTime,
      flag: fields[11] as ImageboardFlag?,
      currentPage: fields[12] as int?,
      uniqueIPCount: fields[13] as int?,
      customSpoilerId: fields[14] as int?,
      attachments:
          fields[16] == null ? [] : (fields[16] as List).cast<Attachment>(),
    );
  }

  @override
  void write(BinaryWriter writer, Thread obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.posts_)
      ..writeByte(1)
      ..write(obj.isArchived)
      ..writeByte(2)
      ..write(obj.isDeleted)
      ..writeByte(3)
      ..write(obj.replyCount)
      ..writeByte(4)
      ..write(obj.imageCount)
      ..writeByte(5)
      ..write(obj.id)
      ..writeByte(6)
      ..write(obj.board)
      ..writeByte(7)
      ..write(obj.deprecatedAttachment)
      ..writeByte(8)
      ..write(obj.title)
      ..writeByte(9)
      ..write(obj.isSticky)
      ..writeByte(10)
      ..write(obj.time)
      ..writeByte(11)
      ..write(obj.flag)
      ..writeByte(12)
      ..write(obj.currentPage)
      ..writeByte(13)
      ..write(obj.uniqueIPCount)
      ..writeByte(14)
      ..write(obj.customSpoilerId)
      ..writeByte(15)
      ..write(obj.attachmentDeleted)
      ..writeByte(16)
      ..write(obj.attachments);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThreadAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ThreadIdentifierAdapter extends TypeAdapter<ThreadIdentifier> {
  @override
  final int typeId = 23;

  @override
  ThreadIdentifier read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ThreadIdentifier(
      fields[0] as String,
      fields[1] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ThreadIdentifier obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.board)
      ..writeByte(1)
      ..write(obj.id);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThreadIdentifierAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

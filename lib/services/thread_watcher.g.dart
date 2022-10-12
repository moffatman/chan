// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'thread_watcher.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ThreadWatchAdapter extends TypeAdapter<ThreadWatch> {
  @override
  final int typeId = 28;

  @override
  ThreadWatch read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ThreadWatch(
      board: fields[0] as String,
      threadId: fields[1] as int,
      lastSeenId: fields[2] as int,
      localYousOnly: fields[3] == null ? true : fields[3] as bool,
      youIds: fields[4] == null ? [] : (fields[4] as List).cast<int>(),
      zombie: fields[5] == null ? false : fields[5] as bool,
      pushYousOnly: fields[6] == null ? true : fields[6] as bool?,
      push: fields[7] == null ? true : fields[7] as bool,
      foregroundMuted: fields[8] == null ? false : fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ThreadWatch obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.board)
      ..writeByte(1)
      ..write(obj.threadId)
      ..writeByte(2)
      ..write(obj.lastSeenId)
      ..writeByte(3)
      ..write(obj.localYousOnly)
      ..writeByte(4)
      ..write(obj.youIds)
      ..writeByte(5)
      ..write(obj.zombie)
      ..writeByte(6)
      ..write(obj.pushYousOnly)
      ..writeByte(7)
      ..write(obj.push)
      ..writeByte(8)
      ..write(obj.foregroundMuted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThreadWatchAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class NewThreadWatchAdapter extends TypeAdapter<NewThreadWatch> {
  @override
  final int typeId = 29;

  @override
  NewThreadWatch read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NewThreadWatch(
      board: fields[0] as String,
      filter: fields[1] as String,
      lastSeenId: fields[2] as int,
      allStickies: fields[3] as bool,
      uniqueId: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, NewThreadWatch obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.board)
      ..writeByte(1)
      ..write(obj.filter)
      ..writeByte(2)
      ..write(obj.lastSeenId)
      ..writeByte(3)
      ..write(obj.allStickies)
      ..writeByte(4)
      ..write(obj.uniqueId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NewThreadWatchAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

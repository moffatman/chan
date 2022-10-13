// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'thread.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

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

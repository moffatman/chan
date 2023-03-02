// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flag.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ImageboardFlagAdapter extends TypeAdapter<ImageboardFlag> {
  @override
  final int typeId = 14;

  @override
  ImageboardFlag read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ImageboardFlag(
      name: fields[0] as String,
      imageUrl: fields[1] as String,
      imageWidth: fields[2] as double,
      imageHeight: fields[3] as double,
    );
  }

  @override
  void write(BinaryWriter writer, ImageboardFlag obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.imageUrl)
      ..writeByte(2)
      ..write(obj.imageWidth)
      ..writeByte(3)
      ..write(obj.imageHeight);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageboardFlagAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ImageboardMultiFlagAdapter extends TypeAdapter<ImageboardMultiFlag> {
  @override
  final int typeId = 36;

  @override
  ImageboardMultiFlag read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ImageboardMultiFlag(
      parts: (fields[0] as List).cast<ImageboardFlag>(),
    );
  }

  @override
  void write(BinaryWriter writer, ImageboardMultiFlag obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.parts);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageboardMultiFlagAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

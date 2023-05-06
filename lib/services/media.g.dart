// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MediaScanAdapter extends TypeAdapter<MediaScan> {
  @override
  final int typeId = 38;

  @override
  MediaScan read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MediaScan(
      hasAudio: fields[0] as bool,
      duration: fields[1] as Duration?,
      bitrate: fields[2] as int?,
      width: fields[3] as int?,
      height: fields[4] as int?,
      codec: fields[5] as String?,
      videoFramerate: fields[6] as double?,
      sizeInBytes: fields[7] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, MediaScan obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.hasAudio)
      ..writeByte(1)
      ..write(obj.duration)
      ..writeByte(2)
      ..write(obj.bitrate)
      ..writeByte(3)
      ..write(obj.width)
      ..writeByte(4)
      ..write(obj.height)
      ..writeByte(5)
      ..write(obj.codec)
      ..writeByte(6)
      ..write(obj.videoFramerate)
      ..writeByte(7)
      ..write(obj.sizeInBytes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaScanAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

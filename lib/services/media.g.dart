// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MediaScanFields {
  static bool getHasAudio(MediaScan x) => x.hasAudio;
  static const hasAudio = ReadOnlyHiveFieldAdapter<MediaScan, bool>(
    getter: getHasAudio,
    fieldNumber: 0,
    fieldName: 'hasAudio',
    merger: PrimitiveMerger(),
  );
  static Duration? getDuration(MediaScan x) => x.duration;
  static const duration = ReadOnlyHiveFieldAdapter<MediaScan, Duration?>(
    getter: getDuration,
    fieldNumber: 1,
    fieldName: 'duration',
    merger: NullableMerger(AdaptedMerger(DurationAdapter.kTypeId)),
  );
  static int? getBitrate(MediaScan x) => x.bitrate;
  static const bitrate = ReadOnlyHiveFieldAdapter<MediaScan, int?>(
    getter: getBitrate,
    fieldNumber: 2,
    fieldName: 'bitrate',
    merger: PrimitiveMerger(),
  );
  static int? getWidth(MediaScan x) => x.width;
  static const width = ReadOnlyHiveFieldAdapter<MediaScan, int?>(
    getter: getWidth,
    fieldNumber: 3,
    fieldName: 'width',
    merger: PrimitiveMerger(),
  );
  static int? getHeight(MediaScan x) => x.height;
  static const height = ReadOnlyHiveFieldAdapter<MediaScan, int?>(
    getter: getHeight,
    fieldNumber: 4,
    fieldName: 'height',
    merger: PrimitiveMerger(),
  );
  static String? getCodec(MediaScan x) => x.codec;
  static const codec = ReadOnlyHiveFieldAdapter<MediaScan, String?>(
    getter: getCodec,
    fieldNumber: 5,
    fieldName: 'codec',
    merger: PrimitiveMerger(),
  );
  static double? getVideoFramerate(MediaScan x) => x.videoFramerate;
  static const videoFramerate = ReadOnlyHiveFieldAdapter<MediaScan, double?>(
    getter: getVideoFramerate,
    fieldNumber: 6,
    fieldName: 'videoFramerate',
    merger: PrimitiveMerger(),
  );
  static int? getSizeInBytes(MediaScan x) => x.sizeInBytes;
  static const sizeInBytes = ReadOnlyHiveFieldAdapter<MediaScan, int?>(
    getter: getSizeInBytes,
    fieldNumber: 7,
    fieldName: 'sizeInBytes',
    merger: PrimitiveMerger(),
  );
  static Map<dynamic, dynamic>? getMetadata(MediaScan x) => x.metadata;
  static const metadata =
      ReadOnlyHiveFieldAdapter<MediaScan, Map<dynamic, dynamic>?>(
    getter: getMetadata,
    fieldNumber: 8,
    fieldName: 'metadata',
    merger: MapEqualsMerger(),
  );
  static String? getFormat(MediaScan x) => x.format;
  static const format = ReadOnlyHiveFieldAdapter<MediaScan, String?>(
    getter: getFormat,
    fieldNumber: 9,
    fieldName: 'format',
    merger: PrimitiveMerger(),
  );
}

class MediaScanAdapter extends TypeAdapter<MediaScan> {
  const MediaScanAdapter();

  static const int kTypeId = 38;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<MediaScan, dynamic>> fields = const {
    0: MediaScanFields.hasAudio,
    1: MediaScanFields.duration,
    2: MediaScanFields.bitrate,
    3: MediaScanFields.width,
    4: MediaScanFields.height,
    5: MediaScanFields.codec,
    6: MediaScanFields.videoFramerate,
    7: MediaScanFields.sizeInBytes,
    8: MediaScanFields.metadata,
    9: MediaScanFields.format
  };

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
      metadata: (fields[8] as Map?)?.cast<dynamic, dynamic>(),
      format: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MediaScan obj) {
    writer
      ..writeByte(10)
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
      ..write(obj.sizeInBytes)
      ..writeByte(8)
      ..write(obj.metadata)
      ..writeByte(9)
      ..write(obj.format);
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

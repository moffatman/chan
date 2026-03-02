// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MediaScanFields {
  static bool getHasAudio(MediaScan x) => x.hasAudio;
  static const int kHasAudio = 0;
  static const hasAudio = ReadOnlyHiveFieldAdapter<MediaScan, bool>(
    getter: getHasAudio,
    fieldNumber: kHasAudio,
    fieldName: 'hasAudio',
    merger: PrimitiveMerger(),
  );
  static Duration? getDuration(MediaScan x) => x.duration;
  static const int kDuration = 1;
  static const duration = ReadOnlyHiveFieldAdapter<MediaScan, Duration?>(
    getter: getDuration,
    fieldNumber: kDuration,
    fieldName: 'duration',
    merger: NullableMerger(AdaptedMerger(DurationAdapter.kTypeId)),
  );
  static int? getBitrate(MediaScan x) => x.bitrate;
  static const int kBitrate = 2;
  static const bitrate = ReadOnlyHiveFieldAdapter<MediaScan, int?>(
    getter: getBitrate,
    fieldNumber: kBitrate,
    fieldName: 'bitrate',
    merger: PrimitiveMerger(),
  );
  static int? getWidth(MediaScan x) => x.width;
  static const int kWidth = 3;
  static const width = ReadOnlyHiveFieldAdapter<MediaScan, int?>(
    getter: getWidth,
    fieldNumber: kWidth,
    fieldName: 'width',
    merger: PrimitiveMerger(),
  );
  static int? getHeight(MediaScan x) => x.height;
  static const int kHeight = 4;
  static const height = ReadOnlyHiveFieldAdapter<MediaScan, int?>(
    getter: getHeight,
    fieldNumber: kHeight,
    fieldName: 'height',
    merger: PrimitiveMerger(),
  );
  static String? getCodec(MediaScan x) => x.codec;
  static const int kCodec = 5;
  static const codec = ReadOnlyHiveFieldAdapter<MediaScan, String?>(
    getter: getCodec,
    fieldNumber: kCodec,
    fieldName: 'codec',
    merger: PrimitiveMerger(),
  );
  static double? getVideoFramerate(MediaScan x) => x.videoFramerate;
  static const int kVideoFramerate = 6;
  static const videoFramerate = ReadOnlyHiveFieldAdapter<MediaScan, double?>(
    getter: getVideoFramerate,
    fieldNumber: kVideoFramerate,
    fieldName: 'videoFramerate',
    merger: PrimitiveMerger(),
  );
  static int? getSizeInBytes(MediaScan x) => x.sizeInBytes;
  static const int kSizeInBytes = 7;
  static const sizeInBytes = ReadOnlyHiveFieldAdapter<MediaScan, int?>(
    getter: getSizeInBytes,
    fieldNumber: kSizeInBytes,
    fieldName: 'sizeInBytes',
    merger: PrimitiveMerger(),
  );
  static Map<dynamic, dynamic>? getMetadata(MediaScan x) => x.metadata;
  static const int kMetadata = 8;
  static const metadata =
      ReadOnlyHiveFieldAdapter<MediaScan, Map<dynamic, dynamic>?>(
    getter: getMetadata,
    fieldNumber: kMetadata,
    fieldName: 'metadata',
    merger: MapEqualsMerger(),
  );
  static String? getFormat(MediaScan x) => x.format;
  static const int kFormat = 9;
  static const format = ReadOnlyHiveFieldAdapter<MediaScan, String?>(
    getter: getFormat,
    fieldNumber: kFormat,
    fieldName: 'format',
    merger: PrimitiveMerger(),
  );
  static String? getPixFmt(MediaScan x) => x.pixFmt;
  static const int kPixFmt = 10;
  static const pixFmt = ReadOnlyHiveFieldAdapter<MediaScan, String?>(
    getter: getPixFmt,
    fieldNumber: kPixFmt,
    fieldName: 'pixFmt',
    merger: PrimitiveMerger(),
  );
  static int? getVideoBitrate(MediaScan x) => x.videoBitrate;
  static const int kVideoBitrate = 11;
  static const videoBitrate = ReadOnlyHiveFieldAdapter<MediaScan, int?>(
    getter: getVideoBitrate,
    fieldNumber: kVideoBitrate,
    fieldName: 'videoBitrate',
    merger: PrimitiveMerger(),
  );
  static int? getAudioBitrate(MediaScan x) => x.audioBitrate;
  static const int kAudioBitrate = 12;
  static const audioBitrate = ReadOnlyHiveFieldAdapter<MediaScan, int?>(
    getter: getAudioBitrate,
    fieldNumber: kAudioBitrate,
    fieldName: 'audioBitrate',
    merger: PrimitiveMerger(),
  );
  static String? getForceFormat(MediaScan x) => x.forceFormat;
  static const int kForceFormat = 13;
  static const forceFormat = ReadOnlyHiveFieldAdapter<MediaScan, String?>(
    getter: getForceFormat,
    fieldNumber: kForceFormat,
    fieldName: 'forceFormat',
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
    9: MediaScanFields.format,
    10: MediaScanFields.pixFmt,
    11: MediaScanFields.videoBitrate,
    12: MediaScanFields.audioBitrate,
    13: MediaScanFields.forceFormat
  };

  @override
  MediaScan read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final List<dynamic> fields = List.filled(14, null);
    for (int i = 0; i < numOfFields; i++) {
      final int fieldId = reader.readByte();
      final dynamic value = reader.read();
      if (fieldId < fields.length) {
        fields[fieldId] = value;
      }
    }
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
      pixFmt: fields[10] as String?,
      videoBitrate: fields[11] as int?,
      audioBitrate: fields[12] as int?,
      forceFormat: fields[13] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MediaScan obj) {
    writer
      ..writeByte(14)
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
      ..write(obj.format)
      ..writeByte(10)
      ..write(obj.pixFmt)
      ..writeByte(11)
      ..write(obj.videoBitrate)
      ..writeByte(12)
      ..write(obj.audioBitrate)
      ..writeByte(13)
      ..write(obj.forceFormat);
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

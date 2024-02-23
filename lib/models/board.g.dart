// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'board.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ImageboardBoardFields {
  static String getName(ImageboardBoard x) => x.name;
  static const name = ReadOnlyHiveFieldAdapter<ImageboardBoard, String>(
    getter: getName,
    fieldNumber: 0,
    fieldName: 'name',
    merger: PrimitiveMerger(),
  );
  static String getTitle(ImageboardBoard x) => x.title;
  static const title = ReadOnlyHiveFieldAdapter<ImageboardBoard, String>(
    getter: getTitle,
    fieldNumber: 1,
    fieldName: 'title',
    merger: PrimitiveMerger(),
  );
  static bool getIsWorksafe(ImageboardBoard x) => x.isWorksafe;
  static const isWorksafe = ReadOnlyHiveFieldAdapter<ImageboardBoard, bool>(
    getter: getIsWorksafe,
    fieldNumber: 2,
    fieldName: 'isWorksafe',
    merger: PrimitiveMerger(),
  );
  static bool getWebmAudioAllowed(ImageboardBoard x) => x.webmAudioAllowed;
  static const webmAudioAllowed =
      ReadOnlyHiveFieldAdapter<ImageboardBoard, bool>(
    getter: getWebmAudioAllowed,
    fieldNumber: 3,
    fieldName: 'webmAudioAllowed',
    merger: PrimitiveMerger(),
  );
  static int? getMaxImageSizeBytes(ImageboardBoard x) => x.maxImageSizeBytes;
  static void setMaxImageSizeBytes(ImageboardBoard x, int? v) =>
      x.maxImageSizeBytes = v;
  static const maxImageSizeBytes = HiveFieldAdapter<ImageboardBoard, int?>(
    getter: getMaxImageSizeBytes,
    setter: setMaxImageSizeBytes,
    fieldNumber: 4,
    fieldName: 'maxImageSizeBytes',
    merger: PrimitiveMerger(),
  );
  static int? getMaxWebmSizeBytes(ImageboardBoard x) => x.maxWebmSizeBytes;
  static void setMaxWebmSizeBytes(ImageboardBoard x, int? v) =>
      x.maxWebmSizeBytes = v;
  static const maxWebmSizeBytes = HiveFieldAdapter<ImageboardBoard, int?>(
    getter: getMaxWebmSizeBytes,
    setter: setMaxWebmSizeBytes,
    fieldNumber: 5,
    fieldName: 'maxWebmSizeBytes',
    merger: PrimitiveMerger(),
  );
  static int? getMaxWebmDurationSeconds(ImageboardBoard x) =>
      x.maxWebmDurationSeconds;
  static const maxWebmDurationSeconds =
      ReadOnlyHiveFieldAdapter<ImageboardBoard, int?>(
    getter: getMaxWebmDurationSeconds,
    fieldNumber: 6,
    fieldName: 'maxWebmDurationSeconds',
    merger: PrimitiveMerger(),
  );
  static int? getMaxCommentCharacters(ImageboardBoard x) =>
      x.maxCommentCharacters;
  static void setMaxCommentCharacters(ImageboardBoard x, int? v) =>
      x.maxCommentCharacters = v;
  static const maxCommentCharacters = HiveFieldAdapter<ImageboardBoard, int?>(
    getter: getMaxCommentCharacters,
    setter: setMaxCommentCharacters,
    fieldNumber: 7,
    fieldName: 'maxCommentCharacters',
    merger: PrimitiveMerger(),
  );
  static int? getThreadCommentLimit(ImageboardBoard x) => x.threadCommentLimit;
  static void setThreadCommentLimit(ImageboardBoard x, int? v) =>
      x.threadCommentLimit = v;
  static const threadCommentLimit = HiveFieldAdapter<ImageboardBoard, int?>(
    getter: getThreadCommentLimit,
    setter: setThreadCommentLimit,
    fieldNumber: 8,
    fieldName: 'threadCommentLimit',
    merger: PrimitiveMerger(),
  );
  static int? getThreadImageLimit(ImageboardBoard x) => x.threadImageLimit;
  static const threadImageLimit =
      ReadOnlyHiveFieldAdapter<ImageboardBoard, int?>(
    getter: getThreadImageLimit,
    fieldNumber: 9,
    fieldName: 'threadImageLimit',
    merger: PrimitiveMerger(),
  );
  static int? getPageCount(ImageboardBoard x) => x.pageCount;
  static void setPageCount(ImageboardBoard x, int? v) => x.pageCount = v;
  static const pageCount = HiveFieldAdapter<ImageboardBoard, int?>(
    getter: getPageCount,
    setter: setPageCount,
    fieldNumber: 10,
    fieldName: 'pageCount',
    merger: PrimitiveMerger(),
  );
  static int? getThreadCooldown(ImageboardBoard x) => x.threadCooldown;
  static const threadCooldown = ReadOnlyHiveFieldAdapter<ImageboardBoard, int?>(
    getter: getThreadCooldown,
    fieldNumber: 11,
    fieldName: 'threadCooldown',
    merger: PrimitiveMerger(),
  );
  static int? getReplyCooldown(ImageboardBoard x) => x.replyCooldown;
  static const replyCooldown = ReadOnlyHiveFieldAdapter<ImageboardBoard, int?>(
    getter: getReplyCooldown,
    fieldNumber: 12,
    fieldName: 'replyCooldown',
    merger: PrimitiveMerger(),
  );
  static int? getImageCooldown(ImageboardBoard x) => x.imageCooldown;
  static const imageCooldown = ReadOnlyHiveFieldAdapter<ImageboardBoard, int?>(
    getter: getImageCooldown,
    fieldNumber: 13,
    fieldName: 'imageCooldown',
    merger: PrimitiveMerger(),
  );
  static bool? getSpoilers(ImageboardBoard x) => x.spoilers;
  static const spoilers = ReadOnlyHiveFieldAdapter<ImageboardBoard, bool?>(
    getter: getSpoilers,
    fieldNumber: 14,
    fieldName: 'spoilers',
    merger: PrimitiveMerger(),
  );
  static DateTime? getAdditionalDataTime(ImageboardBoard x) =>
      x.additionalDataTime;
  static void setAdditionalDataTime(ImageboardBoard x, DateTime? v) =>
      x.additionalDataTime = v;
  static const additionalDataTime =
      HiveFieldAdapter<ImageboardBoard, DateTime?>(
    getter: getAdditionalDataTime,
    setter: setAdditionalDataTime,
    fieldNumber: 15,
    fieldName: 'additionalDataTime',
    merger: PrimitiveMerger(),
  );
  static String? getSubdomain(ImageboardBoard x) => x.subdomain;
  static const subdomain = ReadOnlyHiveFieldAdapter<ImageboardBoard, String?>(
    getter: getSubdomain,
    fieldNumber: 16,
    fieldName: 'subdomain',
    merger: PrimitiveMerger(),
  );
  static Uri? getIcon(ImageboardBoard x) => x.icon;
  static const icon = ReadOnlyHiveFieldAdapter<ImageboardBoard, Uri?>(
    getter: getIcon,
    fieldNumber: 17,
    fieldName: 'icon',
    merger: NullableMerger(AdaptedMerger(UriAdapter.kTypeId)),
  );
  static int? getCaptchaMode(ImageboardBoard x) => x.captchaMode;
  static void setCaptchaMode(ImageboardBoard x, int? v) => x.captchaMode = v;
  static const captchaMode = HiveFieldAdapter<ImageboardBoard, int?>(
    getter: getCaptchaMode,
    setter: setCaptchaMode,
    fieldNumber: 18,
    fieldName: 'captchaMode',
    merger: PrimitiveMerger(),
  );
}

class ImageboardBoardAdapter extends TypeAdapter<ImageboardBoard> {
  const ImageboardBoardAdapter();

  static const int kTypeId = 16;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<ImageboardBoard, dynamic>> fields =
      const {
    0: ImageboardBoardFields.name,
    1: ImageboardBoardFields.title,
    2: ImageboardBoardFields.isWorksafe,
    3: ImageboardBoardFields.webmAudioAllowed,
    4: ImageboardBoardFields.maxImageSizeBytes,
    5: ImageboardBoardFields.maxWebmSizeBytes,
    6: ImageboardBoardFields.maxWebmDurationSeconds,
    7: ImageboardBoardFields.maxCommentCharacters,
    8: ImageboardBoardFields.threadCommentLimit,
    9: ImageboardBoardFields.threadImageLimit,
    10: ImageboardBoardFields.pageCount,
    11: ImageboardBoardFields.threadCooldown,
    12: ImageboardBoardFields.replyCooldown,
    13: ImageboardBoardFields.imageCooldown,
    14: ImageboardBoardFields.spoilers,
    15: ImageboardBoardFields.additionalDataTime,
    16: ImageboardBoardFields.subdomain,
    17: ImageboardBoardFields.icon,
    18: ImageboardBoardFields.captchaMode
  };

  @override
  ImageboardBoard read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final Map<int, dynamic> fields;
    if (numOfFields == 255) {
      // Dynamic number of fields
      fields = {};
      while (true) {
        final int fieldId = reader.readByte();
        fields[fieldId] = reader.read();
        if (fieldId == 0) {
          break;
        }
      }
    } else {
      fields = <int, dynamic>{
        for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
      };
    }
    return ImageboardBoard(
      name: fields[0] as String,
      title: fields[1] as String,
      isWorksafe: fields[2] as bool,
      webmAudioAllowed: fields[3] as bool,
      maxImageSizeBytes: fields[4] as int?,
      maxWebmSizeBytes: fields[5] as int?,
      maxWebmDurationSeconds: fields[6] as int?,
      maxCommentCharacters: fields[7] as int?,
      threadCommentLimit: fields[8] as int?,
      threadImageLimit: fields[9] as int?,
      pageCount: fields[10] as int?,
      threadCooldown: fields[11] as int?,
      replyCooldown: fields[12] as int?,
      imageCooldown: fields[13] as int?,
      spoilers: fields[14] as bool?,
      additionalDataTime: fields[15] as DateTime?,
      subdomain: fields[16] as String?,
      icon: fields[17] as Uri?,
      captchaMode: fields[18] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, ImageboardBoard obj) {
    final Map<int, dynamic> fields = {
      0: obj.name,
      1: obj.title,
      2: obj.isWorksafe,
      3: obj.webmAudioAllowed,
      if (obj.maxImageSizeBytes != null) 4: obj.maxImageSizeBytes,
      if (obj.maxWebmSizeBytes != null) 5: obj.maxWebmSizeBytes,
      if (obj.maxWebmDurationSeconds != null) 6: obj.maxWebmDurationSeconds,
      if (obj.maxCommentCharacters != null) 7: obj.maxCommentCharacters,
      if (obj.threadCommentLimit != null) 8: obj.threadCommentLimit,
      if (obj.threadImageLimit != null) 9: obj.threadImageLimit,
      if (obj.pageCount != null) 10: obj.pageCount,
      if (obj.threadCooldown != null) 11: obj.threadCooldown,
      if (obj.replyCooldown != null) 12: obj.replyCooldown,
      if (obj.imageCooldown != null) 13: obj.imageCooldown,
      if (obj.spoilers != null) 14: obj.spoilers,
      if (obj.additionalDataTime != null) 15: obj.additionalDataTime,
      if (obj.subdomain != null) 16: obj.subdomain,
      if (obj.icon != null) 17: obj.icon,
      if (obj.captchaMode != null) 18: obj.captchaMode,
    };
    writer.writeByte(fields.length);
    for (final MapEntry<int, dynamic> entry in fields.entries) {
      writer
        ..writeByte(entry.key)
        ..write(entry.value);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageboardBoardAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'board.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ImageboardBoardFields {
  static String getName(ImageboardBoard x) => x.name;
  static const int kName = 0;
  static const name = ReadOnlyHiveFieldAdapter<ImageboardBoard, String>(
    getter: getName,
    fieldNumber: kName,
    fieldName: 'name',
    merger: PrimitiveMerger(),
  );
  static String getTitle(ImageboardBoard x) => x.title;
  static const int kTitle = 1;
  static const title = ReadOnlyHiveFieldAdapter<ImageboardBoard, String>(
    getter: getTitle,
    fieldNumber: kTitle,
    fieldName: 'title',
    merger: PrimitiveMerger(),
  );
  static bool getIsWorksafe(ImageboardBoard x) => x.isWorksafe;
  static const int kIsWorksafe = 2;
  static const isWorksafe = ReadOnlyHiveFieldAdapter<ImageboardBoard, bool>(
    getter: getIsWorksafe,
    fieldNumber: kIsWorksafe,
    fieldName: 'isWorksafe',
    merger: PrimitiveMerger(),
  );
  static bool getWebmAudioAllowed(ImageboardBoard x) => x.webmAudioAllowed;
  static const int kWebmAudioAllowed = 3;
  static const webmAudioAllowed =
      ReadOnlyHiveFieldAdapter<ImageboardBoard, bool>(
    getter: getWebmAudioAllowed,
    fieldNumber: kWebmAudioAllowed,
    fieldName: 'webmAudioAllowed',
    merger: PrimitiveMerger(),
  );
  static int? getMaxImageSizeBytes(ImageboardBoard x) => x.maxImageSizeBytes;
  static void setMaxImageSizeBytes(ImageboardBoard x, int? v) =>
      x.maxImageSizeBytes = v;
  static const int kMaxImageSizeBytes = 4;
  static const maxImageSizeBytes = HiveFieldAdapter<ImageboardBoard, int?>(
    getter: getMaxImageSizeBytes,
    setter: setMaxImageSizeBytes,
    fieldNumber: kMaxImageSizeBytes,
    fieldName: 'maxImageSizeBytes',
    merger: PrimitiveMerger(),
  );
  static int? getMaxWebmSizeBytes(ImageboardBoard x) => x.maxWebmSizeBytes;
  static void setMaxWebmSizeBytes(ImageboardBoard x, int? v) =>
      x.maxWebmSizeBytes = v;
  static const int kMaxWebmSizeBytes = 5;
  static const maxWebmSizeBytes = HiveFieldAdapter<ImageboardBoard, int?>(
    getter: getMaxWebmSizeBytes,
    setter: setMaxWebmSizeBytes,
    fieldNumber: kMaxWebmSizeBytes,
    fieldName: 'maxWebmSizeBytes',
    merger: PrimitiveMerger(),
  );
  static int? getMaxWebmDurationSeconds(ImageboardBoard x) =>
      x.maxWebmDurationSeconds;
  static const int kMaxWebmDurationSeconds = 6;
  static const maxWebmDurationSeconds =
      ReadOnlyHiveFieldAdapter<ImageboardBoard, int?>(
    getter: getMaxWebmDurationSeconds,
    fieldNumber: kMaxWebmDurationSeconds,
    fieldName: 'maxWebmDurationSeconds',
    merger: PrimitiveMerger(),
  );
  static int? getMaxCommentCharacters(ImageboardBoard x) =>
      x.maxCommentCharacters;
  static void setMaxCommentCharacters(ImageboardBoard x, int? v) =>
      x.maxCommentCharacters = v;
  static const int kMaxCommentCharacters = 7;
  static const maxCommentCharacters = HiveFieldAdapter<ImageboardBoard, int?>(
    getter: getMaxCommentCharacters,
    setter: setMaxCommentCharacters,
    fieldNumber: kMaxCommentCharacters,
    fieldName: 'maxCommentCharacters',
    merger: PrimitiveMerger(),
  );
  static int? getThreadCommentLimit(ImageboardBoard x) => x.threadCommentLimit;
  static void setThreadCommentLimit(ImageboardBoard x, int? v) =>
      x.threadCommentLimit = v;
  static const int kThreadCommentLimit = 8;
  static const threadCommentLimit = HiveFieldAdapter<ImageboardBoard, int?>(
    getter: getThreadCommentLimit,
    setter: setThreadCommentLimit,
    fieldNumber: kThreadCommentLimit,
    fieldName: 'threadCommentLimit',
    merger: PrimitiveMerger(),
  );
  static int? getThreadImageLimit(ImageboardBoard x) => x.threadImageLimit;
  static const int kThreadImageLimit = 9;
  static const threadImageLimit =
      ReadOnlyHiveFieldAdapter<ImageboardBoard, int?>(
    getter: getThreadImageLimit,
    fieldNumber: kThreadImageLimit,
    fieldName: 'threadImageLimit',
    merger: PrimitiveMerger(),
  );
  static int? getPageCount(ImageboardBoard x) => x.pageCount;
  static void setPageCount(ImageboardBoard x, int? v) => x.pageCount = v;
  static const int kPageCount = 10;
  static const pageCount = HiveFieldAdapter<ImageboardBoard, int?>(
    getter: getPageCount,
    setter: setPageCount,
    fieldNumber: kPageCount,
    fieldName: 'pageCount',
    merger: PrimitiveMerger(),
  );
  static int? getThreadCooldown(ImageboardBoard x) => x.threadCooldown;
  static const int kThreadCooldown = 11;
  static const threadCooldown = ReadOnlyHiveFieldAdapter<ImageboardBoard, int?>(
    getter: getThreadCooldown,
    fieldNumber: kThreadCooldown,
    fieldName: 'threadCooldown',
    merger: PrimitiveMerger(),
  );
  static int? getReplyCooldown(ImageboardBoard x) => x.replyCooldown;
  static const int kReplyCooldown = 12;
  static const replyCooldown = ReadOnlyHiveFieldAdapter<ImageboardBoard, int?>(
    getter: getReplyCooldown,
    fieldNumber: kReplyCooldown,
    fieldName: 'replyCooldown',
    merger: PrimitiveMerger(),
  );
  static int? getImageCooldown(ImageboardBoard x) => x.imageCooldown;
  static const int kImageCooldown = 13;
  static const imageCooldown = ReadOnlyHiveFieldAdapter<ImageboardBoard, int?>(
    getter: getImageCooldown,
    fieldNumber: kImageCooldown,
    fieldName: 'imageCooldown',
    merger: PrimitiveMerger(),
  );
  static bool? getSpoilers(ImageboardBoard x) => x.spoilers;
  static const int kSpoilers = 14;
  static const spoilers = ReadOnlyHiveFieldAdapter<ImageboardBoard, bool?>(
    getter: getSpoilers,
    fieldNumber: kSpoilers,
    fieldName: 'spoilers',
    merger: PrimitiveMerger(),
  );
  static DateTime? getAdditionalDataTime(ImageboardBoard x) =>
      x.additionalDataTime;
  static void setAdditionalDataTime(ImageboardBoard x, DateTime? v) =>
      x.additionalDataTime = v;
  static const int kAdditionalDataTime = 15;
  static const additionalDataTime =
      HiveFieldAdapter<ImageboardBoard, DateTime?>(
    getter: getAdditionalDataTime,
    setter: setAdditionalDataTime,
    fieldNumber: kAdditionalDataTime,
    fieldName: 'additionalDataTime',
    merger: PrimitiveMerger(),
  );
  static String? getSubdomain(ImageboardBoard x) => x.subdomain;
  static const int kSubdomain = 16;
  static const subdomain = ReadOnlyHiveFieldAdapter<ImageboardBoard, String?>(
    getter: getSubdomain,
    fieldNumber: kSubdomain,
    fieldName: 'subdomain',
    merger: PrimitiveMerger(),
  );
  static Uri? getIcon(ImageboardBoard x) => x.icon;
  static const int kIcon = 17;
  static const icon = ReadOnlyHiveFieldAdapter<ImageboardBoard, Uri?>(
    getter: getIcon,
    fieldNumber: kIcon,
    fieldName: 'icon',
    merger: NullableMerger(AdaptedMerger(UriAdapter.kTypeId)),
  );
  static int? getCaptchaMode(ImageboardBoard x) => x.captchaMode;
  static void setCaptchaMode(ImageboardBoard x, int? v) => x.captchaMode = v;
  static const int kCaptchaMode = 18;
  static const captchaMode = HiveFieldAdapter<ImageboardBoard, int?>(
    getter: getCaptchaMode,
    setter: setCaptchaMode,
    fieldNumber: kCaptchaMode,
    fieldName: 'captchaMode',
    merger: PrimitiveMerger(),
  );
  static int? getPopularity(ImageboardBoard x) => x.popularity;
  static const int kPopularity = 19;
  static const popularity = ReadOnlyHiveFieldAdapter<ImageboardBoard, int?>(
    getter: getPopularity,
    fieldNumber: kPopularity,
    fieldName: 'popularity',
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
    18: ImageboardBoardFields.captchaMode,
    19: ImageboardBoardFields.popularity
  };

  @override
  ImageboardBoard read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final List<dynamic> fields = List.filled(20, null);
    if (numOfFields == 255) {
      // Dynamic number of fields
      while (true) {
        final int fieldId = reader.readByte();
        final dynamic value = reader.read();
        if (fieldId < fields.length) {
          fields[fieldId] = value;
        }
        if (fieldId == 0) {
          break;
        }
      }
    } else {
      for (int i = 0; i < numOfFields; i++) {
        final int fieldId = reader.readByte();
        final dynamic value = reader.read();
        if (fieldId < fields.length) {
          fields[fieldId] = value;
        }
      }
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
      popularity: fields[19] as int?,
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
      if (obj.popularity != null) 19: obj.popularity,
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

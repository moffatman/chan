// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AttachmentFields {
  static String getBoard(Attachment x) => x.board;
  static const int kBoard = 0;
  static const board = ReadOnlyHiveFieldAdapter<Attachment, String>(
    getter: getBoard,
    fieldNumber: kBoard,
    fieldName: 'board',
    merger: PrimitiveMerger(),
  );
  static String getExt(Attachment x) => x.ext;
  static const int kExt = 2;
  static const ext = ReadOnlyHiveFieldAdapter<Attachment, String>(
    getter: getExt,
    fieldNumber: kExt,
    fieldName: 'ext',
    merger: PrimitiveMerger(),
  );
  static String getFilename(Attachment x) => x.filename;
  static void setFilename(Attachment x, String v) => x.filename = v;
  static const int kFilename = 3;
  static const filename = HiveFieldAdapter<Attachment, String>(
    getter: getFilename,
    setter: setFilename,
    fieldNumber: kFilename,
    fieldName: 'filename',
    merger: PrimitiveMerger(),
  );
  static AttachmentType getType(Attachment x) => x.type;
  static const int kType = 4;
  static const type = ReadOnlyHiveFieldAdapter<Attachment, AttachmentType>(
    getter: getType,
    fieldNumber: kType,
    fieldName: 'type',
    merger: PrimitiveMerger(),
  );
  static String getUrl(Attachment x) => x.url;
  static const int kUrl = 5;
  static const url = ReadOnlyHiveFieldAdapter<Attachment, String>(
    getter: getUrl,
    fieldNumber: kUrl,
    fieldName: 'url',
    merger: PrimitiveMerger(),
  );
  static String getThumbnailUrl(Attachment x) => x.thumbnailUrl;
  static void setThumbnailUrl(Attachment x, String v) => x.thumbnailUrl = v;
  static const int kThumbnailUrl = 6;
  static const thumbnailUrl = HiveFieldAdapter<Attachment, String>(
    getter: getThumbnailUrl,
    setter: setThumbnailUrl,
    fieldNumber: kThumbnailUrl,
    fieldName: 'thumbnailUrl',
    merger: PrimitiveMerger(),
  );
  static String getMd5(Attachment x) => x.md5;
  static const int kMd5 = 7;
  static const md5 = ReadOnlyHiveFieldAdapter<Attachment, String>(
    getter: getMd5,
    fieldNumber: kMd5,
    fieldName: 'md5',
    merger: PrimitiveMerger(),
  );
  static bool getSpoiler(Attachment x) => x.spoiler;
  static const int kSpoiler = 8;
  static const spoiler = ReadOnlyHiveFieldAdapter<Attachment, bool>(
    getter: getSpoiler,
    fieldNumber: kSpoiler,
    fieldName: 'spoiler',
    merger: PrimitiveMerger(),
  );
  static int? getWidth(Attachment x) => x.width;
  static void setWidth(Attachment x, int? v) => x.width = v;
  static const int kWidth = 9;
  static const width = HiveFieldAdapter<Attachment, int?>(
    getter: getWidth,
    setter: setWidth,
    fieldNumber: kWidth,
    fieldName: 'width',
    merger: PrimitiveMerger(),
  );
  static int? getHeight(Attachment x) => x.height;
  static void setHeight(Attachment x, int? v) => x.height = v;
  static const int kHeight = 10;
  static const height = HiveFieldAdapter<Attachment, int?>(
    getter: getHeight,
    setter: setHeight,
    fieldNumber: kHeight,
    fieldName: 'height',
    merger: PrimitiveMerger(),
  );
  static int? getThreadId(Attachment x) => x.threadId;
  static const int kThreadId = 11;
  static const threadId = ReadOnlyHiveFieldAdapter<Attachment, int?>(
    getter: getThreadId,
    fieldNumber: kThreadId,
    fieldName: 'threadId',
    merger: PrimitiveMerger(),
  );
  static int? getSizeInBytes(Attachment x) => x.sizeInBytes;
  static void setSizeInBytes(Attachment x, int? v) => x.sizeInBytes = v;
  static const int kSizeInBytes = 12;
  static const sizeInBytes = HiveFieldAdapter<Attachment, int?>(
    getter: getSizeInBytes,
    setter: setSizeInBytes,
    fieldNumber: kSizeInBytes,
    fieldName: 'sizeInBytes',
    merger: PrimitiveMerger(),
  );
  static String getId(Attachment x) => x.id;
  static const int kId = 13;
  static const id = ReadOnlyHiveFieldAdapter<Attachment, String>(
    getter: getId,
    fieldNumber: kId,
    fieldName: 'id',
    merger: PrimitiveMerger(),
  );
  static bool getUseRandomUseragent(Attachment x) => x.useRandomUseragent;
  static const int kUseRandomUseragent = 14;
  static const useRandomUseragent = ReadOnlyHiveFieldAdapter<Attachment, bool>(
    getter: getUseRandomUseragent,
    fieldNumber: kUseRandomUseragent,
    fieldName: 'useRandomUseragent',
    merger: PrimitiveMerger(),
  );
  static bool getIsRateLimited(Attachment x) => x.isRateLimited;
  static const int kIsRateLimited = 15;
  static const isRateLimited = ReadOnlyHiveFieldAdapter<Attachment, bool>(
    getter: getIsRateLimited,
    fieldNumber: kIsRateLimited,
    fieldName: 'isRateLimited',
    merger: PrimitiveMerger(),
  );
}

class AttachmentAdapter extends TypeAdapter<Attachment> {
  const AttachmentAdapter();

  static const int kTypeId = 9;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<Attachment, dynamic>> fields = const {
    0: AttachmentFields.board,
    2: AttachmentFields.ext,
    3: AttachmentFields.filename,
    4: AttachmentFields.type,
    5: AttachmentFields.url,
    6: AttachmentFields.thumbnailUrl,
    7: AttachmentFields.md5,
    8: AttachmentFields.spoiler,
    9: AttachmentFields.width,
    10: AttachmentFields.height,
    11: AttachmentFields.threadId,
    12: AttachmentFields.sizeInBytes,
    13: AttachmentFields.id,
    14: AttachmentFields.useRandomUseragent,
    15: AttachmentFields.isRateLimited
  };

  @override
  Attachment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final List<dynamic> fields = List.filled(16, null);
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
    _readHookAttachmentFields(fields);
    return Attachment(
      type: fields[4] as AttachmentType,
      board: fields[0] as String,
      id: fields[13] as String,
      ext: fields[2] as String,
      filename: fields[3] as String,
      url: fields[5] as String,
      thumbnailUrl: fields[6] as String,
      md5: fields[7] as String,
      spoiler: fields[8] == null ? false : fields[8] as bool,
      width: fields[9] as int?,
      height: fields[10] as int?,
      threadId: fields[11] as int?,
      sizeInBytes: fields[12] as int?,
      useRandomUseragent: fields[14] == null ? false : fields[14] as bool,
      isRateLimited: fields[15] == null ? false : fields[15] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Attachment obj) {
    final Map<int, dynamic> fields = {
      0: obj.board,
      2: obj.ext,
      3: obj.filename,
      4: obj.type,
      5: obj.url,
      6: obj.thumbnailUrl,
      7: obj.md5,
      if (obj.spoiler) 8: obj.spoiler,
      if (obj.width != null) 9: obj.width,
      if (obj.height != null) 10: obj.height,
      if (obj.threadId != null) 11: obj.threadId,
      if (obj.sizeInBytes != null) 12: obj.sizeInBytes,
      13: obj.id,
      if (obj.useRandomUseragent) 14: obj.useRandomUseragent,
      if (obj.isRateLimited) 15: obj.isRateLimited,
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
      other is AttachmentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AttachmentTypeAdapter extends TypeAdapter<AttachmentType> {
  const AttachmentTypeAdapter();

  static const int kTypeId = 10;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<AttachmentType, dynamic>> fields =
      const {};

  @override
  AttachmentType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AttachmentType.image;
      case 1:
        return AttachmentType.webm;
      case 2:
        return AttachmentType.mp4;
      case 3:
        return AttachmentType.mp3;
      case 4:
        return AttachmentType.pdf;
      case 5:
        return AttachmentType.url;
      case 6:
        return AttachmentType.swf;
      default:
        return AttachmentType.image;
    }
  }

  @override
  void write(BinaryWriter writer, AttachmentType obj) {
    switch (obj) {
      case AttachmentType.image:
        writer.writeByte(0);
        break;
      case AttachmentType.webm:
        writer.writeByte(1);
        break;
      case AttachmentType.mp4:
        writer.writeByte(2);
        break;
      case AttachmentType.mp3:
        writer.writeByte(3);
        break;
      case AttachmentType.pdf:
        writer.writeByte(4);
        break;
      case AttachmentType.url:
        writer.writeByte(5);
        break;
      case AttachmentType.swf:
        writer.writeByte(6);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttachmentTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

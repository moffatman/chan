// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ImageboardArchiveSearchQueryFields {
  static String getQuery(ImageboardArchiveSearchQuery x) => x.query;
  static void setQuery(ImageboardArchiveSearchQuery x, String v) => x.query = v;
  static const query = HiveFieldAdapter<ImageboardArchiveSearchQuery, String>(
    getter: getQuery,
    setter: setQuery,
    fieldNumber: 0,
    fieldName: 'query',
    merger: PrimitiveMerger(),
  );
  static MediaFilter getMediaFilter(ImageboardArchiveSearchQuery x) =>
      x.mediaFilter;
  static void setMediaFilter(ImageboardArchiveSearchQuery x, MediaFilter v) =>
      x.mediaFilter = v;
  static const mediaFilter =
      HiveFieldAdapter<ImageboardArchiveSearchQuery, MediaFilter>(
    getter: getMediaFilter,
    setter: setMediaFilter,
    fieldNumber: 1,
    fieldName: 'mediaFilter',
    merger: PrimitiveMerger(),
  );
  static PostTypeFilter getPostTypeFilter(ImageboardArchiveSearchQuery x) =>
      x.postTypeFilter;
  static void setPostTypeFilter(
          ImageboardArchiveSearchQuery x, PostTypeFilter v) =>
      x.postTypeFilter = v;
  static const postTypeFilter =
      HiveFieldAdapter<ImageboardArchiveSearchQuery, PostTypeFilter>(
    getter: getPostTypeFilter,
    setter: setPostTypeFilter,
    fieldNumber: 2,
    fieldName: 'postTypeFilter',
    merger: PrimitiveMerger(),
  );
  static DateTime? getStartDate(ImageboardArchiveSearchQuery x) => x.startDate;
  static void setStartDate(ImageboardArchiveSearchQuery x, DateTime? v) =>
      x.startDate = v;
  static const startDate =
      HiveFieldAdapter<ImageboardArchiveSearchQuery, DateTime?>(
    getter: getStartDate,
    setter: setStartDate,
    fieldNumber: 3,
    fieldName: 'startDate',
    merger: PrimitiveMerger(),
  );
  static DateTime? getEndDate(ImageboardArchiveSearchQuery x) => x.endDate;
  static void setEndDate(ImageboardArchiveSearchQuery x, DateTime? v) =>
      x.endDate = v;
  static const endDate =
      HiveFieldAdapter<ImageboardArchiveSearchQuery, DateTime?>(
    getter: getEndDate,
    setter: setEndDate,
    fieldNumber: 4,
    fieldName: 'endDate',
    merger: PrimitiveMerger(),
  );
  static List<String> getBoards(ImageboardArchiveSearchQuery x) => x.boards;
  static void setBoards(ImageboardArchiveSearchQuery x, List<String> v) =>
      x.boards = v;
  static const boards =
      HiveFieldAdapter<ImageboardArchiveSearchQuery, List<String>>(
    getter: getBoards,
    setter: setBoards,
    fieldNumber: 5,
    fieldName: 'boards',
    merger: SetLikePrimitiveListMerger<String>(),
  );
  static String? getMd5(ImageboardArchiveSearchQuery x) => x.md5;
  static void setMd5(ImageboardArchiveSearchQuery x, String? v) => x.md5 = v;
  static const md5 = HiveFieldAdapter<ImageboardArchiveSearchQuery, String?>(
    getter: getMd5,
    setter: setMd5,
    fieldNumber: 6,
    fieldName: 'md5',
    merger: PrimitiveMerger(),
  );
  static PostDeletionStatusFilter getDeletionStatusFilter(
          ImageboardArchiveSearchQuery x) =>
      x.deletionStatusFilter;
  static void setDeletionStatusFilter(
          ImageboardArchiveSearchQuery x, PostDeletionStatusFilter v) =>
      x.deletionStatusFilter = v;
  static const deletionStatusFilter =
      HiveFieldAdapter<ImageboardArchiveSearchQuery, PostDeletionStatusFilter>(
    getter: getDeletionStatusFilter,
    setter: setDeletionStatusFilter,
    fieldNumber: 7,
    fieldName: 'deletionStatusFilter',
    merger: PrimitiveMerger(),
  );
  static String? getImageboardKey(ImageboardArchiveSearchQuery x) =>
      x.imageboardKey;
  static void setImageboardKey(ImageboardArchiveSearchQuery x, String? v) =>
      x.imageboardKey = v;
  static const imageboardKey =
      HiveFieldAdapter<ImageboardArchiveSearchQuery, String?>(
    getter: getImageboardKey,
    setter: setImageboardKey,
    fieldNumber: 8,
    fieldName: 'imageboardKey',
    merger: PrimitiveMerger(),
  );
  static String? getName(ImageboardArchiveSearchQuery x) => x.name;
  static void setName(ImageboardArchiveSearchQuery x, String? v) => x.name = v;
  static const name = HiveFieldAdapter<ImageboardArchiveSearchQuery, String?>(
    getter: getName,
    setter: setName,
    fieldNumber: 9,
    fieldName: 'name',
    merger: PrimitiveMerger(),
  );
  static String? getTrip(ImageboardArchiveSearchQuery x) => x.trip;
  static void setTrip(ImageboardArchiveSearchQuery x, String? v) => x.trip = v;
  static const trip = HiveFieldAdapter<ImageboardArchiveSearchQuery, String?>(
    getter: getTrip,
    setter: setTrip,
    fieldNumber: 10,
    fieldName: 'trip',
    merger: PrimitiveMerger(),
  );
  static String? getSubject(ImageboardArchiveSearchQuery x) => x.subject;
  static void setSubject(ImageboardArchiveSearchQuery x, String? v) =>
      x.subject = v;
  static const subject =
      HiveFieldAdapter<ImageboardArchiveSearchQuery, String?>(
    getter: getSubject,
    setter: setSubject,
    fieldNumber: 11,
    fieldName: 'subject',
    merger: PrimitiveMerger(),
  );
}

class ImageboardArchiveSearchQueryAdapter
    extends TypeAdapter<ImageboardArchiveSearchQuery> {
  const ImageboardArchiveSearchQueryAdapter();

  static const int kTypeId = 5;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int,
          ReadOnlyHiveFieldAdapter<ImageboardArchiveSearchQuery, dynamic>>
      fields = const {
    0: ImageboardArchiveSearchQueryFields.query,
    1: ImageboardArchiveSearchQueryFields.mediaFilter,
    2: ImageboardArchiveSearchQueryFields.postTypeFilter,
    3: ImageboardArchiveSearchQueryFields.startDate,
    4: ImageboardArchiveSearchQueryFields.endDate,
    5: ImageboardArchiveSearchQueryFields.boards,
    6: ImageboardArchiveSearchQueryFields.md5,
    7: ImageboardArchiveSearchQueryFields.deletionStatusFilter,
    8: ImageboardArchiveSearchQueryFields.imageboardKey,
    9: ImageboardArchiveSearchQueryFields.name,
    10: ImageboardArchiveSearchQueryFields.trip,
    11: ImageboardArchiveSearchQueryFields.subject
  };

  @override
  ImageboardArchiveSearchQuery read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ImageboardArchiveSearchQuery(
      query: fields[0] as String,
      mediaFilter: fields[1] as MediaFilter,
      postTypeFilter: fields[2] as PostTypeFilter,
      startDate: fields[3] as DateTime?,
      endDate: fields[4] as DateTime?,
      boards: (fields[5] as List?)?.cast<String>(),
      md5: fields[6] as String?,
      deletionStatusFilter: fields[7] == null
          ? PostDeletionStatusFilter.none
          : fields[7] as PostDeletionStatusFilter,
      imageboardKey: fields[8] as String?,
      name: fields[9] as String?,
      trip: fields[10] as String?,
      subject: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ImageboardArchiveSearchQuery obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.query)
      ..writeByte(1)
      ..write(obj.mediaFilter)
      ..writeByte(2)
      ..write(obj.postTypeFilter)
      ..writeByte(3)
      ..write(obj.startDate)
      ..writeByte(4)
      ..write(obj.endDate)
      ..writeByte(5)
      ..write(obj.boards)
      ..writeByte(6)
      ..write(obj.md5)
      ..writeByte(7)
      ..write(obj.deletionStatusFilter)
      ..writeByte(8)
      ..write(obj.imageboardKey)
      ..writeByte(9)
      ..write(obj.name)
      ..writeByte(10)
      ..write(obj.trip)
      ..writeByte(11)
      ..write(obj.subject);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageboardArchiveSearchQueryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PostTypeFilterAdapter extends TypeAdapter<PostTypeFilter> {
  const PostTypeFilterAdapter();

  static const int kTypeId = 6;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<PostTypeFilter, dynamic>> fields =
      const {};

  @override
  PostTypeFilter read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PostTypeFilter.none;
      case 1:
        return PostTypeFilter.onlyOPs;
      case 2:
        return PostTypeFilter.onlyReplies;
      case 3:
        return PostTypeFilter.onlyStickies;
      default:
        return PostTypeFilter.none;
    }
  }

  @override
  void write(BinaryWriter writer, PostTypeFilter obj) {
    switch (obj) {
      case PostTypeFilter.none:
        writer.writeByte(0);
        break;
      case PostTypeFilter.onlyOPs:
        writer.writeByte(1);
        break;
      case PostTypeFilter.onlyReplies:
        writer.writeByte(2);
        break;
      case PostTypeFilter.onlyStickies:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostTypeFilterAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MediaFilterAdapter extends TypeAdapter<MediaFilter> {
  const MediaFilterAdapter();

  static const int kTypeId = 7;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<MediaFilter, dynamic>> fields =
      const {};

  @override
  MediaFilter read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MediaFilter.none;
      case 1:
        return MediaFilter.onlyWithMedia;
      case 2:
        return MediaFilter.onlyWithNoMedia;
      default:
        return MediaFilter.none;
    }
  }

  @override
  void write(BinaryWriter writer, MediaFilter obj) {
    switch (obj) {
      case MediaFilter.none:
        writer.writeByte(0);
        break;
      case MediaFilter.onlyWithMedia:
        writer.writeByte(1);
        break;
      case MediaFilter.onlyWithNoMedia:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaFilterAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PostDeletionStatusFilterAdapter
    extends TypeAdapter<PostDeletionStatusFilter> {
  const PostDeletionStatusFilterAdapter();

  static const int kTypeId = 26;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<PostDeletionStatusFilter, dynamic>>
      fields = const {};

  @override
  PostDeletionStatusFilter read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PostDeletionStatusFilter.none;
      case 1:
        return PostDeletionStatusFilter.onlyDeleted;
      case 2:
        return PostDeletionStatusFilter.onlyNonDeleted;
      default:
        return PostDeletionStatusFilter.none;
    }
  }

  @override
  void write(BinaryWriter writer, PostDeletionStatusFilter obj) {
    switch (obj) {
      case PostDeletionStatusFilter.none:
        writer.writeByte(0);
        break;
      case PostDeletionStatusFilter.onlyDeleted:
        writer.writeByte(1);
        break;
      case PostDeletionStatusFilter.onlyNonDeleted:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostDeletionStatusFilterAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

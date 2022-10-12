// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ImageboardArchiveSearchQueryAdapter
    extends TypeAdapter<ImageboardArchiveSearchQuery> {
  @override
  final int typeId = 5;

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
    );
  }

  @override
  void write(BinaryWriter writer, ImageboardArchiveSearchQuery obj) {
    writer
      ..writeByte(9)
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
      ..write(obj.imageboardKey);
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
  @override
  final int typeId = 6;

  @override
  PostTypeFilter read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PostTypeFilter.none;
      case 1:
        return PostTypeFilter.onlyOPs;
      case 2:
        return PostTypeFilter.onlyReplies;
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
  @override
  final int typeId = 7;

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
  @override
  final int typeId = 26;

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

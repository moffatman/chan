// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shareable_posts.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ShareablePostsStyleAdapter extends TypeAdapter<ShareablePostsStyle> {
  @override
  final int typeId = 42;

  @override
  ShareablePostsStyle read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ShareablePostsStyle(
      useTree: fields[0] as bool,
      parentDepth: fields[1] as int,
      childDepth: fields[2] as int,
      width: fields[3] as double,
      overrideThemeKey: fields[4] as String?,
      expandPrimaryImage: fields[5] as bool,
      revealYourPosts: fields[6] == null ? true : fields[6] as bool,
      includeFooter: fields[7] == null ? true : fields[7] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ShareablePostsStyle obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.useTree)
      ..writeByte(1)
      ..write(obj.parentDepth)
      ..writeByte(2)
      ..write(obj.childDepth)
      ..writeByte(3)
      ..write(obj.width)
      ..writeByte(4)
      ..write(obj.overrideThemeKey)
      ..writeByte(5)
      ..write(obj.expandPrimaryImage)
      ..writeByte(6)
      ..write(obj.revealYourPosts)
      ..writeByte(7)
      ..write(obj.includeFooter);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShareablePostsStyleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

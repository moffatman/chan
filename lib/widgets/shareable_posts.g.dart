// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shareable_posts.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ShareablePostsStyleFields {
  static bool getUseTree(ShareablePostsStyle x) => x.useTree;
  static const useTree = ReadOnlyHiveFieldAdapter<ShareablePostsStyle, bool>(
    getter: getUseTree,
    fieldNumber: 0,
    fieldName: 'useTree',
    merger: PrimitiveMerger(),
  );
  static int getParentDepth(ShareablePostsStyle x) => x.parentDepth;
  static const parentDepth = ReadOnlyHiveFieldAdapter<ShareablePostsStyle, int>(
    getter: getParentDepth,
    fieldNumber: 1,
    fieldName: 'parentDepth',
    merger: PrimitiveMerger(),
  );
  static int getChildDepth(ShareablePostsStyle x) => x.childDepth;
  static const childDepth = ReadOnlyHiveFieldAdapter<ShareablePostsStyle, int>(
    getter: getChildDepth,
    fieldNumber: 2,
    fieldName: 'childDepth',
    merger: PrimitiveMerger(),
  );
  static double getWidth(ShareablePostsStyle x) => x.width;
  static const width = ReadOnlyHiveFieldAdapter<ShareablePostsStyle, double>(
    getter: getWidth,
    fieldNumber: 3,
    fieldName: 'width',
    merger: PrimitiveMerger(),
  );
  static String? getOverrideThemeKey(ShareablePostsStyle x) =>
      x.overrideThemeKey;
  static const overrideThemeKey =
      ReadOnlyHiveFieldAdapter<ShareablePostsStyle, String?>(
    getter: getOverrideThemeKey,
    fieldNumber: 4,
    fieldName: 'overrideThemeKey',
    merger: PrimitiveMerger(),
  );
  static bool getExpandPrimaryImage(ShareablePostsStyle x) =>
      x.expandPrimaryImage;
  static const expandPrimaryImage =
      ReadOnlyHiveFieldAdapter<ShareablePostsStyle, bool>(
    getter: getExpandPrimaryImage,
    fieldNumber: 5,
    fieldName: 'expandPrimaryImage',
    merger: PrimitiveMerger(),
  );
  static bool getRevealYourPosts(ShareablePostsStyle x) => x.revealYourPosts;
  static const revealYourPosts =
      ReadOnlyHiveFieldAdapter<ShareablePostsStyle, bool>(
    getter: getRevealYourPosts,
    fieldNumber: 6,
    fieldName: 'revealYourPosts',
    merger: PrimitiveMerger(),
  );
  static bool getIncludeFooter(ShareablePostsStyle x) => x.includeFooter;
  static const includeFooter =
      ReadOnlyHiveFieldAdapter<ShareablePostsStyle, bool>(
    getter: getIncludeFooter,
    fieldNumber: 7,
    fieldName: 'includeFooter',
    merger: PrimitiveMerger(),
  );
}

class ShareablePostsStyleAdapter extends TypeAdapter<ShareablePostsStyle> {
  const ShareablePostsStyleAdapter();

  static const int kTypeId = 42;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<ShareablePostsStyle, dynamic>>
      fields = const {
    0: ShareablePostsStyleFields.useTree,
    1: ShareablePostsStyleFields.parentDepth,
    2: ShareablePostsStyleFields.childDepth,
    3: ShareablePostsStyleFields.width,
    4: ShareablePostsStyleFields.overrideThemeKey,
    5: ShareablePostsStyleFields.expandPrimaryImage,
    6: ShareablePostsStyleFields.revealYourPosts,
    7: ShareablePostsStyleFields.includeFooter
  };

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

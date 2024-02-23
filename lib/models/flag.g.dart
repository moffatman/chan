// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flag.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ImageboardFlagFields {
  static String getName(ImageboardFlag x) => x.name;
  static const name = ReadOnlyHiveFieldAdapter<ImageboardFlag, String>(
    getter: getName,
    fieldNumber: 0,
    fieldName: 'name',
    merger: PrimitiveMerger(),
  );
  static String getImageUrl(ImageboardFlag x) => x.imageUrl;
  static const imageUrl = ReadOnlyHiveFieldAdapter<ImageboardFlag, String>(
    getter: getImageUrl,
    fieldNumber: 1,
    fieldName: 'imageUrl',
    merger: PrimitiveMerger(),
  );
  static double getImageWidth(ImageboardFlag x) => x.imageWidth;
  static const imageWidth = ReadOnlyHiveFieldAdapter<ImageboardFlag, double>(
    getter: getImageWidth,
    fieldNumber: 2,
    fieldName: 'imageWidth',
    merger: PrimitiveMerger(),
  );
  static double getImageHeight(ImageboardFlag x) => x.imageHeight;
  static const imageHeight = ReadOnlyHiveFieldAdapter<ImageboardFlag, double>(
    getter: getImageHeight,
    fieldNumber: 3,
    fieldName: 'imageHeight',
    merger: PrimitiveMerger(),
  );
}

class ImageboardFlagAdapter extends TypeAdapter<ImageboardFlag> {
  const ImageboardFlagAdapter();

  static const int kTypeId = 14;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<ImageboardFlag, dynamic>> fields =
      const {
    0: ImageboardFlagFields.name,
    1: ImageboardFlagFields.imageUrl,
    2: ImageboardFlagFields.imageWidth,
    3: ImageboardFlagFields.imageHeight
  };

  @override
  ImageboardFlag read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ImageboardFlag(
      name: fields[0] as String,
      imageUrl: fields[1] as String,
      imageWidth: fields[2] as double,
      imageHeight: fields[3] as double,
    );
  }

  @override
  void write(BinaryWriter writer, ImageboardFlag obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.imageUrl)
      ..writeByte(2)
      ..write(obj.imageWidth)
      ..writeByte(3)
      ..write(obj.imageHeight);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageboardFlagAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ImageboardMultiFlagFields {
  static List<ImageboardFlag> getParts(ImageboardMultiFlag x) => x.parts;
  static const parts =
      ReadOnlyHiveFieldAdapter<ImageboardMultiFlag, List<ImageboardFlag>>(
    getter: getParts,
    fieldNumber: 0,
    fieldName: 'parts',
    merger: ListEqualsMerger<ImageboardFlag>(),
  );
}

class ImageboardMultiFlagAdapter extends TypeAdapter<ImageboardMultiFlag> {
  const ImageboardMultiFlagAdapter();

  static const int kTypeId = 36;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<ImageboardMultiFlag, dynamic>>
      fields = const {0: ImageboardMultiFlagFields.parts};

  @override
  ImageboardMultiFlag read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ImageboardMultiFlag(
      parts: (fields[0] as List).cast<ImageboardFlag>(),
    );
  }

  @override
  void write(BinaryWriter writer, ImageboardMultiFlag obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.parts);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageboardMultiFlagAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

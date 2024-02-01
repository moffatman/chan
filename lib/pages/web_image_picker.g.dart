// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'web_image_picker.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WebImageSearchMethodAdapter extends TypeAdapter<WebImageSearchMethod> {
  @override
  final int typeId = 35;

  @override
  WebImageSearchMethod read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return WebImageSearchMethod.google;
      case 1:
        return WebImageSearchMethod.yandex;
      case 2:
        return WebImageSearchMethod.duckDuckGo;
      case 3:
        return WebImageSearchMethod.bing;
      default:
        return WebImageSearchMethod.google;
    }
  }

  @override
  void write(BinaryWriter writer, WebImageSearchMethod obj) {
    switch (obj) {
      case WebImageSearchMethod.google:
        writer.writeByte(0);
        break;
      case WebImageSearchMethod.yandex:
        writer.writeByte(1);
        break;
      case WebImageSearchMethod.duckDuckGo:
        writer.writeByte(2);
        break;
      case WebImageSearchMethod.bing:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebImageSearchMethodAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

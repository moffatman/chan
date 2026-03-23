// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tls.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TlsClientHelloFields {
  static List<int> getVersions(TlsClientHello x) => x.versions;
  static const int kVersions = 0;
  static const versions = ReadOnlyHiveFieldAdapter<TlsClientHello, List<int>>(
    getter: getVersions,
    fieldNumber: kVersions,
    fieldName: 'versions',
    merger: ExactPrimitiveListMerger(),
  );
  static List<int> getCiphers(TlsClientHello x) => x.ciphers;
  static const int kCiphers = 1;
  static const ciphers = ReadOnlyHiveFieldAdapter<TlsClientHello, List<int>>(
    getter: getCiphers,
    fieldNumber: kCiphers,
    fieldName: 'ciphers',
    merger: ExactPrimitiveListMerger(),
  );
  static List<int> getExtensions(TlsClientHello x) => x.extensions;
  static const int kExtensions = 2;
  static const extensions = ReadOnlyHiveFieldAdapter<TlsClientHello, List<int>>(
    getter: getExtensions,
    fieldNumber: kExtensions,
    fieldName: 'extensions',
    merger: ExactPrimitiveListMerger(),
  );
  static List<int> getSignatureAlgorithms(TlsClientHello x) =>
      x.signatureAlgorithms;
  static const int kSignatureAlgorithms = 3;
  static const signatureAlgorithms =
      ReadOnlyHiveFieldAdapter<TlsClientHello, List<int>>(
    getter: getSignatureAlgorithms,
    fieldNumber: kSignatureAlgorithms,
    fieldName: 'signatureAlgorithms',
    merger: ExactPrimitiveListMerger(),
  );
}

class TlsClientHelloAdapter extends TypeAdapter<TlsClientHello> {
  const TlsClientHelloAdapter();

  static const int kTypeId = 50;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<TlsClientHello, dynamic>> fields =
      const {
    0: TlsClientHelloFields.versions,
    1: TlsClientHelloFields.ciphers,
    2: TlsClientHelloFields.extensions,
    3: TlsClientHelloFields.signatureAlgorithms
  };

  @override
  TlsClientHello read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final List<dynamic> fields = List.filled(4, null);
    for (int i = 0; i < numOfFields; i++) {
      final int fieldId = reader.readByte();
      final dynamic value = reader.read();
      if (fieldId < fields.length) {
        fields[fieldId] = value;
      }
    }
    return TlsClientHello(
      versions: (fields[0] as List).cast<int>(),
      ciphers: (fields[1] as List).cast<int>(),
      extensions: (fields[2] as List).cast<int>(),
      signatureAlgorithms: (fields[3] as List).cast<int>(),
    );
  }

  @override
  void write(BinaryWriter writer, TlsClientHello obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.versions)
      ..writeByte(1)
      ..write(obj.ciphers)
      ..writeByte(2)
      ..write(obj.extensions)
      ..writeByte(3)
      ..write(obj.signatureAlgorithms);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TlsClientHelloAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

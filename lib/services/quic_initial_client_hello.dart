import 'dart:collection';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Decrypts QUIC v1 client Initial packets and reassembles their TLS
/// ClientHello. This implementation is intentionally self-contained and does
/// not use FFI or platform crypto APIs.
///
/// [addDatagram] returns the complete TLS handshake message once all of its
/// CRYPTO bytes are available. It returns `null` for incomplete, malformed, or
/// unauthenticated input.
class QuicInitialClientHelloDecoder {
  QuicInitialClientHelloDecoder();

  static const _initialSalt = <int>[
    0x38,
    0x76,
    0x2c,
    0xf7,
    0xf5,
    0x59,
    0x34,
    0xb3,
    0x4d,
    0x17,
    0x9a,
    0xe6,
    0xa4,
    0xc8,
    0x0c,
    0xad,
    0xcc,
    0xbb,
    0x7f,
    0x0a,
  ];

  static const _quicVersion1 = 0x00000001;
  static const _authenticationTagLength = 16;

  final _CryptoReassembler _crypto = _CryptoReassembler();

  /// Decodes one UDP datagram. A datagram can contain several coalesced QUIC
  /// packets; only QUIC v1 client Initial packets are considered.
  Uint8List? addDatagram(Uint8List datagram) {
    try {
      var packetStart = 0;
      while (packetStart < datagram.length) {
        final packet = _decryptInitialPacket(datagram, packetStart);
        if (packet == null) break;
        packetStart += packet.consumed;
        for (final frame in packet.cryptoFrames) {
          final hello = _crypto.add(frame.offset, frame.data);
          if (hello != null) return hello;
        }
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  /// Convenience for a ClientHello wholly contained in one UDP datagram.
  static Uint8List? decode(Uint8List datagram) =>
      QuicInitialClientHelloDecoder().addDatagram(datagram);

  _InitialPacket? _decryptInitialPacket(Uint8List datagram, int packetStart) {
    if (packetStart >= datagram.length) return null;
    final protectedFirst = datagram[packetStart];
    if ((protectedFirst & 0xc0) != 0xc0 || packetStart + 6 > datagram.length) {
      return null;
    }
    if (_readUint32(datagram, packetStart + 1) != _quicVersion1) return null;
    if (((protectedFirst >> 4) & 0x03) != 0) return null;

    var offset = packetStart + 5;
    final destinationConnectionId = _readBytesWithLength(datagram, offset);
    if (destinationConnectionId == null) return null;
    offset = destinationConnectionId.nextOffset;
    final sourceConnectionId = _readBytesWithLength(datagram, offset);
    if (sourceConnectionId == null) return null;
    offset = sourceConnectionId.nextOffset;

    final tokenLength = _readVarInt(datagram, offset);
    if (tokenLength == null) return null;
    offset = tokenLength.nextOffset;
    if (tokenLength.value > datagram.length - offset) return null;
    offset += tokenLength.value;

    final length = _readVarInt(datagram, offset);
    if (length == null) return null;
    final packetNumberOffset = length.nextOffset;
    final packetEnd = packetNumberOffset + length.value;
    if (packetEnd > datagram.length ||
        packetEnd - packetNumberOffset < 1 + _authenticationTagLength ||
        packetNumberOffset + 4 + 16 > packetEnd) {
      return null;
    }

    final keys = _initialKeys(destinationConnectionId.bytes);
    final unprotected = Uint8List.fromList(
      datagram.sublist(packetStart, packetEnd),
    );
    final packetNumberInPacket = packetNumberOffset - packetStart;
    final sample = Uint8List.fromList(
      unprotected.sublist(packetNumberInPacket + 4, packetNumberInPacket + 20),
    );
    final mask = _Aes128(keys.headerProtectionKey).encryptBlock(sample);
    unprotected[0] ^= mask[0] & 0x0f;
    final packetNumberLength = (unprotected[0] & 0x03) + 1;
    if (packetNumberOffset + packetNumberLength + _authenticationTagLength >
        packetEnd) {
      return null;
    }
    for (var index = 0; index < packetNumberLength; index++) {
      unprotected[packetNumberInPacket + index] ^= mask[index + 1];
    }

    var truncatedPacketNumber = 0;
    for (var index = 0; index < packetNumberLength; index++) {
      truncatedPacketNumber = (truncatedPacketNumber << 8) |
          unprotected[packetNumberInPacket + index];
    }
    final packetNumber = _decodeFirstPacketNumber(
      truncatedPacketNumber,
      packetNumberLength,
    );
    final payloadOffset = packetNumberOffset + packetNumberLength;
    final plaintext = _aesGcmOpen(
      key: keys.key,
      nonce: _packetNonce(keys.iv, packetNumber),
      ciphertext:
          Uint8List.fromList(datagram.sublist(payloadOffset, packetEnd)),
      associatedData: Uint8List.fromList(
        unprotected.sublist(0, payloadOffset - packetStart),
      ),
    );
    if (plaintext == null) return null;
    return _InitialPacket(
      consumed: packetEnd - packetStart,
      cryptoFrames: _readCryptoFrames(plaintext),
    );
  }

  static _InitialKeys _initialKeys(Uint8List destinationConnectionId) {
    final initialSecret = _hkdfExtract(
      Uint8List.fromList(_initialSalt),
      destinationConnectionId,
    );
    final clientSecret = _hkdfExpandLabel(initialSecret, 'client in', 32);
    return _InitialKeys(
      key: _hkdfExpandLabel(clientSecret, 'quic key', 16),
      iv: _hkdfExpandLabel(clientSecret, 'quic iv', 12),
      headerProtectionKey: _hkdfExpandLabel(clientSecret, 'quic hp', 16),
    );
  }
}

class _InitialKeys {
  const _InitialKeys({
    required this.key,
    required this.iv,
    required this.headerProtectionKey,
  });

  final Uint8List key;
  final Uint8List iv;
  final Uint8List headerProtectionKey;
}

class _InitialPacket {
  const _InitialPacket({required this.consumed, required this.cryptoFrames});

  final int consumed;
  final List<_CryptoFrame> cryptoFrames;
}

class _CryptoFrame {
  const _CryptoFrame(this.offset, this.data);

  final int offset;
  final Uint8List data;
}

class _CryptoReassembler {
  final SplayTreeMap<int, Uint8List> _fragments =
      SplayTreeMap<int, Uint8List>();
  final BytesBuilder _contiguous = BytesBuilder(copy: false);
  var _nextOffset = 0;

  Uint8List? add(int offset, Uint8List data) {
    if (data.isEmpty) return _clientHello();
    if (offset + data.length <= _nextOffset) return _clientHello();
    if (offset < _nextOffset) {
      data = Uint8List.fromList(data.sublist(_nextOffset - offset));
      offset = _nextOffset;
    }
    _fragments.putIfAbsent(offset, () => data);
    while (true) {
      final contiguous = _fragments.remove(_nextOffset);
      if (contiguous == null) break;
      _contiguous.add(contiguous);
      _nextOffset += contiguous.length;
    }
    return _clientHello();
  }

  Uint8List? _clientHello() {
    final bytes = _contiguous.toBytes();
    if (bytes.length < 4 || bytes[0] != 1) return null;
    final length = (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
    if (bytes.length < length + 4) return null;
    return Uint8List.fromList(bytes.sublist(0, length + 4));
  }
}

class _VarInt {
  const _VarInt(this.value, this.nextOffset);

  final int value;
  final int nextOffset;
}

class _BytesWithLength {
  const _BytesWithLength(this.bytes, this.nextOffset);

  final Uint8List bytes;
  final int nextOffset;
}

_BytesWithLength? _readBytesWithLength(Uint8List bytes, int offset) {
  if (offset >= bytes.length) return null;
  final length = bytes[offset++];
  if (length > bytes.length - offset) return null;
  return _BytesWithLength(
    Uint8List.fromList(bytes.sublist(offset, offset + length)),
    offset + length,
  );
}

_VarInt? _readVarInt(Uint8List bytes, int offset) {
  if (offset >= bytes.length) return null;
  final first = bytes[offset];
  final length = 1 << (first >> 6);
  if (offset + length > bytes.length) return null;
  var value = first & 0x3f;
  for (var index = 1; index < length; index++) {
    value = (value << 8) | bytes[offset + index];
  }
  return _VarInt(value, offset + length);
}

List<_CryptoFrame> _readCryptoFrames(Uint8List plaintext) {
  final frames = <_CryptoFrame>[];
  var offset = 0;
  while (offset < plaintext.length) {
    final type = _readVarInt(plaintext, offset);
    if (type == null) throw const FormatException('Truncated QUIC frame type');
    offset = type.nextOffset;
    switch (type.value) {
      case 0:
        continue;
      case 1:
        continue;
      case 2:
      case 3:
        offset = _skipAckFrame(plaintext, offset, type.value == 3);
        continue;
      case 6:
        final cryptoOffset = _readVarInt(plaintext, offset);
        final length = cryptoOffset == null
            ? null
            : _readVarInt(plaintext, cryptoOffset.nextOffset);
        if (cryptoOffset == null ||
            length == null ||
            length.value > plaintext.length - length.nextOffset) {
          throw const FormatException('Malformed QUIC CRYPTO frame');
        }
        final data = Uint8List.fromList(
          plaintext.sublist(
              length.nextOffset, length.nextOffset + length.value),
        );
        frames.add(_CryptoFrame(cryptoOffset.value, data));
        offset = length.nextOffset + length.value;
        continue;
      case 0x1c:
      case 0x1d:
        return frames;
      default:
        throw FormatException('Unsupported Initial frame type ${type.value}');
    }
  }
  return frames;
}

int _skipAckFrame(Uint8List bytes, int offset, bool hasEcn) {
  final largest = _readVarInt(bytes, offset);
  final delay = largest == null ? null : _readVarInt(bytes, largest.nextOffset);
  final rangeCount =
      delay == null ? null : _readVarInt(bytes, delay.nextOffset);
  final firstRange =
      rangeCount == null ? null : _readVarInt(bytes, rangeCount.nextOffset);
  if (largest == null ||
      delay == null ||
      rangeCount == null ||
      firstRange == null) {
    throw const FormatException('Malformed QUIC ACK frame');
  }
  offset = firstRange.nextOffset;
  for (var index = 0; index < rangeCount.value; index++) {
    final gap = _readVarInt(bytes, offset);
    final range = gap == null ? null : _readVarInt(bytes, gap.nextOffset);
    if (gap == null || range == null) {
      throw const FormatException('Malformed QUIC ACK range');
    }
    offset = range.nextOffset;
  }
  if (hasEcn) {
    for (var index = 0; index < 3; index++) {
      final count = _readVarInt(bytes, offset);
      if (count == null) throw const FormatException('Malformed QUIC ACK ECN');
      offset = count.nextOffset;
    }
  }
  return offset;
}

int _readUint32(Uint8List bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];

int _decodeFirstPacketNumber(int truncated, int length) {
  final window = 1 << (length * 8);
  final halfWindow = window >> 1;
  const expected = 0;
  var candidate = (expected & ~(window - 1)) | truncated;
  if (candidate + halfWindow <= expected && candidate + window < (1 << 62)) {
    candidate += window;
  } else if (candidate > expected + halfWindow && candidate >= window) {
    candidate -= window;
  }
  return candidate;
}

Uint8List _packetNonce(Uint8List iv, int packetNumber) {
  final nonce = Uint8List.fromList(iv);
  for (var index = 0; index < 8; index++) {
    nonce[nonce.length - 1 - index] ^= (packetNumber >> (index * 8)) & 0xff;
  }
  return nonce;
}

Uint8List _hkdfExtract(Uint8List salt, Uint8List inputKeyMaterial) =>
    Uint8List.fromList(Hmac(sha256, salt).convert(inputKeyMaterial).bytes);

Uint8List _hkdfExpandLabel(Uint8List secret, String label, int length) {
  final labelBytes = Uint8List.fromList('tls13 $label'.codeUnits);
  final info = BytesBuilder(copy: false)
    ..addByte((length >> 8) & 0xff)
    ..addByte(length & 0xff)
    ..addByte(labelBytes.length)
    ..add(labelBytes)
    ..addByte(0);
  return _hkdfExpand(secret, info.takeBytes(), length);
}

Uint8List _hkdfExpand(Uint8List secret, Uint8List info, int length) {
  final output = BytesBuilder(copy: false);
  var previous = Uint8List(0);
  final hmac = Hmac(sha256, secret);
  for (var counter = 1; output.length < length; counter++) {
    previous = Uint8List.fromList(hmac.convert(
      Uint8List.fromList(<int>[...previous, ...info, counter]),
    ).bytes);
    output.add(previous);
  }
  return Uint8List.fromList(output.takeBytes().sublist(0, length));
}

Uint8List? _aesGcmOpen({
  required Uint8List key,
  required Uint8List nonce,
  required Uint8List ciphertext,
  required Uint8List associatedData,
}) {
  if (nonce.length != 12 || ciphertext.length < 16) return null;
  final encrypted = Uint8List.fromList(
    ciphertext.sublist(0, ciphertext.length - 16),
  );
  final receivedTag = Uint8List.fromList(
    ciphertext.sublist(ciphertext.length - 16),
  );
  final aes = _Aes128(key);
  final hashKey = aes.encryptBlock(Uint8List(16));
  final initialCounter = Uint8List(16)
    ..setRange(0, nonce.length, nonce)
    ..[15] = 1;
  final calculatedTag = _xor(
    aes.encryptBlock(initialCounter),
    _ghash(hashKey, associatedData, encrypted),
  );
  if (!_constantTimeEquals(calculatedTag, receivedTag)) return null;

  final counter = Uint8List.fromList(initialCounter);
  final plaintext = Uint8List(encrypted.length);
  for (var offset = 0; offset < encrypted.length; offset += 16) {
    _incrementCounter(counter);
    final keystream = aes.encryptBlock(counter);
    final blockLength =
        encrypted.length - offset < 16 ? encrypted.length - offset : 16;
    for (var index = 0; index < blockLength; index++) {
      plaintext[offset + index] = encrypted[offset + index] ^ keystream[index];
    }
  }
  return plaintext;
}

Uint8List _ghash(Uint8List hashKey, Uint8List aad, Uint8List ciphertext) {
  var value = Uint8List(16);
  void update(Uint8List bytes) {
    for (var offset = 0; offset < bytes.length; offset += 16) {
      final block = Uint8List(16);
      final blockLength =
          bytes.length - offset < 16 ? bytes.length - offset : 16;
      block.setRange(0, blockLength, bytes, offset);
      value = _galoisMultiply(_xor(value, block), hashKey);
    }
  }

  update(aad);
  update(ciphertext);
  final lengths = Uint8List(16);
  _writeUint64(lengths, 0, aad.length * 8);
  _writeUint64(lengths, 8, ciphertext.length * 8);
  return _galoisMultiply(_xor(value, lengths), hashKey);
}

Uint8List _galoisMultiply(Uint8List x, Uint8List y) {
  final result = Uint8List(16);
  final value = Uint8List.fromList(y);
  for (var byteIndex = 0; byteIndex < 16; byteIndex++) {
    for (var bit = 7; bit >= 0; bit--) {
      if ((x[byteIndex] & (1 << bit)) != 0) {
        for (var index = 0; index < 16; index++) {
          result[index] ^= value[index];
        }
      }
      final leastSignificantBit = value[15] & 1;
      for (var index = 15; index > 0; index--) {
        value[index] = (value[index] >> 1) | ((value[index - 1] & 1) << 7);
      }
      value[0] >>= 1;
      if (leastSignificantBit != 0) value[0] ^= 0xe1;
    }
  }
  return result;
}

void _incrementCounter(Uint8List counter) {
  for (var index = 15; index >= 12; index--) {
    counter[index] = (counter[index] + 1) & 0xff;
    if (counter[index] != 0) return;
  }
}

Uint8List _xor(Uint8List left, Uint8List right) {
  final result = Uint8List(left.length);
  for (var index = 0; index < result.length; index++) {
    result[index] = left[index] ^ right[index];
  }
  return result;
}

bool _constantTimeEquals(Uint8List left, Uint8List right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}

void _writeUint64(Uint8List bytes, int offset, int value) {
  for (var index = 7; index >= 0; index--) {
    bytes[offset + index] = value & 0xff;
    value >>= 8;
  }
}

class _Aes128 {
  _Aes128(Uint8List key) : _roundKeys = _expandKey(key);

  final Uint8List _roundKeys;

  Uint8List encryptBlock(Uint8List input) {
    if (input.length != 16) throw ArgumentError.value(input, 'input');
    final state = Uint8List.fromList(input);
    _addRoundKey(state, 0);
    for (var round = 1; round < 10; round++) {
      _subBytes(state);
      _shiftRows(state);
      _mixColumns(state);
      _addRoundKey(state, round);
    }
    _subBytes(state);
    _shiftRows(state);
    _addRoundKey(state, 10);
    return state;
  }

  void _addRoundKey(Uint8List state, int round) {
    final offset = round * 16;
    for (var index = 0; index < 16; index++) {
      state[index] ^= _roundKeys[offset + index];
    }
  }

  static Uint8List _expandKey(Uint8List key) {
    if (key.length != 16) throw ArgumentError.value(key, 'key');
    final expanded = Uint8List(176)..setRange(0, 16, key);
    var generated = 16;
    var roundConstant = 1;
    final temp = Uint8List(4);
    while (generated < expanded.length) {
      temp.setRange(0, 4, expanded, generated - 4);
      if (generated % 16 == 0) {
        final first = temp[0];
        temp[0] = _aesSBox(temp[1]) ^ roundConstant;
        temp[1] = _aesSBox(temp[2]);
        temp[2] = _aesSBox(temp[3]);
        temp[3] = _aesSBox(first);
        roundConstant = _aesMultiply(roundConstant, 2);
      }
      for (var index = 0; index < 4; index++) {
        expanded[generated] = expanded[generated - 16] ^ temp[index];
        generated++;
      }
    }
    return expanded;
  }

  static void _subBytes(Uint8List state) {
    for (var index = 0; index < state.length; index++) {
      state[index] = _aesSBox(state[index]);
    }
  }

  static void _shiftRows(Uint8List state) {
    void shift(int first, int second, int third, int fourth) {
      final value = state[first];
      state[first] = state[second];
      state[second] = state[third];
      state[third] = state[fourth];
      state[fourth] = value;
    }

    void swap(int left, int right) {
      final value = state[left];
      state[left] = state[right];
      state[right] = value;
    }

    shift(1, 5, 9, 13);
    swap(2, 10);
    swap(6, 14);
    shift(3, 15, 11, 7);
  }

  static void _mixColumns(Uint8List state) {
    for (var column = 0; column < 16; column += 4) {
      final a = state[column];
      final b = state[column + 1];
      final c = state[column + 2];
      final d = state[column + 3];
      state[column] = _aesMultiply(a, 2) ^ _aesMultiply(b, 3) ^ c ^ d;
      state[column + 1] = a ^ _aesMultiply(b, 2) ^ _aesMultiply(c, 3) ^ d;
      state[column + 2] = a ^ b ^ _aesMultiply(c, 2) ^ _aesMultiply(d, 3);
      state[column + 3] = _aesMultiply(a, 3) ^ b ^ c ^ _aesMultiply(d, 2);
    }
  }
}

int _aesSBox(int value) {
  final inverse = value == 0 ? 0 : _aesPower(value, 254);
  return (inverse ^
          _rotateByte(inverse, 1) ^
          _rotateByte(inverse, 2) ^
          _rotateByte(inverse, 3) ^
          _rotateByte(inverse, 4) ^
          0x63) &
      0xff;
}

int _rotateByte(int value, int amount) =>
    ((value << amount) | (value >> (8 - amount))) & 0xff;

int _aesPower(int value, int exponent) {
  var result = 1;
  var base = value;
  while (exponent != 0) {
    if ((exponent & 1) != 0) result = _aesMultiply(result, base);
    base = _aesMultiply(base, base);
    exponent >>= 1;
  }
  return result;
}

int _aesMultiply(int left, int right) {
  var result = 0;
  while (right != 0) {
    if ((right & 1) != 0) result ^= left;
    final highBit = left & 0x80;
    left = (left << 1) & 0xff;
    if (highBit != 0) left ^= 0x1b;
    right >>= 1;
  }
  return result;
}

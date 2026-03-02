import 'dart:convert';
import 'dart:typed_data';

class ByteReader {
	final Uint8List buffer;
	int pos = 0;
	ByteReader(this.buffer);

	bool get done => pos >= buffer.length;

	@pragma('vm:prefer-inline')
	void _check(int bytes) {
		if ((pos + bytes - 1) >= buffer.length) {
			throw Exception('Reading $pos + $bytes when there are only ${buffer.length}');
		}
	}

	@pragma('vm:prefer-inline')
	bool takeBool() {
		final byte = takeUint8();
		if (byte == 0x01) {
			return true;
		}
		if (byte == 0x00) {
			return false;
		}
		throw Exception('Unrecognized bool code 0x${byte.toRadixString(16)}');
	}

	@pragma('vm:prefer-inline')
	int takeUint8() {
		_check(1);
		return buffer[pos++];
	}

	@pragma('vm:prefer-inline')
	int takeUint16() {
		_check(2);
		return (buffer[pos++] << 8) | buffer[pos++];
	}

	@pragma('vm:prefer-inline')
	int takeUint24() {
		_check(3);
		return (buffer[pos++] << 16) | (buffer[pos++] << 8) | buffer[pos++];
	}

	@pragma('vm:prefer-inline')
	int takeUint32() {
		_check(4);
		return (buffer[pos++] << 24) | (buffer[pos++] << 16) | (buffer[pos++] << 8) | buffer[pos++];
	}

	@pragma('vm:prefer-inline')
	int takeUint64() {
		_check(8);
		return (buffer[pos++] << 56) | (buffer[pos++] << 48) | (buffer[pos++] << 40) | (buffer[pos++] << 32) | (buffer[pos++] << 24) | (buffer[pos++] << 16) | (buffer[pos++] << 8) | buffer[pos++];
	}

	@pragma('vm:prefer-inline')
	int takeIntVar() {
		final byte = takeUint8();
		if (byte < 0x80) {
			return byte;
		}
		if (byte == 0x81) {
			return takeUint8();
		}
		if (byte == 0x82) {
			return takeUint16();
		}
		if (byte == 0x83) {
			return takeUint24();
		}
		if (byte == 0x84) {
			return takeUint32();
		}
		if (byte == 0x88) {
			return takeUint64();
		}
		if (byte == 0x91) {
			return -takeUint8();
		}
		if (byte == 0x92) {
			return -takeUint16();
		}
		if (byte == 0x93) {
			return -takeUint24();
		}
		if (byte == 0x94) {
			return -takeUint32();
		}
		if (byte == 0x98) {
			return -takeUint64();
		}
		throw Exception('Unrecognized varint code 0x${byte.toRadixString(16)}');
	}

	@pragma('vm:prefer-inline')
	int? takeIntVarNullable() {
		final byte = takeUint8();
		if (byte < 0x80) {
			return byte;
		}
		if (byte == 0x80) {
			return null;
		}
		if (byte == 0x81) {
			return takeUint8();
		}
		if (byte == 0x82) {
			return takeUint16();
		}
		if (byte == 0x83) {
			return takeUint24();
		}
		if (byte == 0x84) {
			return takeUint32();
		}
		if (byte == 0x88) {
			return takeUint64();
		}
		if (byte == 0x91) {
			return -takeUint8();
		}
		if (byte == 0x92) {
			return -takeUint16();
		}
		if (byte == 0x93) {
			return -takeUint24();
		}
		if (byte == 0x94) {
			return -takeUint32();
		}
		if (byte == 0x98) {
			return -takeUint64();
		}
		throw Exception('Unrecognized varint? code 0x${byte.toRadixString(16)}');
	}

	@pragma('vm:prefer-inline')
	Uint8List takeBytes(int length) {
		_check(length);
		final out = buffer.sublist(pos, pos + length);
		pos += length;
		return out;
	}

	@pragma('vm:prefer-inline')
	void skipBytes(int length) {
		_check(length);
		pos += length;
	}

	@pragma('vm:prefer-inline')
	String takeString() {
		final length = takeIntVar();
		return utf8.decode(takeBytes(length));
	}

	@pragma('vm:prefer-inline')
	String? takeStringNullable() {
		final length = takeIntVarNullable();
		if (length == null) {
			return null;
		}
		return utf8.decode(takeBytes(length));
	}

	@override
	String toString() => 'ByteReader(size: ${buffer.length}, pos: $pos)';
}

extension Helpers on BytesBuilder {
	@pragma('vm:prefer-inline')
	void addBool(bool value) {
		addByte(value ? 0x01 : 0x00);
	}
	@pragma('vm:prefer-inline')
	void addUint16(int value) {
		if (value < 0) {
			throw Exception('Tried to write $value as uint');
		}
		addByte((value >> 8) & 0xFF);
		addByte(value & 0xFF);
	}
	@pragma('vm:prefer-inline')
	void addUint24(int value) {
		if (value < 0) {
			throw Exception('Tried to write $value as uint');
		}
		addByte((value >> 16) & 0xFF);
		addByte((value >> 8) & 0xFF);
		addByte(value & 0xFF);
	}
	@pragma('vm:prefer-inline')
	void addUint32(int value) {
		if (value < 0) {
			throw Exception('Tried to write $value as uint');
		}
		addByte((value >> 24) & 0xFF);
		addByte((value >> 16) & 0xFF);
		addByte((value >> 8) & 0xFF);
		addByte(value & 0xFF);
	}
	@pragma('vm:prefer-inline')
	void addUint64(int value) {
		if (value < 0) {
			throw Exception('Tried to write $value as uint');
		}
		addByte((value >> 56) & 0xFF);
		addByte((value >> 48) & 0xFF);
		addByte((value >> 40) & 0xFF);
		addByte((value >> 32) & 0xFF);
		addByte((value >> 24) & 0xFF);
		addByte((value >> 16) & 0xFF);
		addByte((value >> 8) & 0xFF);
		addByte(value & 0xFF);
	}
	@pragma('vm:prefer-inline')
	void addIntVar(int value) {
		if (value >= 0) {
			if (value < 0x80) {
				addByte(value);
			}
			else if (value <= 0xFF) {
				addByte(0x81);
				addByte(value);
			}
			else if (value <= 0xFFFF) {
				addByte(0x82);
				addUint16(value);
			}
			else if (value <= 0xFFFFFF) {
				addByte(0x83);
				addUint24(value);
			}
			else if (value <= 0xFFFFFFFF) {
				addByte(0x84);
				addUint32(value);
			}
			else {
				addByte(0x88);
				addUint64(value);
			}
		}
		else {
			if (value >= -0xFF) {
				addByte(0x91);
				addByte(-value);
			}
			else if (value >= -0xFFFF) {
				addByte(0x92);
				addUint16(-value);
			}
			else if (value >= -0xFFFFFF) {
				addByte(0x93);
				addUint24(-value);
			}
			else if (value >= -0xFFFFFFFF) {
				addByte(0x94);
				addUint32(-value);
			}
			else {
				addByte(0x98);
				addUint64(-value);
			}
		}
	}
	@pragma('vm:prefer-inline')
	void addIntVarNullable(int? value) {
		if (value == null) {
			addByte(0x80);
		}
		else if (value >= 0) {
			if (value < 0x80) {
				addByte(value);
			}
			else if (value <= 0xFF) {
				addByte(0x81);
				addByte(value);
			}
			else if (value <= 0xFFFF) {
				addByte(0x82);
				addUint16(value);
			}
			else if (value <= 0xFFFFFF) {
				addByte(0x83);
				addUint24(value);
			}
			else if (value <= 0xFFFFFFFF) {
				addByte(0x84);
				addUint32(value);
			}
			else {
				addByte(0x88);
				addUint64(value);
			}
		}
		else {
			if (value >= -0xFF) {
				addByte(0x91);
				addByte(-value);
			}
			else if (value >= -0xFFFF) {
				addByte(0x92);
				addUint16(-value);
			}
			else if (value >= -0xFFFFFF) {
				addByte(0x93);
				addUint24(-value);
			}
			else if (value >= -0xFFFFFFFF) {
				addByte(0x94);
				addUint32(-value);
			}
			else {
				addByte(0x98);
				addUint64(-value);
			}
		}
	}
	@pragma('vm:prefer-inline')
	void addString(String value) {
		final bytes = utf8.encode(value);
		addIntVar(bytes.length);
		add(bytes);
	}
	@pragma('vm:prefer-inline')
	void addStringNullable(String? value) {
		final bytes = value == null ? null : utf8.encode(value);
		addIntVarNullable(bytes?.length);
		if (bytes != null) {
			add(bytes);
		}
	}
}

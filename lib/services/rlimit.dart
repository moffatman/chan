import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'package:ffi/ffi.dart';

final class _RLimit extends Struct {
	@Int64()
	external int current;
	@Int64()
	external int maximum;
}

typedef RLimit = ({int current, int maximum});

const kRlimitNoFile = 8;

RLimit getrlimit(int resource) {
	final stdlib = DynamicLibrary.process();
	final getrlimit = stdlib.lookupFunction<Int32 Function(Int32 resource, Pointer<_RLimit> rlp), int Function(int resource, Pointer<_RLimit> rlp)>('getrlimit', isLeaf: true);
	final rlim = calloc<_RLimit>(1);
	final ret = getrlimit(resource, rlim);
	try {
		if (ret == 0) {
			return (current: rlim.ref.current, maximum: rlim.ref.maximum);
		}
		else {
			throw Exception('getrlimit returned error $ret');
		}
	}
	finally {
		calloc.free(rlim);
	}
}

void setrlimit(int resource, RLimit rlimit) {
	final stdlib = DynamicLibrary.process();
	final setrlimit = stdlib.lookupFunction<Int32 Function(Int32 resource, Pointer<_RLimit> rlp), int Function(int resource, Pointer<_RLimit> rlp)>('setrlimit', isLeaf: true);
	final rlim = calloc<_RLimit>(1);
	rlim.ref.current = rlimit.current;
	rlim.ref.maximum = rlimit.maximum;
	final ret = setrlimit(resource, rlim);
	try {
		if (ret != 0) {
			throw Exception('setrlimit returned error $ret');
		}
	}
	finally {
		calloc.free(rlim);
	}
}

Future<void> initializeRLimit() async {
	if (!Platform.isIOS) {
		return;
	}
	// Raise rlimit, the default of 256 is too small on iOS
	try {
		final first = getrlimit(kRlimitNoFile);
		setrlimit(kRlimitNoFile, (current: min(2048, first.maximum), maximum: first.maximum));
	}
	catch (e, st) {
		Future.error(e, st);
		print(e);
		print(st);
	}
}

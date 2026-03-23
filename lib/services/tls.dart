import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chan/services/bytes.dart';
import 'package:chan/services/cloudflare.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hive/hive.dart';

part 'tls.g.dart';

const _kGREASE = {
	0x4a4a, 0x5a5a, 0x6a6a, 0x7a7a,
	0x0a0a, 0x1a1a, 0x2a2a, 0x3a3a,
	0x8a8a, 0x9a9a, 0xaaaa, 0xbaba,
	0xcaca, 0xdada, 0xeaea, 0xfafa
};

String _stringify(Iterable<int> ids) {
	return ids.map((id) => id.toRadixString(16).padLeft(4, '0')).join(',');
}

@HiveType(typeId: 50)
class TlsClientHello {
	@HiveField(0, merger: ExactPrimitiveListMerger())
	final List<int> versions;
	@HiveField(1, merger: ExactPrimitiveListMerger())
	final List<int> ciphers;
	@HiveField(2, merger: ExactPrimitiveListMerger())
	final List<int> extensions;
	@HiveField(3, merger: ExactPrimitiveListMerger())
	final List<int> signatureAlgorithms;
	const TlsClientHello({
		required this.versions,
		required this.ciphers,
		required this.extensions,
		required this.signatureAlgorithms
	});

	static String _first12Sha256(String str) {
		return sha256.convert(utf8.encode(str)).bytes.take(6).map((c) => c.toRadixString(16).padLeft(2, '0')).join('');
	}

	String get ja4h {
		final buffer = StringBuffer();
		buffer.write('t'); // Never QUIC
		buffer.write(switch(versions.first) {
			0x0002 => 's2',
			0x0300 => 's3',
			0x0301 => '10',
			0x0302 => '11',
			0x0303 => '12',
			0x0304 => '13',
			_ => '00'
		});
		final ciphers = this.ciphers.toList();
		ciphers.sort();
		final extensions = this.extensions.toList();
		// Remove SNI and ALPN
		extensions.removeWhere((e) => e == 0x0000 || e == 0x0010);
		extensions.sort();
		final signatureAlgorithms = this.signatureAlgorithms.toList();
		buffer.write('d'); // Use SNI always
		buffer.write(ciphers.length.toString().padLeft(2, '0'));
		// We won't have SNI on 127.0.0.1
		// So just assume it is there (along with ALPN). It's not part of the hash.
		buffer.write((extensions.length + 2).toString().padLeft(2, '0'));
		buffer.write('h2'); // ALPN
		buffer.write('_');
		buffer.write(_first12Sha256(_stringify(ciphers)));
		buffer.write('_');
		if (signatureAlgorithms.isNotEmpty) {
			buffer.write(_first12Sha256('${_stringify(extensions)}_${_stringify(signatureAlgorithms)}'));
		}
		else {
			buffer.write(_first12Sha256(_stringify(extensions)));
		}
		return buffer.toString();
	}

	@override
	String toString() => 'TlsClientHello(versions: [${_stringify(versions)}], ciphers: [${_stringify(ciphers)}], extensions: [${_stringify(extensions)}], signatureAlgorithms: [${_stringify(signatureAlgorithms)}])';
}

Future<TlsClientHello> getTlsHello(Future<void> Function(Uri uri, CancelToken cancelToken) cb) async {
	final localhost = InternetAddress.loopbackIPv4;
	final server = await ServerSocket.bind(localhost, 0);
	final completer = Completer<TlsClientHello>();
	final sub = server.listen((socket) async {
		final record = AsyncByteReader(socket);
		try {
			final recordType = await record.takeUint8();
			if (recordType != 0x16) {
				throw Exception('Unexpected SSL record type 0x${recordType.toRadixString(16).padLeft(2, '0')}');
			}
			final recordVersion = await record.takeUint16();
			if (recordVersion != 0x0301) {
				throw Exception('Unexpected SSL record version 0x${recordVersion.toRadixString(16).padLeft(4, '0')}');
			}
			final recordLength = await record.takeUint16();
			final recordBytes = await record.takeBytes(recordLength);
			Future.delayed(const Duration(seconds: 1), socket.close);
			final handshake = ByteReader(recordBytes);
			final messageType = handshake.takeUint8();
			if (messageType != 0x01) {
				throw Exception('Unexpected message type 0x${messageType.toRadixString(16).padLeft(2, '0')}');
			}
			final messageLength = handshake.takeUint24();
			if (messageLength != handshake.remainingBytes) {
				throw Exception('Message should be $messageLength bytes, but there are ${handshake.remainingBytes} remaining to read');
			}
			final clientVersion = handshake.takeUint16();
			List<int> versions = [clientVersion];
			handshake.skipBytes(32); // clientRandom
			final sessionIdLength = handshake.takeUint8();
			handshake.skipBytes(sessionIdLength); // sessionId
			final ciphersLength = handshake.takeUint16() ~/ 2;
			final ciphers = <int>[];
			for (int i = 0; i < ciphersLength; i++) {
				final id = handshake.takeUint16();
				if (!_kGREASE.contains(id)) {
					ciphers.add(id);
				}
			}
			final compressionMethodsCount = handshake.takeUint8();
			handshake.skipBytes(compressionMethodsCount); // compressionMethods
			final extensionsLength = handshake.takeUint16();
			final extensionsBytes = handshake.takeBytes(extensionsLength);
			final extensionsReader = ByteReader(extensionsBytes);
			final extensions = <int>[];
			final signatureAlgorithms = <int>[];
			while (!extensionsReader.done) {
				final id = extensionsReader.takeUint16();
				final length = extensionsReader.takeUint16();
				if (id == 0x000d) {
					final signatureAlgorithmsLength = extensionsReader.takeUint16();
					signatureAlgorithms.addAll(Iterable.generate(signatureAlgorithmsLength ~/ 2, (_) {
						return extensionsReader.takeUint16();
					}));
				}
				else if (id == 0x002b) {
					versions.clear();
					final supportedVersionsLength = extensionsReader.takeUint8() ~/ 2;
					for (int i = 0; i < supportedVersionsLength; i++) {
						final version = extensionsReader.takeUint16();
						if (!_kGREASE.contains(version)) {
							versions.add(version);
						}
					}
				}
				else {
					extensionsReader.skipBytes(length);
				}
				if (!_kGREASE.contains(id)) {
					extensions.add(id);
				}
			}
			completer.complete(TlsClientHello(
				versions: versions,
				ciphers: ciphers,
				extensions: extensions,
				signatureAlgorithms: signatureAlgorithms
			));
		}
		finally {
			record.dispose();
		}
	});
	final cancelToken = CancelToken();
	try {
		cb(Uri.https(localhost.host).replace(port: server.port), cancelToken).then((_) => null, onError: (_) => null);
		final clientHello = await completer.future;
		cancelToken.cancel();
		await sub.cancel();
		await server.close();
		return clientHello;
	}
	finally {
		cancelToken.cancel();
	}
}

Future<TlsClientHello> getDioHello({required Dio client, required bool cloudflare}) {
	return getTlsHello((uri, cancelToken) => client.getUri(uri, options: Options(
		extra: {
			kCloudflare: cloudflare,
			kPriority: RequestPriority.lowest
		}
	), cancelToken: cancelToken));
}

Future<TlsClientHello> getWebViewHello() async {
	return getTlsHello((uri, cancelToken) async {
		final webView = HeadlessInAppWebView(
			initialUrlRequest: URLRequest(
				url: WebUri.uri(uri)
			)
		);
		await webView.run();
		await cancelToken.whenCancel;
		webView.dispose();
	});
}

void applyTlsSettings(ClientSetting setting) {
	// Will be filled in on forked_flutter_engine branch
}

const _kAndroidHello = TlsClientHello(
	versions: [0x0304,0x0303],
	ciphers: [0x1303,0x1301,0x1302,0xcca9,0xcca8,0xc02b,0xc02f,0xc02c,0xc030,0xc013,0xc014,0x009c,0x009d,0x002f,0x0035],
	extensions: [0xfe0d,0x0017,0xff01,0x000a,0x000b,0x0023,0x0010,0x0005,0x000d,0x0012,0x0033,0x002d,0x002b,0x001b,0x44cd],
	signatureAlgorithms: [0x0403,0x0804,0x0401,0x0503,0x0805,0x0501,0x0806,0x0601]
);

const _kDarwinHello = TlsClientHello(
	versions: [0x0304,0x0303],
	ciphers: [0x1302,0x1303,0x1301,0xc02c,0xc02b,0xcca9,0xc030,0xc02f,0xcca8,0xc00a,0xc009,0xc014,0xc013,0x009d,0x009c,0x0035,0x002f,0xc008,0xc012,0x000a],
	extensions: [0x0017,0xff01,0x000a,0x000b,0x0010,0x0005,0x000d,0x0012,0x0033,0x002d,0x002b,0x001b],
	signatureAlgorithms: [0x0403,0x0804,0x0401,0x0503,0x0805,0x0805,0x0501,0x0806,0x0601,0x0201]
);

final _defaultHello = Platform.isAndroid ? _kAndroidHello : _kDarwinHello;

(Object, StackTrace)? tlsError;

Future<void> initializeTls() async {
	try {
		final desired = Persistence.settings.cachedWebViewTlsHello ??= await getWebViewHello();
		final current = _defaultHello;

		unsafe(desired, () {
			final desiredCiphers = desired.ciphers.toSet();
			final currentCiphers = current.ciphers.toSet();
			final unionCiphers = desiredCiphers.toSet()..retainAll(currentCiphers);
			desiredCiphers.removeAll(unionCiphers);
			currentCiphers.removeAll(unionCiphers);

			final desiredExtensions = desired.extensions.toSet();
			final currentExtensions = current.extensions.toSet();
			final unionExtensions = desiredExtensions.toSet()..retainAll(currentExtensions);
			desiredExtensions.removeAll(unionExtensions);
			currentExtensions.removeAll(unionExtensions);

			final errors = [];

			if (desired.versions.first != current.versions.first) {
				errors.add('Can\'t change versions ${_stringify(current.versions)} -> ${_stringify(desired.versions)}');
			}

			if (currentCiphers.isNotEmpty) {
				errors.add('Can\'t remove ciphers: ${_stringify(currentCiphers)}');
			}
			if (desiredCiphers.isNotEmpty) {
				errors.add('Can\'t add ciphers: ${_stringify(desiredCiphers)}');
			}

			if (currentExtensions.isNotEmpty) {
				errors.add('Can\'t remove extensions: ${_stringify(currentExtensions)}');
			}
			if (desiredExtensions.isNotEmpty) {
				errors.add('Can\'t add extensions: ${_stringify(desiredExtensions)}');
			}

			if (!setEquals(current.signatureAlgorithms.toSet(), desired.signatureAlgorithms.toSet())) {
				errors.add('Can\'t change signatureAlgorithms: ${_stringify(current.signatureAlgorithms)} -> ${_stringify(desired.signatureAlgorithms)}');
			}

			if (errors.isNotEmpty) {
				throw Exception('TLS error: $errors');
			}
		});
	}
	catch (e, st) {
		Future.error(e, st);
		tlsError = (e, st);
	}
}
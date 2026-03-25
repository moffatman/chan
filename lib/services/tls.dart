import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

const _kTlsExtServerName             = 0x0000;
const _kTlsExtALPN                   = 0x0010;
const _kTlsExtPadding                = 0x0015;
const _kTlsExtCertCompression        = 0x001b;
const _kTlsExtSignatureAlgorithms    = 0x000d;
const _kTlsExtSupportedVersions      = 0x002b;
const _kTlsExtPskKeyExchangeModes    = 0x002d;
const _kTlsExtKeyShare               = 0x0033;
const _kTlsExtApplicationSettingsOld = 0x4469;
const _kTlsExtApplicationSettings    = 0x44cd;
const _kTlsExtEncryptedClientHello   = 0xfe0d;

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
		extensions.removeWhere((e) => e == _kTlsExtServerName || e == _kTlsExtALPN);
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
				if (id == _kTlsExtSignatureAlgorithms) {
					final signatureAlgorithmsLength = extensionsReader.takeUint16();
					signatureAlgorithms.addAll(Iterable.generate(signatureAlgorithmsLength ~/ 2, (_) {
						return extensionsReader.takeUint16();
					}));
				}
				else if (id == _kTlsExtSupportedVersions) {
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

bool? _useEchGrease;
bool? _useAlps;
bool? _useNewAlpsCodePoint;
SecurityContext? _context;

void applyTlsSettings(ClientSetting setting) {
	setting.useEchGrease = _useEchGrease;
	setting.useAlps = _useAlps;
	setting.useNewAlpsCodePoint = _useNewAlpsCodePoint;
	setting.context = _context;
}

const _kAndroidHello = TlsClientHello(
	versions: [0x0304,0x0303],
	ciphers: [0x1303,0x1301,0x1302,0xcca9,0xcca8,0xc02b,0xc02f,0xc02c,0xc030,0xc013,0xc014,0x009c,0x009d,0x002f,0x0035],
	extensions: [0xfe0d,0x0017,0xff01,0x000a,0x000b,0x0023,0x0010,0x0005,0x000d,0x0012,0x0033,0x002d,0x002b,0x001b,0x44cd],
	signatureAlgorithms: [0x0403,0x0804,0x0401,0x0503,0x0805,0x0501,0x0806,0x0601]
);
const _kAndroidCipherList = 'HIGH:MEDIUM:-ECDHE-ECDSA-AES256-SHA:-ECDHE-ECDSA-AES128-SHA';

const _kDarwinHello = TlsClientHello(
	versions: [0x0304,0x0303],
	ciphers: [0x1302,0x1303,0x1301,0xc02c,0xc02b,0xcca9,0xc030,0xc02f,0xcca8,0xc00a,0xc009,0xc014,0xc013,0x009d,0x009c,0x0035,0x002f,0xc008,0xc012,0x000a],
	extensions: [0x0017,0xff01,0x000a,0x000b,0x0010,0x0005,0x000d,0x0012,0x0033,0x002d,0x002b,0x001b],
	signatureAlgorithms: [0x0403,0x0804,0x0401,0x0503,0x0805,0x0805,0x0501,0x0806,0x0601,0x0201]
);

const _kDarwinCipherList = 'HIGH:MEDIUM:DES-CBC3-SHA:ECDHE-ECDSA-DES-CBC3-SHA:ECDHE-RSA-DES-CBC3-SHA';

final _defaultHello = Platform.isAndroid ? _kAndroidHello : _kDarwinHello;
final _defaultCipherList = Platform.isAndroid ? _kAndroidCipherList : _kDarwinCipherList;

const _kCipherNames = {
	0x000a: 'DES-CBC3-SHA',
	0x1301: 'TLS_AES_128_GCM_SHA256',
	0x1302: 'TLS_AES_256_GCM_SHA384',
	0x1303: 'TLS_CHACHA20_POLY1305_SHA256',
	0xc009: 'ECDHE-ECDSA-AES128-SHA',
	0xc00a: 'ECDHE-ECDSA-AES256-SHA',
	0xcc13: 'ECDHE-RSA-CHACHA20-POLY1305-OLD',
	0xcc14: 'ECDHE-ECDSA-CHACHA20-POLY1305-OLD'
};

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

			bool? withCertCompression;
			String? withCipherList;
			TlsProtocolVersion? withMaximumTlsProtocolVersion;
			bool? withAlwaysAddPadding;
			Uint16List? withVerifyAlgorithms;
			final errors = [];

			if (desired.versions.first == 0x0303 && current.versions.first == 0x0304) {
				withMaximumTlsProtocolVersion = TlsProtocolVersion.tls1_2;
				// TLSEXT_TYPE_supported_versions will go away too
				if (!currentExtensions.remove(_kTlsExtSupportedVersions)) {
					// Indicate we shouldn't have removed it
					desiredExtensions.add(_kTlsExtSupportedVersions);
				}
				// TLSEXT_TYPE_psk_key_exchange_modes will go away too
				if (!currentExtensions.remove(_kTlsExtPskKeyExchangeModes)) {
					// Indicate we shouldn't have removed it
					desiredExtensions.add(_kTlsExtPskKeyExchangeModes);
				}
				// TLSEXT_TYPE_key_share will go away too
				if (!currentExtensions.remove(_kTlsExtKeyShare)) {
					// Indicate we shouldn't have removed it
					desiredExtensions.add(_kTlsExtKeyShare);
				}
				// TLSEXT_TYPE_application_settings will go away too
				if (!currentExtensions.remove(_kTlsExtApplicationSettings)) {
					// Indicate we shouldn't have removed it
					desiredExtensions.add(_kTlsExtApplicationSettings);
				}
			}
			else if (desired.versions.first != current.versions.first) {
				errors.add('Can\'t change versions ${_stringify(current.versions)} -> ${_stringify(desired.versions)}');
			}

			String cipherList = _defaultCipherList;

			desiredCiphers.removeWhere((cipher) {
				final nameToAdd = _kCipherNames[cipher];
				if (nameToAdd == null) {
					return false;
				}
				cipherList += ':$nameToAdd';
				return true;
			});

			currentCiphers.removeWhere((cipher) {
				final nameToRemove = _kCipherNames[cipher];
				if (nameToRemove == null) {
					return false;
				}
				cipherList += ':-$nameToRemove';
				return true;
			});

			if (cipherList != _defaultCipherList) {
				withCipherList = cipherList;
			}

			if (currentCiphers.isNotEmpty) {
				errors.add('Can\'t remove ciphers: ${_stringify(currentCiphers)}');
			}
			if (desiredCiphers.isNotEmpty) {
				errors.add('Can\'t add ciphers: ${_stringify(desiredCiphers)}');
			}

			if (desiredExtensions.contains(_kTlsExtApplicationSettingsOld) && currentExtensions.contains(_kTlsExtApplicationSettings)) {
				_useNewAlpsCodePoint = false;
				desiredExtensions.remove(_kTlsExtApplicationSettingsOld);
				currentExtensions.remove(_kTlsExtApplicationSettings);
			}

			if (currentExtensions.contains(_kTlsExtApplicationSettings)) {
				_useAlps = false;
				currentExtensions.remove(_kTlsExtApplicationSettings);
			}

			if (desiredExtensions.contains(_kTlsExtApplicationSettings)) {
				_useAlps = true;
				desiredExtensions.remove(_kTlsExtApplicationSettings);
			}

			if (currentExtensions.contains(_kTlsExtEncryptedClientHello)) {
				_useEchGrease = false;
				currentExtensions.remove(_kTlsExtEncryptedClientHello);
			}

			if (desiredExtensions.contains(_kTlsExtPadding)) {
				withAlwaysAddPadding = true;
				desiredExtensions.remove(_kTlsExtPadding);
			}

			if (currentExtensions.contains(_kTlsExtCertCompression)) {
				withCertCompression = false;
				currentExtensions.remove(_kTlsExtCertCompression);
			}

			if (currentExtensions.isNotEmpty) {
				errors.add('Can\'t remove extensions: ${_stringify(currentExtensions)}');
			}
			if (desiredExtensions.isNotEmpty) {
				errors.add('Can\'t add extensions: ${_stringify(desiredExtensions)}');
			}

			if (!setEquals(current.signatureAlgorithms.toSet(), desired.signatureAlgorithms.toSet())) {
				withVerifyAlgorithms = Uint16List.fromList(desired.signatureAlgorithms);
			}

			if (withCertCompression != null ||
					withCipherList != null ||
					withMaximumTlsProtocolVersion != null ||
					withAlwaysAddPadding != null ||
					withVerifyAlgorithms != null
			) {
				final context = _context = SecurityContext(
					withTrustedRoots: true,
					withCertCompression: withCertCompression ?? true
				);
				if (withMaximumTlsProtocolVersion != null) {
					context.maximumTlsProtocolVersion = withMaximumTlsProtocolVersion;
				}
				if (withCipherList != null) {
					context.setCiphers(withCipherList);
				}
				if (withAlwaysAddPadding != null) {
					context.alwaysAddPadding = withAlwaysAddPadding;
				}
				if (withVerifyAlgorithms != null) {
					context.setVerifyAlgorithms(withVerifyAlgorithms);
				}
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
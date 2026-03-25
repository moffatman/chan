import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chan/services/bytes.dart';
import 'package:chan/services/cloudflare.dart';
import 'package:chan/services/http_client.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/quic_initial_client_hello.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hive/hive.dart';

part 'tls.g.dart';

/// Arbitrary cert that at least presents something
SecurityContext makeSecurityContextWithCert() {
	final context = SecurityContext(withTrustedRoots: true);
	context.useCertificateChainBytes('''-----BEGIN CERTIFICATE-----
MIIEATCCAumgAwIBAgIUZKsDO8Mkb9Zg4yW/k7pFT497vf0wDQYJKoZIhvcNAQEL
BQAwgY8xCzAJBgNVBAYTAkNBMRAwDgYDVQQIDAdPbnRhcmlvMRAwDgYDVQQHDAdU
b3JvbnRvMRIwEAYDVQQKDAltb2ZmYXRtYW4xDzANBgNVBAsMBmNoYW5jZTESMBAG
A1UEAwwJbG9jYWxob3N0MSMwIQYJKoZIhvcNAQkBFhRjYWxsdW1AbW9mZmF0bWFu
LmNvbTAeFw0yNjAzMjAwNDQ5MzVaFw0yNzAzMjAwNDQ5MzVaMIGPMQswCQYDVQQG
EwJDQTEQMA4GA1UECAwHT250YXJpbzEQMA4GA1UEBwwHVG9yb250bzESMBAGA1UE
CgwJbW9mZmF0bWFuMQ8wDQYDVQQLDAZjaGFuY2UxEjAQBgNVBAMMCWxvY2FsaG9z
dDEjMCEGCSqGSIb3DQEJARYUY2FsbHVtQG1vZmZhdG1hbi5jb20wggEiMA0GCSqG
SIb3DQEBAQUAA4IBDwAwggEKAoIBAQDEOVxoMNgtFvpOvZSy8jb9GxrRpFM2sREv
GT+OBIvVOv7okYspV26wqU9O4k3O2u3H5b2yH9IAeHPha5JHG89OEaHV76z4OzBz
DWUHAEKTRpy1NWcpid/zAWGTiipOz2pUClu4t8Rm1lHoUwHRDIoyR680mmuHEAVD
aWukgAkhfWR7JB9eB/IwFJhIO+Zb8Js7SXXFhaAoY8jaC037JDnW/SfZitakawqk
xTuj1rKFpAb46c+mFhaoWl3R4BgFJXR0kLVHWSsMD4LFuTLm1amBJAOPAHYTIhp4
p+qTyCxPcTfxGHra0LSOgY6Ijj5uV8uj1Fb2Zxd0A51G0sf5MOwZAgMBAAGjUzBR
MB0GA1UdDgQWBBQSvOvOXyc4aG26AmHO2HwAv6niRjAfBgNVHSMEGDAWgBQSvOvO
Xyc4aG26AmHO2HwAv6niRjAPBgNVHRMBAf8EBTADAQH/MA0GCSqGSIb3DQEBCwUA
A4IBAQCfqE9aEIMaSpMWaE+KgFW1dEM6UQsna6LcFpOJ9WM/oUvIa/bUyF9zxC2i
N3mrB0bXvU08Gwz65Xa9vI7W8DIJtCIntxtTyRkXx4dmZO/w3QwTDLuP547L9XzW
MvrXBXmOp7/UMCQE6Dx+HzbgGsYC0A4zrJzTe5f5uj84xPgxYoca4w34GcHQi/D9
lpAyxbpoZpDqgPR0vCHRTDoXtNPIg7qRcyDTgmExVBft6Zr5F2Xe+FB0WhKM/rse
ScCFTURkPm605284k0B5tFgi47K+jtkfQmtrOBKnKNLsnRrRqxoVVaLPAsDCK8ZT
CUxI8WZDxeKGW2v9vsR2CzzTawtC
-----END CERTIFICATE-----
'''
			.codeUnits);
	context.usePrivateKeyBytes('''-----BEGIN PRIVATE KEY-----
MIIEvwIBADANBgkqhkiG9w0BAQEFAASCBKkwggSlAgEAAoIBAQDEOVxoMNgtFvpO
vZSy8jb9GxrRpFM2sREvGT+OBIvVOv7okYspV26wqU9O4k3O2u3H5b2yH9IAeHPh
a5JHG89OEaHV76z4OzBzDWUHAEKTRpy1NWcpid/zAWGTiipOz2pUClu4t8Rm1lHo
UwHRDIoyR680mmuHEAVDaWukgAkhfWR7JB9eB/IwFJhIO+Zb8Js7SXXFhaAoY8ja
C037JDnW/SfZitakawqkxTuj1rKFpAb46c+mFhaoWl3R4BgFJXR0kLVHWSsMD4LF
uTLm1amBJAOPAHYTIhp4p+qTyCxPcTfxGHra0LSOgY6Ijj5uV8uj1Fb2Zxd0A51G
0sf5MOwZAgMBAAECggEBAK9dPDJ5hJk3cdgxIdWTFoW5VYyKOTwlnt/ixqPbeETG
hs2+VQpLc0c66P/sy/DUQ7FkptWsDngRLi8FfiNCvVBd/a4+luz5qOEJ1YIeP2Fz
t9VStrGu4JBCabv7vLfWMoaNA0/gHAxz+ZuRo4v6kv9AhVqTrwlzzeBjNKo9Kuvb
moQsZoig0JPNmH3788TiOU4GroPZavcn2hufaVGk2eM8dJS+QvO8wA70xZBRgZj5
tNyqPK75eOFMz6RSr8TZJiUPuudFd5nG+Le+8dssOtznQWkxe5ADGbKCPvho24KJ
bw7s2Qk8Dm21kG+mInOSatugPRDY01HPcYhKGSIlrQkCgYEA/4i8xCv63jb9IQcL
MADi+hahPrGRMujIYz4hpE1bxZmLFHYtGJR80mLs4yDJIQAgWY1mdkChSP85QxuR
S1hXRo9CBnFr3h9yUYUFp6gyWvB3aeqjzZvygkMN2AB2VfYCkR7IDFbnX1WhdqqI
VYkiYYgCcALkKpOoVWZhQgEGEb8CgYEAxJTxRURS9CaObhYitZC1rbroufKALSbo
gHCFavqaqJE7qxg+yhu3M1ZA12s38JFT0USZXRR7PyILqCo9DbKY3AUwVP45doDD
9aYbNFfZObPZp0Syp8b1pbMSRdwqMbPX4IGchzXMv8RJo7zPmyOwuz+sajGqTA2Q
r8FXmRhZyCcCgYEA8+M39yvatjhZhCpK3TgbaoIqx8GGScavazkjtsM2sfQIMDFS
fUFLmSld2rGyBVMvjQlOH9MznI4rwwcOt5DLS8bzR179ivUMkQ2bBhecZ/tWnbqb
OGR9IyKIlf5q80Rn0sZEPLK9BdqezrmYgbrvG5NKcEnyJ0jiww+CCBMeDdUCgYEA
rOHgHe6slZOjByXoeI0/ef461e1y1EK3jt1mOGMUyNKRCzNTZSNixn9AnzLoC2WD
tTMDPVzZ1vf2EHq1HurGjBj0HItHtfQgYlUm762imKCW9gfwpqTPPF5z34R0hymG
3SafpjmmS7AwoxNV8TY+Iy8oTmxHPINhj3AVvcowi1kCgYA3gmEuJ+03yjzdXn4c
DJPGBxEtR5PJAFoJYFHADdtII+vSjCtELveZmKovvmT187O3d4LrujvqXD4u1Hy7
Gjb2D+tgiHHnoCtdONZOhBNajh/WTzNUAWlqP7xDERn967hlgzgxiEnJj6DDSzSd
Y4+cP73grtLlaO1XSwsFLqsYsw==
-----END PRIVATE KEY-----
'''
			.codeUnits);
	return context;
}

const _kGREASE = {
	0x4a4a, 0x5a5a, 0x6a6a, 0x7a7a,
	0x0a0a, 0x1a1a, 0x2a2a, 0x3a3a,
	0x8a8a, 0x9a9a, 0xaaaa, 0xbaba,
	0xcaca, 0xdada, 0xeaea, 0xfafa
};

const _kTlsExtServerName             = 0x0000;
const _kTlsExtStatusRequest          = 0x0005;
const _kTlsExtALPN                   = 0x0010;
const _kTlsExtCertificateTimestamp   = 0x0012;
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
	@HiveField(4, defaultValue: false)
	final bool quic;
	const TlsClientHello({
		required this.versions,
		required this.ciphers,
		required this.extensions,
		required this.signatureAlgorithms,
		required this.quic
	});

	static String _first12Sha256(String str) {
		return sha256.convert(utf8.encode(str)).bytes.take(6).map((c) => c.toRadixString(16).padLeft(2, '0')).join('');
	}

	String get ja4h {
		final buffer = StringBuffer();
		buffer.write(quic ? 'q' : 't');
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
	String toString() => 'TlsClientHello(quic: $quic, versions: [${_stringify(versions)}], ciphers: [${_stringify(ciphers)}], extensions: [${_stringify(extensions)}], signatureAlgorithms: [${_stringify(signatureAlgorithms)}])';
}

TlsClientHello _decodeTlsHandshake(bool quic, Uint8List recordBytes) {
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
			final signatureAlgorithmsLength = extensionsReader.takeUint16() ~/ 2;
			for (int i = 0; i < signatureAlgorithmsLength; i++) {
				final signatureAlgorithm = extensionsReader.takeUint16();
				if (!_kGREASE.contains(signatureAlgorithm)) {
					signatureAlgorithms.add(signatureAlgorithm);
				}
			}
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
	return TlsClientHello(
		versions: versions,
		ciphers: ciphers,
		extensions: extensions,
		signatureAlgorithms: signatureAlgorithms,
		quic: quic
	);
}

Future<TlsClientHello> getTlsHello(Future<void> Function(Uri uri, CancelToken cancelToken) cb, {bool webTransportTrick = false}) async {
	final localhost = InternetAddress.loopbackIPv4;
	ServerSocket? tcpServer;
	StreamSubscription<Socket>? tcpSub;
	RawDatagramSocket? udpServer;
	HttpServer? httpsServer;
	StreamSubscription<RawSocketEvent>? udpSub;
	final completer = Completer<TlsClientHello>();
	final cancelToken = CancelToken();
	try {
		final h2s = httpsServer = await HttpServer.bindSecure(localhost, 0, makeSecurityContextWithCert());
		httpsServer.listen((request) async {
			final bytes = utf8.encode('''<!DOCTYPE html>
<html lang="en">
<head>
		<meta charset="UTF-8">
</head>
<body>
		<script type="text/javascript">
			async function main() {
				const transport = new WebTransport("https://127.0.0.1:${tcpServer?.port}");
				await transport.ready;
			}
			main();
		</script>
</body>
</html>''');
			request.response.headers.contentType = ContentType.html;
			request.response.contentLength = bytes.length;
			request.response.add(bytes);
			await request.response.close();
		});
		Future<void> handoffHttps(Socket socket, AsyncByteReader reader) async {
			final socket1 = await Socket.connect(localhost, h2s.port);
			socket1.listen(socket.add, onDone: socket.close, onError: socket.addError, cancelOnError: true);
			reader.replay().listen(socket1.add, onDone: socket1.close, onError: socket1.addError, cancelOnError: true);
		}

		tcpServer = await ServerSocket.bind(localhost, 0);
		tcpSub = tcpServer.listen((socket) async {
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
				if (webTransportTrick) {
					handoffHttps(socket, record);
					await Future.delayed(const Duration(seconds: 3));
					if (!completer.isCompleted) {
						// Nothing came from webTransport
						completer.complete(_decodeTlsHandshake(false, recordBytes));
					}
					socket.close();
					return;
				}
				Future.delayed(const Duration(seconds: 1), socket.close);
				completer.complete(_decodeTlsHandshake(false, recordBytes));
			}
			catch (e, st) {
				if (!completer.isCompleted) {
					completer.completeError(e, st);
				}
			}
			finally {
				record.dispose();
			}
		});
		udpServer = await RawDatagramSocket.bind(localhost, tcpServer.port);
		final decoder = QuicInitialClientHelloDecoder();
		udpSub = udpServer.listen((event) async {
			if (event == RawSocketEvent.read) {
				final datagram = udpServer?.receive();
				if (datagram != null) {
					final hello = decoder.addDatagram(datagram.data);
					if (hello != null) {
						try {
							completer.complete(_decodeTlsHandshake(true, hello));
						}
						catch (e, st) {
							if (!completer.isCompleted) {
								completer.completeError(e, st);
							}
						}
					}
				}
			}
		});
		cb(Uri.https(localhost.address).replace(port: tcpServer.port), cancelToken).then((_) => null, onError: (_) => null);
		final clientHello = await completer.future.timeout(const Duration(seconds: 5));
		return clientHello;
	}
	finally {
		await udpSub?.cancel();
		await tcpSub?.cancel();
		udpServer?.close();
		await tcpServer?.close();
		await httpsServer?.close();
		cancelToken.cancel();
	}
}

Future<TlsClientHello> getDioHello({required Dio client, required bool cloudflare, required bool http3}) {
	return getTlsHello((uri, cancelToken) => client.getUri(uri, options: Options(
		extra: {
			kCloudflare: cloudflare,
			kPriority: RequestPriority.lowest
		},
		preferHttp3WithoutAltSvc: http3
		), cancelToken: cancelToken),
		webTransportTrick: http3 && cloudflare && Platform.isAndroid
	);
}

Future<TlsClientHello> getWebViewHello({required bool http3}) async {
	return getTlsHello((uri, cancelToken) async {
		final webView = HeadlessInAppWebView(
			onReceivedServerTrustAuthRequest: (controller, challenge) async {
				// This only works on Android. need it to get through wrong certificate
				return ServerTrustAuthResponse(
						action: ServerTrustAuthResponseAction.PROCEED);
			},
			initialSettings: InAppWebViewSettings(
				cacheMode: CacheMode.LOAD_DEFAULT,
				cacheEnabled: true,
				allowFileAccess: true,
				allowContentAccess: true,
				allowFileAccessFromFileURLs: true,
				allowUniversalAccessFromFileURLs: true,
			),
			initialUrlRequest: URLRequest(
				url: WebUri.uri(uri),
				assumesHTTP3Capable: http3
			)
		);
		await webView.run();
		await cancelToken.whenCancel;
		webView.dispose();
	}, webTransportTrick: http3 && Platform.isAndroid);
}

class _TlsSettings {
	bool? useEchGrease;
	bool? useAlps;
	bool? useNewAlpsCodePoint;
	SecurityContext? context;
}

final _tlsSettings = _TlsSettings();
final _tlsSettings3 = _TlsSettings();
bool enableQuic = false;

HttpClientAdapter myHttpClientAdapter = MyHttpClientAdapter2();

void applyTlsSettings(ClientSetting setting) {
	setting.useEchGrease = _tlsSettings.useEchGrease;
	setting.useAlps = _tlsSettings.useAlps;
	setting.useNewAlpsCodePoint = _tlsSettings.useNewAlpsCodePoint;
	setting.context = _tlsSettings.context;
}

void applyTlsSettings3(ClientSetting setting) {
	setting.useEchGrease = _tlsSettings3.useEchGrease;
	setting.useAlps = _tlsSettings3.useAlps;
	setting.useNewAlpsCodePoint = _tlsSettings3.useNewAlpsCodePoint;
	setting.context = _tlsSettings3.context;
}

const _kAndroidHello = TlsClientHello(
	versions: [0x0304,0x0303],
	ciphers: [0x1303,0x1301,0x1302,0xcca9,0xcca8,0xc02b,0xc02f,0xc02c,0xc030,0xc013,0xc014,0x009c,0x009d,0x002f,0x0035],
	extensions: [0xfe0d,0x0017,0xff01,0x000a,0x000b,0x0023,0x0010,0x0005,0x000d,0x0012,0x0033,0x002d,0x002b,0x001b,0x44cd],
	signatureAlgorithms: [0x0403,0x0804,0x0401,0x0503,0x0805,0x0501,0x0806,0x0601],
	quic: false
);
const _kAndroidHello3 = TlsClientHello(
	versions: [0x0304],
	ciphers: [0x1303,0x1301,0x1302],
	extensions: [0xfe0d,0x000a,0x0010,0x0005,0x000d,0x0012,0x0033,0x002d,0x002b,0x0039,0x001b,0x44cd],
	signatureAlgorithms: [0x0403,0x0804,0x0401,0x0503,0x0805,0x0501,0x0806,0x0601],
	quic: true
);

const _kDarwinHello = TlsClientHello(
	versions: [0x0304,0x0303],
	ciphers: [0x1302,0x1303,0x1301,0xc02b,0xc02f,0xc02c,0xc030,0xcca9,0xcca8,0xc009,0xc013,0xc00a,0xc014,0x009c,0x009d,0x002f,0x0035,0x000a,0xc008,0xc012],
	extensions: [0x0017,0xff01,0x000a,0x000b,0x0010,0x0005,0x000d,0x0012,0x0033,0x002d,0x002b,0x001b],
	signatureAlgorithms: [0x0403,0x0804,0x0401,0x0503,0x0805,0x0805,0x0501,0x0806,0x0601,0x0201],
	quic: false
);
const _kDarwinHello3 = TlsClientHello(
	versions: [0x0304],
	ciphers: [0x1301,0x1302,0x1303],
	extensions: [0x000a,0x0010,0x0005,0x000d,0x0012,0x0033,0x002d,0x002b,0x0039,0x001b],
	signatureAlgorithms: [0x0403,0x0804,0x0401,0x0503,0x0805,0x0805,0x0501,0x0806,0x0601,0x0201],
	quic: true
);

final _defaultHello = Platform.isAndroid ? _kAndroidHello : _kDarwinHello;
final _defaultHello3 = Platform.isAndroid ? _kAndroidHello3 : _kDarwinHello3;

const _kVersions = {
	0x0301: TlsProtocolVersion.tls1,
	0x0302: TlsProtocolVersion.tls1_1,
	0x0303: TlsProtocolVersion.tls1_2,
	0x0304: TlsProtocolVersion.tls1_3
};

const _kCipherNames = {
	0x000a: 'DES-CBC3-SHA',
	0x002f: 'AES128-SHA',
	0x0035: 'AES256-SHA',
	0x008c: 'PSK-AES128-CBC-SHA',
	0x008d: 'PSK-AES256-CBC-SHA',
	0x009c: 'AES128-GCM-SHA256',
	0x009d: 'AES256-GCM-SHA384',
	0x1301: 'TLS_AES_128_GCM_SHA256',
	0x1302: 'TLS_AES_256_GCM_SHA384',
	0x1303: 'TLS_CHACHA20_POLY1305_SHA256',
	0xc008: 'ECDHE-ECDSA-DES-CBC3-SHA',
	0xc009: 'ECDHE-ECDSA-AES128-SHA',
	0xc00a: 'ECDHE-ECDSA-AES256-SHA',
	0xc012: 'ECDHE-RSA-DES-CBC3-SHA',
	0xc013: 'ECDHE-RSA-AES128-SHA',
	0xc014: 'ECDHE-RSA-AES256-SHA',
	0xc027: 'ECDHE-RSA-AES128-SHA256',
	0xc02b: 'ECDHE-ECDSA-AES128-GCM-SHA256',
	0xc02c: 'ECDHE-ECDSA-AES256-GCM-SHA384',
	0xc02f: 'ECDHE-RSA-AES128-GCM-SHA256',
	0xc030: 'ECDHE-RSA-AES256-GCM-SHA384',
	0xc035: 'ECDHE-PSK-AES128-CBC-SHA',
	0xc036: 'ECDHE-PSK-AES256-CBC-SHA',
	0xcc13: 'ECDHE-RSA-CHACHA20-POLY1305-OLD',
	0xcc14: 'ECDHE-ECDSA-CHACHA20-POLY1305-OLD',
	0xcca8: 'ECDHE-RSA-CHACHA20-POLY1305',
	0xcca9: 'ECDHE-ECDSA-CHACHA20-POLY1305',
	0xccab: 'ECDHE-PSK-CHACHA20-POLY1305',
};

(Object, StackTrace)? tlsError;
(Object, StackTrace)? tlsError3;

void _initializeTls({
	required bool quic,
	required TlsClientHello desired,
	required TlsClientHello current,
	required _TlsSettings settings,
}) =>
		unsafeVoid(desired, () {

			final desiredExtensions = desired.extensions.toSet();
			final currentExtensions = current.extensions.toSet();
			final unionExtensions = desiredExtensions.toSet()..retainAll(currentExtensions);
			desiredExtensions.removeAll(unionExtensions);
			currentExtensions.removeAll(unionExtensions);

			bool? withCertCompression;
			String? withCipherList;
			TlsProtocolVersion withMinimumTlsProtocolVersion = TlsProtocolVersion.tls1_2;
			TlsProtocolVersion withMaximumTlsProtocolVersion = TlsProtocolVersion.tls1_3;
			bool? withAlwaysAddPadding;
			Uint16List? withVerifyAlgorithms;
			bool? withOcspStapling;
			bool? withSignedCertTimestamps;
			final errors = [];

			final desiredVersions = desired.versions.toList()..sort();
			if (desiredVersions.isNotEmpty) {
				withMinimumTlsProtocolVersion = _kVersions[desiredVersions.first] ?? TlsProtocolVersion.tls1_2;
				withMaximumTlsProtocolVersion = _kVersions[desiredVersions.last] ?? TlsProtocolVersion.tls1_3;
			}

			if (withMaximumTlsProtocolVersion == withMinimumTlsProtocolVersion && !quic) {
				// TLSEXT_TYPE_supported_versions will go away
				if (!currentExtensions.remove(_kTlsExtSupportedVersions)) {
					// Indicate we shouldn't have removed it
					desiredExtensions.add(_kTlsExtSupportedVersions);
				}
			}
			if (withMaximumTlsProtocolVersion != TlsProtocolVersion.tls1_3) {
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

			if (
				// TLS 1.3 ciphers are not configurable
				withMinimumTlsProtocolVersion != TlsProtocolVersion.tls1_3
				&& !listEquals(desired.ciphers, current.ciphers)
			) {
				withCipherList = desired.ciphers.tryMap((code) {
					final name = _kCipherNames[code];
					if (name == null) {
						errors.add('Can\'t add cipher 0x${code.toRadixString(16).padLeft(4, '0')}');
					}
					return name;
				}).join(':');
			}

			if (desiredExtensions.contains(_kTlsExtApplicationSettingsOld) && currentExtensions.contains(_kTlsExtApplicationSettings)) {
				settings.useNewAlpsCodePoint = false;
				desiredExtensions.remove(_kTlsExtApplicationSettingsOld);
				currentExtensions.remove(_kTlsExtApplicationSettings);
			}

			if (currentExtensions.contains(_kTlsExtApplicationSettings)) {
				settings.useAlps = false;
				currentExtensions.remove(_kTlsExtApplicationSettings);
			}

			if (desiredExtensions.contains(_kTlsExtApplicationSettings)) {
				settings.useAlps = true;
				desiredExtensions.remove(_kTlsExtApplicationSettings);
			}

			if (currentExtensions.contains(_kTlsExtEncryptedClientHello)) {
				settings.useEchGrease = false;
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

			if (currentExtensions.contains(_kTlsExtStatusRequest)) {
				withOcspStapling = false;
				currentExtensions.remove(_kTlsExtStatusRequest);
			}

			if (currentExtensions.contains(_kTlsExtCertificateTimestamp)) {
				withSignedCertTimestamps = false;
				currentExtensions.remove(_kTlsExtCertificateTimestamp);
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
					withMinimumTlsProtocolVersion != TlsProtocolVersion.tls1_2 ||
					withMaximumTlsProtocolVersion != TlsProtocolVersion.tls1_3 ||
					withAlwaysAddPadding != null ||
					withVerifyAlgorithms != null ||
					withOcspStapling != null ||
					withSignedCertTimestamps != null
			) {
				final context = settings.context = SecurityContext(
					withTrustedRoots: true,
					withCertCompression: withCertCompression ?? true,
					withOcspStapling: withOcspStapling ?? true,
					withSignedCertTimestamps: withSignedCertTimestamps ?? true
				);
				if (withMinimumTlsProtocolVersion != TlsProtocolVersion.tls1_2) {
					context.minimumTlsProtocolVersion = withMinimumTlsProtocolVersion;
				}
				if (withMaximumTlsProtocolVersion != TlsProtocolVersion.tls1_3) {
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

Future<void> initializeTls() async {
	try {
		_initializeTls(
			quic: false,
			desired: Persistence.settings.cachedWebViewTlsHello ??=
					await getWebViewHello(http3: false),
			current: _defaultHello,
			settings: _tlsSettings
		);
	}
	catch (e, st) {
		Future.error(e, st);
		tlsError = (e, st);
	}
	try {
		if (_defaultHello3.quic) {
			final hello3 = Persistence.settings.cachedWebViewTlsHello3 ??= await getWebViewHello(http3: true);
			if (hello3.quic) {
				myHttpClientAdapter = MyHttpClientAdapter3();
				enableQuic = true;
				_initializeTls(
					quic: true,
					desired: hello3,
					current: _defaultHello3,
					settings: _tlsSettings3
				);
			}
			else {
				print('QUIC not supported by WebView');
			}
		}
		else {
			print('QUIC not supported by Dart');
		}
	}
	catch (e, st) {
		Future.error(e, st);
		tlsError3 = (e, st);
	}
}


import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chan/services/persistence.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mutex/mutex.dart';

// It doesn't work on iOS. no way to trust the cert.
const _kSecure = false;

class WebViewIntrospection {
	final _lock = Mutex();
	WebViewIntrospection._();

	Future<Map<String, String>> _getDefaultHeaders() async {
		final HttpServer server;
		final Uri uri;
		if (_kSecure) {
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
'''.codeUnits);
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
'''.codeUnits);
			server = await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, context);
			uri = Uri.https('localhost').replace(port: server.port);
		}
		else {
			server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
			uri = Uri.http('localhost').replace(port: server.port);
		}
		try {
			final headersCompleter = Completer<HttpHeaders>();
			server.listen((request) async {
				if (!headersCompleter.isCompleted) {
					headersCompleter.complete(request.headers);
				}
				request.response.statusCode = HttpStatus.ok;
				request.response.add(utf8.encode('hello world'));
				await request.response.close();
			});
			final webView = HeadlessInAppWebView(
				initialUrlRequest: URLRequest(
					url: WebUri.uri(uri)
				)
			);
			try {
				await webView.run();
				final headers = await headersCompleter.future.timeout(const Duration(seconds: 3));
				final out = <String, String>{};
				headers.forEach((key, values) => out[key.toLowerCase()] = values.join(','));
				// These are already handled properly
				out.remove(HttpHeaders.acceptEncodingHeader);
				out.remove(HttpHeaders.hostHeader);
				out.remove(HttpHeaders.cookieHeader);
				out.remove(HttpHeaders.userAgentHeader);
				out.remove(HttpHeaders.connectionHeader);
				// Because we are using http
				out.remove('upgrade-insecure-requests');
				return out;
			}
			finally {
				webView.dispose();
			}
		}
		finally {
			server.close(force: true);
		}
	}

	Future<Map<String, String>> getDefaultHeaders() => _lock.protect(() async {
		return Persistence.settings.cachedWebViewHeaders ??= await _getDefaultHeaders();
	});

	static WebViewIntrospection? _instance;
	static WebViewIntrospection get instance => _instance ??= WebViewIntrospection._();
}

import 'package:chan/services/tls.dart';
import 'package:dio/dio.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import 'package:dio_http2_adapter/dio_http3_adapter.dart';
import 'package:test/test.dart';

class MyHttpClientAdapter3 extends Http3Adapter {
	final TlsSettings settings;

	MyHttpClientAdapter3(this.settings) : super(Http3ConnectionManager(
		tcpConnectionManager: ConnectionManager(
			onClientCreate: (url, setting) {
				setting.useEchGrease = settings.useEchGrease;
				setting.useAlps = settings.useAlps;
				setting.useNewAlpsCodePoint = settings.useNewAlpsCodePoint;
				setting.context = settings.context;
			}
		),
		onClientCreate: (url, setting) {
			setting.useEchGrease = settings.useEchGrease;
			setting.useAlps = settings.useAlps;
			setting.useNewAlpsCodePoint = settings.useNewAlpsCodePoint;
			setting.context = settings.context;
		},
		useNativeUdp: true,
		preferHttp3WithoutAltSvc: false
	));
}

Future<void> Function() makeTlsTest(TlsClientHello desiredHello) => () async {
	final current = Dio();
	// Enable http3
	current.httpClientAdapter = MyHttpClientAdapter3(TlsSettings());
	final currentHello = await getDioHello(client: current, cloudflare: false, http3: desiredHello.quic);
	final settings = TlsSettings();
	prepareTlsSettings(quic: desiredHello.quic, desired: desiredHello, current: currentHello, settings: settings);
	final desired = Dio();
	desired.httpClientAdapter = MyHttpClientAdapter3(settings);
	final effectiveHello = await getDioHello(client: desired, cloudflare: false, http3: desiredHello.quic);
	expect(effectiveHello.quic, desiredHello.quic);
	expect(effectiveHello.ciphers, desiredHello.ciphers);
	expect(effectiveHello.extensions, desiredHello.extensions);
	expect(effectiveHello.signatureAlgorithms, desiredHello.signatureAlgorithms);
	expect(effectiveHello.versions, desiredHello.versions);
	expect(effectiveHello.ja4h, desiredHello.ja4h);
};

void main() {
	test('kAndroidHello', makeTlsTest(TlsClientHello(
		ciphers: kAndroidHello.ciphers,
		versions: kAndroidHello.versions,
		// TLSEXT_TYPE_session_ticket is hardcoded for Android at compile-time
		// Don't try to enable it
		extensions: kAndroidHello.extensions.toList()..remove(0x0023),
		signatureAlgorithms: kAndroidHello.signatureAlgorithms,
		quic: kAndroidHello.quic
	)));
	test('kAndroidHello3', makeTlsTest(kAndroidHello3));
	test('kDarwinHello', makeTlsTest(kDarwinHello));
	test('kDarwinHello3', makeTlsTest(kDarwinHello3));
}

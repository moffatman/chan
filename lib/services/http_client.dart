import 'package:chan/services/bad_certificate.dart';
import 'package:chan/services/tls.dart';
import 'package:dio/adapter.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import 'package:dio_http2_adapter/dio_http3_adapter.dart';

class MyHttpClientAdapter1 extends DefaultHttpClientAdapter {
	MyHttpClientAdapter1() {
		onHttpClientCreate = (client) {
			return client..badCertificateCallback = badCertificateCallback;
		};
	}
}

class MyHttpClientAdapter2 extends Http2Adapter {
	MyHttpClientAdapter2() : super(ConnectionManager(
		onClientCreate: (url, setting) {
			setting.onBadCertificate = (cert) => badCertificateCallback(cert, url.host, url.port);
			applyTlsSettings(setting);
		}
	));
}

class MyHttpClientAdapter3 extends Http3Adapter {
	MyHttpClientAdapter3({
		bool preferHttp3WithoutAltSvc = false
	}) : super(Http3ConnectionManager(
		tcpConnectionManager: ConnectionManager(
			onClientCreate: (url, setting) {
				setting.onBadCertificate = (cert) => badCertificateCallback(cert, url.host, url.port);
				applyTlsSettings(setting);
			}
		),
		onClientCreate: (url, setting) {
			setting.onBadCertificate = (cert) => badCertificateCallback(cert, url.host, url.port);
			applyTlsSettings3(setting);
		},
		useNativeUdp: true,
		preferHttp3WithoutAltSvc: preferHttp3WithoutAltSvc
	));
}

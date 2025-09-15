import 'package:chan/services/bad_certificate.dart';
import 'package:dio/adapter.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';

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
		}
	));
}

typedef MyHttpClientAdapter = MyHttpClientAdapter2;

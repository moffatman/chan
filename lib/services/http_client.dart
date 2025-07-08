import 'package:chan/services/bad_certificate.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';

class MyHttpClientAdapter extends Http2Adapter {
	MyHttpClientAdapter() : super(ConnectionManager(
		onClientCreate: (url, setting) {
			setting.onBadCertificate = (cert) => badCertificateCallback(cert, url.host, url.port);
		}
	));
}

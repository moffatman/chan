import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/adapter.dart';

final _sha1s = {
	// wizchan.org expired "Wednesday, May 15, 2024 at 5:49:26 AM"
	'a053375bfe84e8b748782c7cee15827a6af5a405'
};

bool badCertificateCallback(X509Certificate cert, String host, int port) {
	return _sha1s.contains(Digest(cert.sha1).toString());
}

class BadCertificateHttpClientAdapter extends DefaultHttpClientAdapter {
	BadCertificateHttpClientAdapter() {
		onHttpClientCreate = (HttpClient client) {
			client.badCertificateCallback = badCertificateCallback;
			return client;
		};
	}
}

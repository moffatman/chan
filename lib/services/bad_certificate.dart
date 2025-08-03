import 'dart:io';

import 'package:crypto/crypto.dart';

final _sha1s = {
	// wizchan.org expired "Wednesday, May 15, 2024 at 5:49:26 AM"
	'a053375bfe84e8b748782c7cee15827a6af5a405',
	// 8chan.moe expired "Sunday, August 3, 2025 at 3:16:37 PM"
	'00abefd055f9a9c784ffdeabd1dcdd8fed741436'
};

bool badCertificateCallback(X509Certificate cert, String host, int port) {
	return _sha1s.contains(Digest(cert.sha1).toString());
}

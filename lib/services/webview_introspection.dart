
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chan/services/persistence.dart';
import 'package:chan/services/tls.dart';
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
			server = await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, makeSecurityContextWithCert());
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

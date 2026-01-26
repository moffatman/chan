
import 'dart:convert';
import 'dart:io';

import 'package:chan/services/cloudflare.dart';
import 'package:chan/services/settings.dart';
import 'package:dio/dio.dart';
import 'package:mutex/mutex.dart';

class WebViewIntrospection {
	final _lock = Mutex();
	Map<String, String>? _defaultHeaders;
	WebViewIntrospection._();

	Future<Map<String, String>> _getDefaultHeaders() async {
		final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
		try {
			HttpHeaders? headers;
			server.listen((request) async {
				headers ??= request.headers;
				request.response.statusCode = HttpStatus.ok;
				request.response.add(utf8.encode('hello world'));
				await request.response.close();
			});
			await Settings.instance.client.getUri(Uri.http('${server.address.host}:${server.port}'), options: Options(
				extra: {
					kCloudflare: true
				}
			));
			final out = <String, String>{};
			headers!.forEach((key, values) => out[key.toLowerCase()] = values.join(','));
			// These are already handled properly
			out.remove(HttpHeaders.acceptEncodingHeader);
			out.remove(HttpHeaders.hostHeader);
			out.remove(HttpHeaders.cookieHeader);
			out.remove(HttpHeaders.userAgentHeader);
			// Because we are using http
			out.remove('upgrade-insecure-requests');
			return out;
		}
		finally {
			server.close(force: true);
		}
	}

	Future<Map<String, String>> getDefaultHeaders() => _lock.protect(() async {
		return _defaultHeaders ??= await _getDefaultHeaders();
	});

	static WebViewIntrospection? _instance;
	static WebViewIntrospection get instance => _instance ??= WebViewIntrospection._();
}

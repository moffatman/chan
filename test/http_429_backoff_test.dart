import 'dart:io';

import 'package:chan/services/http_429_backoff.dart';
import 'package:dio/dio.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
	for (final accept429Response in [true, false]) {
		test('redirected 429 retry exhaustion releases the host queue '
				'(${accept429Response ? 'onResponse' : 'onError'})', () async {
		final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
		var redirects = 0;
		var rateLimitedResponses = 0;
		var successfulResponses = 0;
		server.listen((request) async {
			switch (request.uri.path) {
				case '/start':
					redirects++;
					request.response
						..statusCode = HttpStatus.found
						..headers.set(HttpHeaders.locationHeader, '/rate-limited');
				case '/rate-limited':
					rateLimitedResponses++;
					request.response
						..statusCode = HttpStatus.tooManyRequests
						..headers.set(HttpHeaders.retryAfterHeader, '0');
				case '/after':
					successfulResponses++;
					request.response
						..statusCode = HttpStatus.ok
						..write('ok');
				default:
					request.response.statusCode = HttpStatus.notFound;
			}
			await request.response.close();
		});

		final authority = '${server.address.address}:${server.port}';
		final startUri = Uri.http(authority, '/start');
		final afterUri = Uri.http(authority, '/after');
		final client = accept429Response
				? Dio(BaseOptions(validateStatus: (_) => true))
				: Dio();
		client.interceptors.add(
			HTTP429BackoffInterceptor(client: client, maxRetries: 5),
		);
		client.httpClientAdapter = Http2Adapter(ConnectionManager());

		try {
			await expectLater(
				client.getUri<void>(startUri).timeout(const Duration(seconds: 35)),
				throwsA(
					isA<DioError>()
						.having(
							(error) => error.error,
							'error',
							isA<Http429Exception>().having(
								(error) => error.retriesAttempted,
								'retriesAttempted',
								5,
							),
						)
						.having(
							(error) => error.requestOptions.extra['_retryCount'],
							'outer request retry count',
							isNull,
						)
						.having(
							(error) => error.response?.requestOptions.extra['_retryCount'],
							'outer response retry count',
							5,
						),
				),
			);
			expect(redirects, 6);
			expect(rateLimitedResponses, 6);

			final response = await client
					.getUri<String>(afterUri)
					.timeout(const Duration(seconds: 2));
			expect(response.statusCode, HttpStatus.ok);
			expect(response.data, 'ok');
			expect(successfulResponses, 1);
		}
		finally {
			client.close(force: true);
			await server.close(force: true);
		}
		}, timeout: const Timeout(Duration(seconds: 45)));
	}
}

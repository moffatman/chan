import 'dart:async';
import 'dart:typed_data';

import 'package:chan/services/http_429_backoff.dart';
import 'package:chan/services/http_rate_limit.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
	final ResponseBody Function(RequestOptions) respond;
	_Adapter(this.respond);

	@override
	Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<dynamic>? cancelFuture) async => respond(options);

	@override
	void close({bool force = false}) {}
}

void main() {
	Dio newClient(ResponseBody Function(RequestOptions) respond, {bool acceptErrors = false}) {
		final client = Dio(BaseOptions(validateStatus: acceptErrors ? (_) => true : null));
		client.interceptors.add(XRateLimitInterceptor());
		client.interceptors.add(HTTP429BackoffInterceptor(client: client));
		client.httpClientAdapter = _Adapter(respond);
		addTearDown(() => client.close(force: true));
		return client;
	}

	test('decimal budgets pace requests and exhaustion waits for reset', () {
		Headers headers(String remaining, String reset) => Headers.fromMap({
			'x-ratelimit-remaining': [remaining],
			'x-ratelimit-reset': [reset]
		});
		expect(getRateLimitDelay(headers('76.0', '71')), const Duration(milliseconds: 935));
		for (final remaining in ['0.0', '-1', '0.5']) {
			expect(getRateLimitDelay(headers(remaining, '71')), const Duration(seconds: 71));
		}
		for (final malformed in ['bad', 'NaN', 'Infinity']) {
			expect(getRateLimitDelay(headers(malformed, '71')), isNull);
			expect(getRateLimitDelay(headers('76', malformed)), isNull);
		}
		expect(getRateLimitDelay(Headers()), isNull);
	});

	for (final status in [200, 403]) {
		test('status $status paces clients without changing the 429 queue', () async {
			final uri = Uri.parse('https://separate-$status.example/test');
			final calls = <Duration>[];
			final stopwatch = Stopwatch()..start();
			ResponseBody respond(RequestOptions options) {
				calls.add(stopwatch.elapsed);
				return ResponseBody.fromString('ok', calls.length == 1 ? status : 200, headers: {
					'x-ratelimit-remaining': ['10.0'],
					'x-ratelimit-reset': ['1.5']
				});
			}
			final first = newClient(respond);
			final second = newClient(respond);
			if (status == 200) {
				await first.getUri<String>(uri);
			}
			else {
				await expectLater(first.getUri<String>(uri), throwsA(isA<DioError>()));
			}
			expect(http429Queue.getCurrentDelay(uri), Duration.zero);
			await Future.wait([first.getUri<String>(uri), second.getUri<String>(uri)]);
			expect(calls, hasLength(3));
			expect(calls[1] - calls[0], greaterThanOrEqualTo(const Duration(milliseconds: 140)));
			expect(calls[2] - calls[1], greaterThanOrEqualTo(const Duration(milliseconds: 140)));
		});
	}

	test('short budget waits allow cancellation independently', () async {
		final uri = Uri.parse('https://separate-cancel.example/test');
		var calls = 0;
		final client = newClient((options) {
			calls++;
			return ResponseBody.fromString('ok', 200, headers: {
				'x-ratelimit-remaining': ['0'],
				'x-ratelimit-reset': ['0.5']
			});
		});
		final queueKey = RequestOptions(path: uri.toString());
		addTearDown(() => httpRateLimitQueue.reset(queueKey));
		await client.getUri<String>(uri);
		final token = CancelToken();
		final pending = client.getUri<String>(uri,
			cancelToken: token,
			options: Options(extra: {kPriority: RequestPriority.interactive})
		);
		final cancelled = expectLater(pending,
			throwsA(isA<DioError>().having((error) => error.type, 'type', DioErrorType.cancel))
		);
		await Future<void>.delayed(const Duration(milliseconds: 20));
		token.cancel();
		await cancelled;
		expect(calls, 1);
		expect(http429Queue.getCurrentDelay(uri), Duration.zero);
	});

	for (final entry in [
		(RequestPriority.lowest, '0', '1'),
		(RequestPriority.interactive, '0', '20'),
		(RequestPriority.functional, '0', '71'),
		(RequestPriority.functional, '2', '150')
	]) {
		test('rejects unacceptable budget wait $entry before entering either queue', () async {
			final (priority, remaining, reset) = entry;
			final uri = Uri.parse('https://limit-${priority.name}-$remaining-$reset.example/test');
			var calls = 0;
			final client = newClient((options) {
				calls++;
				return ResponseBody.fromString('ok', 200, headers: calls == 1 ? {
					'x-ratelimit-remaining': [remaining],
					'x-ratelimit-reset': [reset]
				} : {});
			});
			final key = RequestOptions(path: uri.toString());
			addTearDown(() => httpRateLimitQueue.reset(key));
			await client.getUri<String>(uri);
			HttpRateLimitException? rejection;
			try {
				await client.getUri<String>(uri, options: Options(extra: {kPriority: priority}));
				fail('Expected a rate-limit exception');
			}
			on DioError catch (error) {
				expect(error.error, isA<HttpRateLimitException>());
				rejection = error.error as HttpRateLimitException;
			}
			expect(rejection.exhausted, remaining == '0');
			expect(rejection.waitUntil.isAfter(DateTime.now()), isTrue);
			expect(rejection.isReportable, isFalse);
			expect(isExceptionReAttemptable(RequestPriority.functional, rejection), isTrue);
			expect(calls, 1);
			expect(http429Queue.getCurrentDelay(uri), Duration.zero);
			// Independent queue reset releases later requests and clears pacing.
			await rejection.remedies['Reset timer']!(_FakeBuildContext());
			await client.getUri<String>(uri).timeout(const Duration(seconds: 1));
			expect(calls, 2);
		});
	}

	for (final acceptErrors in [true, false]) {
		test('429 retry and queued sibling complete without deadlock ($acceptErrors)', () async {
			final uri = Uri.parse('https://separate-retry-$acceptErrors.example/retry');
			var retryCalls = 0;
			final client = newClient((options) {
				final limited = options.uri.path == '/retry' && ++retryCalls == 1;
				return ResponseBody.fromString('ok', limited ? 429 : 200, headers: limited ? {
					'retry-after': ['0'],
					'x-ratelimit-remaining': ['0'],
					'x-ratelimit-reset': ['0.15']
				} : {});
			}, acceptErrors: acceptErrors);
			final retry = client.getUri<String>(uri);
			await Future<void>.delayed(const Duration(milliseconds: 30));
			final sibling = client.getUri<String>(uri.replace(path: '/sibling'));
			final responses = await Future.wait([retry, sibling]).timeout(const Duration(seconds: 5));
			expect(responses.map((response) => response.statusCode), everyElement(200));
			expect(retryCalls, 2);
		});
	}
}

class _FakeBuildContext extends Fake implements BuildContext {}

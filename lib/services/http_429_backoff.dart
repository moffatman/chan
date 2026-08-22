import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:chan/services/cloudflare.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/interceptor.dart';
import 'package:chan/services/priority_queue.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

final http429Queue = PriorityQueue<Uri, String>(
	groupKeyer: (uri) => uri.host
);

const _kExtraRetriesKey = '_retryCount';

class Http429Exception extends ExtendedException {
	final Uri url;
	final DateTime waitUntil;
	final int retriesAttempted;
	Http429Exception(this.url, this.waitUntil, this.retriesAttempted);

	@override
	bool get isReportable => false;

	@override
	Map<String, FutureOr<void> Function(BuildContext)> get remedies => {
		'Reset timer': (context) {
			http429Queue.reset(url);
			http429Queue.prioritize(url);
		}
	};

	@override
	String toString() => 'Http429Exception(url: $url, waitUntil: $waitUntil, retriesAttempted: $retriesAttempted)';
}

extension _Retries on RequestOptions {
	int get retries => switch (extra[_kExtraRetriesKey]) {
		int r => r,
		_ => 0
	};
}

Duration get429Delay(String? retryAfter, int currentRetries) {
	int? seconds;
	if (retryAfter != null) {
		seconds = int.tryParse(retryAfter);
		if (seconds == null) {
			try {
				final d = HttpDate.parse(retryAfter);
				final diff = d.difference(DateTime.now());
				// Make sure timezone or other problem doesn't cause insane delays
				if (diff < const Duration(seconds: 15)) {
					seconds = diff.inSeconds + 1;
				}
			}
			catch (_) {
				// Malformed?
			}
		}
	}
	return Duration(
		seconds: max(seconds ?? 0, min(6, pow(2, currentRetries + 1).ceil()))
	);
}

class HTTP429BackoffInterceptor extends InterceptorBase {
	final Dio client;
	final int maxRetries;

	HTTP429BackoffInterceptor({
		required this.client,
		this.maxRetries = 5
	});

	static void _maybeShowToast(Uri uri, Duration delay) {
		if (delay >= const Duration(seconds: 12)) {
			if (ImageboardRegistry.instance.context case final context?) {
				showToast(
					context: context,
					message: 'Waiting ${formatDuration(delay)}\n${uri.host}',
					icon: CupertinoIcons.clock
				);
			}
		}
	}

	static Future<void> _handleCancelToken(Future<void> future, CancelToken? cancelToken) async {
		if (cancelToken != null) {
			final cancelError = await Future.any<DioError?>([
				cancelToken.whenCancel,
				future.then((_) => null)
			]);
			if (cancelError != null) {
				throw cancelError;
			}
		}
		else {
			await future;
		}
	}

	@override
	Future<void> onRequestImpl(RequestOptions options, RequestInterceptorHandler handler) async {
		if (options.retries == 0) {
			final delay = http429Queue.getCurrentDelay(options.uri);
			if (options.priority == RequestPriority.interactive && delay > const Duration(seconds: 15)) {
				throw Http429Exception(options.uri, DateTime.now().add(delay), 0);
			}
			await _handleCancelToken(http429Queue.start(options.uri, priority: options.priority.index), options.cancelToken);
		}
		handler.next(options);
	}

	@override
	Future<void> onResponseImpl(Response response, ResponseInterceptorHandler handler) async {
		final currentRetries = response.requestOptions.retries;
		if (response.statusCode == 429) {
			final delay = get429Delay(response.headers.value('retry-after'), currentRetries);
			if (response.requestOptions.priority == RequestPriority.lowest || currentRetries >= maxRetries || (response.requestOptions.priority == RequestPriority.interactive && delay > const Duration(seconds: 15))) {
				throw Http429Exception(response.requestOptions.uri, DateTime.now().add(delay), currentRetries);
			}
			print('[HTTP429BackoffInterceptor] Waiting $delay due to server-side rate-limiting (url: ${response.requestOptions.uri}, currentRetries: $currentRetries)');
			_maybeShowToast(response.requestOptions.uri, delay);
			await _handleCancelToken(http429Queue.delay(response.requestOptions.uri, delay), response.requestOptions.cancelToken);
			final response2 = await client.requestUri(
				response.requestOptions.uri,
				data: response.requestOptions.data,
				cancelToken: response.requestOptions.cancelToken,
				options: Options(
					method: response.requestOptions.method,
					headers: response.requestOptions.headers,
					extra: {
						...response.requestOptions.extra,
						_kExtraRetriesKey: currentRetries + 1
					},
					responseType: response.requestOptions.responseType,
					contentType: response.requestOptions.contentType,
					validateStatus: response.requestOptions.validateStatus
				)
			);
			handler.next(response2);
		}
		else {
			handler.next(response);
		}
		if (currentRetries == 0) {
			http429Queue.end(response.requestOptions.uri);
		}
	}

	@override
	Future<void> onErrorImpl(DioError err, ErrorInterceptorHandler handler) async {
		final currentRetries = err.requestOptions.retries;
		try {
			if (err.type == DioErrorType.response &&
					err.response?.statusCode == 429) {
				final delay = get429Delay(err.response?.headers.value('retry-after'), currentRetries);
				if (err.requestOptions.priority == RequestPriority.lowest || currentRetries >= maxRetries || (err.requestOptions.priority == RequestPriority.interactive && delay > const Duration(seconds: 15))) {
					throw Http429Exception(err.requestOptions.uri, DateTime.now().add(delay), currentRetries);
				}
				print('[HTTP429BackoffInterceptor] Waiting $delay due to server-side rate-limiting (url: ${err.requestOptions.uri}, currentRetries: $currentRetries)');
				_maybeShowToast(err.requestOptions.uri, delay);
				await _handleCancelToken(http429Queue.delay(err.requestOptions.uri, delay), err.requestOptions.cancelToken);
				final response = await client.requestUri(
					err.requestOptions.uri,
					data: err.requestOptions.data,
					cancelToken: err.requestOptions.cancelToken,
					options: Options(
						method: err.requestOptions.method,
						headers: err.requestOptions.headers,
						extra: {
							...err.requestOptions.extra,
							_kExtraRetriesKey: currentRetries + 1
						},
						responseType: err.requestOptions.responseType,
						contentType: err.requestOptions.contentType,
						validateStatus: err.requestOptions.validateStatus
					)
				);
				handler.resolve(response, true);
				return;
			}
			handler.next(err);
		}
		finally {
			if (currentRetries == 0) {
				http429Queue.end(err.requestOptions.uri);
			}
		}
	}
}
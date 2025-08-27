import 'dart:io';
import 'dart:math';

import 'package:chan/services/cloudflare.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/priority_queue.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

final http429Queue = PriorityQueue<Uri, String>(
	groupKeyer: (uri) => uri.host
);

const _kExtraRetriesKey = '_retryCount';

class Http429Exception {
	final DateTime waitUntil;
	final int retriesAttempted;
	Http429Exception(this.waitUntil, this.retriesAttempted);

	@override
	String toString() => 'Http429Exception(waitUntil: $waitUntil, retriesAttempted: $retriesAttempted)';
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

class HTTP429BackoffInterceptor extends Interceptor {
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

	@override
	void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
		try {
			if (options.retries == 0) {
				await http429Queue.start(options.uri);
			}
			handler.next(options);
		}
		catch (e, st) {
			handler.reject(DioError(
				requestOptions: options,
				error: e
			)..stackTrace = st, true);
		}
	}

	@override
	void onResponse(Response response, ResponseInterceptorHandler handler) async {
		final currentRetries = response.requestOptions.retries;
		try {
			if (response.statusCode == 429) {
				final delay = get429Delay(response.headers.value('retry-after'), currentRetries);
				if (response.requestOptions.priority == RequestPriority.lowest || currentRetries >= maxRetries) {
					handler.reject(DioError(
						requestOptions: response.requestOptions,
						response: response,
						error: Http429Exception(DateTime.now().add(delay), currentRetries)
					));
					return;
				}
				print('[HTTP429BackoffInterceptor] Waiting $delay due to server-side rate-limiting (url: ${response.requestOptions.uri}, currentRetries: $currentRetries)');
				_maybeShowToast(response.requestOptions.uri, delay);
				await http429Queue.delay(response.requestOptions.uri, delay);
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
		catch (e, st) {
			if (e is DioError) {
				handler.reject(e, true);
			}
			else {
				handler.reject(DioError(
					requestOptions: response.requestOptions,
					response: response,
					error: e
				)..stackTrace = st, true);
			}
		}
	}

	@override
	void onError(DioError err, ErrorInterceptorHandler handler) async {
		final currentRetries = err.requestOptions.retries;
		try {
			if (err.type == DioErrorType.response &&
					err.response?.statusCode == 429) {
				final delay = get429Delay(err.response?.headers.value('retry-after'), currentRetries);
				if (err.requestOptions.priority == RequestPriority.lowest || currentRetries >= maxRetries) {
					handler.reject(DioError(
						requestOptions: err.requestOptions,
						response: err.response,
						error: Http429Exception(DateTime.now().add(delay), currentRetries)
					));
					return;
				}
				print('[HTTP429BackoffInterceptor] Waiting $delay due to server-side rate-limiting (url: ${err.requestOptions.uri}, currentRetries: $currentRetries)');
				_maybeShowToast(err.requestOptions.uri, delay);
				await http429Queue.delay(err.requestOptions.uri, delay);
				try {
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
				}
				catch (e, st) {
					if (e is DioError) {
						handler.reject(e, true);
					}
					else {
						handler.reject(DioError(
							requestOptions: err.requestOptions,
							response: err.response,
							error: e
						)..stackTrace = st, true);
					}
				}
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
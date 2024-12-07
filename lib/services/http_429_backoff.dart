import 'dart:math';

import 'package:dio/dio.dart';

class HTTP429BackoffInterceptor extends Interceptor {
	final Dio client;
	final int maxRetries;

	HTTP429BackoffInterceptor({
		required this.client,
		this.maxRetries = 5
	});

	static const _kExtraKey = '_retryCount';

	@override
	void onResponse(Response response, ResponseInterceptorHandler handler) async {
		final currentRetries = switch (response.requestOptions.extra[_kExtraKey]) {
			int r => r,
			_ => 0
		};
		if (response.statusCode == 429 &&
				currentRetries < maxRetries) {
			final seconds = max(int.tryParse(response.headers.value('retry-after') ?? '') ?? 0, pow(2, currentRetries + 1).ceil());
			print('[HTTP429BackoffInterceptor] Waiting $seconds seconds due to server-side rate-limiting (url: ${response.requestOptions.uri}, currentRetries: $currentRetries)');
			await Future.delayed(Duration(seconds: seconds));
			try {
				final response2 = await client.requestUri(
					response.requestOptions.uri,
					data: response.requestOptions.data,
					cancelToken: response.requestOptions.cancelToken,
					options: Options(
						headers: response.requestOptions.headers,
						extra: {
							...response.requestOptions.extra,
							_kExtraKey: currentRetries + 1
						},
						validateStatus: response.requestOptions.validateStatus
					)
				);
				handler.resolve(response2);
			}
			catch (e) {
				if (e is DioError) {
					handler.reject(e);
				}
			}
			return;
		}
		handler.next(response);
	}

	@override
	void onError(DioError err, ErrorInterceptorHandler handler) async {
		final currentRetries = switch (err.requestOptions.extra[_kExtraKey]) {
			int r => r,
			_ => 0
		};
		if (err.type == DioErrorType.response &&
			  err.response?.statusCode == 429 &&
				currentRetries < maxRetries) {
			final seconds = max(int.tryParse(err.response?.headers.value('retry-after') ?? '') ?? 0, pow(2, currentRetries + 1).ceil());
			print('[HTTP429BackoffInterceptor] Waiting $seconds seconds due to server-side rate-limiting (url: ${err.requestOptions.uri}, currentRetries: $currentRetries)');
			await Future.delayed(Duration(seconds: seconds));
			try {
				final response = await client.requestUri(
					err.requestOptions.uri,
					data: err.requestOptions.data,
					cancelToken: err.requestOptions.cancelToken,
					options: Options(
						headers: err.requestOptions.headers,
						extra: {
							...err.requestOptions.extra,
							_kExtraKey: currentRetries + 1
						},
						validateStatus: err.requestOptions.validateStatus
					)
				);
				handler.resolve(response);
			}
			catch (e) {
				if (e is DioError) {
					handler.reject(e);
				}
			}
			return;
		}
		handler.next(err);
	}
}
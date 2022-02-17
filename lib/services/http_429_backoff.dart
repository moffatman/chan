import 'package:dio/dio.dart';

class HTTP429BackoffInterceptor extends Interceptor {
	final Dio client;
	final int maxRetries;
	final Map<Uri, int> _retryCount = {};

	HTTP429BackoffInterceptor({
		required this.client,
		this.maxRetries = 3
	});

	@override
	void onError(DioError err, ErrorInterceptorHandler handler) async {
		final secondsStr = err.response?.headers.value('retry-after');
		final currentRetries = _retryCount[err.requestOptions.uri] ?? 0;
		if (err.type == DioErrorType.response &&
			  err.response?.statusCode == 429 &&
				secondsStr != null &&
				currentRetries < maxRetries) {
			final seconds = int.parse(secondsStr);
			print('Waiting $seconds seconds due to server-side rate-limiting (current retry count is $currentRetries)');
			await Future.delayed(Duration(seconds: seconds));
			_retryCount[err.requestOptions.uri] = currentRetries + 1;
			try {
				final response = await client.requestUri(
					err.requestOptions.uri,
					data: err.requestOptions.data,
					cancelToken: err.requestOptions.cancelToken
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
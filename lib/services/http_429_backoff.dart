import 'package:dio/dio.dart';

class HTTP429BackoffInterceptor extends Interceptor {
	final Dio client;
	final int maxRetries;
	final Map<RequestOptions, int> _retryCount = {};

	HTTP429BackoffInterceptor({
		required this.client,
		this.maxRetries = 3
	});

	@override
	void onError(DioError err, ErrorInterceptorHandler handler) async {
		final secondsStr = err.response?.headers.value('retry-after');
		if (err.type == DioErrorType.response && err.response?.statusCode == 429 && secondsStr != null) {
			final seconds = int.parse(secondsStr);
			print('Waiting $seconds seconds due to server-side rate-limiting (current retry count is ${_retryCount[err.requestOptions]}');
			await Future.delayed(Duration(seconds: seconds));
			_retryCount.update(err.requestOptions, (a) => a + 1, ifAbsent: () => 1);
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
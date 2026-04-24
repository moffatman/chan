import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// To handle exceptions
/// Last call in every impl must be to handler
class InterceptorBase extends Interceptor {
	Future<void> onRequestImpl(RequestOptions options, RequestInterceptorHandler handler) async {
		handler.next(options);
	}
	Future<void> onResponseImpl(Response response, ResponseInterceptorHandler handler) async {
		handler.next(response);
	}
	Future<void> onErrorImpl(DioError err, ErrorInterceptorHandler handler) async {
		handler.next(err);
	}

	@override
	@nonVirtual
	void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
		try {
			await onRequestImpl(options, handler);
		}
		catch (e, st) {
			if (e is DioError) {
				handler.reject(e, true);
			}
			else {
				handler.reject(DioError(
					requestOptions: options,
					error: e
				)..stackTrace = st, true);
			}
		}
	}

	@override
	@nonVirtual
	void onResponse(Response response, ResponseInterceptorHandler handler) async {
		try {
			await onResponseImpl(response, handler);
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
	@nonVirtual
	void onError(DioError err, ErrorInterceptorHandler handler) async {
		try {
			await onErrorImpl(err, handler);
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
	}
}

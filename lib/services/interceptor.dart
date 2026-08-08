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

class InterceptorWrapperBase extends InterceptorBase {
	final Future<void> Function(RequestOptions options, RequestInterceptorHandler handler)? _onRequest;
  final Future<void> Function(Response response, ResponseInterceptorHandler handler)? _onResponse;
  final Future<void> Function(DioError err, ErrorInterceptorHandler handler)? _onError;

	InterceptorWrapperBase({
    Future<void> Function(RequestOptions options, RequestInterceptorHandler handler)? onRequest,
    Future<void> Function(Response response, ResponseInterceptorHandler handler)? onResponse,
    Future<void> Function(DioError err, ErrorInterceptorHandler handler)? onError,
  })  : _onRequest = onRequest,
        _onResponse = onResponse,
        _onError = onError;

	@override
	Future<void> onRequestImpl(RequestOptions options, RequestInterceptorHandler handler) {
		return (_onRequest ?? super.onRequestImpl)(options, handler);
	}

	@override
	Future<void> onResponseImpl(Response response, ResponseInterceptorHandler handler) {
		return (_onResponse ?? super.onResponseImpl)(response, handler);
	}

	@override
	Future<void> onErrorImpl(DioError err, ErrorInterceptorHandler handler) {
		return (_onError ?? super.onErrorImpl)(err, handler);
	}
}

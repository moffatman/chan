import 'dart:io';

import 'package:chan/main.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';

class SeparatedCookieManager extends Interceptor {
  final CookieJar wifiCookieJar;
	final CookieJar cellularCookieJar;

  SeparatedCookieManager({
		required this.wifiCookieJar,
		required this.cellularCookieJar
	});

	CookieJar get cookieJar {
		if (settings.connectivity == ConnectivityResult.mobile) {
			return cellularCookieJar;
		}
		return wifiCookieJar;
	}

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
		try {
			final cookies = await cookieJar.loadForRequest(options.uri);
			final cookie = getCookies(cookies);
			if (cookie.isNotEmpty) {
				options.headers[HttpHeaders.cookieHeader] = cookie;
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
		try {
			await _saveCookies(response);
			handler.next(response);
		}
		catch (e, st) {
			handler.reject(DioError(
				requestOptions: response.requestOptions,
				error: e
			)..stackTrace = st, true);
		}
  }

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) async {
    if (err.response != null) {
			try {
      	await _saveCookies(err.response!);
				handler.next(err);
			}
			catch(e, st) {
				handler.next(DioError(
					requestOptions: err.response!.requestOptions,
					error: e
				)..stackTrace = st);
			}
    } else {
      handler.next(err);
    }
  }

  Future<void> _saveCookies(Response response) async {
    var cookies = response.headers[HttpHeaders.setCookieHeader];

    if (cookies != null) {
      await cookieJar.saveFromResponse(
        response.requestOptions.uri,
        cookies.map((str) => Cookie.fromSetCookieValue(str)).toList(),
      );
    }
  }

  static String getCookies(List<Cookie> cookies) {
    return cookies.map((cookie) => '${cookie.name}=${cookie.value}').join('; ');
  }
}

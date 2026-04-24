import 'dart:io';

import 'package:chan/services/interceptor.dart';
import 'package:dio/dio.dart';

class FixupInterceptor extends InterceptorBase {
	@override
	Future<void> onRequestImpl(RequestOptions options, RequestInterceptorHandler handler) async {
		options.headers[HttpHeaders.acceptEncodingHeader] ??= 'gzip';
		if (options.uri.host == 'yewtu.be') {
			options.headers[HttpHeaders.acceptHeader] = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7';
		}
		handler.next(options);
	}
}
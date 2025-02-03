import 'dart:convert';

import 'package:chan/services/html_error.dart';
import 'package:chan/services/util.dart';
import 'package:dio/dio.dart';

class InvalidJsonException extends ExtendedException {
	final Uri uri;
	final int? statusCode;
	final String data;
	final String? extractedError;
	InvalidJsonException({
		required this.uri,
		required this.statusCode,
		required this.data
	}) : extractedError = extractHtmlError(data),
	     super(
				additionalFiles: {
					uri.pathSegments.last: utf8.encode(data)
				}
			);
	@override
	bool get isReportable => true;
	@override
	String toString() => 'InvalidJsonException(${<String, String>{
		'url': uri.toString(),
		if (statusCode != null) 'statusCode': statusCode.toString(),
		if (extractedError != null) 'error': extractedError!
	}.entries.map((e) => '${e.key}: ${e.value}').join(', ')})';
}

class StrictJsonInterceptor extends Interceptor {
	@override
  void onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) {
		if (response.requestOptions.responseType == ResponseType.json &&
				!Transformer.isJsonMimeType(response.headers[Headers.contentTypeHeader]?.first) &&
				// This would be treated as a success and data checked
				switch (response.statusCode) {
					null => false,
					304 => false, // Not modified = no data
					< 400 => true,
					int _ => false
				}) {
			handler.reject(DioError(
				requestOptions: response.requestOptions,
				response: response,
				error: InvalidJsonException(
					data: switch (response.data) {
						String x => x,
						List<int> l => utf8.decode(l),
						dynamic other => 'Unknown data<${other.runtimeType}>: $other'
					},
					uri: response.requestOptions.uri,
					statusCode: response.statusCode
				)
			));
			return;
		}
		handler.next(response);
	}
}

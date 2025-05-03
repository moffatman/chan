import 'package:chan/services/strict_json.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;

extension SiteErrorHandling on Dio {
	Future<Response<T>> getThreadUri<T>(Uri uri, {Options? options, required RequestPriority priority, required ResponseType responseType, CancelToken? cancelToken}) async {
		final extra = options?.extra;
		try {
			final response = await getUri<T>(uri, options: options?.copyWith(
				validateStatus: (_) => true,
				extra: {
					if (extra != null) ...extra,
					kPriority: priority,
				},
				responseType: responseType
			) ?? Options(
				validateStatus: (_) => true,
				extra: {
					kPriority: priority
				},
				responseType: responseType
			), cancelToken: cancelToken);
			final status = response.statusCode;
			if (status != null && status >= 200 && status < 400) {
				return response;
			}
			if (status == 404) {
				throw const ThreadNotFoundException();
			}
			throw HTTPStatusException.fromResponse(response);
		}
		catch (e) {
			if (e is DioError) {
				final err = e.error;
				if (err is InvalidJsonException) {
					final str = err.extractedError?.toLowerCase();
					if (str != null && str.contains('404') && str.contains('not found')) {
						// Should cover most common error pages
						throw const ThreadNotFoundException();
					}
				}
			}
			rethrow;
		}
	}
}


extension TrimNode on dom.Node {
	dom.Node trimLeft() {
		if (this is dom.Text) {
			return dom.Text(text?.trimLeft());
		}
		return this;
	}
	dom.Node trimRight() {
		if (this is dom.Text) {
			return dom.Text(text?.trimRight());
		}
		return this;
	}
	dom.Node trim() {
		if (this is dom.Text) {
			return dom.Text(text?.trim());
		}
		return this;
	}
}

extension TrimNodeList on List<dom.Node> {
	List<dom.Node> trim() {
		if (length == 0) {
			return this;
		}
		else if (length == 1) {
			return [single.trim()];
		}
		else if (length == 2) {
			return [first.trimLeft(), last.trimRight()];
		}
		else {
			return [
				first.trimLeft(),
				...sublist(1, length - 1),
				last.trimRight()
			];
		}
	}
}

import 'package:chan/sites/imageboard_site.dart';
import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;

extension SiteErrorHandling on Dio {
	Future<Response<T>> getThreadUri<T>(Uri uri, {Options? options, required RequestPriority priority}) async {
		final extra = options?.extra;
		final response = await getUri<T>(uri, options: options?.copyWith(
			validateStatus: (_) => true,
			extra: {
				if (extra != null) ...extra,
				kPriority: priority,
			}
		) ?? Options(
			validateStatus: (_) => true,
			extra: {
				kPriority: priority
			}
		));
		final status = response.statusCode;
		if (status != null && status >= 200 && status < 300) {
			return response;	
		}
		if (status == 404) {
			throw const ThreadNotFoundException();
		}
		throw HTTPStatusException.fromResponse(response);
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

import 'package:chan/sites/imageboard_site.dart';
import 'package:dio/dio.dart';

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
		throw HTTPStatusException(status ?? 0);
	}
}

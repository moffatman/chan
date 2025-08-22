import 'dart:io';

import 'package:chan/models/thread.dart';
import 'package:chan/services/strict_json.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

mixin Http304CachingThreadMixin on ImageboardSite {
	@protected
	RequestOptions getThreadRequest(ThreadIdentifier thread, {ThreadVariant? variant});
	@protected
	Future<Thread> makeThread(ThreadIdentifier thread, Response response, {
		ThreadVariant? variant,
		required RequestPriority priority,
		CancelToken? cancelToken
	});
	@override
	Future<Thread> getThreadImpl(ThreadIdentifier thread, {
		ThreadVariant? variant,
		required RequestPriority priority,
		CancelToken? cancelToken
	}) async {
		final baseOptions = getThreadRequest(thread, variant: variant);
		try {
			final response = await client.fetch(baseOptions.copyWith(
				validateStatus: (_) => true,
				extra: {
					...baseOptions.extra,
					kPriority: priority
				},
				cancelToken: cancelToken
			));
			final status = response.statusCode;
			if (status != null && status >= 200 && status < 400) {
				return await unsafeAsync(response.data, () async {
					final t = await makeThread(thread, response, variant: variant, priority: priority, cancelToken: cancelToken);
					// posts.last.time sometimes is off by 1 second. probably due to server-side processing latencies
					// best to use the exact value reported in Last-Modified
					t.lastUpdatedTime ??= DateTimeConversion.fromHttpHeader.maybe(response.headers.value(HttpHeaders.lastModifiedHeader))?.toLocal();
					return t;

				});
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
	@override
	Future<Thread?> getThreadIfModifiedSince(ThreadIdentifier thread, DateTime lastModified, {
		ThreadVariant? variant,
		required RequestPriority priority,
		CancelToken? cancelToken
	}) async {
		final baseOptions = getThreadRequest(thread, variant: variant);
		final response = await client.fetch(baseOptions.copyWith(
			validateStatus: (_) => true,
			extra: {
				...baseOptions.extra,
				kPriority: priority
			},
			headers: {
				...baseOptions.headers,
				HttpHeaders.ifModifiedSinceHeader: lastModified.toHttpHeader
			},
			cancelToken: cancelToken
		));
		final status = response.statusCode;
		if (status == 304) {
			return null;
		}
		if (status != null && status >= 200 && status < 400) {
			return await unsafeAsync(response.data, () async {
				final t = await makeThread(thread, response, variant: variant, priority: priority, cancelToken: cancelToken);
				// posts.last.time sometimes is off by 1 second. probably due to server-side processing latencies
				// best to use the exact value reported in Last-Modified
				t.lastUpdatedTime ??= DateTimeConversion.fromHttpHeader.maybe(response.headers.value(HttpHeaders.lastModifiedHeader))?.toLocal();
				return t;
			});
		}
		if (status == 404) {
			throw const ThreadNotFoundException();
		}
		throw HTTPStatusException.fromResponse(response);
	}
}

extension CatalogLastUpdatedTimeRead on Iterable<Thread> {
	DateTime? get lastUpdatedTime {
		final d0 = DateTime(2000);
		final res = fold(d0, (d, t) {
			final td = t.lastUpdatedTime ?? t.posts_.tryLast?.time ?? d0;
			if (td.isAfter(d)) {
				return td;
			}
			return d;
		});
		if (res == d0) {
			return null;
		}
		return res;
	}
}

mixin Http304CachingCatalogMixin on ImageboardSite {
	@protected
	RequestOptions getCatalogRequest(String board, {CatalogVariant? variant});
	@protected
	Future<List<Thread>> makeCatalog(String board, Response response, {
		required CatalogVariant? variant,
		required RequestPriority priority,
		CancelToken? cancelToken
	});

	static _setLastUpdatedTime(List<Thread> catalog, DateTime? newTime) {
		if (catalog.isEmpty || newTime == null) {
			return;
		}
		DateTime bestTime = catalog[0].time;
		int bestIndex = 0;
		for (int i = 1; i < catalog.length; i++) {
			final thisTime = catalog[i].time;
			if (thisTime.isAfter(bestTime)) {
				bestIndex = i;
				bestTime = catalog[i].time;
			}
		}
		if (bestTime == newTime || bestTime.isAfter(newTime)) {
			return;
		}
		catalog[bestIndex].lastUpdatedTime = newTime;
	}

	@override
	Future<List<Thread>> getCatalogImpl(String board, {
		CatalogVariant? variant,
		required RequestPriority priority,
		CancelToken? cancelToken
	}) async {
		final baseOptions = getCatalogRequest(board, variant: variant);
		try {
			final response = await client.fetch(baseOptions.copyWith(
				validateStatus: (_) => true,
				extra: {
					...baseOptions.extra,
					kPriority: priority
				},
				cancelToken: cancelToken
			));
			final status = response.statusCode;
			if (status != null && status >= 200 && status < 400) {
				return await unsafeAsync(response.data, () async {
					final c = await makeCatalog(board, response, variant: variant, priority: priority, cancelToken: cancelToken);
					// posts.last.time sometimes is off by 1 second. probably due to server-side processing latencies
					// best to use the exact value reported in Last-Modified
					_setLastUpdatedTime(c, DateTimeConversion.fromHttpHeader.maybe(response.headers.value(HttpHeaders.lastModifiedHeader))?.toLocal());
					return c;
				});
			}
			if (status == 404) {
				throw BoardNotFoundException(board);
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
	@override
	Future<List<Thread>?> getCatalogIfModifiedSince(String board, DateTime lastModified, {
		CatalogVariant? variant,
		required RequestPriority priority,
		CancelToken? cancelToken
	}) async {
		final baseOptions = getCatalogRequest(board, variant: variant);
		final response = await client.fetch(baseOptions.copyWith(
			validateStatus: (_) => true,
			extra: {
				...baseOptions.extra,
				kPriority: priority
			},
			headers: {
				...baseOptions.headers,
				HttpHeaders.ifModifiedSinceHeader: lastModified.toHttpHeader
			},
			cancelToken: cancelToken
		));
		final status = response.statusCode;
		if (status == 304) {
			return null;
		}
		if (status != null && status >= 200 && status < 400) {
			return await unsafeAsync(response.data, () async {
				final c = await makeCatalog(board, response, variant: variant, priority: priority, cancelToken: cancelToken);
				// posts.last.time sometimes is off by 1 second. probably due to server-side processing latencies
				// best to use the exact value reported in Last-Modified
				_setLastUpdatedTime(c, DateTimeConversion.fromHttpHeader.maybe(response.headers.value(HttpHeaders.lastModifiedHeader))?.toLocal());
				return c;
			});
		}
		if (status == 404) {
			throw BoardNotFoundException(board);
		}
		throw HTTPStatusException.fromResponse(response);
	}
}

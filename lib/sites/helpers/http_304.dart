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

mixin Http304CachingCatalogMixin on ImageboardSite {
	@protected
	RequestOptions getCatalogRequest(String board, {CatalogVariant? variant});
	@protected
	Future<List<Thread>> makeCatalog(String board, Response response, {
		required CatalogVariant? variant,
		required RequestPriority priority,
		CancelToken? cancelToken
	});

	@override
	Future<Catalog> getCatalogImpl(String board, {
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
					return Catalog.fromResponse(response, c);
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
						throw BoardNotFoundException(board);
					}
				}
			}
			rethrow;
		}
	}
	@override
	Future<Catalog?> getCatalogIfModifiedSince(String board, DateTime lastModified, {
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
				return Catalog.fromResponse(response, c);
			});
		}
		if (status == 404) {
			throw BoardNotFoundException(board);
		}
		throw HTTPStatusException.fromResponse(response);
	}
	@protected
	RequestOptions? getCatalogPageMapRequest(String board, {CatalogVariant? variant}) {
		if (hasPagedCatalog) {
			return null;
		}
		return getCatalogRequest(board, variant: variant);
	}
	@protected
	Future<Map<int, int>> makeCatalogPageMap(String board, Response response, {
		required CatalogVariant? variant,
		required RequestPriority priority,
		CancelToken? cancelToken
	}) async {
		final catalog = await makeCatalog(board, response, variant: variant, priority: priority, cancelToken: cancelToken);
		return {
			for (final thread in catalog)
				if (thread.currentPage case int page)
					thread.id: page
		};
	}
	@protected
	@override
	Future<CatalogPageMap> getCatalogPageMapImpl(String board, {CatalogVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) async {
		final baseOptions = getCatalogPageMapRequest(board, variant: variant);
		if (baseOptions == null) {
			// No hope, getCatalogPageMapRequest needs to be defined per-site if possible
			return const CatalogPageMap(
				pageMap: {},
				lastModified: null
			);
		}
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
					final pageMap = await makeCatalogPageMap(board, response, variant: variant, priority: priority, cancelToken: cancelToken);
					return CatalogPageMap.fromResponse(response, pageMap);
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
						throw BoardNotFoundException(board);
					}
				}
			}
			rethrow;
		}
	}
	@protected
	@override
	Future<CatalogPageMap?> getCatalogPageMapIfModifiedSince(String board, DateTime? lastModified, {CatalogVariant? variant, required RequestPriority priority, DateTime? acceptCachedAfter, CancelToken? cancelToken}) async {
		final baseOptions = getCatalogPageMapRequest(board, variant: variant);
		if (baseOptions == null) {
			// No hope, getCatalogPageMapRequest needs to be defined per-site if possible
			return const CatalogPageMap(
				pageMap: {},
				lastModified: null
			);
		}
		final response = await client.fetch(baseOptions.copyWith(
			validateStatus: (_) => true,
			extra: {
				...baseOptions.extra,
				kPriority: priority
			},
			headers: {
				...baseOptions.headers,
				if (lastModified != null) HttpHeaders.ifModifiedSinceHeader: lastModified.toHttpHeader
			},
			cancelToken: cancelToken
		));
		final status = response.statusCode;
		if (status == 304) {
			return null;
		}
		if (status != null && status >= 200 && status < 400) {
			return await unsafeAsync(response.data, () async {
				final pageMap = await makeCatalogPageMap(board, response, variant: variant, priority: priority, cancelToken: cancelToken);
				return CatalogPageMap.fromResponse(response, pageMap);
			});
		}
		if (status == 404) {
			throw BoardNotFoundException(board);
		}
		throw HTTPStatusException.fromResponse(response);
	}
}

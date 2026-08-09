import 'dart:io';

import 'package:chan/models/thread.dart';
import 'package:chan/services/strict_json.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

extension _Helper on ImageboardSite {
	Future<T?> _helper<T>({
		required RequestOptions baseOptions,
		required DateTime? lastModified,
		required Future<T> Function(Response) func,
		required Future<T?> Function() on404,
		required RequestPriority priority,
		required CancelToken? cancelToken,
		Future<T?> Function()? on304
	}) async {
		try {
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
				return on304?.call();
			}
			if (status != null && status >= 200 && status < 400) {
				return await unsafeAsync(response.data, () => func(response));
			}
			if (status == 404) {
				return on404();
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
						return on404();
					}
				}
			}
			rethrow;
		}
	}
}

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
	}) async => (await _helper(
		baseOptions: getThreadRequest(thread, variant: variant),
		lastModified: null,
		func: (response) async {
			final t = await makeThread(thread, response, variant: variant, priority: priority, cancelToken: cancelToken);
			// posts.last.time sometimes is off by 1 second. probably due to server-side processing latencies
			// best to use the exact value reported in Last-Modified
			t.lastUpdatedTime ??= DateTimeConversion.fromHttpHeader.maybe(response.headers.value(HttpHeaders.lastModifiedHeader))?.toLocal();
			return t;
		},
		on404: () => throw const ThreadNotFoundException(),
		priority: priority,
		cancelToken: cancelToken
	))!;
	@override
	Future<Thread?> getThreadIfModifiedSince(ThreadIdentifier thread, DateTime lastModified, {
		ThreadVariant? variant,
		required RequestPriority priority,
		CancelToken? cancelToken
	}) => _helper(
		baseOptions: getThreadRequest(thread, variant: variant),
		lastModified: lastModified,
		func: (response) async {
			final t = await makeThread(thread, response, variant: variant, priority: priority, cancelToken: cancelToken);
			// posts.last.time sometimes is off by 1 second. probably due to server-side processing latencies
			// best to use the exact value reported in Last-Modified
			t.lastUpdatedTime ??= DateTimeConversion.fromHttpHeader.maybe(response.headers.value(HttpHeaders.lastModifiedHeader))?.toLocal();
			return t;
		},
		on404: () => throw const ThreadNotFoundException(),
		priority: priority,
		cancelToken: cancelToken
	);
}

mixin Http304CachingThreadTailMixin on ImageboardSite {
	@protected
	RequestOptions? getThreadTailRequest(Thread thread, {ThreadVariant? variant});
	@protected
	Future<ThreadTail> makeThreadTail(ThreadIdentifier thread, Response response, {
		ThreadVariant? variant,
		required RequestPriority priority,
		CancelToken? cancelToken
	});
	@override
	Future<ThreadTail?> getThreadTail(Thread thread, {
		ThreadVariant? variant,
		required RequestPriority priority,
		CancelToken? cancelToken
	}) async {
		final request = getThreadTailRequest(thread, variant: variant);
		if (request == null) {
			return null;
		}
		return await _helper<ThreadTail>(
			baseOptions: request,
			lastModified: null,
			func: (response) async {
				final t = await makeThreadTail(thread.identifier, response, variant: variant, priority: priority, cancelToken: cancelToken);
				// posts.last.time sometimes is off by 1 second. probably due to server-side processing latencies
				// best to use the exact value reported in Last-Modified
				t.lastUpdatedTime ??= DateTimeConversion.fromHttpHeader.maybe(response.headers.value(HttpHeaders.lastModifiedHeader))?.toLocal();
				return t;
			},
			on304: () async => ThreadTail.empty(thread),
			// Tail is not available on short threads or archived threads
			on404: () async => null,
			priority: priority,
			cancelToken: cancelToken
		);
	}
}

mixin Http304CachingCatalogMixin on ImageboardSite {
	static const _kIsCatalogRequest = 'catalog_request';
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
		final fetchedTime = DateTime.now();
		return (await _helper(
			baseOptions: getCatalogRequest(board, variant: variant),
			lastModified: null,
			func: (response) async {
				final c = await makeCatalog(board, response, variant: variant, priority: priority, cancelToken: cancelToken);
				return Catalog.fromResponse(response, fetchedTime, c);
			},
			on404: () => throw BoardNotFoundException(board),
			priority: priority,
			cancelToken: cancelToken
		))!;
	}
	@override
	Future<Catalog?> getCatalogIfModifiedSince(String board, DateTime lastModified, {
		CatalogVariant? variant,
		required RequestPriority priority,
		CancelToken? cancelToken
	}) async {
		final fetchedTime = DateTime.now();
		return await _helper(
			baseOptions: getCatalogRequest(board, variant: variant),
			lastModified: lastModified,
			func: (response) async {
				final c = await makeCatalog(board, response, variant: variant, priority: priority, cancelToken: cancelToken);
				return Catalog.fromResponse(response, fetchedTime, c);
			},
			on404: () => throw BoardNotFoundException(board),
			priority: priority,
			cancelToken: cancelToken
		);
	}
	@protected
	RequestOptions? getCatalogPageMapRequest(String board, {CatalogVariant? variant}) {
		if (hasPagedCatalog) {
			return null;
		}
		return getCatalogRequest(board, variant: variant)..extra[_kIsCatalogRequest] = true;
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
			return CatalogPageMap(
				pageMap: {},
				lastModified: null,
				fetchedTime: DateTime(2000)
			);
		}
		final isSameAsCatalog = baseOptions.extra.containsKey(_kIsCatalogRequest);
		final fetchedTime = DateTime.now();
		return (await _helper(
			baseOptions: baseOptions,
			lastModified: null,
			func: (response) async {
				final pageMap = await makeCatalogPageMap(board, response, variant: variant, priority: priority, cancelToken: cancelToken);
				if (isSameAsCatalog) {
					final catalog = await makeCatalog(board, response, variant: variant, priority: priority, cancelToken: cancelToken);
					insertCatalogIntoCache(board, variant, Catalog.fromResponse(response, fetchedTime, catalog));
				}
				return CatalogPageMap.fromResponse(response, fetchedTime, pageMap);
			},
			on404: () => throw BoardNotFoundException(board),
			priority: priority,
			cancelToken: cancelToken
		))!;
	}
	@protected
	@override
	Future<CatalogPageMap?> getCatalogPageMapIfModifiedSince(String board, DateTime? lastModified, {CatalogVariant? variant, required RequestPriority priority, DateTime? acceptCachedAfter, CancelToken? cancelToken}) async {
		final baseOptions = getCatalogPageMapRequest(board, variant: variant);
		if (baseOptions == null) {
			// No hope, getCatalogPageMapRequest needs to be defined per-site if possible
			return CatalogPageMap(
				pageMap: {},
				lastModified: null,
				fetchedTime: DateTime(2000)
			);
		}
		final isSameAsCatalog = baseOptions.extra.containsKey(_kIsCatalogRequest);
		final fetchedTime = DateTime.now();
		return await _helper(
			baseOptions: baseOptions,
			lastModified: lastModified,
			func: (response) async {
				final pageMap = await makeCatalogPageMap(board, response, variant: variant, priority: priority, cancelToken: cancelToken);
				if (isSameAsCatalog) {
					final catalog = await makeCatalog(board, response, variant: variant, priority: priority, cancelToken: cancelToken);
					insertCatalogIntoCache(board, variant, Catalog.fromResponse(response, fetchedTime, catalog));
				}
				return CatalogPageMap.fromResponse(response, fetchedTime, pageMap);
			},
			on404: () => throw BoardNotFoundException(board),
			on304: () async {
				if (isSameAsCatalog) {
					bumpCatalogInCache(board, variant, fetchedTime, lastModified);
				}
				return null;
			},
			priority: priority,
			cancelToken: cancelToken
		);
	}
}

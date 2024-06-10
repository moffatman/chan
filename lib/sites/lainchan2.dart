import 'package:chan/models/board.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/lainchan_org.dart';
import 'package:chan/sites/util.dart';
import 'package:chan/util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart';
import 'package:mutex/mutex.dart';

const _kExtraBypassLock = 'bypass_lock';

/// Block any processing while form is being submitted, so that the new cookies
/// can be injected by a later interceptor
class FormBypassBlockingInterceptor extends Interceptor {
	final SiteLainchan2 site;

	FormBypassBlockingInterceptor(this.site);

	@override
	void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
		if (options.extra[_kExtraBypassLock] == true) {
			handler.next(options);
		}
		else {
			site.formLock.protect(() async {
				handler.next(options);
			});
		}
	}
}

class FormBypassInterceptor extends Interceptor {
	final SiteLainchan2 site;

	FormBypassInterceptor(this.site);

	@override
	void onResponse(Response response, ResponseInterceptorHandler handler) async {
		try {
			if (response.realUri.host == site.baseUrl) {
				final formBypass = site.formBypass[response.realUri.path];
				if (formBypass != null) {
					final document = parse(response.data);
					String? action = document.querySelector('form')?.attributes['action'];
					if (action != null) {
						if (action.startsWith('/')) {
							action = 'https://${site.baseUrl}$action';
						}
						final action_ = action;
						final response2 = await site.formLock.protect(() async {
							final postResponse = await site.client.post(action_, data: FormData.fromMap(formBypass), options: Options(
								validateStatus: (x) => x != null && (x >= 200 || x < 400),
								followRedirects: true,
								extra: {
									_kExtraBypassLock: true
								}
							));
							if (postResponse.realUri.path != response.realUri.path) {
								return await site.client.fetch(response.requestOptions.copyWith(
									extra: {
										...response.requestOptions.extra,
										_kExtraBypassLock: true
									}
								));
							}
						});
						if (response2 != null) {
							// Success
							handler.next(response2);
							return;
						}
					}
				}
			}
			handler.next(response);
		}
		catch (e, st) {
			Future.error(e, st); // Crashlytics
			handler.reject(DioError(
				requestOptions: response.requestOptions,
				error: e
			));
		}
	}
}

/// The old SiteLainchan and SiteLainchanOrg can't really be modified due to backwards compatibility
class SiteLainchan2 extends SiteLainchanOrg {
	@override
	final String? imageThumbnailExtension;
	final List<ImageboardBoard>? boards;
	final Map<String, Map<String, String>> formBypass;
	final formLock = Mutex();

	SiteLainchan2({
		required super.baseUrl,
		required super.basePath,
		required super.name,
		required this.formBypass,
		required this.imageThumbnailExtension,
		super.platformUserAgents,
		super.archives,
		super.faviconPath,
		super.boardsPath,
		this.boards,
		super.defaultUsername
	}) {
		client.interceptors.insert(1, FormBypassBlockingInterceptor(this));
		client.interceptors.add(FormBypassInterceptor(this));
	}
	
	@override
	Future<List<ImageboardBoard>> getBoards({required RequestPriority priority}) async {
		return boards ?? (await super.getBoards(priority: priority));
	}

	@override
	Future<Thread> getThreadImpl(ThreadIdentifier thread, {ThreadVariant? variant, required RequestPriority priority}) async {
		final broken = await super.getThreadImpl(thread, priority: priority);
		if (imageThumbnailExtension != '') {
			return broken;
		}
		final response = await client.getThreadUri(Uri.https(baseUrl, '$basePath/${thread.board}/res/${thread.id}.html'), priority: priority);
		final document = parse(response.data);
		final thumbnailUrls = document.querySelectorAll('img.post-image').map((e) => e.attributes['src']).toList();
		for (final attachment in broken.posts_.expand((p) => p.attachments)) {
			final thumbnailUrl = thumbnailUrls.tryFirstWhere((u) => u?.contains(attachment.id) ?? false);
			if (thumbnailUrl != null) {
				attachment.thumbnailUrl =
					thumbnailUrl.startsWith('/') ?
						Uri.https(baseUrl, thumbnailUrl).toString() :
						thumbnailUrl;
			}
		}
		// Copy corrected thumbnail URLs to thread from posts_.first
		for (final a in broken.posts_.first.attachments) {
			broken.attachments.tryFirstWhere((a2) => a.id == a2.id)?.thumbnailUrl = a.thumbnailUrl;
		}
		return broken;
	}

	@override
	Future<List<Thread>> getCatalogImpl(String board, {CatalogVariant? variant, required RequestPriority priority}) async {
		final broken = await super.getCatalogImpl(board, priority: priority);
		if (imageThumbnailExtension != '') {
			return broken;
		}
		final response = await client.getUri(Uri.https(baseUrl, '$basePath/$board/catalog.html'), options: Options(
			extra: {
				kPriority: priority
			}
		));
		final document = parse(response.data);
		final thumbnailUrls = document.querySelectorAll('img.thread-image').map((e) => e.attributes['src']).toList();
		for (final attachment in broken.expand((t) => t.attachments)) {
			final thumbnailUrl = thumbnailUrls.tryFirstWhere((u) => u?.contains(attachment.id.toString()) ?? false);
			if (thumbnailUrl != null) {
				attachment.thumbnailUrl =
					thumbnailUrl.startsWith('/') ?
						Uri.https(baseUrl, thumbnailUrl).toString() :
						thumbnailUrl;
			}
		}
		return broken;
	}

	@override
	String get siteType => 'lainchan2';
	@override
	String get siteData => baseUrl;

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		(other is SiteLainchan2) &&
		(other.baseUrl == baseUrl) &&
		(other.basePath == basePath) &&
		(other.name == name) &&
		mapEquals(other.platformUserAgents, platformUserAgents) &&
		listEquals(other.archives, archives) &&
		(other.faviconPath == faviconPath) &&
		(other.defaultUsername == defaultUsername) &&
		(other.boardsPath == boardsPath) &&
		mapEquals(other.formBypass, formBypass) &&
		(other.imageThumbnailExtension == imageThumbnailExtension) &&
		(other.boardsPath == boardsPath) &&
		(other.faviconPath == faviconPath) &&
		listEquals(other.boards, boards);

	@override
	int get hashCode => Object.hash(baseUrl, basePath, name, platformUserAgents, archives, faviconPath, defaultUsername, formBypass, imageThumbnailExtension, boardsPath, faviconPath, boards);
}
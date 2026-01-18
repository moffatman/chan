// ignore_for_file: file_names

import 'dart:io';

import 'package:chan/services/cloudflare.dart';
import 'package:chan/services/javascript_challenge.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/lynxchan.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:mutex/mutex.dart';

const _kBypassLock = '_bypass_8chan_lock';

class Site8ChanPoWBlockFakePngBlockingInterceptor extends Interceptor {
	final Site8Chan site;

	Site8ChanPoWBlockFakePngBlockingInterceptor(this.site);


	@override
	void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
		if (options.extra.containsKey(_kBypassLock)) {
			handler.next(options);
			return;
		}
		site._interceptorLock.protect(() async {
			handler.next(options);
		});
	}
}

class Site8ChanPoWBlockFakePngInterceptor extends Interceptor {
	final Site8Chan site;

	Site8ChanPoWBlockFakePngInterceptor(this.site);

	bool _responseMatches(Response response) {
		return response.realUri.host == site.imageUrl
			&& response.realUri.path.startsWith('/.media/')
			&& response.headers.value(HttpHeaders.ageHeader) == '0'
			&& response.headers.value(HttpHeaders.expiresHeader) == '0'
			&& (response.headers.value(HttpHeaders.cacheControlHeader)?.contains('no-cache') ?? false);
	}

	Future<Response?> _resolve(Response response) async {
		final wasLocked = site._interceptorLock.isLocked;
		await site._interceptorLock.protect(() async {
			if (wasLocked) {
				// Assume it was logged into already
				return;
			}
			await site.client.getUri(Uri.https(site.baseUrl, '/'), options: Options(
				extra: {
					_kBypassLock: true,
					kCloudflare: true
				}
			));
		});
		// Retry the request
		return await site.client.fetch(response.requestOptions);
	}

	@override
	void onResponse(Response response, ResponseInterceptorHandler handler) async {
		if (_responseMatches(response)) {
			try {
				final response2 = await _resolve(response);
				if (response2 != null) {
					handler.next(response2);
					return;
				}
			}
			catch (e, st) {
				handler.reject(DioError(
					requestOptions: response.requestOptions,
					response: response,
					error: e
				)..stackTrace = st, true);
				return;
			}
		}
		handler.next(response);
	}

	@override
	void onError(DioError err, ErrorInterceptorHandler handler) async {
		if (err.response case final response? when _responseMatches(response)) {
			try {
				final response2 = await _resolve(response);
				if (response2 != null) {
					handler.resolve(response2, true);
					return;
				}
			}
			catch (e, st) {
				handler.reject(DioError(
					requestOptions: response.requestOptions,
					response: response,
					error: e
				)..stackTrace = st, true);
				return;
			}
		}
		handler.next(err);
	}
}


class Site8Chan extends SiteLynxchan {
	final _interceptorLock = Mutex();
  Site8Chan({
		required super.name,
		required super.baseUrl,
		required super.boards,
		required super.defaultUsername,
		required super.overrideUserAgent,
		required super.archives,
		required super.imageHeaders,
		required super.videoHeaders,
		required super.hasLinkCookieAuth,
		required super.hasPagedCatalog,
		required super.allowsArbitraryBoards
	}) : super(
		hasBlockBypassJson: true
	) {
		client.interceptors.insert(1, Site8ChanPoWBlockFakePngBlockingInterceptor(this));
		client.interceptors.add(Site8ChanPoWBlockFakePngInterceptor(this));
	}

	@override
	@protected
	ImageboardRedirectGateway get redirectGateway => const ImageboardRedirectGateway(
		name: '8chan',
		alwaysNeedsManualSolving: false,
		autoClickSelector: 'h1 a'
	);

	@override
	Future<Map> handleBlockBypassJson(DraftPost post, CaptchaSolution captchaSolution, CancelToken cancelToken) async {
		final data = await super.handleBlockBypassJson(post, captchaSolution, cancelToken);
		if (data case {'data': {'validated': false}}) {
			await solveJavascriptChallenge<void>(
				url: Uri.parse(getWebUrlImpl(post.board, post.threadId)),
				priority: RequestPriority.interactive,
				headlessTime: const Duration(seconds: 20),
				name: '8chan validation',
				javascript:
					'''
						new Promise(function (resolve, reject) {
							resolve.stop = reject
							bypassUtils.runValidation(resolve)
						})
					'''
			);
		}
		return data;
	}

	@override
	Future<ImageboardRedirectGateway?> getRedirectGateway(Uri uri, String? Function() title, Future<String?> Function() html) async {
		if ((uri.host == baseUrl || uri.host == '') && uri.path == '/.static/pages/disclaimer.html') {
			return redirectGateway;
		}
		if (uri.host == baseUrl) {
			final t = title();
			if (t != null && ['Checking…', 'POWBlock'].any(t.contains)) {
				return const ImageboardRedirectGateway(name: '8chan', alwaysNeedsManualSolving: false);
			}
		}
		return null;
	}

	@override
	String get siteType => '8chan';
	@override
	String get siteData => baseUrl;

	@override
	bool get supportsPinkQuotes => true;

	@override
	List<ImageboardSnippet> getBoardSnippets(String board) => const [
		greentextSnippet,
		ImageboardSnippet.simple(
			icon: CupertinoIcons.eye_slash,
			name: 'Spoiler',
			start: '[spoiler]',
			end: '[/spoiler]'
		)
	];

	@override
	bool operator == (Object other) =>
		identical(other, this) ||
		other is Site8Chan &&
		super==(other);
	
	@override
	int get hashCode => baseUrl.hashCode;
}

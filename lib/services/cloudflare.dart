import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:html/parser.dart';
import 'package:mutex/mutex.dart';

extension CloudflareWanted on RequestOptions {
	bool get cloudflare => extra['cloudflare'] == true;
	bool get interactive => extra[kInteractive] != false;
}
extension CloudflareHandled on Response {
	bool get cloudflare => extra['cloudflare'] == true;
	bool get interactive => extra[kInteractive] != false;
}

final _initialAllowNonInteractiveWebvieWhen = (timePasses: DateTime(2000), hostPasses: '');
var _allowNonInteractiveWebviewWhen = _initialAllowNonInteractiveWebvieWhen;

class CloudflareHandlerRateLimitException implements Exception {
	final String message;
	const CloudflareHandlerRateLimitException(this.message);
	@override
	String toString() => message;
}

class CloudflareHandlerInterruptedException implements Exception {
	const CloudflareHandlerInterruptedException();
	@override
	String toString() => 'Cloudflare challenge handler interrupted';
}

dynamic _decode(String data) {
	if (data.startsWith('{') || data.startsWith('[')) {
		try {
			return jsonDecode(data);
		}
		on FormatException {
			// ignore
		}
	}
	return data;
}


typedef _CloudflareResponse = ({String? content, Uri? uri});

extension on _CloudflareResponse {
	Response? response(RequestOptions options) {
		return Response(
			requestOptions: options,
			data: content == null ? null : _decode(content!),
			isRedirect: uri != options.uri,
			redirects: [
				if (uri != null && uri != options.uri) RedirectRecord(302, 'GET', uri!)
			],
			statusCode: content == null ? 302 : 200,
			extra: {
				'cloudflare': true
			}
		);
	}
} 

final _lock = Mutex();

/// Block any processing while Cloudflare is clearing, so that the new cookies
/// can be injected by a later interceptor
class CloudflareBlockingInterceptor extends Interceptor {
	@override
	void onRequest(RequestOptions options, RequestInterceptorHandler handler) => _lock.protect(() async {
		handler.next(options);
	});
}

class CloudflareInterceptor extends Interceptor {
	static bool _titleMatches(String title) {
		return title.contains('Cloudflare') || title.contains('Just a moment') || title.contains('Please wait') || title.contains('Verification Required');
	}

	static bool _responseMatches(Response response) {
		if ([403, 503].contains(response.statusCode) && response.headers.value(Headers.contentTypeHeader)!.contains('text/html')) {
			final document = parse(response.data);
			final title = document.querySelector('title')?.text ?? '';
			return _titleMatches(title);
		}
		return false;
	}

	Future<void> _saveCookies(Uri uri) async {
		final cookies = await CookieManager.instance().getCookies(url: WebUri.uri(uri));
		await Persistence.currentCookies.saveFromResponse(uri, cookies.map((cookie) {
			final newCookie = io.Cookie(cookie.name, cookie.value);
			newCookie.domain = cookie.domain;
			if (cookie.expiresDate != null) {
				newCookie.expires = DateTime.fromMillisecondsSinceEpoch(cookie.expiresDate!);
			}
			newCookie.httpOnly = cookie.isHttpOnly ?? false;
			newCookie.path = cookie.path;
			newCookie.secure = cookie.isSecure ?? false;
			return newCookie;
		}).toList());
	}

	Future<_CloudflareResponse> _useWebview({
		bool skipHeadless = false,
		InAppWebViewInitialData? initialData,
		URLRequest? initialUrlRequest,
		required String userAgent,
		required Uri cookieUrl,
		required bool interactive
	}) => _lock.protect(() async {
		assert(initialData != null || initialUrlRequest != null);
		await CookieManager.instance().deleteAllCookies();
		final initialSettings = InAppWebViewSettings(
			userAgent: userAgent,
			clearCache: true,
			clearSessionCache: true,
			transparentBackground: true
		);
		void Function(InAppWebViewController, Uri?) buildOnLoadStop(ValueChanged<_CloudflareResponse> callback) => (controller, uri) async {
			controller.evaluateJavascript(source: '''
				var style = document.createElement('style');
				style.innerHTML = "* { color: ${EffectiveSettings.instance.theme.primaryColor.toCssHex()} !important; }";
				document.head.appendChild(style);
				document.body.bgColor = "${EffectiveSettings.instance.theme.backgroundColor.toCssHex()}";
			''');
			if ((uri?.host.isEmpty ?? false) && uri?.scheme != 'data') {
				final correctedUri = uri!.replace(
					scheme: cookieUrl.scheme,
					host: cookieUrl.host
				);
				await _saveCookies(correctedUri);
				callback((content: null, uri: correctedUri));
				return;
			}
			final title = await controller.getTitle() ?? '';
			if (!_titleMatches(title)) {
				await _saveCookies(uri!);
				final html = await controller.getHtml() ?? '';
				if (html.contains('<pre')) {
					// Raw JSON response, but web-view has put it within a <pre>
					final document = parse(html);
					callback((content: document.querySelector('pre')!.text, uri: uri));
				}
				else {
					callback((content: html, uri: uri));
				}
			}
		};
		HeadlessInAppWebView? headlessWebView;
		if (!skipHeadless) {
			final headlessCompleter = Completer<_CloudflareResponse>();
			headlessWebView = HeadlessInAppWebView(
				initialSettings: initialSettings,
				initialUrlRequest: initialUrlRequest,
				initialData: initialData,
				onLoadStop: buildOnLoadStop(headlessCompleter.complete)
			);
			await headlessWebView.run();
			showToast(
				context: ImageboardRegistry.instance.context!,
				message: 'Authorizing Cloudflare',
				icon: CupertinoIcons.cloud
			);
			await Future.any([
				headlessCompleter.future,
				Future.delayed(const Duration(seconds: 7))
			]);
			if (headlessCompleter.isCompleted) {
				headlessWebView.dispose();
				return headlessCompleter.future;
			}
		}
		if (!interactive && DateTime.now().isBefore(_allowNonInteractiveWebviewWhen.timePasses)) {
			// User recently rejected a non-interactive cloudflare login, reject it
			throw CloudflareHandlerRateLimitException('Too many Cloudflare challenges! Try again ${formatRelativeTime(_allowNonInteractiveWebviewWhen.timePasses)}');
		}
		final ret = await Navigator.of(ImageboardRegistry.instance.context!).push<_CloudflareResponse>(adaptivePageRoute(
			builder: (context) => AdaptiveScaffold(
				bar: const AdaptiveBar(
					title: Text('Cloudflare Login')
				),
				disableAutoBarHiding: true,
				body: SafeArea(
					child: InAppWebView(
						headlessWebView: headlessWebView,
						initialSettings: initialSettings,
						initialUrlRequest: initialUrlRequest,
						initialData: initialData,
						onLoadStop: buildOnLoadStop(Navigator.of(context).pop),
					)
				)
			)
		));
		headlessWebView?.dispose();
		if (ret == null) {
			// User closed the page manually, block non-interactive cloudflare challenges for a while
			_allowNonInteractiveWebviewWhen = (
				timePasses: DateTime.now().add(const Duration(minutes: 15)),
				hostPasses: cookieUrl.host
			);
			throw const CloudflareHandlerInterruptedException();
		}
		if (cookieUrl.host == _allowNonInteractiveWebviewWhen.hostPasses) {
			// Cloudflare passed on the previously-blocked host
			_allowNonInteractiveWebviewWhen = _initialAllowNonInteractiveWebvieWhen;
		}
		return ret;
	});

	@override
	void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
		if (options.cloudflare) {
			try {
				if (options.data is FormData) {
					options.headers[Headers.contentTypeHeader] =
							'multipart/form-data; boundary=${options.data.boundary}';
					options.data = await (options.data as FormData).finalize().fold<List<int>>([], (a, b) => a + b);
				}
				else if (options.data is String) {
					options.data = utf8.encode(options.data);
				}
				else if (Transformer.isJsonMimeType(options.contentType)) {
					options.data = utf8.encode(jsonEncode(options.data));
				}
				else if (options.data is Map) {
					options.headers[Headers.contentTypeHeader] = Headers.formUrlEncodedContentType;
					options.data = utf8.encode(Transformer.urlEncodeMap(options.data));
				}
				final data = await _useWebview(
					cookieUrl: options.uri,
					userAgent: options.headers['user-agent'] ?? Persistence.settings.userAgent,
					initialUrlRequest: URLRequest(
						url: WebUri.uri(options.uri),
						method: options.method,
						headers: {
							for (final h in options.headers.entries) h.key: h.value
						},
						body: options.data == null ? null : Uint8List.fromList(options.data)
					),
					interactive: options.interactive
				);
				final newResponse = data.response(options);
				if (newResponse != null) {
					handler.resolve(newResponse, true);
					return;
				}
			}
			catch (e) {
				handler.reject(DioError(
					requestOptions: options,
					error: e
				));
				return;
			}
		}
		handler.next(options);
	}

	@override
	void onResponse(Response response, ResponseInterceptorHandler handler) async {
		if (_responseMatches(response)) {
			try {
				final data = await _useWebview(
					cookieUrl: response.requestOptions.uri,
					userAgent: response.requestOptions.headers['user-agent'] ?? Persistence.settings.userAgent,
					initialData: InAppWebViewInitialData(
						data: response.data,
						baseUrl: WebUri.uri(response.realUri)
					),
					interactive: response.requestOptions.interactive
				);
				final newResponse = data.response(response.requestOptions);
				if (newResponse != null) {
					handler.next(newResponse);
					return;
				}
			}
			catch (e) {
				handler.reject(DioError(
					requestOptions: response.requestOptions,
					error: e
				));
				return;
			}
		}
		handler.next(response);
	}

	@override
	void onError(DioError err, ErrorInterceptorHandler handler) async {
		if (err.type == DioErrorType.response && err.response != null && _responseMatches(err.response!)) {
			try {
				final data = await _useWebview(
					cookieUrl: err.requestOptions.uri,
					userAgent: err.requestOptions.headers['user-agent'] ?? Persistence.settings.userAgent,
					initialData: InAppWebViewInitialData(
						data: err.response!.data,
						baseUrl: WebUri.uri(err.response!.realUri)
					),
					interactive: err.requestOptions.interactive
				);
				final newResponse = data.response(err.requestOptions);
				if (newResponse != null) {
					handler.resolve(newResponse);
					return;
				}
			}
			catch (e) {
				handler.reject(DioError(
					requestOptions: err.requestOptions,
					error: e
				));
			}
		}
		handler.next(err);
	}
}
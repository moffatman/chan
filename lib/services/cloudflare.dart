import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:html/parser.dart';
import 'package:mutex/mutex.dart';

extension CloudflareWanted on RequestOptions {
	bool get cloudflare => extra['cloudflare'] == true;
	RequestPriority get priority => (extra[kPriority] as RequestPriority?) ?? RequestPriority.functional;
}
extension CloudflareHandled on Response {
	bool get cloudflare => extra['cloudflare'] == true;
}

extension _Cloudflare on RequestPriority {
	bool get shouldPopupCloudflare => switch(this) {
		RequestPriority.interactive || RequestPriority.functional => true,
		RequestPriority.cosmetic => false
	};
}

final _initialAllowNonInteractiveWebvieWhen = (timePasses: DateTime(2000), hostPasses: '');
var _allowNonInteractiveWebviewWhen = _initialAllowNonInteractiveWebvieWhen;

class CloudflareHandlerRateLimitException implements Exception {
	final String message;
	const CloudflareHandlerRateLimitException(this.message);
	@override
	String toString() => message;
}

class CloudflareHandlerNotAllowedException implements Exception {
	const CloudflareHandlerNotAllowedException();
	@override
	String toString() => 'Cloudflare handling disabled for this request';
}

class CloudflareHandlerInterruptedException implements Exception {
	const CloudflareHandlerInterruptedException();
	@override
	String toString() => 'Cloudflare challenge handler interrupted';
}

class CloudflareHandlerBlockedException implements Exception {
	const CloudflareHandlerBlockedException();
	@override
	String toString() => 'Cloudflare clearance was blocked by the server';
}

dynamic _decode(ResponseType type, String data) {
	if (type == ResponseType.json && (data.startsWith('{') || data.startsWith('['))) {
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
			data: content == null ? null : _decode(options.responseType, content!),
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

extension _TopLevelHost on Uri {
	String get topLevelHost {
		final host = this.host;
		final lastDotPos = host.lastIndexOf('.');
		if (lastDotPos <= 0) {
			// Something weird just give up
			return host;
		}
		final secondLastDotPos = host.lastIndexOf('.', lastDotPos - 1);
		if (secondLastDotPos == -1) {
			// No subdomain
			return host;
		}
		return host.substring(secondLastDotPos + 1);
	}
}

/// Block any processing while Cloudflare is clearing, so that the new cookies
/// can be injected by a later interceptor
class CloudflareBlockingInterceptor extends Interceptor {
	@override
	void onRequest(RequestOptions options, RequestInterceptorHandler handler) => runEphemerallyLocked(options.uri.topLevelHost, () async {
		handler.next(options);
	});
}

class CloudflareInterceptor extends Interceptor {
	static bool _titleMatches(String title) {
		return [
			'Cloudflare',
			'Just a moment',
			'Please wait',
			'Verification Required',
			'Un momento',
			'Um momento'
			'لحظة'
		].any((snippet) => title.contains(snippet)) || [
			'…',
			'...'
		].any((ending) => title.endsWith(ending)) || [
			'McChallenge'
		].any((str) => title == str);
	}

	static bool _responseMatches(Response response) {
		if ([403, 503].contains(response.statusCode) && response.headers.value(Headers.contentTypeHeader)!.contains('text/html')) {
			final document = parse(response.data);
			final title = document.querySelector('title')?.text ?? '';
			return _titleMatches(title);
		}
		if ((response.headers.value(Headers.contentTypeHeader)?.contains('text/html') ?? false) &&
				response.data is String &&
				response.data.contains('<title>McChallenge</title>')) {
			return true;
		}
		return false;
	}

	static bool _bodyMatchesBlock(String data) {
		final lower = data.toLowerCase();
		return [
			'you have been blocked',
			'the action you just performed triggered the security solution',
			'https://www.cloudflare.com/5xx-error-landing'
		].every((substring) => lower.contains(substring));
	}

	static bool _responseMatchesBlock(Response response) {
		if ([403, 503].contains(response.statusCode) && response.headers.value(Headers.contentTypeHeader)!.contains('text/html')) {
			return _bodyMatchesBlock(response.data);
		}
		return false;
	}

	static final _bodyStartsWithOpeningCurlyBrace = RegExp(r'<body[^>]*>{');

	static final _webViewLock = Mutex();
	static Future<_CloudflareResponse> _useWebview({
		bool skipHeadless = false,
		InAppWebViewInitialData? initialData,
		URLRequest? initialUrlRequest,
		required String userAgent,
		required Uri cookieUrl,
		required RequestPriority priority
	}) => runEphemerallyLocked(cookieUrl.topLevelHost, () => _webViewLock.protect(() async {
		assert(initialData != null || initialUrlRequest != null);
		await CookieManager.instance().deleteAllCookies();
		final initialSettings = InAppWebViewSettings(
			userAgent: userAgent,
			clearCache: true,
			clearSessionCache: true,
			transparentBackground: true
		);
		void Function(InAppWebViewController, Uri?) buildOnLoadStop(ValueChanged<_CloudflareResponse> callback, ValueChanged<Exception> errorCallback) => (controller, uri) async {
			await controller.evaluateJavascript(source: '''
				var style = document.createElement('style');
				style.innerHTML = "* {\\
					color: ${Settings.instance.theme.primaryColor.toCssHex()} !important;\\
				}\\
				div {\\
					background: ${Settings.instance.theme.backgroundColor.toCssHex()};\\
				}\\
				html, p, h1, h2, h3, h4, h5 {\\
					background: ${Settings.instance.theme.backgroundColor.toCssHex()} !important;\\
				}";
				document.head.appendChild(style);
				document.body.bgColor = "${Settings.instance.theme.backgroundColor.toCssHex()}";
				document.body.style.background = "${Settings.instance.theme.backgroundColor.toCssHex()}";
			''');
			if ((uri?.host.isEmpty ?? false) && uri?.scheme != 'data') {
				final correctedUri = uri!.replace(
					scheme: cookieUrl.scheme,
					host: cookieUrl.host
				);
				await Persistence.saveCookiesFromWebView(correctedUri);
				callback((content: null, uri: correctedUri));
				return;
			}
			final title = await controller.getTitle() ?? '';
			if (!_titleMatches(title)) {
				await Persistence.saveCookiesFromWebView(uri!);
				final html = await controller.getHtml() ?? '';
				if (html.contains('<pre')) {
					// Raw JSON response, but web-view has put it within a <pre>
					final document = parse(html);
					callback((content: document.querySelector('pre')!.text, uri: uri));
				}
				else if (_bodyStartsWithOpeningCurlyBrace.hasMatch(html) && html.contains('}</body>')) {
					// Raw JSON response, but web-view has put it within a <body>
					final document = parse(html);
					callback((content: document.body!.text, uri: uri));
				}
				else {
					callback((content: html, uri: uri));
				}
			}
			final html = await controller.getHtml() ?? '';
			if (_bodyMatchesBlock(html)) {
				errorCallback(const CloudflareHandlerBlockedException());
			}
		};
		HeadlessInAppWebView? headlessWebView;
		if (!skipHeadless) {
			final headlessCompleter = Completer<_CloudflareResponse>();
			headlessWebView = HeadlessInAppWebView(
				initialSettings: initialSettings,
				initialUrlRequest: initialUrlRequest,
				initialData: initialData,
				onLoadStop: buildOnLoadStop(headlessCompleter.complete, headlessCompleter.completeError)
			);
			await headlessWebView.run();
			showToast(
				context: ImageboardRegistry.instance.context!,
				message: 'Authorizing Cloudflare\n${cookieUrl.host}',
				icon: CupertinoIcons.cloud
			);
			await Future.any([
				headlessCompleter.future,
				Future.delayed(const Duration(seconds: 5))
			]);
			if (headlessCompleter.isCompleted) {
				headlessWebView.dispose();
				return headlessCompleter.future;
			}
		}
		if ((priority != RequestPriority.interactive) && DateTime.now().isBefore(_allowNonInteractiveWebviewWhen.timePasses)) {
			// User recently rejected a non-interactive cloudflare login, reject it
			throw CloudflareHandlerRateLimitException('Too many Cloudflare challenges! Try again ${formatRelativeTime(_allowNonInteractiveWebviewWhen.timePasses)}');
		}
		final ret = await Navigator.of(ImageboardRegistry.instance.context!).push(adaptivePageRoute(
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
						onLoadStop: buildOnLoadStop(Navigator.of(context).pop, Navigator.of(context).pop),
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
		else if (ret is Exception) {
			throw ret;
		}
		if (cookieUrl.host == _allowNonInteractiveWebviewWhen.hostPasses) {
			// Cloudflare passed on the previously-blocked host
			_allowNonInteractiveWebviewWhen = _initialAllowNonInteractiveWebvieWhen;
		}
		return ret;
	}));

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
					priority: options.priority
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
		if (_responseMatchesBlock(response)) {
			handler.reject(DioError(
				requestOptions: response.requestOptions,
				response: response,
				error: const CloudflareHandlerBlockedException()
			));
			return;
		}
		if (_responseMatches(response)) {
			if (!response.requestOptions.priority.shouldPopupCloudflare) {
				handler.reject(DioError(
					requestOptions: response.requestOptions,
					response: response,
					error: const CloudflareHandlerNotAllowedException()
				));
				return;
			}
			try {
				final data = await _useWebview(
					cookieUrl: response.requestOptions.uri,
					userAgent: response.requestOptions.headers['user-agent'] ?? Persistence.settings.userAgent,
					initialData: InAppWebViewInitialData(
						data: response.data is String ? response.data : switch (response.requestOptions.responseType) {
							ResponseType.bytes => utf8.decode(response.data),
							ResponseType.json => jsonEncode(response.data),
							ResponseType.plain => response.data,
							ResponseType.stream => await utf8.decodeStream((response.data as ResponseBody).stream)
						},
						baseUrl: WebUri.uri(response.realUri)
					),
					priority: response.requestOptions.priority
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
					response: response,
					error: e
				));
				return;
			}
		}
		handler.next(response);
	}

	@override
	void onError(DioError err, ErrorInterceptorHandler handler) async {
		if (err.type == DioErrorType.response &&
		    err.response != null &&
				_responseMatchesBlock(err.response!)) {
			handler.reject(DioError(
				requestOptions: err.requestOptions,
				response: err.response,
				error: const CloudflareHandlerBlockedException()
			));
			return;
		}
		if (err.type == DioErrorType.response &&
		    err.response != null &&
				_responseMatches(err.response!)) {
			if (!err.requestOptions.priority.shouldPopupCloudflare) {
				handler.reject(DioError(
					requestOptions: err.requestOptions,
					response: err.response,
					error: const CloudflareHandlerNotAllowedException()
				));
				return;
			}
			try {
				final data = await _useWebview(
					cookieUrl: err.requestOptions.uri,
					userAgent: err.requestOptions.headers['user-agent'] ?? Persistence.settings.userAgent,
					initialData: InAppWebViewInitialData(
						data: err.response?.data is String ? err.response!.data : switch (err.requestOptions.responseType) {
							ResponseType.bytes => utf8.decode(err.response!.data),
							ResponseType.json => jsonEncode(err.response!.data),
							ResponseType.plain => err.response!.data,
							ResponseType.stream => await utf8.decodeStream((err.response!.data as ResponseBody).stream)
						},
						baseUrl: WebUri.uri(err.response!.realUri)
					),
					priority: err.requestOptions.priority
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
					response: err.response,
					error: e
				));
				return;
			}
		}
		handler.next(err);
	}
}
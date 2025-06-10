import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:chan/services/dark_mode_browser.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/report_bug.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:html/parser.dart';
import 'package:html/dom.dart' as dom;
import 'package:mutex/mutex.dart';

const kCloudflare = 'cloudflare';
const kRetryIfCloudflare = 'retry_cloudflare';
const kToastCloudflare = 'toast_cloudflare';
const kRedirectGateway = 'redirect_gateway';

extension CloudflareWanted on RequestOptions {
	bool get cloudflare => extra[kCloudflare] == true;
	bool get retryIfCloudflare => extra[kRetryIfCloudflare] == true;
	bool get toast => extra[kToastCloudflare] != false;
	RequestPriority get priority => (extra[kPriority] as RequestPriority?) ?? RequestPriority.functional;
}
extension CloudflareHandled on Response {
	bool get cloudflare => extra[kCloudflare] == true;
}
extension HtmlTitle on Response {
	String? get htmlTitle {
		if ((headers.value(Headers.contentTypeHeader)?.contains('text/html') ?? false) &&
				data is String) {
			return parse(data).querySelector('title')?.text;
		}
		return null;
	}
}

Future<String> _bodyAsString(dynamic data) async => switch (data) {
	String raw => raw,
	List<int> bytes => utf8.decode(bytes),
	ResponseBody stream => await utf8.decodeStream(stream.stream),
	Object? other => jsonEncode(other)
};

Future<({Uint8List data, String contentType})?> _requestDataAsBytes(RequestOptions options) async {
	if (options.method.toUpperCase() == 'GET') {
		// GET cannot include body. WebView will break if you include it
		return null;
	}
	if (options.data == null) {
		return null;
	}
	final Uint8List data;
	final String contentType;
	if (options.data is FormData) {
		contentType = 'multipart/form-data; boundary=${options.data.boundary}';
		data = Uint8List.fromList(await (options.data as FormData).finalize().fold<List<int>>([], (a, b) => a + b));
	}
	else if (options.data case String str) {
		data = utf8.encode(str);
		contentType = 'text/plain';
	}
	else if (Transformer.isJsonMimeType(options.contentType)) {
		data = utf8.encode(jsonEncode(options.data));
		contentType = 'application/json';
	}
	else if (options.data case Map map) {
		contentType = Headers.formUrlEncodedContentType;
		data = utf8.encode(Transformer.urlEncodeMap(map));
	}
	else {
		return null;
	}
	return (data: data, contentType: contentType);
}

extension _Cloudflare on RequestPriority {
	bool get shouldPopupCloudflare => switch(this) {
		RequestPriority.interactive || RequestPriority.functional => true,
		RequestPriority.cosmetic => false
	};
}

final _initialAllowNonInteractiveWebvieWhen = (timePasses: DateTime(2000), hostPasses: '');
var _allowNonInteractiveWebviewWhen = _initialAllowNonInteractiveWebvieWhen;
void _resetAllowNonInteractiveWebview(BuildContext context) {
	_allowNonInteractiveWebviewWhen = _initialAllowNonInteractiveWebvieWhen;
}

class CloudflareHandlerRateLimitException extends ExtendedException {
	final String message;
	const CloudflareHandlerRateLimitException(this.message);
	@override
	bool get isReportable => false;
	@override
	Map<String, FutureOr<void> Function(BuildContext)> get remedies => const {
		'Reset timer': _resetAllowNonInteractiveWebview
	};
	@override
	String toString() => message;
}

class CloudflareHandlerNotAllowedException implements Exception {
	const CloudflareHandlerNotAllowedException();
	@override
	String toString() => 'Cloudflare handling disabled for this request';
}

class CloudflareHandlerInterruptedException extends ExtendedException {
	final String gatewayName;
	const CloudflareHandlerInterruptedException(this.gatewayName);
	@override
	bool get isReportable => false;
	@override
	String toString() => '$gatewayName challenge handler interrupted';
}

class CloudflareHandlerBlockedException implements Exception {
	const CloudflareHandlerBlockedException();
	@override
	String toString() => 'Cloudflare clearance was blocked by the server';
}

({dynamic data, bool isJson}) _decode(ResponseType type, String data) {
	if (type == ResponseType.json && (data.startsWith('{') || data.startsWith('['))) {
		try {
			return (data: jsonDecode(data), isJson: true);
		}
		on FormatException {
			// ignore
		}
	}
	if (type == ResponseType.bytes) {
		return (data: utf8.encode(data), isJson: false);
	}
	if (type == ResponseType.stream) {
		return (data: ResponseBody.fromString(data, 200), isJson: false);
	}
	return (data: data, isJson: false);
}


typedef _CloudflareResponse = ({String? content, Uri? uri});

extension on _CloudflareResponse {
	Response? response(RequestOptions options) {
		final resp = switch (content) {
			null => (data: null, isJson: false),
			String content => _decode(options.responseType ?? ResponseType.json, content)
		};
		return Response(
			requestOptions: options,
			data: resp.data,
			isRedirect: uri != options.uri,
			redirects: [
				if (uri != null && uri != options.uri) RedirectRecord(302, 'GET', uri!)
			],
			headers: Headers.fromMap({
				if (resp.isJson) Headers.contentTypeHeader: [Headers.jsonContentType]
			}),
			statusCode: content == null ? 302 : 200,
			extra: {
				kCloudflare: true
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

extension _WebViewRedirect on Uri {
	bool get looksLikeWebViewRedirect => host.isEmpty && scheme != 'data';
}

extension _FillInBlanks on Uri {
	Uri fillInFrom(Uri otherUri) => replace(
		scheme: scheme.nonEmptyOrNull ?? otherUri.scheme,
		host: host.nonEmptyOrNull ?? otherUri.host
	);
}

class CloudflareUserException extends ExtendedException {
	final Uri originalUrl;
	CloudflareUserException({
		required this.originalUrl,
		required Uri? currentUrl,
		required List<io.Cookie> cookies,
		required String? html,
		required String? title
	}) : super(
		additionalFiles: {
			'log.txt': utf8.encode('Original URL: $originalUrl\nCurrent URL: $currentUrl\nCookies: $cookies\nTitle: $title\nHTML follows:\n$html')
		}
	);
	@override
	bool get isReportable => true;
	@override
	String toString() => 'CloudflareUserException(originalUrl: $originalUrl)';
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
		].any((ending) => title.endsWith(ending));
	}

	static bool _responseMatches(Response response) {
		if ([403, 503].contains(response.statusCode) && (response.headers.value(Headers.contentTypeHeader)?.contains('text/html') ?? false)) {
			if (response.headers.value('server') == 'cloudflare' && response.headers.value('cf-mitigated') == 'challenge') {
				// Hopefully this catches the streamed ones
				return true;
			}
			if (response.data is ResponseBody) {
				// Can't really inspect it
				return false;
			}
			final document = parse(response.data);
			final title = document.querySelector('title')?.text ?? '';
			return _titleMatches(title);
		}
		if (ImageboardRegistry.instance.isRedirectGateway(response.redirects.tryLast?.location, response.htmlTitle)) {
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

	static Future<bool> _responseMatchesBlock(Response response) async {
		if ([403, 503].contains(response.statusCode) && (response.headers.value(Headers.contentTypeHeader)?.contains('text/html') ?? false)) {
			if (response.data is ResponseBody) {
				// Can't really inspect it
				return false;
			}
			return _bodyMatchesBlock(await _bodyAsString(response.data));
		}
		return false;
	}

	static Future<_CloudflareResponse> Function(InAppWebViewController, Uri?) _buildHandler(Uri initialUrl) => (controller, uri) async {
		if (uri?.looksLikeWebViewRedirect ?? false) {
			final correctedUri = uri!.replace(
				scheme: initialUrl.scheme,
				host: initialUrl.host
			);
			return (content: null, uri: correctedUri);
		}
		final html = await controller.getHtml() ?? '';
		final document = parse(html);
		final headNodes = document.head?.nodes.toList() ?? [];
		headNodes.removeWhere((node) {
			if (node is dom.Element && node.localName == 'style' && node.innerHtml == kDarkModeCss) {
				// We injected it
				return true;
			}
			if (node is dom.Element && node.localName == 'meta' && node.attributes['name'] == 'color-scheme') {
				// This one shows up sometimes on iOS
				return true;
			}
			if (node is dom.Element && node.localName == 'meta' && node.attributes['charset'] == 'utf-8') {
				// This one shows up on Android
				return true;
			}
			return false;
		});
		if (headNodes.isEmpty) {
			// This is a dummy page
			if (document.body?.nodes.tryFirst case dom.Element e) {
				if (e.localName == 'pre') {
					return (content: e.text, uri: uri);
				}
			}
			if (document.body?.innerHtml case String content) {
				return (content: content, uri: uri);
			}
		}
		return (content: html, uri: uri);
	};

	static const _kDefaultGatewayName = 'Cloudflare';
	static const kDefaultHeadlessTime = Duration(seconds: 5);

	static final _webViewLock = Mutex();
	static Future<T> _useWebview<T>({
		required Future<T> Function(InAppWebViewController, Uri?) handler,
		bool skipHeadless = false,
		Duration headlessTime = kDefaultHeadlessTime,
		InAppWebViewInitialData? initialData,
		URLRequest? initialUrlRequest,
		required String userAgent,
		required Uri cookieUrl,
		required RequestPriority priority,
		bool toast = true,
		String? autoClickSelector,
		String gatewayName = _kDefaultGatewayName,
		CancelToken? cancelToken
	}) => runEphemerallyLocked(cookieUrl.topLevelHost, () => _webViewLock.protect(() async {
		assert(initialData != null || initialUrlRequest != null);
		HeadlessInAppWebView? headlessWebView;
		try {
			final manager = CookieManager.instance();
			await manager.deleteAllCookies();
			final cookies = await Persistence.currentCookies.loadForRequest(cookieUrl);
			for (final cookie in cookies) {
				if (cookie.value.isEmpty) {
					continue;
				}
				await manager.setCookie(
					url: WebUri.uri(cookieUrl),
					domain: cookie.domain,
					name: cookie.name,
					value: cookie.value,
					path: cookie.path ?? '/',
					expiresDate: cookie.expires?.millisecondsSinceEpoch,
					maxAge: cookie.maxAge,
					isHttpOnly: cookie.httpOnly,
					isSecure: cookie.secure,
					sameSite: HTTPCookieSameSitePolicy.fromValue(cookie.sameSite?.name)
				);
			}
			final initialSettings = InAppWebViewSettings(
				userAgent: userAgent,
				clearCache: true,
				clearSessionCache: true,
				transparentBackground: true
			);
			bool firstLoad = true;
			InAppWebViewController? lastController;
			late ValueChanged<AsyncSnapshot<T>> callback_;
			AsyncSnapshot<T>? callbackValue;
			void callback(AsyncSnapshot<T> value) {
				if (callbackValue != null) {
					Future.error(Exception('Tried to callback with $value, but already had $callbackValue'), StackTrace.current);
					return;
				}
				callbackValue = value;
				callback_(value);
			}
			void onReceivedError(InAppWebViewController controller, WebResourceRequest request, WebResourceError error) {
				if (callbackValue == null && firstLoad) {
					callback(AsyncSnapshot.withError(ConnectionState.done, error, StackTrace.current));
				}
			}
			void onLoadStop(InAppWebViewController controller, WebUri? uri) async {
				lastController = controller;
				await maybeApplyDarkModeBrowserJS(controller);
				final title = await controller.getTitle() ?? '';
				if (!ImageboardRegistry.instance.isRedirectGateway(uri, title) && (!_titleMatches(title) || (uri?.looksLikeWebViewRedirect ?? false))) {
					await Persistence.saveCookiesFromWebView(uri!);
					try {
						final value = await handler(controller, uri);
						callback(AsyncSnapshot.withData(ConnectionState.done, value));
					}
					catch (e, st) {
						callback(AsyncSnapshot.withError(ConnectionState.done, e, st));
					}
					return;
				}
				final html = await controller.getHtml() ?? '';
				if (_bodyMatchesBlock(html)) {
					callback(AsyncSnapshot.withError(ConnectionState.done, const CloudflareHandlerBlockedException(), StackTrace.current));
				}
				if (autoClickSelector != null && firstLoad) {
					firstLoad = false;
					await controller.evaluateJavascript(source: 'document.querySelector("$autoClickSelector").click()');
				}
			}
			if (!skipHeadless) {
				final headlessCompleter = Completer<AsyncSnapshot<T>>();
				callback_ = headlessCompleter.complete;
				headlessWebView = HeadlessInAppWebView(
					initialSettings: initialSettings,
					initialUrlRequest: initialUrlRequest,
					initialData: initialData,
					onLoadStop: onLoadStop,
					onReceivedError: onReceivedError,
					onConsoleMessage: kDebugMode ? (controller, msg) => print(msg) : null
				);
				await headlessWebView.run();
				if (toast) {
					showToast(
						context: ImageboardRegistry.instance.context!,
						message: 'Authorizing $gatewayName\n${cookieUrl.host}',
						icon: CupertinoIcons.cloud
					);
				}
				await Future.any([
					headlessCompleter.future,
					Future.delayed(headlessTime),
					if (cancelToken?.whenCancel case Future<DioError> whenCancel) whenCancel
				]);
				if (headlessCompleter.isCompleted) {
					final snapshot = await headlessCompleter.future;
					if (snapshot.data case T data) {
						return data;
					}
					else {
						throw Error.throwWithStackTrace(snapshot.error!, snapshot.stackTrace ?? StackTrace.current);
					}
				}
			}
			switch (priority) {
				case RequestPriority.cosmetic:
					// We gave it a shot with headless...
					throw const CloudflareHandlerNotAllowedException();
				case RequestPriority.functional:
					if (DateTime.now().isBefore(_allowNonInteractiveWebviewWhen.timePasses)) {
						// User recently rejected a non-interactive cloudflare login, reject it
						throw CloudflareHandlerRateLimitException('Too many Cloudflare challenges! Try again ${formatRelativeTime(_allowNonInteractiveWebviewWhen.timePasses)}');
					}
				case RequestPriority.interactive:
					// Allow popup
			}
			if (cancelToken?.isCancelled ?? false) {
				throw CloudflareHandlerInterruptedException(gatewayName);
			}
			final navigator = Navigator.of(ImageboardRegistry.instance.context!);
			final settings = RouteSettings(name: 'cloudflare${DateTime.now().millisecondsSinceEpoch}');
			cancelToken?.whenCancel.then((_) {
				// Close the popup if still open
				navigator.popUntil((r) => r.settings != settings);
			});
			final stackTrace = StackTrace.current;
			callback_ = navigator.pop;
			final ret = await navigator.push<AsyncSnapshot<T>>(adaptivePageRoute(
				builder: (context) => AdaptiveScaffold(
					bar: AdaptiveBar(
						title: Text('$gatewayName Login'),
						actions: [
							AdaptiveIconButton(
								icon: const Icon(CupertinoIcons.exclamationmark_triangle),
								onPressed: () async {
									reportBug(CloudflareUserException(
										originalUrl: cookieUrl,
										currentUrl: (await lastController?.getUrl())?.uriValue,
										cookies: cookies,
										html: await lastController?.getHtml(),
										title: await lastController?.getTitle()
									), stackTrace);
								}
							)
						]
					),
					disableAutoBarHiding: true,
					body: SafeArea(
						child: InAppWebView(
							headlessWebView: headlessWebView,
							initialSettings: initialSettings,
							initialUrlRequest: initialUrlRequest,
							initialData: initialData,
							onLoadStop: onLoadStop,
							onReceivedError: onReceivedError,
							onConsoleMessage: kDebugMode ? (controller, msg) => print(msg) : null
						)
					)
				),
				settings: settings,
				useFullWidthGestures: gatewayName == _kDefaultGatewayName // Normal cloudflare should be OK
			));
			if (ret == null) {
				// User closed the page manually, block non-interactive cloudflare challenges for a while
				_allowNonInteractiveWebviewWhen = (
					timePasses: DateTime.now().add(const Duration(minutes: 15)),
					hostPasses: cookieUrl.host
				);
				throw CloudflareHandlerInterruptedException(gatewayName);
			}
			else if (ret.hasError) {
				Error.throwWithStackTrace(ret.error!, ret.stackTrace ?? StackTrace.current);
			}
			if (cookieUrl.host == _allowNonInteractiveWebviewWhen.hostPasses) {
				// Cloudflare passed on the previously-blocked host
				_allowNonInteractiveWebviewWhen = _initialAllowNonInteractiveWebvieWhen;
			}
			return ret.data as T;
		}
		finally {
			headlessWebView?.dispose();
		}
	}));

	@override
	void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
		final redirectGateway = options.extra[kRedirectGateway] as ImageboardRedirectGateway?;
		if (options.cloudflare || redirectGateway != null) {
			try {
				final requestData = await _requestDataAsBytes(options);
				final data = await _useWebview(
					handler: _buildHandler(options.uri),
					cookieUrl: options.uri,
					userAgent: options.headers['user-agent'] as String? ?? Settings.instance.userAgent,
					initialUrlRequest: URLRequest(
						url: WebUri.uri(options.uri),
						mainDocumentURL: WebUri.uri(options.uri),
						method: options.method,
						headers: {
							for (final h in options.headers.entries)
								if (h.value case String value)
									h.key: value,
							if (requestData != null)
								Headers.contentTypeHeader: requestData.contentType
						},
						body: requestData?.data
					),
					priority: options.priority,
					cancelToken: options.cancelToken,
					autoClickSelector: redirectGateway?.autoClickSelector,
					gatewayName: redirectGateway?.name ?? _kDefaultGatewayName,
					toast: options.toast && redirectGateway == null // Not forced
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
		try {
			if (await _responseMatchesBlock(response)) {
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
				final _CloudflareResponse data;
				final gateway = ImageboardRegistry.instance.getRedirectGateway(response.redirects.tryLast?.location.fillInFrom(response.requestOptions.uri), response.htmlTitle);
				if (gateway != null) {
					// Start the request again
					// We need to ensure cookies are preserved in all navigation sequences
					final requestData = await _requestDataAsBytes(response.requestOptions);
					data = await _useWebview(
						handler: _buildHandler(response.requestOptions.uri),
						cookieUrl: response.requestOptions.uri,
						userAgent: (response.requestOptions.headers['user-agent'] as String?) ?? Settings.instance.userAgent,
						skipHeadless: gateway.alwaysNeedsManualSolving,
						autoClickSelector: gateway.autoClickSelector,
						initialUrlRequest: URLRequest(
							url: WebUri.uri(response.requestOptions.uri),
							mainDocumentURL: WebUri.uri(response.requestOptions.uri),
							method: response.requestOptions.method,
							headers: {
								for (final h in response.requestOptions.headers.entries) h.key: h.value.toString(),
								if (requestData != null)
									Headers.contentTypeHeader: requestData.contentType
							},
							body: requestData?.data
						),
						priority: response.requestOptions.priority,
						gatewayName: gateway.name,
						cancelToken: response.requestOptions.cancelToken
					);
				 }
				 else {
					data = await _useWebview(
						handler: _buildHandler(response.requestOptions.uri),
						cookieUrl: response.requestOptions.uri,
						userAgent: (response.requestOptions.headers['user-agent'] as String?) ?? Settings.instance.userAgent,
						initialData: InAppWebViewInitialData(
							data: await _bodyAsString(response.data),
							baseUrl: WebUri.uri(response.realUri.fillInFrom(response.requestOptions.uri))
						),
						priority: response.requestOptions.priority,
						cancelToken: response.requestOptions.cancelToken
					);
				}
				final newResponse = data.response(response.requestOptions);
				if (newResponse != null) {
					handler.next(newResponse);
					return;
				}
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
		handler.next(response);
	}

	@override
	void onError(DioError err, ErrorInterceptorHandler handler) async {
		try {
			if (err.type == DioErrorType.response &&
					err.response != null &&
					await _responseMatchesBlock(err.response!)) {
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
				final data = await _useWebview(
					handler: _buildHandler(err.requestOptions.uri),
					cookieUrl: err.requestOptions.uri,
					userAgent: err.requestOptions.headers['user-agent'] as String? ?? Settings.instance.userAgent,
					initialData: InAppWebViewInitialData(
						data: await _bodyAsString(err.response?.data),
						baseUrl: WebUri.uri(err.response!.realUri.fillInFrom(err.requestOptions.uri))
					),
					priority: err.requestOptions.priority,
					cancelToken: err.requestOptions.cancelToken
				);
				final newResponse = data.response(err.requestOptions);
				if (newResponse != null) {
					handler.resolve(newResponse, true);
					return;
				}
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
		handler.next(err);
	}
}

/// For requests that probably can't use cloudflare-cleared data
/// E.g. because null bytes are dropped in webview
class RetryIfCloudflareInterceptor extends Interceptor {
	final Dio client;
	RetryIfCloudflareInterceptor(this.client);
	@override
	void onResponse(Response response, ResponseInterceptorHandler handler) async {
		if (response.cloudflare && response.requestOptions.retryIfCloudflare) {
			try {
				final response2 = await client.requestUri(
					response.requestOptions.uri,
					data: response.requestOptions.data,
					cancelToken: response.requestOptions.cancelToken,
					options: Options(
						headers: response.requestOptions.headers,
						extra: {
							...response.requestOptions.extra,
							kRetryIfCloudflare: false
						},
						responseType: response.requestOptions.responseType,
						contentType: response.requestOptions.contentType,
						validateStatus: response.requestOptions.validateStatus
					)
				);
				handler.next(response2);
			}
			catch (e, st) {
				if (e is DioError) {
					handler.reject(e);
				}
				else {
					handler.reject(DioError(
						requestOptions: response.requestOptions,
						response: response,
						error: e
					)..stackTrace = st);
				}
			}
		}
		else {
			handler.next(response);
		}
	}
}

Future<T> useCloudflareClearedWebview<T>({
	required Future<T> Function(InAppWebViewController, Uri?) handler,
	required Uri uri,
	String? userAgent,
	required RequestPriority priority,
	bool toast = true,
	required String gatewayName,
	CancelToken? cancelToken,
	bool skipHeadless = false,
	Duration? headlessTime
}) => CloudflareInterceptor._useWebview(
	handler: handler,
	cookieUrl: uri,
	userAgent: userAgent ?? Settings.instance.userAgent,
	initialUrlRequest: URLRequest(
		url: WebUri.uri(uri),
		mainDocumentURL: WebUri.uri(uri),
		method: 'GET',
		body: null
	),
	priority: priority,
	toast: toast,
	gatewayName: gatewayName,
	skipHeadless: skipHeadless,
	headlessTime: headlessTime ?? CloudflareInterceptor.kDefaultHeadlessTime,
	cancelToken: cancelToken
);

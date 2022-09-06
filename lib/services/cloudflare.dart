import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/cupertino_page_route.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:html/parser.dart';
import 'package:provider/provider.dart';

class CloudflareInterceptor extends Interceptor {
	static bool _titleMatches(String title) {
		return title.contains('Cloudflare') || title.contains('Just a moment') || title.contains('Please wait');
	}

	static bool _responseMatches(Response response) {
		if ([403, 503].contains(response.statusCode) && response.headers.value(Headers.contentTypeHeader)!.contains('text/html')) {
			final document = parse(response.data);
			final title = document.querySelector('title')?.text ?? '';
			return _titleMatches(title);
		}
		return false;
	}

	Future<String?> _useWebview(Uri desiredUrl) async {
		final initialOptions = InAppWebViewGroupOptions(
			crossPlatform: InAppWebViewOptions(
				userAgent: userAgent
			)
		);
		final initialUrlRequest = URLRequest(
			url: desiredUrl,
			headers: {
				'Cookie': (await Persistence.cookies.loadForRequest(desiredUrl)).join('; ')
			},
			iosHttpShouldHandleCookies: false
		);
		void Function(InAppWebViewController, Uri?) buildOnLoadStop(ValueChanged<String?> callback) => (controller, uri) async {
			final title = await controller.getTitle() ?? '';
			if (!_titleMatches(title)) {
				final cookies = await CookieManager.instance().getCookies(url: uri!);
				Persistence.cookies.saveFromResponse(uri, cookies.map((cookie) {
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
				final html = await controller.getHtml() ?? '';
				final jsonAsHtmlPattern = RegExp(r'<html><head><\/head><body><pre style="word-wrap: break-word; white-space: pre-wrap;">(.*)<\/pre><\/body><\/html>');
				final jsonAsHtmlMatch = jsonAsHtmlPattern.firstMatch(html);
				if (jsonAsHtmlMatch != null) {
					callback(jsonAsHtmlMatch.group(1)!);
				}
				else {
					callback(html);
				}
			}
		};
		final headlessCompleter = Completer<String?>();
		final headlessWebView = HeadlessInAppWebView(
			initialOptions: initialOptions,
			initialUrlRequest: initialUrlRequest,
			onLoadStop: buildOnLoadStop(headlessCompleter.complete)
		);
		await headlessWebView.run();
		print('cloudflare now');
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
			return headlessCompleter.future;
		}
		return await Navigator.of(ImageboardRegistry.instance.context!).push<String?>(FullWidthCupertinoPageRoute(
			builder: (context) => CupertinoPageScaffold(
				navigationBar: const CupertinoNavigationBar(
					transitionBetweenRoutes: false,
					middle: Text('Cloudflare Login')
				),
				child: InAppWebView(
					initialOptions: initialOptions,
					initialUrlRequest: initialUrlRequest,
					onLoadStop: buildOnLoadStop(Navigator.of(context).pop)
				)
			),
			// ignore: use_build_context_synchronously
			showAnimations: ImageboardRegistry.instance.context!.read<EffectiveSettings?>()?.showAnimations ?? true
		));
	}

	@override
	void onResponse(Response response, ResponseInterceptorHandler handler) async {
		if (_responseMatches(response)) {
			final response2 = await _useWebview(response.requestOptions.uri);
			if (response2 != null) {
				handler.resolve(Response(
					data: response2,
					statusCode: 200,
					requestOptions: response.requestOptions
				));
				return;
			}
		}
		handler.next(response);
	}

	@override
	void onError(DioError err, ErrorInterceptorHandler handler) async {
		if (err.type == DioErrorType.response && err.response != null && _responseMatches(err.response!)) {
			final response2 = await _useWebview(err.requestOptions.uri);
			if (response2 != null) {
				dynamic data = response2;
				if (response2.startsWith('{')) {
					try {
						data = jsonDecode(data);
					}
					on FormatException {
						// ignore
					}
				}
				handler.resolve(Response(
					data: data,
					statusCode: 200,
					requestOptions: err.requestOptions
				));
				return;
			}
		}
		handler.next(err);
	}
}
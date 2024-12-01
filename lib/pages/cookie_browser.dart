
import 'dart:convert';

import 'package:chan/services/dark_mode_browser.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/report_bug.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class CookieBrowser extends StatefulWidget {
	final Uri initialUrl;
	final Map<String, String?> formFields;
	final ValueChanged<Map<String, String>>? onFormSubmitted;
	final ValueChanged<List<Cookie>>? onCookiesSaved;

	const CookieBrowser({
		required this.initialUrl,
		this.formFields = const {},
		this.onFormSubmitted,
		this.onCookiesSaved,
		super.key
	});

	@override
	createState() => _CookieBrowserState();
}

class _CookieBrowserState extends State<CookieBrowser> {
	AsyncSnapshot<bool> _initialized = const AsyncSnapshot.waiting();
	InAppWebViewController? _controller;
	bool _canGoBack = false;
	bool _canGoForward = false;

	static const _kFormChannelName = 'formData';

	@override
	void initState() {
		super.initState();
		_initialize();
	}

	void _initialize() async {
		try {
			final manager = CookieManager.instance();
			await manager.deleteAllCookies();
			final cookies = await Persistence.currentCookies.loadForRequest(widget.initialUrl);
			for (final cookie in cookies) {
				await manager.setCookie(
					url: WebUri.uri(widget.initialUrl),
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
			_initialized = const AsyncSnapshot.withData(ConnectionState.done, true);
		}
		catch (e, st) {
			Future.error(e, st);
			_initialized = AsyncSnapshot.withError(ConnectionState.done, e, st);
		}
		if (mounted) {
			setState(() {});
		}
	}

	Widget _buildBody() {
		if (_initialized.hasError) {
			return Center(
				child: ErrorMessageCard(_initialized.error!.toStringDio(), remedies: {
					'Report bug': () => reportBug(_initialized.error!, _initialized.stackTrace!)
				})
			);
		}
		if (!_initialized.hasData) {
			return const Center(
				child: CircularProgressIndicator.adaptive()
			);
		}
		return SafeArea(
			child: InAppWebView(
				initialSettings: InAppWebViewSettings(
					transparentBackground: true,
					mediaPlaybackRequiresUserGesture: false,
					useHybridComposition: true,
					userAgent: Settings.instance.userAgent,
					allowsInlineMediaPlayback: true
				),
				initialUrlRequest: URLRequest(
					url: WebUri.uri(widget.initialUrl),
					mainDocumentURL: WebUri.uri(widget.initialUrl),
					method: 'GET'
				),
				onWebViewCreated: (controller) {
					_controller = controller;
					controller.addJavaScriptHandler(handlerName: _kFormChannelName, callback: (messages) async {
						if (messages[0] case Map map) {
							widget.onFormSubmitted?.call({
								for (final key in widget.formFields.keys)
									if (map[key] case String value)
										key: value
							});
						}
					});
					setState(() {});
				},
				onPermissionRequest: (controller, request) async {
					return PermissionResponse(
						resources: request.resources,
						action: PermissionResponseAction.GRANT
					);
				},
				onLoadStop: (controller, webUrl) async {
					await maybeApplyDarkModeBrowserJS(controller);
					if (widget.formFields.isNotEmpty) {
						// Restore field values and listen for saving upon submission
						await controller.evaluateJavascript(source: '''
							(function anon() {
								var formFields = ${jsonEncode(widget.formFields)}
								for (var name of Object.keys(formFields)) {
									var value = formFields[name]
									if (value) {
										var elem = document.querySelector("[name='" + name + "']")
										if (elem) {
											elem.value = value
										}
									}
								}
								function onSubmit(e) {
									var map = {}
									for (var name of Object.keys(formFields)) {
										console.error(name)
										var elem = document.querySelector("[name='" + name + "']")
										console.error(elem)
										if (elem) {
											map[name] = elem.value
										}
									}
									console.error(map)
									window.flutter_inappwebview.callHandler("$_kFormChannelName", map)
								}
								for (var form of document.querySelectorAll("form")) {
									form.addEventListener("submit", onSubmit)
								}
							})()
						''');
					}
					if (webUrl != null && webUrl.isValidUri) {
						final cookies = await Persistence.saveCookiesFromWebView(webUrl.uriValue);
						widget.onCookiesSaved?.call(cookies);
					}
				},
				onTitleChanged: (controller, title) async {
					_canGoBack = await controller.canGoBack();
					_canGoForward = await controller.canGoForward();
					setState(() {});
				},
				onUpdateVisitedHistory: (controller, url, androidIsReload) async {
					_canGoBack = await controller.canGoBack();
					_canGoForward = await controller.canGoForward();
					setState(() {});
				}
			)
		);
	}

	@override
	Widget build(BuildContext context) {
		return AdaptiveScaffold(
			bar: AdaptiveBar(
				title: const Text('Browser'),
				actions: [
					AdaptiveIconButton(
						onPressed: _canGoBack ? _controller?.goBack : null,
						icon: const Icon(CupertinoIcons.arrow_left)
					),
					AdaptiveIconButton(
						onPressed: _canGoForward ? _controller?.goForward : null,
						icon: const Icon(CupertinoIcons.arrow_right)
					),
					AdaptiveIconButton(
						onPressed: _controller?.reload,
						icon: const Icon(CupertinoIcons.refresh)
					)
				]
			),
			body: _buildBody()
		);
	}
}

// For some unknown reason, need to use root navigator. or else tapping doesn't work well on iosOnMac (due to NativeDropView i guess)
Future<void> openCookieBrowser(BuildContext context, Uri url, {ValueChanged<List<Cookie>>? onCookiesSaved}) => Navigator.of(context, rootNavigator: true).push(adaptivePageRoute(
	builder: (context) => CookieBrowser(
		initialUrl: url,
		onCookiesSaved: onCookiesSaved
	)
));

const _kLoginFieldPrefix = '__cookie_browser__';

Future<void> openCookieLoginBrowser(BuildContext context, Imageboard imageboard) => Navigator.of(context, rootNavigator: true).push(adaptivePageRoute(
	useFullWidthGestures: false, // Some captchas have sliding thing
	builder: (context) => CookieBrowser(
		initialUrl: imageboard.site.authPage!,
		formFields: {
			for (final key in imageboard.site.authPageFormFields)
				key: imageboard.persistence.browserState.loginFields['$_kLoginFieldPrefix$key']
		},
		onFormSubmitted: (fields) {
			bool dirty = false;
			for (final key in imageboard.site.authPageFormFields) {
				if (fields[key] case String value) {
					imageboard.persistence.browserState.loginFields['$_kLoginFieldPrefix$key'] = value;
					dirty = true;
				}
			}
			if (dirty) {
				imageboard.persistence.didUpdateBrowserState();
			}
		},
	)
));
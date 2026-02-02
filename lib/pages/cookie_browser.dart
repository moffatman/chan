
import 'dart:async';
import 'dart:convert';

import 'package:chan/services/dark_mode_browser.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/report_bug.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mime/mime.dart';

class CookieBrowser extends StatefulWidget {
	final Uri initialUrl;
	final Map<String, dynamic> formFields;
	final ValueChanged<Map<String, String>>? onFormSubmitted;
	final ValueChanged<List<Cookie>>? onCookiesSaved;
	final ValueChanged<Uri>? onLoadStop;
	final String? javascript;

	const CookieBrowser({
		required this.initialUrl,
		this.formFields = const {},
		this.onFormSubmitted,
		this.onCookiesSaved,
		this.onLoadStop,
		this.javascript,
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
	bool _showProgress = true;
	Timer? _showProgressTimer;
	bool _loadedOnce = false;
	late final ValueNotifier<double?> _progress;

	static const _kFormChannelName = 'formData';

	@override
	void initState() {
		super.initState();
		_progress = ValueNotifier<double?>(null);
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
				child: ErrorMessageCard(
					_initialized.error!.toStringDio(),
					remedies: generateBugRemedies(_initialized.error!, _initialized.stackTrace!, context)
				)
			);
		}
		if (!_initialized.hasData) {
			return const Center(
				child: CircularProgressIndicator.adaptive()
			);
		}
		return SafeArea(
			child: Column(
				children: [
					AnimatedSwitcher(
						duration: const Duration(milliseconds: 500),
						switchInCurve: Curves.ease,
						switchOutCurve: Curves.ease,
						child: _showProgress ? ValueListenableBuilder<double?>(
							valueListenable: _progress,
							builder: (context, progress, _) => LinearProgressIndicator(
								minHeight: 5,
								value: progress,
								valueColor: AlwaysStoppedAnimation(ChanceTheme.primaryColorOf(context)),
								backgroundColor: ChanceTheme.backgroundColorOf(context)
							)
						) : const SizedBox(
							height: 5,
							width: double.infinity
						)
					),
					Expanded(
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
							onConsoleMessage: (controller, message) => print(message),
							onWebViewCreated: (controller) {
								_controller = controller;
								controller.addJavaScriptHandler(handlerName: _kFormChannelName, callback: (messages) async {
									if (messages[0] case Map map) {
										widget.onFormSubmitted?.call({
											for (final entry in map.entries)
												entry.key.toString(): entry.value.toString()
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
							onLoadStart: (controller, url) {
								_progress.value = null;
								_showProgressTimer?.cancel();
								_showProgressTimer = null;
								_showProgress = true;
								setState(() {});
							},
							onProgressChanged: (controller, progress) {
								_progress.value = progress / 100;
								if (progress > 0) {
									_showProgressTimer?.cancel();
									_showProgressTimer = null;
									_showProgress = true;
									setState(() {});
								}
							},
							onLoadStop: (controller, webUrl) async {
								if (webUrl != null) {
									widget.onLoadStop?.call(webUrl);
								}
								if (!_loadedOnce) {
									if (widget.javascript case final javascript?) {
										await controller.evaluateJavascript(source: javascript);
									}
									_loadedOnce = true;
								}
								_progress.value = 1;
								_showProgressTimer = Timer(const Duration(milliseconds: 300), () => setState(() {
									_showProgress = false;
								}));
								await maybeApplyDarkModeBrowserJS(controller);
								if (widget.formFields.isNotEmpty) {
									// Restore field values and listen for saving upon submission
									final stringFields = Map.fromEntries(widget.formFields.entries.where((e) => e.value is String));
									final fileFields = <String, ({String base64, String filename, String mimeType})>{};
									for (final e in widget.formFields.entries) {
										if (e.value case MultipartFile file) {
											final stringBuffer = StringBuffer();
											await base64.encoder.bind(file.finalize()).forEach(stringBuffer.write);
											fileFields[e.key] = (
												base64: stringBuffer.toString(),
												filename: file.filename!,
												mimeType: lookupMimeType(file.filename ?? '') ?? file.contentType?.mimeType ?? 'application/octet-stream'
											);
										}
									}
									await controller.evaluateJavascript(source: '''
										(function anon() {
											var formFields = ${jsonEncode(stringFields)}
											for (var name of Object.keys(formFields)) {
												var value = formFields[name]
												for (var elem of [...document.querySelectorAll("[name='" + name + "']")]) {
													if (elem.type == "checkbox") {
														elem.checked = elem.value == value
													}
													else {
														elem.value = value
													}
												}
											}
											var formFiles = {${fileFields.entries.map((f) => '"${f.key}": new File([Uint8Array.fromBase64("${f.value.base64}")], "${f.value.filename}", {options: {type: "${f.value.mimeType}"}})').join(', ')}}
											for (var name of Object.keys(formFiles)) {
												var file = formFiles[name]
												for (var elem of [...document.querySelectorAll("[name='" + name + "']")]) {
													var container = new DataTransfer()
													if (file) {
														container.items.add(file)
													}
													elem.files = container.files
												}
											}
											function onSubmit(e) {
												console.error(e.target)
												var map = {}
												for (var elem of [...e.target.querySelectorAll('input[type="text"], input[type="submit"], input[type="hidden"], textarea')]) {
													var name = elem.name
													if (name) {
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
					)
				]
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
						onPressed: () {
							_showProgressTimer?.cancel();
							_showProgressTimer = null;
							_showProgress = true;
							setState(() {});
							_controller?.reload();
						},
						icon: const Icon(CupertinoIcons.refresh)
					)
				]
			),
			body: _buildBody()
		);
	}

	@override
	void dispose() {
		super.dispose();
		_progress.dispose();
		_showProgressTimer?.cancel();
	}
}

// For some unknown reason, need to use root navigator. or else tapping doesn't work well on iosOnMac (due to NativeDropView i guess)
Future<void> openCookieBrowser(BuildContext context, Uri url, {ValueChanged<List<Cookie>>? onCookiesSaved, required bool useFullWidthGestures}) => Navigator.of(context, rootNavigator: true).push(adaptivePageRoute(
	builder: (context) => CookieBrowser(
		initialUrl: url,
		onCookiesSaved: onCookiesSaved
	),
	useFullWidthGestures: useFullWidthGestures
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
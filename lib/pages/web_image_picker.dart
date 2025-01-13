import 'dart:convert';
import 'dart:io';

import 'package:chan/pages/overscroll_modal.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/pick_attachment.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/media_thumbnail.dart';
import 'package:chan/widgets/network_image.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mime/mime.dart';
import 'package:provider/provider.dart';
part 'web_image_picker.g.dart';

@HiveType(typeId: 35)
enum WebImageSearchMethod {
	@HiveField(0)
	google,
	@HiveField(1)
	yandex,
	@HiveField(2)
	duckDuckGo,
	@HiveField(3)
	bing;
	String get name {
		switch (this) {
			case google:
				return 'Google';
			case yandex:
				return 'Yandex';
			case duckDuckGo:
				return 'DuckDuckGo';
			case bing:
				return 'Bing';
		}
	}
	Uri searchUrl(String query) {
		switch (this) {
			case google:
				return Uri.https('www.google.com', '/search', {
					'tbm': 'isch',
					'q': query
				});
			case yandex:
				return Uri.https('yandex.com', '/images/search', {
					'text': query
				});
			case duckDuckGo:
				return Uri.https('duckduckgo.com', '/', {
					'q': query,
					't': 'h_',
					'iax': 'images',
					'ia': 'images'
				});
			case bing:
				return Uri.https('www.bing.com', '/images/search', {
					'q': query
				});
		}
	}
}

enum _NavigationState {
	/// No specific URL loaded yet
	initial,
	/// First URL loaded after search
	firstPage,
	/// Some further navigation after the search landing
	furtherPage
}

class WebImagePickerPage extends StatefulWidget {
	const WebImagePickerPage({
		super.key
	});

	@override
	createState() => _WebImagePickerPageState();
}

typedef _WebImageResult = ({
	String src,
	int width,
	int height,
	double displayWidth,
	double displayHeight,
	double top,
	double left,
	bool visible1,
	bool visible2,
	bool isVideo
});

class _WebImagePickerPageState extends State<WebImagePickerPage> {
	InAppWebViewController? webViewController;

	late final PullToRefreshController pullToRefreshController;
	_NavigationState _navigationState = _NavigationState.initial;
	bool startedInitialLoad = false;
	bool canGoBack = false;
	bool canGoForward = false;
	double progress = 0;
	late final TextEditingController urlController;
	late final FocusNode urlFocusNode;
	static const _kMobileUserAgent = 'Mozilla/5.0 (iPhone; CPU iPhone OS 15_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.2 Mobile/15E148 Safari/604.1';
	static const _kDesktopUserAgent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15';
	bool useDesktopUserAgent = false;
	bool showSearchHistory = true;

	@override
	void initState() {
		super.initState();
		urlController = TextEditingController();
		urlFocusNode = FocusNode();
		urlFocusNode.addListener(_onUrlFocusChange);
		pullToRefreshController = PullToRefreshController(
			settings: PullToRefreshSettings(
				color: Colors.blue,
			),
			onRefresh: () async {
				if (Platform.isAndroid) {
					webViewController?.reload();
				} else if (Platform.isIOS) {
					webViewController?.loadUrl(
						urlRequest: URLRequest(url: await webViewController?.getUrl())
					);
				}
			}
		);
	}

	void _onUrlFocusChange() {
		if (urlFocusNode.hasPrimaryFocus) {
			setState(() {
				showSearchHistory = true;
			});
		}
	}

	void _onNewUrl(WebUri? url) {
		if (url == null) {
			return;
		}
		if (_navigationState == _NavigationState.furtherPage) {
			final urlStr = url.toString();
			if (urlStr != 'about:blank') {
				urlController.text = urlStr;
			}
		}
	}

	void _search(String value) async {
		Uri url = Uri.parse(value);
		if (supportedFileExtensions.any(url.path.endsWith)) {
			// Download it directly?
			if (url.scheme.isEmpty) {
				url = Uri.parse('https://$value');
			}
			if (url.path.isNotEmpty || value.startsWith('https://')) {
				// No downloading junk like "something.png"
				final file = await downloadToShareCache(context: context, url: url);
				if (!mounted) {
					return;
				}
				if (file != null) {
					Navigator.pop(context, file);
					return;
				}
			}
			// User cancelled, just go forward to the URL
		}
		urlController.text = value;
		final settings = Settings.instance;
		_navigationState = _NavigationState.initial;
		setState(() {
			showSearchHistory = false;
		});
		if (url.scheme.isEmpty) {
			url = settings.webImageSearchMethod.searchUrl(value);
			// Don't pop-in behind loading search
			Future.delayed(const Duration(seconds: 2), () => Persistence.handleWebImageSearch(value));
		}
		webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri.uri(url)));
	}

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<Settings>();
		final backgroundColor = ChanceTheme.backgroundColorOf(context);
		return AdaptiveScaffold(
			bar: AdaptiveBar(
				title: AdaptiveSearchTextField(
					autofocus: true,
					focusNode: urlFocusNode,
					controller: urlController,
					enableIMEPersonalizedLearning: settings.enableIMEPersonalizedLearning,
					smartDashesType: SmartDashesType.disabled,
					smartQuotesType: SmartQuotesType.disabled,
					onSubmitted: _search,
					onChanged: (_) {
						setState(() {});
					},
					onSuffixTap: () {
						urlController.clear();
						urlFocusNode.requestFocus();
						setState(() {});
					},
				),
				actions: [
					Padding(
						padding: const EdgeInsets.only(left: 8),
						child: CupertinoButton(
							minSize: 0,
							padding: EdgeInsets.zero,
							onPressed: () => showAdaptiveModalPopup<WebImageSearchMethod>(
								context: context,
								builder: (context) => StatefulBuilder(
									builder: (context, setDialogState) => AdaptiveActionSheet(
										title: const Text('Web Image Picker Settings'),
										message: Column(
											children: [
												const Text('Search method'),
												const SizedBox(height: 10),
												AdaptiveChoiceControl(
													knownWidth: 100,
													children: {
														for (final entry in WebImageSearchMethod.values)
															entry: (null, entry.name)
													},
													groupValue: settings.webImageSearchMethod,
													onValueChanged: (choice) {
														Settings.webImageSearchMethodSetting.value = choice;
														setDialogState(() {});
													}
												),
												const SizedBox(height: 10),
												const Text('User Agent'),
												const SizedBox(height: 10),
												AdaptiveChoiceControl(
													knownWidth: 100,
													children: const {
														false: (CupertinoIcons.device_phone_portrait, 'Mobile'),
														true: (CupertinoIcons.desktopcomputer, 'Desktop')
													},
													groupValue: useDesktopUserAgent,
													onValueChanged: (newUseDesktopUserAgent) async {
														useDesktopUserAgent = newUseDesktopUserAgent;
														setDialogState(() {});
														final settings = await webViewController?.getSettings();
														if (settings == null) {
															if (context.mounted) {
																alertError(context, 'Failed to change WebView settings', null);
															}
															return;
														}
														settings.userAgent = useDesktopUserAgent ? _kDesktopUserAgent : _kMobileUserAgent;
														await webViewController?.setSettings(settings: settings);
													}
												)
											]
										),
										cancelButton: AdaptiveActionSheetAction(
											child: const Text('Close'),
											onPressed: () => Navigator.of(context, rootNavigator: true).pop()
										)
									)
								)
							),
							child: const Icon(CupertinoIcons.gear)
						)
					)
				]
			),
			body: SafeArea(
				child: Column(
					children: <Widget>[
						Expanded(
							child: Stack(
								children: [
									InAppWebView(
										initialSettings: InAppWebViewSettings(
											mediaPlaybackRequiresUserGesture: false,
											transparentBackground: true,
											userAgent: useDesktopUserAgent ? _kDesktopUserAgent : _kMobileUserAgent,
											useHybridComposition: true,
											allowsInlineMediaPlayback: true,
										),
										pullToRefreshController: pullToRefreshController,
										onWebViewCreated: (controller) {
											webViewController = controller;
										},
										onLoadStart: (controller, url) {
											startedInitialLoad = true;
											_navigationState = switch(_navigationState) {
												_NavigationState.initial => _NavigationState.firstPage,
												_NavigationState.firstPage || _NavigationState.furtherPage => _NavigationState.furtherPage
											};
											_onNewUrl(url);
										},
										onPermissionRequest: (controller, request) async {
											return PermissionResponse(
												resources: request.resources,
												action: PermissionResponseAction.GRANT
											);
										},
										onLoadStop: (controller, url) async {
											pullToRefreshController.endRefreshing();
											_onNewUrl(url);
										},
										onReceivedError: (controller, url, code) {
											pullToRefreshController.endRefreshing();
										},
										onProgressChanged: (controller, progress) async {
											if (progress == 100) {
												pullToRefreshController.endRefreshing();
											}
											setState(() {
												this.progress = progress / 100;
											});
										},
										onTitleChanged: (controller, title) async {
											canGoBack = await controller.canGoBack();
											canGoForward = await controller.canGoForward();
										},
										onUpdateVisitedHistory: (controller, url, androidIsReload) async {
											canGoBack = await controller.canGoBack();
											canGoForward = await controller.canGoForward();
											_onNewUrl(url);
										}
									),
									if (showSearchHistory) Container(
										color: backgroundColor,
										child: ListView(
											children: Persistence.recentWebImageSearches.where((s) {
													return s.toLowerCase().contains(urlController.text.toLowerCase());
											}).map((query) {
												return CupertinoButton(
													padding: EdgeInsets.zero,
													onPressed: () => _search(query),
													child: Container(
														decoration: BoxDecoration(
															border: Border(bottom: BorderSide(color: ChanceTheme.primaryColorWithBrightness20Of(context)))
														),
														padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
														child: Row(
															children: [
																Expanded(
																	child: Text(query)
																),
																CupertinoButton(
																	padding: EdgeInsets.zero,
																	child: const Icon(CupertinoIcons.xmark),
																	onPressed: () {
																		Persistence.removeRecentWebImageSearch(query);
																		setState(() {});
																	}
																)
															]
														)
													)
												);
											}).toList()
										)
									)
									else if (progress < 1.0) LinearProgressIndicator(value: progress),
									if (showSearchHistory && startedInitialLoad) Align(
										alignment: Alignment.bottomCenter,
										child: Padding(
											padding: const EdgeInsets.only(bottom: 16),
											child: AdaptiveFilledButton(
												padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
												child: const Row(
													mainAxisSize: MainAxisSize.min,
													children: [
														Icon(CupertinoIcons.xmark),
														SizedBox(width: 8),
														Text('Back to browser')
													]
												),
												onPressed: () {
													urlFocusNode.unfocus();
													setState(() {
														showSearchHistory = false;
													});
												}
											)
										)
									)
								],
							),
						),
						OverflowBar(
							alignment: MainAxisAlignment.center,
							children: <Widget>[
								ElevatedButton(
									onPressed: canGoBack ? () {
										webViewController?.goBack();
									} : null,
									child: const Icon(CupertinoIcons.arrow_left)
								),
								ElevatedButton(
									onPressed: canGoForward ? () {
										webViewController?.goForward();
									} : null,
									child: const Icon(CupertinoIcons.arrow_right)
								),
								ElevatedButton(
									child: Icon(Adaptive.icons.photo),
									onPressed: () async {
										final headers = {
											'user-agent': useDesktopUserAgent ? _kDesktopUserAgent : _kMobileUserAgent
										};
										if (await webViewController?.getUrl() case WebUri url) {
											final cookies = await CookieManager.instance().getCookies(url: url);
											headers['cookie'] = cookies.map((c) => '${c.name}=${c.value}').join('; ');
										}
										final returnedResults = await webViewController?.evaluateJavascript(
											source: '''[...document.querySelectorAll('img, video'), ...[...document.querySelectorAll('iframe')].flatMap(iframe => {
												try {
													return [...iframe.contentWindow.document.body.querySelectorAll('img, video')]
												}
												catch (ex) {
													// Security error
													return []
												}
											})].map(img => {
												var rect = img.getBoundingClientRect()
												var src = img.src
												if (!src && img.localName == 'video') {
													var sources = [...img.querySelectorAll('source')]
													var candidate = [
														sources.find((e) => e.type == 'video/mp4'),
														sources.find((e) => e.type == 'video/webm'),
														sources[0]
													].find((e) => !!e)
													if (candidate) {
														src = candidate.src
													}
												}
												return {
													src: src,
													width: img.naturalWidth || img.videoWidth || img.width,
													height: img.naturalHeight || img.videoHeight || img.height,
													displayWidth: rect.width,
													displayHeight: rect.height,
													top: rect.top,
													left: rect.left,
													visible1: rect.bottom >= 0 && rect.right >= 0 && rect.top <= (window.innerHeight || document.documentElement.clientHeight) && rect.left <= (window.innerWidth || document.documentElement.clientWidth),
													visible2: img.paused === false || (
														document.elementFromPoint((rect.left + rect.right) / 2, (rect.top + rect.bottom) / 2) ||
														document.elementFromPoint((rect.left + rect.right) / 2, (0.8 * rect.top) + (0.2 * rect.bottom))
													) == img,
													isVideo: img.localName == 'video'
												}
											})'''
										) as List;
										// Have to copy it as the List is unmodifiable
										final results = returnedResults.map<_WebImageResult>((r) => (
											src: r['src'] as String,
											width: (r['width'] as num).toInt(),
											height: (r['height'] as num).toInt(),
											displayWidth: (r['displayWidth'] as num).toDouble(),
											displayHeight: (r['displayHeight'] as num).toDouble(),
											top: (r['top'] as num).toDouble(),
											left: (r['left'] as num).toDouble(),
											visible1: r['visible1'] as bool,
											visible2: r['visible2'] as bool,
											isVideo: r['isVideo'] as bool
										)).toList();
										results.removeWhere((r) => r.width * r.height <= 1);
										results.removeWhere((r) => r.displayWidth * r.displayHeight == 0);
										results.removeWhere((r) => r.src.endsWith('.svg'));
										results.removeWhere((r) => r.src.isEmpty);
										results.sort((a, b) => a.left.compareTo(b.left));
										if (results.isEmpty) {
											if (context.mounted) {
												showToast(
													context: context,
													icon: CupertinoIcons.exclamationmark_triangle,
													message: 'No images found'
												);
											}
											return;
										}
										mergeSort<_WebImageResult>(results, compare: (a, b) => a.top.compareTo(b.top));
										makeGrid(BuildContext context, List<_WebImageResult> images) => GridView.builder(
											gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
												maxCrossAxisExtent: 150,
												mainAxisSpacing: 16,
												crossAxisSpacing: 16
											),
											shrinkWrap: true,
											physics: const NeverScrollableScrollPhysics(),
											itemCount: images.length,
											itemBuilder: (context, i) {
												final image = images[i];
												Widget imageWidget = CNetworkImage(
													url: image.src,
													headers: headers,
													client: null,
													cache: true,
													fit: BoxFit.contain
												);
												Uint8List? data;
												if (image.src.startsWith('data:')) {
													data = base64Decode(image.src.split(',')[1]);
													imageWidget = ExtendedImage.memory(
														data,
														fit: BoxFit.contain
													);
												}
												return GestureDetector(
													onTap: () async {
														try {
															if (data != null) {
																Navigator.of(context).pop(data);
																return;
															}
															final file = await getCachedImageFile(image.src);
															if (!context.mounted) return;
															if (file != null) {
																// Avoid second download
																final bytes = await file.readAsBytes();
																if (context.mounted) {
																	Navigator.pop(context, bytes);
																}
																return;
															}
															final response = await modalLoad(context, 'Downloading...', (controller) async {
																final token = CancelToken();
																controller.onCancel = token.cancel;
																final response = await settings.client.get(image.src, options: Options(
																	responseType: ResponseType.bytes,
																	headers: headers
																), cancelToken: token);
																if (response.data is Uint8List) {
																	return response;
																}
																// Something this happens with cloudflare clearance,
																// we get <img> as String, just try again
																return await settings.client.get(image.src, options: Options(
																	responseType: ResponseType.bytes,
																	headers: headers
																), cancelToken: token);
															}, cancellable: true);
															if (!context.mounted) return;
															Navigator.of(context).pop(response.data);
														}
														catch (e, st) {
															Future.error(e, st); // crashlytics
															if (mounted) {
																alertError(context, e, st);
															}
														}
													},
													child: Column(
														crossAxisAlignment: CrossAxisAlignment.stretch,
														children: [
															Expanded(
																child: image.isVideo ? MediaThumbnail(
																	uri: Uri.parse(image.src),
																	headers: headers
																) : imageWidget
															),
															const SizedBox(height: 4),
															Text('${image.width}x${image.height}', style: const TextStyle(
																fontSize: 16
															))
														]
													)
												);
											},
										);
										final noVisible2 = results.every((r) => !r.visible2);
										final fullImages = results.where((r) => r.visible1 && (noVisible2 || r.visible2) && r.width * r.height >= 10201).toList();
										final thumbnails = results.where((r) => r.visible1 && (noVisible2 || r.visible2) && r.width * r.height < 10201).toList();
										final offscreen = results.where((r) => !(r.visible1 && (noVisible2 || r.visible2))).toList();
										if (!context.mounted) return;
										final pickedBytes = await Navigator.of(context).push<Uint8List>(TransparentRoute(
											builder: (context) => OverscrollModalPage(
												child: Container(
													width: double.infinity,
													color: backgroundColor,
													padding: const EdgeInsets.all(16),
													child: Column(
														children: [
															const Text('Images'),
															const SizedBox(height: 16),
															makeGrid(context, fullImages),
															if (offscreen.isNotEmpty) ...[
																const SizedBox(height: 16),
																AdaptiveFilledButton(
																	child: Text('${offscreen.length} Offscreen'),
																	onPressed: () async {
																		final selectedImage = await Navigator.of(context).push(TransparentRoute(
																			builder: (innerContext) => OverscrollModalPage(
																				child: Container(
																					width: double.infinity,
																					color: backgroundColor,
																					padding: const EdgeInsets.all(16),
																					child: Column(
																						children: [
																							const Text('Offscreen'),
																							const SizedBox(height: 16),
																							makeGrid(innerContext, offscreen)
																						]
																					)
																				)
																			)
																		));
																		if (selectedImage != null && context.mounted) {
																			Navigator.of(context).pop(selectedImage);
																		}
																	}
																)
															],
															if (thumbnails.isNotEmpty) ...[
																const SizedBox(height: 16),
																AdaptiveFilledButton(
																	child: Text('${thumbnails.length} Thumbnails'),
																	onPressed: () async {
																		final selectedThumbnail = await Navigator.of(context).push(TransparentRoute(
																			builder: (innerContext) => OverscrollModalPage(
																				child: Container(
																					width: double.infinity,
																					color: backgroundColor,
																					padding: const EdgeInsets.all(16),
																					child: Column(
																						children: [
																							const Text('Thumbnails'),
																							const SizedBox(height: 16),
																							makeGrid(innerContext, thumbnails)
																						]
																					)
																				)
																			)
																		));
																		if (selectedThumbnail != null && context.mounted) {
																			Navigator.of(context).pop(selectedThumbnail);
																		}
																	}
																)
															]
														]
													)
												)
											)
										));
										if (pickedBytes != null) {
											String? ext = lookupMimeType('', headerBytes: pickedBytes)?.split('/').last;
											if (ext == 'jpeg') {
												ext = 'jpg';
											}
											if (ext != null) {
												final f = File('${Persistence.temporaryDirectory.path}/webpickercache/${DateTime.now().millisecondsSinceEpoch}.$ext');
												await f.create(recursive: true);
												await f.writeAsBytes(pickedBytes, flush: true);
												if (context.mounted) {
													Navigator.of(context).pop(f);
												}
											}
										}
									}
								),
								ElevatedButton(
									child: const Icon(CupertinoIcons.refresh),
									onPressed: () {
										webViewController?.reload();
									}
								)
							]
						)
					]
				)
			)
		);
	}

	@override
	void dispose() {
		super.dispose();
		urlController.dispose();
		urlFocusNode.dispose();
	}
}
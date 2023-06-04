import 'dart:convert';
import 'dart:io';

import 'package:chan/pages/overscroll_modal.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/cupertino_dialog.dart';
import 'package:chan/widgets/cupertino_text_field2.dart';
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
	duckDuckGo;
	String get name {
		switch (this) {
			case google:
				return 'Google';
			case yandex:
				return 'Yandex';
			case duckDuckGo:
				return 'DuckDuckGo';
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
		}
	}
}

extension ToCssRgba on Color {
	String toCssRgba() => 'rgba($red, $green, $blue, $opacity)';
}

class WebImagePickerPage extends StatefulWidget {
	final ImageboardSite? site;

	const WebImagePickerPage({
		required this.site,
		Key? key
	}) : super(key: key);

	@override
	createState() => _WebImagePickerPageState();
}

class _WebImagePickerPageState extends State<WebImagePickerPage> {
	InAppWebViewController? webViewController;

	late final PullToRefreshController pullToRefreshController;
	String url = "";
	bool startedInitialLoad = false;
	bool canGoBack = false;
	bool canGoForward = false;
	double progress = 0;
	late final TextEditingController urlController;
	late final FocusNode urlFocusNode;

	@override
	void initState() {
		super.initState();
		urlController = TextEditingController();
		urlFocusNode = FocusNode();
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
		urlFocusNode.requestFocus();
	}

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<EffectiveSettings>();
		return CupertinoPageScaffold(
			navigationBar: CupertinoNavigationBar(
				transitionBetweenRoutes: false,
				middle: CupertinoSearchTextField2(
					focusNode: urlFocusNode,
					controller: urlController,
					enableIMEPersonalizedLearning: context.select<EffectiveSettings, bool>((s) => s.enableIMEPersonalizedLearning),
					smartDashesType: SmartDashesType.disabled,
					smartQuotesType: SmartQuotesType.disabled,
					onSubmitted: (value) {
						Uri url = Uri.parse(value);
						if (url.scheme.isEmpty) {
							url = settings.webImageSearchMethod.searchUrl(value);
						}
						webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri.uri(url)));
					},
					onSuffixTap: () {
						urlController.clear();
						urlFocusNode.requestFocus();
					},
				),
				trailing: Padding(
					padding: const EdgeInsets.only(left: 8),
					child: CupertinoButton(
						minSize: 0,
						padding: EdgeInsets.zero,
						onPressed: () async {
							final choice = await showCupertinoModalPopup<WebImageSearchMethod>(
								context: context,
								builder: (context) => CupertinoActionSheet(
									title: const Text('Search'),
									actions: WebImageSearchMethod.values.map((entry) => CupertinoActionSheetAction2(
										child: Text(entry.name, style: TextStyle(
											fontWeight: entry == settings.webImageSearchMethod ? FontWeight.bold : null
										)),
										onPressed: () {
											Navigator.of(context, rootNavigator: true).pop(entry);
										}
									)).toList(),
									cancelButton: CupertinoActionSheetAction2(
										child: const Text('Cancel'),
										onPressed: () => Navigator.of(context, rootNavigator: true).pop()
									)
								)
							);
							if (choice != null) {
								settings.webImageSearchMethod = choice;
							}
						},
						child: const Icon(CupertinoIcons.gear)
					)
				)
			),
			child: SafeArea(
				child: Column(
					children: <Widget>[
						Expanded(
							child: Stack(
								children: [
									InAppWebView(
										initialSettings: InAppWebViewSettings(
											mediaPlaybackRequiresUserGesture: false,
											transparentBackground: true,
											userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 15_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.2 Mobile/15E148 Safari/604.1',
											useHybridComposition: true,
											allowsInlineMediaPlayback: true,
										),
										pullToRefreshController: pullToRefreshController,
										onWebViewCreated: (controller) {
											webViewController = controller;
										},
										onLoadStart: (controller, url) {
											setState(() {
												startedInitialLoad = true;
												this.url = url.toString();
												if (url.toString() != 'about:blank') urlController.text = this.url;
											});
										},
										onPermissionRequest: (controller, request) async {
											return PermissionResponse(
												resources: request.resources,
												action: PermissionResponseAction.GRANT
											);
										},
										onLoadStop: (controller, url) async {
											pullToRefreshController.endRefreshing();
											setState(() {
												this.url = url.toString();
												if (url.toString() != 'about:blank') urlController.text = this.url;
											});
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
												if (url.toString() != 'about:blank') urlController.text = url;
											});
										},
										onTitleChanged: (controller, title) async {
											canGoBack = await controller.canGoBack();
											canGoForward = await controller.canGoForward();
										},
										onUpdateVisitedHistory: (controller, url, androidIsReload) async {
											canGoBack = await controller.canGoBack();
											canGoForward = await controller.canGoForward();
											setState(() {
												this.url = url.toString();
												if (url.toString() != 'about:blank') urlController.text = this.url;
											});
										}
									),
									if (startedInitialLoad && progress < 1.0) LinearProgressIndicator(value: progress)
								],
							),
						),
						ButtonBar(
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
									child: const Icon(CupertinoIcons.photo),
									onPressed: () async {
										final List<dynamic> returnedResults = await webViewController?.evaluateJavascript(
											source: '''[...document.querySelectorAll('img')].map(img => {
												var rect = img.getBoundingClientRect()
												return {
													src: img.src,
													width: img.naturalWidth,
													height: img.naturalHeight,
													displayWidth: rect.width,
													displayHeight: rect.height,
													top: rect.top,
													left: rect.left,
													alt: img.alt,
													visible1: rect.bottom >= 0 && rect.right >= 0 && rect.top <= (window.innerHeight || document.documentElement.clientHeight) && rect.left <= (window.innerWidth || document.documentElement.clientWidth),
													visible2: document.elementFromPoint((rect.left + rect.right) / 2, (rect.top + rect.bottom) / 2) == img
												}
											})'''
										);
										final results = [...returnedResults];
										results.removeWhere((r) => r['displayWidth'] * r['displayHeight'] == 0);
										results.removeWhere((r) => r['src'].endsWith('.svg'));
										results.removeWhere((r) => r['src'].isEmpty);
										results.sort((a, b) => a['left'].compareTo(b['left']));
										mergeSort<dynamic>(results, compare: (a, b) => a['top'].compareTo(b['top']));
										makeGrid(BuildContext context, List<dynamic> images) => GridView.builder(
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
												Widget imageWidget = ExtendedImage.network(
													image['src'],
													fit: BoxFit.contain
												);
												Uint8List? data;
												if (image['src'].startsWith('data:')) {
													data = base64Decode(image['src'].split(',')[1]);
													imageWidget = ExtendedImage.memory(
														data,
														fit: BoxFit.contain
													);
												}
												return GestureDetector(
													onTap: () async {
														if (data != null) {
															Navigator.of(context).pop(data);
														}
														else {
															final response = await (widget.site?.client ?? Dio()).get(image['src'], options: Options(
																responseType: ResponseType.bytes
															));
															if (!mounted) return;
															Navigator.of(context).pop(response.data);
														}
													},
													child: Column(
														children: [
															Expanded(
																child: imageWidget
															),
															const SizedBox(height: 4),
															Text('${image['width'].round()}x${image['height'].round()}', style: const TextStyle(
																fontSize: 16
															))
														]
													)
												);
											},
										);
										final noVisible2 = results.every((r) => !r['visible2']);
										final fullImages = results.where((r) => r['visible1'] && (noVisible2 || r['visible2']) && r['width'] * r['height'] >= 10201).toList();
										final thumbnails = results.where((r) => r['visible1'] && (noVisible2 || r['visible2']) && r['width'] * r['height'] < 10201).toList();
										final offscreen = results.where((r) => !(r['visible1'] && (noVisible2 || r['visible2']))).toList();
										if (!mounted) return;
										final pickedBytes = await Navigator.of(context).push<Uint8List>(TransparentRoute(
											builder: (context) => OverscrollModalPage(
												child: Container(
													width: double.infinity,
													color: ChanceTheme.backgroundColorOf(context),
													padding: const EdgeInsets.all(16),
													child: Column(
														children: [
															const Text('Images'),
															const SizedBox(height: 16),
															makeGrid(context, fullImages),
															if (offscreen.isNotEmpty) ...[
																const SizedBox(height: 16),
																CupertinoButton.filled(
																	child: Text('${offscreen.length} Offscreen'),
																	onPressed: () async {
																		final selectedImage = await Navigator.of(context).push(TransparentRoute(
																			builder: (innerContext) => OverscrollModalPage(
																				child: Container(
																					width: double.infinity,
																					color: ChanceTheme.backgroundColorOf(context),
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
																		if (selectedImage != null && mounted) {
																			Navigator.of(context).pop(selectedImage);
																		}
																	}
																)
															],
															if (thumbnails.isNotEmpty) ...[
																const SizedBox(height: 16),
																CupertinoButton.filled(
																	child: Text('${thumbnails.length} Thumbnails'),
																	onPressed: () async {
																		final selectedThumbnail = await Navigator.of(context).push(TransparentRoute(
																			builder: (innerContext) => OverscrollModalPage(
																				child: Container(
																					width: double.infinity,
																					color: ChanceTheme.backgroundColorOf(context),
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
																		if (selectedThumbnail != null && mounted) {
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
												if (mounted) {
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
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chan/pages/overscroll_modal.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mime/mime.dart';
import 'package:provider/provider.dart';

extension ToCssRgba on Color {
	String toCssRgba() => 'rgba($red, $green, $blue, $opacity)';
}

class WebImagePickerPage extends StatefulWidget {
	const WebImagePickerPage({
		Key? key
	}) : super(key: key);

	@override
	createState() => _WebImagePickerPageState();
}

class _WebImagePickerPageState extends State<WebImagePickerPage> {
	InAppWebViewController? webViewController;

	late final PullToRefreshController pullToRefreshController;
	String url = "";
	bool finishedInitialLoad = false;
	double progress = 0;
	final urlController = TextEditingController();
	final urlFocusNode = FocusNode();

	@override
	void initState() {
		super.initState();
		pullToRefreshController = PullToRefreshController(
			options: PullToRefreshOptions(
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
		return CupertinoPageScaffold(
			navigationBar: CupertinoNavigationBar(
				middle: CupertinoSearchTextField(
					focusNode: urlFocusNode,
					controller: urlController,
					onSubmitted: (value) {
						var url = Uri.parse(value);
						if (url.scheme.isEmpty) {
							url = Uri.parse("https://www.google.com/search?tbm=isch&q=$value");
						}
						webViewController?.loadUrl(urlRequest: URLRequest(url: url));
					},
				)
			),
			child: SafeArea(
				child: Column(
					children: <Widget>[
						Expanded(
							child: Stack(
								children: [
									InAppWebView(
										initialOptions: InAppWebViewGroupOptions(
											crossPlatform: InAppWebViewOptions(
												mediaPlaybackRequiresUserGesture: false,
												transparentBackground: true,
												userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 15_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.2 Mobile/15E148 Safari/604.1'
											),
											android: AndroidInAppWebViewOptions(
												useHybridComposition: true,
											),
											ios: IOSInAppWebViewOptions(
												allowsInlineMediaPlayback: true,
											)
										),
										pullToRefreshController: pullToRefreshController,
										onWebViewCreated: (controller) {
											webViewController = controller;
										},
										onLoadStart: (controller, url) {
											setState(() {
												this.url = url.toString();
												if (url.toString() != 'about:blank') urlController.text = this.url;
											});
										},
										androidOnPermissionRequest: (controller, origin, resources) async {
											return PermissionRequestResponse(
												resources: resources,
												action: PermissionRequestResponseAction.GRANT
											);
										},
										onLoadStop: (controller, url) async {
											pullToRefreshController.endRefreshing();
											setState(() {
												finishedInitialLoad = true;
												this.url = url.toString();
												if (url.toString() != 'about:blank') urlController.text = this.url;
											});
										},
										onLoadError: (controller, url, code, message) {
											pullToRefreshController.endRefreshing();
										},
										onProgressChanged: (controller, progress) {
											if (progress == 100) {
												pullToRefreshController.endRefreshing();
											}
											setState(() {
												this.progress = progress / 100;
												if (url.toString() != 'about:blank') urlController.text = url;
											});
										},
										onUpdateVisitedHistory: (controller, url, androidIsReload) {
											setState(() {
												this.url = url.toString();
												if (url.toString() != 'about:blank') urlController.text = this.url;
											});
										}
									),
									if (finishedInitialLoad && progress < 1.0) LinearProgressIndicator(value: progress)
									else Container()
								],
							),
						),
						ButtonBar(
							alignment: MainAxisAlignment.center,
							children: <Widget>[
								ElevatedButton(
									child: const Icon(CupertinoIcons.arrow_left),
									onPressed: () {
										webViewController?.goBack();
									}
								),
								ElevatedButton(
									child: const Icon(CupertinoIcons.arrow_right),
									onPressed: () {
										webViewController?.goForward();
									}
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
													alt: img.alt
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
															final response = await context.read<ImageboardSite>().client.get(image['src'], options: Options(
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
										final fullImages = results.where((r) => r['width'] * r['height'] >= 10201).toList();
										final thumbnails = results.where((r) => r['width'] * r['height'] < 10201).toList();
										if (!mounted) return;
										final pickedBytes = await Navigator.of(context).push<Uint8List>(TransparentRoute(
											builder: (context) => OverscrollModalPage(
												child: Container(
													width: double.infinity,
													color: CupertinoTheme.of(context).scaffoldBackgroundColor,
													padding: const EdgeInsets.all(16),
													child: Column(
														children: [
															const Text('Images'),
															const SizedBox(height: 16),
															makeGrid(context, fullImages),
															if (thumbnails.isNotEmpty) ...[
																const SizedBox(height: 16),
																CupertinoButton.filled(
																	child: const Text('Thumbnails'),
																	onPressed: () async {
																		final selectedThumbnail = await Navigator.of(context).push(TransparentRoute(
																			builder: (innerContext) => OverscrollModalPage(
																				child: Container(
																					width: double.infinity,
																					color: CupertinoTheme.of(context).scaffoldBackgroundColor,
																					padding: const EdgeInsets.all(16),
																					child: Column(
																						children: [
																							const Text('Thumbnails'),
																							const SizedBox(height: 16),
																							makeGrid(innerContext, thumbnails)
																						]
																					)
																				)
																			),
																			showAnimations: context.read<EffectiveSettings>().showAnimations
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
											),
											showAnimations: context.read<EffectiveSettings>().showAnimations
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
}
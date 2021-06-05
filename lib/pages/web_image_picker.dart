import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:chan/pages/overscroll_modal.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/widgets/util.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

extension ToCssRgba on Color {
	String toCssRgba() => 'rgba($red, $green, $blue, $opacity)';
}

class WebImagePickerPage extends StatefulWidget {
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
							url = Uri.parse("https://www.google.com/search?tbm=isch&q=" + value);
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
												transparentBackground: true
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
												if (url.toString() != 'about:blank') urlController.text = this.url;
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
									child: Icon(Icons.arrow_back),
									onPressed: () {
										webViewController?.goBack();
									}
								),
								ElevatedButton(
									child: Icon(Icons.arrow_forward),
									onPressed: () {
										webViewController?.goForward();
									}
								),
								ElevatedButton(
									child: Icon(Icons.image),
									onPressed: () async {
										final List<dynamic> returnedResults = await webViewController?.evaluateJavascript(
											source: '''[...document.querySelectorAll('img')].map(img => {
												var rect = img.getBoundingClientRect()
												return {
													src: img.src,
													width: img.naturalWidth,
													height: img.naturalHeight,
													top: rect.top,
													left: rect.left,
													alt: img.alt
												}
											})'''
										);
										final results = [...returnedResults];
										results.removeWhere((r) => r['src'].endsWith('.svg'));
										results.removeWhere((r) => r['src'].isEmpty);
										results.sort((a, b) => a['left'].compareTo(b['left']));
										mergeSort<dynamic>(results, compare: (a, b) => a['top'].compareTo(b['top']));
										final _makeGrid = (BuildContext context, List<dynamic> images) => GridView.builder(
											gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
												maxCrossAxisExtent: 100,
												mainAxisSpacing: 16,
												crossAxisSpacing: 16
											),
											shrinkWrap: true,
											physics: NeverScrollableScrollPhysics(),
											itemCount: images.length,
											itemBuilder: (context, i) {
												final image = images[i];
												ExtendedImageState? eState;
												final handleLoadState = (ExtendedImageState state) {
													eState = state;
												};
												Widget imageWidget = ExtendedImage.network(
													image['src'],
													fit: BoxFit.contain,
													loadStateChanged: handleLoadState
												);
												if (image['src'].startsWith('data:')) {
													imageWidget = ExtendedImage.memory(
														base64Decode(image['src'].split(',')[1]),
														fit: BoxFit.contain,
														loadStateChanged: handleLoadState
													);
												}
												return GestureDetector(
													onTap: () async {
														final png = await eState?.extendedImageInfo?.image.toByteData(format: ImageByteFormat.png);
														Navigator.of(context).pop(png);
													},
													child: Column(
														children: [
															Expanded(
																child: imageWidget
															),
															SizedBox(height: 4),
															Text(image['width'].round().toString() + 'x' + image['height'].round().toString(), style: TextStyle(
																fontSize: 16
															))
														]
													)
												);
											},
										);
										final fullImages = results.where((r) => r['width'] * r['height'] >= 10201).toList();
										final thumbnails = results.where((r) => r['width'] * r['height'] < 10201).toList();
										final pickedBytes = await Navigator.of(context).push<ByteData>(TransparentRoute(
											builder: (context) => OverscrollModalPage(
												child: Container(
													width: double.infinity,
													color: CupertinoTheme.of(context).scaffoldBackgroundColor,
													padding: EdgeInsets.all(16),
													child: Column(
														children: [
															Text('Images'),
															SizedBox(height: 16),
															_makeGrid(context, fullImages),
															if (thumbnails.isNotEmpty) ...[
																SizedBox(height: 16),
																CupertinoButton(
																	child: Text('Thumbnails'),
																	onPressed: () async {
																		final selectedThumbnail = await Navigator.of(context).push(TransparentRoute(
																			builder: (innerContext) => OverscrollModalPage(
																				child: Container(
																					width: double.infinity,
																					color: CupertinoTheme.of(context).scaffoldBackgroundColor,
																					padding: EdgeInsets.all(16),
																					child: Column(
																						children: [
																							Text('Thumbnails'),
																							SizedBox(height: 16),
																							_makeGrid(innerContext, thumbnails)
																						]
																					)
																				)
																			)
																		));
																		if (selectedThumbnail != null) {
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
											final f = File(Persistence.temporaryDirectory.path + '/webpickercache/' + DateTime.now().millisecondsSinceEpoch.toString() + '.png');
											await f.create(recursive: true);
											await f.writeAsBytes(pickedBytes.buffer.asUint8List());
											Navigator.of(context).pop(f);
										}
									}
								),
								ElevatedButton(
									child: Icon(Icons.refresh),
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
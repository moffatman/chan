import 'dart:async';
import 'dart:convert' hide Codec;
import 'dart:ui';

import 'package:chan/util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class HTMLRendering {
	late final ExpiringMutexResource<HeadlessInAppWebView> _webView;

	HTMLRendering() {
		_webView = ExpiringMutexResource<HeadlessInAppWebView>(_init, _deinit, interval: const Duration(seconds: 5));
	}

	static Future<HeadlessInAppWebView> _init() async {
		final loadCompleter = Completer<void>();
		final webView = HeadlessInAppWebView(
			initialSettings: InAppWebViewSettings(
				transparentBackground: true
			),
			initialData: InAppWebViewInitialData(data: '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head><body style="width: 400px"/></html>'),
			onLoadStop: (controller, url) {
				loadCompleter.complete();
			},
			onConsoleMessage: (controller, message) {
				print(message);
			}
		);
		await webView.run();
		await Future.any([loadCompleter.future, Future.delayed(const Duration(seconds: 5))]);
		await Future.delayed(const Duration(milliseconds: 100));
		return webView;
	}

	static Future<void> _deinit(HeadlessInAppWebView webView) async {
		await webView.dispose();
	}

	Future<Uint8List> renderHtml(String html, {double textScaleFactor = 1.0}) async {
		final imageCompleter = Completer<Uint8List>();
		_webView.runWithResource((webView) async {
			final returnData = await webView.webViewController?.callAsyncJavaScript(functionBody: '''
				var html = atob("${base64.encode(utf8.encode(html))}");
				var span = document.createElement("span");
				span.innerHTML = html;
				document.body.replaceChildren(span);
				return new Promise(function (resolve, reject) {
					requestAnimationFrame(function() {
						var rect = span.getBoundingClientRect();
						resolve(rect.x + "," + rect.y + "," + rect.width + "," + rect.height);
					});
				});
			''');
			await Future.delayed(const Duration(milliseconds: 50));
			final ltwh = (returnData!.value as String).split(',').map((s) => double.parse(s)).toList();
			final imageData = await webView.webViewController?.takeScreenshot(screenshotConfiguration: ScreenshotConfiguration(
				rect: InAppWebViewRect(
					x: ltwh[0] - 5,
					y: ltwh[1] - 5,
					width: ltwh[2] + 10,
					height: ltwh[3] + 10
				)
			));
			if (imageData != null) {
				imageCompleter.complete(imageData);
			}
		});
		return await imageCompleter.future;
	}

	static HTMLRendering? _instance;
	static HTMLRendering get instance => _instance ??= HTMLRendering();
}

class HTMLImageProvider extends ImageProvider<HTMLImageProvider> {
	final String html;

	HTMLImageProvider(this.html);

	@override
	ImageStreamCompleter loadImage(HTMLImageProvider key, ImageDecoderCallback decode) {
		return MultiFrameImageStreamCompleter(
			codec: _loadAsync(decode),
			chunkEvents: Stream.fromIterable([const ImageChunkEvent(cumulativeBytesLoaded: 0, expectedTotalBytes: 1)]),
			scale: 2.0
		);
	}

	Future<Codec> _loadAsync(ImageDecoderCallback decode) async {
		final image = await HTMLRendering.instance.renderHtml(html);
		return await decode(await ImmutableBuffer.fromUint8List(image));
	}

	@override
	Future<HTMLImageProvider> obtainKey(ImageConfiguration configuration) {
		return SynchronousFuture<HTMLImageProvider>(this);
	}

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		(other is HTMLImageProvider) &&
		(other.html == html);

	@override
	int get hashCode => html.hashCode;

	@override
	String toString() => '${objectRuntimeType(this, 'HTMLImageProvider')}("$html")';
}

import 'dart:async';
import 'dart:convert' hide Codec;
import 'dart:ui';

import 'package:chan/util.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';


abstract class HTMLRendering<T> {
	late final ExpiringMutexResource<(HeadlessInAppWebView, T)> _webView;
	@protected
	String extraHead = '';
	@protected
	String afterInsert = '';

	HTMLRendering({
		this.extraHead = '',
		this.afterInsert = ''
	}) {
		_webView = ExpiringMutexResource<(HeadlessInAppWebView, T)>(_init, _deinit, interval: const Duration(seconds: 5));
	}

	Future<T> initImpl();
	Future<void> deinitImpl(T resource);

	Future<(HeadlessInAppWebView, T)> _init() async {
		final private = await initImpl();
		final loadCompleter = Completer<void>();
		final webView = HeadlessInAppWebView(
			initialSettings: InAppWebViewSettings(
				transparentBackground: true
			),
			initialData: InAppWebViewInitialData(data: '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">$extraHead</head><body style="width: 400px"/></html>'),
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
		return (webView, private);
	}

	Future<void> _deinit((HeadlessInAppWebView, T) webView) async {
		await webView.$1.dispose();
		await deinitImpl(webView.$2);
	}

	Future<Uint8List> renderHtml(String html, {double textScaleFactor = 1.0, Color? primaryColor}) async {
		final imageCompleter = Completer<Uint8List>();
		_webView.runWithResource((webView) async {
			if (primaryColor != null) {
				await webView.$1.webViewController?.evaluateJavascript(
					source: 'document.body.style.color = "${primaryColor.toCssHex()}"'
				);
			}
			final returnData = await webView.$1.webViewController?.callAsyncJavaScript(functionBody: '''
				var html = atob("${base64.encode(utf8.encode(html))}");
				var span = document.createElement("span");
				span.innerHTML = html;
				document.body.replaceChildren(span);
				$afterInsert
				return new Promise(function (resolve, reject) {
					setTimeout(function() {
						var rect = span.getBoundingClientRect();
						function descend(element) {
							var rect2 = element.getBoundingClientRect();
							var left = Math.min(rect.left, rect2.left);
							var top = Math.min(rect.top, rect2.top);
							var right = Math.max(rect.right, rect2.right);
							var bottom = Math.max(rect.bottom, rect2.bottom);
							rect = new DOMRect(left, top, right - left, bottom - top);
							[...element.children].forEach(descend)
						}
						[...span.children].forEach(descend)
						resolve(rect.x + "," + rect.y + "," + rect.width + "," + rect.height);
					}, 100);
				});
			''');
			final ltwh = (returnData!.value as String).split(',').map((s) => double.parse(s)).toList();
			final imageData = await webView.$1.webViewController?.takeScreenshot(screenshotConfiguration: ScreenshotConfiguration(
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
}

class _BasicHtmlRendering extends HTMLRendering<void> {
	static _BasicHtmlRendering? _instance;
	static _BasicHtmlRendering get instance => _instance ??= _BasicHtmlRendering();

	@override
	Future<void> initImpl() async { }

	@override
	Future<void> deinitImpl(void resource) async { }
}

class HTMLImageProvider extends ImageProvider<HTMLImageProvider> {
	final String html;
	final Color? primaryColor;

	HTMLImageProvider(this.html, {this.primaryColor});

	@override
	ImageStreamCompleter loadImage(HTMLImageProvider key, ImageDecoderCallback decode) {
		return MultiFrameImageStreamCompleter(
			codec: _loadAsync(decode),
			chunkEvents: Stream.fromIterable([const ImageChunkEvent(cumulativeBytesLoaded: 0, expectedTotalBytes: 1)]),
			scale: 2.0
		);
	}

	Future<Codec> _loadAsync(ImageDecoderCallback decode) async {
		final image = await _BasicHtmlRendering.instance.renderHtml(html, primaryColor: primaryColor);
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
		(other.html == html) &&
		(other.primaryColor == primaryColor);

	@override
	int get hashCode => Object.hash(html, primaryColor);

	@override
	String toString() => '${objectRuntimeType(this, 'HTMLImageProvider')}("$html", primaryColor: $primaryColor)';
}

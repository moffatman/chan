import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:chan/util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_tex/flutter_tex.dart';
// ignore: implementation_imports
import 'package:flutter_tex/src/utils/core_utils.dart';
import 'package:mime/mime.dart';

const String _indexHtmlPath = 'packages/flutter_tex/js/katex/index.html';
const String _replacementIndexHtmlPath = 'assets/katex.html';

class _ServerWebViewCombo {
	final HttpServer server;
	final HeadlessInAppWebView webView;
	const _ServerWebViewCombo(this.server, this.webView);
}

class TeXRendering {
	late final ExpiringMutexResource<_ServerWebViewCombo> _webView;
	Completer<String?>? _renderCallbackCompleter;

	TeXRendering() {
		_webView = ExpiringMutexResource<_ServerWebViewCombo>(_initCombo, _deinitCombo);
	}

	Future<_ServerWebViewCombo> _initCombo() async {
		final server = await HttpServer.bind('localhost', 0, shared: true);
		server.listen((HttpRequest httpRequest) async {
			List<int> body = [];
			String path = httpRequest.requestedUri.path;
			path = (path.startsWith('/')) ? path.substring(1) : path;
			path += (path.endsWith('/')) ? 'index.html' : '';
			try {
				if (path == _indexHtmlPath) {
					body = (await rootBundle.load(_replacementIndexHtmlPath)).buffer.asUint8List();
				}
				else {
					body = (await rootBundle.load(path)).buffer.asUint8List();
				}
			} catch (e) {
				print('Error: $e');
				httpRequest.response.close();
				return;
			}
			var contentType = ['text', 'html'];
			if (!httpRequest.requestedUri.path.endsWith('/') &&
					httpRequest.requestedUri.pathSegments.isNotEmpty) {
				String? mimeType = lookupMimeType(httpRequest.requestedUri.path,
						headerBytes: body);
				if (mimeType != null) {
					contentType = mimeType.split('/');
				}
			}
			httpRequest.response.headers.contentType =
					ContentType(contentType[0], contentType[1], charset: 'utf-8');
			httpRequest.response.add(body);
			httpRequest.response.close();
		});
		final loadCompleter = Completer<void>();
		final webView = HeadlessInAppWebView(
			initialOptions: InAppWebViewGroupOptions(
				crossPlatform: InAppWebViewOptions(
					transparentBackground: true
				)
			),
			initialUrlRequest: URLRequest(
				url: Uri.http('localhost:${server.port}', _indexHtmlPath)
			),
			onLoadStop: (controller, url) {
				loadCompleter.complete();
			},
			onConsoleMessage: (controller, message) {
				print(message);
			}
		);
		await webView.run();
		await webView.webViewController.addWebMessageListener(WebMessageListener(
			jsObjectName: 'TeXViewRenderedCallback',
			allowedOriginRules: {'*'},
			onPostMessage: (message, origin, isMainFrame, replyProxy) {
				_renderCallbackCompleter?.complete(message);
			}
		));
		await Future.any([loadCompleter.future, Future.delayed(const Duration(seconds: 5))]);
		await Future.delayed(const Duration(milliseconds: 100));
		return _ServerWebViewCombo(server, webView);
	}

	Future<void> _deinitCombo(_ServerWebViewCombo combo) async {
		await combo.webView.dispose();
		await combo.server.close();
	}

	Future<Uint8List> renderTex(String tex, {double textScaleFactor = 1.0}) async {
		final imageCompleter = Completer<Uint8List>();
		_webView.runWithResource((combo) async {
			_renderCallbackCompleter = Completer<String>();
			await combo.webView.webViewController.evaluateJavascript(source: 'var jsonData = ${getRawData(TeXView(
				child: TeXViewDocument('\$\$${tex.replaceAll('<br>', '')}\$\$'),
				style: TeXViewStyle(
					fontStyle: TeXViewFontStyle(fontSize: (16 * textScaleFactor).round())
				)
			))};initView(jsonData);');
			final returnData = await Future.any([Future<String?>.delayed(const Duration(seconds: 10)), _renderCallbackCompleter!.future]);
			if (returnData == null) {
				throw StateError('Timed out rendering $tex');
			}
			else {
				await Future.delayed(const Duration(milliseconds: 50));
				final ltwh = returnData.split(',').map((s) => double.parse(s)).toList();
				final imageData = await combo.webView.webViewController.takeScreenshot(screenshotConfiguration: ScreenshotConfiguration(
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
			}
		});
		return await imageCompleter.future;
	}

	static TeXRendering? _instance;
	static TeXRendering getInstance() {
		_instance ??= TeXRendering();
		return _instance!;
	}

}

class TeXImageProvider extends ImageProvider<TeXImageProvider> {
	final String tex;
	final double textScaleFactor;

	TeXImageProvider(this.tex, {this.textScaleFactor = 1.0});

	@override
	ImageStreamCompleter loadBuffer(TeXImageProvider key, DecoderBufferCallback decode) {
		return MultiFrameImageStreamCompleter(
			codec: _loadAsync(decode),
			chunkEvents: Stream.fromIterable([const ImageChunkEvent(cumulativeBytesLoaded: 0, expectedTotalBytes: 1)]),
			scale: 2.0
		);
	}

	Future<Codec> _loadAsync(DecoderBufferCallback decode) async {
		final image = await TeXRendering.getInstance().renderTex(tex, textScaleFactor: textScaleFactor);
		return await decode(await ImmutableBuffer.fromUint8List(image));
	}

	@override
	Future<TeXImageProvider> obtainKey(ImageConfiguration configuration) {
		return SynchronousFuture<TeXImageProvider>(this);
	}

	@override
	bool operator == (dynamic other) => (other is TeXImageProvider) && (other.tex == tex);

	@override
	int get hashCode => tex.hashCode;

	@override
	String toString() => '${objectRuntimeType(this, 'TeXImageProvider')}("$tex")';
}
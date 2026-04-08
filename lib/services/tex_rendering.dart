import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:chan/services/html_rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mime/mime.dart';

const _kJsPath = 'assets/mathjax.min.js';
const _kGzippedPaths = {_kJsPath};

class TeXRendering extends HTMLRendering<HttpServer> {
	TeXRendering() : super(
		afterInsert: 'await window.MathJax.typesetPromise();await document.fonts.ready;'
	);

	@override
	Future<HttpServer> initImpl() async {
		final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
		extraHead = '<script type="text/javascript">MathJax = {output: {font: "mathjax-newcm", fontPath: "http://localhost:${server.port}/assets/mathjax-newcm-font"}}</script><script type="text/javascript" src="http://localhost:${server.port}/$_kJsPath"></script>';
		server.listen((HttpRequest httpRequest) async {
			List<int> body = [];
			String path = httpRequest.requestedUri.path;
			path = (path.startsWith('/')) ? path.substring(1) : path;
			path += (path.endsWith('/')) ? 'index.html' : '';
			try {
				if (_kGzippedPaths.contains(path)) {
					body = (await rootBundle.load('$path.gz')).buffer.asUint8List();
					if (httpRequest.headers.value(HttpHeaders.acceptEncodingHeader)?.contains('gzip') ?? false) {
						httpRequest.response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
					}
					else {
						body = gzip.decode(body);
					}
				}
				else {
					body = (await rootBundle.load(path)).buffer.asUint8List();
				}
			} catch (e, st) {
				print('Error: $e');
				print(st);
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
		return server;
	}

	@override
	Future<void> deinitImpl(HttpServer server) async {
		await server.close();
	}

	static TeXRendering? _instance;
	static TeXRendering getInstance() {
		_instance ??= TeXRendering();
		return _instance!;
	}
}

class TeXImageProvider extends ImageProvider<TeXImageProvider> {
	final String tex;
	final Color? color;
	final double textScaleFactor;

	TeXImageProvider(this.tex, {this.color, this.textScaleFactor = 1.0});

	@override
	ImageStreamCompleter loadImage(TeXImageProvider key, ImageDecoderCallback decode) {
		return MultiFrameImageStreamCompleter(
			codec: _loadAsync(decode),
			chunkEvents: Stream.fromIterable([const ImageChunkEvent(cumulativeBytesLoaded: 0, expectedTotalBytes: 1)]),
			scale: 2.0
		);
	}

	Future<Codec> _loadAsync(ImageDecoderCallback decode) async {
		final image = await TeXRendering.getInstance().renderHtml('<span style="font-size: 20px">\\($tex\\)</span>', textScaleFactor: textScaleFactor, primaryColor: color);
		return await decode(await ImmutableBuffer.fromUint8List(image));
	}

	@override
	Future<TeXImageProvider> obtainKey(ImageConfiguration configuration) {
		return SynchronousFuture<TeXImageProvider>(this);
	}

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		(other is TeXImageProvider) &&
		(other.tex == tex) &&
		(other.color == color);

	@override
	int get hashCode => Object.hash(tex, color);

	@override
	String toString() => '${objectRuntimeType(this, 'TeXImageProvider')}("$tex")';
}
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chan/models/attachment.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/streaming_mp4.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/attachment_viewer.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Transparent 1x1 PNG bytes
final kDefaultPng = base64.decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==');

extension _Utility on HttpRequest {
	Future<void> closeWithImage() async {
		response.statusCode = 200;
		response.headers.contentType = ContentType('image', 'png');
		response.contentLength = kDefaultPng.length;
		response.add(kDefaultPng);
		await response.flush();
		await response.close();
	}
  Future<void> closeWith429(int seconds) async {
		response.statusCode = 429;
		response.headers.add(HttpHeaders.retryAfterHeader, '5');
		response.contentLength = 0;
		await response.close();
	}
}

class FakeContext implements BuildContext {
  @override
  bool get mounted => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeImageboardSite extends ImageboardSite {
  @override
  final String imageUrl;
  FakeImageboardSite({
    required this.imageUrl
  }) : super(
    archives: const [],
    overrideUserAgent: null
  );
  @override
  dynamic noSuchMethod(Invocation invocation) {
    print(invocation);
    throw UnimplementedError();
  }
  @override
	String toString() => 'FakeImageboardSite(imageUrl: $imageUrl)';
}

class FakeImageboard extends Imageboard {
  @override
  final ImageboardSite site;
  FakeImageboard({
    required this.site
  }) : super(key: 'fake', siteData: null);
}

Attachment makeFakeAttachment(Uri uri) => Attachment(
	type: AttachmentType.mp4,
	board: '',
	id: '',
	ext: '',
	filename: '',
	url: uri.toString(),
	thumbnailUrl: '',
	md5: '',
	width: null,
	height: null,
	threadId: null,
	sizeInBytes: null
);

void main() async {
	await Persistence.initializeForTesting();
	test('HTTP 429 queueing', () async {
		final root = await Directory.current.createTemp('caching_server_');
		final fakeServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
		VideoServer.initializeStatic(root, root, port: 4071, bufferOutput: false);
		try {
			Completer<HttpRequest> completer = Completer();
			fakeServer.listen((request) {
				print('new request ${request.uri}');
				if (completer.isCompleted) {
					throw Exception('HttpRequest not expected: ${request.uri}');
				}
				completer.complete(request);
			});
			final host = InternetAddress.loopbackIPv4.host;
			final authority = '$host:${fakeServer.port}';
			final context = FakeContext();
			final imageboard = FakeImageboard(
				site: FakeImageboardSite(
					imageUrl: host
				)
			);
			final u1 = Uri.http(authority, '/1');
			final c1 = AttachmentViewerController(
				context: context,
				imageboard: imageboard,
				attachment: makeFakeAttachment(u1)
			);
			final u2 = Uri.http(authority, '/2');
			final c2 = AttachmentViewerController(
				context: context,
				imageboard: imageboard,
				attachment: makeFakeAttachment(u2)
			);
			final u3 = Uri.http(authority, '/3');
			final c3 = AttachmentViewerController(
				context: context,
				imageboard: imageboard,
				attachment: makeFakeAttachment(u3)
			);
			final u4 = Uri.http(authority, '/4');
			final c4 = AttachmentViewerController(
				context: context,
				imageboard: imageboard,
				attachment: makeFakeAttachment(u4)
			);
			final c1f = c1.preloadFullAttachment();
			final c1r1 = await completer.future;
			expect(c1r1.uri.toString(), u1.path);
			completer = Completer();
			final c2f = c2.preloadFullAttachment();
			final c2r1 = await completer.future;
			expect(c2r1.uri.toString(), u2.path);
			completer = Completer();
			final c3f = c3.preloadFullAttachment();
			final c3r1 = await completer.future;
			expect(c3r1.uri.toString(), u3.path);
			completer = Completer();
			final c4f = c4.preloadFullAttachment();
			final c4r1 = await completer.future;
			expect(c4r1.uri.toString(), u4.path);
			completer = Completer();
			await c1r1.closeWith429(5);
			await c2r1.closeWith429(1);
			await c3r1.closeWith429(1);
			await c4r1.closeWith429(1);
			final c1r2 = await completer.future;
			completer = Completer();
			expect(c1r2.uri.toString(), u1.path);
			await Future.delayed(const Duration(seconds: 1));
			// Should be in series mode
			expect(completer.isCompleted, isFalse);
			c1r2.closeWithImage();
			final c2r2 = await completer.future;
			completer = Completer();
			expect(c2r2.uri.toString(), u2.path);
			c2r2.closeWithImage();
			final c3r2 = await completer.future;
			completer = Completer();
			expect(c3r2.uri.toString(), u3.path);
			c3r2.closeWithImage();
			final c4r2 = await completer.future;
			completer = Completer();
			expect(c4r2.uri.toString(), u4.path);
			c4r2.closeWithImage();
			await c1f;
			expect(c1.cacheCompleted, isTrue);
			await c2f;
			expect(c2.cacheCompleted, isTrue);
			await c3f;
			expect(c3.cacheCompleted, isTrue);
			await c4f;
			expect(c4.cacheCompleted, isTrue);
			VideoServer.teardownStatic();
		}
		finally {
			await root.delete(recursive: true);
			await fakeServer.close(force: true);
			VideoServer.teardownStatic();
		}
	}, timeout: const Timeout(Duration(seconds: 10)));

	test('HTTP 429 priority', () async {
		final root = await Directory.current.createTemp('caching_server_');
		final fakeServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
		VideoServer.initializeStatic(root, root, port: 4071, bufferOutput: false);
		try {
			Completer<HttpRequest> completer = Completer();
			fakeServer.listen((request) {
				print('new request ${request.uri}');
				if (completer.isCompleted) {
					throw Exception('HttpRequest not expected: ${request.uri}');
				}
				completer.complete(request);
			});
			final host = InternetAddress.loopbackIPv4.host;
			final authority = '$host:${fakeServer.port}';
			final context = FakeContext();
			final imageboard = FakeImageboard(
				site: FakeImageboardSite(
					imageUrl: host
				)
			);
			final u1 = Uri.http(authority, '/1');
			final c1 = AttachmentViewerController(
				context: context,
				imageboard: imageboard,
				attachment: makeFakeAttachment(u1)
			);
			final u2 = Uri.http(authority, '/2');
			final c2 = AttachmentViewerController(
				context: context,
				imageboard: imageboard,
				attachment: makeFakeAttachment(u2)
			);
			final u3 = Uri.http(authority, '/3');
			final c3 = AttachmentViewerController(
				context: context,
				imageboard: imageboard,
				attachment: makeFakeAttachment(u3)
			);
			final c1f = c1.preloadFullAttachment();
			final c1r1 = await completer.future;
			expect(c1r1.uri.toString(), u1.path);
			completer = Completer();
			final c2f = c2.preloadFullAttachment();
			final c2r1 = await completer.future;
			expect(c2r1.uri.toString(), u2.path);
			completer = Completer();
			final c3f = c3.preloadFullAttachment();
			final c3r1 = await completer.future;
			expect(c3r1.uri.toString(), u3.path);
			completer = Completer();
			await c1r1.closeWith429(5);
			await c2r1.closeWith429(5);
			await c3r1.closeWith429(1);
			c2.isPrimary = true;
			c2.isPrimary = false;
			c3.isPrimary = true;
			await Future.delayed(const Duration(milliseconds: 4900));
			expect(completer.isCompleted, isFalse);
			final c3r2 = await completer.future;
			completer = Completer();
			expect(c3r2.uri.toString(), u3.path);
			await Future.delayed(const Duration(seconds: 1));
			// Should be in series mode
			expect(completer.isCompleted, isFalse);
			c3r2.closeWithImage();
			final c2r2 = await completer.future;
			completer = Completer();
			expect(c2r2.uri.toString(), u2.path);
			c2r2.closeWithImage();
			final c1r2 = await completer.future;
			completer = Completer();
			expect(c1r2.uri.toString(), u1.path);
			c1r2.closeWithImage();
			await c3f;
			expect(c3.cacheCompleted, isTrue);
			await c2f;
			expect(c2.cacheCompleted, isTrue);
			await c1f;
			expect(c1.cacheCompleted, isTrue);
			VideoServer.teardownStatic();
		}
		finally {
			await root.delete(recursive: true);
			await fakeServer.close(force: true);
			VideoServer.teardownStatic();
		}
	}, timeout: const Timeout(Duration(seconds: 10)));

	test('HTTP 429 cancellation', () async {
		final root = await Directory.current.createTemp('caching_server_');
		final fakeServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
		VideoServer.initializeStatic(root, root, port: 4071, bufferOutput: false);
		try {
			Completer<HttpRequest> completer = Completer();
			fakeServer.listen((request) {
				print('new request ${request.uri}');
				if (completer.isCompleted) {
					throw Exception('HttpRequest not expected: ${request.uri}');
				}
				completer.complete(request);
			});
			final host = InternetAddress.loopbackIPv4.host;
			final authority = '$host:${fakeServer.port}';
			final context = FakeContext();
			final imageboard = FakeImageboard(
				site: FakeImageboardSite(
					imageUrl: host
				)
			);
			final u1 = Uri.http(authority, '/1');
			final c1 = AttachmentViewerController(
				context: context,
				imageboard: imageboard,
				attachment: makeFakeAttachment(u1)
			);
			final u2 = Uri.http(authority, '/2');
			final c2 = AttachmentViewerController(
				context: context,
				imageboard: imageboard,
				attachment: makeFakeAttachment(u2)
			);
			final c1f = c1.preloadFullAttachment();
			final c1r1 = await completer.future;
			expect(c1r1.uri.toString(), u1.path);
			completer = Completer();
			final c2f = c2.preloadFullAttachment();
			final c2r1 = await completer.future;
			expect(c2r1.uri.toString(), u2.path);
			completer = Completer();
			await c1r1.closeWith429(5);
			await c2r1.closeWith429(5);
			c1.dispose();
			await Future.delayed(const Duration(milliseconds: 4900));
			expect(completer.isCompleted, isFalse);
			final c2r2 = await completer.future;
			completer = Completer();
			expect(c2r2.uri.toString(), u2.path);
			c2r2.closeWithImage();
			await c2f;
			expect(c2.cacheCompleted, isTrue);
			await Future.delayed(const Duration(seconds: 1));
			expect(completer.isCompleted, isFalse);
			await c1f;
			expect(c1.cacheCompleted, isFalse);
			VideoServer.teardownStatic();
		}
		finally {
			await root.delete(recursive: true);
			await fakeServer.close(force: true);
			VideoServer.teardownStatic();
		}
	}, timeout: const Timeout(Duration(seconds: 15)));
}

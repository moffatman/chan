import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:chan/models/board.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/compress_html.dart';
import 'package:chan/services/html_error.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/json_cache.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/priority_queue.dart';
import 'package:chan/services/streaming_mp4.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/jforum.dart';
import 'package:chan/sites/lainchan2.dart';
import 'package:flutter/foundation.dart';
import 'package:test/test.dart';
import 'package:chan/util.dart';

bool id(bool x) => x;

void main() async {
  await Persistence.initializeForTesting();
  final sites = await JsonCache.instance.sites.updater();
  group('BinarySearch', () {
    test('firstwhere', () {
      for (int length = 1; length < 90; length++) {
        for (int switchpoint = 0; switchpoint <= length; switchpoint++) {
          final List<bool> list = List.generate(length, (i) => i >= switchpoint);
          expect(list.binarySearchFirstIndexWhere(id), switchpoint == length ? -1 : switchpoint);
        }
      }
    });
    test('lastwhere', () {
      for (int length = 1; length < 90; length++) {
        for (int switchpoint = 0; switchpoint <= length; switchpoint++) {
          final List<bool> list = List.generate(length, (i) => i <= switchpoint);
          expect(list.binarySearchLastIndexWhere(id), switchpoint == length ? length - 1 : switchpoint);
        }
      }
    });
  });

  group('insertIntoSortedList', () {
    test('test1', () {
      final methods = <Comparator<String>>[
        (a, b) => a.substring(1, 2).compareTo(b.substring(1, 2)),
        (a, b) => a.substring(0, 1).compareTo(b.substring(0, 1))
      ];
      final list = ['01a', '02', '10'];
      insertIntoSortedList(list: list, sortMethods: methods, reverseSort: false, item: '03');
      expect(listEquals(list, ['01a', '02', '03', '10']), isTrue);
      insertIntoSortedList(list: list, sortMethods: methods, reverseSort: false, item: '00');
      expect(listEquals(list, ['00', '01a', '02', '03', '10']), isTrue);
      insertIntoSortedList(list: list, sortMethods: methods, reverseSort: false, item: '20');
      expect(listEquals(list, ['00', '01a', '02', '03', '10', '20']), isTrue);
      insertIntoSortedList(list: list, sortMethods: methods, reverseSort: false, item: '01b');
      expect(listEquals(list, ['00', '01b', '01a', '02', '03', '10', '20']), isTrue);
    });
  });

  group('decodeUrl and toWebUrl', () {
    for (final siteEntry in sites.entries) {
      test(siteEntry.key, () async {
        final imageboard = Imageboard(key: siteEntry.key, siteData: siteEntry.value);
        await imageboard.initialize(forTesting: true);
        final site = imageboard.site;
        for (final b in [
          if (!site.supportsMultipleBoards) ''
          else if (site is SiteJForum) ...[
            '1.a',
            '2.fdsa',
            '3.λ'
          ]
          else ...[
            'a',
            'fdsa',
            'λ'
          ]
        ]) {
          for (final id in [
            if (site.supportsMultipleBoards) BoardThreadOrPostIdentifier(b),
            BoardThreadOrPostIdentifier(b, 1234 + b.hashCode),
            // Hacker news would need network lookup to find the OP
            if (site.supportsMultipleBoards) BoardThreadOrPostIdentifier(b, 2345 + b.hashCode, 6789),
            if (site.isPaged) BoardThreadOrPostIdentifier(b, 2345 + b.hashCode, -10)
          ]) {
            // Hack around network request need by attempting to prepopulate data
            await imageboard.persistence.setBoard(id.board, ImageboardBoard(
              name: id.board,
              title: 'Fake board "${id.board}"',
              isWorksafe: false,
              webmAudioAllowed: false
            ));
            await Persistence.sharedThreadStateBox.put(
              '${imageboard.key}/${ImageboardBoard.getKey(id.board)}/${id.threadId ?? 0}',
              PersistentThreadState(
                imageboardKey: imageboard.key,
                board: id.board,
                id: id.threadId ?? 0,
                showInHistory: true
              )
            );
            final url = site.getWebUrl(board: id.board, threadId: id.threadId, postId: id.postId);
            expect(await site.decodeUrl(Uri.parse(url)), id);
            for (final archive in site.archives) {
              final url = archive.getWebUrl(board: id.board, threadId: id.threadId, postId: id.postId);
              expect(await archive.decodeUrl(Uri.parse(url)), id);
            }
          }
        }
      });
    }
  });

  group('Lainchan RegExes', () {
    test('decodeUrl', () async {
      final site = SiteLainchan2(
        baseUrl: 'example.com',
        name: 'example',
        imageUrl: null,
        overrideUserAgent: null,
        archives: const [],
        imageHeaders: const {},
        videoHeaders: const {},
        turnstileSiteKey: null,
        basePath: '',
        formBypass: const {},
        additionalCookies: const {},
        imageThumbnailExtension: null,
        boardsWithHtmlOnlyFlags: const [],
        boardsWithMemeFlags: const [],
        res: 'res'
      );
      expect(await site.decodeUrl(Uri.https('example.com', '/')), null);
      expect(await site.decodeUrl(Uri.https('example.com', '/board/')), BoardThreadOrPostIdentifier('board'));
      expect(await site.decodeUrl(Uri.https('example.com', '/board/0.json')), null);
      expect(await site.decodeUrl(Uri.https('example.com', '/board/res/1234.html')), BoardThreadOrPostIdentifier('board', 1234));
      expect(await site.decodeUrl(Uri.https('example.com', '/board/res/1234.json')), null);
      expect(await site.decodeUrl(Uri.https('example.com', '/board/res/1234.html').replace(fragment: 'q1235')), BoardThreadOrPostIdentifier('board', 1234, 1235));
      expect(await site.decodeUrl(Uri.https('example.com', '/board/res/1234.html', {'also': 'yes'}).replace(fragment: 'q1235')), BoardThreadOrPostIdentifier('board', 1234, 1235));
    });
  });

  group('HTML compressor', () {
    test('compress', () {
      const html = '<a href="https://example.com">https://example.com</a><br><span>&gt;&gt;12345678</span>';
      final compressed = compressHTML(html);
      expect(compressed.html, '<c></c><br></br><d></d>');
      expect(compressed.decompressTranslation(compressed.html), html);
    });
  });

  group('Caching server', () {
    test('normal', () async {
      final root = await Directory.current.createTemp('caching_server_');
      VideoServer.initializeStatic(root, root, bufferOutput: false);
      final fakeServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = HttpClient();
      final requests = <HttpRequest>[];
      fakeServer.listen((request) {
        requests.add(request);
      });
      try {
        final digestFuture = VideoServer.instance.startCachingDownload(uri: (Uri.http('localhost:${fakeServer.port}')));
        await Future.delayed(const Duration(milliseconds: 1000));
        expect(requests.length, equals(1));
        requests[0].response.bufferOutput = false;
        requests[0].response.contentLength = 10000;
        requests[0].response.add(Uint8List(1000));
        await requests[0].response.flush();
        final digest = await digestFuture;
        final clientRequest = await client.getUrl(VideoServer.instance.getUri(digest));
        clientRequest.bufferOutput = false;
        final response = await clientRequest.close();
        await Future.delayed(const Duration(milliseconds: 100));
        expect(response.contentLength, equals(10000));
        expect(response.statusCode, equals(200));
        final chunks = <List<int>>[];
        bool responseStreamSubscriptionIsDone = false;
        response.listen(chunks.add, onDone: () {
          responseStreamSubscriptionIsDone = true;
        });
        await Future.delayed(const Duration(milliseconds: 100));
        expect(chunks.length, equals(1));
        expect(chunks[0].length, equals(1000));
        requests[0].response.add(Uint8List(9000));
        await requests[0].response.flush();
        await Future.delayed(const Duration(milliseconds: 100));
        expect(chunks.length, equals(2));
        expect(chunks[1].length, equals(9000));
        await requests[0].response.close();
        await Future.delayed(const Duration(milliseconds: 100));
        expect(chunks.length, equals(2));
        expect(responseStreamSubscriptionIsDone, isTrue);
        final file = VideoServer.instance.getFile(digest);
        expect(await file.exists(), isTrue);
        expect(await file.length(), equals(10000));
        // Try a second request, it shouldn't hit the original server, and should return all in one chunk.
        final clientRequest2 = await client.getUrl(VideoServer.instance.getUri(digest));
        clientRequest2.bufferOutput = false;
        final response2 = await clientRequest2.close();
        chunks.clear();
        responseStreamSubscriptionIsDone = false;
        response2.listen(chunks.add, onDone: () {
          responseStreamSubscriptionIsDone = true;
        });
        await Future.delayed(const Duration(milliseconds: 100));
        expect(response.contentLength, equals(10000));
        expect(response.statusCode, equals(200));
        await Future.delayed(const Duration(milliseconds: 100));
        expect(chunks.length, equals(1));
        expect(chunks[0].length, equals(10000));
        expect(responseStreamSubscriptionIsDone, isTrue);
        expect(requests.length, equals(1));
        // Now delete the file and check that another request is issued
        await file.delete();
        final future2 = VideoServer.instance.startCachingDownload(uri: (Uri.http('localhost:${fakeServer.port}')));
        await Future.delayed(const Duration(milliseconds: 100));
        expect(requests.length, equals(2));
        requests[1].response.bufferOutput = false;
        requests[1].response.contentLength = 10000;
        requests[1].response.add(Uint8List(10000));
        await requests[0].response.close();
        await future2;
        final clientRequest3 = await client.getUrl(VideoServer.instance.getUri(digest));
        clientRequest3.bufferOutput = false;
        final response3 = await clientRequest3.close();
        chunks.clear();
        responseStreamSubscriptionIsDone = false;
        response3.listen(chunks.add, onDone: () {
          responseStreamSubscriptionIsDone = true;
        });
        await Future.delayed(const Duration(milliseconds: 100));
        expect(response3.contentLength, equals(10000));
        expect(response3.statusCode, equals(200));
        await Future.delayed(const Duration(milliseconds: 100));
        expect(chunks.length, equals(1));
        expect(chunks[0].length, equals(10000));
        expect(responseStreamSubscriptionIsDone, isTrue);
        expect(await file.exists(), isTrue);
        expect(await file.length(), equals(10000));
      }
      finally {
        await root.delete(recursive: true);
        fakeServer.close();
        VideoServer.teardownStatic();
      }
    });

    test('status code 404', () async {
      final root = await Directory.current.createTemp('caching_server_');
      VideoServer.initializeStatic(root, root, bufferOutput: false);
      final fakeServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = HttpClient();
      final requests = <HttpRequest>[];
      fakeServer.listen((request) {
        requests.add(request);
      });
      try {
        final digestFuture0 = VideoServer.instance.startCachingDownload(uri: (Uri.http('localhost:${fakeServer.port}')));
        await Future.delayed(const Duration(milliseconds: 100));
        expect(requests.length, equals(1));
        requests[0].response.bufferOutput = false;
        requests[0].response.statusCode = 404;
        requests[0].response.contentLength = 10000;
        requests[0].response.add(Uint8List(1000));
        await requests[0].response.flush();
        try {
          await digestFuture0;
          throw Exception('Did not get expected exception');
        }
        on HTTPStatusException catch (e) {
          expect(e.code, equals(404));
        }
        final digestFuture1 = VideoServer.instance.startCachingDownload(uri: (Uri.http('localhost:${fakeServer.port}')));
        await Future.delayed(const Duration(milliseconds: 100));
        expect(requests.length, equals(2));
        requests[1].response.bufferOutput = false;
        requests[1].response.statusCode = 200;
        requests[1].response.contentLength = 10000;
        requests[1].response.add(Uint8List(1000));
        await requests[0].response.flush();
        final digest = await digestFuture1;
        final clientRequest = await client.getUrl(VideoServer.instance.getUri(digest));
        clientRequest.bufferOutput = false;
        final response = await clientRequest.close();
        await Future.delayed(const Duration(milliseconds: 100));
        expect(response.contentLength, equals(10000));
        expect(response.statusCode, equals(200));
        final chunks = <List<int>>[];
        bool responseStreamSubscriptionIsDone = false;
        response.listen(chunks.add, onDone: () {
          responseStreamSubscriptionIsDone = true;
        });
        await Future.delayed(const Duration(milliseconds: 100));
        expect(chunks.length, equals(1));
        expect(chunks[0].length, equals(1000));
        requests[1].response.add(Uint8List(9000));
        await requests[1].response.flush();
        await Future.delayed(const Duration(milliseconds: 100));
        expect(chunks.length, equals(2));
        expect(chunks[1].length, equals(9000));
        await requests[1].response.close();
        await Future.delayed(const Duration(milliseconds: 100));
        expect(chunks.length, equals(2));
        expect(responseStreamSubscriptionIsDone, isTrue);
        final file = VideoServer.instance.getFile(digest);
        expect(await file.exists(), isTrue);
        expect(await file.length(), equals(10000));
        // Try again
        final clientRequest2 = await client.getUrl(VideoServer.instance.getUri(digest));
        clientRequest2.bufferOutput = false;
        final response2 = await clientRequest2.close();
        chunks.clear();
        responseStreamSubscriptionIsDone = false;
        response2.listen(chunks.add, onDone: () {
          responseStreamSubscriptionIsDone = true;
        });
        await Future.delayed(const Duration(milliseconds: 100));
        expect(response2.contentLength, equals(10000));
        expect(response2.statusCode, equals(200));
        await Future.delayed(const Duration(milliseconds: 100));
        expect(chunks.length, equals(1));
        expect(chunks[0].length, equals(10000));
        expect(responseStreamSubscriptionIsDone, isTrue);
        expect(requests.length, equals(2));
      }
      finally {
        await root.delete(recursive: true);
        fakeServer.close();
        VideoServer.teardownStatic();
      }
    });

    test('incomplete', () async {
      final root = await Directory.current.createTemp('caching_server_');
      final fakeServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = HttpClient();
      final requests = <HttpRequest>[];
      fakeServer.listen((request) {
        requests.add(request);
      });
      try {
        VideoServer.initializeStatic(root, root, bufferOutput: false);
        final digestFuture = VideoServer.instance.startCachingDownload(uri: (Uri.http('localhost:${fakeServer.port}')));
        await Future.delayed(const Duration(milliseconds: 100));
        expect(requests.length, equals(1));
        requests[0].response.bufferOutput = false;
        requests[0].response.contentLength = 10000;
        requests[0].response.add(Uint8List(1000));
        await requests[0].response.flush();
        final digest = await digestFuture;
        final clientRequest = await client.getUrl(VideoServer.instance.getUri(digest));
        clientRequest.bufferOutput = false;
        final response = await clientRequest.close();
        await Future.delayed(const Duration(milliseconds: 100));
        expect(response.contentLength, equals(10000));
        final chunks = <List<int>>[];
        bool responseStreamSubscriptionIsErrored = false;
        response.listen(chunks.add, onError: (e) {
          responseStreamSubscriptionIsErrored = true;
        });
        await Future.delayed(const Duration(milliseconds: 100));
        expect(chunks.length, equals(1));
        expect(chunks[0].length, equals(1000));
        try {
          await requests[0].response.close();
          fail('Closing response should have thrown');
        }
        on HttpException {
          // Expected, we are prematurely closing the stream
        }
        await Future.delayed(const Duration(milliseconds: 200));
        expect(chunks.length, equals(1));
        expect(responseStreamSubscriptionIsErrored, isTrue);
        final file = VideoServer.instance.getFile(digest);
        expect(await file.exists(), isFalse);
      }
      finally {
        await root.delete(recursive: true);
        fakeServer.close();
        VideoServer.teardownStatic();
      }
    });

    test('content', () async {
      final root = await Directory.current.createTemp('caching_server_');
      VideoServer.initializeStatic(root, root, bufferOutput: false);
      final fakeServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = HttpClient();
      final requests = <HttpRequest>[];
      fakeServer.listen((request) {
        requests.add(request);
      });
      try {
        const int kLength = 10000;
        final random = Random();
        final buffer = Uint8List.fromList(List.generate(kLength, (i) => random.nextInt(256)));
        final digestFuture = VideoServer.instance.startCachingDownload(uri: (Uri.http('localhost:${fakeServer.port}')));
        await Future.delayed(const Duration(milliseconds: 100));
        expect(requests.length, equals(1));
        requests[0].response.bufferOutput = false;
        requests[0].response.contentLength = kLength;
        requests[0].response.add(buffer.sublist(0, 10));
        await requests[0].response.flush();
        final digest = await digestFuture;
        final clientRequest = await client.getUrl(VideoServer.instance.getUri(digest));
        clientRequest.bufferOutput = false;
        const int rangeStart = 1;
        final rangeEndInclusive = 1 + random.nextInt(kLength ~/ 3) + kLength ~/ 2;
        clientRequest.headers.set(HttpHeaders.rangeHeader, 'bytes=$rangeStart-$rangeEndInclusive');
        await requests[0].response.flush();
        final response = await clientRequest.close();
        await Future.delayed(const Duration(milliseconds: 100));
        expect(response.contentLength, equals(1 + rangeEndInclusive - rangeStart));
        expect(response.statusCode, equals(206));
        final toListFuture = response.toList();
        int i = 10;
        while (i < kLength) {
          final chunkSize = random.nextInt(50);
          requests[0].response.add(buffer.sublist(i, min(i + chunkSize, kLength)));
          await requests[0].response.flush();
          i += chunkSize;
        }
        await requests[0].response.close();
        await Future.delayed(const Duration(milliseconds: 100));
        final file = VideoServer.instance.getFile(digest);
        expect(await file.exists(), isTrue);
        expect(await file.length(), equals(10000));
        final outputBuffer = (await toListFuture).expand((x) => x).toList();
        expect(outputBuffer, equals(buffer.sublist(rangeStart, rangeEndInclusive + 1)));
      }
      finally {
        await root.delete(recursive: true);
        fakeServer.close();
        VideoServer.teardownStatic();
      }
    });

    test('Sibling', () async {
      final root = await Directory.current.createTemp('caching_server_');
      VideoServer.initializeStatic(root, root, bufferOutput: false);
      final fakeServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = HttpClient();
      final requests = <HttpRequest>[];
      fakeServer.listen((request) {
        requests.add(request);
      });
      try {
        final uri1 = Uri.http('localhost:${fakeServer.port}', '/Dir1/File1.ext1');
        final digestFuture = VideoServer.instance.startCachingDownload(uri: uri1);
        await Future.delayed(const Duration(milliseconds: 100));
        expect(requests.length, equals(1));
        expect(requests[0].requestedUri.path, equals('/Dir1/File1.ext1'));
        requests[0].response.bufferOutput = false;
        requests[0].response.contentLength = 10000;
        requests[0].response.add(Uint8List(1000));
        await requests[0].response.flush();
        final digest = await digestFuture;
        final clientRequest = await client.getUrl(VideoServer.instance.getUri(digest));
        expect(VideoServer.instance.getUri(digest).path, endsWith('.ext1'));
        clientRequest.bufferOutput = false;
        final response = await clientRequest.close();
        await Future.delayed(const Duration(milliseconds: 100));
        expect(response.contentLength, equals(10000));
        expect(response.statusCode, equals(200));
        final chunks = <List<int>>[];
        bool responseStreamSubscriptionIsDone = false;
        response.listen(chunks.add, onDone: () {
          responseStreamSubscriptionIsDone = true;
        });
        await Future.delayed(const Duration(milliseconds: 100));
        expect(chunks.length, equals(1));
        expect(chunks[0].length, equals(1000));
        requests[0].response.add(Uint8List(9000));
        await requests[0].response.flush();
        await Future.delayed(const Duration(milliseconds: 100));
        expect(chunks.length, equals(2));
        expect(chunks[1].length, equals(9000));
        await requests[0].response.close();
        await Future.delayed(const Duration(milliseconds: 100));
        expect(chunks.length, equals(2));
        expect(responseStreamSubscriptionIsDone, isTrue);
        final file = VideoServer.instance.getFile(digest);
        expect(await file.exists(), isTrue);
        expect(await file.length(), equals(10000));
        // Now try a file relative to the first URI
        final uri2 = VideoServer.instance.getUri(digest).resolve('./File2.ext2');
        final clientRequest2 = await client.getUrl(uri2);
        clientRequest2.bufferOutput = false;
        final clientRequest2Future = clientRequest2.close();
        await Future.delayed(const Duration(milliseconds: 100));
        expect(requests.length, equals(2));
        expect(requests[1].requestedUri.path, equals('/Dir1/File2.ext2'));
        requests[1].response.bufferOutput = false;
        requests[1].response.contentLength = 300;
        requests[1].response.add(Uint8List(100));
        await requests[1].response.flush();
        final response2 = await clientRequest2Future;
        bool response2StreamSubscriptionIsDone = false;
        final chunks2 = <List<int>>[];
        response2.listen(chunks2.add, onDone: () {
          response2StreamSubscriptionIsDone = true;
        });
        await Future.delayed(const Duration(milliseconds: 100));
        expect(chunks2.length, equals(1));
        expect(chunks2[0].length, equals(100));
        requests[1].response.add(Uint8List(200));
        await requests[1].response.close();
        await Future.delayed(const Duration(milliseconds: 100));
        expect(chunks2.length, equals(2));
        expect(chunks2[1].length, equals(200));
        expect(response2StreamSubscriptionIsDone, isTrue);
        final file2 = VideoServer.instance.optimisticallyGetFile(uri1.resolve('./File2.ext2'))!;
        expect(await file2.exists(), isTrue);
        expect(await file2.length(), equals(300));
        await VideoServer.instance.cleanupCachedDownloadTree(digest);
        expect(await file.exists(), isFalse);
        expect(await file2.exists(), isFalse);
      }
      finally {
        await root.delete(recursive: true);
        fakeServer.close();
        VideoServer.teardownStatic();
      }
    });

    test('incomplete m3u8', () async {
      final root = await Directory.current.createTemp('caching_server_');
      final fakeServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <HttpRequest>[];
      fakeServer.listen((request) {
        requests.add(request);
      });
      try {
        VideoServer.initializeStatic(root, root, bufferOutput: false);
        String? digest;
        bool digestErrored = false;
        VideoServer.instance.startCachingDownload(uri: (Uri.http('localhost:${fakeServer.port}', '/test.m3u8'))).then((h) {
          digest = h;
        }).catchError((e) {
          digestErrored = true;
        });
        await Future.delayed(const Duration(milliseconds: 100));
        expect(requests.length, equals(1));
        requests[0].response.bufferOutput = false;
        requests[0].response.contentLength = 10000;
        requests[0].response.add(Uint8List(1000));
        await requests[0].response.flush();
        try {
          await requests[0].response.close();
          fail('Closing response should have thrown');
        }
        on HttpException {
          // Expected, we are prematurely closing the stream
        }
        await Future.delayed(const Duration(milliseconds: 100));
        expect(digest, isNull);
        expect(digestErrored, isTrue);
      }
      finally {
        await root.delete(recursive: true);
        fakeServer.close();
        VideoServer.teardownStatic();
      }
    });

    test('Sibling incomplete m3u8s', () async {
      final root = await Directory.current.createTemp('caching_server_');
      VideoServer.initializeStatic(root, root, bufferOutput: false);
      final fakeServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = HttpClient();
      final requests = <HttpRequest>[];
      fakeServer.listen((request) {
        requests.add(request);
      });
      try {
        final uri1 = Uri.http('localhost:${fakeServer.port}', '/Dir1/File1.ext1');
        final digestFuture = VideoServer.instance.startCachingDownload(uri: uri1);
        await Future.delayed(const Duration(milliseconds: 100));
        expect(requests.length, equals(1));
        expect(requests[0].requestedUri.path, equals('/Dir1/File1.ext1'));
        requests[0].response.bufferOutput = false;
        requests[0].response.contentLength = 10000;
        requests[0].response.add(Uint8List(1000));
        await requests[0].response.flush();
        final digest = await digestFuture;
        final clientRequest = await client.getUrl(VideoServer.instance.getUri(digest));
        expect(VideoServer.instance.getUri(digest).path, endsWith('.ext1'));
        clientRequest.bufferOutput = false;
        final response = await clientRequest.close();
        await Future.delayed(const Duration(milliseconds: 100));
        expect(response.contentLength, equals(10000));
        expect(response.statusCode, equals(200));
        final chunks = <List<int>>[];
        bool responseStreamSubscriptionIsDone = false;
        response.listen(chunks.add, onDone: () {
          responseStreamSubscriptionIsDone = true;
        });
        await Future.delayed(const Duration(milliseconds: 100));
        expect(chunks.length, equals(1));
        expect(chunks[0].length, equals(1000));
        requests[0].response.add(Uint8List(9000));
        await requests[0].response.flush();
        await Future.delayed(const Duration(milliseconds: 100));
        expect(chunks.length, equals(2));
        expect(chunks[1].length, equals(9000));
        await requests[0].response.close();
        await Future.delayed(const Duration(milliseconds: 100));
        expect(chunks.length, equals(2));
        expect(responseStreamSubscriptionIsDone, isTrue);
        final file = VideoServer.instance.getFile(digest);
        expect(await file.exists(), isTrue);
        expect(await file.length(), equals(10000));
        // Now try a m3u8 file relative to the first URI
        final uri2 = VideoServer.instance.getUri(digest).resolve('./File2.m3u8');
        final clientRequest2 = await client.getUrl(uri2);
        clientRequest2.bufferOutput = false;
        final clientRequest2Future = clientRequest2.close();
        await Future.delayed(const Duration(milliseconds: 100));
        expect(requests.length, equals(2));
        expect(requests[1].requestedUri.path, equals('/Dir1/File2.m3u8'));
        requests[1].response.bufferOutput = false;
        requests[1].response.contentLength = 300;
        requests[1].response.add(Uint8List(100));
        await requests[1].response.flush();
        try {
          await requests[1].response.close();
          fail('Closing response should have thrown');
        }
        on HttpException {
          // Expected, we are prematurely closing the stream
        }
        final response2 = await clientRequest2Future;
        expect(response2.statusCode, equals(502));
        bool response2StreamSubscriptionIsDone = false;
        bool response2StreamSubscriptionIsErrored = false;
        final chunks2 = <List<int>>[];
        response2.listen(chunks2.add, onDone: () {
          response2StreamSubscriptionIsDone = true;
        }, onError: () {
          response2StreamSubscriptionIsErrored = true;
        });
        await Future.delayed(const Duration(milliseconds: 100));
        expect(chunks2.length, equals(0));
        expect(response2StreamSubscriptionIsDone, isTrue);
        expect(response2StreamSubscriptionIsErrored, isFalse);
        final file2 = VideoServer.instance.optimisticallyGetFile(uri1.resolve('./File2.m3u8'))!;
        expect(await file2.exists(), isFalse);
      }
      finally {
        await root.delete(recursive: true);
        fakeServer.close();
        VideoServer.teardownStatic();
      }
    });

    test('interruptOngoingDownload', () async {
      final root = await Directory.current.createTemp('caching_server_');
      final fakeServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = HttpClient();
      final requests = <HttpRequest>[];
      fakeServer.listen((request) {
        requests.add(request);
      });
      try {
        VideoServer.initializeStatic(root, root, bufferOutput: false, insignificantByteThreshold: 0);
        final url = Uri.http('localhost:${fakeServer.port}');
        final digestFuture = VideoServer.instance.startCachingDownload(uri: url, interruptible: true);
        await Future.delayed(const Duration(milliseconds: 100));
        expect(requests[0].method, equals('GET'));
        requests[0].response.bufferOutput = false;
        requests[0].response.contentLength = 10000;
        requests[0].response.add(Uint8List(1000));
        await requests[0].response.flush();
        final digest = await digestFuture;
        final clientRequest = await client.getUrl(VideoServer.instance.getUri(digest));
        clientRequest.bufferOutput = false;
        final response = await clientRequest.close();
        await Future.delayed(const Duration(milliseconds: 100));
        expect(response.contentLength, equals(10000));
        final chunks = <List<int>>[];
        bool responseStreamSubscriptionIsErrored = false;
        bool responseStreamSubscriptionIsDone = false;
        response.listen(chunks.add, onError: (e) {
          responseStreamSubscriptionIsErrored = true;
        }, onDone: () {
          responseStreamSubscriptionIsDone = true;
        });
        await Future.delayed(const Duration(milliseconds: 100));
        expect(chunks.length, equals(1));
        expect(chunks[0].length, equals(1000));
        await VideoServer.instance.interruptOngoingDownloadFromUri(url);
        await Future.delayed(const Duration(milliseconds: 200));
        requests[0].response.add(Uint8List(9000));
        await requests[0].response.close();
        await Future.delayed(const Duration(milliseconds: 200));
        expect(chunks.length, equals(1));
        expect(responseStreamSubscriptionIsDone, isTrue);
        expect(responseStreamSubscriptionIsErrored, isTrue);
        await Future.delayed(const Duration(milliseconds: 200));
        final digestFuture2 = VideoServer.instance.startCachingDownload(uri: url, interruptible: true);
        await Future.delayed(const Duration(milliseconds: 100));
        expect(requests.length, equals(2));
        expect(requests[1].method, equals('HEAD'));
        requests[1].response.bufferOutput = false;
        requests[1].response.contentLength = 10000;
        await requests[1].response.close();
        await Future.delayed(const Duration(milliseconds: 100));
        expect(requests.length, equals(3));
        expect(requests[2].method, equals('GET'));
        expect(requests[2].headers.value(HttpHeaders.rangeHeader), equals('bytes=1000-'));
        requests[2].response.bufferOutput = false;
        requests[2].response.contentLength = 9000;
        requests[2].response.add(Uint8List(1));
        await requests[2].response.flush();
        final digest2 = await digestFuture2;
        final clientRequest2 = await client.getUrl(VideoServer.instance.getUri(digest2));
        clientRequest2.bufferOutput = false;
        final response2 = await clientRequest2.close();
        await Future.delayed(const Duration(milliseconds: 100));
        expect(response2.contentLength, equals(10000));
        final chunks2 = <List<int>>[];
        bool response2StreamSubscriptionIsErrored = false;
        bool response2StreamSubscriptionIsDone = false;
        response2.listen(chunks2.add, onError: (e) {
          response2StreamSubscriptionIsErrored = true;
        }, onDone: () {
          response2StreamSubscriptionIsDone = true;
        });
        await Future.delayed(const Duration(milliseconds: 100));
        expect(chunks2.length, equals(1));
        expect(chunks2[0].length, equals(1001));
        requests[2].response.add(Uint8List(8999));
        await requests[2].response.close();
        await Future.delayed(const Duration(milliseconds: 100));
        expect(chunks2.length, equals(2));
        expect(chunks2[1].length, equals(8999));
        expect(response2StreamSubscriptionIsDone, isTrue);
        expect(response2StreamSubscriptionIsErrored, isFalse);
      }
      finally {
        await root.delete(recursive: true);
        fakeServer.close();
        VideoServer.teardownStatic();
      }
    });
    test('reusingEndProxyChunks', () async {
      final root = await Directory.current.createTemp('caching_server_');
      final fakeServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = HttpClient();
      final requests = <HttpRequest>[];
      fakeServer.listen((request) {
        requests.add(request);
      });
      try {
        VideoServer.initializeStatic(root, root, bufferOutput: false, insignificantByteThreshold: 0);
        final url = Uri.http('localhost:${fakeServer.port}');
        final digestFuture = VideoServer.instance.startCachingDownload(uri: url, interruptible: true);
        await Future.delayed(const Duration(milliseconds: 100));
        expect(requests[0].method, equals('GET'));
        requests[0].response.bufferOutput = false;
        requests[0].response.contentLength = 10000;
        requests[0].response.add(Uint8List(1000));
        await requests[0].response.flush();
        final digest = await digestFuture;
        final clientRequest = await client.getUrl(VideoServer.instance.getUri(digest));
        clientRequest.bufferOutput = false;
        final response = await clientRequest.close();
        await Future.delayed(const Duration(milliseconds: 100));
        expect(response.contentLength, equals(10000));
        final chunks = <List<int>>[];
        bool responseStreamSubscriptionIsErrored = false;
        bool responseStreamSubscriptionIsDone = false;
        response.listen(chunks.add, onError: (e) {
          responseStreamSubscriptionIsErrored = true;
        }, onDone: () {
          responseStreamSubscriptionIsDone = true;
        });
        await Future.delayed(const Duration(milliseconds: 100));
        expect(chunks.length, equals(1));
        expect(chunks[0].length, equals(1000));
        final clientRequestEnd = await client.getUrl(VideoServer.instance.getUri(digest));
        clientRequestEnd.bufferOutput = false;
        clientRequestEnd.headers.set(HttpHeaders.rangeHeader, 'bytes=9000-');
        final responseEndFuture = clientRequestEnd.close();
        await Future.delayed(const Duration(milliseconds: 100));
        expect(requests[1].method, equals('GET'));
        expect(requests[1].headers.value(HttpHeaders.rangeHeader), 'bytes=9000-');
        requests[1].response.bufferOutput = false;
        requests[1].response.statusCode = HttpStatus.partialContent;
        requests[1].response.contentLength = 1000;
        requests[1].response.add(Uint8List(1000));
        await requests[1].response.close();
        final responseEnd = await responseEndFuture;
        expect(responseEnd.contentLength, equals(1000));
        final chunksEnd = <List<int>>[];
        bool responseEndStreamSubscriptionIsErrored = false;
        bool responseEndStreamSubscriptionIsDone = false;
        responseEnd.listen(chunksEnd.add, onError: (e) {
          responseEndStreamSubscriptionIsErrored = true;
        }, onDone: () {
          responseEndStreamSubscriptionIsDone = true;
        });
        await Future.delayed(const Duration(milliseconds: 100));
        expect(chunks.length, equals(1));
        expect(chunksEnd.length, equals(1));
        expect(chunksEnd[0].length, equals(1000));
        expect(responseEndStreamSubscriptionIsErrored, isFalse);
        expect(responseEndStreamSubscriptionIsDone, isTrue);
        final clientRequestEnd2 = await client.getUrl(VideoServer.instance.getUri(digest));
        clientRequestEnd2.bufferOutput = false;
        clientRequestEnd2.headers.set(HttpHeaders.rangeHeader, 'bytes=9500-');
        // Should be no upstream request here, and it's served directly from cache
        final responseEnd2 = await clientRequestEnd2.close();
        expect(responseEnd2.contentLength, equals(500));
        final chunksEnd2 = <List<int>>[];
        bool responseEnd2StreamSubscriptionIsErrored = false;
        bool responseEnd2StreamSubscriptionIsDone = false;
        responseEnd2.listen(chunksEnd2.add, onError: (e) {
          responseEnd2StreamSubscriptionIsErrored = true;
        }, onDone: () {
          responseEnd2StreamSubscriptionIsDone = true;
        });
        await Future.delayed(const Duration(milliseconds: 100));
        expect(chunks.length, equals(1));
        expect(chunksEnd.length, equals(1));
        expect(chunksEnd2.length, equals(1));
        expect(chunksEnd2[0].length, equals(500));
        expect(responseEnd2StreamSubscriptionIsErrored, isFalse);
        expect(responseEnd2StreamSubscriptionIsDone, isTrue);
        requests[0].response.add(Uint8List(8000));
        await requests[0].response.flush();
        await Future.delayed(const Duration(milliseconds: 100));
        expect(chunks.length, equals(3));
        expect(chunks[1].length, equals(8000));
        expect(chunks[2].length, equals(1000));
        expect(responseStreamSubscriptionIsErrored, isFalse);
        expect(responseStreamSubscriptionIsDone, isTrue);
      }
      finally {
        await root.delete(recursive: true);
        fakeServer.close();
        VideoServer.teardownStatic();
      }
    });
  });

  group('PriorityQueue', () {
    test('basic', () async {
      final q = PriorityQueue<(String, String), String>(groupKeyer: (k) => k.$1);
      // Both should start (start in parallel mode)
      const a = ('1', 'a');
      const b = ('1', 'b');
      await q.start(a);
      await q.start(b);
      bool d1a = false;
      q.delay(a, const Duration(seconds: 1)).then((_) => d1a = true);
      bool d2b = false;
      q.delay(b, const Duration(seconds: 2)).then((_) => d2b = true);
      const c = ('1', 'c');
      bool sc = false;
      q.start(c).then((_) => sc = true);
      // The delay should be extended
      await Future.delayed(const Duration(milliseconds: 1100));
      expect(d1a, isFalse);
      expect(d2b, isFalse);
      expect(sc, isFalse);
      await Future.delayed(const Duration(seconds: 1));
      expect(d1a, isTrue);
      expect(d2b, isFalse);
      expect(sc, isFalse);
      await q.end(a);
      await Future.delayed(Duration.zero);
      expect(d2b, isTrue);
      expect(sc, isFalse);
      await q.end(b);
      await Future.delayed(Duration.zero);
      expect(sc, isTrue);
      await q.end(c);
      // Should be back in parallel mode
      const d = ('1', 'd');
      const e = ('1', 'e');
      const f = ('1', 'f');
      await q.start(d);
      await q.start(e);
      await q.end(d);
      await q.start(f);
      await q.end(e);
      await q.end(f);
      q.dispose();
    });
  });

  test('FileBasename', () {
    expect(FileBasename.get('asdf///'), 'asdf');
    expect(FileBasename.get('/'), '/');
    expect(FileBasename.get('a//'), 'a');
    expect(FileBasename.get('asdf'), 'asdf');
    expect(FileBasename.get('/f/g/b/c'), 'c');
  });

  test('debounce', () async {
    int retval = 0;
    final debouncer = Debouncer1((int x) async {
      final r = retval;
      await Future.delayed(Duration(milliseconds: x));
      return r;
    });
    final f1 = debouncer.debounce(100);
    retval = 1;
    await Future.delayed(const Duration(milliseconds: 50));
    final f2 = debouncer.debounce(100);
    await Future.delayed(const Duration(milliseconds: 51));
    final v1 = await f1;
    expect(v1, equals(0));
    final v2 = await f2;
    expect(v2, equals(0));
    final v3 = await debouncer.debounce(100);
    expect(v3, equals(1));
  });

  test('extractHtmlError', () {
    const html = '''
<html xmlns="http://www.w3.org/1999/xhtml"><head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<meta name="keywords" content="">
<meta name="robots" content="noarchive">
<meta http-equiv="pragma" content="no-cache">
<meta http-equiv="expires" content="-1">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>4chan - Error</title>
<style type="text/css">html{color:#000}blockquote,body,code,dd,div,dl,dt,fieldset,form,h1,h2,h3,h4,h5,h6,input,legend,li,ol,p,pre,td,textarea,th,ul{margin:0;padding:0}table{border-collapse:collapse;border-spacing:0}fieldset,img{border:0}address,caption,cite,code,dfn,em,strong,th,var{font-style:normal;font-weight:400}li{list-style:none}caption,th{text-align:left}h1,h2,h3,h4,h5,h6{font-size:100%;font-weight:400}q:after,q:before{content:''}abbr,acronym{border:0;font-variant:normal}sup{vertical-align:text-top}sub{vertical-align:text-bottom}input,select,textarea{font-family:inherit;font-size:inherit;font-weight:inherit}legend{color:#000}body{font:13px / 1.231 arial,helvetica,clean,sans-serif!important;font-size:*small}table{font:100%}code,kbd,pre,samp,tt{font-family:monospace;font-size:*108%;line-height:100%}body{text-align:center}#ft{clear:both}#doc{margin:auto;text-align:left;width:57.69em;width:*56.301em;min-width:750px}#logo{background:url(data:image/png;base64,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%3D) top left no-repeat;font-size:1px;line-height:0;height:120px;overflow:hidden;margin:0 auto;width:300px}#logo h1{margin-left:-200px;width:100%;height:100%;display:block}#logo h1 a{width:100%;height:100%;display:block;padding-right:150px}#hd{margin-bottom:0}br.clear-bug{height:0;line-height:0;clear:both}.box-outer{border:1px solid;zoom:100%;margin-bottom:.5em;padding-bottom:.5em}.boxbar{padding-left:.5em;line-height:2em}.boxcontent{padding:.25em .5em 0}#copyright{text-align:center;margin-top:0;margin-bottom:1em}.boxbar{position:relative;zoom:100%}#ft,.boxcontent{font-size:93%}h1{font-family:Tahoma,Bitstream Vera Sans;font-size:197%;font-weight:700}h2{font-size:131%;font-weight:700}h3{font-size:100%;font-weight:700}#copyright{font-size:11px}h1 a{color:#800;text-decoration:none}html{background:#ffe}body{background:url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAADICAIAAACmkByiAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAFxJREFUKJFj+ndtPRMDAwMSZmRiYGTAFEPmM2IRg/EZcenBop4otYw47MSinxw16HYRZQYBPfjkUdRims1ItNmE/EOcfSTLEx2GBNTgSkc41eGLF3S7cKQr0tM2AO8LBH073E/fAAAAAElFTkSuQmCC) top repeat-x #ffe;color:#800}.boxbar{background:#fca;color:#800}.top-box{background:#fff}dl,ol,ul{margin:0}ol li{list-style:decimal}em{font-style:italic}strong{font-weight:700}.boxcontent h3{font-size:116%}.boxcontent h4{font-weight:700}.boxcontent{color:#000;line-height:1.5em}ol,ul{margin-left:0}.boxcontent p{margin:.5em 0}hr{border:0;color:#800;background:#800;height:1px;margin-top:0;margin-bottom:1em}ul li{list-style-type:none}h2{text-align:center}#error-blurb{text-align:center;padding:0 .5em}.boxcontent img{display:block;margin:auto}.cloudflare.cf-captcha{margin:0 auto!important}@media only screen and (max-width:480px){#doc{width:auto;min-width:0}.boxcontent img{max-width:100%}}</style>



<style>html {filter: invert(1) hue-rotate(180deg) contrast(0.8);} img, video, picture, canvas, iframe, embed {filter: invert(1) hue-rotate(180deg);}</style></head>
<body>
<div id="doc">
<div id="hd">
<div id="logo">
<h1><a href="//www.4chan.org/" title="Home">4chan</a></h1>
</div>
</div>
<div id="bd">
<div class="box-outer top-box">
<div class="box-inner">
<div class="boxbar">
<h2>Error</h2>
</div>
<div class="boxcontent" style="text-align: center;">
<p style="font-size: larger;">Our server encountered a problem while processing your request.</p>
<hr>
<p></p><div class="cf-error-details cf-error-502">
  <h1>Bad gateway</h1>
  <p>The web server reported a bad gateway error.</p>
  <ul>
    <li>Ray ID: 95702fb1fb6c0048</li>
    <li>Your IP address: 154.198.114.180</li>
    <li>Error reference number: 502</li>
    <li>Cloudflare Location: Karachi</li>
  </ul>
</div>
<p></p>
</div>
</div>
</div>
</div>
<div id="ft">
<br class="clear-bug">
<div id="copyright">Copyright © 2003-2015 4chan community support LLC. All rights reserved.</div>
</div>
</div>



</body></html>
''';
    expect(extractHtmlError(html), '''Bad gateway
 The web server reported a bad gateway error.
 Ray ID: 95702fb1fb6c0048
 Your IP address: 154.198.114.180
 Error reference number: 502
 Cloudflare Location: Karachi''');
  });
}
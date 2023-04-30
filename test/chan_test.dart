import 'dart:io';
import 'dart:math';

import 'package:chan/models/thread.dart';
import 'package:chan/services/compress_html.dart';
import 'package:chan/services/streaming_mp4.dart';
import 'package:chan/sites/lainchan.dart';
import 'package:flutter/foundation.dart';
import 'package:test/test.dart';
import 'package:chan/util.dart';

bool id(bool x) => x;

void main() {
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

  group('Lainchan RegExes', () {
    test('decodeUrl', () {
      expect(SiteLainchan.decodeGenericUrl('example.com', 'https://example.com/'), null);
      expect(SiteLainchan.decodeGenericUrl('example.com', 'https://example.com/board/'), BoardThreadOrPostIdentifier('board'));
      expect(SiteLainchan.decodeGenericUrl('example.com', 'https://example.com/board/0.json'), null);
      expect(SiteLainchan.decodeGenericUrl('example.com', 'https://example.com/board/res/1234.html'), BoardThreadOrPostIdentifier('board', 1234));
      expect(SiteLainchan.decodeGenericUrl('example.com', 'https://example.com/board/res/1234.json'), null);
      expect(SiteLainchan.decodeGenericUrl('example.com', 'https://example.com/board/res/1234.html#q1235'), BoardThreadOrPostIdentifier('board', 1234, 1235));
      expect(SiteLainchan.decodeGenericUrl('example.com', 'https://example.com/board/res/1234.html#q1235&also=yes'), BoardThreadOrPostIdentifier('board', 1234, 1235));
    });
  });

  group('HTML compressor', () {
    test('compress', () {
      const html = '<a href="https://example.com">https://example.com</a><br><span>&gt;&gt;12345678</span>';
      final compressed = compressHTML(html);
      expect(compressed.html, '<a><b></b></a><br></br><c><d></d></c>');
      expect(compressed.decompressTranslation(compressed.html), html);
    });
  });

  group('Caching server', () {
    test('normal', () async {
      final root = await Directory.current.createTemp('caching_server_');
      VideoServer.initializeStatic(root, port: 4071, bufferOutput: false);
      final fakeServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = HttpClient();
      final requests = <HttpRequest>[];
      fakeServer.listen((request) {
        requests.add(request);
      });
      try {
        final hashFuture = VideoServer.instance.startCachingDownload(uri: (Uri.http('localhost:${fakeServer.port}')));
        await Future.delayed(const Duration(milliseconds: 100));
        expect(requests.length, equals(1));
        requests[0].response.bufferOutput = false;
        requests[0].response.contentLength = 10000;
        requests[0].response.add(Uint8List(1000));
        await requests[0].response.flush();
        final hash = await hashFuture;
        final clientRequest = await client.getUrl(VideoServer.instance.getUri(hash));
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
        final file = VideoServer.instance.getFile(hash);
        expect(await file.exists(), isTrue);
        expect(await file.length(), equals(10000));
        // Try a second request, it shouldn't hit the original server, and should return all in one chunk.
        final clientRequest2 = await client.getUrl(VideoServer.instance.getUri(hash));
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
        final clientRequest3 = await client.getUrl(VideoServer.instance.getUri(hash));
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

    test('status code', () async {
      final root = await Directory.current.createTemp('caching_server_');
      VideoServer.initializeStatic(root, port: 4071, bufferOutput: false);
      final fakeServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = HttpClient();
      final requests = <HttpRequest>[];
      fakeServer.listen((request) {
        requests.add(request);
      });
      try {
        final hashFuture = VideoServer.instance.startCachingDownload(uri: (Uri.http('localhost:${fakeServer.port}')));
        await Future.delayed(const Duration(milliseconds: 100));
        expect(requests.length, equals(1));
        requests[0].response.bufferOutput = false;
        requests[0].response.statusCode = 404;
        requests[0].response.contentLength = 10000;
        requests[0].response.add(Uint8List(1000));
        await requests[0].response.flush();
        final hash = await hashFuture;
        final clientRequest = await client.getUrl(VideoServer.instance.getUri(hash));
        clientRequest.bufferOutput = false;
        final response = await clientRequest.close();
        await Future.delayed(const Duration(milliseconds: 100));
        expect(response.contentLength, equals(10000));
        expect(response.statusCode, equals(404));
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
        final file = VideoServer.instance.getFile(hash);
        expect(await file.exists(), isTrue);
        expect(await file.length(), equals(10000));
        // Try again
        final clientRequest2 = await client.getUrl(VideoServer.instance.getUri(hash));
        clientRequest2.bufferOutput = false;
        final response2 = await clientRequest2.close();
        chunks.clear();
        responseStreamSubscriptionIsDone = false;
        response2.listen(chunks.add, onDone: () {
          responseStreamSubscriptionIsDone = true;
        });
        await Future.delayed(const Duration(milliseconds: 100));
        expect(response.contentLength, equals(10000));
        expect(response.statusCode, equals(404));
        await Future.delayed(const Duration(milliseconds: 100));
        expect(chunks.length, equals(1));
        expect(chunks[0].length, equals(10000));
        expect(responseStreamSubscriptionIsDone, isTrue);
        expect(requests.length, equals(1));
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
        VideoServer.initializeStatic(root, port: 4071, bufferOutput: false);
        final hashFuture = VideoServer.instance.startCachingDownload(uri: (Uri.http('localhost:${fakeServer.port}')));
        await Future.delayed(const Duration(milliseconds: 100));
        expect(requests.length, equals(1));
        requests[0].response.bufferOutput = false;
        requests[0].response.contentLength = 10000;
        requests[0].response.add(Uint8List(1000));
        await requests[0].response.flush();
        final hash = await hashFuture;
        final clientRequest = await client.getUrl(VideoServer.instance.getUri(hash));
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
        }
        on HttpException {
          // Expected, we are prematurely closing the stream
        }
        await Future.delayed(const Duration(milliseconds: 200));
        expect(chunks.length, equals(1));
        expect(responseStreamSubscriptionIsErrored, isTrue);
        final file = VideoServer.instance.getFile(hash);
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
      VideoServer.initializeStatic(root, port: 4071, bufferOutput: false);
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
        final hashFuture = VideoServer.instance.startCachingDownload(uri: (Uri.http('localhost:${fakeServer.port}')));
        await Future.delayed(const Duration(milliseconds: 100));
        expect(requests.length, equals(1));
        requests[0].response.bufferOutput = false;
        requests[0].response.contentLength = kLength;
        requests[0].response.add(buffer.sublist(0, 10));
        await requests[0].response.flush();
        final hash = await hashFuture;
        final clientRequest = await client.getUrl(VideoServer.instance.getUri(hash));
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
        final file = VideoServer.instance.getFile(hash);
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
  });
}
import 'package:chan/models/thread.dart';
import 'package:chan/services/compress_html.dart';
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
}
import 'package:chan/models/thread.dart';
import 'package:chan/services/compress_html.dart';
import 'package:chan/sites/lainchan.dart';
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
      expect(compressed.html, '<a><b></b></a><br><c><d></d></c>');
      expect(compressed.decompressTranslation(compressed.html), html);
    });
  });
}
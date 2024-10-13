import 'package:chan/sites/lainchan.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:test/test.dart';

void main() {
	group('lainchan', () {
		test('cross-site quotelinks are preserved', () {
			final r = SiteLainchan.makeSpan('', 0, '<a href="/board/res/1.html#2">quotelink</a><a href="https://otherimageboard.com/board/res/1.html#2">cross-site link</a>');
			expect(r.children, hasLength(2));
			final quotelink = r.children[0] as PostQuoteLinkSpan;
			expect(quotelink.postId, 2);
			expect(quotelink.threadId, 1);
			expect(quotelink.board, 'board');
			final link = r.children[1] as PostLinkSpan;
			expect(link.url, 'https://otherimageboard.com/board/res/1.html#2');
			expect(link.name, 'cross-site link');
		});
	});
}

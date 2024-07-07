import 'package:chan/sites/4chan.dart';
import 'package:chan/sites/reddit.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:test/test.dart';

void main() {
	group('LooseUrlLinkifier', () {
		test('raw link', () {
			final r = SiteReddit.makeSpan('', 0, 'https://www.example.com/image.jpg');
			final link = r.children.single as PostLinkSpan;
			expect(link.url, 'https://www.example.com/image.jpg');
		});

		test('raw wikipedia link', () {
			final r = SiteReddit.makeSpan('', 0, 'https://en.wikipedia.org/wiki/ANSI_(disambiguation)');
			final link = r.children.single as PostLinkSpan;
			expect(link.url, 'https://en.wikipedia.org/wiki/ANSI_(disambiguation)');
		});

		test('quoted link', () {
			final r = SiteReddit.makeSpan('', 0, '<img src="https://www.example.com/image.jpg">');
			final img = r.children.single as PostInlineImageSpan;
			expect(img.src, 'https://www.example.com/image.jpg');
		});

		test('html link', () {
			final r = SiteReddit.makeSpan('', 0, '<a href="https://www2.example.com">example1.com</a>');
			final link = r.children.single as PostLinkSpan;
			expect(link.url, 'https://www2.example.com');
			expect(link.name, 'example1.com');
		});

		test('markdown link', () {
			final r = SiteReddit.makeSpan('', 0, '[example1.com](https://www2.example.com)');
			final link = r.children.single as PostLinkSpan;
			expect(link.url, 'https://www2.example.com');
			expect(link.name, 'example1.com');
		});

		test('escapes in description', () {
			final r = SiteReddit.makeSpan('', 0, '[https://www.foreignaffairs.com/united-states/sources-american-power-biden-jake-sullivan?check\\_logged\\_in=1&utm\\_medium=promo\\_email&utm\\_source=lo\\_flows&utm\\_campaign=registered\\_user\\_welcome&utm\\_term=email\\_1&utm\\_content=20240225](https://www.foreignaffairs.com/united-states/sources-american-power-biden-jake-sullivan?check_logged_in=1&utm_medium=promo_email&utm_source=lo_flows&utm_campaign=registered_user_welcome&utm_term=email_1&utm_content=20240225)');
			final link = r.children.single as PostLinkSpan;
			expect(link.url, 'https://www.foreignaffairs.com/united-states/sources-american-power-biden-jake-sullivan?check_logged_in=1&utm_medium=promo_email&utm_source=lo_flows&utm_campaign=registered_user_welcome&utm_term=email_1&utm_content=20240225');
			expect(link.name, 'https://www.foreignaffairs.com/united-states/sources-american-power-biden-jake-sullivan?check_logged_in=1&utm_medium=promo_email&utm_source=lo_flows&utm_campaign=registered_user_welcome&utm_term=email_1&utm_content=20240225');
		});

		test('markdown-like syntax in link', () {
			final r = SiteReddit.makeSpan('', 0, 'https://en.wikipedia.org/wiki/NLRB_v._Jones_%26_Laughlin_Steel_Corp');
			final link = r.children.single as PostLinkSpan;
			expect(link.url, 'https://en.wikipedia.org/wiki/NLRB_v._Jones_&_Laughlin_Steel_Corp');
		});

		test('wikipedia url with single quote', () {
			final r = Site4Chan.makeSpan('', 0, 'https://en.wikipedia.org/wiki/Bachelor\'s_Day_(tradition)');
			final link = r.children.single as PostLinkSpan;
			expect(link.url, 'https://en.wikipedia.org/wiki/Bachelor\'s_Day_(tradition)');
		});
	});
}
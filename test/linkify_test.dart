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

		test('markdown link with parentheses', () {
			final r = SiteReddit.makeSpan('', 0, '[example1.com/asdf(2)](https://www2.example.com/asdf(2))');
			final link = r.children.single as PostLinkSpan;
			expect(link.url, 'https://www2.example.com/asdf(2)');
			expect(link.name, 'example1.com/asdf(2)');
		});

		test('markdown link with parentheses 2', () {
			final r = SiteReddit.makeSpan('', 0, '[On The Beaten Trail (reddit.com)](https://www.reddit.com/r/DesirePath/)');
			final link = r.children.single as PostLinkSpan;
			expect(link.url, 'https://www.reddit.com/r/DesirePath/');
			expect(link.name, 'On The Beaten Trail (reddit.com)');
		});

		test('markdown link 2', () {
			final r = SiteReddit.makeSpan('', 0, '[second reddit post](https://www.reddit.com/r/toronto/s/tNWH3wwQsU)');
			final link = r.children.single as PostLinkSpan;
			expect(link.url, 'https://www.reddit.com/r/toronto/s/tNWH3wwQsU');
			expect(link.name, 'second reddit post');
		});

		test('markdown link followed by comma', () {
			final r = SiteReddit.makeSpan('', 0, '[the majority of 750+ scorers](https://www.brookings.edu/articles/race-gaps-in-sat-scores-highlight-inequality-and-hinder-upward-mobility/),');
			expect(r.children, hasLength(2));
			final link = r.children[0] as PostLinkSpan;
			expect(link.url, 'https://www.brookings.edu/articles/race-gaps-in-sat-scores-highlight-inequality-and-hinder-upward-mobility/');
			expect(link.name, 'the majority of 750+ scorers');
			final comma = r.children[1] as PostTextSpan;
			expect(comma.text, ',');
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
			expect(link.url, 'https://en.wikipedia.org/wiki/NLRB_v._Jones_%26_Laughlin_Steel_Corp');
		});

		test('wikipedia url with single quote', () {
			final r = Site4Chan.makeSpan('', 0, 'https://en.wikipedia.org/wiki/Bachelor\'s_Day_(tradition)');
			final link = r.children.single as PostLinkSpan;
			expect(link.url, 'https://en.wikipedia.org/wiki/Bachelor\'s_Day_(tradition)');
		});

		test('brackets in link', () {
			final r = Site4Chan.makeSpan('', 0, 'https://datausa.io/profile/geo/miami-fl/#:~:text=The%205%20largest%20ethnic%20groups,(Hispanic)%20(6.18%25)');
			final link = r.children.single as PostLinkSpan;
			expect(link.url, 'https://datausa.io/profile/geo/miami-fl/#:~:text=The%205%20largest%20ethnic%20groups,(Hispanic)%20(6.18%25)');
		});

		test('Reddit complex markdownification', () {
			final r = SiteReddit.makeSpan('', 0, 'https://www.toronto.ca/community-people/housing-shelter/rental-housing-tenant-information/rental-housing-standards/#:\\~:text=Property%20Cleanliness%20(Chapter%20629%2C%20Section,are%20health%20or%20fire%20hazards');
			final link = r.children.single as PostLinkSpan;
			expect(link.url, 'https://www.toronto.ca/community-people/housing-shelter/rental-housing-tenant-information/rental-housing-standards/#:~:text=Property%20Cleanliness%20(Chapter%20629%2C%20Section,are%20health%20or%20fire%20hazards');
			expect(link.name, 'www.toronto.ca/community-people/housing-shelter/rental-housing-tenant-information/rental-housing-standards/#:~:text=Property%20Cleanliness%20(Chapter%20629%2C%20Section,are%20health%20or%20fire%20hazards');
		});

		test('slash needed to make a link', () {
			final r = SiteReddit.makeSpan('', 0, '1.to(5)');
			expect(r.children, hasLength(2));
			final link = r.children[0] as PostLinkSpan;
			expect(link.url, 'https://1.to');
			expect(link.name, '1.to');
			final text = r.children[1] as PostTextSpan;
			expect(text.text, '(5)');
		});

		test('link inside code block should not be linkified', () {
			final r = SiteReddit.makeSpan('', 0, '```1.to```');
			final code = r.children.single as PostCodeSpan;
			expect(code.text, '1.to');
		});

		test('link after code block', () {
			final r = SiteReddit.makeSpan('', 0, '```code```1.to');
			expect(r.children, hasLength(2));
			final code = r.children[0] as PostCodeSpan;
			expect(code.text, 'code');
			final link = r.children[1] as PostLinkSpan;
			expect(link.url, 'https://1.to');
			expect(link.name, '1.to');
		});
	});
}
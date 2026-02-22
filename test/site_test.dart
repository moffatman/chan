import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/sites/lainchan.dart';
import 'package:chan/sites/reddit.dart';
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
	group('reddit', () {
		test('keeping deleted post text', () async {
			await Persistence.initializeHive(forTesting: true);
			final time1 = DateTime(2000);
			final time2 = DateTime(2001);
			const board = 'board';
			final op = Post(
				board: board,
				text: 'OP text',
				name: '',
				time: time1,
				threadId: 1,
				id: 1,
				spanFormat: PostSpanFormat.reddit,
				attachments_: []
			);
			final post2v1 = Post(
				board: board,
				text: 'Reply text',
				name: 'username',
				time: time2,
				threadId: 1,
				id: 2,
				spanFormat: PostSpanFormat.reddit,
				attachments_: []
			);
			final threadv1 = Thread(
				posts_: [op, post2v1],
				replyCount: 2,
				imageCount: 0,
				id: op.threadId,
				board: board,
				title: 'OP title',
				isSticky: false,
				time: DateTime.now(),
				attachments: op.attachments_
			);
			final post2v2 = Post(
				board: board,
				text: '[deleted] or something',
				name: '[removed] or something',
				time: time2,
				threadId: 1,
				id: 2,
				spanFormat: PostSpanFormat.reddit,
				attachments_: [],
				isDeleted: true
			);
			final threadv2 = Thread(
				posts_: [op, post2v2],
				replyCount: 2,
				imageCount: 0,
				id: op.threadId,
				board: board,
				title: 'OP title',
				isSticky: false,
				time: DateTime.now(),
				attachments: op.attachments_
			);
			final reddit = SiteReddit(
				overrideUserAgent: null,
				addIntrospectedHeaders: false,
				archives: [],
				imageHeaders: const {},
				videoHeaders: const {}
			);
			expect(threadv2.mergePosts(threadv1, threadv1.posts, reddit), isTrue);
			expect(threadv2.posts[1].text, post2v1.text);
			expect(threadv2.posts[1].name, post2v1.name);
			expect(threadv2.posts[1].isDeleted, isTrue);
		});
	});
}

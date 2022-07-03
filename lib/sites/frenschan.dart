import 'package:chan/models/thread.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/soyjak.dart';
import 'package:chan/util.dart';
import 'package:html/parser.dart';

class SiteFrenschan extends SiteSoyjak {
	SiteFrenschan({
		required String baseUrl,
		required String name,
		List<ImageboardSiteArchive> archives = const []
	}) : super(
		baseUrl: baseUrl,
		name: name,
		archives: archives
	);

	@override
	String? get imageThumbnailExtension => null;

	@override
	Uri get iconUrl => Uri.https(baseUrl, '/favicon.ico');

	@override
	String get siteType => 'frenschan';

	@override
	Future<Thread> getThread(ThreadIdentifier thread) async {
		final broken = await super.getThread(thread);
		final response = await client.get(Uri.https(baseUrl, '/${thread.board}/res/${thread.id}.html').toString());
		final document = parse(response.data);
		final thumbnailUrls = document.querySelectorAll('img.post-image').map((e) => e.attributes['src']).toList();
		for (final post in broken.posts_) {
			if (post.attachment == null) {
				continue;
			}
			final thumbnailUrl = thumbnailUrls.tryFirstWhere((u) => u?.contains(post.attachment!.id.toString()) ?? false);
			if (thumbnailUrl != null) {
				post.attachment?.thumbnailUrl = Uri.https(baseUrl, thumbnailUrl);
			}
		}
		if (broken.posts_.first.attachment != null) {
			broken.attachment?.thumbnailUrl = broken.posts_.first.attachment!.thumbnailUrl;
		}
		return broken;
	}

	@override
	Future<List<Thread>> getCatalog(String board) async {
		final broken = await super.getCatalog(board);
		final response = await client.get(Uri.https(baseUrl, '/$board/catalog.html').toString());
		final document = parse(response.data);
		final thumbnailUrls = document.querySelectorAll('img.thread-image').map((e) => e.attributes['src']).toList();
		for (final thread in broken) {
			if (thread.attachment == null) {
				continue;
			}
			final thumbnailUrl = thumbnailUrls.tryFirstWhere((u) => u?.contains(thread.attachment!.id.toString()) ?? false);
			if (thumbnailUrl != null) {
				thread.attachment?.thumbnailUrl = Uri.https(baseUrl, thumbnailUrl);
			}
		}
		return broken;
	}

	@override
	CaptchaRequest getCaptchaRequest(String board, [int? threadId]) {
		return SecurimageCaptchaRequest(
			challengeUrl: Uri.https(baseUrl, '/securimage.php')
		);
	}

	@override
	bool operator ==(Object other) => (other is SiteFrenschan) && (other.name == name) && (other.baseUrl == baseUrl);

	@override
	int get hashCode => Object.hash(name, baseUrl);
	
	@override
	String get defaultUsername => 'Fren';
}
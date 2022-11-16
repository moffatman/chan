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
	Future<Thread> getThread(ThreadIdentifier thread, {ThreadVariant? variant}) async {
		final broken = await super.getThread(thread);
		final response = await client.get(Uri.https(baseUrl, '/${thread.board}/res/${thread.id}.html').toString());
		final document = parse(response.data);
		final thumbnailUrls = document.querySelectorAll('img.post-image').map((e) => e.attributes['src']).toList();
		for (final attachment in broken.posts_.expand((p) => p.attachments)) {
			final thumbnailUrl = thumbnailUrls.tryFirstWhere((u) => u?.contains(attachment.id) ?? false);
			if (thumbnailUrl != null) {
				attachment.thumbnailUrl = Uri.https(baseUrl, thumbnailUrl);
			}
		}
		// Copy corrected thumbnail URLs to thread from posts_.first
		for (final a in broken.posts_.first.attachments) {
			broken.attachments.tryFirstWhere((a2) => a.id == a2.id)?.thumbnailUrl = a.thumbnailUrl;
		}
		return broken;
	}

	@override
	Future<List<Thread>> getCatalog(String board, {CatalogVariant? variant}) async {
		final broken = await super.getCatalog(board);
		final response = await client.get(Uri.https(baseUrl, '/$board/catalog.html').toString());
		final document = parse(response.data);
		final thumbnailUrls = document.querySelectorAll('img.thread-image').map((e) => e.attributes['src']).toList();
		for (final attachment in broken.expand((t) => t.attachments)) {
			final thumbnailUrl = thumbnailUrls.tryFirstWhere((u) => u?.contains(attachment.id.toString()) ?? false);
			if (thumbnailUrl != null) {
				attachment.thumbnailUrl = Uri.https(baseUrl, thumbnailUrl);
			}
		}
		return broken;
	}

	@override
	Future<CaptchaRequest> getCaptchaRequest(String board, [int? threadId]) async {
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
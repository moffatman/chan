import 'package:chan/models/thread.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/soyjak.dart';
import 'package:chan/util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart';

class SiteFrenschan extends SiteSoyjak {
	SiteFrenschan({
		required super.baseUrl,
		required super.name,
		super.archives = const [],
		super.faviconPath = '/favicon.ico',
		super.defaultUsername = 'Fren'
	});

	@override
	String? get imageThumbnailExtension => null;

	@override
	String get siteType => 'frenschan';

	@override
	Future<Thread> getThreadImpl(ThreadIdentifier thread, {ThreadVariant? variant, required RequestPriority priority}) async {
		final broken = await super.getThreadImpl(thread, priority: priority);
		final response = await client.getUri(Uri.https(baseUrl, '/${thread.board}/res/${thread.id}.html'), options: Options(
			extra: {
				kPriority: priority
			}
		));
		final document = parse(response.data);
		final thumbnailUrls = document.querySelectorAll('img.post-image').map((e) => e.attributes['src']).toList();
		for (final attachment in broken.posts_.expand((p) => p.attachments)) {
			final thumbnailUrl = thumbnailUrls.tryFirstWhere((u) => u?.contains(attachment.id) ?? false);
			if (thumbnailUrl != null) {
				attachment.thumbnailUrl = Uri.https(baseUrl, thumbnailUrl).toString();
			}
		}
		// Copy corrected thumbnail URLs to thread from posts_.first
		for (final a in broken.posts_.first.attachments) {
			broken.attachments.tryFirstWhere((a2) => a.id == a2.id)?.thumbnailUrl = a.thumbnailUrl;
		}
		return broken;
	}

	@override
	Future<List<Thread>> getCatalogImpl(String board, {CatalogVariant? variant, required RequestPriority priority}) async {
		final broken = await super.getCatalogImpl(board, priority: priority);
		final response = await client.getUri(Uri.https(baseUrl, '/$board/catalog.html'), options: Options(
			extra: {
				kPriority: priority
			}
		));
		final document = parse(response.data);
		final thumbnailUrls = document.querySelectorAll('img.thread-image').map((e) => e.attributes['src']).toList();
		for (final attachment in broken.expand((t) => t.attachments)) {
			final thumbnailUrl = thumbnailUrls.tryFirstWhere((u) => u?.contains(attachment.id.toString()) ?? false);
			if (thumbnailUrl != null) {
				attachment.thumbnailUrl = Uri.https(baseUrl, thumbnailUrl).toString();
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
	bool operator ==(Object other) => (other is SiteFrenschan) && (other.baseUrl == baseUrl) && (other.name == name) && listEquals(other.archives, archives);

	@override
	int get hashCode => Object.hash(baseUrl, name, archives);

	@override
	String get res => 'res';
}
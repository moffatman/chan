import 'package:chan/models/board.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/lainchan.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart';

class SiteLainchanOrg extends SiteLainchan {
	final String boardsPath;
	SiteLainchanOrg({
		required super.baseUrl,
		required super.name,
		required super.overrideUserAgent,
		required super.archives,
		required super.imageHeaders,
		required super.videoHeaders,
		required super.turnstileSiteKey,
		super.faviconPath,
		super.defaultUsername,
		super.basePath,
		this.boardsPath = '/'
	});

	@override
	Future<List<ImageboardBoard>> getBoards({required RequestPriority priority, CancelToken? cancelToken}) async {
		final response = await client.getUri(Uri.https(baseUrl, '$basePath$boardsPath'), options: Options(
			responseType: ResponseType.plain,
			extra: {
				kPriority: priority
			},
			// Needed to allow multiple interception
			validateStatus: (_) => true
		), cancelToken: cancelToken);
		if (response.statusCode != 200) {
			throw HTTPStatusException.fromResponse(response);
		}
		final document = parse(response.data);
		return document.querySelectorAll('.boardlist a').where((e) => e.attributes['title'] != null && (e.attributes['href'] ?? '').contains('/')).map((e) => ImageboardBoard(
			name: e.attributes['href']!.replaceFirst(basePath, '').split('/')[1],
			title: e.attributes['title']!,
			maxWebmSizeBytes: 25000000,
			maxImageSizeBytes: 25000000,
			isWorksafe: false,
			webmAudioAllowed: true
		)).toList();
	}

	@override
	String get siteType => 'lainchan_org';
	@override
	String get siteData => baseUrl;

	@override
	bool operator ==(Object other) =>
		identical(this, other) ||
		(other is SiteLainchanOrg) &&
		(other.boardsPath == boardsPath) &&
		super==(other);

	@override
	int get hashCode => baseUrl.hashCode;

	@override
	bool get supportsPushNotifications => false;
} 
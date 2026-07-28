import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/lainchan2.dart';
import 'package:dio/dio.dart';

class SiteChud extends SiteLainchan2 {
	SiteChud({
		required super.baseUrl,
		required super.name,
		required super.additionalCookies,
		required super.imageUrl,
		required super.overrideUserAgent,
		required super.addIntrospectedHeaders,
		required super.boardsWithHtmlOnlyFlags,
		required super.boardsWithMemeFlags,
		required super.archives,
		required super.imageHeaders,
		required super.videoHeaders,
		required super.turnstileSiteKey,
		super.boards,
	}) : super(
		basePath: '',
		defaultUsername: 'Anonymous',
		formBypass: {},
		imageThumbnailExtension: '',
		maxUploadSizeBytes: 25000000,
		filesPerPost: 4,
		boardsPath: '/',
	);

	@override
	String get siteType => 'chud';

	@override
	Future<CaptchaRequest> getCaptchaRequest(String board, int? threadId, {CancelToken? cancelToken}) async {
		return const NoCaptchaRequest();
	}

	@override
	bool get supportsPinkQuotes => true;

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is SiteChud &&
		super==(other);
	
	@override
	int get hashCode => baseUrl.hashCode;
}

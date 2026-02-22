import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/lainchan2.dart';
import 'package:dio/dio.dart';

class SiteErischan extends SiteLainchan2 {
	SiteErischan({
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
		required super.turnstileSiteKey
	}) : super(
		basePath: '',
		defaultUsername: '',
		formBypass: {},
		imageThumbnailExtension: ''
	);

	@override
	Future<CaptchaRequest> getCaptchaRequest(String board, int? threadId, {CancelToken? cancelToken}) async {
		return SecucapCaptchaRequest(
			challengeUrl: Uri.https(baseUrl, '/captcha.php', {
				random.nextDouble().toString(): ''
			})
		);
	}

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is SiteErischan &&
		super==(other);
	
	@override
	int get hashCode => baseUrl.hashCode;
}
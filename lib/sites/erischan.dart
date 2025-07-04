import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/lainchan2.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class SiteErischan extends SiteLainchan2 {
	SiteErischan({
		required super.baseUrl,
		required super.name,
		required super.overrideUserAgent,
		required super.boardsWithHtmlOnlyFlags,
		required super.boardsWithMemeFlags,
		required super.archives,
		required super.imageHeaders,
		required super.videoHeaders
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
		other.baseUrl == baseUrl &&
		other.name == name &&
		other.overrideUserAgent == overrideUserAgent &&
		listEquals(other.archives, archives) &&
		mapEquals(other.imageHeaders, imageHeaders) &&
		mapEquals(other.videoHeaders, videoHeaders) &&
		listEquals(other.boardsWithHtmlOnlyFlags, boardsWithHtmlOnlyFlags) &&
		listEquals(other.boardsWithMemeFlags, boardsWithMemeFlags);
	
	@override
	int get hashCode => baseUrl.hashCode;
}
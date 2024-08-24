import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/lainchan2.dart';
import 'package:flutter/foundation.dart';

class SiteErischan extends SiteLainchan2 {
	SiteErischan({
		required super.baseUrl,
		required super.name,
		super.platformUserAgents,
	}) : super(
		basePath: '',
		defaultUsername: '',
		formBypass: {},
		imageThumbnailExtension: ''
	);

	@override
	Future<CaptchaRequest> getCaptchaRequest(String board, [int? threadId]) async {
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
		mapEquals(platformUserAgents, platformUserAgents) &&
		listEquals(other.archives, archives);
	
	@override
	int get hashCode => Object.hash(baseUrl, name, Object.hashAll(platformUserAgents.values), Object.hashAll(archives));
}
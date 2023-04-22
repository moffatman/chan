import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/lainchan_org.dart';

class SiteErischan extends SiteLainchanOrg {
	SiteErischan({
		required super.baseUrl,
		required super.name
	});

	@override
	Future<CaptchaRequest> getCaptchaRequest(String board, [int? threadId]) async {
		return SecucapCaptchaRequest(
			challengeUrl: Uri.https(baseUrl, '/captcha.php', {
				random.nextDouble().toString(): ''
			})
		);
	}
}
import 'package:chan/services/util.dart';
import 'package:chan/sites/frenschan.dart';
import 'package:chan/sites/imageboard_site.dart';

class SiteErischan extends SiteFrenschan {
	SiteErischan({
		required super.baseUrl,
		required super.name,
		super.platformUserAgents,
		super.archives
	}) : super(
		defaultUsername: ''
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
	String get res => 'res';
}
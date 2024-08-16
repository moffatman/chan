import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/lainchan_org.dart';
import 'package:flutter/foundation.dart';

class SiteSoyjak extends SiteLainchanOrg {
	final String? captchaQuestion;
	final List<String>? boardsWithCaptcha;

	SiteSoyjak({
		required super.baseUrl,
		required super.name,
		this.captchaQuestion,
		this.boardsWithCaptcha,
		super.platformUserAgents,
		super.archives,
		super.faviconPath = '/static/favicon.png',
		super.defaultUsername = 'Chud'
	});

	@override
	String? get imageThumbnailExtension => null;

	@override
	String get siteType => 'soyjak';

	@override
	Future<CaptchaRequest> getCaptchaRequest(String board, [int? threadId]) async {
		if (boardsWithCaptcha?.contains(board) ?? true) {
			// If boardsWithCaptcha == null, every board has captcha
			return McCaptchaRequest(
				question: captchaQuestion,
				challengeUrl: Uri.https(baseUrl, '/inc/mccaptcha/entrypoint.php', {'mode': 'captcha'})
			);
		}
		return const NoCaptchaRequest();
	}

	@override
	bool operator ==(Object other) =>
		identical(this, other) ||
		(other is SiteSoyjak) &&
		(other.baseUrl == baseUrl) &&
		(other.name == name) &&
		(other.captchaQuestion == captchaQuestion) &&
		listEquals(other.boardsWithCaptcha, boardsWithCaptcha) &&
		(other.faviconPath == faviconPath) &&
		(other.defaultUsername == defaultUsername) &&
		mapEquals(other.platformUserAgents, platformUserAgents) &&
		listEquals(other.archives, archives);

	@override
	int get hashCode => Object.hash(baseUrl, name, captchaQuestion, Object.hashAll(boardsWithCaptcha ?? []), faviconPath, defaultUsername, Object.hashAll(platformUserAgents.values), Object.hashAll(archives));

	@override
	String get res => 'thread';
}
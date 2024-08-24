import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/lainchan2.dart';
import 'package:flutter/foundation.dart';

class SiteFrenschan extends SiteLainchan2 {
	SiteFrenschan({
		required super.baseUrl,
		required super.name,
		super.platformUserAgents,
	}) : super(
		basePath: '',
		faviconPath: '/favicon.ico',
		defaultUsername: 'Fren',
		formBypass: {},
		imageThumbnailExtension: ''
	);

	@override
	String get siteType => 'frenschan';

	@override
	Future<CaptchaRequest> getCaptchaRequest(String board, [int? threadId]) async {
		return SecurimageCaptchaRequest(
			challengeUrl: Uri.https(baseUrl, '/securimage.php')
		);
	}

	@override
	bool operator ==(Object other) =>
		identical(this, other) ||
		(other is SiteFrenschan) &&
		(other.baseUrl == baseUrl) &&
		(other.name == name) &&
		(other.faviconPath == faviconPath) &&
		(other.defaultUsername == defaultUsername) &&
		mapEquals(other.platformUserAgents, platformUserAgents) &&
		listEquals(other.archives, archives);

	@override
	int get hashCode => Object.hash(baseUrl, name, faviconPath, defaultUsername, Object.hashAll(platformUserAgents.values), Object.hashAll(archives));

	@override
	String get res => 'res';
}
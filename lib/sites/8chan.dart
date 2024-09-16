// ignore_for_file: file_names

import 'package:chan/services/persistence.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/lynxchan.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class Site8Chan extends SiteLynxchan {
  Site8Chan({
		required super.name,
		required super.baseUrl,
		required super.boards,
		required super.defaultUsername,
		required super.overrideUserAgent,
		required super.archives,
		required super.hasLinkCookieAuth
	});

	@override
	Future<CaptchaRequest> getCaptchaRequest(String board, [int? threadId]) async {
		return LynxchanCaptchaRequest(
			board: board
		);
	}

	@override
	Future<PostReceipt> submitPost(DraftPost post, CaptchaSolution captchaSolution, CancelToken cancelToken) async {
		await client.postUri(Uri.https(baseUrl, '/renewBypass.js', {'json': '1'}), data: {
			if (captchaSolution is LynxchanCaptchaSolution) 'captcha': captchaSolution.answer
		}, options: Options(
			extra: {
				kPriority: RequestPriority.interactive
			}
		));
		return await super.submitPost(post, captchaSolution, cancelToken);
	}

	@override
	String? getRedirectGatewayName(Uri uri, String? title) {
		if ((uri.host == baseUrl || uri.host == '') && uri.path == '/.static/pages/disclaimer.html') {
			return '8chan';
		}
		return null;
	}

	@override
	String get siteType => '8chan';
	@override
	String get siteData => baseUrl;

	@override
	bool operator == (Object other) =>
		identical(other, this) ||
		other is Site8Chan &&
		other.name == name &&
		other.baseUrl == baseUrl &&
		(other.overrideUserAgent == overrideUserAgent) &&
		listEquals(other.archives, archives) &&
		listEquals(other.boards, boards) &&
		other.defaultUsername == defaultUsername &&
		other.hasLinkCookieAuth == hasLinkCookieAuth;
	
	@override
	int get hashCode => Object.hash(name, baseUrl, overrideUserAgent, Object.hashAll(archives), Object.hashAll(boards ?? []), defaultUsername, hasLinkCookieAuth);
}

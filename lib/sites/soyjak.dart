import 'package:chan/services/javascript_challenge.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/lainchan2.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class SiteSoyjak extends SiteLainchan2 {
	final String? captchaQuestion;
	final List<String>? boardsWithCaptcha;

	SiteSoyjak({
		required super.baseUrl,
		required super.name,
		this.captchaQuestion,
		this.boardsWithCaptcha,
		required super.overrideUserAgent,
		required super.boardsWithHtmlOnlyFlags,
		required super.archives
	}) : super(
		basePath: '',
		formBypass: {},
		imageThumbnailExtension: null,
		faviconPath: '/static/favicon.png',
		defaultUsername: 'Chud',
		res: 'thread'
	);

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
	Future<PostReceipt> submitPost(DraftPost post, CaptchaSolution captchaSolution, CancelToken cancelToken) async {
		try {
			return await super.submitPost(post, captchaSolution, cancelToken);
		}
		on HTTPStatusException catch (e) {
			if (e.code == 405) {
				throw WebGatewayException(this, authPage);
			}
			rethrow;
		}
	}

	@override
	Future<void> updatePostingFields(DraftPost post, Map<String, dynamic> fields) async {
		fields['integrity-v2'] = await solveJavascriptChallenge(
			url: Uri.parse(getWebUrl(
				board: post.board,
				threadId: post.threadId
			)),
			javascript: 'Module.ccall("x", "string")',
			waitJavascript: 'Object.keys(wasmExports).length > 0',
			priority: RequestPriority.interactive,
			name: 'McChallenge'
		);
	}

	@override
	Uri get authPage => Uri.https(baseUrl, '/challenge-check.html');

	@override
	ImageboardRedirectGateway? getRedirectGateway(Uri uri, String? title) {
		if (title == 'McChallenge') {
			return const ImageboardRedirectGateway(
				name: 'McChallenge',
				alwaysNeedsManualSolving: true
			);
		}
		return null;
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
		(other.overrideUserAgent == overrideUserAgent) &&
		listEquals(other.archives, archives) &&
		listEquals(other.boardsWithHtmlOnlyFlags, boardsWithHtmlOnlyFlags);

	@override
	int get hashCode => Object.hash(baseUrl, name, captchaQuestion, Object.hashAll(boardsWithCaptcha ?? []), faviconPath, defaultUsername, overrideUserAgent, Object.hashAll(archives), Object.hashAll(boardsWithHtmlOnlyFlags));
}
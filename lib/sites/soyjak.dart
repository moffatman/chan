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
		required super.boardsWithMemeFlags,
		required super.archives,
		required super.imageHeaders,
		required super.videoHeaders
	}) : super(
		basePath: '',
		formBypass: {},
		imageThumbnailExtension: null,
		faviconPath: '/favicon.ico',
		defaultUsername: 'Chud',
		res: 'thread'
	);

	@override
	String get siteType => 'soyjak';

	@override
	Future<CaptchaRequest> getCaptchaRequest(String board, int? threadId, {CancelToken? cancelToken}) async {
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
	Future<void> updatePostingFields(DraftPost post, Map<String, dynamic> fields, CancelToken? cancelToken) async {
		fields['integrity-v2'] = await solveJavascriptChallenge<String>(
			url: Uri.parse(getWebUrl(
				board: post.board,
				threadId: post.threadId
			)),
			javascript: 'Module.ccall("x", "string")',
			waitJavascript: 'Object.keys(wasmExports).length > 0',
			priority: RequestPriority.interactive,
			name: 'McChallenge',
			cancelToken: cancelToken
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

	/// soyjak reuses same image ID for reposts. So need to make it unique within thread
	@override
	String getAttachmentId(int postId, String imageId, String source) => '${postId}_${imageId}_$source';

	@override
	bool get supportsPinkQuotes => true;
	@override
	bool get supportsBlueQuotes => true;

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
		listEquals(other.boardsWithHtmlOnlyFlags, boardsWithHtmlOnlyFlags) &&
		listEquals(other.boardsWithMemeFlags, boardsWithMemeFlags);

	@override
	int get hashCode => baseUrl.hashCode;
}
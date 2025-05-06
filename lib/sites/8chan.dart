// ignore_for_file: file_names

import 'package:chan/services/javascript_challenge.dart';
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
		required super.hasLinkCookieAuth,
		required super.hasPagedCatalog
	});

	static const _kRedirectGateway = ImageboardRedirectGateway(
		name: '8chan',
		alwaysNeedsManualSolving: false,
		autoClickSelector: 'h1 a'
	);

	@override
	Future<CaptchaRequest> getCaptchaRequest(String board, int? threadId, {CancelToken? cancelToken}) async {
		final captchaMode = persistence?.maybeGetBoard(board)?.captchaMode ?? 0;
		if (captchaMode == 0 ||
				(captchaMode == 1 && threadId != null)) {
			return const NoCaptchaRequest();
		}
		return LynxchanCaptchaRequest(
			board: board,
			redirectGateway: _kRedirectGateway
		);
	}

	@override
	Future<PostReceipt> submitPost(DraftPost post, CaptchaSolution captchaSolution, CancelToken cancelToken) async {
		final blockResponse = await client.postUri(Uri.https(baseUrl, '/blockBypass.js', {'json': '1'}), options: Options(
			responseType: ResponseType.json,
			extra: {
				kPriority: RequestPriority.interactive
			}
		), cancelToken: cancelToken);
		if (blockResponse.data['status'] == 'error') {
			throw PostFailedException(blockResponse.data['data'] as String);
		}
		if (blockResponse.data['data']['valid'] != true) {
			if (captchaSolution is LynxchanCaptchaSolution) {
				// Register the existing captcha
				final submit1Response = await client.postUri(Uri.https(baseUrl, '/solveCaptcha.js', {'json': '1'}), data: {
					'captchaId': captchaSolution.id,
					'answer': captchaSolution.answer
				}, options: Options(
					extra: {
						kPriority: RequestPriority.interactive
					}
				), cancelToken: cancelToken);
				if (submit1Response.data['status'] == 'error') {
					throw PostFailedException(submit1Response.data['data'] as String);
				}
			}
			throw AdditionalCaptchaRequiredException(
				captchaRequest: LynxchanCaptchaRequest(
					board: post.board,
					redirectGateway: _kRedirectGateway
				),
				onSolved: (solution2, cancelToken2) async {
					final response = await client.postUri(Uri.https(baseUrl, '/renewBypass.js', {'json': '1'}), data: {
						if (solution2 is LynxchanCaptchaSolution) 'captcha': solution2.answer
					}, options: Options(
						responseType: ResponseType.json,
						extra: {
							kPriority: RequestPriority.interactive
						}
					), cancelToken: cancelToken2);
					if (response.data['status'] == 'error') {
						throw PostFailedException(response.data['data'] as String);
					}
				}
			);
		}
		if (blockResponse.data['data']['validated'] == false) {
			await solveJavascriptChallenge<void>(
				url: Uri.parse(getWebUrlImpl(post.board, post.threadId)),
				priority: RequestPriority.interactive,
				headlessTime: const Duration(seconds: 20),
				name: '8chan validation',
				javascript:
					'''
						new Promise(function (resolve, reject) {
							resolve.stop = reject
							bypassUtils.runValidation(resolve)
						})
					'''
			);
		}
		return await super.submitPost(post, captchaSolution, cancelToken);
	}

	@override
	ImageboardRedirectGateway? getRedirectGateway(Uri uri, String? title) {
		if ((uri.host == baseUrl || uri.host == '') && uri.path == '/.static/pages/disclaimer.html') {
			return _kRedirectGateway;
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
		other.hasLinkCookieAuth == hasLinkCookieAuth &&
		other.hasPagedCatalog == hasPagedCatalog;
	
	@override
	int get hashCode => Object.hash(name, baseUrl, overrideUserAgent, Object.hashAll(archives), Object.hashAll(boards ?? []), defaultUsername, hasLinkCookieAuth, hasPagedCatalog);
}

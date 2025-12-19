// ignore_for_file: file_names

import 'package:chan/services/javascript_challenge.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/lynxchan.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

class Site8Chan extends SiteLynxchan {
  Site8Chan({
		required super.name,
		required super.baseUrl,
		required super.boards,
		required super.defaultUsername,
		required super.overrideUserAgent,
		required super.archives,
		required super.imageHeaders,
		required super.videoHeaders,
		required super.hasLinkCookieAuth,
		required super.hasPagedCatalog,
		required super.allowsArbitraryBoards
	}) : super(
		hasBlockBypassJson: true
	);

	@override
	@protected
	ImageboardRedirectGateway get redirectGateway => const ImageboardRedirectGateway(
		name: '8chan',
		alwaysNeedsManualSolving: false,
		autoClickSelector: 'h1 a'
	);

	@override
	Future<Map> handleBlockBypassJson(DraftPost post, CaptchaSolution captchaSolution, CancelToken cancelToken) async {
		final data = await super.handleBlockBypassJson(post, captchaSolution, cancelToken);
		if (data case {'data': {'validated': false}}) {
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
		return data;
	}

	@override
	ImageboardRedirectGateway? getRedirectGateway(Uri uri, String? Function() title) {
		if ((uri.host == baseUrl || uri.host == '') && uri.path == '/.static/pages/disclaimer.html') {
			return redirectGateway;
		}
		return null;
	}

	@override
	String get siteType => '8chan';
	@override
	String get siteData => baseUrl;

	@override
	bool get supportsPinkQuotes => true;

	@override
	List<ImageboardSnippet> getBoardSnippets(String board) => const [
		greentextSnippet,
		ImageboardSnippet.simple(
			icon: CupertinoIcons.eye_slash,
			name: 'Spoiler',
			start: '[spoiler]',
			end: '[/spoiler]'
		)
	];

	@override
	bool operator == (Object other) =>
		identical(other, this) ||
		other is Site8Chan &&
		super==(other);
	
	@override
	int get hashCode => baseUrl.hashCode;
}

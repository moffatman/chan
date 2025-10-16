import 'package:chan/services/persistence.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/lainchan2.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class SiteCRBA extends SiteLainchan2 {
	SiteSoyjak({
		required super.baseUrl,
		required super.name,
		required super.imageUrl,
		required super.overrideUserAgent,
		required super.boardsWithHtmlOnlyFlags,
		required super.boardsWithMemeFlags,
		required super.archives,
		required super.imageHeaders,
		required super.videoHeaders,
		required super.turnstileSiteKey
	}) : super(
		basePath: '',
		formBypass: {},
		imageThumbnailExtension: null,
		faviconPath: '/favicon.ico',
		defaultUsername: 'Anonymous',
		res: 'res'
	);

	@override
	String get siteType => 'CRBAchan';

	@override
	Future<CaptchaRequest> getCaptchaRequest(String board, int? threadId, {CancelToken? cancelToken}) async {
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
	String getAttachmentId(int postId, String imageId, String source) => '${postId}_${imageId}_$source';

	@override
	bool operator ==(Object other) =>
		identical(this, other) ||
		(other is SiteCRBA) &&
		super==(other);
}

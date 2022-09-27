import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:chan/main.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/search.dart';
import 'package:chan/services/cloudflare.dart';
import 'package:chan/services/cookies.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/sites/4chan.dart';
import 'package:chan/sites/dvach.dart';
import 'package:chan/sites/foolfuuka.dart';
import 'package:chan/sites/frenschan.dart';
import 'package:chan/sites/futaba.dart';
import 'package:chan/sites/fuuka.dart';
import 'package:chan/sites/lainchan.dart';
import 'package:chan/sites/lainchan_org.dart';
import 'package:chan/sites/soyjak.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import '../models/thread.dart';

import 'package:dio/dio.dart';
final userAgent = Platform.isAndroid ? 
	'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/105.0.5195.79 Mobile Safari/537.36'
	: 'Mozilla/5.0 (iPhone; CPU iPhone OS 15_6_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.6.1 Mobile/15E148 Safari/604.1';

class PostNotFoundException implements Exception {
	String board;
	int id;
	PostNotFoundException(this.board, this.id);
	@override
	String toString() => 'Post not found: /$board/$id';
}

class ThreadNotFoundException implements Exception {
	ThreadIdentifier thread;
	ThreadNotFoundException(this.thread);
	@override
	String toString() => 'Thread not found: /${thread.board}/${thread.id}';
}

class BoardNotFoundException implements Exception {
	String board;
	BoardNotFoundException(this.board);
	@override
	String toString() => 'Board not found: /$board/';
}

class BoardNotArchivedException implements Exception {
	String board;
	BoardNotArchivedException(this.board);
	@override
	String toString() => 'Board not archived: /$board/';
}

class HTTPStatusException implements Exception {
	int code;
	HTTPStatusException(this.code);
	@override
	String toString() => 'HTTP Error $code';
}

class PostFailedException implements Exception {
	String reason;
	PostFailedException(this.reason);
	@override
	String toString() => 'Posting failed: $reason';
}

class BannedException implements Exception {
	String reason;
	BannedException(this.reason);
	@override
	String toString() => 'Posting failed: $reason';
}

class DeletionFailedException implements Exception {
	final String reason;
	const DeletionFailedException(this.reason);
	@override
	String toString() => 'Deleting failed: $reason';
}

class ImageboardArchiveException implements Exception {
	Map<String, String> archiveErrors;
	ImageboardArchiveException(this.archiveErrors);
	@override
	String toString() => archiveErrors.entries.map((e) => '${e.key}: ${e.value}').join('\n');
}

class UnknownSiteTypeException implements Exception {
	final String siteType;
	const UnknownSiteTypeException(this.siteType);
	@override
	String toString() => 'Unknown site type "$siteType"\nAn app update might be required.';
}

class UnknownArchiveTypeException implements Exception {
	final String siteType;
	const UnknownArchiveTypeException(this.siteType);
	@override
	String toString() => 'Unknown archive type "$siteType"\nAn app update might be required.';
}

enum ImageboardAction {
	postThread,
	postReply,
	postReplyWithImage
}

class CaptchaRequest {

}

class NoCaptchaRequest extends CaptchaRequest {
  
}

class RecaptchaRequest extends CaptchaRequest {
	final String key;
	final String sourceUrl;
	final bool cloudflare;
	RecaptchaRequest({
		required this.key,
		required this.sourceUrl,
		required this.cloudflare
	});
	@override
	String toString() => 'RecaptchaRequest(sourceUrl: $sourceUrl, key: $key)';
}

class Chan4CustomCaptchaRequest extends CaptchaRequest {
	final Uri challengeUrl;
	Chan4CustomCaptchaRequest({
		required this.challengeUrl
	});
	@override
	String toString() => 'Chan4CustomCaptchaRequest(challengeUrl: $challengeUrl)';
}

class SecurimageCaptchaRequest extends CaptchaRequest {
	final Uri challengeUrl;
	SecurimageCaptchaRequest({
		required this.challengeUrl
	});
	@override
	String toString() => 'SecurimageCaptchaRequest(challengeUrl: $challengeUrl)';
}

class DvachCaptchaRequest extends CaptchaRequest {
	final Duration challengeLifetime;
	DvachCaptchaRequest({
		required this.challengeLifetime
	});
}

abstract class CaptchaSolution {
	DateTime? get expiresAt;
	bool get cloudflare => false;
}

class NoCaptchaSolution extends CaptchaSolution {
	@override
	DateTime? get expiresAt => null;
}

class RecaptchaSolution extends CaptchaSolution {
	final String response;
	@override
	final bool cloudflare;
	RecaptchaSolution({
		required this.response,
		required this.cloudflare
	});
	@override
	DateTime? get expiresAt => null;
	@override
	String toString() => 'RecaptchaSolution(response: $response)';
}

class Chan4CustomCaptchaSolution extends CaptchaSolution {
	final String challenge;
	final String response;
	@override
	final DateTime expiresAt;
	final ui.Image? alignedImage;
	@override
	final bool cloudflare;
	Chan4CustomCaptchaSolution({
		required this.challenge,
		required this.response,
		required this.expiresAt,
		required this.alignedImage,
		required this.cloudflare
	});
	@override
	String toString() => 'Chan4CustomCaptchaSolution(challenge: $challenge, response: $response)';
}

class SecurimageCaptchaSolution extends CaptchaSolution {
	final String cookie;
	final String response;
	@override
	final DateTime expiresAt;
	SecurimageCaptchaSolution({
		required this.cookie,
		required this.response,
		required this.expiresAt
	});
	@override
	String toString() => 'SecurimageCaptchaSolution(cookie: $cookie, response: $response)';
}

class DvachCaptchaSolution extends CaptchaSolution {
	final String id;
	final String response;
	@override
	final DateTime expiresAt;
	DvachCaptchaSolution({
		required this.id,
		required this.response,
		required this.expiresAt
	});
	@override
	String toString() => 'DvachCaptchaSolution(id: $id, response: $response)';
}

class ImageboardArchiveSearchResult {
	final Post? post;
	final Thread? thread;
	ImageboardArchiveSearchResult({
		this.post,
		this.thread
	}) {
		assert(post != null || thread != null);
	}

	ThreadIdentifier get threadIdentifier => (post?.threadIdentifier ?? thread?.identifier)!;
	int get id => (post?.id ?? thread?.id)!;

	@override toString() => 'ImageboardArchiveSearchResult(${post ?? thread})';
}

class ImageboardArchiveSearchResultPage {
	final List<ImageboardArchiveSearchResult> posts;
	final int page;
	final int maxPage;
	final ImageboardSiteArchive archive;
	ImageboardArchiveSearchResultPage({
		required this.posts,
		required this.page,
		required this.maxPage,
		required this.archive
	});
}

class ImageboardSiteLoginField {
	final String displayName;
	final String formKey;
	final TextInputType? inputType;
	const ImageboardSiteLoginField({
		required this.displayName,
		required this.formKey,
		this.inputType
	});

	@override
	String toString() => 'ImageboardSiteLoginField(displayName: $displayName, formKey: $formKey)';
}

class ImageboardSiteLoginException implements Exception {
	final String message;
	const ImageboardSiteLoginException(this.message);

	@override
	String toString() => 'Login failed: $message';
}

class ImageboardEmote {
	final String code;
	final String? text;
	final Uri? image;
	const ImageboardEmote({
		required this.code,
		this.text,
		this.image
	});
}

class ImageboardBoardFlag {
	final String code;
	final String name;
	final Uri image;
	const ImageboardBoardFlag({
		required this.code,
		required this.name,
		required this.image
	});
}

class ImageboardSnippet {
	final IconData icon;
	final String name;
	final String start;
	final String end;
	final PostSpan Function(String text)? previewBuilder;
	const ImageboardSnippet({
		required this.icon,
		required this.name,
		required this.start,
		required this.end,
		this.previewBuilder
	});
}

abstract class ImageboardSiteArchive {
	final Dio client = Dio();
	ImageboardSiteArchive() {
		client.interceptors.add(SeparatedCookieManager(
			wifiCookieJar: Persistence.wifiCookies,
			cellularCookieJar: Persistence.cellularCookies
		));
		client.interceptors.add(InterceptorsWrapper(
			onRequest: (options, handler) {
				options.headers['user-agent'] = userAgent;
				handler.next(options);
			}
		));
		client.interceptors.add(CloudflareInterceptor());
	}
	String get name;
	Future<Post> getPost(String board, int id);
	Future<Thread> getThread(ThreadIdentifier thread);
	Future<List<Thread>> getCatalog(String board);
	Future<List<ImageboardBoard>> getBoards();
	Future<ImageboardArchiveSearchResultPage> search(ImageboardArchiveSearchQuery query, {required int page});
	String getWebUrl(String board, [int? threadId, int? postId]);
	BoardThreadOrPostIdentifier? decodeUrl(String url);
}

abstract class ImageboardSite extends ImageboardSiteArchive {
	final Map<String, Map<String, String>> memoizedWifiHeaders = {};
	final Map<String, Map<String, String>> memoizedCellularHeaders = {};
	final List<ImageboardSiteArchive> archives;
	ImageboardSite(this.archives) : super();
	Future<void> ensureCookiesMemoized(Uri url) async {
		memoizedWifiHeaders.putIfAbsent(url.host, () => {
			'user-agent': userAgent
		})['cookie'] = (await Persistence.wifiCookies.loadForRequest(url)).join('; ');
		memoizedCellularHeaders.putIfAbsent(url.host, () => {
			'user-agent': userAgent
		})['cookie'] = (await Persistence.cellularCookies.loadForRequest(url)).join('; ');
	}
	Map<String, String>? getHeaders(Uri url) {
		if (settings.connectivity == ConnectivityResult.mobile) {
			return memoizedCellularHeaders[url.host];
		}
		return memoizedWifiHeaders[url.host];
	}
	Uri get passIconUrl;
	String get baseUrl;
	String get imageUrl;
	Uri get iconUrl;
	Future<CaptchaRequest> getCaptchaRequest(String board, [int? threadId]);
	Future<PostReceipt> createThread({
		required String board,
		String name = '',
		String options = '',
		String subject = '',
		required String text,
		required CaptchaSolution captchaSolution,
		File? file,
		bool? spoiler,
		String? overrideFilename,
		ImageboardBoardFlag? flag
	});
	Future<PostReceipt> postReply({
		required ThreadIdentifier thread,
		String name = '',
		String options = '',
		required String text,
		required CaptchaSolution captchaSolution,
		File? file,
		bool? spoiler,
		String? overrideFilename,
		ImageboardBoardFlag? flag
	});
	DateTime? getActionAllowedTime(String board, ImageboardAction action);
	Future<void> deletePost(String board, PostReceipt receipt);
	Future<Post> getPostFromArchive(String board, int id) async {
		final Map<String, String> errorMessages = {};
		for (final archive in archives) {
			try {
				final post = await archive.getPost(board, id);
				for (final attachment in post.attachments) {
					await ensureCookiesMemoized(attachment.thumbnailUrl);
					await ensureCookiesMemoized(attachment.url);
				}
				return post;
			}
			catch(e, st) {
				if (e is! BoardNotFoundException) {
					errorMessages[archive.name] = e.toStringDio();
					print(e);
					print(st);
				}
			}
		}
		if (errorMessages.isNotEmpty) {
			throw ImageboardArchiveException(errorMessages);
		}
		else {
			throw BoardNotArchivedException(board);
		}
	}
	Future<Thread> getThreadFromArchive(ThreadIdentifier thread, {Future<void> Function(Thread)? validate}) async {
		final Map<String, String> errorMessages = {};
		for (final archive in archives) {
			try {
				final thread_ = await archive.getThread(thread);
				for (final attachment in thread_.attachments) {
					await ensureCookiesMemoized(attachment.thumbnailUrl);
					await ensureCookiesMemoized(attachment.url);
				}
				if (validate != null) {
					await validate(thread_);
				}
				return thread_;
			}
			catch(e) {
				if (e is! BoardNotFoundException) {
					print('Error getting $thread from ${archive.name}: ${e.toStringDio()}');
					errorMessages[archive.name] = e.toStringDio();
				}
			}
		}
		if (errorMessages.isNotEmpty) {
			throw ImageboardArchiveException(errorMessages);
		}
		else {
			throw BoardNotArchivedException(thread.board);
		}
	}

	@override
	Future<ImageboardArchiveSearchResultPage> search(ImageboardArchiveSearchQuery query, {required int page}) async {
		String s = '';
		for (final archive in archives) {
			try {
				return await archive.search(query, page: page);
			}
			catch (e, st) {
				if (e is! BoardNotFoundException) {
					print('Error from ${archive.name}');
					print(e.toStringDio());
					print(st);
					s += '\n${archive.name}: ${e.toStringDio()}';
				}
			}
		}
		throw Exception('Search failed - exhausted all archives$s');
	}
	Uri getSpoilerImageUrl(Attachment attachment, {ThreadIdentifier? thread});
	Uri getPostReportUrl(String board, int id);
	late Persistence persistence;
	String? getLoginSystemName();
	List<ImageboardSiteLoginField> getLoginFields();
	Future<void> login(Map<ImageboardSiteLoginField, String> fields);
	Map<ImageboardSiteLoginField, String>? getSavedLoginFields() {
		 if (persistence.browserState.loginFields.isNotEmpty) {
			 try {
					final savedFields = {
						for (final field in getLoginFields()) field: persistence.browserState.loginFields[field.formKey]!
					};
					return savedFields;
			 }
			 catch (e) {
				 // Probably a field isn't present
			 }
		 }
		 return null;
	}
	Future<void> clearSavedLoginFields() async {
		persistence.browserState.loginFields.clear();
		await persistence.didUpdateBrowserState();
	}
	Future<void> clearLoginCookies(bool fromBothWifiAndCellular);
	List<ImageboardEmote> getEmotes();
	Future<List<ImageboardBoardFlag>> getBoardFlags(String board);
	String get siteType;
	String get siteData;
	String get defaultUsername;
	List<ImageboardSnippet> getBoardSnippets(String board);
	CaptchaRequest? getBannedCaptchaRequest(bool cloudflare) => null;
	Future<String> getBannedReason(CaptchaSolution captchaSolution) async => 'Unknown';
}

ImageboardSite makeSite(dynamic data) {
	if (data['type'] == 'lainchan') {
		return SiteLainchan(
			name: data['name'],
			baseUrl: data['baseUrl']
		);
	}
	else if (data['type'] == 'soyjak') {
		return SiteSoyjak(
			name: data['name'],
			baseUrl: data['baseUrl']
		);
	}
	else if (data['type'] == 'frenschan') {
		return SiteFrenschan(
			name: data['name'],
			baseUrl: data['baseUrl']
		);
	}
	else if (data['type'] == 'lainchan_org') {
		return SiteLainchanOrg(
			name: data['name'],
			baseUrl: data['baseUrl']
		);
	}
	else if (data['type'] == 'dvach') {
		return SiteDvach(
			name: data['name'],
			baseUrl: data['baseUrl']
		);
	}
	else if (data['type'] == 'futaba') {
		return SiteFutaba(
			name: data['name'],
			baseUrl: data['baseUrl'],
			maxUploadSizeBytes: data['maxUploadSizeBytes']
		);
	}
	else if (data['type'] == '4chan') {
		return Site4Chan(
			name: data['name'],
			imageUrl: data['imageUrl'],
			captchaKey: data['captchaKey'],
			apiUrl: data['apiUrl'],
			sysUrl: data['sysUrl'],
			baseUrl: data['baseUrl'],
			staticUrl: data['staticUrl'],
			archives: (data['archives'] ?? []).map<ImageboardSiteArchive>((archive) {
				final boards = (archive['boards'] as List<dynamic>?)?.map((b) => ImageboardBoard(
					title: b['title'],
					name: b['name'],
					isWorksafe: b['isWorksafe'],
					webmAudioAllowed: false
				)).toList();
				if (archive['type'] == 'foolfuuka') {
					return FoolFuukaArchive(
						name: archive['name'],
						baseUrl: archive['baseUrl'],
						staticUrl: archive['staticUrl'],
						boards: boards
					);
				}
				else if (archive['type'] == 'fuuka') {
					return FuukaArchive(
						name: archive['name'],
						baseUrl: archive['baseUrl'],
						boards: boards
					);
				}
				else {
					print(archive);
					throw UnknownArchiveTypeException(data['type']);
				}
			}).toList()
		);
	}
	else {
		print(data);
		throw UnknownSiteTypeException(data['type']);
	}
}
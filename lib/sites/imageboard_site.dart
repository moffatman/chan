import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:chan/models/attachment.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/search.dart';
import 'package:chan/services/cloudflare.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/sites/4chan.dart';
import 'package:chan/sites/foolfuuka.dart';
import 'package:chan/sites/frenschan.dart';
import 'package:chan/sites/fuuka.dart';
import 'package:chan/sites/lainchan.dart';
import 'package:chan/sites/lainchan_org.dart';
import 'package:chan/sites/soyjak.dart';
import 'package:chan/util.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/widgets.dart';

import '../models/thread.dart';

import 'package:dio/dio.dart';
const userAgent = 'Mdozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) AppleWebKit/605.1.15 (KHTML, like Gecko)';

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
	RecaptchaRequest({
		required this.key,
		required this.sourceUrl
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

abstract class CaptchaSolution {
	DateTime? get expiresAt;
}

class NoCaptchaSolution extends CaptchaSolution {
	@override
	DateTime? get expiresAt => null;
}

class RecaptchaSolution extends CaptchaSolution {
	final String response;
	RecaptchaSolution({
		required this.response
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
	Chan4CustomCaptchaSolution({
		required this.challenge,
		required this.response,
		required this.expiresAt,
		required this.alignedImage
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

abstract class ImageboardSiteArchive {
	final Dio client = Dio();
	ImageboardSiteArchive() {
		client.interceptors.add(CookieManager(Persistence.cookies));
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
}

abstract class ImageboardSite extends ImageboardSiteArchive {
	final Map<String, Map<String, String>> memoizedHeaders = {};
	final List<ImageboardSiteArchive> archives;
	ImageboardSite(this.archives) : super();
	Future<void> ensureCookiesMemoized(Uri url) async {
		memoizedHeaders.putIfAbsent(url.host, () => {
			'user-agent': userAgent
		})['cookie'] = (await Persistence.cookies.loadForRequest(url)).join('; ');
	}
	Map<String, String>? getHeaders(Uri url) {
		return memoizedHeaders[url.host];
	}
	Uri get passIconUrl;
	String get imageUrl;
	Uri get iconUrl;
	CaptchaRequest getCaptchaRequest(String board, [int? threadId]);
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
				if (post.attachment != null) {
					await ensureCookiesMemoized(post.attachment!.thumbnailUrl);
					await ensureCookiesMemoized(post.attachment!.url);
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
			throw BoardNotFoundException(board);
		}
	}
	Future<Thread> getThreadFromArchive(ThreadIdentifier thread, {Future<void> Function(Thread)? validate}) async {
		final Map<String, String> errorMessages = {};
		for (final archive in archives) {
			try {
				final thread_ = await archive.getThread(thread);
				if (thread_.attachment != null) {
					await ensureCookiesMemoized(thread_.attachment!.thumbnailUrl);
					await ensureCookiesMemoized(thread_.attachment!.url);
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
			throw BoardNotFoundException(thread.board);
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
					print(e);
					print(st);
					s += '\n${archive.name}: ${e.toStringDio()}';
				}
			}
		}
		throw Exception('Search failed - exhausted all archives$s');
	}
	Uri getSpoilerImageUrl(Attachment attachment, {ThreadIdentifier? thread});
	Uri getPostReportUrl(String board, int id);
	Persistence? persistence;
	String? getLoginSystemName();
	List<ImageboardSiteLoginField> getLoginFields();
	Future<void> login(Map<ImageboardSiteLoginField, String> fields);
	Future<Map<ImageboardSiteLoginField, String>?> getSavedLoginFields() async {
		 if ((persistence?.browserState.loginFields.length ?? 0) > 0) {
			 try {
					final savedFields = {
						for (final field in getLoginFields()) field: persistence!.browserState.loginFields[field.formKey]!
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
		persistence?.browserState.loginFields.clear();
		await persistence?.didUpdateBrowserState();
	}
	Future<void> clearLoginCookies();
	List<ImageboardEmote> getEmotes();
	Future<List<ImageboardBoardFlag>> getBoardFlags(String board);
	String get siteType;
	String get siteData;
	ThreadOrPostIdentifier? decodeUrl(String url);
	String get defaultUsername;
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
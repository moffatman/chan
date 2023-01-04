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
import 'package:chan/services/settings.dart';
import 'package:chan/sites/4chan.dart';
import 'package:chan/sites/dvach.dart';
import 'package:chan/sites/foolfuuka.dart';
import 'package:chan/sites/frenschan.dart';
import 'package:chan/sites/futaba.dart';
import 'package:chan/sites/fuuka.dart';
import 'package:chan/sites/hacker_news.dart';
import 'package:chan/sites/lainchan.dart';
import 'package:chan/sites/lainchan_org.dart';
import 'package:chan/sites/reddit.dart';
import 'package:chan/sites/soyjak.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/thread.dart';

import 'package:dio/dio.dart';

part 'imageboard_site.g.dart';

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

@HiveType(typeId: 33)
enum CatalogVariant {
	@HiveField(0)
	unsorted,
	@HiveField(1)
	unsortedReversed,
	@HiveField(2)
	lastPostTime,
	@HiveField(3)
	lastPostTimeReversed,
	@HiveField(4)
	replyCount,
	@HiveField(5)
	replyCountReversed,
	@HiveField(6)
	threadPostTime,
	@HiveField(7)
	threadPostTimeReversed,
	@HiveField(8)
	savedTime,
	@HiveField(9)
	savedTimeReversed,
	@HiveField(10)
	postsPerMinute,
	@HiveField(11)
	postsPerMinuteReversed,
	@HiveField(12)
	lastReplyTime,
	@HiveField(13)
	lastReplyTimeReversed,
	@HiveField(14)
	imageCount,
	@HiveField(15)
	imageCountReversed,
	@HiveField(16)
	lastReplyByYouTime,
	@HiveField(17)
	lastReplyByYouTimeReversed,
	@HiveField(18)
	redditHot,
	@HiveField(19)
	redditNew,
	@HiveField(20)
	redditRising,
	@HiveField(21)
	redditControversialPastHour,
	@HiveField(22)
	redditControversialPast24Hours,
	@HiveField(23)
	redditControversialPastWeek,
	@HiveField(24)
	redditControversialPastMonth,
	@HiveField(25)
	redditControversialPastYear,
	@HiveField(26)
	redditControversialAllTime,
	@HiveField(27)
	redditTopPastHour,
	@HiveField(28)
	redditTopPast24Hours,
	@HiveField(29)
	redditTopPastWeek,
	@HiveField(30)
	redditTopPastMonth,
	@HiveField(31)
	redditTopPastYear,
	@HiveField(32)
	redditTopAllTime,
	@HiveField(33)
	chan4NativeArchive,
	@HiveField(34)
	hackerNewsTop,
	@HiveField(35)
	hackerNewsNew,
	@HiveField(36)
	hackerNewsBest,
	@HiveField(37)
	hackerNewsAsk,
	@HiveField(38)
	hackerNewsShow,
	@HiveField(39)
	hackerNewsJobs
}

extension CatalogVariantMetadata on CatalogVariant {
	ThreadSortingMethod? get sortingMethod {
		switch (this) {
			case CatalogVariant.lastPostTime:
			case CatalogVariant.lastPostTimeReversed:
				return ThreadSortingMethod.lastPostTime;
			case CatalogVariant.replyCount:
			case CatalogVariant.replyCountReversed:
				return ThreadSortingMethod.replyCount;
			case CatalogVariant.threadPostTime:
			case CatalogVariant.threadPostTimeReversed:
				return ThreadSortingMethod.threadPostTime;
			case CatalogVariant.savedTime:
			case CatalogVariant.savedTimeReversed:
				return ThreadSortingMethod.savedTime;
			case CatalogVariant.postsPerMinute:
			case CatalogVariant.postsPerMinuteReversed:
				return ThreadSortingMethod.postsPerMinute;
			case CatalogVariant.lastReplyTime:
			case CatalogVariant.lastReplyTimeReversed:
				return ThreadSortingMethod.lastReplyTime;
			case CatalogVariant.imageCount:
			case CatalogVariant.imageCountReversed:
				return ThreadSortingMethod.imageCount;
			case CatalogVariant.lastReplyByYouTime:
			case CatalogVariant.lastReplyByYouTimeReversed:
				return ThreadSortingMethod.imageCount;
			default:
				return null;
		}
	}
	bool get reverseAfterSorting {
		switch (this) {
			case CatalogVariant.unsortedReversed:
			case CatalogVariant.lastPostTimeReversed:
			case CatalogVariant.replyCountReversed:
			case CatalogVariant.threadPostTimeReversed:
			case CatalogVariant.savedTimeReversed:
			case CatalogVariant.postsPerMinuteReversed:
			case CatalogVariant.lastReplyTimeReversed:
			case CatalogVariant.imageCountReversed:
			case CatalogVariant.lastReplyByYouTimeReversed:
				return true;
			default:
				return false;
		}
	}
	bool get temporary {
		switch (this) {
			case CatalogVariant.chan4NativeArchive:
				return true;
			default:
				return false;
		}
	}
	IconData? get icon => const {
		CatalogVariant.lastPostTime: CupertinoIcons.staroflife,
		CatalogVariant.lastPostTimeReversed: CupertinoIcons.staroflife,
		CatalogVariant.replyCount: CupertinoIcons.reply_all,
		CatalogVariant.replyCountReversed: CupertinoIcons.reply_all,
		CatalogVariant.threadPostTime: CupertinoIcons.clock,
		CatalogVariant.threadPostTimeReversed: CupertinoIcons.clock,
		CatalogVariant.postsPerMinute: CupertinoIcons.speedometer,
		CatalogVariant.postsPerMinuteReversed: CupertinoIcons.speedometer,
		CatalogVariant.lastReplyTime: CupertinoIcons.staroflife,
		CatalogVariant.lastReplyTimeReversed: CupertinoIcons.staroflife,
		CatalogVariant.imageCount: CupertinoIcons.photo,
		CatalogVariant.imageCountReversed: CupertinoIcons.photo,
		CatalogVariant.redditHot: CupertinoIcons.flame,
		CatalogVariant.redditNew: CupertinoIcons.clock,
		CatalogVariant.redditRising: CupertinoIcons.graph_square,
		CatalogVariant.redditControversialPastHour: CupertinoIcons.exclamationmark_shield,
		CatalogVariant.redditControversialPast24Hours: CupertinoIcons.exclamationmark_shield,
		CatalogVariant.redditControversialPastWeek: CupertinoIcons.exclamationmark_shield,
		CatalogVariant.redditControversialPastMonth: CupertinoIcons.exclamationmark_shield,
		CatalogVariant.redditControversialPastYear: CupertinoIcons.exclamationmark_shield,
		CatalogVariant.redditControversialAllTime: CupertinoIcons.exclamationmark_shield,
		CatalogVariant.redditTopPastHour: CupertinoIcons.arrow_up,
		CatalogVariant.redditTopPast24Hours: CupertinoIcons.arrow_up,
		CatalogVariant.redditTopPastWeek: CupertinoIcons.arrow_up,
		CatalogVariant.redditTopPastMonth: CupertinoIcons.arrow_up,
		CatalogVariant.redditTopPastYear: CupertinoIcons.arrow_up,
		CatalogVariant.redditTopAllTime: CupertinoIcons.arrow_up,
		CatalogVariant.chan4NativeArchive: CupertinoIcons.archivebox,
		CatalogVariant.hackerNewsTop: CupertinoIcons.arrow_up,
		CatalogVariant.hackerNewsNew: CupertinoIcons.clock,
		CatalogVariant.hackerNewsBest: CupertinoIcons.star,
		CatalogVariant.hackerNewsAsk: CupertinoIcons.chat_bubble_2,
		CatalogVariant.hackerNewsShow: CupertinoIcons.chart_bar_square,
		CatalogVariant.hackerNewsJobs: CupertinoIcons.briefcase
	}[this];
	String get name => const {
		CatalogVariant.unsorted: 'Bump order',
		CatalogVariant.unsortedReversed: 'Reverse bump order',
		CatalogVariant.lastPostTime: 'Latest reply first',
		CatalogVariant.lastPostTimeReversed: 'Latest reply last',
		CatalogVariant.replyCount: 'Most replies',
		CatalogVariant.replyCountReversed: 'Least replies',
		CatalogVariant.threadPostTime: 'Newest threads',
		CatalogVariant.threadPostTimeReversed: 'Oldest threads',
		CatalogVariant.savedTime: 'Newest saved',
		CatalogVariant.savedTimeReversed: 'Oldest saved',
		CatalogVariant.postsPerMinute: 'Fastest threads',
		CatalogVariant.postsPerMinuteReversed: 'Slowest threads',
		CatalogVariant.lastReplyTime: 'Latest reply first',
		CatalogVariant.lastReplyTimeReversed: 'Latest reply last',
		CatalogVariant.imageCount: 'Most images',
		CatalogVariant.imageCountReversed: 'Least images',
		CatalogVariant.lastReplyByYouTime: 'Latest reply by you',
		CatalogVariant.lastReplyByYouTimeReversed: 'Oldest reply by you',
		CatalogVariant.redditHot: 'Hot',
		CatalogVariant.redditNew: 'New',
		CatalogVariant.redditRising: 'Rising',
		CatalogVariant.redditControversialPastHour: 'Hour',
		CatalogVariant.redditControversialPast24Hours: 'Day',
		CatalogVariant.redditControversialPastWeek: 'Week',
		CatalogVariant.redditControversialPastMonth: 'Month',
		CatalogVariant.redditControversialPastYear: 'Year',
		CatalogVariant.redditControversialAllTime: 'All time',
		CatalogVariant.redditTopPastHour: 'Hour',
		CatalogVariant.redditTopPast24Hours: 'Day',
		CatalogVariant.redditTopPastWeek: 'Week',
		CatalogVariant.redditTopPastMonth: 'Month',
		CatalogVariant.redditTopPastYear: 'Year',
		CatalogVariant.redditTopAllTime: 'All time',
		CatalogVariant.chan4NativeArchive: 'Archive',
		CatalogVariant.hackerNewsTop: 'Top',
		CatalogVariant.hackerNewsNew: 'New',
		CatalogVariant.hackerNewsBest: 'Best',
		CatalogVariant.hackerNewsAsk: 'Ask HN',
		CatalogVariant.hackerNewsShow: 'Show HN',
		CatalogVariant.hackerNewsJobs: 'Jobs'
	}[this]!;
	bool get countsUnreliable {
		switch (this) {
			case CatalogVariant.chan4NativeArchive:
				return true;
			default:
				return false;
		}
	}
	String get dataId {
		switch (this) {
			case CatalogVariant.unsorted:
			case CatalogVariant.unsortedReversed:
			case CatalogVariant.lastPostTime:
			case CatalogVariant.lastPostTimeReversed:
			case CatalogVariant.replyCount:
			case CatalogVariant.replyCountReversed:
			case CatalogVariant.threadPostTime:
			case CatalogVariant.threadPostTimeReversed:
			case CatalogVariant.savedTime:
			case CatalogVariant.savedTimeReversed:
			case CatalogVariant.postsPerMinute:
			case CatalogVariant.postsPerMinuteReversed:
			case CatalogVariant.lastReplyTime:
			case CatalogVariant.lastReplyTimeReversed:
			case CatalogVariant.imageCount:
			case CatalogVariant.imageCountReversed:
			case CatalogVariant.lastReplyByYouTime:
			case CatalogVariant.lastReplyByYouTimeReversed:
				return '';
			default:
				return toString();
		}
	}

	static CatalogVariant migrate(ThreadSortingMethod? sortingMethod, bool? reverseSorting) {
		final method = sortingMethod ?? ThreadSortingMethod.unsorted;
		final reverse = reverseSorting ?? false;
		switch (method) {
			case ThreadSortingMethod.unsorted:
				return reverse ? CatalogVariant.unsortedReversed : CatalogVariant.unsorted;
			case ThreadSortingMethod.lastPostTime:
				return reverse ? CatalogVariant.lastPostTimeReversed : CatalogVariant.lastPostTime;
			case ThreadSortingMethod.replyCount:
				return reverse ? CatalogVariant.replyCountReversed : CatalogVariant.replyCount;
			case ThreadSortingMethod.threadPostTime:
				return reverse ? CatalogVariant.threadPostTimeReversed : CatalogVariant.threadPostTime;
			case ThreadSortingMethod.savedTime:
				return reverse ? CatalogVariant.savedTimeReversed : CatalogVariant.savedTime;
			case ThreadSortingMethod.postsPerMinute:
				return reverse ? CatalogVariant.postsPerMinuteReversed : CatalogVariant.postsPerMinute;
			case ThreadSortingMethod.lastReplyTime:
				return reverse ? CatalogVariant.lastReplyTimeReversed : CatalogVariant.lastReplyTime;
			case ThreadSortingMethod.imageCount:
				return reverse ? CatalogVariant.imageCountReversed : CatalogVariant.imageCount;
			case ThreadSortingMethod.lastReplyByYouTime:
				return reverse ? CatalogVariant.lastReplyByYouTimeReversed : CatalogVariant.lastReplyByYouTime;
		}
	}
}

class CatalogVariantGroup {
	final String name;
	final List<CatalogVariant> variants;
	final bool hasPrimary;
	const CatalogVariantGroup({
		required this.name,
		required this.variants,
		this.hasPrimary = false
	});
}

@HiveType(typeId: 34)
enum ThreadVariant {
	@HiveField(0)
	redditTop,
	@HiveField(1)
	redditBest,
	@HiveField(2)
	redditNew,
	@HiveField(3)
	redditControversial,
	@HiveField(4)
	redditOld,
	@HiveField(5)
	redditQandA
}

extension ThreadVariantMetadata on ThreadVariant {
	String get dataId => toString();
	IconData get icon => const {
		ThreadVariant.redditTop: CupertinoIcons.arrow_up,
		ThreadVariant.redditBest: CupertinoIcons.star,
		ThreadVariant.redditNew: CupertinoIcons.clock,
		ThreadVariant.redditControversial: CupertinoIcons.exclamationmark_shield,
		ThreadVariant.redditOld: CupertinoIcons.clock,
		ThreadVariant.redditQandA: CupertinoIcons.chat_bubble_2
	}[this]!;
	String get name => const {
		ThreadVariant.redditTop: 'Top',
		ThreadVariant.redditBest: 'Best',
		ThreadVariant.redditNew: 'New',
		ThreadVariant.redditControversial: 'Controversial',
		ThreadVariant.redditOld: 'Old',
		ThreadVariant.redditQandA: 'Q&A'
	}[this]!;
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

	const ImageboardArchiveSearchResult.post(Post this.post) : thread = null;
	const ImageboardArchiveSearchResult.thread(Thread this.thread) : post = null;

	ThreadIdentifier get threadIdentifier => (post?.threadIdentifier ?? thread?.identifier)!;
	int get id => (post?.id ?? thread?.id)!;

	@override toString() => 'ImageboardArchiveSearchResult(${post ?? thread})';
}

class ImageboardArchiveSearchResultPage {
	final List<ImageboardArchiveSearchResult> posts;
	final int page;
	final int? maxPage;
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
				options.headers['user-agent'] ??= userAgent;
				handler.next(options);
			}
		));
		client.interceptors.add(CloudflareInterceptor());
	}
	String get name;
	Future<Post> getPost(String board, int id);
	Future<Thread> getThread(ThreadIdentifier thread, {ThreadVariant? variant});
	Future<List<Thread>> getCatalog(String board, {CatalogVariant? variant});
	Future<List<ImageboardBoard>> getBoards();
	Future<ImageboardArchiveSearchResultPage> search(ImageboardArchiveSearchQuery query, {required int page, ImageboardArchiveSearchResultPage? lastResult});
	String getWebUrl(String board, [int? threadId, int? postId]);
	Future<BoardThreadOrPostIdentifier?> decodeUrl(String url);
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
	Uri get passIconUrl => Uri.https('boards.chance.surf', '/minileaf.gif');
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
				final thread_ = await archive.getThread(thread).timeout(const Duration(seconds: 10));
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
	Future<ImageboardArchiveSearchResultPage> search(ImageboardArchiveSearchQuery query, {required int page, ImageboardArchiveSearchResultPage? lastResult}) async {
		String s = '';
		for (final archive in archives) {
			try {
				return await archive.search(query, page: page, lastResult: lastResult);
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
	List<ImageboardEmote> getEmotes() => [];
	Future<List<ImageboardBoardFlag>> getBoardFlags(String board) async => [];
	String get siteType;
	String get siteData;
	String get defaultUsername;
	List<ImageboardSnippet> getBoardSnippets(String board) => [];
	CaptchaRequest? getBannedCaptchaRequest(bool cloudflare) => null;
	Future<String> getBannedReason(CaptchaSolution captchaSolution) async => 'Unknown';
	Future<List<ImageboardBoard>> getBoardsForQuery(String query) async => [];
	bool get allowsArbitraryBoards => false;
	bool get classicCatalogStyle => true;
	bool get explicitIds => true;
	bool get useTree => false;
	bool get showImageCount => true;
	bool get supportsSearch => archives.isNotEmpty;
	bool get supportsPosting => true;
	Future<List<Post>> getMoreThread(Post after) async => throw UnimplementedError();
	/// If an empty list is returned from here, the bottom of the catalog has been reached.
	Future<List<Thread>> getMoreCatalog(Thread after) async => [];
	bool get hasOmittedReplies => false;
	bool get isHackerNews => false;
	bool get isReddit => false;
	bool get supportsMultipleBoards => true;
	bool get supportsSearchOptions => true;
	bool get supportsPushNotifications => false;
	List<CatalogVariantGroup> get catalogVariantGroups => const [
		CatalogVariantGroup(
			name: 'Bump order',
			variants: [CatalogVariant.unsorted, CatalogVariant.unsortedReversed],
			hasPrimary: true
		),
		CatalogVariantGroup(
			name: 'Reply count',
			variants: [CatalogVariant.replyCount, CatalogVariant.replyCountReversed],
			hasPrimary: true
		),
		CatalogVariantGroup(
			name: 'Creation date',
			variants: [CatalogVariant.threadPostTime, CatalogVariant.threadPostTimeReversed],
			hasPrimary: true
		),
		CatalogVariantGroup(
			name: 'Reply rate',
			variants: [CatalogVariant.postsPerMinute, CatalogVariant.postsPerMinuteReversed],
			hasPrimary: true
		),
		CatalogVariantGroup(
			name: 'Last reply',
			variants: [CatalogVariant.lastReplyTime, CatalogVariant.lastReplyTimeReversed],
			hasPrimary: true
		),
		CatalogVariantGroup(
			name: 'Image count',
			variants: [CatalogVariant.imageCount, CatalogVariant.imageCountReversed],
			hasPrimary: true
		)
	];
	List<ThreadVariant> get threadVariants => const [];
}

ImageboardSite makeSite(dynamic data) {
	if (data['type'] == 'lainchan') {
		return SiteLainchan(
			name: data['name'],
			baseUrl: data['baseUrl'],
			maxUploadSizeBytes: data['maxUploadSizeBytes']
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
	else if (data['type'] == 'reddit') {
		return SiteReddit();
	}
	else if (data['type'] == 'hackernews') {
		return SiteHackerNews();
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
						boards: boards,
						useRandomUseragent: archive['useRandomUseragent'] ?? false
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
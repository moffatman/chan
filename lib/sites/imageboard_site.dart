// ignore_for_file: argument_type_not_assignable
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chan/main.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/flag.dart';
import 'package:chan/models/parent_and_child.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/search.dart';
import 'package:chan/services/cloudflare.dart';
import 'package:chan/services/cookies.dart';
import 'package:chan/services/http_429_backoff.dart';
import 'package:chan/services/http_client.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/network_logging.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/request_fixup.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/strict_json.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/4chan.dart';
import 'package:chan/sites/8chan.dart';
import 'package:chan/sites/8kun.dart';
import 'package:chan/sites/dvach.dart';
import 'package:chan/sites/erischan.dart';
import 'package:chan/sites/foolfuuka.dart';
import 'package:chan/sites/frenschan.dart';
import 'package:chan/sites/futaba.dart';
import 'package:chan/sites/fuuka.dart';
import 'package:chan/sites/hacker_news.dart';
import 'package:chan/sites/jforum.dart';
import 'package:chan/sites/jschan.dart';
import 'package:chan/sites/karachan.dart';
import 'package:chan/sites/lainchan.dart';
import 'package:chan/sites/lainchan_org.dart';
import 'package:chan/sites/lynxchan.dart';
import 'package:chan/sites/reddit.dart';
import 'package:chan/sites/soyjak.dart';
import 'package:chan/sites/lainchan2.dart';
import 'package:chan/sites/wizchan.dart';
import 'package:chan/sites/xenforo.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/attachment_viewer.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/thread.dart';

import 'package:dio/dio.dart';

part 'imageboard_site.g.dart';

const _preferredArchiveApiRoot = 'https://push.chance.surf';
const kPriority = 'priority';
enum RequestPriority {
	interactive,
	functional,
	cosmetic
}

class PostNotFoundException extends ExtendedException {
	String board;
	int id;
	PostNotFoundException(this.board, this.id);
	@override
	String toString() => 'Post not found: /$board/$id';

	@override
	bool get isReportable => false;
}

class ThreadNotFoundException extends ExtendedException {
	const ThreadNotFoundException();
	@override
	String toString() => 'Thread not found';

	@override
	bool get isReportable => false;
}

class BoardNotFoundException implements Exception {
	String board;
	BoardNotFoundException(this.board);
	@override
	String toString() => 'Board not found: /$board/';
}

class BoardNotArchivedException extends ExtendedException {
	String board;
	BoardNotArchivedException(this.board);
	@override
	String toString() => 'Board not archived: /$board/';

	@override
	bool get isReportable => false;
}

const kHttpStatusCodes = {
	100: 'Continue',
	101: 'Switching Protocols',
	102: 'Processing',
	103: 'Early Hints',
	200: 'OK',
	201: 'Created',
	202: 'Accepted',
	203: 'Non-Authoritative Information',
	204: 'No Content',
	205: 'Reset Content',
	206: 'Partial Content',
	207: 'Multi-Status',
	208: 'Already Reported',
	226: 'IM Used',
	300: 'Multiple Choices',
	301: 'Moved Permanently',
	302: 'Found',
	303: 'See Other',
	304: 'Not Modified',
	307: 'Temporary Redirect',
	400: 'Bad Request',
	401: 'Unauthorized',
	402: 'Payment Required',
	403: 'Forbidden',
	404: 'Not Found',
	405: 'Method Not Allowed',
	406: 'Not Acceptable',
	407: 'Proxy Authentication Required',
	408: 'Request',
	409: 'Conflict',
	410: 'Gone',
	411: 'Length Required',
	412: 'Precondition',
	413: 'Request Entity Too Large',
	414: 'Request-URI Too Long',
	415: 'Unsupported Media Type',
	416: 'Requested Range Not Satisfiable',
	417: 'Expectation Failed',
	418: 'I\'m a teapot',
	421: 'Misdirected Request',
	422: 'Unprocessable Content',
	423: 'Locked',
	424: 'Failed Dependency',
	425: 'Too Early',
	426: 'Upgrade Required',
	428: 'Precondition Required',
	429: 'Too Many Requests',
	431: 'Request Header Fields Too Large',
	451: 'Unavailable For Legal Reasons',
	500: 'Internal Server Error',
	501: 'Not Implemented',
	502: 'Bad Gateway',
	503: 'Service Unavailable',
	504: 'Gateway Timeout',
	505: 'HTTP Version Not Supported',
	506: 'Variant Also Negotiates',
	507: 'Insufficient Storage',
	508: 'Loop Detected',
	510: 'Not Extended',
	511: 'Network Authentication Required',
	522: 'Connection timeout between Cloudflare and origin server',
	525: 'SSL handshake failed between Cloudflare and origin server'
};

class HTTPStatusException implements Exception {
	final Uri url;
	int code;
	HTTPStatusException(this.url, this.code);
	HTTPStatusException.fromResponse(Response response)
		: url = response.requestOptions.uri, code = response.statusCode ?? 0;
	@override
	String toString() => 'HTTP Error $code (url: $url, meaning: ${kHttpStatusCodes[code] ?? 'unknown'})';
}

class CooldownException implements Exception {
	final DateTime tryAgainAt;
	const CooldownException(this.tryAgainAt);
	@override
	String toString() => 'Try again at $tryAgainAt';
}

class PostFailedException extends ExtendedException {
	String reason;
	@override
	final Map<String, FutureOr<void> Function(BuildContext)> remedies;
	PostFailedException(this.reason, {this.remedies = const {}});
	@override
	String toString() => 'Posting failed: $reason';
	
	@override
	bool get isReportable => true;
}

class PostCooldownException extends CooldownException {
	final String message;
	const PostCooldownException(this.message, super.tryAgainAt);
	@override
	String toString() => 'PostCooldownException: $message, try again at $tryAgainAt';
}

class WebAuthenticationRequiredException implements Exception {
	const WebAuthenticationRequiredException();
	@override
	String toString() => 'Web authentication required';
}

class WebGatewayException extends ExtendedException {
	final ImageboardSite site;
	final Uri url;
	const WebGatewayException(this.site, this.url);
	@override
	bool get isReportable => false;
	Future<void> openWebGateway(BuildContext context) async {
		await site.client.getUri(url, options: Options(
			extra: {
				kCloudflare: true,
				kPriority: RequestPriority.interactive
			}
		));
	}
	@override
	get remedies => {
		'Login': openWebGateway
	};
	@override
	String toString() => 'Web login required: $url';
}

class BannedException implements Exception {
	String reason;
	Uri? url;
	BannedException(this.reason, this.url);
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
	Map<ImageboardSiteArchive, Object> archiveErrors;
	ImageboardArchiveException(this.archiveErrors);
	@override
	String toString() => archiveErrors.entries.map((e) => '${e.key.name}: ${e.value.toStringDio()}').join('\n');
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

class ReportFailedException implements Exception {
	final String message;
	const ReportFailedException(this.message);
	@override
	String toString() => 'Report failed: $message';
}

class AdditionalCaptchaRequiredException implements Exception {
	final CaptchaRequest captchaRequest;
	final Future<void> Function(CaptchaSolution, CancelToken) onSolved;
	const AdditionalCaptchaRequiredException({
		required this.captchaRequest,
		required this.onSolved
	});
	@override
	String toString() => 'Additional captcha needed';
}

class DuplicateFileException extends ExtendedException {
	final String link;

	const DuplicateFileException(this.link);

	@override
	Map<String, FutureOr<void> Function(BuildContext)> get remedies => {
		'Go to post': (_) => fakeLinkStream.add(link)
	};

	@override
	String toString() => 'Duplicate file exists';
	
	@override
	bool get isReportable => false;
}

enum ImageboardAction {
	postThread(
		verbSimplePresentLowercase: 'create thread',
		nounSingularLowercase: 'thread',
		nounSingularCapitalized: 'Thread',
		nounPluralCapitalized: 'Threads'
	),
	postReply(
		verbSimplePresentLowercase: 'reply',
		nounSingularLowercase: 'reply',
		nounSingularCapitalized: 'Reply',
		nounPluralCapitalized: 'Replies'
	),
	postReplyWithImage(
		verbSimplePresentLowercase: 'reply with image',
		nounSingularLowercase: 'image',
		nounSingularCapitalized: 'Image',
		nounPluralCapitalized: 'Images'
	),
	report(
		verbSimplePresentLowercase: 'report',
		nounSingularLowercase: 'report',
		nounSingularCapitalized: 'Report',
		nounPluralCapitalized: 'Reports'
	),
	delete(
		verbSimplePresentLowercase: 'delete',
		nounSingularLowercase: 'deletion',
		nounSingularCapitalized: 'Deletion',
		nounPluralCapitalized: 'Deletions'
	);
	const ImageboardAction({
		required this.verbSimplePresentLowercase,
		required this.nounSingularLowercase,
		required this.nounSingularCapitalized,
		required this.nounPluralCapitalized
	});
	final String verbSimplePresentLowercase;
	final String nounSingularLowercase;
	final String nounSingularCapitalized;
	final String nounPluralCapitalized;
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
	hackerNewsJobs,
	@HiveField(40)
	hackerNewsSecondChancePool,
	@HiveField(41)
	alphabeticByTitle,
	@HiveField(42)
	alphabeticByTitleReversed,
	@HiveField(43)
	postsPerMinuteWithNewThreadsAtTop,
	@HiveField(44)
	postsPerMinuteWithNewThreadsAtTopReversed;
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
			case CatalogVariant.alphabeticByTitle:
			case CatalogVariant.alphabeticByTitleReversed:
				return ThreadSortingMethod.alphabeticByTitle;
			case CatalogVariant.postsPerMinuteWithNewThreadsAtTop:
			case CatalogVariant.postsPerMinuteWithNewThreadsAtTopReversed:
				return ThreadSortingMethod.postsPerMinuteWithNewThreadsAtTop;
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
			case CatalogVariant.alphabeticByTitleReversed:
			case CatalogVariant.postsPerMinuteWithNewThreadsAtTopReversed:
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
	IconData? get icon => {
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
		CatalogVariant.imageCount: Adaptive.icons.photo,
		CatalogVariant.imageCountReversed: Adaptive.icons.photo,
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
		CatalogVariant.hackerNewsJobs: CupertinoIcons.briefcase,
		CatalogVariant.hackerNewsSecondChancePool: CupertinoIcons.arrow_2_circlepath,
		CatalogVariant.alphabeticByTitle: CupertinoIcons.textformat,
		CatalogVariant.alphabeticByTitleReversed: CupertinoIcons.textformat,
		CatalogVariant.postsPerMinuteWithNewThreadsAtTop: CupertinoIcons.speedometer,
		CatalogVariant.postsPerMinuteWithNewThreadsAtTopReversed: CupertinoIcons.speedometer,
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
		CatalogVariant.hackerNewsJobs: 'Jobs',
		CatalogVariant.hackerNewsSecondChancePool: 'Second Chance',
		CatalogVariant.alphabeticByTitle: 'A-Z by title',
		CatalogVariant.alphabeticByTitleReversed: 'Z-A by title',
		CatalogVariant.postsPerMinuteWithNewThreadsAtTop: 'Fastest threads (+new first)',
		CatalogVariant.postsPerMinuteWithNewThreadsAtTopReversed: 'Slowest threads (+new last)',
	}[this]!;
	bool? get hasPagedCatalog {
		switch (this) {
			case CatalogVariant.chan4NativeArchive:
				return true;
			default:
				return null;
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
			case CatalogVariant.alphabeticByTitle:
			case CatalogVariant.alphabeticByTitleReversed:
			case CatalogVariant.postsPerMinuteWithNewThreadsAtTop:
			case CatalogVariant.postsPerMinuteWithNewThreadsAtTopReversed:
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
			case ThreadSortingMethod.alphabeticByTitle:
				return reverse ? CatalogVariant.alphabeticByTitleReversed : CatalogVariant.alphabeticByTitle;
			case ThreadSortingMethod.postsPerMinuteWithNewThreadsAtTop:
				return reverse ? CatalogVariant.postsPerMinuteWithNewThreadsAtTopReversed : CatalogVariant.postsPerMinuteWithNewThreadsAtTop;
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

@HiveType(typeId: 41)
enum PostSortingMethod {
	@HiveField(0)
	none,
	@HiveField(1)
	replyCount;
	String get displayName => switch (this) {
		none => 'None',
		replyCount => 'Reply Count'
	};
}

sealed class CaptchaRequest {
	bool get cloudSolveSupported => false;
	const CaptchaRequest();
}

class NoCaptchaRequest extends CaptchaRequest {
  const NoCaptchaRequest();
}

class RecaptchaRequest extends CaptchaRequest {
	final String key;
	final String sourceUrl;
	final bool cloudflare;
	const RecaptchaRequest({
		required this.key,
		required this.sourceUrl,
		required this.cloudflare
	});
	@override
	String toString() => 'RecaptchaRequest(sourceUrl: $sourceUrl, key: $key)';
}

class Recaptcha3Request extends CaptchaRequest {
	final String key;
	final String sourceUrl;
	final String? action;
	const Recaptcha3Request({
		required this.key,
		required this.sourceUrl,
		required this.action
	});
	@override
	String toString() => 'Recaptcha3Request(sourceUrl: $sourceUrl, key: $key, action: $action)';
}

class Chan4CustomCaptchaRequest extends CaptchaRequest {
	final Uri challengeUrl;
	final Map<String, String> challengeHeaders;
	final List<int> possibleLetterCounts;
	final String? hCaptchaKey;
	final bool stickyCloudflare;
	final List<String> letters;
	final Map<String, String> lettersRemap;

	const Chan4CustomCaptchaRequest({
		required this.challengeUrl,
		required this.challengeHeaders,
		required this.possibleLetterCounts,
		required this.hCaptchaKey,
		required this.stickyCloudflare,
		required this.letters,
		required this.lettersRemap
	});
	@override
	String toString() => 'Chan4CustomCaptchaRequest(challengeUrl: $challengeUrl, challengeHeaders: $challengeHeaders, possibleLetterCounts: $possibleLetterCounts, hCaptchaKey: $hCaptchaKey, stickyCloudflare: $stickyCloudflare, letters: $letters, lettersRemap: $lettersRemap)';

	@override
	bool get cloudSolveSupported => true;

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is Chan4CustomCaptchaRequest &&
		other.challengeUrl == challengeUrl &&
		mapEquals(other.challengeHeaders, challengeHeaders) &&
		listEquals(other.possibleLetterCounts, possibleLetterCounts) &&
		other.hCaptchaKey == hCaptchaKey &&
		other.stickyCloudflare == stickyCloudflare &&
		listEquals(other.letters, letters) &&
		mapEquals(other.lettersRemap, lettersRemap);
	
	@override
	int get hashCode => Object.hash(challengeUrl, hCaptchaKey);
}

class SecurimageCaptchaRequest extends CaptchaRequest {
	final Uri challengeUrl;
	const SecurimageCaptchaRequest({
		required this.challengeUrl
	});
	@override
	String toString() => 'SecurimageCaptchaRequest(challengeUrl: $challengeUrl)';
}

class DvachCaptchaRequest extends CaptchaRequest {
	final Duration challengeLifetime;
	const DvachCaptchaRequest({
		required this.challengeLifetime
	});
}

class DvachEmojiCaptchaRequest extends CaptchaRequest {
	final Duration challengeLifetime;
	const DvachEmojiCaptchaRequest({
		required this.challengeLifetime
	});
}

class LynxchanCaptchaRequest extends CaptchaRequest {
	final String board;
	/// Force use of webview/RedirectGateway
	final ImageboardRedirectGateway? redirectGateway;
	const LynxchanCaptchaRequest({
		required this.board,
		this.redirectGateway
	});
	@override
	String toString() => 'LynxchanCaptchaRequest(board: $board, redirectGateway: $redirectGateway)';
}

class SecucapCaptchaRequest extends CaptchaRequest {
	final Uri challengeUrl;
	const SecucapCaptchaRequest({
		required this.challengeUrl
	});
	@override
	String toString() => 'SecucapCaptchaRequest(challengeUrl: $challengeUrl)';
}

class McCaptchaRequest extends CaptchaRequest {
	final Uri challengeUrl;
	final String? question;
	const McCaptchaRequest({
		required this.challengeUrl,
		required this.question
	});
	@override
	String toString() => 'McCaptchaRequest(challengeUrl: $challengeUrl, question: $question)';
}

class JsChanCaptchaRequest extends CaptchaRequest {
	final Uri challengeUrl;
	final String type;
	const JsChanCaptchaRequest({
		required this.challengeUrl,
		required this.type
	});
	@override
	String toString() => 'JsChanCaptchaRequest(challengeUrl: $challengeUrl, type: $type)';
}

class HCaptchaRequest extends CaptchaRequest {
	final Uri hostPage;
	final String siteKey;
	const HCaptchaRequest({
		required this.hostPage,
		required this.siteKey
	});
	@override
	String toString() => 'HCaptchaRequest(hostPage: $hostPage, siteKey: $siteKey)';
}

class SimpleTextCaptchaRequest extends CaptchaRequest {
	final String question;
	final DateTime acquiredAt;
	const SimpleTextCaptchaRequest({
		required this.question,
		required this.acquiredAt
	});
	@override
	String toString() => 'SimpleTextCaptchaRequest(question: $question, acquiredAt: $acquiredAt)';
}

class CloudflareTurnstileCaptchaRequest extends CaptchaRequest {
	final String siteKey;
	final Uri hostPage;
	const CloudflareTurnstileCaptchaRequest({
		required this.siteKey,
		required this.hostPage
	});
	@override
	String toString() => 'CloudflareTurnstileCaptchaRequest(siteKey: $siteKey, hostPage: $hostPage)';
}

abstract class CaptchaSolution {
	DateTime? get expiresAt;
	final DateTime acquiredAt;
	final bool cloudflare;
	final bool autoSolved;
	final String? ip;
	const CaptchaSolution({
		required this.acquiredAt,
		this.cloudflare = false,
		this.autoSolved = false,
		this.ip
	});

	@mustCallSuper
	void dispose() {}
}

class NoCaptchaSolution extends CaptchaSolution {
	@override
	DateTime? get expiresAt => null;
	NoCaptchaSolution(DateTime acquiredAt) : super(acquiredAt: acquiredAt);
}

class RecaptchaSolution extends CaptchaSolution {
	final String response;
	RecaptchaSolution({
		required this.response,
		required super.cloudflare,
		required super.acquiredAt
	});
	@override
	DateTime? get expiresAt => null;
	@override
	String toString() => 'RecaptchaSolution(response: $response)';
}

class Recaptcha3Solution extends CaptchaSolution {
	final String response;
	Recaptcha3Solution({
		required this.response,
		required super.acquiredAt
	});
	@override
	DateTime? get expiresAt => acquiredAt.add(const Duration(seconds: 120));
	@override
	String toString() => 'Recaptcha3Solution(response: $response)';
}

class Chan4CustomCaptchaSolution extends CaptchaSolution {
	final String challenge;
	final String response;
	final int? slide;
	final Map<String, dynamic> originalData;
	final Duration lifetime;
	Chan4CustomCaptchaSolution({
		required this.challenge,
		required this.response,
		required super.acquiredAt,
		required this.lifetime,
		required this.slide,
		required this.originalData,
		required super.cloudflare,
		required super.ip,
		super.autoSolved
	});
	@override
	DateTime? get expiresAt => acquiredAt.add(lifetime);
	@override
	String toString() => 'Chan4CustomCaptchaSolution(challenge: $challenge, response: $response)';
}

class SecurimageCaptchaSolution extends CaptchaSolution {
	final String cookie;
	final String response;
	final Duration lifetime;
	@override
	DateTime? get expiresAt => acquiredAt.add(lifetime);
	SecurimageCaptchaSolution({
		required this.cookie,
		required this.response,
		required super.acquiredAt,
		required this.lifetime
	});
	@override
	String toString() => 'SecurimageCaptchaSolution(cookie: $cookie, response: $response)';
}

class DvachCaptchaSolution extends CaptchaSolution {
	final String id;
	final String response;
	final Duration lifetime;
	@override
	DateTime? get expiresAt => acquiredAt.add(lifetime);
	DvachCaptchaSolution({
		required this.id,
		required this.response,
		required super.acquiredAt,
		required this.lifetime
	});
	@override
	String toString() => 'DvachCaptchaSolution(id: $id, response: $response)';
}

class DvachEmojiCaptchaSolution extends CaptchaSolution {
	final String id;
	final Duration lifetime;
	@override
	DateTime? get expiresAt => acquiredAt.add(lifetime);
	DvachEmojiCaptchaSolution({
		required this.id,
		required super.acquiredAt,
		required this.lifetime
	});
	@override
	String toString() => 'DvachEmojiCaptchaSolution(id: $id)';
}

class LynxchanCaptchaSolution extends CaptchaSolution {
	final String id;
	final String answer;
	final Duration lifetime;
	@override
	DateTime? get expiresAt => acquiredAt.add(lifetime);
	LynxchanCaptchaSolution({
		required this.id,
		required this.answer,
		required super.acquiredAt,
		required this.lifetime
	});
	@override
	String toString() => 'LynxchanCaptchaSolution(id: $id)';
}

class SecucapCaptchaSolution extends CaptchaSolution {
	final String response;
	@override
	DateTime? get expiresAt => null;
	SecucapCaptchaSolution({
		required this.response,
		required super.acquiredAt
	});
	@override
	String toString() => 'SecucapCaptchaSolution(response: $response)';
}

class McCaptchaSolution extends CaptchaSolution {
	final String guid;
	final int x;
	final int y;
	final String answer;
	@override
	DateTime? get expiresAt => acquiredAt.add(const Duration(seconds: 90));
	McCaptchaSolution({
		required super.acquiredAt,
		required this.guid,
		required this.x,
		required this.y,
		required this.answer
	});
	@override
	String toString() => 'McCaptchaSolution(guid: $guid, x: $x, y: $y, answer: $answer)';
}

abstract class JsChanCaptchaSolution extends CaptchaSolution {
	final String id;
	JsChanCaptchaSolution({
		required this.id,
		required super.acquiredAt
	});
}

class JsChanGridCaptchaSolution extends JsChanCaptchaSolution {
	///  0  1  2  3
	///  4  5  6  7
	///  8  9 10 11
	/// 12 13 14 15
	final Set<int> selected;
	final Duration lifetime;
	@override
	DateTime? get expiresAt => acquiredAt.add(lifetime);

	JsChanGridCaptchaSolution({
		required super.acquiredAt,
		required super.id,
		required this.selected,
		required this.lifetime
	});
	@override
	String toString() => 'JsChanGridCaptchaSolution(id: $id, selected: $selected, lifetime: $lifetime)';
}

class JsChanTextCaptchaSolution extends JsChanCaptchaSolution {
	final String text;
	final Duration lifetime;
	@override
	DateTime? get expiresAt => acquiredAt.add(lifetime);

	JsChanTextCaptchaSolution({
		required super.acquiredAt,
		required super.id,
		required this.text,
		required this.lifetime
	});
	@override
	String toString() => 'JsChanTextCaptchaSolution(id: $id, text: $text, lifetime: $lifetime)';
}

class HCaptchaSolution extends CaptchaSolution {
	/// From hcaptcha docs
	static const kLifetime = Duration(seconds: 120);
	final String token;
	@override
	DateTime? get expiresAt => acquiredAt.add(kLifetime);

	HCaptchaSolution({
		required super.acquiredAt,
		required this.token
	});
	@override
	String toString() => 'HCaptchaSolution(token: $token)';
}

class SimpleTextCaptchaSolution extends CaptchaSolution {
	final String answer;
	final Duration? lifetime;
	@override
	DateTime? get expiresAt => lifetime == null ? null : acquiredAt.add(lifetime!);
	SimpleTextCaptchaSolution({
		required this.answer,
		required super.acquiredAt,
		this.lifetime
	});
	@override
	String toString() => 'SimpleTextCaptchaSolution(answer: $answer, lifetime: $lifetime)';
}

class CloudflareTurnstileCaptchaSolution extends CaptchaSolution {
	/// From google
	static const kLifetime = Duration(minutes: 5);
	final String token;
	@override
	DateTime? get expiresAt => acquiredAt.add(kLifetime);
	CloudflareTurnstileCaptchaSolution({
		required super.acquiredAt,
		required this.token
	});
	@override
	String toString() => 'CloudflareTurnstileCaptchaSolution(token: $token)';
}

class ImageboardArchiveSearchResult {
	final Post? post;
	final Thread? thread;

	const ImageboardArchiveSearchResult.post(Post this.post) : thread = null;
	const ImageboardArchiveSearchResult.thread(Thread this.thread) : post = null;

	ThreadIdentifier get threadIdentifier => (post?.threadIdentifier ?? thread?.identifier)!;
	int get id => (post?.id ?? thread?.id)!;

	@override toString() => 'ImageboardArchiveSearchResult(${post ?? thread})';

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		(other is ImageboardArchiveSearchResult) &&
		(other.post == post) &&
		(other.thread == thread);
	
	@override
	int get hashCode => Object.hash(post, thread);
}

class ImageboardArchiveSearchResultPage {
	final List<ImageboardArchiveSearchResult> posts;
	final bool replyCountsUnreliable;
	final bool imageCountsUnreliable;
	final int? count;
	final int page;
	final int? maxPage;
	final bool canJumpToArbitraryPage;
	final ImageboardSiteArchive archive;
	final Map<String, Object> memo;
	ImageboardArchiveSearchResultPage({
		required this.posts,
		required this.replyCountsUnreliable,
		required this.imageCountsUnreliable,
		required this.count,
		required this.page,
		required this.maxPage,
		required this.archive,
		required this.canJumpToArbitraryPage,
		this.memo = const {}
	});
}

class ImageboardSiteLoginField {
	final String displayName;
	final String formKey;
	final TextInputType? inputType;
	final List<String>? autofillHints;
	const ImageboardSiteLoginField({
		required this.displayName,
		required this.formKey,
		this.inputType,
		this.autofillHints
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

@HiveType(typeId: 46)
class ImageboardBoardFlag implements ImageboardFlag {
	@HiveField(0)
	final String code;
	@override
	@HiveField(1)
	final String name;
	@override
	@HiveField(2)
	final String imageUrl;
	const ImageboardBoardFlag({
		required this.code,
		required this.name,
		required this.imageUrl
	});

	@override
	double get imageWidth => 16;
	@override
	double get imageHeight => 16;
	@override
	List<ImageboardFlag> get parts => [this];

	@override
	bool operator == (Object other) =>
		other is ImageboardBoardFlag &&
		other.code == code &&
		other.name == name &&
		other.imageUrl == imageUrl;
	
	@override
	int get hashCode => Object.hash(code, name, imageUrl);
}

class ImageboardSnippet {
	final IconData icon;
	final String name;
	final (String, String)? _caps;
	final String Function(String)? _wrap;
	final PostSpan Function(String text)? previewBuilder;
	const ImageboardSnippet.simple({
		required this.icon,
		required this.name,
		required String start,
		required String end,
		this.previewBuilder
	}) : _caps = (start, end), _wrap = null;

	const ImageboardSnippet.complex({
		required this.icon,
		required this.name,
		required String Function(String) wrap,
		this.previewBuilder
	}) : _wrap = wrap, _caps = null;

	String wrap(String content) {
		return _wrap?.call(content) ?? '${_caps?.$1}$content${_caps?.$2}';
	}
}

String _wrapQuoteSnippet(String content) {
	return '>${content.replaceAll('\n', '\n>')}';
}

PostQuoteSpan _previewQuoteSnippet(String content) {
	return PostQuoteSpan(PostTextSpan(_wrapQuoteSnippet(content)));
}

const greentextSnippet = ImageboardSnippet.complex(
	icon: CupertinoIcons.chevron_right,
	name: 'Greentext',
	wrap: _wrapQuoteSnippet,
	previewBuilder: _previewQuoteSnippet
);

class SnippetPreviewBuilders {
	static PostSpan bold(String input) => PostBoldSpan(PostTextSpan(input));
	static PostSpan italic(String input) => PostItalicSpan(PostTextSpan(input));
	static PostSpan underline(String input) => PostUnderlinedSpan(PostTextSpan(input));
	static PostSpan overline(String input) => PostOverlinedSpan(PostTextSpan(input));
	static PostSpan strikethrough(String input) => PostStrikethroughSpan(PostTextSpan(input));
	static PostSpan superscript(String input) => PostSuperscriptSpan(PostTextSpan(input));
	static PostSpan subscript(String input) => PostSubscriptSpan(PostTextSpan(input));
}

class ImageboardSearchOptions {
	final bool text;
	final bool name;
	final bool date;
	final bool imageMD5;
	final bool subject;
	final bool trip;
	final bool isDeleted;
	final bool withMedia;
	final Set<PostTypeFilter> supportedPostTypeFilters;

	const ImageboardSearchOptions({
		this.text = false,
		this.name = false,
		this.date = false,
		this.imageMD5 = false,
		this.subject = false,
		this.trip = false,
		this.isDeleted = false,
		this.withMedia = false,
		this.supportedPostTypeFilters = const {PostTypeFilter.none}
	});

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is ImageboardSearchOptions &&
		other.text == text &&
		other.name == name &&
		other.date == date &&
		other.subject == subject &&
		other.trip == trip &&
		other.isDeleted == isDeleted &&
		other.withMedia == withMedia &&
		setEquals(other.supportedPostTypeFilters, supportedPostTypeFilters);
	@override
	int get hashCode => Object.hash(text, name, date, subject, trip, isDeleted, withMedia, Object.hashAllUnordered(supportedPostTypeFilters));

	bool get hasOptions => name || imageMD5 || supportedPostTypeFilters.length > 1 || date || subject || trip || isDeleted || withMedia;
}

class ImageboardSearchMetadata {
	final String name;
	final ImageboardSearchOptions options;
	const ImageboardSearchMetadata({
		required this.name,
		required this.options
	});

	@override
	String toString() => 'ImageboardSearchMetadata(name: $name, options: $options)';
}

class ImageboardUserInfo {
	final String username;
	final Uri webUrl;
	final Uri? avatar;
	final DateTime? createdAt;
	final int? commentKarma;
	final int? linkKarma;
	final int totalKarma;

	const ImageboardUserInfo({
		required this.username,
		required this.webUrl,
		this.avatar,
		required this.createdAt,
		this.commentKarma,
		this.linkKarma,
		required this.totalKarma
	});

	@override
	String toString() => 'ImageboardUserInfo($username)';
}

sealed class ImageboardReportMethod {
	const ImageboardReportMethod();
}

class WebReportMethod extends ImageboardReportMethod {
	final Uri uri;
	const WebReportMethod(this.uri);
}

typedef ChoiceReportMethodChoice = ({String name, Map<String, String> value});

class ChoiceReportMethod extends ImageboardReportMethod {
	final PostIdentifier post;
	final String question;
	final List<ChoiceReportMethodChoice> choices;
	final Future<CaptchaRequest> Function({CancelToken? cancelToken}) getCaptchaRequest;
	final Future<void> Function(ChoiceReportMethodChoice choice, CaptchaSolution captchaSolution, {CancelToken? cancelToken}) onSubmit;
	const ChoiceReportMethod({
		required this.post,
		required this.question,
		required this.choices,
		required this.getCaptchaRequest,
		required this.onSubmit
	});
}

enum ImageboardBoardPopularityType {
	subscriberCount,
	postsCount
}

@HiveType(typeId: 47)
class DraftPost {
	@HiveField(0)
	final String board;
	@HiveField(1)
	final int? threadId;
	@HiveField(2)
	String? name;
	@HiveField(3)
	final String? options;
	@HiveField(4)
	final String? subject;
	@HiveField(5)
	final String text;
	@HiveField(6)
	String? file;
	@HiveField(7)
	final bool? spoiler;
	@HiveField(8)
	final String? overrideFilenameWithoutExtension;
	@HiveField(9)
	final ImageboardBoardFlag? flag;
	@HiveField(10)
	bool? useLoginSystem;
	@HiveField(11, defaultValue: false)
	bool overrideRandomizeFilenames;

	DraftPost({
		required this.board,
		required this.threadId,
		required this.name,
		required this.options,
		this.subject,
		required this.text,
		this.file,
		this.spoiler,
		this.overrideFilenameWithoutExtension,
		this.flag,
		required this.useLoginSystem,
		this.overrideRandomizeFilenames = false
	});

	ImageboardAction get action =>
		threadId == null ?
			ImageboardAction.postThread :
			(file != null) ?
				ImageboardAction.postReplyWithImage :
				ImageboardAction.postReply;
	
	ThreadIdentifier? get thread => threadId == null ? null : ThreadIdentifier(board, threadId!);

	String? get fileExt => file?.afterLast('.').toLowerCase();

	String? get overrideFilename {
		final override = overrideFilenameWithoutExtension;
		if ((override?.isEmpty ?? true) || file == null) {
			return null;
		}
		if (Settings.instance.randomizeFilenames && !overrideRandomizeFilenames) {
			return '${DateTime.now().subtract(const Duration(days: 365) * random.nextDouble()).microsecondsSinceEpoch}.$fileExt';
		}
		return '$override.$fileExt';
	}

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is DraftPost &&
		other.board == board &&
		other.threadId == threadId &&
		other.name == name &&
		other.options == options &&
		other.subject == subject &&
		other.text == text &&
		other.file == file &&
		other.spoiler == spoiler &&
		other.overrideFilenameWithoutExtension == overrideFilenameWithoutExtension &&
		other.flag == flag &&
		other.useLoginSystem == useLoginSystem &&
		other.overrideRandomizeFilenames == overrideRandomizeFilenames;
	
	@override
	int get hashCode => Object.hash(board, threadId, name, options, subject, text, file, spoiler, overrideFilenameWithoutExtension, flag, useLoginSystem, overrideRandomizeFilenames);

	@override
	String toString() => 'DraftPost(board: $board, threadId: $threadId, name: $name, options: $options, subject: $subject, text: $text, file: $file, spoiler: $spoiler, overrideFilenameWithoutExtension: $overrideFilenameWithoutExtension, flag: $flag, useLoginSystem: $useLoginSystem, overrideRandomizeFilenames: $overrideRandomizeFilenames)';
}

@HiveType(typeId: 48)
class ImageboardPollRow {
	@HiveField(0)
	final String name;
	@HiveField(1)
	final int votes;
	@HiveField(2)
	final Color? color;

	const ImageboardPollRow({
		required this.name,
		required this.votes,
		this.color
	});

	@override
	String toString() => 'ImageboardPollRow(name: $name, votes: $votes, color: $color)';

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is ImageboardPollRow &&
		other.name == name &&
		other.votes == votes &&
		other.color == color;
	
	@override
	int get hashCode => Object.hash(name, votes, color);
}

@HiveType(typeId: 49)
class ImageboardPoll {
	@HiveField(1)
	final String? title;
	@HiveField(2, merger: ListEqualsMerger<ImageboardPollRow>())
	final List<ImageboardPollRow> rows;

	const ImageboardPoll({
		required this.title,
		required this.rows
	});

	@override
	String toString() => 'ImageboardPoll(title: $title, rows: $rows)';

	@override
	bool operator == (Object other) =>
		identical(other, this) ||
		other is ImageboardPoll &&
		other.title == title &&
		listEquals(other.rows, rows);
	
	@override
	int get hashCode => Object.hash(title, Object.hashAll(rows));
}

class ImageboardRedirectGateway {
	final String name;
	final String? autoClickSelector;
	final bool alwaysNeedsManualSolving;

	const ImageboardRedirectGateway({
		required this.name,
		required this.alwaysNeedsManualSolving,
		this.autoClickSelector,
	});

	@override
	String toString() => 'ImageboardRedirectGateway(name: $name, alwaysNeedsManualSolving: $alwaysNeedsManualSolving, autoClickSelector: $autoClickSelector)';
}

abstract class ImageboardSiteArchive {
	final Dio client = Dio(BaseOptions(
		/// Avoid hanging for 2 minutes+ with default value
		/// 15 seconds should be well long enough for initial TCP handshake
		connectTimeout: 15000
	));
	final Map<String, ({Map<int, Thread> cache, DateTime time})> _catalogCache = {};
	final Map<String, ({Map<int, int> cache, DateTime time})> _catalogPageMapCache = {};
	String get userAgent => overrideUserAgent ?? Settings.instance.userAgent;
	final String? overrideUserAgent;
	ImageboardSiteArchive({
		required this.overrideUserAgent
	}) {
		client.interceptors.add(CloudflareBlockingInterceptor());
		client.interceptors.add(HTTP429BackoffInterceptor(client: client));
		client.interceptors.add(SeparatedCookieManager());
		client.interceptors.add(InterceptorsWrapper(
			onRequest: (options, handler) {
				options.headers['user-agent'] ??= userAgent;
				handler.next(options);
			}
		));
		client.interceptors.add(FixupInterceptor());
		client.interceptors.add(CloudflareInterceptor());
		client.interceptors.add(RetryIfCloudflareInterceptor(client));
		client.interceptors.add(StrictJsonInterceptor());
		if (!kInUnitTest) {
			client.interceptors.add(LoggingInterceptor.instance);
		}
		client.httpClientAdapter = MyHttpClientAdapter();
	}
	String get name;
	String get baseUrl;
	Future<Post> getPostFromArchive(String board, int id, {required RequestPriority priority, CancelToken? cancelToken});
	Future<Thread> getThread(ThreadIdentifier thread, {ThreadVariant? variant, required RequestPriority priority, CancelToken? cancelToken});
	@protected
	Future<List<Thread>> getCatalogImpl(String board, {CatalogVariant? variant, required RequestPriority priority, CancelToken? cancelToken});
	Future<List<Thread>> getCatalog(String board, {CatalogVariant? variant, required RequestPriority priority, DateTime? acceptCachedAfter, CancelToken? cancelToken}) async {
		return runEphemerallyLocked('getCatalog($name,$board)', () async {
			if (acceptCachedAfter != null) {
				final entry = _catalogCache[board];
				if (entry != null && entry.time.isAfter(acceptCachedAfter)) {
					return entry.cache.values.toList(); // Order is wrong but shouldn't matter
				}
			}
			final catalog = await getCatalogImpl(board, variant: variant, priority: priority, cancelToken: cancelToken);
			final oldCache = _catalogCache[board]?.cache ?? {};
			final newCache = <int, Thread>{};
			for (final newThread in catalog) {
				oldCache.remove(newThread.id);
				newCache[newThread.id] = newThread;
			}
			for (final oldThread in oldCache.values) {
				// Not in new catalog, it must have been archived
				oldThread.isArchived = true;
			}
			_catalogCache[board] = (cache: newCache, time: DateTime.now());
			return catalog;
		});
	}
	@protected
	Future<Map<int, int>> getCatalogPageMapImpl(String board, {CatalogVariant? variant, required RequestPriority priority, DateTime? acceptCachedAfter, CancelToken? cancelToken}) async {
		if (hasPagedCatalog) {
			// No hope, this needs to be defined per-site if possible
			return const {};
		}
		final catalog = await getCatalog(board, variant: variant, priority: priority, cancelToken: cancelToken, acceptCachedAfter: acceptCachedAfter);
		return {
			for (final thread in catalog)
				if (thread.currentPage case int page)
					thread.id: page
		};
	}
	Future<Map<int, int>> getCatalogPageMap(String board, {CatalogVariant? variant, required RequestPriority priority, DateTime? acceptCachedAfter, CancelToken? cancelToken}) async {
		return runEphemerallyLocked('getCatalogPageMap($name,$board)', () async {
			if (acceptCachedAfter != null) {
				final entry = _catalogPageMapCache[board];
				if (entry != null && entry.time.isAfter(acceptCachedAfter)) {
					return entry.cache;
				}
			}
			final fresh = await getCatalogPageMapImpl(board, variant: variant, priority: priority, acceptCachedAfter: acceptCachedAfter, cancelToken: cancelToken);
			_catalogPageMapCache[board] = (cache: fresh, time: DateTime.now());
			return fresh;
		});
	}
	/// If an empty list is returned from here, the bottom of the catalog has been reached.
	@protected
	Future<List<Thread>> getMoreCatalogImpl(String board, Thread after, {CatalogVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) async => [];
	Future<List<Thread>> getMoreCatalog(String board, Thread after, {CatalogVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) async {
		final moreCatalog = await getMoreCatalogImpl(board, after, variant: variant, priority: priority, cancelToken: cancelToken);
		(_catalogCache[board] ??= (cache: {}, time: DateTime.now())).cache.addAll({
			for (final t in moreCatalog)
				t.id: t
		});
		return moreCatalog;
	}
	Thread? getThreadFromCatalogCache(ThreadIdentifier? identifier, {DateTime? ifAfter}) {
		if (identifier == null) {
			return null;
		}
		final cache = _catalogCache[identifier.board];
		if (cache == null) {
			return null;
		}
		if (ifAfter != null && cache.time.isBefore(ifAfter)) {
			return null;
		}
		return cache.cache[identifier.id];
	}
	Future<List<ImageboardBoard>> getBoards({required RequestPriority priority, CancelToken? cancelToken});
	Future<ImageboardArchiveSearchResultPage> search(ImageboardArchiveSearchQuery query, {required int page, ImageboardArchiveSearchResultPage? lastResult, required RequestPriority priority, CancelToken? cancelToken});
	@protected
	String getWebUrlImpl(String board, [int? threadId, int? postId]);
	String getWebUrl({
		required String board,
		int? threadId,
		int? postId,
		String? archiveName
	}) {
		return getWebUrlImpl(board, threadId, postId);
	}
	Future<BoardThreadOrPostIdentifier?> decodeUrl(Uri url);
	int placeOrphanPost(List<Post> posts, Post post) {
		final index = posts.indexWhere((p) => p.id > post.id);
		// Make a copy so that filtering WeakMaps will see it as new
		post = post.copyWith(
			isDeleted: true
		);
		if (index == -1) {
			posts.add(post);
			return posts.length - 1;
		}
		else {
			posts.insert(index, post);
			return index;
		}
	}
	bool get hasPagedCatalog => false;
	bool get isArchive => this is! ImageboardSite;

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is ImageboardSiteArchive &&
		other.overrideUserAgent == overrideUserAgent;
	
	@override
	int get hashCode => baseUrl.hashCode;
}

abstract class ImageboardSite extends ImageboardSiteArchive {
	final List<ImageboardSiteArchive> archives;
	final Map<String, String> imageHeaders;
	final Map<String, String> videoHeaders;
	ImageboardSite({
		required this.archives,
		required this.imageHeaders,
		required this.videoHeaders,
		required super.overrideUserAgent
	});
	/// Get headers to use to download an Attachment
	Map<String, String> getHeaders(Uri url) {
		final type = AttachmentType.fromFilename(FileBasename.get(url.path));
		return {
			'user-agent': userAgent,
			if (type.isVideo) ...videoHeaders
			else if (type == AttachmentType.image) ...imageHeaders
		};
	}
	String? get imageUrl => null;
	Uri? get iconUrl;
	Future<CaptchaRequest> getCaptchaRequest(String board, int? threadId, {CancelToken? cancelToken});
	Future<CaptchaRequest> getDeleteCaptchaRequest(ThreadIdentifier thread, {CancelToken? cancelToken}) async => const NoCaptchaRequest();
	Future<PostReceipt> submitPost(DraftPost post, CaptchaSolution captchaSolution, CancelToken cancelToken);
	Duration getActionCooldown(String board, ImageboardAction action, CookieJar cookies) => const Duration(seconds: 3);
	Future<void> deletePost(ThreadIdentifier thread, PostReceipt receipt, CaptchaSolution captchaSolution, CancelToken cancelToken, {required bool imageOnly}) async {
		throw UnimplementedError('Post deletion is not implemented on $name ($runtimeType)');
	}

	static bool _isCloudflareNotAllowedException(Object e) => switch (e) {
		CloudflareHandlerNotAllowedException() => true,
		DioError dioError => dioError.error is CloudflareHandlerNotAllowedException,
		_ => false
	};
	@override
	Future<Post> getPostFromArchive(String board, int id, {required RequestPriority priority, CancelToken? cancelToken}) async {
		final Map<ImageboardSiteArchive, Object> errors = {};
		for (final archive in archives) {
			if (persistence?.browserState.disabledArchiveNames.contains(archive.name) ?? false) {
				continue;
			}
			try {
				final post = await archive.getPostFromArchive(board, id, priority: RequestPriority.cosmetic, cancelToken: cancelToken);
				post.archiveName = archive.name;
				return post;
			}
			catch(e) {
				if (e is! BoardNotFoundException) {
					errors[archive] = e;
				}
			}
		}
		if (priority != RequestPriority.cosmetic) {
			// Try again, allowing cloudflare clearance
			for (final error in errors.entries.toList(growable: false)) { // concurrent modification
				// No need to check disabledArchiveNames, they can't fail to begin with
				if (_isCloudflareNotAllowedException(error.value)) {
					try {
						final post = await error.key.getPostFromArchive(board, id, priority: priority, cancelToken: cancelToken);
						post.archiveName = error.key.name;
						return post;
					}
					catch (e) {
						if (e is! BoardNotFoundException) {
							errors[error.key] = e;
						}
					}
				}
			}
		}
		if (errors.isNotEmpty) {
			throw ImageboardArchiveException(errors);
		}
		else {
			throw BoardNotArchivedException(board);
		}
	}
	Future<Thread> getThreadFromArchive(ThreadIdentifier thread, {Future<void> Function(Thread)? customValidator, required RequestPriority priority, CancelToken? cancelToken, String? archiveName}) async {
		final Map<ImageboardSiteArchive, Object> errors = {};
		Thread? fallback;
		final isReallyArchived = () async {
			try {
				// Maybe we already know
				final t0 = await persistence?.getThreadStateIfExists(thread)?.getThread();
				if (t0 != null && t0.archiveName == null && t0.isArchived) {
					return true;
				}
				final acceptCachedAfter = DateTime.now().subtract(const Duration(minutes: 1));
				if (hasPagedCatalog) {
					// Need to get the actual thread
					final t = getThreadFromCatalogCache(thread, ifAfter: acceptCachedAfter) ?? await getThread(thread, priority: priority, cancelToken: cancelToken);
					return t.isArchived;
				}
				else {
					// 4chan started to put old thread JSONs behind cloudflare
					// Hopefully they never do that to catalogs
					final catalog = await getCatalog(thread.board, priority: priority, cancelToken: cancelToken, acceptCachedAfter: acceptCachedAfter);
					return catalog.tryFirstWhere((t) => t.id == thread.id)?.isArchived ?? true;
				}
			}
			catch  (_) {
				// Assume the worst
				return true;
			}
		}();
		final validator = customValidator ?? (Thread thread) async {
			if (thread.archiveName == archiveName) {
				// Skip validation
				return;
			}
			final opAttachment = thread.attachments.tryFirst ?? thread.posts_.tryFirst?.attachments.tryFirst;
			if (opAttachment != null) {
				final response = await client.head(opAttachment.url, options: Options(
					headers: {
						...getHeaders(Uri.parse(opAttachment.url)),
						if (opAttachment.useRandomUseragent) 'user-agent': makeRandomUserAgent()
					},
					followRedirects: false,
					validateStatus: (_) => true,
					extra: {
						kPriority: priority
					}
				), cancelToken: cancelToken);
				if ((response.statusCode ?? 400) >= 400) {
					throw HTTPStatusException.fromResponse(response);
				}
			}
		};
		final completer = Completer<Thread>();
		if (archiveName != null) {
			final archive = archives.tryFirstWhere((a) => a.name == archiveName);
			if (archive != null) {
				try {
					final thread_ = await archive.getThread(thread, priority: priority, cancelToken: cancelToken).timeout(const Duration(seconds: 15));
					thread_.archiveName = archive.name;
					thread_.isArchived = await isReallyArchived;
					fallback = thread_;
					try {
						await validator(thread_);
					}
					catch (e) {
						if (
							(e is AttachmentNotArchivedException || e is AttachmentNotFoundException)
						) {
							fallback = null;
						}
						rethrow;
					}
					return thread_;
				}
				catch(e, st) {
					if (e is! BoardNotFoundException) {
						print('Error getting $thread from preferred ${archive.name}: ${e.toStringDio()}');
						print(st);
						errors[archive] = e;
					}
				}
			}
		}
		() async {
			await Future.wait(archives.map((archive) async {
				if (persistence?.browserState.disabledArchiveNames.contains(archive.name) ?? false) {
					return null;
				}
				if (archiveName == archive.name) {
					// It should have been already attempted
					return null;
				}
				try {
					final thread_ = await archive.getThread(thread, priority: RequestPriority.cosmetic, cancelToken: cancelToken).timeout(const Duration(seconds: 15));
					if (completer.isCompleted) return null;
					thread_.archiveName = archive.name;
					thread_.isArchived = await isReallyArchived;
					fallback = thread_;
					if (completer.isCompleted) return null;
					try {
						await validator(thread_);
					}
					catch (e) {
						if (
							(e is AttachmentNotArchivedException || e is AttachmentNotFoundException) &&
							identical(fallback, thread_)
						) {
							fallback = null;
						}
						rethrow;
					}
					if (!completer.isCompleted) {
						completer.complete(thread_);
					}
					return thread_;
				}
				catch(e, st) {
					if (e is! BoardNotFoundException) {
						print('Error getting $thread from ${archive.name}: ${e.toStringDio()}');
						print(st);
						errors[archive] = e;
					}
				}
			}));
			if (completer.isCompleted) {
				// Do nothing, the thread was already returned
				return null;
			}
			if (priority != RequestPriority.cosmetic) {
				// Try again, allowing cloudflare clearance
				for (final error in errors.entries.toList(growable: false)) { // concurrent modification
					if (_isCloudflareNotAllowedException(error.value)) {
						try {
							final thread_ = await error.key.getThread(thread, priority: priority, cancelToken: cancelToken).timeout(const Duration(seconds: 15));
							thread_.archiveName = error.key.name;
							fallback = thread_;
							try {
								await validator(thread_);
							}
							catch (e) {
								if (
									(e is AttachmentNotArchivedException || e is AttachmentNotFoundException) &&
									identical(fallback, thread_)
								) {
									fallback = null;
								}
								rethrow;
							}
							completer.complete(thread_);
							return;
						}
						catch (e) {
							// Update to new error
							errors[error.key] = e;
						}
					}
				}
			}
			if (fallback != null) {
				completer.complete(fallback);
			}
			else if (errors.isNotEmpty) {
				completer.completeError(ImageboardArchiveException(errors));
			}
			else {
				completer.completeError(BoardNotArchivedException(thread.board));
			}
		}();
		return completer.future;
	}

	@override
	Future<ImageboardArchiveSearchResultPage> search(ImageboardArchiveSearchQuery query, {required int page, ImageboardArchiveSearchResultPage? lastResult, required RequestPriority priority, CancelToken? cancelToken})
		=> searchArchives(query, page: page, lastResult: lastResult, priority: priority, cancelToken: cancelToken);

	Future<ImageboardArchiveSearchResultPage> searchArchives(ImageboardArchiveSearchQuery query, {required int page, ImageboardArchiveSearchResultPage? lastResult, required RequestPriority priority, CancelToken? cancelToken}) async {
		final errors = <ImageboardSiteArchive, Object>{};
		for (final archive in archives) {
			if (persistence?.browserState.disabledArchiveNames.contains(archive.name) ?? false) {
				continue;
			}
			try {
				return await archive.search(query, page: page, lastResult: lastResult, priority: RequestPriority.cosmetic, cancelToken: cancelToken);
			}
			catch (e, st) {
				if (e is! BoardNotFoundException) {
					print('Error from ${archive.name}');
					print(e.toStringDio());
					print(st);
					errors[archive] = e;
				}
			}
		}
		if (priority != RequestPriority.cosmetic) {
			// Try again, allowing cloudflare clearance
			for (final error in errors.entries.toList(growable: false)) { // concurrent modification
				// No need to check disabledArchiveNames, they can't fail to begin with
				if (_isCloudflareNotAllowedException(error.value)) {
					try {
						return await error.key.search(query, page: page, lastResult: lastResult, priority: priority, cancelToken: cancelToken);
					}
					catch (e, st) {
						if (e is! BoardNotFoundException) {
							print('Error2 from ${error.key.name}');
							print(e.toStringDio());
							print(st);
							errors[error.key] = e;
						}
					}
				}
			}
		}
		throw Exception('Search failed - exhausted all archives\n${errors.entries.map((e) => '${e.key.name}: ${e.value.toStringDio()}').join('\n')}');
	}
	Uri? getSpoilerImageUrl(Attachment attachment, {Thread? thread}) => null;
	Future<ImageboardReportMethod> getPostReportMethod(PostIdentifier post, {CancelToken? cancelToken}) async {
		return WebReportMethod(Uri.parse(getWebUrlImpl(post.board, post.threadId, post.postId)));
	}
	Imageboard? imageboard;
	Persistence? get persistence => imageboard?.persistence;
	ImageboardSiteLoginSystem? get loginSystem => null;
	List<ImageboardEmote> getEmotes() => [];
	Future<List<ImageboardBoardFlag>> getBoardFlags(String board) async => [];
	String get siteType;
	String get siteData;
	String get defaultUsername;
	List<ImageboardSnippet> getBoardSnippets(String board) => const [];
	Future<List<ImageboardBoard>> getBoardsForQuery(String query) async => [];
	ImageboardBoardPopularityType? get boardPopularityType => null;
	bool get allowsArbitraryBoards => false;
	bool get classicCatalogStyle => true;
	bool get explicitIds => true;
	bool get useTree => false;
	bool get showImageCount => true;
	ImageboardSearchMetadata supportsSearch(String? board) {
		if (board != null && archives.isNotEmpty) {
			return ImageboardSearchMetadata(
				name: '$name archives',
				options: const ImageboardSearchOptions(
					text: true,
					name: true,
					date: true,
					supportedPostTypeFilters: {
						PostTypeFilter.none,
						PostTypeFilter.onlyOPs,
						PostTypeFilter.onlyReplies,
						PostTypeFilter.onlyStickies
					},
					imageMD5: true,
					isDeleted: true,
					withMedia: true,
					subject: true,
					trip: true
				)
			);
		}
		return ImageboardSearchMetadata(
			name: name,
			options: const ImageboardSearchOptions()
		);
	}
	bool get supportsPosting => true;
	bool get supportsThreadUpvotes => false;
	bool get supportsPostUpvotes => false;
	int? get postsPerPage => null;
	bool get isPaged => postsPerPage != null;
	Future<List<Post>> getStubPosts(ThreadIdentifier thread, List<ParentAndChildIdentifier> postIds, {required RequestPriority priority, CancelToken? cancelToken}) async => throw UnimplementedError();
	bool get supportsMultipleBoards => true;
	bool get hasSharedIdSpace => false;
	bool get hasWeakQuoteLinks => false;
	bool get hasSecondsPrecision => true;
	bool get supportsPushNotifications => false;
	bool get supportsUserInfo => false;
	bool get supportsUserAvatars => false;
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
			name: 'Reply rate (+new first)',
			variants: [CatalogVariant.postsPerMinuteWithNewThreadsAtTop, CatalogVariant.postsPerMinuteWithNewThreadsAtTopReversed],
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
		),
		CatalogVariantGroup(
			name: 'Alphabetically',
			variants: [CatalogVariant.alphabeticByTitle, CatalogVariant.alphabeticByTitleReversed],
			hasPrimary: true
		)
	];
	List<ThreadVariant> get threadVariants => const [];
	String formatBoardName(String name) => '/$name/';
	String formatBoardNameWithoutTrailingSlash(String name) => '/$name';
	String formatBoardLink(String name) => '>>/$name/';
	String formatBoardSearchLink(String name, String query) => '>>>/$name/$query';
	String formatUsername(String name) => name;
	@mustCallSuper
	void migrateFromPrevious(covariant ImageboardSite oldSite) {
		_catalogCache.addAll(oldSite._catalogCache);
		_catalogPageMapCache.addAll(oldSite._catalogPageMapCache);
		final oldLoggedIn = oldSite.loginSystem?.loggedIn;
		if (oldLoggedIn != null) {
			loginSystem?.loggedIn = oldLoggedIn;
		}
	}
	@mustCallSuper
	void initState() {}
	@mustCallSuper
	void dispose() {}
	@protected
	Future<Map<int, String>> queryPreferredArchive(String board, List<int> threadIds, {CancelToken? cancelToken}) async {
		final sorted = threadIds.toList()..sort();
		final diffs = List.generate(sorted.length - 1, (i) => sorted[i + 1] - sorted[i]);
		final response = await client.get('$_preferredArchiveApiRoot/ops', queryParameters: {
			'siteType': siteType,
			'siteData': siteData,
			'board': board,
			'base': sorted.first.toString(),
			'diffs': base64Url.encode(gzip.encode(utf8.encode(diffs.join(','))))
		}, cancelToken: cancelToken);
		return {
			for (final entry in (response.data as Map).entries) int.parse(entry.key as String): entry.value as String
		};
	}
	@protected
	Future<Thread> getThreadImpl(ThreadIdentifier thread, {ThreadVariant? variant, required RequestPriority priority, CancelToken? cancelToken});
	@override
	Future<Thread> getThread(ThreadIdentifier thread, {ThreadVariant? variant, required RequestPriority priority, CancelToken? cancelToken}) async {
		final theThread = await getThreadImpl(thread, variant: variant, priority: priority, cancelToken: cancelToken);
		await updatePageNumber(theThread, null, priority: priority, cancelToken: cancelToken);
		return theThread;
	}
	/// By default, always fetch the thread
	/// No currentPage handling, must be handled separately
	Future<Thread?> getThreadIfModifiedSince(ThreadIdentifier thread, DateTime lastModified, {
		ThreadVariant? variant,
		required RequestPriority priority,
		CancelToken? cancelToken
	}) async => getThreadImpl(
		thread,
		variant: variant,
		priority: priority,
		cancelToken: cancelToken
	);
	Future<void> updatePageNumber(Thread thread, bool? hasNewPost, {
		required RequestPriority priority,
		CancelToken? cancelToken
	}) async {
		if (!hasExpiringThreads || thread.isArchived || thread.isDeleted) {
			return;
		}
		// The logic here -- if there is no new post, then page only slowly decays
		// If there was a new post, page probably jumped to 1. But can't just assume 1,
		// that's only if we have been updating continuously.
		final acceptCachedAfter = switch (hasNewPost) {
			true => thread.lastUpdatedTime?.toLocal() ?? thread.posts_.last.time.toLocal(),
			false => DateTime.now().subtract(const Duration(minutes: 2)),
			null => DateTimeConversion.max(
				thread.lastUpdatedTime?.toLocal() ?? thread.posts_.last.time.toLocal(),
				DateTime.now().subtract(const Duration(minutes: 2))
			)
		};
		if (!hasPagedCatalog) {
			// We get all the threads in one call
			final catalog = await getCatalog(
				thread.board,
				acceptCachedAfter: acceptCachedAfter,
				priority: priority,
				cancelToken: cancelToken
			);
			thread.currentPage = catalog.tryFirstWhere((t) => t.id == thread.id)?.currentPage ?? thread.currentPage;
		}
		else {
			// Need to use specialized method (or fail with empty map)
			final map = await getCatalogPageMap(
				thread.board,
				acceptCachedAfter: acceptCachedAfter,
				priority: priority,
				cancelToken: cancelToken
			);
			thread.currentPage = map[thread.id] ?? thread.currentPage;
		}
	}
	Future<ImageboardUserInfo> getUserInfo(String username) async => throw UnimplementedError();
	@override
	String getWebUrl({
		required String board,
		int? threadId,
		int? postId,
		String? archiveName
	}) {
		return (archives.tryFirstWhere((a) => a.name == archiveName) ?? this).getWebUrlImpl(board, threadId, postId);
	}
	Future<void> clearPseudoCookies() async {}
	DateTime getCaptchaUsableTime(CaptchaSolution captcha) {
		if (captcha is NoCaptchaSolution) {
			return captcha.acquiredAt;
		}
		return captcha.acquiredAt.add(Duration(milliseconds: random.nextInt(500) + 450));
	}
	/// Different cooldowns, but queue is shared
	ImageboardAction getQueue(ImageboardAction action) => switch(action) {
		ImageboardAction.postReply || ImageboardAction.postReplyWithImage => ImageboardAction.postReply,
		ImageboardAction.postThread => ImageboardAction.postThread,
		ImageboardAction.report => ImageboardAction.report,
		ImageboardAction.delete => ImageboardAction.delete
	};
	int? get subjectCharacterLimit => null;
	bool get hasLinkCookieAuth => false;
	Uri? get authPage => null;
	/// Remember these fields (HTML "name"s) between uses
	Set<String> get authPageFormFields => const {};
	bool get hasExpiringThreads => true;
	bool get hasLargeInlineAttachments => false;
	CatalogVariant get defaultCatalogVariant => Settings.instance.catalogVariant;
	set defaultCatalogVariant(CatalogVariant value) => Settings.catalogVariantSetting.set(Settings.instance, value);
	ImageboardRedirectGateway? getRedirectGateway(Uri uri, String? title) => null;
	bool get supportsPinkQuotes => false;
	bool get supportsBlueQuotes => false;

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is ImageboardSite &&
		listEquals(other.archives, archives) &&
		mapEquals(other.imageHeaders, imageHeaders) &&
		mapEquals(other.videoHeaders, videoHeaders) &&
		super==(other);
	
	@override
	int get hashCode => baseUrl.hashCode;
}

abstract class ImageboardSiteLoginSystem {
	@protected
	Map<CookieJar, bool> loggedIn = {};
	ImageboardSite get parent;
	String get name;
	bool get hidden;
	Uri? get iconUrl => null;
	List<ImageboardSiteLoginField> getLoginFields();
	Future<void> login(Map<ImageboardSiteLoginField, String> fields, CancelToken cancelToken);
	Map<ImageboardSiteLoginField, String>? getSavedLoginFields() {
		 if (parent.persistence?.browserState.loginFields.isNotEmpty ?? false) {
			 try {
					final savedFields = {
						for (final field in getLoginFields()) field: parent.persistence!.browserState.loginFields[field.formKey]!
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
		parent.persistence?.browserState.loginFields.clear();
		await parent.persistence?.didUpdateBrowserState();
	}
	Future<void> logoutImpl(bool fromBothWifiAndCellular, CancelToken cancelToken);
	Future<void> logout(bool fromBothWifiAndCellular, CancelToken cancelToken) async {
		if (!fromBothWifiAndCellular && !(loggedIn[Persistence.currentCookies] ?? getSavedLoginFields() != null)) {
			// No-op
			return;
		}
		await logoutImpl(fromBothWifiAndCellular, cancelToken);
	}
	bool isLoggedIn(CookieJar jar) {
		return loggedIn.putIfAbsent(jar, () => false);
	}
}

ImageboardSiteArchive makeArchive(dynamic archive) {
	final overrideUserAgent = archive['overrideUserAgent'] as String?;
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
			useRandomUseragent: archive['useRandomUseragent'] ?? false,
			hasAttachmentRateLimit: archive['hasAttachmentRateLimit'] ?? false,
			overrideUserAgent: overrideUserAgent
		);
	}
	else if (archive['type'] == 'fuuka') {
		return FuukaArchive(
			name: archive['name'],
			baseUrl: archive['baseUrl'],
			boards: boards,
			overrideUserAgent: overrideUserAgent
		);
	}
	else {
		// Maybe it's another full site API?
		return makeSite(archive);
	}
}

ImageboardSite makeSite(dynamic data) {
	final overrideUserAgent = data['overrideUserAgent'] as String?;
	final archives = (data['archives'] as List? ?? []).map<ImageboardSiteArchive>(makeArchive).toList(growable: false);
	final imageHeaders = (data['imageHeaders'] as Map?)?.cast<String, String>() ?? {};
	final videoHeaders = (data['videoHeaders'] as Map?)?.cast<String, String>() ?? {};
	final boards = (data['boards'] as List?)?.map((b) => ImageboardBoard(
		title: b['title'],
		name: b['name'],
		isWorksafe: b['isWorksafe'],
		webmAudioAllowed: true
	)).toList();
	if (data['type'] == 'lainchan') {
		return SiteLainchan(
			name: data['name'],
			baseUrl: data['baseUrl'],
			maxUploadSizeBytes: data['maxUploadSizeBytes'],
			overrideUserAgent: overrideUserAgent,
			archives: archives,
			imageHeaders: imageHeaders,
			videoHeaders: videoHeaders,
			turnstileSiteKey: data['turnstileSiteKey']
		);
	}
	else if (data['type'] == 'soyjak') {
		return SiteSoyjak(
			name: data['name'],
			baseUrl: data['baseUrl'],
			overrideUserAgent: overrideUserAgent,
			archives: archives,
			imageHeaders: imageHeaders,
			videoHeaders: videoHeaders,
			turnstileSiteKey: data['turnstileSiteKey'],
			boardsWithCaptcha: (data['boardsWithCaptcha'] as List?)?.cast<String>(),
			boardsWithHtmlOnlyFlags: (data['boardsWithHtmlOnlyFlags'] as List?)?.cast<String>() ?? [],
			boardsWithMemeFlags: (data['boardsWithMemeFlags'] as List?)?.cast<String>(),
			captchaQuestion: data['captchaQuestion']
		);
	}
	else if (data['type'] == 'frenschan') {
		return SiteFrenschan(
			name: data['name'],
			baseUrl: data['baseUrl'],
			overrideUserAgent: overrideUserAgent,
			boardsWithHtmlOnlyFlags: (data['boardsWithHtmlOnlyFlags'] as List?)?.cast<String>() ?? [],
			boardsWithMemeFlags: (data['boardsWithMemeFlags'] as List?)?.cast<String>(),
			archives: archives,
			imageHeaders: imageHeaders,
			videoHeaders: videoHeaders,
			turnstileSiteKey: data['turnstileSiteKey']
		);
	}
	else if (data['type'] == 'wizchan') {
		return SiteWizchan(
			name: data['name'],
			baseUrl: data['baseUrl'],
			overrideUserAgent: overrideUserAgent,
			archives: archives,
			imageHeaders: imageHeaders,
			videoHeaders: videoHeaders,
			turnstileSiteKey: data['turnstileSiteKey']
		);
	}
	else if (data['type'] == 'lainchan_org') {
		return SiteLainchanOrg(
			name: data['name'],
			baseUrl: data['baseUrl'],
			faviconPath: data['faviconPath'] ?? '/favicon.ico',
			defaultUsername: data['defaultUsername'] ?? 'Anonymous',
			overrideUserAgent: overrideUserAgent,
			archives: archives,
			imageHeaders: imageHeaders,
			videoHeaders: videoHeaders,
			turnstileSiteKey: data['turnstileSiteKey']
		);
	}
	else if (data['type'] == 'dvach') {
		return SiteDvach(
			name: data['name'],
			baseUrl: data['baseUrl'],
			overrideUserAgent: overrideUserAgent,
			archives: archives,
			imageHeaders: imageHeaders,
			videoHeaders: videoHeaders
		);
	}
	else if (data['type'] == 'futaba') {
		return SiteFutaba(
			name: data['name'],
			baseUrl: data['baseUrl'],
			maxUploadSizeBytes: data['maxUploadSizeBytes'],
			overrideUserAgent: overrideUserAgent,
			archives: archives,
			imageHeaders: imageHeaders,
			videoHeaders: videoHeaders
		);
	}
	else if (data['type'] == 'reddit') {
		return SiteReddit(
			overrideUserAgent: overrideUserAgent,
			archives: archives,
			imageHeaders: imageHeaders,
			videoHeaders: videoHeaders
		);
	}
	else if (data['type'] == 'hackernews') {
		return SiteHackerNews(
			overrideUserAgent: overrideUserAgent,
			archives: archives,
			imageHeaders: imageHeaders,
			videoHeaders: videoHeaders
		);
	}
	else if (data['type'] == 'erischan') {
		return SiteErischan(
			name: data['name'],
			baseUrl: data['baseUrl'],
			overrideUserAgent: overrideUserAgent,
			boardsWithHtmlOnlyFlags: (data['boardsWithHtmlOnlyFlags'] as List?)?.cast<String>() ?? [],
			boardsWithMemeFlags: (data['boardsWithMemeFlags'] as List?)?.cast<String>(),
			archives: archives,
			imageHeaders: imageHeaders,
			videoHeaders: videoHeaders,
			turnstileSiteKey: data['turnstileSiteKey']
		);
	}
	else if (data['type'] == '4chan') {
		final captchaTicketLifetime = data['captchaTicketLifetime'] as int?;
		final reportCooldown = data ['reportCooldown'] as int?;
		return Site4Chan(
			name: data['name'],
			imageUrl: data['imageUrl'],
			captchaKey: data['captchaKey'],
			hCaptchaKey: data['hCaptchaKey'],
			apiUrl: data['apiUrl'],
			sysUrl: data['sysUrl'],
			baseUrl: data['baseUrl'],
			staticUrl: data['staticUrl'],
			captchaUserAgents: (data['captchaUserAgents'] as Map?)?.cast<String, String>() ?? {},
			possibleCaptchaLetterCounts: (data['possibleCaptchaLetterCounts'] as List?)?.cast<int>() ?? [],
			captchaLetters:
				(data['captchaLetters'] as List?)?.cast<String>() ??
				['0', '2', '4', '8', 'A', 'D', 'G', 'H', 'J', 'K', 'M', 'N', 'P', 'R', 'S', 'T', 'V', 'W', 'X', 'Y'],
			captchaLettersRemap:
				(data['captchaLettersRemap'] as Map?)?.cast<String, String>() ??
				{
					'5': 'S',
					'B': '8',
					'F': 'P',
					'U': 'V',
					'Z': '2',
					'O': '0'
				},
			postingHeaders: (data['postingHeaders'] as Map?)?.cast<String, String>() ?? {},
			captchaTicketLifetime: captchaTicketLifetime == null ? null : Duration(seconds: captchaTicketLifetime),
			reportCooldown: Duration(seconds: reportCooldown ?? 20),
			spamFilterCaptchaDelayGreen: Duration(milliseconds: data['spamFilterCaptchaDelayGreen'] ?? 1000),
			spamFilterCaptchaDelayYellow: Duration(milliseconds: data['spamFilterCaptchaDelayYellow'] ?? 5000),
			spamFilterCaptchaDelayRed: Duration(milliseconds: data['spamFilterCaptchaDelayRed'] ?? 12000),
			stickyCloudflare: data['stickyCloudflare'] ?? false,
			subjectCharacterLimit: data['subjectCharacterLimit'],
			overrideUserAgent: overrideUserAgent,
			boardFlags: (data['boardFlags'] as Map?)?.cast<String, Map>().map((k, v) => MapEntry(k, v.cast<String, String>())),
			searchUrl: data['searchUrl'] ?? '',
			archives: archives,
			imageHeaders: imageHeaders,
			videoHeaders: videoHeaders
		);
	}
	else if (data['type'] == 'lynxchan') {
		return SiteLynxchan(
			name: data['name'],
			baseUrl: data['baseUrl'],
			boards: boards,
			overrideUserAgent: overrideUserAgent,
			archives: archives,
			imageHeaders: imageHeaders,
			videoHeaders: videoHeaders,
			defaultUsername: data['defaultUsername'] ?? 'Anonymous',
			hasLinkCookieAuth: data['hasLinkCookieAuth'] ?? false,
			hasPagedCatalog: data['hasPagedCatalog'] ?? true
		);
	}
	else if (data['type'] == '8chan') {
		return Site8Chan(
			name: data['name'],
			baseUrl: data['baseUrl'],
			boards: boards,
			overrideUserAgent: overrideUserAgent,
			archives: archives,
			imageHeaders: imageHeaders,
			videoHeaders: videoHeaders,
			defaultUsername: data['defaultUsername'] ?? 'Anonymous',
			hasLinkCookieAuth: data['hasLinkCookieAuth'] ?? false,
			hasPagedCatalog: data['hasPagedCatalog'] ?? true
		);
	}
	else if (data['type'] == 'lainchan2') {
		return SiteLainchan2(
			name: data['name'],
			baseUrl: data['baseUrl'],
			basePath: data['basePath'] ?? '',
			imageThumbnailExtension: data['imageThumbnailExtension'],
			faviconPath: data['faviconPath'],
			boardsPath: data['boardsPath'],
			defaultUsername: data['defaultUsername'],
			overrideUserAgent: overrideUserAgent,
			archives: archives,
			imageHeaders: imageHeaders,
			videoHeaders: videoHeaders,
			turnstileSiteKey: data['turnstileSiteKey'],
			boards: boards,
			boardsWithHtmlOnlyFlags: (data['boardsWithHtmlOnlyFlags'] as List?)?.cast<String>() ?? [],
			boardsWithMemeFlags: (data['boardsWithMemeFlags'] as List?)?.cast<String>(),
			formBypass: {
				for (final entry in ((data['formBypass'] as Map?) ?? {}).entries)
					entry.key as String: (entry.value as Map).cast<String, String>()
			}
		);
	}
	else if (data['type'] == '8kun') {
		return Site8Kun(
			name: data['name'],
			baseUrl: data['baseUrl'],
			basePath: data['basePath'] ?? '',
			sysUrl: data['sysUrl'],
			imageUrl: data['imageUrl'],
			imageThumbnailExtension: data['imageThumbnailExtension'],
			faviconPath: data['faviconPath'],
			boardsPath: data['boardsPath'],
			defaultUsername: data['defaultUsername'],
			overrideUserAgent: overrideUserAgent,
			archives: archives,
			imageHeaders: imageHeaders,
			videoHeaders: videoHeaders,
			turnstileSiteKey: data['turnstileSiteKey'],
			boards: boards,
			boardsWithHtmlOnlyFlags: (data['boardsWithHtmlOnlyFlags'] as List?)?.cast<String>() ?? [],
			boardsWithMemeFlags: (data['boardsWithMemeFlags'] as List?)?.cast<String>(),
			formBypass: {
				for (final entry in ((data['formBypass'] as Map?) ?? {}).entries)
					entry.key as String: (entry.value as Map).cast<String, String>()
			}
		);
	}
	else if (data['type'] == 'xenforo') {
		return SiteXenforo(
			name: data['name'],
			baseUrl: data['baseUrl'],
			basePath: data['basePath'],
			faviconPath: data['faviconPath'],
			postsPerPage: data['postsPerPage'],
			overrideUserAgent: overrideUserAgent,
			archives: archives,
			imageHeaders: imageHeaders,
			videoHeaders: videoHeaders
		);
	}
	else if (data['type'] == 'karachan') {
		return SiteKarachan(
			baseUrl: data['baseUrl'],
			name: data['name'],
			captchaKey: data['captchaKey'] ?? '',
			defaultUsername: data['defaultUsername'] ?? 'Anonymous',
			overrideUserAgent: overrideUserAgent,
			archives: archives,
			imageHeaders: imageHeaders,
			videoHeaders: videoHeaders
		);
	}
	else if (data['type'] == 'jschan') {
		return SiteJsChan(
			baseUrl: data['baseUrl'],
			name: data['name'],
			defaultUsername: data['defaultUsername'] ?? 'Anonymous',
			faviconPath: data['faviconPath'],
			postingCaptcha: data['postingCaptcha'] ?? 'grid',
			deletingCaptcha: data['deletingCaptcha'] ?? 'grid',
			overrideUserAgent: overrideUserAgent,
			archives: archives,
			imageHeaders: imageHeaders,
			videoHeaders: videoHeaders
		);
	}
	else if (data['type'] == 'jforum') {
		return SiteJForum(
			baseUrl: data['baseUrl'],
			name: data['name'],
			basePath: data['basePath'],
			defaultUsername: data['defaultUsername'] ?? 'Anonymous',
			faviconPath: data['faviconPath'],
			threadsPerPage: data['threadsPerPage'] ?? 25,
			postsPerPage: data['postsPerPage'] ?? 15,
			searchResultsPerPage: data['searchResultsPerPage'] ?? 25,
			overrideUserAgent: overrideUserAgent,
			archives: archives,
			imageHeaders: imageHeaders,
			videoHeaders: videoHeaders
		);
	}
	else {
		print(data);
		throw UnknownSiteTypeException(data['type']);
	}
}
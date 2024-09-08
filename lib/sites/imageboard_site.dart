import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:chan/models/attachment.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/flag.dart';
import 'package:chan/models/parent_and_child.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/search.dart';
import 'package:chan/services/bad_certificate.dart';
import 'package:chan/services/cloudflare.dart';
import 'package:chan/services/cookies.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/network_logging.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
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
import 'package:connectivity_plus/connectivity_plus.dart';
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

class PostNotFoundException implements Exception {
	String board;
	int id;
	PostNotFoundException(this.board, this.id);
	@override
	String toString() => 'Post not found: /$board/$id';
}

class ThreadNotFoundException implements Exception {
	const ThreadNotFoundException();
	@override
	String toString() => 'Thread not found';
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

class CooldownException implements Exception {
	final DateTime tryAgainAt;
	const CooldownException(this.tryAgainAt);
	@override
	String toString() => 'Try again at $tryAgainAt';
}

class PostFailedException implements Exception {
	String reason;
	PostFailedException(this.reason);
	@override
	String toString() => 'Posting failed: $reason';
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

class ReportFailedException implements Exception {
	final String message;
	const ReportFailedException(this.message);
	@override
	String toString() => 'Report failed: $message';
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
	alphabeticByTitleReversed
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
		CatalogVariant.alphabeticByTitleReversed: CupertinoIcons.textformat
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
		CatalogVariant.alphabeticByTitleReversed: 'Z-A by title'
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
	final bool stickyCloudflare;

	const Chan4CustomCaptchaRequest({
		required this.challengeUrl,
		required this.challengeHeaders,
		required this.possibleLetterCounts,
		required this.stickyCloudflare
	});
	@override
	String toString() => 'Chan4CustomCaptchaRequest(challengeUrl: $challengeUrl, challengeHeaders: $challengeHeaders, possibleLetterCounts: $possibleLetterCounts, stickyCloudflare: $stickyCloudflare)';

	@override
	bool get cloudSolveSupported => true;

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is Chan4CustomCaptchaRequest &&
		other.challengeUrl == challengeUrl &&
		mapEquals(other.challengeHeaders, challengeHeaders) &&
		listEquals(other.possibleLetterCounts, possibleLetterCounts) &&
		other.stickyCloudflare == stickyCloudflare;
	
	@override
	int get hashCode => Object.hash(challengeUrl, Object.hashAll(challengeHeaders.values), Object.hashAll(possibleLetterCounts), stickyCloudflare);
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
	const LynxchanCaptchaRequest({
		required this.board
	});
	@override
	String toString() => 'LynxchanCaptchaRequest(board: $board)';
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
	final ui.Image? alignedImage;
	final Duration lifetime;
	Chan4CustomCaptchaSolution({
		required this.challenge,
		required this.response,
		required super.acquiredAt,
		required this.lifetime,
		required this.alignedImage,
		required super.cloudflare,
		required super.ip,
		super.autoSolved
	});
	@override
	DateTime? get expiresAt => acquiredAt.add(lifetime);
	@override
	String toString() => 'Chan4CustomCaptchaSolution(challenge: $challenge, response: $response)';

	@override
	void dispose() {
		super.dispose();
		alignedImage?.dispose();
	}
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
	final bool countsUnreliable;
	final int page;
	final int? maxPage;
	final ImageboardSiteArchive archive;
	final Map<String, Object> memo;
	ImageboardArchiveSearchResultPage({
		required this.posts,
		required this.countsUnreliable,
		required this.page,
		required this.maxPage,
		required this.archive,
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
	final Future<CaptchaRequest> Function() getCaptchaRequest;
	final Future<void> Function(ChoiceReportMethodChoice choice, CaptchaSolution captchaSolution) onSubmit;
	const ChoiceReportMethod({
		required this.post,
		required this.question,
		required this.choices,
		required this.getCaptchaRequest,
		required this.onSubmit
	});
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

	String? get fileExt => file?.split('.').last.toLowerCase();

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
		other.file == file &&
		other.spoiler == spoiler &&
		other.overrideFilenameWithoutExtension == overrideFilenameWithoutExtension &&
		other.flag == flag &&
		other.useLoginSystem == useLoginSystem &&
		other.overrideRandomizeFilenames == overrideRandomizeFilenames;
	
	@override
	int get hashCode => Object.hash(board, threadId, name, options, subject, file, spoiler, overrideFilenameWithoutExtension, flag, useLoginSystem, overrideRandomizeFilenames);

	@override
	String toString() => 'DraftPost(board: $board, threadId: $threadId, name: $name, options: $options, subject: $subject, file: $file, spoiler: $spoiler, overrideFilenameWithoutExtension: $overrideFilenameWithoutExtension, flag: $flag, useLoginSystem: $useLoginSystem, overrideRandomizeFilenames: $overrideRandomizeFilenames)';
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

abstract class ImageboardSiteArchive {
	final Dio client = Dio(BaseOptions(
		/// Avoid hanging for 2 minutes+ with default value
		/// 15 seconds should be well long enough for initial TCP handshake
		connectTimeout: 15000
	));
	final Map<ThreadIdentifier, Thread> _catalogCache = {};
	final Map<String, DateTime> _lastCatalogCacheTime = {};
	String get userAgent => overrideUserAgent ?? Settings.instance.userAgent;
	final String? overrideUserAgent;
	ImageboardSiteArchive({
		required this.overrideUserAgent
	}) {
		client.interceptors.add(CloudflareBlockingInterceptor());
		client.interceptors.add(SeparatedCookieManager(
			wifiCookieJar: Persistence.wifiCookies,
			cellularCookieJar: Persistence.cellularCookies
		));
		client.interceptors.add(InterceptorsWrapper(
			onRequest: (options, handler) {
				options.headers['user-agent'] ??= userAgent;
				options.headers[HttpHeaders.acceptEncodingHeader] ??= 'gzip';
				handler.next(options);
			}
		));
		client.interceptors.add(CloudflareInterceptor());
		client.interceptors.add(LoggingInterceptor.instance);
		client.httpClientAdapter = BadCertificateHttpClientAdapter();
	}
	String get name;
	Future<Post> getPost(String board, int id, {required RequestPriority priority});
	Future<Thread> getThread(ThreadIdentifier thread, {ThreadVariant? variant, required RequestPriority priority});
	@protected
	Future<List<Thread>> getCatalogImpl(String board, {CatalogVariant? variant, required RequestPriority priority});
	Future<List<Thread>> getCatalog(String board, {CatalogVariant? variant, required RequestPriority priority, DateTime? acceptCachedAfter}) async {
		return runEphemerallyLocked('getCatalog($name,$board)', () async {
			if (acceptCachedAfter != null && (_lastCatalogCacheTime[board]?.isAfter(acceptCachedAfter) ?? false)) {
				return _catalogCache.values.where((t) => !t.isArchived && t.board == board).toList(); // Order is wrong but shouldn't matter
			}
			final catalog = await getCatalogImpl(board, variant: variant, priority: priority);
			final oldThreads = Map.fromEntries(_catalogCache.entries.where((e) => e.key.board == board));
			for (final newThread in catalog) {
				oldThreads.remove(newThread.identifier);
				_catalogCache[newThread.identifier] = newThread;
			}
			for (final oldThread in oldThreads.values) {
				// Not in new catalog, it must have been archived
				oldThread.isArchived = true;
			}
			_lastCatalogCacheTime[board] = DateTime.now();
			return catalog;
		});
	}
	/// If an empty list is returned from here, the bottom of the catalog has been reached.
	@protected
	Future<List<Thread>> getMoreCatalogImpl(String board, Thread after, {CatalogVariant? variant, required RequestPriority priority}) async => [];
	Future<List<Thread>> getMoreCatalog(String board, Thread after, {CatalogVariant? variant, required RequestPriority priority}) async {
		final moreCatalog = await getMoreCatalogImpl(board, after, variant: variant, priority: priority);
		_catalogCache.addAll({
			for (final t in moreCatalog)
				t.identifier: t
		});
		return moreCatalog;
	}
	Thread? getThreadFromCatalogCache(ThreadIdentifier identifier) => _catalogCache[identifier];
	Future<List<ImageboardBoard>> getBoards({required RequestPriority priority});
	Future<ImageboardArchiveSearchResultPage> search(ImageboardArchiveSearchQuery query, {required int page, ImageboardArchiveSearchResultPage? lastResult});
	@protected
	String getWebUrlImpl(String board, [int? threadId, int? postId]);
	Future<BoardThreadOrPostIdentifier?> decodeUrl(String url);
	int placeOrphanPost(List<Post> posts, Post post) {
		final index = posts.indexWhere((p) => p.id > post.id);
		post.isDeleted = true;
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
}

abstract class ImageboardSite extends ImageboardSiteArchive {
	Map<String, Map<String, String>> _memoizedWifiHeaders = {};
	Map<String, Map<String, String>> _memoizedCellularHeaders = {};
	final List<ImageboardSiteArchive> archives;
	ImageboardSite({
		required this.archives,
		required super.overrideUserAgent
	});
	Future<void> _ensureCookiesMemoizedForUrl(Uri url) async {
		_memoizedWifiHeaders.putIfAbsent(url.host, () => {

		})['cookie'] = (await Persistence.wifiCookies.loadForRequest(url)).join('; ');
		_memoizedCellularHeaders.putIfAbsent(url.host, () => {

		})['cookie'] = (await Persistence.cellularCookies.loadForRequest(url)).join('; ');
	}
	Future<void> _ensureCookiesMemoizedForAttachment(Attachment attachment) async {
		await _ensureCookiesMemoizedForUrl(Uri.parse(attachment.url));
		await _ensureCookiesMemoizedForUrl(Uri.parse(attachment.thumbnailUrl));
	}
	Map<String, String> getHeaders(Uri url) {
		if (Settings.instance.connectivity == ConnectivityResult.mobile) {
			return {
				'user-agent': userAgent,
				..._memoizedCellularHeaders[url.host] ?? {}
			};
		}
		return {
			'user-agent': userAgent,
			..._memoizedWifiHeaders[url.host] ?? {}
		};
	}
	Uri get passIconUrl => Uri.https('boards.chance.surf', '/minileaf.gif');
	String get baseUrl;
	Uri get iconUrl;
	Future<CaptchaRequest> getCaptchaRequest(String board, [int? threadId]);
	Future<CaptchaRequest> getDeleteCaptchaRequest(ThreadIdentifier thread) async => const NoCaptchaRequest();
	Future<PostReceipt> submitPost(DraftPost post, CaptchaSolution captchaSolution, CancelToken cancelToken);
	Duration getActionCooldown(String board, ImageboardAction action, bool cellular) => const Duration(seconds: 3);
	Future<void> deletePost(ThreadIdentifier thread, PostReceipt receipt, CaptchaSolution captchaSolution, {required bool imageOnly}) async {
		throw UnimplementedError('Post deletion is not implemented on $name ($runtimeType)');
	}
	Future<Post> getPostFromArchive(String board, int id, {required RequestPriority priority}) async {
		final Map<String, String> errorMessages = {};
		for (final archive in archives) {
			if (persistence?.browserState.disabledArchiveNames.contains(archive.name) ?? false) {
				continue;
			}
			try {
				final post = await archive.getPost(board, id, priority: priority);
				await Future.wait(post.attachments.map(_ensureCookiesMemoizedForAttachment));
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
	Future<Thread> getThreadFromArchive(ThreadIdentifier thread, {Future<void> Function(Thread)? customValidator, required RequestPriority priority}) async {
		final Map<String, String> errorMessages = {};
		Thread? fallback;
		final validator = customValidator ?? (Thread thread) async {
			final opAttachment = thread.attachments.tryFirst ?? thread.posts_.tryFirst?.attachments.tryFirst;
			if (opAttachment != null) {
				await client.head(opAttachment.url, options: Options(
					headers: {
						...getHeaders(Uri.parse(opAttachment.url)),
						if (opAttachment.useRandomUseragent) 'user-agent': makeRandomUserAgent()
					},
					extra: {
						kPriority: priority
					}
				));
			}
		};
		final completer = Completer<Thread>();
		() async {
			await Future.wait(archives.map((archive) async {
				if (persistence?.browserState.disabledArchiveNames.contains(archive.name) ?? false) {
					return null;
				}
				try {
					final thread_ = await archive.getThread(thread, priority: priority).timeout(const Duration(seconds: 15));
					if (completer.isCompleted) return null;
					await Future.wait(thread_.posts_.expand((p) => p.attachments).map(_ensureCookiesMemoizedForAttachment));
					thread_.archiveName = archive.name;
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
						errorMessages[archive.name] = e.toStringDio();
					}
				}
			}));
			if (completer.isCompleted) {
				// Do nothing, the thread was already returned
			}
			else if (fallback != null) {
				completer.complete(fallback);
			}
			else if (errorMessages.isNotEmpty) {
				completer.completeError(ImageboardArchiveException(errorMessages));
			}
			else {
				completer.completeError(BoardNotArchivedException(thread.board));
			}
		}();
		return completer.future;
	}

	@override
	Future<ImageboardArchiveSearchResultPage> search(ImageboardArchiveSearchQuery query, {required int page, ImageboardArchiveSearchResultPage? lastResult}) => searchArchives(query, page: page, lastResult: lastResult);

	Future<ImageboardArchiveSearchResultPage> searchArchives(ImageboardArchiveSearchQuery query, {required int page, ImageboardArchiveSearchResultPage? lastResult}) async {
		String s = '';
		for (final archive in archives) {
			if (persistence?.browserState.disabledArchiveNames.contains(archive.name) ?? false) {
				continue;
			}
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
	Uri? getSpoilerImageUrl(Attachment attachment, {ThreadIdentifier? thread}) => null;
	Future<ImageboardReportMethod> getPostReportMethod(PostIdentifier post) async {
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
	Iterable<ImageboardSnippet> getBoardSnippets(String board) => const Iterable.empty();
	Future<List<ImageboardBoard>> getBoardsForQuery(String query) async => [];
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
	Future<List<Post>> getStubPosts(ThreadIdentifier thread, List<ParentAndChildIdentifier> postIds, {required RequestPriority priority}) async => throw UnimplementedError();
	bool get supportsMultipleBoards => true;
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
	String formatUsername(String name) => name;
	@mustCallSuper
	void migrateFromPrevious(covariant ImageboardSite oldSite) {
		_catalogCache.addAll(oldSite._catalogCache);
		_memoizedWifiHeaders = oldSite._memoizedWifiHeaders;
		_memoizedCellularHeaders = oldSite._memoizedCellularHeaders;
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
	Future<Map<int, String>> queryPreferredArchive(String board, List<int> threadIds) async {
		final sorted = threadIds.toList()..sort();
		final diffs = List.generate(sorted.length - 1, (i) => sorted[i + 1] - sorted[i]);
		final response = await client.get('$_preferredArchiveApiRoot/ops', queryParameters: {
			'siteType': siteType,
			'siteData': siteData,
			'board': board,
			'base': sorted.first.toString(),
			'diffs': base64Url.encode(gzip.encode(utf8.encode(diffs.join(','))))
		});
		return {
			for (final entry in (response.data as Map).entries) int.parse(entry.key): entry.value
		};
	}
	@override
	Future<List<Thread>> getCatalog(String board, {CatalogVariant? variant, required RequestPriority priority, DateTime? acceptCachedAfter}) async {
		final catalog = await super.getCatalog(board, variant: variant, priority: priority, acceptCachedAfter: acceptCachedAfter);
		await Future.wait(catalog.expand((t) => t.posts_.expand((p) => p.attachments)).map(_ensureCookiesMemoizedForAttachment));
		return catalog;
	}
	@override
	Future<List<Thread>> getMoreCatalog(String board, Thread after, {CatalogVariant? variant, required RequestPriority priority}) async {
		final catalog = await super.getMoreCatalog(board, after, variant: variant, priority: priority);
		await Future.wait(catalog.expand((t) => t.posts_.expand((p) => p.attachments)).map(_ensureCookiesMemoizedForAttachment));
		return catalog;
	}
	@protected
	Future<Thread> getThreadImpl(ThreadIdentifier thread, {ThreadVariant? variant, required RequestPriority priority});
	@override
	Future<Thread> getThread(ThreadIdentifier thread, {ThreadVariant? variant, required RequestPriority priority}) async {
		final theThread = await getThreadImpl(thread, variant: variant, priority: priority);
		await Future.wait(theThread.posts_.expand((p) => p.attachments).map(_ensureCookiesMemoizedForAttachment));
		return theThread;
	}
	Future<ImageboardUserInfo> getUserInfo(String username) async => throw UnimplementedError();
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
	bool get hasExpiringThreads => true;
	CatalogVariant get defaultCatalogVariant => Settings.instance.catalogVariant;
	set defaultCatalogVariant(CatalogVariant value) => Settings.catalogVariantSetting.set(Settings.instance, value);
	bool isRedirectGateway(Uri uri) => false;
}

abstract class ImageboardSiteLoginSystem {
	@protected
	Map<PersistCookieJar, bool> loggedIn = {};
	ImageboardSite get parent;
	String get name;
	List<ImageboardSiteLoginField> getLoginFields();
	Future<void> login(Map<ImageboardSiteLoginField, String> fields);
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
	Future<void> logout(bool fromBothWifiAndCellular);
	bool isLoggedIn(PersistCookieJar jar) {
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
			archives: archives
		);
	}
	else if (data['type'] == 'soyjak') {
		return SiteSoyjak(
			name: data['name'],
			baseUrl: data['baseUrl'],
			overrideUserAgent: overrideUserAgent,
			archives: archives,
			boardsWithCaptcha: (data['boardsWithCaptcha'] as List?)?.cast<String>(),
			captchaQuestion: data['captchaQuestion']
		);
	}
	else if (data['type'] == 'frenschan') {
		return SiteFrenschan(
			name: data['name'],
			baseUrl: data['baseUrl'],
			overrideUserAgent: overrideUserAgent,
			archives: archives
		);
	}
	else if (data['type'] == 'wizchan') {
		return SiteWizchan(
			name: data['name'],
			baseUrl: data['baseUrl'],
			overrideUserAgent: overrideUserAgent,
			archives: archives
		);
	}
	else if (data['type'] == 'lainchan_org') {
		return SiteLainchanOrg(
			name: data['name'],
			baseUrl: data['baseUrl'],
			faviconPath: data['faviconPath'] ?? '/favicon.ico',
			defaultUsername: data['defaultUsername'] ?? 'Anonymous',
			overrideUserAgent: overrideUserAgent,
			archives: archives
		);
	}
	else if (data['type'] == 'dvach') {
		return SiteDvach(
			name: data['name'],
			baseUrl: data['baseUrl'],
			overrideUserAgent: overrideUserAgent,
			archives: archives
		);
	}
	else if (data['type'] == 'futaba') {
		return SiteFutaba(
			name: data['name'],
			baseUrl: data['baseUrl'],
			maxUploadSizeBytes: data['maxUploadSizeBytes'],
			overrideUserAgent: overrideUserAgent,
			archives: archives
		);
	}
	else if (data['type'] == 'reddit') {
		return SiteReddit(
			overrideUserAgent: overrideUserAgent,
			archives: archives
		);
	}
	else if (data['type'] == 'hackernews') {
		return SiteHackerNews(
			overrideUserAgent: overrideUserAgent,
			archives: archives
		);
	}
	else if (data['type'] == 'erischan') {
		return SiteErischan(
			name: data['name'],
			baseUrl: data['baseUrl'],
			overrideUserAgent: overrideUserAgent,
			archives: archives
		);
	}
	else if (data['type'] == '4chan') {
		final captchaTicketLifetime = data['captchaTicketLifetime'] as int?;
		final reportCooldown = data ['reportCooldown'] as int?;
		return Site4Chan(
			name: data['name'],
			imageUrl: data['imageUrl'],
			captchaKey: data['captchaKey'],
			apiUrl: data['apiUrl'],
			sysUrl: data['sysUrl'],
			baseUrl: data['baseUrl'],
			staticUrl: data['staticUrl'],
			captchaUserAgents: (data['captchaUserAgents'] as Map?)?.cast<String, String>() ?? {},
			possibleCaptchaLetterCounts: (data['possibleCaptchaLetterCounts'] as List?)?.cast<int>() ?? [],
			postingHeaders: (data['postingHeaders'] as Map?)?.cast<String, String>() ?? {},
			captchaTicketLifetime: captchaTicketLifetime == null ? null : Duration(seconds: captchaTicketLifetime),
			reportCooldown: Duration(seconds: reportCooldown ?? 20),
			spamFilterCaptchaDelayGreen: Duration(milliseconds: data['spamFilterCaptchaDelayGreen'] ?? 1000),
			spamFilterCaptchaDelayYellow: Duration(milliseconds: data['spamFilterCaptchaDelayYellow'] ?? 5000),
			spamFilterCaptchaDelayRed: Duration(milliseconds: data['spamFilterCaptchaDelayRed'] ?? 12000),
			stickyCloudflare: data['stickyCloudflare'] ?? false,
			subjectCharacterLimit: data['subjectCharacterLimit'],
			overrideUserAgent: overrideUserAgent,
			boardFlags: (data['boardFlags'] as Map?)?.cast<String, Map>().map((k, v) => MapEntry(k, v.cast<String, String>())) ?? {},
			searchUrl: data['searchUrl'] ?? '',
			archives: archives
		);
	}
	else if (data['type'] == 'lynxchan') {
		return SiteLynxchan(
			name: data['name'],
			baseUrl: data['baseUrl'],
			boards: boards,
			overrideUserAgent: overrideUserAgent,
			archives: archives,
			defaultUsername: data['defaultUsername'] ?? 'Anonymous',
			hasLinkCookieAuth: data['hasLinkCookieAuth'] ?? false
		);
	}
	else if (data['type'] == '8chan') {
		return Site8Chan(
			name: data['name'],
			baseUrl: data['baseUrl'],
			boards: boards,
			overrideUserAgent: overrideUserAgent,
			archives: archives,
			defaultUsername: data['defaultUsername'] ?? 'Anonymous',
			hasLinkCookieAuth: data['hasLinkCookieAuth'] ?? false
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
			boards: boards,
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
			boards: boards,
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
			archives: archives
		);
	}
	else if (data['type'] == 'karachan') {
		return SiteKarachan(
			baseUrl: data['baseUrl'],
			name: data['name'],
			captchaKey: data['captchaKey'] ?? '',
			defaultUsername: data['defaultUsername'] ?? 'Anonymous',
			overrideUserAgent: overrideUserAgent,
			archives: archives
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
			archives: archives
		);
	}
	else {
		print(data);
		throw UnknownSiteTypeException(data['type']);
	}
}
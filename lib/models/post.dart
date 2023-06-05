import 'dart:io';
import 'dart:math';

import 'package:chan/models/flag.dart';
import 'package:chan/models/intern.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/sites/4chan.dart';
import 'package:chan/sites/foolfuuka.dart';
import 'package:chan/sites/futaba.dart';
import 'package:chan/sites/fuuka.dart';
import 'package:chan/sites/hacker_news.dart';
import 'package:chan/sites/jforum.dart';
import 'package:chan/sites/jschan.dart';
import 'package:chan/sites/karachan.dart';
import 'package:chan/sites/lainchan.dart';
import 'package:chan/sites/lynxchan.dart';
import 'package:chan/sites/reddit.dart';
import 'package:chan/sites/xenforo.dart';
import 'package:chan/util.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:isolate_pool_2/isolate_pool_2.dart';
import 'package:mutex/mutex.dart';
import 'package:string_similarity/string_similarity.dart';

import '../widgets/post_spans.dart';

import 'attachment.dart';

part 'post.g.dart';

// Avoid creating too many small threads
final _makeSpanPool = IsolatePool((Platform.numberOfProcessors / 2).floor().clamp(1, 4));
bool _makeSpanPoolStarted = false;
final _makeSpanPoolLock = Mutex();
Future<IsolatePool> _getMakeSpanPool() async {
	return _makeSpanPoolLock.protect(() async {
		if (!_makeSpanPoolStarted) {
			await _makeSpanPool.start();
			_makeSpanPoolStarted = true;
		}
		return _makeSpanPool;
	});
}

class _MakeSpanJob extends PooledJob<PostNodeSpan> {
	final Post post;
	_MakeSpanJob(this.post);

	@override
	Future<PostNodeSpan> job() async {
		return post._makeSpan();
	}
}

@HiveType(typeId: 13)
enum PostSpanFormat {
	@HiveField(0)
	chan4,
	@HiveField(1)
	foolFuuka,
	@HiveField(2)
	lainchan,
	@HiveField(3)
	fuuka,
	@HiveField(4)
	futaba,
	@HiveField(5)
	reddit,
	@HiveField(6)
	hackerNews,
	@HiveField(7)
	stub,
	@HiveField(8)
	lynxchan,
	@HiveField(9)
	chan4Search,
	@HiveField(10)
	xenforo,
	@HiveField(11)
	pageStub,
	@HiveField(12)
	karachan,
	@HiveField(13)
	jsChan,
	@HiveField(14)
	jForum;
	bool get hasInlineAttachments => switch (this) {
		xenforo || reddit => true,
		_ => false
	};
	bool get hasInlineReplies => switch (this) {
		reddit || stub || pageStub => false,
		_ => true
	};
	bool get hasWeakQuoteLinks => this == jForum;
}

void _readHookPostFields(Map<int, dynamic> fields) {
	final deprecatedAttachment = fields[6] as Attachment?;
	List<Attachment> fallbackAttachments = const [];
	if (deprecatedAttachment != null) {
		fallbackAttachments = [deprecatedAttachment].toList(growable: false);
	}
	fields[PostFields.attachments_.fieldNumber] ??= fallbackAttachments;
}

@HiveType(typeId: 11, isOptimized: true, readHook: _readHookPostFields)
class Post implements Filterable {
	@override
	@HiveField(0)
	final String board;
	@HiveField(1)
	final String text;
	@HiveField(2)
	final String name;
	@override
	@HiveField(3)
	final DateTime time;
	@override
	@HiveField(4)
	final int threadId;
	@override
	@HiveField(5)
	final int id;
	@HiveField(7, isOptimized: true, merger: PrimitiveMerger<Flag?>())
	Flag? flag;
	@HiveField(8, isOptimized: true)
	final String? posterId;
	@HiveField(9)
	PostSpanFormat spanFormat;
	// Do not persist
	PostNodeSpan? _span;
	bool get isInitialized => _span != null;
	/// '$board/$postId' -> threadId (for FoolFuuka)
	/// '$postId/$weakQuoteLinkId' -> postId (for JForum)
	@HiveField(12, isOptimized: true)
	Map<String, int>? extraMetadata;
	PostNodeSpan _makeSpan() {
		switch (spanFormat) {
			case PostSpanFormat.chan4:
				return Site4Chan.makeSpan(board, threadId, text);
			case PostSpanFormat.foolFuuka:
				return FoolFuukaArchive.makeSpan(board, threadId, extraMetadata ?? {}, text);
			case PostSpanFormat.lainchan:
				return SiteLainchan.makeSpan(board, threadId, text);
			case PostSpanFormat.fuuka:
				return FuukaArchive.makeSpan(board, threadId, extraMetadata ?? {}, text);
			case PostSpanFormat.futaba:
				return SiteFutaba.makeSpan(board, threadId, text);
			case PostSpanFormat.reddit:
				return SiteReddit.makeSpan(board, threadId, text, attachments: attachments_);
			case PostSpanFormat.hackerNews:
				return SiteHackerNews.makeSpan(text);
			case PostSpanFormat.stub:
				return const PostNodeSpan([
					PostTextSpan('Stub post')
				]);
			case PostSpanFormat.lynxchan:
				return SiteLynxchan.makeSpan(board, threadId, text);
			case PostSpanFormat.chan4Search:
				return Site4Chan.makeSpan(board, threadId, text, fromSearch: true);
			case PostSpanFormat.xenforo:
				return SiteXenforo.makeSpan(board, threadId, id, text);
			case PostSpanFormat.pageStub:
				return PostNodeSpan([
					PostTextSpan('Page $id')
				]);
			case PostSpanFormat.karachan:
				return SiteKarachan.makeSpan(board, threadId, text);
			case PostSpanFormat.jsChan:
				return SiteJsChan.makeSpan(board, threadId, text);
			case PostSpanFormat.jForum:
				return SiteJForum.makeSpan(text);
		}
	}
	PostNodeSpan get span {
		_span ??= _makeSpan();
		return _span!;
	}
	Future<void> preinit() async {
		if (_span != null) {
			return;
		}
		if (text.length > 500) {
			_span = await (await _getMakeSpanPool()).scheduleJob(_MakeSpanJob(this));
		}
		else {
			_span = _makeSpan();
		}
	}
	// Do not persist
	static const _kEmptyReplyIds = <int>[];
	List<int> replyIds = const [];
	void maybeAddReplyId(int replyId) {
		if (identical(replyIds, _kEmptyReplyIds)) {
			// Make it modifiable
			replyIds = List.filled(1, replyId, growable: false);
		}
		else if (!replyIds.contains(replyId)) {
			final oldReplyIds = replyIds;
			replyIds = List.filled(replyIds.length + 1, replyId, growable: false);
			replyIds.setAll(0, oldReplyIds);
		}
	}
	bool updateWeakQuoteLinks(Map<int, String> earlierPostTexts) {
		bool updated = false;
		outer:
		for (final s in span.traverse(this)) {
			if (s is! PostWeakQuoteLinkSpan) {
				continue;
			}
			if (s.findQuoteTarget(this) != null) {
				// Already matched
				continue;
			}
			final quoteText = s.quote.child.buildText(this, forQuoteComparison: true);
			// First try for whole string match
			for (final otherPostText in earlierPostTexts.entries) {
				final similarity = quoteText.similarityTo(otherPostText.value);
				if (similarity > 0.9) {
					s.setQuoteTarget(this, otherPostText.key, true);
					updated = true;
					continue outer;
				}
			}
			// Then look for substring
			for (final otherPostText in earlierPostTexts.entries) {
				if (otherPostText.value.contains(quoteText)) {
					final lengthFactor = min(quoteText.length / otherPostText.value.length, otherPostText.value.length / quoteText.length);
					s.setQuoteTarget(this, otherPostText.key, lengthFactor > 0.9);
					updated = true;
					continue outer;
				}
			}
		}
		if (updated) {
			_repliedToIds = null;
		}
		return updated;
	}
	@HiveField(11, isOptimized: true, defaultValue: false)
	bool attachmentDeleted;
	@HiveField(13, isOptimized: true)
	String? trip;
	@HiveField(14, isOptimized: true)
	int? passSinceYear;
	@HiveField(15, isOptimized: true)
	String? capcode;
	@HiveField(16, isOptimized: true, defaultValue: <Attachment>[], merger: Attachment.unmodifiableListMerger)
	List<Attachment> attachments_;
	Iterable<Attachment> get attachments => spanFormat.hasInlineAttachments ? attachments_.followedBy(_inlineAttachments) : attachments_;
	@HiveField(17, isOptimized: true)
	final int? upvotes;
	@HiveField(18, isOptimized: true)
	final int? parentId;
	// field 19 was used for int omittedChildrenCount
	@HiveField(20, isOptimized: true, defaultValue: false)
	bool hasOmittedReplies;
	@override
	@HiveField(21, isOptimized: true, defaultValue: false)
	final bool isDeleted;
	@HiveField(22, isOptimized: true)
	int? ipNumber;
	@HiveField(23, isOptimized: true)
	String? archiveName;
	@HiveField(24, isOptimized: true)
	final String? email;

	Post({
		required String board,
		required this.text,
		required String name,
		required this.time,
		this.trip,
		required this.threadId,
		required this.id,
		required this.spanFormat,
		this.flag,
		this.attachmentDeleted = false,
		this.posterId,
		this.extraMetadata,
		this.passSinceYear,
		this.capcode,
		required List<Attachment> attachments_,
		this.upvotes,
		this.parentId,
		this.hasOmittedReplies = false,
		this.isDeleted = false,
		this.ipNumber,
		this.archiveName,
		this.email
	}) : board = intern(board), name = intern(name), attachments_ = attachments_.isEmpty ? const [] : List.of(attachments_, growable: false);

	@override
	String toString() {
		if (isStub) {
			return 'Stub Post $id (parentId: $parentId)';
		}
		return 'Post $id ($name): ${text.length > 23 ? '${text.substring(0, 20)}...' : text}';
	}

	@override
	String? getFilterFieldText(String fieldName) {
		switch (fieldName) {
			case 'name':
				return name;
			case 'filename':
				return attachments.map((a) => a.filename).join('\n');
			case 'dimensions':
				return attachments.map((a) => '${a.width}x${a.height}').join('\n');
			case 'text':
				return buildText();
			case 'postID':
				return id.toString();
			case 'posterID':
				return posterId;
			case 'flag':
				return flag?.name;
			case 'md5':
				return md5s.join(' ');
			case 'capcode':
				return capcode;
			case 'trip':
				return trip;
			case 'email':
				return email;
			default:
				return null;
		}
	}
	@override
	bool get hasFile => attachments.isNotEmpty;
	@override
	bool get isThread => id == threadId;
	List<int>? _repliedToIds;
	@override
	List<int> get repliedToIds {
		return _repliedToIds ??= _makeRepliedToIds();
	}
	List<int> _makeRepliedToIds() {
		final parentId = this.parentId;
		if (!spanFormat.hasInlineReplies) {
			return parentId != null ? List.filled(1, parentId, growable: false) : const [];
		}
		final dedupe = {
			// Disallow recursive replies
			id,
			if (parentId != null) parentId
		};
		return [
			if (parentId != null) parentId,
			..._referencedPostIds.where(dedupe.add)
		].toList(growable: false);
	}
	@override
	Iterable<String> get md5s => attachments_.map((a) => a.md5); // inlineAttachments will never really have MD5s
	Iterable<Attachment> get _inlineAttachments sync* {
		for (final s in span.traverse(this)) {
			if (s is PostAttachmentsSpan) {
				yield* s.attachments;
			}
		}
	}
	bool get containsLink => span.traverse(this).any((s) => s is PostLinkSpan);
	Iterable<int> get _referencedPostIds sync* {
		for (final s in span.traverse(this)) {
			if (s is PostQuoteLinkSpan && s.board == board) {
				yield s.postId;
			}
		}
	}
	Iterable<PostIdentifier> get referencedPostIdentifiers sync* {
		for (final s in span.traverse(this)) {
			if (s is PostQuoteLinkSpan && s.threadId != null) {
				yield PostIdentifier(s.board, s.threadId!, s.postId);
			}
		}
	}
	bool get hasVeryTallWidgetSpan => span.traverse(this).any((s) => s is PostCodeSpan && '\n'.allMatches(s.text).length > 4);
	String buildText({bool forQuoteComparison = false}) => span.buildText(this, forQuoteComparison: forQuoteComparison);

	void migrateFrom(Post previous) {
		ipNumber ??= previous.ipNumber;
		for (final attachment in attachments_) {
			final otherAttachment = previous.attachments_.tryFirstWhere((a) => a.id == attachment.id);
			if (attachment.sizeInBytes == null) {
				// This is probably Reddit
				// The [otherAttachment] has a much better idea of the width/height
				attachment.sizeInBytes = otherAttachment?.sizeInBytes;
				attachment.width = otherAttachment?.width ?? attachment.width;
				attachment.height = otherAttachment?.height ?? attachment.height;
			}
			else {
				// Naive merge
				attachment.sizeInBytes ??= otherAttachment?.sizeInBytes;
				attachment.width ??= otherAttachment?.width;
				attachment.height ??= otherAttachment?.height;
			}
		}
		if (text == previous.text) {
			_span ??= previous._span;
		}
	}

	ThreadIdentifier get threadIdentifier => ThreadIdentifier(board, threadId);
	PostIdentifier get identifier => PostIdentifier(board, threadId, id);

	@override
	int get replyCount => replyIds.length;

	String get globalId => '${board}_${threadId}_$id';

	bool get isStub => spanFormat == PostSpanFormat.stub;

	/// For indicating unloaded page
	bool get isPageStub => spanFormat == PostSpanFormat.pageStub;

	@override
	bool get isSticky => false;

	@override
	bool operator ==(Object other) =>
		identical(this, other) ||
		other is Post &&
		other.board == board &&
		other.id == id &&
		other.text == text &&
		other.upvotes == upvotes &&
		other.isDeleted == isDeleted &&
		listEquals(other.attachments_, attachments_) &&
		other.name == name &&
		other.hasOmittedReplies == hasOmittedReplies &&
		other.flag == flag &&
		other.attachmentDeleted == attachmentDeleted &&
		other.archiveName == archiveName &&
		other.email == email &&
		other.capcode == capcode &&
		mapEquals(other.extraMetadata, extraMetadata);
	
	bool isIdenticalForFilteringPurposes(Post other) {
		return 
			other.board == board &&
			other.id == id &&
			other.text == text &&
			//other.upvotes == upvotes &&
			other.isDeleted == isDeleted &&
			listEquals(other.attachments_, attachments_) &&
			other.name == name &&
			//other.hasOmittedReplies == hasOmittedReplies &&
			other.flag == flag &&
			//other.attachmentDeleted == attachmentDeleted &&
			other.archiveName == archiveName &&
			other.email == email;
	}

	Post copyWith({
		bool? isDeleted,
		/// To clarify whether to override with null or not
		NullWrapper<String>? archiveName
	}) => Post(
		board: board,
		text: text,
		name: name,
		time: time,
		threadId: threadId,
		id: id,
		flag: flag,
		posterId: posterId,
		spanFormat: spanFormat,
		extraMetadata: extraMetadata,
		attachmentDeleted: attachmentDeleted,
		trip: trip,
		passSinceYear: passSinceYear,
		capcode: capcode,
		attachments_: attachments_,
		upvotes: upvotes,
		parentId: parentId,
		hasOmittedReplies: hasOmittedReplies,
		isDeleted: isDeleted ?? this.isDeleted,
		ipNumber: ipNumber,
		archiveName: archiveName != null ? archiveName.value : this.archiveName,
		email: email,
	).._span = _span..replyIds = replyIds; // [text] hasn't changed

	@override
	int get hashCode => Object.hash(board, id);
}

class PostIdentifier {
	final String board;
	final int threadId;
	final int postId;
	PostIdentifier(this.board, this.threadId, this.postId);

	PostIdentifier.thread(ThreadIdentifier identifier) : board = identifier.board, threadId = identifier.id, postId = identifier.id;

	@override
	String toString() => 'PostIdentifier: /$board/$threadId/$postId';

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		(other is PostIdentifier) &&
		(other.board == board) &&
		(other.threadId == threadId) &&
		(other.postId == postId);

	@override
	int get hashCode => Object.hash(board, threadId, postId);

	ThreadIdentifier get thread => ThreadIdentifier(board, threadId);
	ThreadOrPostIdentifier get threadOrPostId => ThreadOrPostIdentifier(board, threadId, postId);
	BoardThreadOrPostIdentifier get boardThreadOrPostId => BoardThreadOrPostIdentifier(board, threadId, postId);
}

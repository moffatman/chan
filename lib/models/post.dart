import 'dart:io';

import 'package:chan/models/flag.dart';
import 'package:chan/models/intern.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/sites/4chan.dart';
import 'package:chan/sites/foolfuuka.dart';
import 'package:chan/sites/futaba.dart';
import 'package:chan/sites/fuuka.dart';
import 'package:chan/sites/hacker_news.dart';
import 'package:chan/sites/lainchan.dart';
import 'package:chan/sites/lynxchan.dart';
import 'package:chan/sites/reddit.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:pool/pool.dart';

import '../widgets/post_spans.dart';

import 'attachment.dart';

part 'post.g.dart';

// Avoid creating too many small threads
final _makeSpanPool = Pool((Platform.numberOfProcessors / 2).ceil());

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
	chan4Search
}

void _readHookPostFields(Map<int, dynamic> fields) {
	final deprecatedAttachment = fields[6] as Attachment?;
	List<Attachment> fallbackAttachments = const [];
	if (deprecatedAttachment != null) {
		fallbackAttachments = [deprecatedAttachment].toList(growable: false);
	}
	fields[PostFields.attachments.fieldNumber] ??= fallbackAttachments;
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
	@HiveField(3)
	final DateTime time;
	@HiveField(4)
	final int threadId;
	@override
	@HiveField(5)
	final int id;
	@HiveField(7, isOptimized: true, merger: PrimitiveMerger<Flag?>())
	final Flag? flag;
	@HiveField(8, isOptimized: true)
	final String? posterId;
	@HiveField(9)
	PostSpanFormat spanFormat;
	// Do not persist
	PostNodeSpan? _span;
	bool get isInitialized => _span != null;
	@HiveField(12, isOptimized: true)
	Map<String, int>? foolfuukaLinkedPostThreadIds;
	PostNodeSpan _makeSpan() {
		switch (spanFormat) {
			case PostSpanFormat.chan4:
				return Site4Chan.makeSpan(board, threadId, text);
			case PostSpanFormat.foolFuuka:
				return FoolFuukaArchive.makeSpan(board, threadId, foolfuukaLinkedPostThreadIds ?? {}, text);
			case PostSpanFormat.lainchan:
				return SiteLainchan.makeSpan(board, threadId, text);
			case PostSpanFormat.fuuka:
				return FuukaArchive.makeSpan(board, threadId, foolfuukaLinkedPostThreadIds ?? {}, text);
			case PostSpanFormat.futaba:
				return SiteFutaba.makeSpan(board, threadId, text);
			case PostSpanFormat.reddit:
				return SiteReddit.makeSpan(board, threadId, text);
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
			_span = await _makeSpanPool.withResource(() => compute<Post, PostNodeSpan>((p) => p._makeSpan(), this));
		}
		else {
			_span = _makeSpan();
		}
	}
	// Do not persist
	static const _kEmptyReplyIds = <int>[];
	List<int> replyIds = const [];
	void maybeAddReplyId(int replyId) {
		if (!replyIds.contains(replyId)) {
			if (identical(replyIds, _kEmptyReplyIds)) {
				// Make it modifiable
				replyIds = [replyId].toList(growable: false);
			}
			else {
				replyIds = [...replyIds, replyId].toList(growable: false);
			}
		}
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
	List<Attachment> attachments;
	@HiveField(17, isOptimized: true)
	final int? upvotes;
	@HiveField(18, isOptimized: true)
	final int? parentId;
	// field 19 was used for int omittedChildrenCount
	@HiveField(20, isOptimized: true, defaultValue: false)
	bool hasOmittedReplies;
	@override
	@HiveField(21, isOptimized: true, defaultValue: false)
	bool isDeleted;
	@HiveField(22, isOptimized: true)
	int? ipNumber;

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
		this.foolfuukaLinkedPostThreadIds,
		this.passSinceYear,
		this.capcode,
		required List<Attachment> attachments,
		this.upvotes,
		this.parentId,
		this.hasOmittedReplies = false,
		this.isDeleted = false,
		this.ipNumber
	}) : board = intern(board), name = intern(name), attachments = attachments.isEmpty ? const [] : attachments;

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
				return span.buildText();
			case 'postID':
				return id.toString();
			case 'posterID':
				return posterId;
			case 'flag':
				return flag?.name;
			case 'md5':
				return attachments.map((a) => a.md5).join(' ');
			case 'capcode':
				return capcode;
			default:
				return null;
		}
	}
	@override
	bool get hasFile => attachments.isNotEmpty;
	@override
	bool get isThread => false;
	List<int>? _repliedToIds;
	@override
	List<int> get repliedToIds {
		_repliedToIds ??= id == threadId ? const [] : [
			if (parentId != null) parentId!,
			...span.referencedPostIds(board).where((otherId) => otherId != id)
		].toList(growable: false);
		return _repliedToIds!;
	}
	@override
	Iterable<String> get md5s => attachments.map((a) => a.md5);

	ThreadIdentifier get threadIdentifier => ThreadIdentifier(board, threadId);
	PostIdentifier get identifier => PostIdentifier(board, threadId, id);

	@override
	int get replyCount => replyIds.length;

	String get globalId => '${board}_${threadId}_$id';

	bool get isStub => spanFormat == PostSpanFormat.stub;

	@override
	bool operator ==(dynamic other) => other is Post && other.board == board && other.id == id && other.upvotes == upvotes && other.isDeleted == isDeleted && listEquals(other.attachments, attachments);

	@override
	int get hashCode => Object.hash(board, id, upvotes, isDeleted, attachments);
}

class PostIdentifier {
	final String board;
	final int threadId;
	final int? postId;
	PostIdentifier(this.board, this.threadId, this.postId);

	PostIdentifier.thread(ThreadIdentifier identifier) : board = identifier.board, threadId = identifier.id, postId = null;

	@override
	String toString() => 'PostIdentifier: /$board/$threadId/$postId';

	@override
	bool operator == (dynamic other) => (other is PostIdentifier) && (other.board == board) && (other.threadId == threadId) && (other.postId == postId);
	@override
	int get hashCode => Object.hash(board, threadId, postId);

	ThreadIdentifier get thread => ThreadIdentifier(board, threadId);
	BoardThreadOrPostIdentifier get boardThreadOrPostId => BoardThreadOrPostIdentifier(board, threadId, postId);
}

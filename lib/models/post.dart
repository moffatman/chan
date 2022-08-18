import 'package:chan/models/flag.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/sites/4chan.dart';
import 'package:chan/sites/foolfuuka.dart';
import 'package:chan/sites/fuuka.dart';
import 'package:chan/sites/lainchan.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../widgets/post_spans.dart';

import 'attachment.dart';

part 'post.g.dart';

@HiveType(typeId: 13)
enum PostSpanFormat {
	@HiveField(0)
	chan4,
	@HiveField(1)
	foolFuuka,
	@HiveField(2)
	lainchan,
	@HiveField(3)
	fuuka
}

@HiveType(typeId: 11)
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
	@HiveField(6)
	Attachment? deprecatedAttachment;
	@HiveField(7)
	final ImageboardFlag? flag;
	@HiveField(8)
	final String? posterId;
	@HiveField(9)
	PostSpanFormat spanFormat;
	PostNodeSpan? _span;
	@HiveField(12)
	Map<String, int>? foolfuukaLinkedPostThreadIds;
	PostNodeSpan _makeSpan() {
		if (spanFormat == PostSpanFormat.chan4) {
			return Site4Chan.makeSpan(board, threadId, text);
		}
		else if (spanFormat == PostSpanFormat.foolFuuka) {
			return FoolFuukaArchive.makeSpan(board, threadId, foolfuukaLinkedPostThreadIds ?? {}, text);
		}
		else if (spanFormat == PostSpanFormat.lainchan) {
			return SiteLainchan.makeSpan(board, threadId, text);
		}
		else if (spanFormat == PostSpanFormat.fuuka) {
			return FuukaArchive.makeSpan(board, threadId, foolfuukaLinkedPostThreadIds ?? {}, text);
		}
		throw UnimplementedError();
	}
	PostNodeSpan get span {
		_span ??= _makeSpan();
		return _span!;
	}
	Future<void> preinit() async {
		if (text.length > 500) {
			_span = await compute<Post, PostNodeSpan>((p) => p._makeSpan(), this);
		}
		else {
			_span = _makeSpan();
		}
	}
	@HiveField(10)
	List<int> replyIds = [];
	@HiveField(11, defaultValue: false)
	bool attachmentDeleted;
	@HiveField(13)
	String? trip;
	@HiveField(14)
	int? passSinceYear;
	@HiveField(15)
	String? capcode;
	@HiveField(16, defaultValue: [])
	final List<Attachment> attachments;
	Post({
		required this.board,
		required this.text,
		required this.name,
		required this.time,
		this.trip,
		required this.threadId,
		required this.id,
		required this.spanFormat,
		this.flag,
		this.deprecatedAttachment,
		this.attachmentDeleted = false,
		this.posterId,
		this.foolfuukaLinkedPostThreadIds,
		this.passSinceYear,
		this.capcode,
		required this.attachments
	});

	@override
	String toString() {
		return 'Post $id';
	}

	@override
	String? getFilterFieldText(String fieldName) {
		switch (fieldName) {
			case 'name':
				return name;
			case 'filename':
				return attachments.map((a) => a.filename).join(' ');
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
			default:
				return null;
		}
	}
	@override
	bool get hasFile => attachments.isNotEmpty;
	@override
	bool get isThread => false;
	@override
	Iterable<int> get repliedToIds => span.referencedPostIds(board);
	@override
	Iterable<String> get md5s => attachments.map((a) => a.md5);

	ThreadIdentifier get threadIdentifier => ThreadIdentifier(board, threadId);

	String get globalId => '${board}_${threadId}_$id';

	@override
	bool operator ==(dynamic other) => other is Post && other.board == board && other.id == id;

	@override
	int get hashCode => Object.hash(board, id);
}
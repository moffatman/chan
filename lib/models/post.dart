import 'package:chan/models/flag.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/sites/4chan.dart';
import 'package:chan/sites/foolfuuka.dart';
import 'package:chan/sites/futaba.dart';
import 'package:chan/sites/fuuka.dart';
import 'package:chan/sites/hacker_news.dart';
import 'package:chan/sites/lainchan.dart';
import 'package:chan/sites/reddit.dart';
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
	fuuka,
	@HiveField(4)
	futaba,
	@HiveField(5)
	reddit,
	@HiveField(6)
	hackerNews
}

class Post implements Filterable {
	@override
	final String board;
	final String text;
	final String name;
	final DateTime time;
	final int threadId;
	@override
	final int id;
	Attachment? deprecatedAttachment;
	final ImageboardFlag? flag;
	final String? posterId;
	PostSpanFormat spanFormat;
	PostNodeSpan? _span;
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
		}
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
	List<int> replyIds = [];
	bool attachmentDeleted;
	String? trip;
	int? passSinceYear;
	String? capcode;
	final List<Attachment> attachments;
	final int? upvotes;
	final int? parentId;
	int omittedChildrenCount;

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
		required this.attachments,
		this.upvotes,
		this.parentId,
		this.omittedChildrenCount = 0
	});

	@override
	String toString() {
		return 'Post $id ($name): ${text.length > 23 ? '${text.substring(0, 20)}...' : text}';
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
		_repliedToIds ??= id == threadId ? [] : [
			if (parentId != null) parentId!,
			...span.referencedPostIds(board)
		];
		return _repliedToIds!;
	}
	@override
	Iterable<String> get md5s => attachments.map((a) => a.md5);

	ThreadIdentifier get threadIdentifier => ThreadIdentifier(board, threadId);

	String get globalId => '${board}_${threadId}_$id';

	@override
	bool operator ==(dynamic other) => other is Post && other.board == board && other.id == id && other.upvotes == upvotes && other.omittedChildrenCount == omittedChildrenCount;

	@override
	int get hashCode => Object.hash(board, id, upvotes, omittedChildrenCount);
}

class PostAdapter extends TypeAdapter<Post> {
  @override
  final int typeId = 11;

  @override
  Post read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final Map<int, dynamic> fields;
		if (numOfFields == 255) {
			// Use new method (dynamic number of fields)
			fields = {};
			while (true) {
				final int fieldId = reader.readByte();
				fields[fieldId] = reader.read();
				if (fieldId == 0) {
					break;
				}
			}
		}
		else {
			fields = {
				for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
			};
		}
    return Post(
      board: fields[0] as String,
      text: fields[1] as String,
      name: fields[2] as String,
      time: fields[3] as DateTime,
      trip: fields[13] as String?,
      threadId: fields[4] as int,
      id: fields[5] as int,
      spanFormat: fields[9] as PostSpanFormat,
      flag: fields[7] as ImageboardFlag?,
      deprecatedAttachment: fields[6] as Attachment?,
      attachmentDeleted: fields[11] == null ? false : fields[11] as bool,
      posterId: fields[8] as String?,
      foolfuukaLinkedPostThreadIds: (fields[12] as Map?)?.cast<String, int>(),
      passSinceYear: fields[14] as int?,
      capcode: fields[15] as String?,
      attachments:
          fields[16] == null ? [] : (fields[16] as List).cast<Attachment>(),
			upvotes: fields[17] as int?,
			parentId: fields[18] as int?,
			omittedChildrenCount: (fields[19] as int?) ?? 0
    );
  }

  @override
  void write(BinaryWriter writer, Post obj) {
    writer
      ..writeByte(255)
      ..writeByte(1)
      ..write(obj.text)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.time)
      ..writeByte(4)
      ..write(obj.threadId)
      ..writeByte(5)
      ..write(obj.id)
      ..writeByte(9)
      ..write(obj.spanFormat)
      ..writeByte(11)
      ..write(obj.attachmentDeleted)
      ..writeByte(16)
      ..write(obj.attachments);
		if (obj.flag != null) {
      writer..writeByte(7)..write(obj.flag);
		}
		if (obj.posterId != null) {
      writer..writeByte(8)..write(obj.posterId);
		}
		if (obj.foolfuukaLinkedPostThreadIds != null) {
      writer..writeByte(12)..write(obj.foolfuukaLinkedPostThreadIds);
		}
		if (obj.trip != null) {
      writer..writeByte(13)..write(obj.trip);
		}
		if (obj.passSinceYear != null) {
      writer..writeByte(14)..write(obj.passSinceYear);
		}
		if (obj.capcode != null) {
      writer..writeByte(15)..write(obj.capcode);
		}
		if (obj.upvotes != null) {
			writer..writeByte(17)..write(obj.upvotes);
		}
		if (obj.parentId != null) {
			writer..writeByte(18)..write(obj.parentId);
		}
		if (obj.omittedChildrenCount != 0) {
			writer..writeByte(19)..write(obj.omittedChildrenCount);
		}
		// End with field zero (terminator)
		writer
			..writeByte(0)
      ..write(obj.board);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

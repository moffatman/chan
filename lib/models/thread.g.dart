// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'thread.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ThreadFields {
  static List<Post> getPosts_(Thread x) => x.posts_;
  static const int kPosts_ = 0;
  static const posts_ = ReadOnlyHiveFieldAdapter<Thread, List<Post>>(
    getter: getPosts_,
    fieldNumber: kPosts_,
    fieldName: 'posts_',
    merger: MapLikeListMerger<Post, int>(
        childMerger: AdaptedMerger(PostAdapter.kTypeId),
        keyer: PostFields.getId,
        maintainOrder: true),
  );
  static bool getIsArchived(Thread x) => x.isArchived;
  static void setIsArchived(Thread x, bool v) => x.isArchived = v;
  static const int kIsArchived = 1;
  static const isArchived = HiveFieldAdapter<Thread, bool>(
    getter: getIsArchived,
    setter: setIsArchived,
    fieldNumber: kIsArchived,
    fieldName: 'isArchived',
    merger: PrimitiveMerger(),
  );
  static bool getIsDeleted(Thread x) => x.isDeleted;
  static void setIsDeleted(Thread x, bool v) => x.isDeleted = v;
  static const int kIsDeleted = 2;
  static const isDeleted = HiveFieldAdapter<Thread, bool>(
    getter: getIsDeleted,
    setter: setIsDeleted,
    fieldNumber: kIsDeleted,
    fieldName: 'isDeleted',
    merger: PrimitiveMerger(),
  );
  static int getReplyCount(Thread x) => x.replyCount;
  static const int kReplyCount = 3;
  static const replyCount = ReadOnlyHiveFieldAdapter<Thread, int>(
    getter: getReplyCount,
    fieldNumber: kReplyCount,
    fieldName: 'replyCount',
    merger: PrimitiveMerger(),
  );
  static int getImageCount(Thread x) => x.imageCount;
  static const int kImageCount = 4;
  static const imageCount = ReadOnlyHiveFieldAdapter<Thread, int>(
    getter: getImageCount,
    fieldNumber: kImageCount,
    fieldName: 'imageCount',
    merger: PrimitiveMerger(),
  );
  static int getId(Thread x) => x.id;
  static const int kId = 5;
  static const id = ReadOnlyHiveFieldAdapter<Thread, int>(
    getter: getId,
    fieldNumber: kId,
    fieldName: 'id',
    merger: PrimitiveMerger(),
  );
  static String getBoard(Thread x) => x.board;
  static const int kBoard = 6;
  static const board = ReadOnlyHiveFieldAdapter<Thread, String>(
    getter: getBoard,
    fieldNumber: kBoard,
    fieldName: 'board',
    merger: PrimitiveMerger(),
  );
  static String? getTitle(Thread x) => x.title;
  static const int kTitle = 8;
  static const title = ReadOnlyHiveFieldAdapter<Thread, String?>(
    getter: getTitle,
    fieldNumber: kTitle,
    fieldName: 'title',
    merger: PrimitiveMerger(),
  );
  static bool getIsSticky(Thread x) => x.isSticky;
  static void setIsSticky(Thread x, bool v) => x.isSticky = v;
  static const int kIsSticky = 9;
  static const isSticky = HiveFieldAdapter<Thread, bool>(
    getter: getIsSticky,
    setter: setIsSticky,
    fieldNumber: kIsSticky,
    fieldName: 'isSticky',
    merger: PrimitiveMerger(),
  );
  static DateTime getTime(Thread x) => x.time;
  static const int kTime = 10;
  static const time = ReadOnlyHiveFieldAdapter<Thread, DateTime>(
    getter: getTime,
    fieldNumber: kTime,
    fieldName: 'time',
    merger: PrimitiveMerger(),
  );
  static Flag? getFlair(Thread x) => x.flair;
  static const int kFlair = 11;
  static const flair = ReadOnlyHiveFieldAdapter<Thread, Flag?>(
    getter: getFlair,
    fieldNumber: kFlair,
    fieldName: 'flair',
    merger: PrimitiveMerger(),
  );
  static int? getCurrentPage(Thread x) => x.currentPage;
  static void setCurrentPage(Thread x, int? v) => x.currentPage = v;
  static const int kCurrentPage = 12;
  static const currentPage = HiveFieldAdapter<Thread, int?>(
    getter: getCurrentPage,
    setter: setCurrentPage,
    fieldNumber: kCurrentPage,
    fieldName: 'currentPage',
    merger: PrimitiveMerger(),
  );
  static int? getUniqueIPCount(Thread x) => x.uniqueIPCount;
  static void setUniqueIPCount(Thread x, int? v) => x.uniqueIPCount = v;
  static const int kUniqueIPCount = 13;
  static const uniqueIPCount = HiveFieldAdapter<Thread, int?>(
    getter: getUniqueIPCount,
    setter: setUniqueIPCount,
    fieldNumber: kUniqueIPCount,
    fieldName: 'uniqueIPCount',
    merger: PrimitiveMerger(),
  );
  static int? getCustomSpoilerId(Thread x) => x.customSpoilerId;
  static void setCustomSpoilerId(Thread x, int? v) => x.customSpoilerId = v;
  static const int kCustomSpoilerId = 14;
  static const customSpoilerId = HiveFieldAdapter<Thread, int?>(
    getter: getCustomSpoilerId,
    setter: setCustomSpoilerId,
    fieldNumber: kCustomSpoilerId,
    fieldName: 'customSpoilerId',
    merger: PrimitiveMerger(),
  );
  static bool getAttachmentDeleted(Thread x) => x.attachmentDeleted;
  static void setAttachmentDeleted(Thread x, bool v) => x.attachmentDeleted = v;
  static const int kAttachmentDeleted = 15;
  static const attachmentDeleted = HiveFieldAdapter<Thread, bool>(
    getter: getAttachmentDeleted,
    setter: setAttachmentDeleted,
    fieldNumber: kAttachmentDeleted,
    fieldName: 'attachmentDeleted',
    merger: PrimitiveMerger(),
  );
  static List<Attachment> getAttachments(Thread x) => x.attachments;
  static void setAttachments(Thread x, List<Attachment> v) => x.attachments = v;
  static const int kAttachments = 16;
  static const attachments = HiveFieldAdapter<Thread, List<Attachment>>(
    getter: getAttachments,
    setter: setAttachments,
    fieldNumber: kAttachments,
    fieldName: 'attachments',
    merger: Attachment.unmodifiableListMerger,
  );
  static ThreadVariant? getSuggestedVariant(Thread x) => x.suggestedVariant;
  static void setSuggestedVariant(Thread x, ThreadVariant? v) =>
      x.suggestedVariant = v;
  static const int kSuggestedVariant = 17;
  static const suggestedVariant = HiveFieldAdapter<Thread, ThreadVariant?>(
    getter: getSuggestedVariant,
    setter: setSuggestedVariant,
    fieldNumber: kSuggestedVariant,
    fieldName: 'suggestedVariant',
    merger: PrimitiveMerger(),
  );
  static String? getArchiveName(Thread x) => x.archiveName;
  static void setArchiveName(Thread x, String? v) => x.archiveName = v;
  static const int kArchiveName = 18;
  static const archiveName = HiveFieldAdapter<Thread, String?>(
    getter: getArchiveName,
    setter: setArchiveName,
    fieldNumber: kArchiveName,
    fieldName: 'archiveName',
    merger: PrimitiveMerger(),
  );
  static ImageboardPoll? getPoll(Thread x) => x.poll;
  static void setPoll(Thread x, ImageboardPoll? v) => x.poll = v;
  static const int kPoll = 19;
  static const poll = HiveFieldAdapter<Thread, ImageboardPoll?>(
    getter: getPoll,
    setter: setPoll,
    fieldNumber: kPoll,
    fieldName: 'poll',
    merger: NullableMerger(AdaptedMerger(ImageboardPollAdapter.kTypeId)),
  );
  static bool getIsEndless(Thread x) => x.isEndless;
  static void setIsEndless(Thread x, bool v) => x.isEndless = v;
  static const int kIsEndless = 20;
  static const isEndless = HiveFieldAdapter<Thread, bool>(
    getter: getIsEndless,
    setter: setIsEndless,
    fieldNumber: kIsEndless,
    fieldName: 'isEndless',
    merger: PrimitiveMerger(),
  );
  static DateTime? getLastUpdatedTime(Thread x) => x.lastUpdatedTime;
  static void setLastUpdatedTime(Thread x, DateTime? v) =>
      x.lastUpdatedTime = v;
  static const int kLastUpdatedTime = 21;
  static const lastUpdatedTime = HiveFieldAdapter<Thread, DateTime?>(
    getter: getLastUpdatedTime,
    setter: setLastUpdatedTime,
    fieldNumber: kLastUpdatedTime,
    fieldName: 'lastUpdatedTime',
    merger: PrimitiveMerger(),
  );
  static bool getIsLocked(Thread x) => x.isLocked;
  static void setIsLocked(Thread x, bool v) => x.isLocked = v;
  static const int kIsLocked = 22;
  static const isLocked = HiveFieldAdapter<Thread, bool>(
    getter: getIsLocked,
    setter: setIsLocked,
    fieldNumber: kIsLocked,
    fieldName: 'isLocked',
    merger: PrimitiveMerger(),
  );
  static bool getIsNsfw(Thread x) => x.isNsfw;
  static void setIsNsfw(Thread x, bool v) => x.isNsfw = v;
  static const int kIsNsfw = 23;
  static const isNsfw = HiveFieldAdapter<Thread, bool>(
    getter: getIsNsfw,
    setter: setIsNsfw,
    fieldNumber: kIsNsfw,
    fieldName: 'isNsfw',
    merger: PrimitiveMerger(),
  );
}

class ThreadAdapter extends TypeAdapter<Thread> {
  const ThreadAdapter();

  static const int kTypeId = 15;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<Thread, dynamic>> fields = const {
    0: ThreadFields.posts_,
    1: ThreadFields.isArchived,
    2: ThreadFields.isDeleted,
    3: ThreadFields.replyCount,
    4: ThreadFields.imageCount,
    5: ThreadFields.id,
    6: ThreadFields.board,
    8: ThreadFields.title,
    9: ThreadFields.isSticky,
    10: ThreadFields.time,
    11: ThreadFields.flair,
    12: ThreadFields.currentPage,
    13: ThreadFields.uniqueIPCount,
    14: ThreadFields.customSpoilerId,
    15: ThreadFields.attachmentDeleted,
    16: ThreadFields.attachments,
    17: ThreadFields.suggestedVariant,
    18: ThreadFields.archiveName,
    19: ThreadFields.poll,
    20: ThreadFields.isEndless,
    21: ThreadFields.lastUpdatedTime,
    22: ThreadFields.isLocked,
    23: ThreadFields.isNsfw
  };

  @override
  Thread read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final List<dynamic> fields = List.filled(24, null);
    if (numOfFields == 255) {
      // Dynamic number of fields
      while (true) {
        final int fieldId = reader.readByte();
        final dynamic value = reader.read();
        if (fieldId < fields.length) {
          fields[fieldId] = value;
        }
        if (fieldId == 0) {
          break;
        }
      }
    } else {
      for (int i = 0; i < numOfFields; i++) {
        final int fieldId = reader.readByte();
        final dynamic value = reader.read();
        if (fieldId < fields.length) {
          fields[fieldId] = value;
        }
      }
    }
    _readHookThreadFields(fields);
    return Thread(
      posts_: (fields[0] as List).cast<Post>(),
      isArchived: fields[1] as bool,
      isDeleted: fields[2] as bool,
      replyCount: fields[3] as int,
      imageCount: fields[4] as int,
      id: fields[5] as int,
      attachmentDeleted: fields[15] == null ? false : fields[15] as bool,
      board: fields[6] as String,
      title: fields[8] as String?,
      isSticky: fields[9] as bool,
      time: fields[10] as DateTime,
      flair: fields[11] as Flag?,
      currentPage: fields[12] as int?,
      uniqueIPCount: fields[13] as int?,
      customSpoilerId: fields[14] as int?,
      attachments: (fields[16] as List).cast<Attachment>(),
      suggestedVariant: fields[17] as ThreadVariant?,
      poll: fields[19] as ImageboardPoll?,
      archiveName: fields[18] as String?,
      isEndless: fields[20] == null ? false : fields[20] as bool,
      lastUpdatedTime: fields[21] as DateTime?,
      isLocked: fields[22] == null ? false : fields[22] as bool,
      isNsfw: fields[23] == null ? false : fields[23] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Thread obj) {
    final Map<int, dynamic> fields = {
      0: obj.posts_,
      1: obj.isArchived,
      2: obj.isDeleted,
      3: obj.replyCount,
      4: obj.imageCount,
      5: obj.id,
      6: obj.board,
      8: obj.title,
      9: obj.isSticky,
      10: obj.time,
      if (obj.flair != null) 11: obj.flair,
      if (obj.currentPage != null) 12: obj.currentPage,
      if (obj.uniqueIPCount != null) 13: obj.uniqueIPCount,
      if (obj.customSpoilerId != null) 14: obj.customSpoilerId,
      if (obj.attachmentDeleted) 15: obj.attachmentDeleted,
      16: obj.attachments,
      if (obj.suggestedVariant != null) 17: obj.suggestedVariant,
      if (obj.archiveName != null) 18: obj.archiveName,
      if (obj.poll != null) 19: obj.poll,
      if (obj.isEndless) 20: obj.isEndless,
      if (obj.lastUpdatedTime != null) 21: obj.lastUpdatedTime,
      if (obj.isLocked) 22: obj.isLocked,
      if (obj.isNsfw) 23: obj.isNsfw,
    };
    writer.writeByte(fields.length);
    for (final MapEntry<int, dynamic> entry in fields.entries) {
      writer
        ..writeByte(entry.key)
        ..write(entry.value);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThreadAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ThreadIdentifierFields {
  static String getBoard(ThreadIdentifier x) => x.board;
  static const int kBoard = 0;
  static const board = ReadOnlyHiveFieldAdapter<ThreadIdentifier, String>(
    getter: getBoard,
    fieldNumber: kBoard,
    fieldName: 'board',
    merger: PrimitiveMerger(),
  );
  static int getId(ThreadIdentifier x) => x.id;
  static const int kId = 1;
  static const id = ReadOnlyHiveFieldAdapter<ThreadIdentifier, int>(
    getter: getId,
    fieldNumber: kId,
    fieldName: 'id',
    merger: PrimitiveMerger(),
  );
}

class ThreadIdentifierAdapter extends TypeAdapter<ThreadIdentifier> {
  const ThreadIdentifierAdapter();

  static const int kTypeId = 23;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<ThreadIdentifier, dynamic>> fields =
      const {0: ThreadIdentifierFields.board, 1: ThreadIdentifierFields.id};

  @override
  ThreadIdentifier read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final List<dynamic> fields = List.filled(2, null);
    for (int i = 0; i < numOfFields; i++) {
      final int fieldId = reader.readByte();
      final dynamic value = reader.read();
      if (fieldId < fields.length) {
        fields[fieldId] = value;
      }
    }
    return ThreadIdentifier(
      fields[0] as String,
      fields[1] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ThreadIdentifier obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.board)
      ..writeByte(1)
      ..write(obj.id);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThreadIdentifierAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

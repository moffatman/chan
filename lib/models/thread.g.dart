// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'thread.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ThreadFields {
  static List<Post> getPosts_(Thread x) => x.posts_;
  static const posts_ = ReadOnlyHiveFieldAdapter<Thread, List<Post>>(
    getter: getPosts_,
    fieldNumber: 0,
    fieldName: 'posts_',
    merger: MapLikeListMerger<Post, int>(
        childMerger: AdaptedMerger(PostAdapter.kTypeId),
        keyer: PostFields.getId,
        maintainOrder: true),
  );
  static bool getIsArchived(Thread x) => x.isArchived;
  static void setIsArchived(Thread x, bool v) => x.isArchived = v;
  static const isArchived = HiveFieldAdapter<Thread, bool>(
    getter: getIsArchived,
    setter: setIsArchived,
    fieldNumber: 1,
    fieldName: 'isArchived',
    merger: PrimitiveMerger(),
  );
  static bool getIsDeleted(Thread x) => x.isDeleted;
  static void setIsDeleted(Thread x, bool v) => x.isDeleted = v;
  static const isDeleted = HiveFieldAdapter<Thread, bool>(
    getter: getIsDeleted,
    setter: setIsDeleted,
    fieldNumber: 2,
    fieldName: 'isDeleted',
    merger: PrimitiveMerger(),
  );
  static int getReplyCount(Thread x) => x.replyCount;
  static const replyCount = ReadOnlyHiveFieldAdapter<Thread, int>(
    getter: getReplyCount,
    fieldNumber: 3,
    fieldName: 'replyCount',
    merger: PrimitiveMerger(),
  );
  static int getImageCount(Thread x) => x.imageCount;
  static const imageCount = ReadOnlyHiveFieldAdapter<Thread, int>(
    getter: getImageCount,
    fieldNumber: 4,
    fieldName: 'imageCount',
    merger: PrimitiveMerger(),
  );
  static int getId(Thread x) => x.id;
  static const id = ReadOnlyHiveFieldAdapter<Thread, int>(
    getter: getId,
    fieldNumber: 5,
    fieldName: 'id',
    merger: PrimitiveMerger(),
  );
  static String getBoard(Thread x) => x.board;
  static const board = ReadOnlyHiveFieldAdapter<Thread, String>(
    getter: getBoard,
    fieldNumber: 6,
    fieldName: 'board',
    merger: PrimitiveMerger(),
  );
  static String? getTitle(Thread x) => x.title;
  static const title = ReadOnlyHiveFieldAdapter<Thread, String?>(
    getter: getTitle,
    fieldNumber: 8,
    fieldName: 'title',
    merger: PrimitiveMerger(),
  );
  static bool getIsSticky(Thread x) => x.isSticky;
  static void setIsSticky(Thread x, bool v) => x.isSticky = v;
  static const isSticky = HiveFieldAdapter<Thread, bool>(
    getter: getIsSticky,
    setter: setIsSticky,
    fieldNumber: 9,
    fieldName: 'isSticky',
    merger: PrimitiveMerger(),
  );
  static DateTime getTime(Thread x) => x.time;
  static const time = ReadOnlyHiveFieldAdapter<Thread, DateTime>(
    getter: getTime,
    fieldNumber: 10,
    fieldName: 'time',
    merger: PrimitiveMerger(),
  );
  static Flag? getFlair(Thread x) => x.flair;
  static const flair = ReadOnlyHiveFieldAdapter<Thread, Flag?>(
    getter: getFlair,
    fieldNumber: 11,
    fieldName: 'flair',
    merger: PrimitiveMerger(),
  );
  static int? getCurrentPage(Thread x) => x.currentPage;
  static void setCurrentPage(Thread x, int? v) => x.currentPage = v;
  static const currentPage = HiveFieldAdapter<Thread, int?>(
    getter: getCurrentPage,
    setter: setCurrentPage,
    fieldNumber: 12,
    fieldName: 'currentPage',
    merger: PrimitiveMerger(),
  );
  static int? getUniqueIPCount(Thread x) => x.uniqueIPCount;
  static void setUniqueIPCount(Thread x, int? v) => x.uniqueIPCount = v;
  static const uniqueIPCount = HiveFieldAdapter<Thread, int?>(
    getter: getUniqueIPCount,
    setter: setUniqueIPCount,
    fieldNumber: 13,
    fieldName: 'uniqueIPCount',
    merger: PrimitiveMerger(),
  );
  static int? getCustomSpoilerId(Thread x) => x.customSpoilerId;
  static void setCustomSpoilerId(Thread x, int? v) => x.customSpoilerId = v;
  static const customSpoilerId = HiveFieldAdapter<Thread, int?>(
    getter: getCustomSpoilerId,
    setter: setCustomSpoilerId,
    fieldNumber: 14,
    fieldName: 'customSpoilerId',
    merger: PrimitiveMerger(),
  );
  static bool getAttachmentDeleted(Thread x) => x.attachmentDeleted;
  static void setAttachmentDeleted(Thread x, bool v) => x.attachmentDeleted = v;
  static const attachmentDeleted = HiveFieldAdapter<Thread, bool>(
    getter: getAttachmentDeleted,
    setter: setAttachmentDeleted,
    fieldNumber: 15,
    fieldName: 'attachmentDeleted',
    merger: PrimitiveMerger(),
  );
  static List<Attachment> getAttachments(Thread x) => x.attachments;
  static void setAttachments(Thread x, List<Attachment> v) => x.attachments = v;
  static const attachments = HiveFieldAdapter<Thread, List<Attachment>>(
    getter: getAttachments,
    setter: setAttachments,
    fieldNumber: 16,
    fieldName: 'attachments',
    merger: Attachment.unmodifiableListMerger,
  );
  static ThreadVariant? getSuggestedVariant(Thread x) => x.suggestedVariant;
  static void setSuggestedVariant(Thread x, ThreadVariant? v) =>
      x.suggestedVariant = v;
  static const suggestedVariant = HiveFieldAdapter<Thread, ThreadVariant?>(
    getter: getSuggestedVariant,
    setter: setSuggestedVariant,
    fieldNumber: 17,
    fieldName: 'suggestedVariant',
    merger: PrimitiveMerger(),
  );
  static String? getArchiveName(Thread x) => x.archiveName;
  static void setArchiveName(Thread x, String? v) => x.archiveName = v;
  static const archiveName = HiveFieldAdapter<Thread, String?>(
    getter: getArchiveName,
    setter: setArchiveName,
    fieldNumber: 18,
    fieldName: 'archiveName',
    merger: PrimitiveMerger(),
  );
  static ImageboardPoll? getPoll(Thread x) => x.poll;
  static void setPoll(Thread x, ImageboardPoll? v) => x.poll = v;
  static const poll = HiveFieldAdapter<Thread, ImageboardPoll?>(
    getter: getPoll,
    setter: setPoll,
    fieldNumber: 19,
    fieldName: 'poll',
    merger: NullableMerger(AdaptedMerger(ImageboardPollAdapter.kTypeId)),
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
    19: ThreadFields.poll
  };

  @override
  Thread read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final Map<int, dynamic> fields;
    if (numOfFields == 255) {
      // Dynamic number of fields
      fields = {};
      while (true) {
        final int fieldId = reader.readByte();
        fields[fieldId] = reader.read();
        if (fieldId == 0) {
          break;
        }
      }
    } else {
      fields = <int, dynamic>{
        for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
      };
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
  static const board = ReadOnlyHiveFieldAdapter<ThreadIdentifier, String>(
    getter: getBoard,
    fieldNumber: 0,
    fieldName: 'board',
    merger: PrimitiveMerger(),
  );
  static int getId(ThreadIdentifier x) => x.id;
  static const id = ReadOnlyHiveFieldAdapter<ThreadIdentifier, int>(
    getter: getId,
    fieldNumber: 1,
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
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
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

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PostFields {
  static String getBoard(Post x) => x.board;
  static const board = ReadOnlyHiveFieldAdapter<Post, String>(
    getter: getBoard,
    fieldNumber: 0,
    fieldName: 'board',
    merger: PrimitiveMerger(),
  );
  static String getText(Post x) => x.text;
  static const text = ReadOnlyHiveFieldAdapter<Post, String>(
    getter: getText,
    fieldNumber: 1,
    fieldName: 'text',
    merger: PrimitiveMerger(),
  );
  static String getName(Post x) => x.name;
  static const name = ReadOnlyHiveFieldAdapter<Post, String>(
    getter: getName,
    fieldNumber: 2,
    fieldName: 'name',
    merger: PrimitiveMerger(),
  );
  static DateTime getTime(Post x) => x.time;
  static const time = ReadOnlyHiveFieldAdapter<Post, DateTime>(
    getter: getTime,
    fieldNumber: 3,
    fieldName: 'time',
    merger: PrimitiveMerger(),
  );
  static int getThreadId(Post x) => x.threadId;
  static const threadId = ReadOnlyHiveFieldAdapter<Post, int>(
    getter: getThreadId,
    fieldNumber: 4,
    fieldName: 'threadId',
    merger: PrimitiveMerger(),
  );
  static int getId(Post x) => x.id;
  static const id = ReadOnlyHiveFieldAdapter<Post, int>(
    getter: getId,
    fieldNumber: 5,
    fieldName: 'id',
    merger: PrimitiveMerger(),
  );
  static Flag? getFlag(Post x) => x.flag;
  static const flag = ReadOnlyHiveFieldAdapter<Post, Flag?>(
    getter: getFlag,
    fieldNumber: 7,
    fieldName: 'flag',
    merger: PrimitiveMerger<Flag?>(),
  );
  static String? getPosterId(Post x) => x.posterId;
  static const posterId = ReadOnlyHiveFieldAdapter<Post, String?>(
    getter: getPosterId,
    fieldNumber: 8,
    fieldName: 'posterId',
    merger: PrimitiveMerger(),
  );
  static PostSpanFormat getSpanFormat(Post x) => x.spanFormat;
  static void setSpanFormat(Post x, PostSpanFormat v) => x.spanFormat = v;
  static const spanFormat = HiveFieldAdapter<Post, PostSpanFormat>(
    getter: getSpanFormat,
    setter: setSpanFormat,
    fieldNumber: 9,
    fieldName: 'spanFormat',
    merger: PrimitiveMerger(),
  );
  static Map<String, int>? getFoolfuukaLinkedPostThreadIds(Post x) =>
      x.foolfuukaLinkedPostThreadIds;
  static void setFoolfuukaLinkedPostThreadIds(Post x, Map<String, int>? v) =>
      x.foolfuukaLinkedPostThreadIds = v;
  static const foolfuukaLinkedPostThreadIds =
      HiveFieldAdapter<Post, Map<String, int>?>(
    getter: getFoolfuukaLinkedPostThreadIds,
    setter: setFoolfuukaLinkedPostThreadIds,
    fieldNumber: 12,
    fieldName: 'foolfuukaLinkedPostThreadIds',
    merger: NullableMerger(MapMerger(PrimitiveMerger())),
  );
  static bool getAttachmentDeleted(Post x) => x.attachmentDeleted;
  static void setAttachmentDeleted(Post x, bool v) => x.attachmentDeleted = v;
  static const attachmentDeleted = HiveFieldAdapter<Post, bool>(
    getter: getAttachmentDeleted,
    setter: setAttachmentDeleted,
    fieldNumber: 11,
    fieldName: 'attachmentDeleted',
    merger: PrimitiveMerger(),
  );
  static String? getTrip(Post x) => x.trip;
  static void setTrip(Post x, String? v) => x.trip = v;
  static const trip = HiveFieldAdapter<Post, String?>(
    getter: getTrip,
    setter: setTrip,
    fieldNumber: 13,
    fieldName: 'trip',
    merger: PrimitiveMerger(),
  );
  static int? getPassSinceYear(Post x) => x.passSinceYear;
  static void setPassSinceYear(Post x, int? v) => x.passSinceYear = v;
  static const passSinceYear = HiveFieldAdapter<Post, int?>(
    getter: getPassSinceYear,
    setter: setPassSinceYear,
    fieldNumber: 14,
    fieldName: 'passSinceYear',
    merger: PrimitiveMerger(),
  );
  static String? getCapcode(Post x) => x.capcode;
  static void setCapcode(Post x, String? v) => x.capcode = v;
  static const capcode = HiveFieldAdapter<Post, String?>(
    getter: getCapcode,
    setter: setCapcode,
    fieldNumber: 15,
    fieldName: 'capcode',
    merger: PrimitiveMerger(),
  );
  static List<Attachment> getAttachments_(Post x) => x.attachments_;
  static void setAttachments_(Post x, List<Attachment> v) => x.attachments_ = v;
  static const attachments_ = HiveFieldAdapter<Post, List<Attachment>>(
    getter: getAttachments_,
    setter: setAttachments_,
    fieldNumber: 16,
    fieldName: 'attachments_',
    merger: Attachment.unmodifiableListMerger,
  );
  static int? getUpvotes(Post x) => x.upvotes;
  static const upvotes = ReadOnlyHiveFieldAdapter<Post, int?>(
    getter: getUpvotes,
    fieldNumber: 17,
    fieldName: 'upvotes',
    merger: PrimitiveMerger(),
  );
  static int? getParentId(Post x) => x.parentId;
  static const parentId = ReadOnlyHiveFieldAdapter<Post, int?>(
    getter: getParentId,
    fieldNumber: 18,
    fieldName: 'parentId',
    merger: PrimitiveMerger(),
  );
  static bool getHasOmittedReplies(Post x) => x.hasOmittedReplies;
  static void setHasOmittedReplies(Post x, bool v) => x.hasOmittedReplies = v;
  static const hasOmittedReplies = HiveFieldAdapter<Post, bool>(
    getter: getHasOmittedReplies,
    setter: setHasOmittedReplies,
    fieldNumber: 20,
    fieldName: 'hasOmittedReplies',
    merger: PrimitiveMerger(),
  );
  static bool getIsDeleted(Post x) => x.isDeleted;
  static void setIsDeleted(Post x, bool v) => x.isDeleted = v;
  static const isDeleted = HiveFieldAdapter<Post, bool>(
    getter: getIsDeleted,
    setter: setIsDeleted,
    fieldNumber: 21,
    fieldName: 'isDeleted',
    merger: PrimitiveMerger(),
  );
  static int? getIpNumber(Post x) => x.ipNumber;
  static void setIpNumber(Post x, int? v) => x.ipNumber = v;
  static const ipNumber = HiveFieldAdapter<Post, int?>(
    getter: getIpNumber,
    setter: setIpNumber,
    fieldNumber: 22,
    fieldName: 'ipNumber',
    merger: PrimitiveMerger(),
  );
}

class PostAdapter extends TypeAdapter<Post> {
  const PostAdapter();

  static const int kTypeId = 11;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<Post, dynamic>> fields = const {
    0: PostFields.board,
    1: PostFields.text,
    2: PostFields.name,
    3: PostFields.time,
    4: PostFields.threadId,
    5: PostFields.id,
    7: PostFields.flag,
    8: PostFields.posterId,
    9: PostFields.spanFormat,
    12: PostFields.foolfuukaLinkedPostThreadIds,
    11: PostFields.attachmentDeleted,
    13: PostFields.trip,
    14: PostFields.passSinceYear,
    15: PostFields.capcode,
    16: PostFields.attachments_,
    17: PostFields.upvotes,
    18: PostFields.parentId,
    20: PostFields.hasOmittedReplies,
    21: PostFields.isDeleted,
    22: PostFields.ipNumber
  };

  @override
  Post read(BinaryReader reader) {
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
    _readHookPostFields(fields);
    return Post(
      board: fields[0] as String,
      text: fields[1] as String,
      name: fields[2] as String,
      time: fields[3] as DateTime,
      trip: fields[13] as String?,
      threadId: fields[4] as int,
      id: fields[5] as int,
      spanFormat: fields[9] as PostSpanFormat,
      flag: fields[7] as Flag?,
      attachmentDeleted: fields[11] == null ? false : fields[11] as bool,
      posterId: fields[8] as String?,
      foolfuukaLinkedPostThreadIds: (fields[12] as Map?)?.cast<String, int>(),
      passSinceYear: fields[14] as int?,
      capcode: fields[15] as String?,
      attachments_:
          fields[16] == null ? [] : (fields[16] as List).cast<Attachment>(),
      upvotes: fields[17] as int?,
      parentId: fields[18] as int?,
      hasOmittedReplies: fields[20] == null ? false : fields[20] as bool,
      isDeleted: fields[21] == null ? false : fields[21] as bool,
      ipNumber: fields[22] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Post obj) {
    final Map<int, dynamic> fields = {
      0: obj.board,
      1: obj.text,
      2: obj.name,
      3: obj.time,
      4: obj.threadId,
      5: obj.id,
      if (obj.flag != null) 7: obj.flag,
      if (obj.posterId != null) 8: obj.posterId,
      9: obj.spanFormat,
      if (obj.foolfuukaLinkedPostThreadIds != null)
        12: obj.foolfuukaLinkedPostThreadIds,
      if (obj.attachmentDeleted) 11: obj.attachmentDeleted,
      if (obj.trip != null) 13: obj.trip,
      if (obj.passSinceYear != null) 14: obj.passSinceYear,
      if (obj.capcode != null) 15: obj.capcode,
      if (obj.attachments_.isNotEmpty) 16: obj.attachments_,
      if (obj.upvotes != null) 17: obj.upvotes,
      if (obj.parentId != null) 18: obj.parentId,
      if (obj.hasOmittedReplies) 20: obj.hasOmittedReplies,
      if (obj.isDeleted) 21: obj.isDeleted,
      if (obj.ipNumber != null) 22: obj.ipNumber,
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
      other is PostAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PostSpanFormatAdapter extends TypeAdapter<PostSpanFormat> {
  const PostSpanFormatAdapter();

  static const int kTypeId = 13;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<PostSpanFormat, dynamic>> fields =
      const {};

  @override
  PostSpanFormat read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PostSpanFormat.chan4;
      case 1:
        return PostSpanFormat.foolFuuka;
      case 2:
        return PostSpanFormat.lainchan;
      case 3:
        return PostSpanFormat.fuuka;
      case 4:
        return PostSpanFormat.futaba;
      case 5:
        return PostSpanFormat.reddit;
      case 6:
        return PostSpanFormat.hackerNews;
      case 7:
        return PostSpanFormat.stub;
      case 8:
        return PostSpanFormat.lynxchan;
      case 9:
        return PostSpanFormat.chan4Search;
      case 10:
        return PostSpanFormat.xenforo;
      case 11:
        return PostSpanFormat.pageStub;
      case 12:
        return PostSpanFormat.karachan;
      case 13:
        return PostSpanFormat.jsChan;
      default:
        return PostSpanFormat.chan4;
    }
  }

  @override
  void write(BinaryWriter writer, PostSpanFormat obj) {
    switch (obj) {
      case PostSpanFormat.chan4:
        writer.writeByte(0);
        break;
      case PostSpanFormat.foolFuuka:
        writer.writeByte(1);
        break;
      case PostSpanFormat.lainchan:
        writer.writeByte(2);
        break;
      case PostSpanFormat.fuuka:
        writer.writeByte(3);
        break;
      case PostSpanFormat.futaba:
        writer.writeByte(4);
        break;
      case PostSpanFormat.reddit:
        writer.writeByte(5);
        break;
      case PostSpanFormat.hackerNews:
        writer.writeByte(6);
        break;
      case PostSpanFormat.stub:
        writer.writeByte(7);
        break;
      case PostSpanFormat.lynxchan:
        writer.writeByte(8);
        break;
      case PostSpanFormat.chan4Search:
        writer.writeByte(9);
        break;
      case PostSpanFormat.xenforo:
        writer.writeByte(10);
        break;
      case PostSpanFormat.pageStub:
        writer.writeByte(11);
        break;
      case PostSpanFormat.karachan:
        writer.writeByte(12);
        break;
      case PostSpanFormat.jsChan:
        writer.writeByte(13);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostSpanFormatAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

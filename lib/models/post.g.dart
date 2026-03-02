// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PostFields {
  static String getBoard(Post x) => x.board;
  static const int kBoard = 0;
  static const board = ReadOnlyHiveFieldAdapter<Post, String>(
    getter: getBoard,
    fieldNumber: kBoard,
    fieldName: 'board',
    merger: PrimitiveMerger(),
  );
  static String getText(Post x) => x.text;
  static const int kText = 1;
  static const text = ReadOnlyHiveFieldAdapter<Post, String>(
    getter: getText,
    fieldNumber: kText,
    fieldName: 'text',
    merger: PrimitiveMerger(),
  );
  static String getName(Post x) => x.name;
  static const int kName = 2;
  static const name = ReadOnlyHiveFieldAdapter<Post, String>(
    getter: getName,
    fieldNumber: kName,
    fieldName: 'name',
    merger: PrimitiveMerger(),
  );
  static DateTime getTime(Post x) => x.time;
  static const int kTime = 3;
  static const time = ReadOnlyHiveFieldAdapter<Post, DateTime>(
    getter: getTime,
    fieldNumber: kTime,
    fieldName: 'time',
    merger: PrimitiveMerger(),
  );
  static int getThreadId(Post x) => x.threadId;
  static const int kThreadId = 4;
  static const threadId = ReadOnlyHiveFieldAdapter<Post, int>(
    getter: getThreadId,
    fieldNumber: kThreadId,
    fieldName: 'threadId',
    merger: PrimitiveMerger(),
  );
  static int getId(Post x) => x.id;
  static const int kId = 5;
  static const id = ReadOnlyHiveFieldAdapter<Post, int>(
    getter: getId,
    fieldNumber: kId,
    fieldName: 'id',
    merger: PrimitiveMerger(),
  );
  static Flag? getFlag(Post x) => x.flag;
  static void setFlag(Post x, Flag? v) => x.flag = v;
  static const int kFlag = 7;
  static const flag = HiveFieldAdapter<Post, Flag?>(
    getter: getFlag,
    setter: setFlag,
    fieldNumber: kFlag,
    fieldName: 'flag',
    merger: PrimitiveMerger<Flag?>(),
  );
  static String? getPosterId(Post x) => x.posterId;
  static const int kPosterId = 8;
  static const posterId = ReadOnlyHiveFieldAdapter<Post, String?>(
    getter: getPosterId,
    fieldNumber: kPosterId,
    fieldName: 'posterId',
    merger: PrimitiveMerger(),
  );
  static PostSpanFormat getSpanFormat(Post x) => x.spanFormat;
  static void setSpanFormat(Post x, PostSpanFormat v) => x.spanFormat = v;
  static const int kSpanFormat = 9;
  static const spanFormat = HiveFieldAdapter<Post, PostSpanFormat>(
    getter: getSpanFormat,
    setter: setSpanFormat,
    fieldNumber: kSpanFormat,
    fieldName: 'spanFormat',
    merger: PrimitiveMerger(),
  );
  static Map<String, int>? getExtraMetadata(Post x) => x.extraMetadata;
  static void setExtraMetadata(Post x, Map<String, int>? v) =>
      x.extraMetadata = v;
  static const int kExtraMetadata = 12;
  static const extraMetadata = HiveFieldAdapter<Post, Map<String, int>?>(
    getter: getExtraMetadata,
    setter: setExtraMetadata,
    fieldNumber: kExtraMetadata,
    fieldName: 'extraMetadata',
    merger: NullableMerger(MapMerger(PrimitiveMerger())),
  );
  static bool getAttachmentDeleted(Post x) => x.attachmentDeleted;
  static void setAttachmentDeleted(Post x, bool v) => x.attachmentDeleted = v;
  static const int kAttachmentDeleted = 11;
  static const attachmentDeleted = HiveFieldAdapter<Post, bool>(
    getter: getAttachmentDeleted,
    setter: setAttachmentDeleted,
    fieldNumber: kAttachmentDeleted,
    fieldName: 'attachmentDeleted',
    merger: PrimitiveMerger(),
  );
  static String? getTrip(Post x) => x.trip;
  static void setTrip(Post x, String? v) => x.trip = v;
  static const int kTrip = 13;
  static const trip = HiveFieldAdapter<Post, String?>(
    getter: getTrip,
    setter: setTrip,
    fieldNumber: kTrip,
    fieldName: 'trip',
    merger: PrimitiveMerger(),
  );
  static int? getPassSinceYear(Post x) => x.passSinceYear;
  static void setPassSinceYear(Post x, int? v) => x.passSinceYear = v;
  static const int kPassSinceYear = 14;
  static const passSinceYear = HiveFieldAdapter<Post, int?>(
    getter: getPassSinceYear,
    setter: setPassSinceYear,
    fieldNumber: kPassSinceYear,
    fieldName: 'passSinceYear',
    merger: PrimitiveMerger(),
  );
  static String? getCapcode(Post x) => x.capcode;
  static void setCapcode(Post x, String? v) => x.capcode = v;
  static const int kCapcode = 15;
  static const capcode = HiveFieldAdapter<Post, String?>(
    getter: getCapcode,
    setter: setCapcode,
    fieldNumber: kCapcode,
    fieldName: 'capcode',
    merger: PrimitiveMerger(),
  );
  static List<Attachment> getAttachments_(Post x) => x.attachments_;
  static void setAttachments_(Post x, List<Attachment> v) => x.attachments_ = v;
  static const int kAttachments_ = 16;
  static const attachments_ = HiveFieldAdapter<Post, List<Attachment>>(
    getter: getAttachments_,
    setter: setAttachments_,
    fieldNumber: kAttachments_,
    fieldName: 'attachments_',
    merger: Attachment.unmodifiableListMerger,
  );
  static int? getUpvotes(Post x) => x.upvotes;
  static const int kUpvotes = 17;
  static const upvotes = ReadOnlyHiveFieldAdapter<Post, int?>(
    getter: getUpvotes,
    fieldNumber: kUpvotes,
    fieldName: 'upvotes',
    merger: PrimitiveMerger(),
  );
  static int? getParentId(Post x) => x.parentId;
  static const int kParentId = 18;
  static const parentId = ReadOnlyHiveFieldAdapter<Post, int?>(
    getter: getParentId,
    fieldNumber: kParentId,
    fieldName: 'parentId',
    merger: PrimitiveMerger(),
  );
  static bool getHasOmittedReplies(Post x) => x.hasOmittedReplies;
  static void setHasOmittedReplies(Post x, bool v) => x.hasOmittedReplies = v;
  static const int kHasOmittedReplies = 20;
  static const hasOmittedReplies = HiveFieldAdapter<Post, bool>(
    getter: getHasOmittedReplies,
    setter: setHasOmittedReplies,
    fieldNumber: kHasOmittedReplies,
    fieldName: 'hasOmittedReplies',
    merger: PrimitiveMerger(),
  );
  static bool getIsDeleted(Post x) => x.isDeleted;
  static const int kIsDeleted = 21;
  static const isDeleted = ReadOnlyHiveFieldAdapter<Post, bool>(
    getter: getIsDeleted,
    fieldNumber: kIsDeleted,
    fieldName: 'isDeleted',
    merger: PrimitiveMerger(),
  );
  static int? getIpNumber(Post x) => x.ipNumber;
  static void setIpNumber(Post x, int? v) => x.ipNumber = v;
  static const int kIpNumber = 22;
  static const ipNumber = HiveFieldAdapter<Post, int?>(
    getter: getIpNumber,
    setter: setIpNumber,
    fieldNumber: kIpNumber,
    fieldName: 'ipNumber',
    merger: PrimitiveMerger(),
  );
  static String? getArchiveName(Post x) => x.archiveName;
  static void setArchiveName(Post x, String? v) => x.archiveName = v;
  static const int kArchiveName = 23;
  static const archiveName = HiveFieldAdapter<Post, String?>(
    getter: getArchiveName,
    setter: setArchiveName,
    fieldNumber: kArchiveName,
    fieldName: 'archiveName',
    merger: PrimitiveMerger(),
  );
  static String? getEmail(Post x) => x.email;
  static const int kEmail = 24;
  static const email = ReadOnlyHiveFieldAdapter<Post, String?>(
    getter: getEmail,
    fieldNumber: kEmail,
    fieldName: 'email',
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
    12: PostFields.extraMetadata,
    11: PostFields.attachmentDeleted,
    13: PostFields.trip,
    14: PostFields.passSinceYear,
    15: PostFields.capcode,
    16: PostFields.attachments_,
    17: PostFields.upvotes,
    18: PostFields.parentId,
    20: PostFields.hasOmittedReplies,
    21: PostFields.isDeleted,
    22: PostFields.ipNumber,
    23: PostFields.archiveName,
    24: PostFields.email
  };

  @override
  Post read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final List<dynamic> fields = List.filled(25, null);
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
      extraMetadata: (fields[12] as Map?)?.cast<String, int>(),
      passSinceYear: fields[14] as int?,
      capcode: fields[15] as String?,
      attachments_:
          fields[16] == null ? [] : (fields[16] as List).cast<Attachment>(),
      upvotes: fields[17] as int?,
      parentId: fields[18] as int?,
      hasOmittedReplies: fields[20] == null ? false : fields[20] as bool,
      isDeleted: fields[21] == null ? false : fields[21] as bool,
      ipNumber: fields[22] as int?,
      archiveName: fields[23] as String?,
      email: fields[24] as String?,
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
      if (obj.extraMetadata != null) 12: obj.extraMetadata,
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
      if (obj.archiveName != null) 23: obj.archiveName,
      if (obj.email != null) 24: obj.email,
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
      case 14:
        return PostSpanFormat.jForum;
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
      case PostSpanFormat.jForum:
        writer.writeByte(14);
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

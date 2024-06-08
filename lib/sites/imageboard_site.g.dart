// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'imageboard_site.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ImageboardBoardFlagFields {
  static String getCode(ImageboardBoardFlag x) => x.code;
  static const code = ReadOnlyHiveFieldAdapter<ImageboardBoardFlag, String>(
    getter: getCode,
    fieldNumber: 0,
    fieldName: 'code',
    merger: PrimitiveMerger(),
  );
  static String getName(ImageboardBoardFlag x) => x.name;
  static const name = ReadOnlyHiveFieldAdapter<ImageboardBoardFlag, String>(
    getter: getName,
    fieldNumber: 1,
    fieldName: 'name',
    merger: PrimitiveMerger(),
  );
  static String getImageUrl(ImageboardBoardFlag x) => x.imageUrl;
  static const imageUrl = ReadOnlyHiveFieldAdapter<ImageboardBoardFlag, String>(
    getter: getImageUrl,
    fieldNumber: 2,
    fieldName: 'imageUrl',
    merger: PrimitiveMerger(),
  );
}

class ImageboardBoardFlagAdapter extends TypeAdapter<ImageboardBoardFlag> {
  const ImageboardBoardFlagAdapter();

  static const int kTypeId = 46;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<ImageboardBoardFlag, dynamic>>
      fields = const {
    0: ImageboardBoardFlagFields.code,
    1: ImageboardBoardFlagFields.name,
    2: ImageboardBoardFlagFields.imageUrl
  };

  @override
  ImageboardBoardFlag read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ImageboardBoardFlag(
      code: fields[0] as String,
      name: fields[1] as String,
      imageUrl: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ImageboardBoardFlag obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.code)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.imageUrl);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageboardBoardFlagAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DraftPostFields {
  static String getBoard(DraftPost x) => x.board;
  static const board = ReadOnlyHiveFieldAdapter<DraftPost, String>(
    getter: getBoard,
    fieldNumber: 0,
    fieldName: 'board',
    merger: PrimitiveMerger(),
  );
  static int? getThreadId(DraftPost x) => x.threadId;
  static const threadId = ReadOnlyHiveFieldAdapter<DraftPost, int?>(
    getter: getThreadId,
    fieldNumber: 1,
    fieldName: 'threadId',
    merger: PrimitiveMerger(),
  );
  static String? getName(DraftPost x) => x.name;
  static void setName(DraftPost x, String? v) => x.name = v;
  static const name = HiveFieldAdapter<DraftPost, String?>(
    getter: getName,
    setter: setName,
    fieldNumber: 2,
    fieldName: 'name',
    merger: PrimitiveMerger(),
  );
  static String? getOptions(DraftPost x) => x.options;
  static const options = ReadOnlyHiveFieldAdapter<DraftPost, String?>(
    getter: getOptions,
    fieldNumber: 3,
    fieldName: 'options',
    merger: PrimitiveMerger(),
  );
  static String? getSubject(DraftPost x) => x.subject;
  static const subject = ReadOnlyHiveFieldAdapter<DraftPost, String?>(
    getter: getSubject,
    fieldNumber: 4,
    fieldName: 'subject',
    merger: PrimitiveMerger(),
  );
  static String getText(DraftPost x) => x.text;
  static const text = ReadOnlyHiveFieldAdapter<DraftPost, String>(
    getter: getText,
    fieldNumber: 5,
    fieldName: 'text',
    merger: PrimitiveMerger(),
  );
  static String? getFile(DraftPost x) => x.file;
  static void setFile(DraftPost x, String? v) => x.file = v;
  static const file = HiveFieldAdapter<DraftPost, String?>(
    getter: getFile,
    setter: setFile,
    fieldNumber: 6,
    fieldName: 'file',
    merger: PrimitiveMerger(),
  );
  static bool? getSpoiler(DraftPost x) => x.spoiler;
  static const spoiler = ReadOnlyHiveFieldAdapter<DraftPost, bool?>(
    getter: getSpoiler,
    fieldNumber: 7,
    fieldName: 'spoiler',
    merger: PrimitiveMerger(),
  );
  static String? getOverrideFilenameWithoutExtension(DraftPost x) =>
      x.overrideFilenameWithoutExtension;
  static const overrideFilenameWithoutExtension =
      ReadOnlyHiveFieldAdapter<DraftPost, String?>(
    getter: getOverrideFilenameWithoutExtension,
    fieldNumber: 8,
    fieldName: 'overrideFilenameWithoutExtension',
    merger: PrimitiveMerger(),
  );
  static ImageboardBoardFlag? getFlag(DraftPost x) => x.flag;
  static const flag = ReadOnlyHiveFieldAdapter<DraftPost, ImageboardBoardFlag?>(
    getter: getFlag,
    fieldNumber: 9,
    fieldName: 'flag',
    merger: NullableMerger(AdaptedMerger(ImageboardBoardFlagAdapter.kTypeId)),
  );
  static bool? getUseLoginSystem(DraftPost x) => x.useLoginSystem;
  static void setUseLoginSystem(DraftPost x, bool? v) => x.useLoginSystem = v;
  static const useLoginSystem = HiveFieldAdapter<DraftPost, bool?>(
    getter: getUseLoginSystem,
    setter: setUseLoginSystem,
    fieldNumber: 10,
    fieldName: 'useLoginSystem',
    merger: PrimitiveMerger(),
  );
}

class DraftPostAdapter extends TypeAdapter<DraftPost> {
  const DraftPostAdapter();

  static const int kTypeId = 47;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<DraftPost, dynamic>> fields = const {
    0: DraftPostFields.board,
    1: DraftPostFields.threadId,
    2: DraftPostFields.name,
    3: DraftPostFields.options,
    4: DraftPostFields.subject,
    5: DraftPostFields.text,
    6: DraftPostFields.file,
    7: DraftPostFields.spoiler,
    8: DraftPostFields.overrideFilenameWithoutExtension,
    9: DraftPostFields.flag,
    10: DraftPostFields.useLoginSystem
  };

  @override
  DraftPost read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DraftPost(
      board: fields[0] as String,
      threadId: fields[1] as int?,
      name: fields[2] as String?,
      options: fields[3] as String?,
      subject: fields[4] as String?,
      text: fields[5] as String,
      file: fields[6] as String?,
      spoiler: fields[7] as bool?,
      overrideFilenameWithoutExtension: fields[8] as String?,
      flag: fields[9] as ImageboardBoardFlag?,
      useLoginSystem: fields[10] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, DraftPost obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.board)
      ..writeByte(1)
      ..write(obj.threadId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.options)
      ..writeByte(4)
      ..write(obj.subject)
      ..writeByte(5)
      ..write(obj.text)
      ..writeByte(6)
      ..write(obj.file)
      ..writeByte(7)
      ..write(obj.spoiler)
      ..writeByte(8)
      ..write(obj.overrideFilenameWithoutExtension)
      ..writeByte(9)
      ..write(obj.flag)
      ..writeByte(10)
      ..write(obj.useLoginSystem);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DraftPostAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ImageboardPollRowFields {
  static String getName(ImageboardPollRow x) => x.name;
  static const name = ReadOnlyHiveFieldAdapter<ImageboardPollRow, String>(
    getter: getName,
    fieldNumber: 0,
    fieldName: 'name',
    merger: PrimitiveMerger(),
  );
  static int getVotes(ImageboardPollRow x) => x.votes;
  static const votes = ReadOnlyHiveFieldAdapter<ImageboardPollRow, int>(
    getter: getVotes,
    fieldNumber: 1,
    fieldName: 'votes',
    merger: PrimitiveMerger(),
  );
  static Color? getColor(ImageboardPollRow x) => x.color;
  static const color = ReadOnlyHiveFieldAdapter<ImageboardPollRow, Color?>(
    getter: getColor,
    fieldNumber: 2,
    fieldName: 'color',
    merger: NullableMerger(AdaptedMerger(ColorAdapter.kTypeId)),
  );
}

class ImageboardPollRowAdapter extends TypeAdapter<ImageboardPollRow> {
  const ImageboardPollRowAdapter();

  static const int kTypeId = 48;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<ImageboardPollRow, dynamic>> fields =
      const {
    0: ImageboardPollRowFields.name,
    1: ImageboardPollRowFields.votes,
    2: ImageboardPollRowFields.color
  };

  @override
  ImageboardPollRow read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ImageboardPollRow(
      name: fields[0] as String,
      votes: fields[1] as int,
      color: fields[2] as Color?,
    );
  }

  @override
  void write(BinaryWriter writer, ImageboardPollRow obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.votes)
      ..writeByte(2)
      ..write(obj.color);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageboardPollRowAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ImageboardPollFields {
  static String? getTitle(ImageboardPoll x) => x.title;
  static const title = ReadOnlyHiveFieldAdapter<ImageboardPoll, String?>(
    getter: getTitle,
    fieldNumber: 1,
    fieldName: 'title',
    merger: PrimitiveMerger(),
  );
  static List<ImageboardPollRow> getRows(ImageboardPoll x) => x.rows;
  static const rows =
      ReadOnlyHiveFieldAdapter<ImageboardPoll, List<ImageboardPollRow>>(
    getter: getRows,
    fieldNumber: 2,
    fieldName: 'rows',
    merger: ListEqualsMerger<ImageboardPollRow>(),
  );
}

class ImageboardPollAdapter extends TypeAdapter<ImageboardPoll> {
  const ImageboardPollAdapter();

  static const int kTypeId = 49;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<ImageboardPoll, dynamic>> fields =
      const {1: ImageboardPollFields.title, 2: ImageboardPollFields.rows};

  @override
  ImageboardPoll read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ImageboardPoll(
      title: fields[1] as String?,
      rows: (fields[2] as List).cast<ImageboardPollRow>(),
    );
  }

  @override
  void write(BinaryWriter writer, ImageboardPoll obj) {
    writer
      ..writeByte(2)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.rows);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageboardPollAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CatalogVariantAdapter extends TypeAdapter<CatalogVariant> {
  const CatalogVariantAdapter();

  static const int kTypeId = 33;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<CatalogVariant, dynamic>> fields =
      const {};

  @override
  CatalogVariant read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return CatalogVariant.unsorted;
      case 1:
        return CatalogVariant.unsortedReversed;
      case 2:
        return CatalogVariant.lastPostTime;
      case 3:
        return CatalogVariant.lastPostTimeReversed;
      case 4:
        return CatalogVariant.replyCount;
      case 5:
        return CatalogVariant.replyCountReversed;
      case 6:
        return CatalogVariant.threadPostTime;
      case 7:
        return CatalogVariant.threadPostTimeReversed;
      case 8:
        return CatalogVariant.savedTime;
      case 9:
        return CatalogVariant.savedTimeReversed;
      case 10:
        return CatalogVariant.postsPerMinute;
      case 11:
        return CatalogVariant.postsPerMinuteReversed;
      case 12:
        return CatalogVariant.lastReplyTime;
      case 13:
        return CatalogVariant.lastReplyTimeReversed;
      case 14:
        return CatalogVariant.imageCount;
      case 15:
        return CatalogVariant.imageCountReversed;
      case 16:
        return CatalogVariant.lastReplyByYouTime;
      case 17:
        return CatalogVariant.lastReplyByYouTimeReversed;
      case 18:
        return CatalogVariant.redditHot;
      case 19:
        return CatalogVariant.redditNew;
      case 20:
        return CatalogVariant.redditRising;
      case 21:
        return CatalogVariant.redditControversialPastHour;
      case 22:
        return CatalogVariant.redditControversialPast24Hours;
      case 23:
        return CatalogVariant.redditControversialPastWeek;
      case 24:
        return CatalogVariant.redditControversialPastMonth;
      case 25:
        return CatalogVariant.redditControversialPastYear;
      case 26:
        return CatalogVariant.redditControversialAllTime;
      case 27:
        return CatalogVariant.redditTopPastHour;
      case 28:
        return CatalogVariant.redditTopPast24Hours;
      case 29:
        return CatalogVariant.redditTopPastWeek;
      case 30:
        return CatalogVariant.redditTopPastMonth;
      case 31:
        return CatalogVariant.redditTopPastYear;
      case 32:
        return CatalogVariant.redditTopAllTime;
      case 33:
        return CatalogVariant.chan4NativeArchive;
      case 34:
        return CatalogVariant.hackerNewsTop;
      case 35:
        return CatalogVariant.hackerNewsNew;
      case 36:
        return CatalogVariant.hackerNewsBest;
      case 37:
        return CatalogVariant.hackerNewsAsk;
      case 38:
        return CatalogVariant.hackerNewsShow;
      case 39:
        return CatalogVariant.hackerNewsJobs;
      case 40:
        return CatalogVariant.hackerNewsSecondChancePool;
      case 41:
        return CatalogVariant.alphabeticByTitle;
      case 42:
        return CatalogVariant.alphabeticByTitleReversed;
      default:
        return CatalogVariant.unsorted;
    }
  }

  @override
  void write(BinaryWriter writer, CatalogVariant obj) {
    switch (obj) {
      case CatalogVariant.unsorted:
        writer.writeByte(0);
        break;
      case CatalogVariant.unsortedReversed:
        writer.writeByte(1);
        break;
      case CatalogVariant.lastPostTime:
        writer.writeByte(2);
        break;
      case CatalogVariant.lastPostTimeReversed:
        writer.writeByte(3);
        break;
      case CatalogVariant.replyCount:
        writer.writeByte(4);
        break;
      case CatalogVariant.replyCountReversed:
        writer.writeByte(5);
        break;
      case CatalogVariant.threadPostTime:
        writer.writeByte(6);
        break;
      case CatalogVariant.threadPostTimeReversed:
        writer.writeByte(7);
        break;
      case CatalogVariant.savedTime:
        writer.writeByte(8);
        break;
      case CatalogVariant.savedTimeReversed:
        writer.writeByte(9);
        break;
      case CatalogVariant.postsPerMinute:
        writer.writeByte(10);
        break;
      case CatalogVariant.postsPerMinuteReversed:
        writer.writeByte(11);
        break;
      case CatalogVariant.lastReplyTime:
        writer.writeByte(12);
        break;
      case CatalogVariant.lastReplyTimeReversed:
        writer.writeByte(13);
        break;
      case CatalogVariant.imageCount:
        writer.writeByte(14);
        break;
      case CatalogVariant.imageCountReversed:
        writer.writeByte(15);
        break;
      case CatalogVariant.lastReplyByYouTime:
        writer.writeByte(16);
        break;
      case CatalogVariant.lastReplyByYouTimeReversed:
        writer.writeByte(17);
        break;
      case CatalogVariant.redditHot:
        writer.writeByte(18);
        break;
      case CatalogVariant.redditNew:
        writer.writeByte(19);
        break;
      case CatalogVariant.redditRising:
        writer.writeByte(20);
        break;
      case CatalogVariant.redditControversialPastHour:
        writer.writeByte(21);
        break;
      case CatalogVariant.redditControversialPast24Hours:
        writer.writeByte(22);
        break;
      case CatalogVariant.redditControversialPastWeek:
        writer.writeByte(23);
        break;
      case CatalogVariant.redditControversialPastMonth:
        writer.writeByte(24);
        break;
      case CatalogVariant.redditControversialPastYear:
        writer.writeByte(25);
        break;
      case CatalogVariant.redditControversialAllTime:
        writer.writeByte(26);
        break;
      case CatalogVariant.redditTopPastHour:
        writer.writeByte(27);
        break;
      case CatalogVariant.redditTopPast24Hours:
        writer.writeByte(28);
        break;
      case CatalogVariant.redditTopPastWeek:
        writer.writeByte(29);
        break;
      case CatalogVariant.redditTopPastMonth:
        writer.writeByte(30);
        break;
      case CatalogVariant.redditTopPastYear:
        writer.writeByte(31);
        break;
      case CatalogVariant.redditTopAllTime:
        writer.writeByte(32);
        break;
      case CatalogVariant.chan4NativeArchive:
        writer.writeByte(33);
        break;
      case CatalogVariant.hackerNewsTop:
        writer.writeByte(34);
        break;
      case CatalogVariant.hackerNewsNew:
        writer.writeByte(35);
        break;
      case CatalogVariant.hackerNewsBest:
        writer.writeByte(36);
        break;
      case CatalogVariant.hackerNewsAsk:
        writer.writeByte(37);
        break;
      case CatalogVariant.hackerNewsShow:
        writer.writeByte(38);
        break;
      case CatalogVariant.hackerNewsJobs:
        writer.writeByte(39);
        break;
      case CatalogVariant.hackerNewsSecondChancePool:
        writer.writeByte(40);
        break;
      case CatalogVariant.alphabeticByTitle:
        writer.writeByte(41);
        break;
      case CatalogVariant.alphabeticByTitleReversed:
        writer.writeByte(42);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogVariantAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ThreadVariantAdapter extends TypeAdapter<ThreadVariant> {
  const ThreadVariantAdapter();

  static const int kTypeId = 34;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<ThreadVariant, dynamic>> fields =
      const {};

  @override
  ThreadVariant read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ThreadVariant.redditTop;
      case 1:
        return ThreadVariant.redditBest;
      case 2:
        return ThreadVariant.redditNew;
      case 3:
        return ThreadVariant.redditControversial;
      case 4:
        return ThreadVariant.redditOld;
      case 5:
        return ThreadVariant.redditQandA;
      default:
        return ThreadVariant.redditTop;
    }
  }

  @override
  void write(BinaryWriter writer, ThreadVariant obj) {
    switch (obj) {
      case ThreadVariant.redditTop:
        writer.writeByte(0);
        break;
      case ThreadVariant.redditBest:
        writer.writeByte(1);
        break;
      case ThreadVariant.redditNew:
        writer.writeByte(2);
        break;
      case ThreadVariant.redditControversial:
        writer.writeByte(3);
        break;
      case ThreadVariant.redditOld:
        writer.writeByte(4);
        break;
      case ThreadVariant.redditQandA:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThreadVariantAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PostSortingMethodAdapter extends TypeAdapter<PostSortingMethod> {
  const PostSortingMethodAdapter();

  static const int kTypeId = 41;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<PostSortingMethod, dynamic>> fields =
      const {};

  @override
  PostSortingMethod read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PostSortingMethod.none;
      case 1:
        return PostSortingMethod.replyCount;
      default:
        return PostSortingMethod.none;
    }
  }

  @override
  void write(BinaryWriter writer, PostSortingMethod obj) {
    switch (obj) {
      case PostSortingMethod.none:
        writer.writeByte(0);
        break;
      case PostSortingMethod.replyCount:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostSortingMethodAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

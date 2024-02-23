// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'thread_watcher.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ThreadWatchFields {
  static String getBoard(ThreadWatch x) => x.board;
  static const board = ReadOnlyHiveFieldAdapter<ThreadWatch, String>(
    getter: getBoard,
    fieldNumber: 0,
    fieldName: 'board',
    merger: PrimitiveMerger(),
  );
  static int getThreadId(ThreadWatch x) => x.threadId;
  static const threadId = ReadOnlyHiveFieldAdapter<ThreadWatch, int>(
    getter: getThreadId,
    fieldNumber: 1,
    fieldName: 'threadId',
    merger: PrimitiveMerger(),
  );
  static int getLastSeenId(ThreadWatch x) => x.lastSeenId;
  static void setLastSeenId(ThreadWatch x, int v) => x.lastSeenId = v;
  static const lastSeenId = HiveFieldAdapter<ThreadWatch, int>(
    getter: getLastSeenId,
    setter: setLastSeenId,
    fieldNumber: 2,
    fieldName: 'lastSeenId',
    merger: PrimitiveMerger(),
  );
  static bool getLocalYousOnly(ThreadWatch x) => x.localYousOnly;
  static void setLocalYousOnly(ThreadWatch x, bool v) => x.localYousOnly = v;
  static const localYousOnly = HiveFieldAdapter<ThreadWatch, bool>(
    getter: getLocalYousOnly,
    setter: setLocalYousOnly,
    fieldNumber: 3,
    fieldName: 'localYousOnly',
    merger: PrimitiveMerger(),
  );
  static List<int> getYouIds(ThreadWatch x) => x.youIds;
  static void setYouIds(ThreadWatch x, List<int> v) => x.youIds = v;
  static const youIds = HiveFieldAdapter<ThreadWatch, List<int>>(
    getter: getYouIds,
    setter: setYouIds,
    fieldNumber: 4,
    fieldName: 'youIds',
    merger: SetLikePrimitiveListMerger<int>(),
  );
  static bool getZombie(ThreadWatch x) => x.zombie;
  static void setZombie(ThreadWatch x, bool v) => x.zombie = v;
  static const zombie = HiveFieldAdapter<ThreadWatch, bool>(
    getter: getZombie,
    setter: setZombie,
    fieldNumber: 5,
    fieldName: 'zombie',
    merger: PrimitiveMerger(),
  );
  static bool getPushYousOnly(ThreadWatch x) => x.pushYousOnly;
  static void setPushYousOnly(ThreadWatch x, bool v) => x.pushYousOnly = v;
  static const pushYousOnly = HiveFieldAdapter<ThreadWatch, bool>(
    getter: getPushYousOnly,
    setter: setPushYousOnly,
    fieldNumber: 6,
    fieldName: 'pushYousOnly',
    merger: PrimitiveMerger(),
  );
  static bool getPush(ThreadWatch x) => x.push;
  static void setPush(ThreadWatch x, bool v) => x.push = v;
  static const push = HiveFieldAdapter<ThreadWatch, bool>(
    getter: getPush,
    setter: setPush,
    fieldNumber: 7,
    fieldName: 'push',
    merger: PrimitiveMerger(),
  );
  static bool getForegroundMuted(ThreadWatch x) => x.foregroundMuted;
  static void setForegroundMuted(ThreadWatch x, bool v) =>
      x.foregroundMuted = v;
  static const foregroundMuted = HiveFieldAdapter<ThreadWatch, bool>(
    getter: getForegroundMuted,
    setter: setForegroundMuted,
    fieldNumber: 8,
    fieldName: 'foregroundMuted',
    merger: PrimitiveMerger(),
  );
  static DateTime? getWatchTime(ThreadWatch x) => x.watchTime;
  static void setWatchTime(ThreadWatch x, DateTime? v) => x.watchTime = v;
  static const watchTime = HiveFieldAdapter<ThreadWatch, DateTime?>(
    getter: getWatchTime,
    setter: setWatchTime,
    fieldNumber: 9,
    fieldName: 'watchTime',
    merger: PrimitiveMerger(),
  );
}

class ThreadWatchAdapter extends TypeAdapter<ThreadWatch> {
  const ThreadWatchAdapter();

  static const int kTypeId = 28;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<ThreadWatch, dynamic>> fields =
      const {
    0: ThreadWatchFields.board,
    1: ThreadWatchFields.threadId,
    2: ThreadWatchFields.lastSeenId,
    3: ThreadWatchFields.localYousOnly,
    4: ThreadWatchFields.youIds,
    5: ThreadWatchFields.zombie,
    6: ThreadWatchFields.pushYousOnly,
    7: ThreadWatchFields.push,
    8: ThreadWatchFields.foregroundMuted,
    9: ThreadWatchFields.watchTime
  };

  @override
  ThreadWatch read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ThreadWatch(
      board: fields[0] as String,
      threadId: fields[1] as int,
      lastSeenId: fields[2] as int,
      localYousOnly: fields[3] == null ? true : fields[3] as bool,
      youIds: fields[4] == null ? [] : (fields[4] as List).cast<int>(),
      zombie: fields[5] == null ? false : fields[5] as bool,
      pushYousOnly: fields[6] == null ? true : fields[6] as bool?,
      push: fields[7] == null ? true : fields[7] as bool,
      foregroundMuted: fields[8] == null ? false : fields[8] as bool,
      watchTime: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, ThreadWatch obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.board)
      ..writeByte(1)
      ..write(obj.threadId)
      ..writeByte(2)
      ..write(obj.lastSeenId)
      ..writeByte(3)
      ..write(obj.localYousOnly)
      ..writeByte(4)
      ..write(obj.youIds)
      ..writeByte(5)
      ..write(obj.zombie)
      ..writeByte(6)
      ..write(obj.pushYousOnly)
      ..writeByte(7)
      ..write(obj.push)
      ..writeByte(8)
      ..write(obj.foregroundMuted)
      ..writeByte(9)
      ..write(obj.watchTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThreadWatchAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BoardWatchFields {
  static String getBoard(BoardWatch x) => x.board;
  static void setBoard(BoardWatch x, String v) => x.board = v;
  static const board = HiveFieldAdapter<BoardWatch, String>(
    getter: getBoard,
    setter: setBoard,
    fieldNumber: 0,
    fieldName: 'board',
    merger: PrimitiveMerger(),
  );
  static bool getThreadsOnly(BoardWatch x) => x.threadsOnly;
  static void setThreadsOnly(BoardWatch x, bool v) => x.threadsOnly = v;
  static const threadsOnly = HiveFieldAdapter<BoardWatch, bool>(
    getter: getThreadsOnly,
    setter: setThreadsOnly,
    fieldNumber: 3,
    fieldName: 'threadsOnly',
    merger: PrimitiveMerger(),
  );
}

class BoardWatchAdapter extends TypeAdapter<BoardWatch> {
  const BoardWatchAdapter();

  static const int kTypeId = 29;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<BoardWatch, dynamic>> fields = const {
    0: BoardWatchFields.board,
    3: BoardWatchFields.threadsOnly
  };

  @override
  BoardWatch read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BoardWatch(
      board: fields[0] as String,
      threadsOnly: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, BoardWatch obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.board)
      ..writeByte(3)
      ..write(obj.threadsOnly);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoardWatchAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
